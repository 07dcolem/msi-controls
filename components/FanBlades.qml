import QtQuick

Item {
  id: root

  property real speed: 0.15
  property bool boost: false
  property bool lit: false
  property color bladeColor: "#c6b395"
  property int bladeCount: 5
  property bool live: true

  property real angle: 0
  property real glowPhase: 0
  readonly property real spin: 26 + Math.max(0, Math.min(1, speed)) * 340 + (boost ? 240 : 0)
  readonly property real glow: 0.5 + 0.5 * Math.sin(glowPhase)

  Timer {
    interval: 16
    repeat: true
    running: root.visible && root.live
    onTriggered: root.angle = (root.angle + root.spin * 0.016) % 360
  }

  Timer {
    interval: 32
    repeat: true
    running: root.visible && root.live && (root.boost || root.lit)
    onTriggered: root.glowPhase += root.boost ? 0.11 : 0.05
  }

  Rectangle {
    anchors.centerIn: parent
    width: parent.width * (root.boost ? 1.22 : 0.96)
    height: width
    radius: width / 2
    color: root.bladeColor
    opacity: root.boost ? 0.10 + root.glow * 0.16 : (root.lit ? 0.06 + root.glow * 0.05 : 0.04)
    Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 280 } }
  }

  Item {
    anchors.fill: parent
    visible: root.lit || root.boost
    rotation: -root.angle * (root.boost ? 0.55 : 0.32)

    Repeater {
      model: root.boost ? 8 : 5
      Item {
        anchors.fill: parent
        rotation: index * (360 / (root.boost ? 8 : 5))

        Rectangle {
          width: Math.max(2, parent.width * 0.07)
          height: width
          radius: width / 2
          color: root.bladeColor
          opacity: 0.15 + root.glow * 0.75
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
        }
      }
    }
  }

  Item {
    id: rotor
    anchors.fill: parent
    rotation: root.angle

    Repeater {
      model: root.bladeCount
      Item {
        anchors.fill: parent
        rotation: index * (360 / Math.max(1, root.bladeCount))

        Rectangle {
          width: Math.max(2, parent.width * 0.16)
          height: parent.height * 0.44
          radius: width
          color: root.bladeColor
          opacity: 0.28
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.verticalCenter
          anchors.bottomMargin: -width * 0.15
        }

        Rectangle {
          width: Math.max(2, parent.width * 0.09)
          height: parent.height * 0.40
          radius: width / 2
          color: root.bladeColor
          opacity: 0.96
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.verticalCenter
          anchors.bottomMargin: -width * 0.15
        }
      }
    }
  }

  Rectangle {
    anchors.centerIn: parent
    width: parent.width * 0.30
    height: width
    radius: width / 2
    color: root.bladeColor
    border.width: Math.max(1, parent.width * 0.035)
    border.color: Qt.rgba(0, 0, 0, 0.38)
  }

  Rectangle {
    anchors.centerIn: parent
    width: parent.width * 0.10
    height: width
    radius: width / 2
    color: Qt.rgba(0, 0, 0, 0.55)
  }
}
