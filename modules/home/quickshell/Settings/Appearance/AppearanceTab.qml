import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import "../.."
import "../../Singletons"
import "../../Components"

ColumnLayout {
  id: root

  required property var s
  required property var matches
  required property string fontFamily
  required property var fontChoices
  required property var setFontFamily
  required property string colorScheme
  required property var setColorScheme
  required property string themeSearchQuery
  required property var themeMatches

  Layout.fillWidth: true
  spacing: s(14)

  Process {
    id: fontInstallProcess
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        let out = this.text.trim()
        if (out === "") return
        let idx = out.indexOf('|')
        if (idx === -1) return
        let fName = out.substring(0, idx).trim()
        if (fName === "") return

        if (root.fontChoices.indexOf(fName) === -1) {
          let arr = root.fontChoices.slice()
          arr.push(fName)
          root.fontChoices = arr
        }
        root.setFontFamily(fName)
      }
    }
  }

  function installFontFile(filePath) {
    if (!filePath || filePath.trim() === "") return
    let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1') }
    let script =
      "D=\"$HOME/.local/share/fonts\"; " +
      "S=\"" + escapeBash(filePath) + "\"; " +
      "mkdir -p \"$D\"; " +
      "B=$(basename \"$S\"); " +
      "if [ ! -f \"$D/$B\" ]; then cp \"$S\" \"$D/$B\"; fi; " +
      "F=\"$D/$B\"; " +
      "fc-cache -f \"$D\" >/dev/null 2>&1; " +
      "FAM=$(fc-query -f \"%{family}\" \"$F\" 2>/dev/null | cut -d, -f1); " +
      "if [ -z \"$FAM\" ]; then FAM=$(basename \"$F\" | sed 's/\\.[^.]*$//'); fi; " +
      "echo \"$FAM|$F\";"
    fontInstallProcess.command = ["bash", "-c", script]
    fontInstallProcess.running = true
  }

  // Reparented to the top-level window's content item so the picker overlays
  // the whole shell instead of appearing pushed down inside the settings list.
  FilePickerDialog {
    id: fontPickerDialog
    parent: root.QsWindow?.window?.contentItem || root.parent || root
    anchors.fill: parent
    z: 1000
    visible: false
    titleText: "Select a font"
    nameFilters: ["ttf", "otf", "ttc", "woff", "woff2"]
    places: [
      { name: "Home", icon: "󰋜", path: Quickshell.env("HOME") || "" },
      { name: "Downloads", icon: "󰇚", path: (Quickshell.env("HOME") || "") + "/Downloads" },
      { name: "User Fonts", icon: "󰆉", path: (Quickshell.env("HOME") || "") + "/.local/share/fonts" },
    ]
    onAccepted: (path) => {
      visible = false
      root.installFontFile(path)
    }
    onCancelled: visible = false
  }

  SettingRow {
    id: fontRow
    visible: root.matches("Font") && root.fontChoices.length > 1
    icon: "󰛖"
    title: "UI Font"
    description: "Font used across the shell interface"

    control: Component {
      Item {
        implicitWidth: rowLayoutInner.implicitWidth
        implicitHeight: rowLayoutInner.implicitHeight

        RowLayout {
          id: rowLayoutInner
          anchors.fill: parent
          spacing: root.s(8)

          Rectangle {
            Layout.preferredWidth: root.s(30)
            Layout.preferredHeight: root.s(30)
            radius: root.s(8)
            color: addFontMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06)
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
              anchors.centerIn: parent
              text: "󰐕"
              font.pixelSize: root.s(14)
              font.family: "JetBrainsMono Nerd Font"
              color: MatugenColors.text
            }

            MouseArea {
              id: addFontMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: fontPickerDialog.visible = true
            }
          }

          Dropdown {
            id: fontDropdown
            s: root.s
            boxWidth: 220
            boxHeight: 30
            searchable: true
            useOptionAsFont: true
            options: root.fontChoices
            currentIndex: root.fontChoices.indexOf(root.fontFamily)
            onPicked: (i, v) => root.setFontFamily(v)
          }
        }
      }
    }
  }

  Rectangle { visible: root.matches("Color theme"); Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

  Text { visible: root.matches("Color theme"); text: "COLOR THEME"; font.pixelSize: s(10); font.weight: Font.Bold; font.family: root.fontFamily; color: MatugenColors.border }

  Rectangle {
    visible: root.matches("Color theme")
    Layout.fillWidth: true
    Layout.preferredHeight: s(36)
    radius: s(Config.uiRadius)
    color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

    RowLayout {
      anchors.fill: parent
      anchors.margins: s(8)
      spacing: s(6)

      Text { text: "󰍉"; font.pixelSize: s(13); font.family: root.fontFamily; color: MatugenColors.textDim }

      TextInput {
        id: themeSearchInput
        Layout.fillWidth: true
        text: root.themeSearchQuery
        verticalAlignment: TextInput.AlignVCenter
        font.pixelSize: s(12)
        font.family: root.fontFamily
        color: MatugenColors.text
        clip: true
        onTextChanged: root.themeSearchQuery = text
        Text { text: "Search themes..."; color: MatugenColors.textDim; visible: !parent.text; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
        Keys.onEscapePressed: { text = ""; themeSearchInput.focus = false }
      }
    }
  }

  GridLayout {
    visible: root.matches("Color theme")
    Layout.fillWidth: true
    columns: 3
    columnSpacing: s(8)
    rowSpacing: s(8)

    Repeater {
      model: Config.themeChoices.filter(t => root.themeMatches(t.label))
      delegate: Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: s(56)
        radius: s(Config.uiRadius)
        property bool selected: root.colorScheme === modelData.id
        color: selected
          ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16)
          : Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)
        border.width: 1
        border.color: selected ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.08)
        Behavior on color { ColorAnimation { duration: 150 } }

        property var preset: Config.themePresets[modelData.id]

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: s(8)
          spacing: s(4)

          RowLayout {
            spacing: s(4)
            Rectangle { width: s(12); height: s(12); radius: s(3); color: preset ? preset.bgBase : MatugenColors.bgBase }
            Rectangle { width: s(12); height: s(12); radius: s(3); color: preset ? preset.accent : MatugenColors.accent }
            Rectangle { width: s(12); height: s(12); radius: s(3); color: preset ? preset.text : MatugenColors.text }
          }

          Text {
            text: modelData.label
            font.pixelSize: s(10)
            font.family: root.fontFamily
            color: selected ? MatugenColors.accent : MatugenColors.text
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.setColorScheme(modelData.id)
        }
      }
    }

    Text {
      visible: root.matches("Color theme") && Config.themeChoices.filter(t => root.themeMatches(t.label)).length === 0
      Layout.columnSpan: 3
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      text: "No themes match \u201c" + root.themeSearchQuery + "\u201d"
      font.pixelSize: s(10)
      font.family: root.fontFamily
      color: MatugenColors.textDim
    }
  }
}
