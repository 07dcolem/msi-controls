import QtQuick
import qs.Commons

Item {
  id: root

  property string fnSide: "right"
  property bool marked: false
  property color foreground: "#c6b395"
  property color accent: "#d7a15a"
  property string fontFamily: Style.font.family
  property real arrival: 1
  property real nudge: 0

  signal swap()

  readonly property bool fnRight: fnSide === "right"

  implicitWidth: Style.space(150)
  implicitHeight: Style.space(78)
  opacity: Math.max(0, Math.min(1, arrival))
  scale: 0.97 + 0.03 * Math.max(0, Math.min(1, arrival))
  transformOrigin: Item.Top

  Text {
    id: heading
    textFormat: Text.PlainText
    text: "Fn key"
    color: root.foreground
    opacity: 0.7
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.capitalization: Font.AllUppercase
  }

  Item {
    id: deck
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: heading.bottom
    anchors.topMargin: Style.space(6)
    height: Style.space(44)

    readonly property real keyWidth: Style.space(58)
    readonly property real travel: Math.max(0, width - keyWidth)

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: Style.space(10)
      radius: Style.space(4)
      color: Qt.rgba(0, 0, 0, 0.28)
    }

    Rectangle {
      id: fnKey
      width: deck.keyWidth
      height: parent.height - Style.space(4)
      radius: Style.space(6)
      x: root.fnRight ? deck.travel : 0
      y: root.nudge
      color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
      border.width: root.marked ? 2 : 1
      border.color: root.marked ? root.foreground : root.accent

      Behavior on x {
        NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.35 }
      }

      Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: Style.space(5)
        radius: Style.space(5)
        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
      }

      Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Style.space(2)
        textFormat: Text.PlainText
        text: "Fn"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }
    }

    Rectangle {
      width: deck.keyWidth
      height: parent.height - Style.space(4)
      radius: Style.space(6)
      x: root.fnRight ? 0 : deck.travel
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
      border.width: 1
      border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.28)

      Behavior on x {
        NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.35 }
      }

      Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: Style.space(5)
        radius: Style.space(5)
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14)
      }

      Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Style.space(2)
        textFormat: Text.PlainText
        text: "Win"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
      }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: {
        nudgeAnim.restart()
        root.swap()
      }
      cursorShape: Qt.PointingHandCursor
    }
  }

  SequentialAnimation {
    id: nudgeAnim
    NumberAnimation { target: root; property: "nudge"; to: -3; duration: 90; easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "nudge"; to: 0; duration: 180; easing.type: Easing.OutCubic }
  }
}
