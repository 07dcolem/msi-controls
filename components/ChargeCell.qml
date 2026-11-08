import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property int committed: 0
  property int draft: 80
  property bool dirty: false
  property bool marked: false
  property color foreground: "#c6b395"
  property color accent: "#d7a15a"
  property string fontFamily: Style.font.family
  property var bar: null
  property real arrival: 1
  property bool live: true
  property real shimmer: 0

  signal preview(int value)
  signal apply(int value)

  readonly property real shownFill: committed > 0 ? committed / 100 : 1
  readonly property bool unlimited: committed === 0

  implicitHeight: body.implicitHeight
  opacity: Math.max(0, Math.min(1, arrival))
  scale: 0.97 + 0.03 * Math.max(0, Math.min(1, arrival))
  transformOrigin: Item.Top

  Timer {
    interval: 32
    repeat: true
    running: root.visible && root.live && root.unlimited
    onTriggered: root.shimmer = (root.shimmer + 0.04) % (Math.PI * 2)
  }

  Column {
    id: body
    width: parent.width
    spacing: Style.space(6)

    Text {
      textFormat: Text.PlainText
      text: "Charge limit"
      color: root.foreground
      opacity: 0.7
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.capitalization: Font.AllUppercase
    }

    Item {
      width: parent.width
      height: Style.space(36)

      Item {
        id: cell
        width: Style.space(78)
        height: parent.height

        Rectangle {
          anchors.fill: parent
          anchors.rightMargin: Style.space(6)
          radius: Style.space(5)
          color: "transparent"
          border.width: root.marked ? 2 : 1
          border.color: root.foreground
        }

        Rectangle {
          width: Style.space(4)
          height: Style.space(12)
          radius: 1
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          color: root.foreground
        }

        Item {
          id: electrolyte
          anchors.fill: parent
          anchors.leftMargin: Style.space(4)
          anchors.rightMargin: Style.space(10)
          anchors.topMargin: Style.space(4)
          anchors.bottomMargin: Style.space(4)
          clip: true

          Row {
            anchors.fill: parent
            spacing: 2

            Repeater {
              model: 8
              Rectangle {
                required property int index
                width: Math.max(1, (electrolyte.width - 14) / 8)
                height: electrolyte.height
                radius: 2
                color: root.unlimited ? root.foreground : root.accent
                opacity: (index + 0.65) / 8 <= root.shownFill
                  ? (root.unlimited ? 0.34 + 0.28 * (0.5 + 0.5 * Math.sin(root.shimmer + index * 0.7)) : 0.92)
                  : 0.12
              }
            }
          }

          Rectangle {
            visible: root.unlimited
            width: electrolyte.width * 0.28
            height: electrolyte.height
            y: 0
            x: -width + ((root.shimmer % (Math.PI * 2)) / (Math.PI * 2)) * (electrolyte.width + width)
            color: root.foreground
            opacity: 0.28
          }
        }
      }

      Text {
        anchors.left: cell.right
        anchors.leftMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: root.unlimited ? "No limit" : String(root.committed) + "%"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      Button {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.dirty
        text: "Apply"
        foreground: root.foreground
        accent: root.accent
        fontFamily: root.fontFamily
        bordered: true
        onClicked: root.apply(root.draft)
      }
    }

    Text {
      width: parent.width
      visible: root.committed === 0
      textFormat: Text.PlainText
      text: "A limit stays on. This driver cannot clear it."
      color: root.foreground
      opacity: 0.5
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.NoWrap
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      visible: root.unlimited || root.dirty
      textFormat: Text.PlainText
      text: "Draft " + root.draft + "%"
      color: root.foreground
      opacity: 0.7
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }

    PanelSlider {
      width: parent.width
      bar: root.bar
      minimum: 50
      maximum: 100
      step: 10
      integer: true
      value: root.draft
      tickCount: 6
      onReleased: function(next) { root.preview(Math.round(next)) }
    }
  }
}
