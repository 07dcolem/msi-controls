import QtQuick
import QtQuick.Shapes
import qs.Commons

Item {
  id: root

  property string label: ""
  property real value: 0
  property real maximum: 100
  property real fan: -1
  property string unit: ""
  property color foreground: "#c6b395"
  property color accent: "#d7a15a"
  property string fontFamily: Style.font.family
  property bool marked: false
  property bool live: false

  property real shown: 0
  property real fanShown: 0

  readonly property real span: Math.max(1, maximum)
  readonly property real fraction: Math.max(0, Math.min(1, shown / span))
  readonly property real fanFraction: fan < 0 ? 0 : Math.max(0, Math.min(1, fanShown / 100))
  readonly property color heat: Qt.tint(foreground, Qt.rgba(accent.r, accent.g, accent.b, Math.min(0.85, fraction * 0.9)))
  readonly property bool arcVisible: fraction > 0.004
  readonly property bool fanVisible: fan >= 0 && fanFraction > 0.004
  readonly property int tickCount: 27
  readonly property real dialStart: 135
  readonly property real dialSweep: 270

  implicitWidth: Style.space(160)
  implicitHeight: Style.space(148)

  Behavior on shown {
    enabled: !ignition.running
    NumberAnimation { duration: 640; easing.type: Easing.OutCubic }
  }

  Behavior on fanShown {
    NumberAnimation { duration: 700; easing.type: Easing.OutCubic }
  }

  onValueChanged: if (!ignition.running) shown = value
  onFanChanged: if (fan >= 0) fanShown = fan
  onLiveChanged: {
    if (!live) {
      ignition.stop()
      return
    }
    if (fan >= 0) fanShown = fan
    ignition.restart()
  }

  SequentialAnimation {
    id: ignition
    NumberAnimation {
      target: root
      property: "shown"
      to: root.maximum
      duration: 420
      easing.type: Easing.InOutCubic
    }
    NumberAnimation {
      target: root
      property: "shown"
      to: 0
      duration: 360
      easing.type: Easing.OutCubic
    }
    onFinished: root.shown = root.value
  }

  Item {
    id: face
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    width: Math.min(parent.width, Style.space(132))
    height: width

    readonly property real arcWidth: Math.max(3, Style.space(3))
    readonly property real arcRadius: width / 2 - arcWidth * 2

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        strokeWidth: face.arcWidth
        strokeColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: face.width / 2
          centerY: face.height / 2
          radiusX: face.arcRadius
          radiusY: face.arcRadius
          startAngle: root.dialStart
          sweepAngle: root.dialSweep
        }
      }

      ShapePath {
        strokeWidth: face.arcWidth * 2.6
        strokeColor: root.arcVisible ? Qt.rgba(root.heat.r, root.heat.g, root.heat.b, 0.22) : "transparent"
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: face.width / 2
          centerY: face.height / 2
          radiusX: face.arcRadius
          radiusY: face.arcRadius
          startAngle: root.dialStart
          sweepAngle: root.dialSweep * root.fraction
        }
      }

      ShapePath {
        strokeWidth: face.arcWidth
        strokeColor: root.arcVisible ? root.heat : "transparent"
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: face.width / 2
          centerY: face.height / 2
          radiusX: face.arcRadius
          radiusY: face.arcRadius
          startAngle: root.dialStart
          sweepAngle: root.dialSweep * root.fraction
        }
      }

      ShapePath {
        strokeWidth: Math.max(2, face.arcWidth * 0.7)
        strokeColor: root.fanVisible ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.7) : "transparent"
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: face.width / 2
          centerY: face.height / 2
          radiusX: face.arcRadius * 0.72
          radiusY: face.arcRadius * 0.72
          startAngle: root.dialStart
          sweepAngle: root.dialSweep * root.fanFraction
        }
      }
    }

    Repeater {
      model: root.tickCount
      Item {
        required property int index
        readonly property bool major: index % 9 === 0
        anchors.fill: parent
        rotation: root.dialStart + (index / (root.tickCount - 1)) * root.dialSweep - 270

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          y: face.arcWidth + (parent.major ? 0 : Style.space(2))
          width: parent.major ? 2 : 1
          height: parent.major ? Style.space(7) : Style.space(4)
          radius: 1
          color: root.foreground
          opacity: (index / (root.tickCount - 1)) <= root.fraction + 0.03 ? 0.9 : 0.22
        }
      }
    }

    Item {
      anchors.fill: parent
      rotation: root.dialStart + root.fraction * root.dialSweep - 270

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: face.arcWidth * 2 + Style.space(8)
        width: 2
        height: face.width * 0.28
        radius: 1
        gradient: Gradient {
          GradientStop { position: 0.0; color: root.heat }
          GradientStop { position: 0.45; color: root.heat }
          GradientStop { position: 1.0; color: "transparent" }
        }
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: Style.space(8)
      textFormat: Text.PlainText
      text: isFinite(root.shown) ? String(Math.round(root.shown)) : "--"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    textFormat: Text.PlainText
    text: root.label + (root.unit !== "" ? "  " + root.unit : "") + (root.fan >= 0 ? "   " + Math.round(root.fanShown) + "%" : "")
    color: root.foreground
    opacity: root.marked ? 1 : 0.62
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    Behavior on opacity { NumberAnimation { duration: 180 } }
  }
}
