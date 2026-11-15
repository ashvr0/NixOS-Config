import QtQuick
import QtQuick.Layouts
import "../../Singletons"

Rectangle {
  id: root

  property var s: function(v) { return v }
  property string text: ""
  property string icon: ""
  property string variant: "subtle"
  property bool active: false
  property bool fill: false
  property int fontSize: 12
  property int iconSize: 12
  property int hPadding: 10
  property int buttonHeight: 30

  readonly property bool filled: variant === "primary" || active
  readonly property bool hovered: ma.containsMouse && enabled
  readonly property bool pressed: ma.pressed && enabled
  readonly property color contentColor: filled ? MatugenColors.accentText : MatugenColors.text

  signal clicked()
  signal rightClicked()

  implicitWidth: content.implicitWidth + s(hPadding * 2)
  implicitHeight: s(buttonHeight)
  Layout.preferredWidth: implicitWidth
  Layout.preferredHeight: implicitHeight
  Layout.fillWidth: fill

  radius: s(8)
  opacity: enabled ? 1 : 0.4
  activeFocusOnTab: enabled

  readonly property color baseColor: variant === "ghost" ? MatugenColors.bgElevated : Qt.tint(MatugenColors.bgElevated2, Qt.rgba(MatugenColors.text.r, MatugenColors.text.g, MatugenColors.text.b, 0.14))
  readonly property color accentTint: Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.18)

  color: {
    if (filled) {
      if (pressed) return Qt.darker(MatugenColors.accent, 1.1)
      if (hovered) return Qt.lighter(MatugenColors.accent, 1.1)
      return MatugenColors.accent
    }
    if (pressed) return Qt.tint(baseColor, Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.28))
    if (hovered) return Qt.tint(baseColor, accentTint)
    return baseColor
  }
  Behavior on color { ColorAnimation { duration: 150 } }

  Keys.onPressed: (event) => {
    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (root.enabled) root.clicked()
      event.accepted = true
    }
  }

  RowLayout {
    id: content
    anchors.centerIn: parent
    spacing: root.s(6)

    Text {
      visible: root.icon.length > 0
      text: root.icon
      font.pixelSize: root.s(root.iconSize)
      font.family: "JetBrainsMono Nerd Font"
      color: root.contentColor
      Behavior on color { ColorAnimation { duration: 150 } }
    }

    Text {
      visible: root.text.length > 0
      text: root.text
      font.pixelSize: root.s(root.fontSize)
      font.weight: Font.Bold
      font.family: "JetBrainsMono Nerd Font"
      color: root.contentColor
      Behavior on color { ColorAnimation { duration: 150 } }
    }
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
