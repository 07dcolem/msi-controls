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
  property real pulse: 0
  readonly property real pulseWave: 0.5 + 0.5 * Math.sin(pulse)

  signal picked(string mode)

  Timer {
    interval: 32
    repeat: true
    running: root.visible && root.live
    onTriggered: root.pulse += 0.09
  }

  implicitHeight: Style.space(124)
  opacity: Math.max(0, Math.min(1, arrival))
  scale: 0.97 + 0.03 * Math.max(0, Math.min(1, arrival))
  transformOrigin: Item.Top

  Text {
    id: heading
    textFormat: Text.PlainText
    text: "Fan"
    color: root.foreground
    opacity: 0.7
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.capitalization: Font.AllUppercase
  }

  Row {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: heading.bottom
    anchors.topMargin: Style.space(8)
    height: Style.space(100)
    spacing: Style.space(8)

    Repeater {
      model: root.modes

      Rectangle {
        required property string modelData
        required property int index
        width: (parent.width - Style.space(8) * (root.modes.length - 1)) / Math.max(1, root.modes.length)
        height: parent.height
        radius: Style.cornerRadius
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, modelData === root.value ? 0.10 : 0.04)
        border.width: root.cursor === index || modelData === root.value ? 1 : 0
        border.color: modelData === root.value ? root.accent : root.foreground
        scale: modelData === root.value ? 1 : 0.96

        Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
        Behavior on color { ColorAnimation { duration: 220 } }
        Behavior on border.color { ColorAnimation { duration: 220 } }

        Rectangle {
          anchors.centerIn: parent
          width: parent.width * (modelData === root.value ? 0.92 + root.pulseWave * 0.1 : 0.8)
          height: width
          radius: width / 2
          color: "transparent"
          border.width: 1
          border.color: root.accent
          opacity: modelData === root.value ? 0.15 + root.pulseWave * 0.45 : 0
        }

        FanBlades {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
          anchors.topMargin: Style.space(8)
          width: Style.space(46)
          height: Style.space(46)
          speed: modelData === root.value ? 0.72 : 0.08
          boost: false
          lit: modelData === root.value
          bladeColor: root.foreground
          bladeCount: modelData === "advanced" ? 7 : modelData === "basic" ? 3 : 5
          live: root.live
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(8)
          textFormat: Text.PlainText
          text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: modelData === root.value
        }

        MouseArea {
          anchors.fill: parent
          onClicked: root.picked(modelData)
          cursorShape: Qt.PointingHandCursor
        }
      }
    }
  }
}
