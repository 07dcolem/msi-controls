import QtQuick
import qs.Commons

Item {
  id: root

  property bool on: false
  property bool marked: false
  property color foreground: "#c6b395"
  property color accent: "#d7a15a"
  property string fontFamily: Style.font.family
  property real arrival: 1
  property bool live: true
  property real burst: 0
  property string note: ""

  signal toggle()

  implicitWidth: Style.space(132)
  implicitHeight: Style.space(124)
  clip: true
  opacity: Math.max(0, Math.min(1, arrival))
  scale: 0.97 + 0.03 * Math.max(0, Math.min(1, arrival))
  transformOrigin: Item.Top

  onOnChanged: if (on) burstAnim.restart()

  NumberAnimation {
    id: burstAnim
    target: root
    property: "burst"
    from: 0
    to: 1
    duration: 760
    easing.type: Easing.OutCubic
  }

  Text {
    id: heading
    anchors.horizontalCenter: parent.horizontalCenter
    textFormat: Text.PlainText
    text: "Boost"
    color: root.foreground
    opacity: 0.7
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.capitalization: Font.AllUppercase
  }

  Text {
    width: parent.width
    horizontalAlignment: Text.AlignHCenter
    anchors.top: heading.bottom
    visible: root.note !== ""
    textFormat: Text.PlainText
    text: root.note
    elide: Text.ElideRight
    color: root.accent
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
  }

  Item {
    id: stage
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    width: Style.space(86)
    height: Style.space(86)

    Item {
      anchors.centerIn: parent
      width: Style.space(78)
      height: width
      visible: root.on

      RotationAnimation on rotation {
        running: root.on && root.visible && root.live
        from: 0
        to: 360
        duration: 2200
        loops: Animation.Infinite
      }

      Repeater {
        model: 10
        Item {
          anchors.fill: parent
          rotation: index * 36

          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: 2
            height: Style.space(6)
            radius: 1
            color: root.accent
            opacity: 0.75
          }
        }
      }
    }

    Repeater {
      model: 3
      Item {
        id: ring
        required property int index
        anchors.centerIn: parent
        width: Style.space(52)
        height: width
        property real wave: 0

        SequentialAnimation {
          running: root.on && root.visible && root.live
          loops: Animation.Infinite
          PauseAnimation { duration: ring.index * 260 }
          NumberAnimation {
            target: ring
            property: "wave"
            from: 0
            to: 1
            duration: 1280
            easing.type: Easing.OutCubic
          }
        }

        Rectangle {
          anchors.centerIn: parent
          width: ring.width * (root.on ? 1 + ring.wave * 0.9 : 0.7)
          height: width
          radius: width / 2
          color: "transparent"
          border.width: 1
          border.color: root.accent
          opacity: root.on ? 0.62 * (1 - ring.wave) : 0
        }
      }
    }

    Rectangle {
      anchors.centerIn: parent
      width: Style.space(52) * (1 + root.burst * 1.35)
      height: width
      radius: width / 2
      color: "transparent"
      border.width: 2
      border.color: root.accent
      opacity: (1 - root.burst) * (root.on ? 0.8 : 0)
    }

    Rectangle {
      id: core
      anchors.centerIn: parent
      width: Style.space(52)
      height: width
      radius: width / 2
      color: root.on ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
      border.width: root.marked ? 2 : 1
      border.color: root.marked ? root.foreground : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.35)
      scale: root.on ? 1.04 : 1

      Behavior on color { ColorAnimation { duration: 240 } }
      Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }

      Text {
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: root.on ? "On" : "Off"
        color: root.on ? "#1c120d" : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }

      MouseArea {
        anchors.fill: parent
        onClicked: root.toggle()
        cursorShape: Qt.PointingHandCursor
      }
    }
  }
}
