#!/usr/bin/python3 -I
import json
import os
import stat
import subprocess
import tempfile
import unittest

HELPER = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "bin", "msi-ec.py")


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC, 0o644)
    try:
        os.write(fd, text.encode("ascii"))
    finally:
        os.close(fd)


class HelperTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.mkdtemp(prefix="msi-controls-")
        os.chmod(self.directory, 0o700)
        platform = os.path.join(self.directory, "platform")
        os.mkdir(platform, 0o755)
        os.mkdir(os.path.join(platform, "cpu"), 0o755)
        os.mkdir(os.path.join(platform, "gpu"), 0o755)
        write(os.path.join(platform, "fw_version"), "17G3EWS1.113\n")
        write(os.path.join(platform, "fw_release_date"), "2021-02-03T11:10:21\n")
        write(os.path.join(platform, "available_shift_modes"), "turbo\neco\ncomfort\nsport\n")
        write(os.path.join(platform, "shift_mode"), "unspecified\n")
        write(os.path.join(platform, "available_fan_modes"), "auto\nbasic\nadvanced\n")
        write(os.path.join(platform, "fan_mode"), "auto\n")
        write(os.path.join(platform, "cooler_boost"), "off\n")
        write(os.path.join(platform, "webcam"), "on\n")
        write(os.path.join(platform, "webcam_block"), "off\n")
        write(os.path.join(platform, "fn_key"), "right\n")
        write(os.path.join(platform, "win_key"), "left\n")
        write(os.path.join(platform, "cpu", "realtime_temperature"), "59\n")
        write(os.path.join(platform, "cpu", "realtime_fan_speed"), "50\n")
        write(os.path.join(platform, "gpu", "realtime_temperature"), "53\n")
        write(os.path.join(platform, "gpu", "realtime_fan_speed"), "48\n")
        battery = os.path.join(self.directory, "battery", "BAT1")
        write(os.path.join(battery, "charge_control_end_threshold"), "0\n")

    def run_helper(self, *args):
        return subprocess.run(
            ["/usr/bin/python3", "-I", "-S", HELPER, "--fixture", self.directory, *args],
            check=False, capture_output=True, text=True, timeout=5)

    def test_status_shape(self):
        result = self.run_helper("status")
        self.assertEqual(result.returncode, 0, result.stderr)
        body = json.loads(result.stdout)
        self.assertEqual(body["fwVersion"], "17G3EWS1.113")
        self.assertEqual(body["shiftMode"], "unspecified")
        self.assertEqual(body["fanModes"], ["auto", "basic", "advanced"])
        self.assertEqual(body["cpuTemp"], 59)
        self.assertEqual(body["chargeEnd"], 0)
        self.assertIsNone(body["superBattery"])
        self.assertTrue(body["writable"])
        self.assertLessEqual(len(result.stdout), 4096)

    def test_set_fan_mode(self):
        result = self.run_helper("set", "fan_mode", "basic")
        self.assertEqual(result.returncode, 0, result.stderr)
        body = json.loads(result.stdout)
        self.assertEqual(body["fanMode"], "basic")
        with open(os.path.join(self.directory, "platform", "fan_mode"), encoding="ascii") as handle:
            self.assertEqual(handle.read(), "basic\n")

    def test_reject_unknown_and_charge_clear(self):
        self.assertEqual(self.run_helper("set", "fan_mode", "silent").returncode, 3)
        self.assertEqual(self.run_helper("set", "shift_mode", "unspecified").returncode, 3)
        self.assertEqual(self.run_helper("set", "charge_control_end_threshold", "0").returncode, 3)
        self.assertEqual(self.run_helper("set", "charge_control_end_threshold", "101").returncode, 3)
        self.assertEqual(self.run_helper("set", "../platform/fan_mode", "auto").returncode, 3)
        with open(os.path.join(self.directory, "platform", "fan_mode"), encoding="ascii") as handle:
            self.assertEqual(handle.read(), "auto\n")

    def test_symlink_is_not_followed(self):
        victim = os.path.join(self.directory, "victim")
        with open(victim, "w", encoding="ascii") as handle:
            handle.write("SAFE\n")
        fan = os.path.join(self.directory, "platform", "fan_mode")
        os.remove(fan)
        os.symlink(victim, fan)
        status = self.run_helper("status")
        self.assertEqual(status.returncode, 0)
        self.assertIsNone(json.loads(status.stdout)["fanMode"])
        denied = self.run_helper("set", "fan_mode", "basic")
        self.assertNotEqual(denied.returncode, 0)
        with open(victim, encoding="ascii") as handle:
            self.assertEqual(handle.read(), "SAFE\n")

    def test_missing_driver(self):
        empty = tempfile.mkdtemp(prefix="msi-controls-empty-")
        os.chmod(empty, 0o700)
        result = subprocess.run(
            ["/usr/bin/python3", "-I", "-S", HELPER, "--fixture", empty, "status"],
            check=False, capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0)
        self.assertFalse(json.loads(result.stdout)["present"])
        self.assertTrue(stat.S_ISDIR(os.stat(empty).st_mode))


if __name__ == "__main__":
    unittest.main()
