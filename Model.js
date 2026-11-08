.pragma library

function plain(value, maxLen) {
  var limit = maxLen > 0 ? maxLen : 48
  var text = String(value === undefined || value === null ? "" : value)
  var out = ""
  for (var i = 0; i < text.length && out.length < limit; i++) {
    var code = text.charCodeAt(i)
    var ch = text.charAt(i)
    if (ch === "<" || ch === ">" || ch === "&") continue
    if (code < 32 || code === 127) continue
    if (code >= 0x80 && code <= 0x9f) continue
    if (code >= 0x202a && code <= 0x202e) continue
    if (code >= 0x2066 && code <= 0x2069) continue
    out += ch
  }
  return out
}

function _mode(value) {
  if (typeof value !== "string") return null
  if (!/^[a-z]{2,16}$/.test(value)) return null
  return value
}

function _modeList(value) {
  if (!Array.isArray(value)) return []
  if (value.length > 8) return []
  var out = []
  for (var i = 0; i < value.length; i++) {
    var mode = _mode(value[i])
    if (!mode || out.indexOf(mode) >= 0) return []
    out.push(mode)
  }
  return out
}

function _bool(value) {
  if (value === true || value === false) return value
  return null
}

function _side(value) {
  if (value === "left" || value === "right") return value
  return null
}

function _int(value, min, max) {
  if (typeof value !== "number" || !isFinite(value) || Math.round(value) !== value) return null
  if (value < min || value > max) return null
  return value
}

function parseStatus(text) {
  if (typeof text !== "string" || text.length > 4096) return null
  var data
  try { data = JSON.parse(text) }
  catch (error) { return null }
  if (!data || typeof data !== "object" || Array.isArray(data)) return null
  if (data.present !== true && data.present !== false) return null
  var shiftModes = _modeList(data.shiftModes)
  var shiftMode = data.shiftMode === null || data.shiftMode === undefined
    ? null
    : (data.shiftMode === "unspecified" ? "unspecified" : _mode(data.shiftMode))
  if (shiftMode && shiftMode !== "unspecified" && shiftModes.indexOf(shiftMode) < 0) shiftMode = null
  var fanModes = _modeList(data.fanModes)
  var fanMode = _mode(data.fanMode)
  if (fanMode && fanModes.indexOf(fanMode) < 0) fanMode = null
  return {
    present: data.present === true,
    writable: data.writable === true,
    fwVersion: typeof data.fwVersion === "string" && /^[A-Za-z0-9._-]{1,32}$/.test(data.fwVersion) ? data.fwVersion : "",
    fwDate: typeof data.fwDate === "string" && /^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}$/.test(data.fwDate) ? data.fwDate : "",
    shiftMode: shiftMode,
    shiftModes: shiftModes,
    fanMode: fanMode,
    fanModes: fanModes,
    coolerBoost: _bool(data.coolerBoost),
    webcam: _bool(data.webcam),
    webcamBlock: _bool(data.webcamBlock),
    fnKey: _side(data.fnKey),
    winKey: _side(data.winKey),
    superBattery: _bool(data.superBattery),
    chargeEnd: data.chargeEnd === undefined ? null : _int(data.chargeEnd, 0, 100),
    cpuTemp: data.cpuTemp === undefined ? null : _int(data.cpuTemp, 0, 150),
    cpuFan: data.cpuFan === undefined ? null : _int(data.cpuFan, 0, 150),
    gpuTemp: data.gpuTemp === undefined ? null : _int(data.gpuTemp, 0, 150),
    gpuFan: data.gpuFan === undefined ? null : _int(data.gpuFan, 0, 150)
  }
}

function titleCase(mode) {
  if (mode === "unspecified") return "Unspecified"
  if (!_mode(mode)) return "Unavailable"
  return mode.charAt(0).toUpperCase() + mode.slice(1)
}

function rows(state) {
  var out = []
  if (!state || state.present !== true) return out
  if (state.shiftModes && state.shiftModes.length) out.push({ id: "shift", n: state.shiftModes.length })
  if (state.fanModes && state.fanModes.length) out.push({ id: "fan", n: state.fanModes.length })
  if (state.coolerBoost === true || state.coolerBoost === false) out.push({ id: "boost", n: 1 })
  if (typeof state.chargeEnd === "number") out.push({ id: "charge", n: 1 })
  if (state.webcam === true || state.webcam === false) out.push({ id: "webcam", n: 1 })
  if (state.webcamBlock === true || state.webcamBlock === false) out.push({ id: "block", n: 1 })
  if (state.fnKey === "left" || state.fnKey === "right") out.push({ id: "keys", n: 1 })
  if (state.superBattery === true || state.superBattery === false) out.push({ id: "super", n: 1 })
  return out
}

function moveCursor(list, row, col, dx, dy) {
  if (!list || !list.length) return { row: 0, col: 0 }
  var r = row
  if (r < 0 || r >= list.length) r = 0
  var c = col
  if (dy !== 0) {
    r += dy > 0 ? 1 : -1
    if (r < 0) r = 0
    if (r >= list.length) r = list.length - 1
    c = Math.min(Math.max(0, c), list[r].n - 1)
  }
  if (dx !== 0 && list[r].n > 1) {
    c += dx > 0 ? 1 : -1
    if (c < 0) c = 0
    if (c >= list[r].n) c = list[r].n - 1
  }
  return { row: r, col: c }
}

function commandValue(key, value, state) {
  if (!state || state.writable !== true) return null
  if (key === "shift_mode") {
    var shift = _mode(value)
    if (!shift || !state.shiftModes || state.shiftModes.indexOf(shift) < 0) return null
    return shift
  }
  if (key === "fan_mode") {
    var fan = _mode(value)
    if (!fan || !state.fanModes || state.fanModes.indexOf(fan) < 0) return null
    return fan
  }
  if (key === "cooler_boost" || key === "webcam" || key === "webcam_block" || key === "super_battery") {
    if (value !== "on" && value !== "off") return null
    return value
  }
  if (key === "fn_key" || key === "win_key") {
    if (value !== "left" && value !== "right") return null
    return value
  }
  if (key === "charge_control_end_threshold") {
    var number = _int(typeof value === "number" ? value : Number(value), 10, 100)
    if (number === null || String(value).length > 3) return null
    return String(number)
  }
  return null
}

function fanUnit(state) {
  if (!state) return 0.12
  var cpu = typeof state.cpuFan === "number" ? state.cpuFan : 0
  var gpu = typeof state.gpuFan === "number" ? state.gpuFan : 0
  var peak = Math.max(cpu, gpu)
  if (peak <= 0) return state.coolerBoost === true ? 0.85 : 0.12
  return Math.max(0, Math.min(1, peak / 100))
}

function chargeProposal(end) {
  if (typeof end === "number" && end >= 50 && end <= 100) return end
  return 80
}

// Stores that this firmware accepts and reads back without the machine acting
// on them. Filled from a deliberate test. The panel does not write to discover this.
// Cooler boost is a real fan burst on 17G3EWS1.113, so it is not listed here.
var storedOnlyByFirmware = {
  "17G3EWS1.113": ["shift"]
}

function storedOnly(state, id) {
  if (!state || typeof state.fwVersion !== "string" || typeof id !== "string") return false
  var list = storedOnlyByFirmware[state.fwVersion]
  if (!list) return false
  return list.indexOf(id) >= 0
}

function storedOnlyNote(state) {
  var shift = storedOnly(state, "shift")
  var boost = storedOnly(state, "boost")
  if (shift && boost) return "Shift and cooler boost are stored on this machine. They do not change the fans or the power cap."
  if (shift) return "Shift is stored on this machine. It does not change the power cap."
  if (boost) return "Cooler boost is stored on this machine. It does not change the fans."
  return ""
}
