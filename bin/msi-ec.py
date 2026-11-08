#!/usr/bin/python3 -I
"""Read and write the msi-ec sysfs controls. Values stay on an allowlist."""

import json
import os
import re
import stat
import sys

PLATFORM = "/sys/devices/platform/msi-ec"
BATTERY_ROOT = "/sys/class/power_supply"
MAX_BYTES = 128
_NAME = re.compile(r"[a-z0-9_]+")
_BATTERY = re.compile(r"BAT[0-9]")
_MODE = re.compile(r"[a-z]{2,16}")

PLATFORM_READS = (
    "fw_version",
    "fw_release_date",
    "available_shift_modes",
    "shift_mode",
    "available_fan_modes",
    "fan_mode",
    "cooler_boost",
    "webcam",
    "webcam_block",
    "fn_key",
    "win_key",
    "super_battery",
    "cpu/realtime_temperature",
    "cpu/realtime_fan_speed",
    "gpu/realtime_temperature",
    "gpu/realtime_fan_speed",
)
BOOL_KEYS = ("cooler_boost", "webcam", "webcam_block", "super_battery")
SIDE_KEYS = ("fn_key", "win_key")


class Rejected(Exception):
    pass


def _parts(relative):
    parts = relative.split("/")
    if len(parts) > 2 or not parts or any(_NAME.fullmatch(part) is None for part in parts):
        raise Rejected()
    return parts


def _read_fd(fd):
    os.set_blocking(fd, True)
    data = b""
    while len(data) <= MAX_BYTES:
        chunk = os.read(fd, MAX_BYTES + 1 - len(data))
        if not chunk:
            break
        data += chunk
    if len(data) > MAX_BYTES:
        raise Rejected()
    return data.decode("ascii").strip()


def read_attr(path):
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC)
    except FileNotFoundError:
        return None
    except OSError:
        return None
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode):
            return None
        return _read_fd(fd)
    except (OSError, UnicodeError, Rejected):
        return None
    finally:
        os.close(fd)


def write_attr(path, text):
    payload = (text + "\n").encode("ascii")
    if len(payload) > 32:
        raise Rejected()
    fd = os.open(path, os.O_WRONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode):
            raise Rejected()
        view = memoryview(payload)
        while view:
            wrote = os.write(fd, view)
            if wrote <= 0:
                raise OSError("short write")
            view = view[wrote:]
    finally:
        os.close(fd)


def _writable(path):
    try:
        return os.access(path, os.W_OK) and not os.path.islink(path) and os.path.isfile(path)
    except OSError:
        return False


def _modes(text):
    if text is None:
        return []
    found = []
    for line in text.splitlines():
        if not line:
            continue
        if _MODE.fullmatch(line) is None or line in found or len(found) >= 8:
            return []
        found.append(line)
    return found


def _current_mode(text, allowed):
    if text is None:
        return None
    if text in allowed:
        return text
    if text == "unspecified":
        return "unspecified"
    return None


def _bool_text(text):
    if text == "on":
        return True
    if text == "off":
        return False
    return None


def _side_text(text):
    if text in ("left", "right"):
        return text
    return None


def _int_text(text, low, high):
    if text is None or not text.isdecimal() or len(text) > 3:
        return None
    value = int(text)
    if value < low or value > high:
        return None
    return value


def _battery_name(root):
    try:
        names = os.listdir(root)
    except OSError:
        return None
    chosen = None
    seen = 0
    for name in sorted(names):
        seen += 1
        if seen > 32:
            break
        if _BATTERY.fullmatch(name) is None:
            continue
        path = os.path.join(root, name, "charge_control_end_threshold")
        if os.path.isfile(path) and not os.path.islink(path):
            chosen = name
            break
    return chosen


def _platform(base, relative):
    return os.path.join(base, *_parts(relative))


class Tree:
    def __init__(self, fixture=None):
        if fixture is None:
            self.platform = PLATFORM
            self.batteries = BATTERY_ROOT
            return
        info = os.lstat(fixture)
        if (not stat.S_ISDIR(info.st_mode) or stat.S_ISLNK(info.st_mode)
                or info.st_uid != os.geteuid() or stat.S_IMODE(info.st_mode) != 0o700):
            raise Rejected()
        fd = os.open(fixture, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
        os.close(fd)
        self.platform = os.path.join(fixture, "platform")
        self.batteries = os.path.join(fixture, "battery")


def status(tree):
    present = os.path.isdir(tree.platform) and not os.path.islink(tree.platform)
    body = {
        "present": present,
        "writable": False,
        "fwVersion": None,
        "fwDate": None,
        "shiftMode": None,
        "shiftModes": [],
        "fanMode": None,
        "fanModes": [],
        "coolerBoost": None,
        "webcam": None,
        "webcamBlock": None,
        "fnKey": None,
        "winKey": None,
        "superBattery": None,
        "chargeEnd": None,
        "cpuTemp": None,
        "cpuFan": None,
        "gpuTemp": None,
        "gpuFan": None,
    }
    if not present:
        return body

    raw = {}
    for relative in PLATFORM_READS:
        try:
            raw[relative] = read_attr(_platform(tree.platform, relative))
        except Rejected:
            raw[relative] = None

    version = raw["fw_version"] if raw["fw_version"] and re.fullmatch(r"[A-Za-z0-9._-]{1,32}", raw["fw_version"]) else None
    date = raw["fw_release_date"] if raw["fw_release_date"] and re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}", raw["fw_release_date"]) else None
    shift_modes = _modes(raw["available_shift_modes"])
    fan_modes = _modes(raw["available_fan_modes"])
    body.update({
        "fwVersion": version,
        "fwDate": date,
        "shiftModes": shift_modes,
        "shiftMode": _current_mode(raw["shift_mode"], shift_modes),
        "fanModes": fan_modes,
        "fanMode": _current_mode(raw["fan_mode"], fan_modes) if raw["fan_mode"] != "unspecified" else None,
        "coolerBoost": _bool_text(raw["cooler_boost"]),
        "webcam": _bool_text(raw["webcam"]),
        "webcamBlock": _bool_text(raw["webcam_block"]),
        "fnKey": _side_text(raw["fn_key"]),
        "winKey": _side_text(raw["win_key"]),
        "superBattery": _bool_text(raw["super_battery"]),
        "cpuTemp": _int_text(raw["cpu/realtime_temperature"], 0, 150),
        "cpuFan": _int_text(raw["cpu/realtime_fan_speed"], 0, 150),
        "gpuTemp": _int_text(raw["gpu/realtime_temperature"], 0, 150),
        "gpuFan": _int_text(raw["gpu/realtime_fan_speed"], 0, 150),
    })
    if body["fanMode"] == "unspecified":
        body["fanMode"] = None

    battery = _battery_name(tree.batteries)
    if battery is not None:
        body["chargeEnd"] = _int_text(
            read_attr(os.path.join(tree.batteries, battery, "charge_control_end_threshold")),
            0, 100)

    controls = [name for name in (
        "shift_mode", "fan_mode", "cooler_boost", "webcam", "webcam_block",
        "fn_key", "win_key", "super_battery") if raw.get(name) is not None]
    writable = bool(controls) and all(_writable(_platform(tree.platform, name)) for name in controls)
    if battery is not None:
        charge_path = os.path.join(tree.batteries, battery, "charge_control_end_threshold")
        writable = writable and _writable(charge_path) if controls else _writable(charge_path)
    body["writable"] = writable
    return body


def _require_mode(tree, relative, value):
    if _MODE.fullmatch(value) is None:
        raise Rejected()
    allowed = _modes(read_attr(_platform(tree.platform, relative)))
    if value not in allowed:
        raise Rejected()
    return value


def apply_control(tree, key, value):
    if not isinstance(key, str) or not isinstance(value, str):
        raise Rejected()
    if key == "shift_mode":
        text = _require_mode(tree, "available_shift_modes", value)
        write_attr(_platform(tree.platform, "shift_mode"), text)
        return
    if key == "fan_mode":
        text = _require_mode(tree, "available_fan_modes", value)
        write_attr(_platform(tree.platform, "fan_mode"), text)
        return
    if key in BOOL_KEYS:
        if value not in ("on", "off"):
            raise Rejected()
        path = _platform(tree.platform, key)
        if read_attr(path) is None:
            raise Rejected()
        write_attr(path, value)
        return
    if key in SIDE_KEYS:
        if value not in ("left", "right"):
            raise Rejected()
        path = _platform(tree.platform, key)
        if read_attr(path) is None:
            raise Rejected()
        write_attr(path, value)
        return
    if key == "charge_control_end_threshold":
        number = _int_text(value, 10, 100)
        if number is None or number < 10:
            raise Rejected()
        battery = _battery_name(tree.batteries)
        if battery is None:
            raise Rejected()
        write_attr(os.path.join(tree.batteries, battery, key), str(number))
        return
    raise Rejected()


def _fixture(path):
    if not path.startswith("/") or "\x00" in path or len(path) > 240:
        raise Rejected()
    return Tree(path)


def main(argv):
    args = argv[1:]
    fixture = None
    if args and args[0] == "--fixture":
        if len(args) < 2:
            return 2
        try:
            fixture = _fixture(args[1])
        except (Rejected, OSError):
            return 2
        args = args[2:]
    else:
        fixture = Tree()
    if not args or args[0] not in ("status", "set"):
        return 2
    try:
        if args[0] == "status":
            if len(args) != 1:
                return 2
            document = status(fixture)
        else:
            if len(args) != 3:
                return 2
            apply_control(fixture, args[1], args[2])
            document = status(fixture)
    except Rejected:
        return 3
    except OSError:
        return 4
    sys.stdout.write(json.dumps(document, separators=(",", ":"), ensure_ascii=True))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv))
    except BrokenPipeError:
        raise SystemExit(0)
