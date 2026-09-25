import QtQuick
import QtQuick.Layouts
import ".."
import "../Singletons"

ColumnLayout {
  id: root

  required property var s
  required property var matches
  required property bool capturingMainMod
  required property var cancelCaptureMainMod
  required property var startCaptureMainMod
  required property var keyEventToModToken
  required property var setMainMod
  required property string mainMod
  required property var refreshKeybinds
  required property var keybindsModel
  required property var setKeybindName
  required property var cancelCapture
  required property var startCapture
  required property var keyEventToToken
  required property var setKeybindKey

  Layout.fillWidth: true
  spacing: s(14)

  Text { visible: root.matches("Main mod"); text: "MAIN MOD"; font.pixelSize: s(10); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.border }

  Rectangle {
    id: mainModRow
    visible: root.matches("Main mod")
    Layout.fillWidth: true
    Layout.preferredHeight: s(48)
    radius: s(Config.uiRadius)
    color: root.capturingMainMod
      ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.14)
      : Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)
    border.color: root.capturingMainMod ? MatugenColors.accent : "transparent"
    border.width: 1
    Behavior on color { ColorAnimation { duration: 120 } }

    RowLayout {
      anchors.fill: parent
      anchors.margins: s(10)
      spacing: s(8)

      Text { text: "󰌌"; font.pixelSize: s(15); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent }
      Text {
        text: "Main modifier"
        font.pixelSize: s(13)
        font.family: "JetBrainsMono Nerd Font"
        color: MatugenColors.text
        Layout.fillWidth: true
      }

      Text {
        text: root.capturingMainMod ? "Press a key..." : root.mainMod
        font.pixelSize: s(12)
        font.weight: Font.Bold
        font.family: "JetBrainsMono Nerd Font"
        color: MatugenColors.accent
      }
    }

    MouseArea {
      id: mainModMa
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (root.capturingMainMod) root.cancelCaptureMainMod()
        else root.startCaptureMainMod()
      }
    }

    Keys.onPressed: {
      if (!root.capturingMainMod) return
      let token = root.keyEventToModToken(event)
      if (token) root.setMainMod(token)
      root.capturingMainMod = false
      event.accepted = true
    }
    focus: root.capturingMainMod
  }

  RowLayout {
    Layout.fillWidth: true
    visible: root.matches("Keybinds")
    Text { text: "KEYBINDS"; font.pixelSize: s(10); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.border; Layout.fillWidth: true }
    Text {
      text: "󰑐"
      font.pixelSize: s(13)
      font.family: "JetBrainsMono Nerd Font"
      color: kbRefreshMa.containsMouse ? MatugenColors.accent : MatugenColors.textDim
      Behavior on color { ColorAnimation { duration: 150 } }
      MouseArea { id: kbRefreshMa; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.refreshKeybinds() }
    }
  }

  Repeater {
    model: root.keybindsModel
    delegate: Rectangle {
      visible: root.matches("Keybinds") || root.matches(model.key) || root.matches(model.name)
      Layout.fillWidth: true
      Layout.preferredHeight: s(40)
      radius: s(8)
      color: model.editing ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.14) : Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)
      border.width: model.editing ? 1 : 0
      border.color: MatugenColors.accent
      Behavior on color { ColorAnimation { duration: 150 } }

      RowLayout {
        anchors.fill: parent
        anchors.margins: s(10)
        spacing: s(8)

        Text { text: root.mainMod; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textDim }
        Text { text: "+"; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textDim }

        Item {
          id: renameEdit
          Layout.fillWidth: true
          Layout.preferredHeight: s(20)
          property bool renaming: false
          function startEdit() { renaming = true; nameInput.text = model.name; nameInput.forceActiveFocus(); nameInput.selectAll() }
          function commit() { renaming = false; if (nameInput.text.trim()) root.setKeybindName(index, nameInput.text.trim()) }

          Text {
            anchors.fill: parent
            visible: !renameEdit.renaming
            verticalAlignment: Text.AlignVCenter
            text: model.name
            font.pixelSize: s(12)
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.text
            elide: Text.ElideRight
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onDoubleClicked: renameEdit.startEdit() }
          }

          TextInput {
            id: nameInput
            anchors.fill: parent
            visible: renameEdit.renaming
            verticalAlignment: TextInput.AlignVCenter
            font.pixelSize: s(12)
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.accent
            clip: true
            onAccepted: renameEdit.commit()
            Keys.onEscapePressed: renameEdit.renaming = false
            onActiveFocusChanged: if (!activeFocus && renameEdit.renaming) renameEdit.commit()
          }
        }

        Rectangle {
          width: s(72); height: s(26); radius: s(6); Layout.preferredWidth: s(72); Layout.preferredHeight: s(26)
          color: model.error ? Qt.rgba(1, 0.3, 0.3, 0.22) : (model.editing ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.22) : Qt.rgba(1, 1, 1, 0.08))
          border.width: model.editing || model.error ? 1 : 0
          border.color: model.error ? "#ff4d4d" : MatugenColors.accent

          Text {
            anchors.centerIn: parent
            text: model.editing ? "press key" : model.key
            font.pixelSize: model.editing ? 9 : 11
            font.weight: Font.Bold
            font.family: "JetBrainsMono Nerd Font"
            color: model.editing ? MatugenColors.accent : MatugenColors.text
          }

          MouseArea {
            id: keyEditMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (model.editing) root.cancelCapture()
              else root.startCapture(index)
            }
          }

          Keys.onPressed: {
            if (!model.editing) return
            let token = root.keyEventToToken(event)
            if (token) root.setKeybindKey(index, token)
            event.accepted = true
          }
          focus: model.editing

          Text {
            visible: !!model.error
            anchors.top: parent.bottom
            anchors.topMargin: s(4)
            anchors.right: parent.right
            width: s(160)
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignRight
            text: model.error
            font.pixelSize: s(10)
            font.family: "JetBrainsMono Nerd Font"
            color: "#ff4d4d"
            z: 10
          }
        }
      }
    }
  }
}
