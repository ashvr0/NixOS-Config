import QtQuick
import QtQuick.Layouts
import "../../Singletons"

// Rounded text box with placeholder.
//
// text: read and write the content
// committed(text): fires on Enter or when focus leaves the box (not on Escape)
// accepted(): fires on Enter only
// cancelled(): fires on Escape
// edited(): fires on every keystroke
// trailingIcon + trailingClicked(): optional small glyph button on the right
Rectangle {
  id: root

  property var s: function(v) { return v }
  property alias text: input.text
  property string placeholderText: ""
  property var validator: null
  property int maximumLength: 32767
  property int boxWidth: 150
  property int fieldHeight: 30
  property int fontSize: 12
  property bool fill: false
  property string trailingIcon: ""
  readonly property bool focused: input.activeFocus

  signal accepted()
  signal committed(string text)
  signal cancelled()
  signal edited()
  signal trailingClicked()

  function focusField() { input.forceActiveFocus() }
  function releaseFocus() { input.focus = false }

  implicitWidth: s(boxWidth)
  implicitHeight: s(fieldHeight)
  Layout.preferredWidth: implicitWidth
  Layout.preferredHeight: implicitHeight
  Layout.fillWidth: fill

  radius: s(8)
  opacity: enabled ? 1 : 0.4
  color: Qt.rgba(1, 1, 1, 0.06)
  border.width: input.activeFocus ? 1 : 0
  border.color: Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.5)

  TextInput {
    id: input
    property bool skipCommit: false

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: root.s(10)
    anchors.rightMargin: root.trailingIcon.length > 0 ? root.s(28) : root.s(10)
    font.pixelSize: root.s(root.fontSize)
    font.family: "JetBrainsMono Nerd Font"
    color: MatugenColors.text
    selectionColor: MatugenColors.accent
    selectedTextColor: MatugenColors.accentText
    selectByMouse: true
    clip: true
    maximumLength: root.maximumLength
    validator: root.validator

    onTextEdited: root.edited()
    onActiveFocusChanged: {
      if (activeFocus) skipCommit = false
      else if (!skipCommit) root.committed(text)
    }
    onAccepted: { root.accepted(); focus = false }
    Keys.onEscapePressed: { skipCommit = true; root.cancelled(); focus = false }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: input.text.length === 0 && !input.activeFocus
      text: root.placeholderText
      font: input.font
      color: MatugenColors.textDim
    }
  }

  Text {
    visible: root.trailingIcon.length > 0
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.rightMargin: root.s(8)
    text: root.trailingIcon
    font.pixelSize: root.s(11)
    font.family: "JetBrainsMono Nerd Font"
    color: trailMa.containsMouse ? MatugenColors.accent : MatugenColors.textDim
    Behavior on color { ColorAnimation { duration: 150 } }

    MouseArea {
      id: trailMa
      anchors.fill: parent
      anchors.margins: root.s(-6)
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.trailingClicked()
    }
  }
}
