import QtQuick
import QtQuick.Layouts
import "../../Singletons"
import ".."

// Minus, value, plus. The parent stores the new value in onMoved.
//
//   Stepper { s: root.s; value: Config.workspaceCount; from: 1; to: 10
//             editable: true; onMoved: (v) => Config.workspaceCount = v }
//
// editable: click the number to type one (Enter or click away to apply)
// valueText: show this instead of the number (for example "Never")
// liveEdit: with editable, apply the value while typing instead of on Enter
// stepFn: optional function(value, dir) for uneven steps, returns the new value
RowLayout {
  id: root

  property var s: function(v) { return v }
  property real value: 0
  property real from: 0
  property real to: 100
  property real step: 1
  property int decimals: 0
  property string suffix: ""
  property string valueText: ""
  property bool editable: false
  property int boxWidth: 56
  property bool liveEdit: false
  property var stepFn: null

  signal moved(real v)

  readonly property bool canDec: value > from
  readonly property bool canInc: value < to
  readonly property string display: valueText.length > 0 ? valueText : value.toFixed(decimals) + suffix

  spacing: s(4)
  opacity: enabled ? 1 : 0.4

  function clamp(n) {
    let f = Math.pow(10, root.decimals)
    n = Math.round(n * f) / f
    return Math.max(root.from, Math.min(root.to, n))
  }

  function bump(dir) {
    let raw = root.stepFn ? root.stepFn(root.value, dir) : root.value + dir * root.step
    let n = root.clamp(raw)
    if (n !== root.value) root.moved(n)
  }

  function commitText(t) {
    let n = parseFloat(t)
    if (isNaN(n)) return
    n = root.clamp(n)
    if (n !== root.value) root.moved(n)
  }

  IconButton {
    s: root.s
    size: 28
    iconSize: 11
    icon: "\uf053"
    iconColor: MatugenColors.accent
    enabled: root.canDec
    onClicked: root.bump(-1)
  }

  Rectangle {
    Layout.preferredWidth: root.s(root.boxWidth)
    Layout.preferredHeight: root.s(28)
    radius: root.s(6)
    color: Qt.rgba(1, 1, 1, input.activeFocus ? 0.12 : 0.08)
    border.width: input.activeFocus ? 1 : 0
    border.color: MatugenColors.accent
    Behavior on color { ColorAnimation { duration: 120 } }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.NoButton
      onWheel: (wheel) => {
        root.bump(wheel.angleDelta.y > 0 ? 1 : -1)
        wheel.accepted = true
      }
    }

    TextInput {
      id: input
      property bool skipCommit: false

      anchors.fill: parent
      verticalAlignment: TextInput.AlignVCenter
      horizontalAlignment: TextInput.AlignHCenter
      font.pixelSize: root.s(13)
      font.weight: Font.Bold
      font.family: "JetBrainsMono Nerd Font"
      color: MatugenColors.accent
      selectionColor: MatugenColors.accent
      selectedTextColor: MatugenColors.accentText
      readOnly: !root.editable
      activeFocusOnPress: root.editable
      selectByMouse: root.editable
      inputMethodHints: Qt.ImhFormattedNumbersOnly
      validator: RegularExpressionValidator {
        regularExpression: root.decimals > 0 ? /^-?\d*\.?\d*$/ : /^-?\d*$/
      }

      Component.onCompleted: text = root.display

      onActiveFocusChanged: {
        if (activeFocus) {
          skipCommit = false
          text = root.value.toFixed(root.decimals)
          selectAll()
        } else {
          if (!skipCommit) root.commitText(text)
          text = root.display
        }
      }

      onTextEdited: if (root.liveEdit) root.commitText(text)

      Keys.onReturnPressed: focus = false
      Keys.onEnterPressed: focus = false
      Keys.onEscapePressed: { skipCommit = true; focus = false }

      Connections {
        target: root
        function onDisplayChanged() {
          if (!input.activeFocus) input.text = root.display
        }
      }
    }
  }

  IconButton {
    s: root.s
    size: 28
    iconSize: 11
    icon: "\uf054"
    iconColor: MatugenColors.accent
    enabled: root.canInc
    onClicked: root.bump(1)
  }
}
