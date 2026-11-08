import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "components"
import "Model.js" as Model

Panel {
  id: root

  moduleName: "io.github.07dcolem.msi-controls"
  ipcTarget: "io.github.07dcolem.msi-controls"

  property var stateData: ({ present: false, writable: false, shiftModes: [], fanModes: [] })
  property string notice: ""
  property bool holdNotice: false
  property int cursorRow: 0
  property int cursorCol: 0
  property bool cursorActive: false
  property real reveal: 0
  property int chargeDraft: 80
  property bool chargeDraftDirty: false
  property int generation: 0

  readonly property color ink: bar ? bar.foreground : Commons.Color.foreground
  readonly property color wash: Commons.Color.accent
  readonly property string face: bar && bar.fontFamily ? bar.fontFamily : Style.font.family
  readonly property var cursorRows: Model.rows(stateData)
  readonly property string cursorId: cursorRows.length ? cursorRows[Math.max(0, Math.min(cursorRows.length - 1, cursorRow))].id : ""
  readonly property real fanAmount: Model.fanUnit(stateData)
  readonly property bool barFanSpin: setting("barFanSpin", true) !== false

  function toggleBarFan() {
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry.barFanSpin = !root.barFanSpin
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function sectionIn(index) {
    return Math.max(0, Math.min(1, reveal - index * 0.72))
  }

  function helperPath() {
    var value = String(Qt.resolvedUrl("bin/msi-ec.py"))
    if (value.indexOf("file://") === 0) value = decodeURIComponent(value.substring(7))
    return value
  }

  function rowIndex(id) {
    for (var i = 0; i < cursorRows.length; i++) if (cursorRows[i].id === id) return i
    return -1
  }

  function installStatus(parsed) {
    if (!parsed) {
      if (!holdNotice) notice = "Status was unreadable"
      return
    }
    stateData = parsed
    if (!chargeDraftDirty) chargeDraft = Model.chargeProposal(parsed.chargeEnd)
    if (!holdNotice) {
      if (!parsed.present) notice = "msi-ec is not loaded"
      else if (!parsed.writable) notice = "Read only until the seat grant is installed"
      else notice = ""
    }
  }

  function begin(op, key, value) {
    if (proc.running) {
      proc.queuedOp = op
      proc.queuedKey = key || ""
      proc.queuedValue = value || ""
      return
    }
    generation += 1
    proc.gen = generation
    proc.buf = ""
    proc.op = op
    proc.opKey = key || ""
    proc.command = op === "set"
      ? ["/usr/bin/python3", "-I", "-S", helperPath(), "set", key, value]
      : ["/usr/bin/python3", "-I", "-S", helperPath(), "status"]
    proc.running = true
    deadline.restart()
  }

  function refresh() { begin("status", "", "") }

  function commit(key, value) {
    var safe = Model.commandValue(key, value, stateData)
    if (!safe) {
      notice = stateData.writable ? "That value was rejected" : "Read only until the seat grant is installed"
      holdNotice = true
      noticeTimer.restart()
      return
    }
    begin("set", key, safe)
  }

  function pump() {
    if (proc.running) return
    if (proc.queuedOp === "") return
    var op = proc.queuedOp
    var key = proc.queuedKey
    var value = proc.queuedValue
    proc.queuedOp = ""
    proc.queuedKey = ""
    proc.queuedValue = ""
    if (op === "set") commit(key, value)
    else refresh()
  }

  function moveCursor(dx, dy) {
    if (!cursorRows.length) return
    if (cursorId === "charge" && dx !== 0) {
      var next = Math.max(50, Math.min(100, chargeDraft + (dx > 0 ? 10 : -10)))
      chargeDraft = next
      chargeDraftDirty = stateData.chargeEnd === 0 || next !== stateData.chargeEnd
      return
    }
    var moved = Model.moveCursor(cursorRows, cursorRow, cursorCol, dx, dy)
    cursorRow = moved.row
    cursorCol = moved.col
  }

  function activateCursor() {
    if (!cursorActive || !cursorRows.length) return
    var row = cursorRows[Math.max(0, Math.min(cursorRows.length - 1, cursorRow))]
    if (row.id === "shift") commit("shift_mode", stateData.shiftModes[cursorCol])
    else if (row.id === "fan") commit("fan_mode", stateData.fanModes[cursorCol])
    else if (row.id === "boost") commit("cooler_boost", stateData.coolerBoost ? "off" : "on")
    else if (row.id === "charge") commit("charge_control_end_threshold", String(chargeDraft))
    else if (row.id === "webcam") commit("webcam", stateData.webcam ? "off" : "on")
    else if (row.id === "block") commit("webcam_block", stateData.webcamBlock ? "off" : "on")
    else if (row.id === "keys") commit("fn_key", stateData.fnKey === "left" ? "right" : "left")
    else if (row.id === "super") commit("super_battery", stateData.superBattery ? "off" : "on")
  }

  onOpenedChanged: {
    if (!opened) return
    reveal = 0
    revealAnim.restart()
    cursorActive = false
    refresh()
  }

  Component.onCompleted: refresh()
  Component.onDestruction: if (proc.running) proc.signal(15)

  Timer {
    interval: root.opened ? 1200 : 3000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Timer {
    id: deadline
    interval: 3000
    onTriggered: if (proc.running) proc.signal(15)
  }

  Timer {
    id: killTimer
    interval: 400
    onTriggered: if (proc.running) proc.signal(9)
  }

  Timer {
    id: noticeTimer
    interval: 2400
    onTriggered: root.holdNotice = false
  }

  NumberAnimation {
    id: revealAnim
    target: root
    property: "reveal"
    from: 0
    to: 6
    duration: 1100
    easing.type: Easing.OutCubic
  }

  Process {
    id: proc
    property int gen: 0
    property string buf: ""
    property string op: ""
    property string opKey: ""
    property string queuedOp: ""
    property string queuedKey: ""
    property string queuedValue: ""

    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        proc.buf += chunk
        if (proc.buf.length > 4096) {
          proc.buf = ""
          proc.signal(15)
          killTimer.restart()
        }
      }
    }

    onStarted: deadline.restart()

    onExited: function(code) {
      deadline.stop()
      var text = proc.buf
      var op = proc.op
      proc.buf = ""
      if (proc.gen !== root.generation) {
        root.pump()
        return
      }
      if (code === 0) {
        root.installStatus(Model.parseStatus(text))
        if (op === "set" && proc.opKey === "charge_control_end_threshold") root.chargeDraftDirty = false
      } else if (op === "set") {
        root.notice = code === 3 ? "That value was rejected" : "The embedded controller did not accept the change"
        root.holdNotice = true
        noticeTimer.restart()
      }
      root.pump()
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    active: root.opened
    tooltipText: "MSI controls"
    iconComponent: fanGlyph
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.toggleBarFan()
      else if (mouseButton === Qt.LeftButton) root.toggle()
    }
  }

  Component {
    id: fanGlyph
    Item {
      FanBlades {
        anchors.fill: parent
        anchors.margins: 1
        speed: root.fanAmount
        boost: root.stateData.coolerBoost === true
        lit: root.opened && root.barFanSpin
        bladeColor: root.ink
        live: root.barFanSpin
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(500))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) {
          root.cursorActive = true
          return
        }
        root.moveCursor(dx, dy)
      }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(10)

        Column {
          id: titleBlock
          width: parent.width
          opacity: root.sectionIn(0)
          scale: 0.96 + 0.04 * root.sectionIn(0)
          transformOrigin: Item.Left
          spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: "MSI"
              color: root.ink
              opacity: 0.55
              font.family: root.face
              font.pixelSize: Style.font.caption
              font.bold: true
              font.capitalization: Font.AllUppercase
            }

            Text {
              id: modeTitle
              width: parent.width
              textFormat: Text.PlainText
              text: Model.titleCase(root.stateData.shiftMode)
              color: root.ink
              font.family: root.face
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: Model.plain((root.stateData.fwVersion || "") + (root.stateData.fwDate ? "  " + root.stateData.fwDate : ""), 48)
              color: root.ink
              opacity: 0.55
              font.family: root.face
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              visible: text !== ""
            }
        }

        Row {
          width: parent.width
          spacing: Style.space(8)
          opacity: root.sectionIn(1)

          ArcMeter {
            width: (parent.width - Style.space(8)) / 2
            label: "CPU"
            unit: "°C"
            value: root.stateData.cpuTemp === null || root.stateData.cpuTemp === undefined ? 0 : root.stateData.cpuTemp
            fan: root.stateData.cpuFan === null || root.stateData.cpuFan === undefined ? -1 : root.stateData.cpuFan
            maximum: 100
            foreground: root.ink
            accent: root.wash
            fontFamily: root.face
            live: root.opened
          }

          ArcMeter {
            width: (parent.width - Style.space(8)) / 2
            label: "GPU"
            unit: "°C"
            value: root.stateData.gpuTemp === null || root.stateData.gpuTemp === undefined ? 0 : root.stateData.gpuTemp
            fan: root.stateData.gpuFan === null || root.stateData.gpuFan === undefined ? -1 : root.stateData.gpuFan
            maximum: 100
            foreground: root.ink
            accent: root.wash
            fontFamily: root.face
            live: root.opened
          }
        }

        Text {
          width: parent.width
          visible: Model.storedOnlyNote(root.stateData) !== ""
          wrapMode: Text.WordWrap
          textFormat: Text.PlainText
          text: Model.storedOnlyNote(root.stateData)
          color: root.ink
          opacity: 0.72
          font.family: root.face
          font.pixelSize: Style.font.caption
        }

        ShiftStage {
          width: parent.width
          visible: root.stateData.shiftModes && root.stateData.shiftModes.length > 0
          modes: root.stateData.shiftModes || []
          value: root.stateData.shiftMode || ""
          note: Model.storedOnly(root.stateData, "shift") ? "Stored only" : ""
          cursor: root.cursorActive && root.cursorId === "shift" ? root.cursorCol : -1
          foreground: root.ink
          accent: root.wash
          fontFamily: root.face
          arrival: root.sectionIn(2)
          live: root.opened
          onPicked: function(mode) {
            root.cursorActive = true
            root.cursorRow = root.rowIndex("shift")
            root.commit("shift_mode", mode)
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(12)
          visible: (root.stateData.fanModes && root.stateData.fanModes.length)
            || root.stateData.coolerBoost === true || root.stateData.coolerBoost === false

          FanModes {
            width: parent.width - (boost.visible ? boost.implicitWidth + parent.spacing : 0)
            visible: root.stateData.fanModes && root.stateData.fanModes.length > 0
            modes: root.stateData.fanModes || []
            value: root.stateData.fanMode || ""
            cursor: root.cursorActive && root.cursorId === "fan" ? root.cursorCol : -1
            foreground: root.ink
            accent: root.wash
            fontFamily: root.face
            arrival: root.sectionIn(3)
            live: root.opened
            onPicked: function(mode) {
              root.cursorActive = true
              root.cursorRow = root.rowIndex("fan")
              root.commit("fan_mode", mode)
            }
          }

          BoostControl {
            id: boost
            visible: root.stateData.coolerBoost === true || root.stateData.coolerBoost === false
            on: root.stateData.coolerBoost === true
            note: Model.storedOnly(root.stateData, "boost") ? "Stored only" : ""
            marked: root.cursorActive && root.cursorId === "boost"
            foreground: root.ink
            accent: root.wash
            fontFamily: root.face
            arrival: root.sectionIn(3)
            live: root.opened
            onToggle: {
              root.cursorActive = true
              root.cursorRow = root.rowIndex("boost")
              root.commit("cooler_boost", root.stateData.coolerBoost ? "off" : "on")
            }
          }
        }

        ChargeCell {
          width: parent.width
          visible: typeof root.stateData.chargeEnd === "number"
          committed: typeof root.stateData.chargeEnd === "number" ? root.stateData.chargeEnd : 0
          draft: root.chargeDraft
          dirty: root.chargeDraftDirty
          marked: root.cursorActive && root.cursorId === "charge"
          foreground: root.ink
          accent: root.wash
          fontFamily: root.face
          bar: root.bar
          arrival: root.sectionIn(4)
          live: root.opened
          onPreview: function(value) {
            root.cursorActive = true
            root.cursorRow = root.rowIndex("charge")
            root.chargeDraft = value
            root.chargeDraftDirty = value !== root.stateData.chargeEnd
          }
          onApply: function(value) {
            root.cursorRow = root.rowIndex("charge")
            root.commit("charge_control_end_threshold", String(value))
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(12)
          visible: root.stateData.webcam === true || root.stateData.webcam === false
            || root.stateData.webcamBlock === true || root.stateData.webcamBlock === false
            || root.stateData.fnKey === "left" || root.stateData.fnKey === "right"

          CameraRow {
            width: parent.width - (keys.visible ? keys.implicitWidth + parent.spacing : 0)
            visible: root.stateData.webcam === true || root.stateData.webcam === false
              || root.stateData.webcamBlock === true || root.stateData.webcamBlock === false
            cameraOn: root.stateData.webcam !== false
            blocked: root.stateData.webcamBlock === true
            showCamera: root.stateData.webcam === true || root.stateData.webcam === false
            showBlock: root.stateData.webcamBlock === true || root.stateData.webcamBlock === false
            markCamera: root.cursorActive && root.cursorId === "webcam"
            markBlock: root.cursorActive && root.cursorId === "block"
            foreground: root.ink
            accent: root.wash
            fontFamily: root.face
            arrival: root.sectionIn(5)
            live: root.opened
            onToggleCamera: {
              root.cursorRow = root.rowIndex("webcam")
              root.commit("webcam", root.stateData.webcam ? "off" : "on")
            }
            onToggleBlock: {
              root.cursorRow = root.rowIndex("block")
              root.commit("webcam_block", root.stateData.webcamBlock ? "off" : "on")
            }
          }

          KeySwap {
            id: keys
            visible: root.stateData.fnKey === "left" || root.stateData.fnKey === "right"
            fnSide: root.stateData.fnKey || "right"
            marked: root.cursorActive && root.cursorId === "keys"
            foreground: root.ink
            accent: root.wash
            fontFamily: root.face
            arrival: root.sectionIn(5)
            onSwap: {
              root.cursorRow = root.rowIndex("keys")
              root.commit("fn_key", root.stateData.fnKey === "left" ? "right" : "left")
            }
          }
        }

        Toggle {
          width: parent.width
          visible: root.stateData.superBattery === true || root.stateData.superBattery === false
          label: "Super battery"
          description: root.stateData.superBattery ? "Saving" : "Off"
          checked: root.stateData.superBattery === true
          hasCursor: root.cursorActive && root.cursorId === "super"
          foreground: root.ink
          accent: root.wash
          fontFamily: root.face
          opacity: root.sectionIn(5)
          onClicked: root.commit("super_battery", root.stateData.superBattery ? "off" : "on")
        }

        Text {
          width: parent.width
          visible: root.notice !== ""
          textFormat: Text.PlainText
          text: Model.plain(root.notice, 80)
          color: root.ink
          opacity: 0.7
          font.family: root.face
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }
}
