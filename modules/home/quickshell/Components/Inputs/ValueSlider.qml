import QtQuick
import QtQuick.Layouts
import "../../Singletons"

// Drag slider with the current value shown on the right.
// The parent stores the new value in onMoved.
RowLayout {
  id: root

  property var s: function(v) { return v }
  property int from: 0
  property int to: 100
  property int value: 0
  property string suffix: ""
  property int trackWidth: 160
  property int labelWidth: 56
  property int step: 1

  signal moved(int v)

  spacing: s(8)
  opacity: enabled ? 1 : 0.4

  Item {
    Layout.preferredWidth: root.s(root.trackWidth)
    Layout.preferredHeight: root.s(18)

    Rectangle {
      id: track
      anchors.fill: parent
      radius: height / 2
      color: Qt.rgba(1, 1, 1, 0.1)
      clip: true
      readonly property real ratio: root.to > root.from
        ? Math.max(0, Math.min(1, (root.value - root.from) / (root.to - root.from))) : 0

      Rectangle {
        width: Math.max(parent.radius * 2, track.width * track.ratio)
        height: parent.height
        radius: parent.radius
        color: MatugenColors.accent
        Behavior on width { enabled: !ma.pressed; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
      }

      Rectangle {
        width: root.s(2)
        height: parent.height
        x: Math.max(0, Math.min(parent.width - width, track.width * track.ratio - width / 2))
        color: MatugenColors.bgBase
        opacity: 0.55
        Behavior on x { enabled: !ma.pressed; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
      }

      MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true

        function updateFromX(mx) {
          let r = Math.max(0, Math.min(1, mx / track.width))
          let v = root.from + r * (root.to - root.from)
          if (root.step > 1) v = root.from + Math.round((v - root.from) / root.step) * root.step
          root.moved(Math.max(root.from, Math.min(root.to, Math.round(v))))
        }
        onPressed: (mouse) => updateFromX(mouse.x)
        onPositionChanged: (mouse) => { if (pressed) updateFromX(mouse.x) }
      }
    }
  }

  Text {
    text: root.value + root.suffix
    font.pixelSize: root.s(13)
    font.weight: Font.Bold
    font.family: "JetBrainsMono Nerd Font"
    color: MatugenColors.accent
    Layout.preferredWidth: root.s(root.labelWidth)
    horizontalAlignment: Text.AlignHCenter
  }
}
