import QtQuick
import qs.Commons

Item {
  id: root

  property var modes: []
  property string value: ""
  property int cursor: -1
  property color foreground: "#c6b395"
  property color accent: "#d7a15a"
  property string fontFamily: Style.font.family
  property real arrival: 1
  property bool live: true
  property string note: ""

  signal picked(string mode)

  readonly property int count: modes ? modes.length : 0
  readonly property int selected: {
    if (!modes) return -1
    for (var i = 0; i < modes.length; i++) if (modes[i] === value) return i
    return -1
  }
  readonly property real intensity: value === "turbo" ? 0.22 : value === "sport" ? 0.14 : value === "eco" ? 0.08 : 0.05
  readonly property real tempo: value === "turbo" ? 0.14 : value === "sport" ? 0.07 : value === "eco" ? 0.025 : 0.04
  readonly property real scan: breath

  property real phase: 0
  readonly property real breath: 0.5 + 0.5 * Math.sin(phase)

  implicitHeight: Style.space(92)
  clip: true
  opacity: Math.max(0, Math.min(1, arrival))
  scale: 0.97 + 0.03 * Math.max(0, Math.min(1, arrival))
  transformOrigin: Item.Top

  Timer {
    interval: 32
    repeat: true
    running: root.visible && root.live && root.count > 0
    onTriggered: root.phase += root.tempo
  }

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
    border.width: 1
    border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
  }

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: root.accent
    opacity: root.intensity * (0.35 + root.breath)
  }

  Rectangle {
    width: parent.width * 0.22
    height: parent.height
    x: -width + root.scan * (parent.width + width)
    color: root.accent
    opacity: 0.16
  }

  Text {
    id: heading
    x: Style.space(12)
    y: Style.space(8)
    textFormat: Text.PlainText
    text: "Shift"
    color: root.foreground
    opacity: 0.7
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.capitalization: Font.AllUppercase
  }

  Text {
    anchors.left: heading.right
    anchors.leftMargin: Style.space(8)
    anchors.right: parent.right
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: heading.verticalCenter
    visible: root.note !== ""
    textFormat: Text.PlainText
    text: root.note
    color: root.accent
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    elide: Text.ElideRight
    horizontalAlignment: Text.AlignRight
  }

  Item {
    id: lane
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: Style.space(8)
    anchors.rightMargin: Style.space(8)
    anchors.bottomMargin: Style.space(8)
    height: Style.space(36)

    readonly property real chipWidth: count > 0
      ? (width - Style.space(6) * (count - 1)) / count
      : 0

    Rectangle {
      visible: root.selected >= 0
      y: 0
      height: parent.height
      width: lane.chipWidth
      radius: Style.cornerRadius
      color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.42)
      x: root.selected * (lane.chipWidth + Style.space(6))
      Behavior on x { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
      Behavior on color { ColorAnimation { duration: 220 } }
    }

    Repeater {
      model: root.modes

      Rectangle {
        required property string modelData
        required property int index
        width: lane.chipWidth
        height: lane.height
        x: index * (lane.chipWidth + Style.space(6))
        radius: Style.cornerRadius
        color: "transparent"
        border.width: root.cursor === index ? 1 : 0
        border.color: root.foreground
        clip: true

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(3)
          width: parent.width * 0.28
          radius: width / 2
          color: root.accent
          opacity: modelData === root.value ? 0.85 : 0.28
          height: parent.height * (0.16 + (modelData === root.value ? 0.62 : 0.28) * (0.45 + 0.55 * (0.5 + 0.5 * Math.sin(root.phase * (1 + index * 0.45) + index))))
        }

        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: modelData === root.value
          opacity: modelData === root.value ? 1 : 0.72
          Behavior on opacity { NumberAnimation { duration: 180 } }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.picked(modelData)
          cursorShape: Qt.PointingHandCursor
        }
      }
    }
  }
}
