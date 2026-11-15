import QtQuick
import QtQuick.Layouts
import "../../Singletons"

Rectangle {
  id: root

  property var s: function(v) { return v }
  property string icon: ""
  property int size: 26
  property int iconSize: 14
  property bool active: false
  property color iconColor: MatugenColors.text

  readonly property bool hovered: ma.containsMouse && enabled
  readonly property bool pressed: ma.pressed && enabled

  signal clicked()
  signal rightClicked()

  implicitWidth: s(size)
  implicitHeight: s(size)
  Layout.preferredWidth: implicitWidth
  Layout.preferredHeight: implicitHeight

  radius: s(8)
  opacity: enabled ? 1 : 0.4
  activeFocusOnTab: enabled
  border.width: activeFocus ? 1 : 0
  border.color: MatugenColors.accent

  color: {
    if (active) return Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.3)
    if (pressed) return Qt.rgba(1, 1, 1, 0.16)
    if (hovered) return Qt.rgba(1, 1, 1, 0.14)
    return Qt.rgba(1, 1, 1, 0.08)
  }
  Behavior on color { ColorAnimation { duration: 120 } }

  Keys.onPressed: (event) => {
    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (root.enabled) root.clicked()
      event.accepted = true
    }
  }

  Text {
    anchors.centerIn: parent
    text: root.icon
    font.pixelSize: root.s(root.iconSize)
    font.family: "JetBrainsMono Nerd Font"
    color: root.active ? MatugenColors.accent : root.iconColor
    Behavior on color { ColorAnimation { duration: 150 } }
  }

  MouseArea {
    id: ma
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: (mouse) => {
      if (!root.enabled) return
      if (mouse.button === Qt.RightButton) root.rightClicked()
      else root.clicked()
    }
  }
}
