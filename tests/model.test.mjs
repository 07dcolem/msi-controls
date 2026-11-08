import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"
import vm from "node:vm"

const source = readFileSync(new URL("../Model.js", import.meta.url), "utf8").replace(/^\.pragma library\s*/, "")
const context = vm.createContext({})
vm.runInContext(source, context)

const sample = {
  present: true,
  writable: true,
  fwVersion: "17G3EWS1.113",
  fwDate: "2021-02-03T11:10:21",
  shiftMode: "unspecified",
  shiftModes: ["turbo", "eco", "comfort", "sport"],
  fanMode: "auto",
  fanModes: ["auto", "basic", "advanced"],
  coolerBoost: false,
  webcam: true,
  webcamBlock: false,
  fnKey: "right",
  winKey: "left",
  superBattery: null,
  chargeEnd: 0,
  cpuTemp: 59,
  cpuFan: 50,
  gpuTemp: 53,
  gpuFan: 48
}

test("plain text drops markup and controls", () => {
  assert.equal(context.plain('<img src="http://127.0.0.1/x.png">', 80), 'img src="http://127.0.0.1/x.png"')
  assert.equal(context.plain("a&b<c>\u0001", 20), "abc")
  assert.equal(context.plain("abcdef", 3), "abc")
})

test("parse keeps a supported laptop snapshot", () => {
  const parsed = context.parseStatus(JSON.stringify(sample))
  assert.equal(parsed.present, true)
  assert.equal(parsed.shiftMode, "unspecified")
  assert.equal(JSON.stringify(parsed.fanModes), JSON.stringify(["auto", "basic", "advanced"]))
  assert.equal(parsed.chargeEnd, 0)
  assert.equal(parsed.superBattery, null)
  assert.equal(context.titleCase(parsed.shiftMode), "Unspecified")
  assert.equal(context.titleCase("eco"), "Eco")
})

test("parse rejects markup, unknown shapes, and oversized documents", () => {
  const bad = Object.assign({}, sample, { shiftMode: "<b>eco</b>", shiftModes: ["eco"] })
  assert.equal(context.parseStatus(JSON.stringify(bad)).shiftMode, null)
  assert.equal(context.parseStatus("{"), null)
  assert.equal(context.parseStatus("[]"), null)
  assert.equal(context.parseStatus("x".repeat(5000)), null)
  const modes = Object.assign({}, sample, { fanModes: ["auto", "auto"] })
  assert.equal(JSON.stringify(context.parseStatus(JSON.stringify(modes)).fanModes), "[]")
})

test("commands stay on the live allowlist", () => {
  const state = context.parseStatus(JSON.stringify(sample))
  assert.equal(context.commandValue("fan_mode", "auto", state), "auto")
  assert.equal(context.commandValue("fan_mode", "silent", state), null)
  assert.equal(context.commandValue("shift_mode", "unspecified", state), null)
  assert.equal(context.commandValue("charge_control_end_threshold", "0", state), null)
  assert.equal(context.commandValue("charge_control_end_threshold", "80", state), "80")
  assert.equal(context.commandValue("charge_control_end_threshold", "101", state), null)
  assert.equal(context.commandValue("cooler_boost", "on", state), "on")
  assert.equal(context.commandValue("fn_key", "left", state), "left")
  assert.equal(context.commandValue("shift_mode", "eco", Object.assign({}, state, { writable: false })), null)
})

test("cursor walks only the exposed rows", () => {
  const state = context.parseStatus(JSON.stringify(sample))
  const list = context.rows(state)
  assert.equal(JSON.stringify(list.map((row) => row.id)), JSON.stringify(["shift", "fan", "boost", "charge", "webcam", "block", "keys"]))
  const moved = context.moveCursor(list, 0, 0, 1, 0)
  assert.equal(moved.row, 0)
  assert.equal(moved.col, 1)
  const down = context.moveCursor(list, 0, 3, 0, 1)
  assert.equal(down.row, 1)
  assert.equal(context.rows({ present: false }).length, 0)
})

test("fan motion uses the higher fan and stays inside 0..1", () => {
  const state = context.parseStatus(JSON.stringify(sample))
  assert.equal(context.fanUnit(state), 0.5)
  assert.equal(context.fanUnit({ cpuFan: 140, gpuFan: 10, coolerBoost: false }), 1)
  assert.equal(context.chargeProposal(0), 80)
  assert.equal(context.chargeProposal(70), 70)
})

test("this firmware marks shift stored-only and leaves boost live", () => {
  const state = context.parseStatus(JSON.stringify(sample))
  assert.equal(context.storedOnly(state, "shift"), true)
  assert.equal(context.storedOnly(state, "boost"), false)
  assert.equal(context.storedOnly(state, "fan"), false)
  assert.equal(context.storedOnlyNote(state), "Shift is stored on this machine. It does not change the power cap.")
  const other = Object.assign({}, state, { fwVersion: "17G3EMS1.113" })
  assert.equal(context.storedOnly(other, "shift"), false)
  assert.equal(context.storedOnlyNote(other), "")
  assert.equal(context.storedOnly(null, "shift"), false)
})
