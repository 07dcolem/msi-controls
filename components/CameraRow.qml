import QtQuick
import qs.Commons

Item {
  id: root

  property bool cameraOn: true
  property bool blocked: false
  property bool markCamera: false
  property bool markBlock: false
  property bool showCamera: true
  property bool showBlock: true
  property color foreground: "#c6b395"
  property color accent: "#d7a15a"
  property string fontFamily: Style.font.family
  property real arrival: 1
  property bool live: true
  property real glint: 0

  signal toggleCamera()
  signal toggleBlock()

  readonly property bool shut: !cameraOn || blocked
  property real petal: shut ? 1 : 0

  implicitHeight: Style.space(78)
  opacity: Math.max(0, Math.min(1, arrival))
  scale: 0.97 + 0.03 * Math.max(0, Math.min(1, arrival))
  transformOrigin: Item.Top

  Behavior on petal { NumberAnimation { duration: 520; easing.type: Easing.InOutCubic } }

  Timer {
    interval: 32
    repeat: true
    running: root.visible && root.live && !root.shut
    onTriggered: root.glint = (root.glint + 0.045) % (Math.PI * 2)
  }

  Text {
    id: heading
    textFormat: Text.PlainText
    text: "Camera"
    color: root.foreground
    opacity: 0.7
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.capitalization: Font.AllUppercase
  }

  Item {
    id: iris
    anchors.left: parent.left
    anchors.top: heading.bottom
    anchors.topMargin: Style.space(6)
    width: Style.space(52)
    height: Style.space(52)

    Repeater {
      model: 8
      Item {
        anchors.fill: parent
        rotation: index * 45 + root.petal * 36

        Rectangle {
          width: Math.max(2, parent.width * 0.2)
          height: parent.height * (0.12 + root.petal * 0.42)
          radius: width
          color: root.foreground
          opacity: 0.78
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.verticalCenter
          anchors.bottomMargin: parent.width * (0.04 - root.petal * 0.08)
        }
      }
    }

    Rectangle {
      anchors.centerIn: parent
      width: parent.width * (0.34 - root.petal * 0.2)
      height: width
      radius: width / 2
      color: root.blocked ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
      border.width: 1
      border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.45)
      scale: 1 - root.petal * 0.15

      Rectangle {
        width: parent.width * 0.22
        height: width
        radius: width / 2
        color: root.foreground
        opacity: root.shut ? 0 : 0.35 + 0.45 * (0.5 + 0.5 * Math.sin(root.glint))
        x: parent.width * (0.2 + 0.35 * (0.5 + 0.5 * Math.sin(root.glint)))
        y: parent.height * (0.16 + 0.12 * (0.5 + 0.5 * Math.cos(root.glint)))
      }
    }

    Rectangle {
      anchors.centerIn: parent
      width: parent.width * (0.1 + root.petal * 0.5)
      height: width
      radius: width / 2
      color: root.blocked ? root.accent : root.foreground
      opacity: root.petal * 0.72
    }
  }

  Column {
    anchors.left: iris.right
    anchors.leftMargin: Style.space(10)
    anchors.right: parent.right
    anchors.verticalCenter: iris.verticalCenter
    spacing: Style.space(4)

    Rectangle {
      visible: root.showCamera
      width: parent.width
      height: Style.space(24)
      radius: Style.cornerRadius
      color: root.markCamera ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08) : "transparent"
      border.width: root.markCamera ? 1 : 0
      border.color: root.foreground

      Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Style.space(8)
        textFormat: Text.PlainText
        text: root.cameraOn ? "Camera on" : "Camera off"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      MouseArea {
        anchors.fill: parent
        onClicked: root.toggleCamera()
        cursorShape: Qt.PointingHandCursor
      }
    }

    Rectangle {
      visible: root.showBlock
      width: parent.width
      height: Style.space(24)
      radius: Style.cornerRadius
      color: root.markBlock ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08) : "transparent"
      border.width: root.markBlock ? 1 : 0
      border.color: root.foreground

      Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Style.space(8)
        textFormat: Text.PlainText
        text: root.blocked ? "Block on" : "Block off"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      MouseArea {
        anchors.fill: parent
        onClicked: root.toggleBlock()
        cursorShape: Qt.PointingHandCursor
      }
    }
  }
}
