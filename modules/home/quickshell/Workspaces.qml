
import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
  id: root
  implicitWidth: pillBg.width

  property int cascadeIndex: 0
  property int wsCount: 6
  property int pillH: 36
  property int step: pillH + 6
  implicitHeight: pillBg.height
  property bool entered: false
  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }
  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutBack } } }
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

  Rectangle {
    id: pillBg
    height: 50
    width: wsLayout.implicitWidth + 20
    radius: 14
    color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.75)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    anchors.verticalCenter: parent.verticalCenter

    Rectangle {
      id: activeHighlight
      y: (pillBg.height - root.pillH) / 2
      height: root.pillH
      radius: 10
      color: MatugenColors.accent
      z: 0

      property int curIdx: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id - 1 : 0
      x: wsLayout.x + curIdx * root.step
      width: root.pillH

      Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
      Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
    }

    Row {
      id: wsLayout
      anchors.centerIn: parent
      spacing: 6

      Repeater {
        model: root.wsCount

        Rectangle {
          id: wsButton
          width: root.pillH
          height: root.pillH
          radius: 10
          color: "transparent"

          property bool isFocused: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === (index + 1)
          property bool isOccupied: {
            var list = Hyprland.workspaces.values
            for (var i = 0; i < list.length; i++) {
              if (list[i].id === (index + 1)) return true
            }
            return false
          }
          property bool isHovered: wsMouse.containsMouse

          scale: isHovered && !isFocused ? 1.1 : 1.0
          Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

          Text {
            anchors.centerIn: parent
            text: (index + 1).toString()
            font.pixelSize: 13
            font.weight: wsButton.isFocused ? Font.Black : (wsButton.isOccupied ? Font.Bold : Font.Normal)
            color: wsButton.isFocused  ? MatugenColors.accentText
                 : wsButton.isHovered  ? MatugenColors.text
                 : wsButton.isOccupied ? MatugenColors.accent
                 :                       MatugenColors.border
            Behavior on color { ColorAnimation { duration: 200 } }
          }

          MouseArea {
            id: wsMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Hyprland.dispatch('hl.dsp.focus({workspace=' + (index + 1) + '})')
          }
        }
      }
    }
  }
}
