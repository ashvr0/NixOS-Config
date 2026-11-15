import QtQuick
import QtQuick.Layouts
import "../../Singletons"

// Row of choices where one is selected.
// choices: [ { id: "numbers", label: "Numbers" }, ... ]
// current: the id of the selected choice
RowLayout {
  id: root

  property var s: function(v) { return v }
  property var choices: []
  property string current: ""
  property int buttonWidth: 78
  property int buttonHeight: 30

  signal picked(string id)

  readonly property color idleColor: Qt.tint(MatugenColors.bgElevated2, Qt.rgba(MatugenColors.text.r, MatugenColors.text.g, MatugenColors.text.b, 0.14))

  spacing: s(4)

  Repeater {
    model: root.choices
    delegate: Rectangle {
      id: btn
      required property var modelData
      readonly property bool sel: root.current === btn.modelData.id

      Layout.preferredWidth: root.s(root.buttonWidth)
      Layout.preferredHeight: root.s(root.buttonHeight)
      radius: root.s(8)
      opacity: root.enabled ? 1 : 0.4
      color: btn.sel
        ? (ma.containsMouse ? Qt.lighter(MatugenColors.accent, 1.1) : MatugenColors.accent)
        : (ma.containsMouse
            ? Qt.tint(root.idleColor, Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.18))
            : root.idleColor)
      Behavior on color { ColorAnimation { duration: 150 } }

      Text {
        anchors.centerIn: parent
        text: btn.modelData.label
        font.pixelSize: root.s(11)
        font.weight: Font.Bold
        font.family: "JetBrainsMono Nerd Font"
        color: btn.sel ? MatugenColors.accentText : MatugenColors.text
        Behavior on color { ColorAnimation { duration: 150 } }
      }

      MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.enabled) root.picked(btn.modelData.id)
      }
    }
  }
}
