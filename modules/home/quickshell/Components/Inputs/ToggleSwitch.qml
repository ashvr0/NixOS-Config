import QtQuick
import QtQuick.Layouts
import "../../Singletons"

// On/off switch. It does not flip itself: it emits toggled() and the parent
// changes the value. Set either `checked` or `on`, both work.
Rectangle {
  id: root

  property var s: function(v) { return v }
  property bool checked: false
  property bool on: false
  readonly property bool isOn: checked || on

  signal toggled()

  implicitWidth: s(48)
  implicitHeight: s(26)
  Layout.preferredWidth: implicitWidth
  Layout.preferredHeight: implicitHeight

  radius: height / 2
  opacity: enabled ? 1 : 0.4
  color: isOn ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.08)
  Behavior on color { ColorAnimation { duration: 250 } }

  activeFocusOnTab: enabled
  border.width: activeFocus ? 1 : 0
  border.color: MatugenColors.accent

  Keys.onPressed: (event) => {
    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (root.enabled) root.toggled()
      event.accepted = true
    }
  }

  Rectangle {
    width: root.s(20); height: root.s(20); radius: root.s(10)
    color: "white"
    anchors.verticalCenter: parent.verticalCenter
    x: root.isOn ? parent.width - width - root.s(3) : root.s(3)
    Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: if (root.enabled) root.toggled()
  }
}
