import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import ".."
import "../Singletons"

ColumnLayout {
  id: root

  required property var s
  required property var matches
  required property string fontFamily
  required property var fontChoices
  required property var setFontFamily
  required property string currentWallpaperPath
  required property string wallpaperDir
  required property var setWallpaperDir
  required property string colorScheme
  required property var setColorScheme
  required property string themeSearchQuery
  required property var themeMatches

  Layout.fillWidth: true
  spacing: s(14)

  component SettingRow: Rectangle {
    id: settingRow
    property string icon: ""
    required property string title
    property string description: ""
    property Component control: null

    Layout.fillWidth: true
    Layout.preferredHeight: Math.max(root.s(48), rowContent.implicitHeight + root.s(20))
    radius: root.s(Config.uiRadius)
    color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

    RowLayout {
      id: rowContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: root.s(10)
      spacing: root.s(10)

      Text {
        visible: settingRow.icon.length > 0
        text: settingRow.icon
        font.pixelSize: root.s(22)
        font.family: "JetBrainsMono Nerd Font"
        color: MatugenColors.accent
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: root.s(2)

        Text {
          text: settingRow.title
          font.pixelSize: root.s(13)
          font.weight: Font.Bold
          font.family: "JetBrainsMono Nerd Font"
          color: MatugenColors.text
          Layout.fillWidth: true
        }

        Text {
          visible: settingRow.description.length > 0
          text: settingRow.description
          font.pixelSize: root.s(11)
          font.family: "JetBrainsMono Nerd Font"
          color: MatugenColors.textDim
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }
      }

      Loader {
        sourceComponent: settingRow.control
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: item ? item.implicitWidth : 0
      }
    }
  }

  // ── Current wallpaper preview ──
  Text { visible: root.matches("Wallpaper"); text: "CURRENT WALLPAPER"; font.pixelSize: s(10); font.weight: Font.Bold; font.family: root.fontFamily; color: MatugenColors.border }

  property string liveWallpaperPath: root.currentWallpaperPath
  property int wallpaperRevision: 0

  readonly property string activeScreenName: (Quickshell.screens && Quickshell.screens.length > 0 && Quickshell.screens[0].name) ? Quickshell.screens[0].name : ""

  FileView {
    id: wpStateWatcher
    path: root.activeScreenName !== "" ? (Caching.getCacheDir("wallpaper") + "/current_" + root.activeScreenName) : ""
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      let res = text().trim()
      if (res !== "" && res !== root.liveWallpaperPath) {
        root.liveWallpaperPath = res
        root.wallpaperRevision++
      }
    }
  }

  Process {
    id: wallpaperFetcher
    running: false
    command: {
      let screenName = root.activeScreenName
      let mainQmlPath = Caching.mainQml || ""
      if (!mainQmlPath || !screenName) return ["true"]
      return ["bash", "-c", "quickshell -p \"" + mainQmlPath + "\" ipc call wallpaper getWallpaperPath \"" + screenName + "\""]
    }
    stdout: StdioCollector {
      onStreamFinished: {
        let res = this.text.trim()
        if (res !== "" && res !== root.liveWallpaperPath) {
          root.liveWallpaperPath = res
          root.wallpaperRevision++
        }
      }
    }
  }

  Component.onCompleted: {
    // If the state file didn't produce anything on load, ask the
    // daemon directly so the preview never shows a stale path.
    refreshTimer.start()
  }

  Timer {
    id: refreshTimer
    interval: 150
    repeat: false
    onTriggered: {
      if (root.liveWallpaperPath === "") {
        wallpaperFetcher.running = true
      }
    }
  }

  // Reparented to the top-level window's content item so the picker overlays
  // the whole shell instead of being clipped/pushed down by the settings
  // ColumnLayout (previously required scrolling to see it).
  FilePickerDialog {
    id: wallpaperPickerDialog
    parent: root.QsWindow?.window?.contentItem || root.parent || root
    anchors.fill: parent
    z: 1000
    visible: false
    selectFolders: true
    titleText: "Choose wallpaper folder"
    nameFilters: []
    places: [
      { name: "Home", icon: "󰋜", path: Quickshell.env("HOME") || "" },
      { name: "Downloads", icon: "󰇚", path: (Quickshell.env("HOME") || "") + "/Downloads" },
      { name: "Pictures", icon: "󰉏", path: (Quickshell.env("HOME") || "") + "/Pictures" },
    ]
    onAccepted: (path) => {
      visible = false
      root.setWallpaperDir(path)
    }
    onCancelled: visible = false
  }

  Rectangle {
    visible: root.matches("Wallpaper")
    Layout.fillWidth: true
    Layout.preferredHeight: s(260)
    radius: s(Config.uiRadius)
    color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)
    clip: true

    Image {
      id: wallpaperPreviewImg
      anchors.fill: parent
      anchors.margins: s(4)
      source: root.liveWallpaperPath ? "file://" + root.liveWallpaperPath + "?rev=" + root.wallpaperRevision : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      visible: status === Image.Ready
    }

    Rectangle {
      anchors.fill: wallpaperPreviewImg
      radius: s(Config.uiRadius - 4)
      color: "transparent"
      border.color: Qt.rgba(1, 1, 1, 0.08)
      border.width: 1
      visible: wallpaperPreviewImg.visible
    }

    ColumnLayout {
      anchors.centerIn: parent
      visible: !wallpaperPreviewImg.visible
      spacing: s(6)
      Text { text: "󰋩"; font.pixelSize: s(22); font.family: root.fontFamily; color: MatugenColors.textDim; Layout.alignment: Qt.AlignHCenter }
      Text { text: "No wallpaper set"; font.pixelSize: s(11); font.family: root.fontFamily; color: MatugenColors.textDim; Layout.alignment: Qt.AlignHCenter }
    }

    // Bottom gradient so the overlay text stays legible over bright wallpapers
    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: s(56)
      visible: wallpaperPreviewImg.visible
      gradient: Gradient {
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
      }
    }

    // Bottom-left: select wallpaper button
    Rectangle {
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      anchors.margins: s(12)
      width: selectWpRow.implicitWidth + s(20)
      height: s(32)
      radius: s(Config.uiRadius)
      color: selectWpMa.containsMouse ? Qt.lighter(MatugenColors.accent, 1.1) : MatugenColors.accent

      RowLayout {
        id: selectWpRow
        anchors.centerIn: parent
        spacing: s(6)
        Text { text: "󰸉"; font.pixelSize: s(13); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accentText }
        Text { text: "Select wallpaper"; font.pixelSize: s(11); font.weight: Font.Bold; font.family: root.fontFamily; color: MatugenColors.accentText }
      }

      MouseArea {
        id: selectWpMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["qs", "ipc", "call", "wallpaper", "toggle"])
      }
    }

    // Bottom-right: filename + directory path
    ColumnLayout {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: s(12)
      spacing: s(1)
      visible: wallpaperPreviewImg.visible

      Text {
        Layout.alignment: Qt.AlignRight
        text: root.liveWallpaperPath ? root.liveWallpaperPath.split("/").pop() : ""
        font.pixelSize: s(12)
        font.weight: Font.Bold
        font.family: root.fontFamily
        color: "#ffffff"
        elide: Text.ElideLeft
        Layout.maximumWidth: s(280)
      }
      Text {
        Layout.alignment: Qt.AlignRight
        text: root.liveWallpaperPath ? root.liveWallpaperPath.substring(0, root.liveWallpaperPath.lastIndexOf("/")).replace(Quickshell.env("HOME") || "", "~") : ""
        font.pixelSize: s(10)
        font.family: root.fontFamily
        color: Qt.rgba(1, 1, 1, 0.75)
        elide: Text.ElideLeft
        Layout.maximumWidth: s(280)
      }
    }
  }

  // ── Wallpaper directory: boxed textbox + folder-picker icon button ──
  SettingRow {
    visible: root.matches("Wallpaper directory")
    icon: "󰉏"
    title: "Wallpaper directory"
    description: "Directory to search for wallpapers"

    control: Component {
      RowLayout {
        spacing: root.s(6)

        Rectangle {
          Layout.preferredWidth: root.s(200)
          Layout.preferredHeight: root.s(30)
          radius: root.s(8)
          color: Qt.rgba(1, 1, 1, 0.06)
          border.width: 1
          border.color: Qt.rgba(1, 1, 1, 0.10)

          TextInput {
            id: wallpaperDirInput
            anchors.fill: parent
            anchors.leftMargin: root.s(10)
            anchors.rightMargin: root.s(10)
            text: root.wallpaperDir
            verticalAlignment: TextInput.AlignVCenter
            font.pixelSize: root.s(12)
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.textDim
            clip: true
            onAccepted: root.setWallpaperDir(text)
            onActiveFocusChanged: if (!activeFocus) root.setWallpaperDir(text)
          }
        }

        Rectangle {
          Layout.preferredWidth: root.s(30)
          Layout.preferredHeight: root.s(30)
          radius: root.s(8)
          color: wpDirPickMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06)
          Behavior on color { ColorAnimation { duration: 150 } }

          Text {
            anchors.centerIn: parent
            text: "󰉋"
            font.pixelSize: root.s(14)
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.text
          }

          MouseArea {
            id: wpDirPickMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              wallpaperPickerDialog.openWithOptionalPath(root.wallpaperDir + "/")
              wallpaperPickerDialog.visible = true
            }
          }
        }
      }
    }
  }

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

          Rectangle {
            id: fontValueBox
            Layout.preferredWidth: root.s(220)
            Layout.preferredHeight: root.s(30)
            radius: root.s(8)
            color: fontValueMa.containsMouse || fontDropdown.opened ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06)
            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: root.s(10)
              anchors.rightMargin: root.s(8)
              spacing: root.s(6)

              TextInput {
                id: fontSearchInput
                Layout.fillWidth: true
                text: fontDropdown.searchMode ? fontDropdown.fontSearchQuery : root.fontFamily
                font.pixelSize: root.s(12)
                font.weight: Font.Bold
                font.family: root.fontFamily
                color: MatugenColors.text
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                selectByMouse: true
                readOnly: !fontDropdown.searchMode

                onTextChanged: if (fontDropdown.searchMode) fontDropdown.fontSearchQuery = text

                Text {
                  text: "Select..."
                  color: MatugenColors.textDim
                  visible: fontDropdown.searchMode && !parent.text
                  font: parent.font
                  anchors.verticalCenter: parent.verticalCenter
                }

                Keys.onEscapePressed: {
                  fontDropdown.close()
                  fontDropdown.searchMode = false
                  fontDropdown.fontSearchQuery = ""
                }
                Keys.onReturnPressed: {
                  if (fontDropdown.filteredFonts.length > 0) {
                    root.setFontFamily(fontDropdown.filteredFonts[0])
                    fontDropdown.close()
                    fontDropdown.searchMode = false
                    fontDropdown.fontSearchQuery = ""
                  }
                }
              }

              Text {
                text: fontDropdown.opened ? "󰅃" : "󰅀"
                font.pixelSize: root.s(12)
                font.family: root.fontFamily
                color: MatugenColors.textDim
              }
            }

            MouseArea {
              id: fontValueMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (fontDropdown.opened) {
                  fontDropdown.close()
                  fontDropdown.searchMode = false
                  fontDropdown.fontSearchQuery = ""
                } else {
                  fontDropdown.open()
                }
              }
              onDoubleClicked: {
                fontDropdown.open()
                fontDropdown.searchMode = true
                fontDropdown.fontSearchQuery = ""
                fontSearchInput.forceActiveFocus()
              }
            }
          }
        }

        Popup {
          id: fontDropdown
          parent: fontValueBox
          y: fontValueBox.height + root.s(6)
          x: fontValueBox.width - width
          width: root.s(220)
          height: Math.min(root.s(220), fontDropdown.filteredFonts.length * root.s(28) + root.s(12))
          padding: root.s(6)
          closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

          property bool searchMode: false
          property string fontSearchQuery: ""
          property var filteredFonts: root.fontChoices.filter(f =>
              !searchMode || fontSearchQuery === "" || f.toLowerCase().indexOf(fontSearchQuery.toLowerCase()) !== -1)

          background: Rectangle {
            radius: root.s(Config.uiRadius)
            color: MatugenColors.bgElevated
            border.color: Qt.rgba(1, 1, 1, 0.10)
            border.width: 1
          }

          contentItem: ListView {
            clip: true
            model: fontDropdown.filteredFonts
            delegate: Rectangle {
              width: ListView.view.width
              height: root.s(26)
              radius: root.s(6)
              property bool selected: root.fontFamily === modelData
              color: selected
                ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16)
                : (fontItemMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
              Behavior on color { ColorAnimation { duration: 120 } }

              Text {
                anchors.left: parent.left
                anchors.leftMargin: root.s(8)
                anchors.right: parent.right
                anchors.rightMargin: root.s(8)
                anchors.verticalCenter: parent.verticalCenter
                text: modelData
                elide: Text.ElideRight
                font.pixelSize: root.s(12)
                font.family: modelData
                color: selected ? MatugenColors.accent : MatugenColors.text
              }

              MouseArea {
                id: fontItemMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.setFontFamily(modelData)
                  fontDropdown.close()
                  fontDropdown.searchMode = false
                  fontDropdown.fontSearchQuery = ""
                }
              }
            }

            Text {
              anchors.centerIn: parent
              visible: fontDropdown.filteredFonts.length === 0
              text: "No fonts match"
              font.pixelSize: root.s(11)
              font.family: root.fontFamily
              color: MatugenColors.textDim
            }
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
