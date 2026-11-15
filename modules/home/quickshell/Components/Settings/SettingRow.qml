import QtQuick
import QtQuick.Layouts
import "../../Singletons"

Rectangle {
  id: settingRow

  // Scaler function. Tabs can pass "s: root.s", otherwise it falls back to Scaler.
  property var s: function(v) { return Scaler.s(v) }

  property string icon: ""
  required property string title
  property string description: ""
  // flat removes the own background (used inside monitor cards)
  property bool flat: false
  property Component control: null

  Layout.fillWidth: true
  Layout.preferredHeight: Math.max(settingRow.s(48), rowContent.implicitHeight + settingRow.s(20))
  radius: settingRow.s(Config.uiRadius)
  color: settingRow.flat
    ? "transparent"
    : Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

  RowLayout {
    id: rowContent
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: settingRow.s(settingRow.flat ? 2 : 10)
    anchors.rightMargin: settingRow.s(settingRow.flat ? 2 : 10)
    spacing: settingRow.s(10)

    Text {
      visible: settingRow.icon.length > 0
      text: settingRow.icon
      font.pixelSize: settingRow.s(22)
      font.family: "JetBrainsMono Nerd Font"
      color: MatugenColors.accent
      Layout.alignment: Qt.AlignVCenter
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: settingRow.s(2)

      Text {
        text: settingRow.title
        font.pixelSize: settingRow.s(13)
        font.weight: Font.Bold
        font.family: "JetBrainsMono Nerd Font"
        color: MatugenColors.text
        Layout.fillWidth: true
      }

      Text {
        visible: settingRow.description.length > 0
        text: settingRow.description
        font.pixelSize: settingRow.s(11)
        font.family: "JetBrainsMono Nerd Font"
        color: MatugenColors.textDim
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }
    }

    Loader {
      sourceComponent: settingRow.control
      Layout.alignment: Qt.AlignVCenter
    }
  }
}
