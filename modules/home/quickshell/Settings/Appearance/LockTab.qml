import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../.."
import "../../Singletons"
import "../../Components"

// Lock screen settings. TEMP DESIGN.
// Everything marked TODO is local state or an inert button until it is wired to Config.
ColumnLayout {
  id: root

  required property var s
  required property var matches
  required property string fontFamily

  // Path of the current wallpaper, shown in the preview while "Follow wallpaper" is on
  property string currentWallpaperPath: ""

  // TODO: move these into Config
  // Stored in LockLayout (saved to lock-layout.json, read by the lock screen)
  readonly property string bgMode: LockLayout.bgMode
  readonly property string customBgPath: LockLayout.customBgPath
  readonly property bool attemptLimits: LockLayout.attemptLimits
  readonly property bool blurOnInput: LockLayout.blurOnInput
  readonly property int maxAttempts: LockLayout.maxAttempts

  readonly property string previewPath: root.bgMode === "follow" ? root.liveWallpaperPath : root.customBgPath
  property string liveWallpaperPath: root.currentWallpaperPath

readonly property string activeScreenName: (Quickshell.screens && Quickshell.screens.length > 0 && Quickshell.screens[0].name) ? Quickshell.screens[0].name : ""

FileView {
  id: wpStateWatcher
  printErrors: false
  path: root.activeScreenName !== ""
    ? (Quickshell.env("HOME") + "/.cache/wallpaper-picker/current_" + root.activeScreenName)
    : ""
  watchChanges: true
  onFileChanged: reload()
  onLoaded: {
    let res = text().trim()
    if (res !== "" && res !== root.liveWallpaperPath)
      root.liveWallpaperPath = res
  }
}

  // Turns a plain path into a safe file url. Spaces, #, % and ? in names break a raw
  // "file://" + path concatenation, so every segment gets percent encoded.
  function toUrl(p) {
    if (!p) return ""
    if (p.indexOf("file://") === 0) return p
    return "file://" + p.split("/").map(encodeURIComponent).join("/")
  }

  Layout.fillWidth: true
  spacing: s(14)
  focus: true

  TapHandler { onTapped: root.forceActiveFocus() }

  // ---------- shared building blocks ----------

  component SectionTitle: Text {
    font.pixelSize: root.s(14)
    font.weight: Font.Bold
    font.family: "JetBrainsMono Nerd Font"
    color: MatugenColors.text
  }

  // ---------- background preview ----------

  Text {
    visible: root.matches("Lock background")
    text: "BACKGROUND"
    font.pixelSize: s(10)
    font.weight: Font.Bold
    font.family: root.fontFamily
    color: MatugenColors.border
  }

  Rectangle {
    id: hero
    visible: root.matches("Lock background")
    Layout.fillWidth: true
    Layout.preferredHeight: s(260)
    radius: s(Config.uiRadius)
    color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)
    clip: true

    Image {
      id: heroImg
      anchors.fill: parent
      anchors.margins: s(4)
      source: root.toUrl(root.previewPath)
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      visible: status === Image.Ready
    }

    // Dim the image so the centered label and the controls stay readable
    Rectangle {
      anchors.fill: heroImg
      color: Qt.rgba(0, 0, 0, 0.38)
      visible: heroImg.visible
    }

    Rectangle {
      anchors.fill: heroImg
      radius: s(Math.max(0, Config.uiRadius - 4))
      color: "transparent"
      border.color: Qt.rgba(1, 1, 1, 0.08)
      border.width: 1
      visible: heroImg.visible
    }

    ColumnLayout {
      anchors.centerIn: parent
      spacing: s(8)

      Text {
        text: "\uf03e"
        font.pixelSize: s(30)
        font.family: "JetBrainsMono Nerd Font"
        color: heroImg.visible ? "#ffffff" : MatugenColors.textDim
        Layout.alignment: Qt.AlignHCenter
      }
      Text {
        text: root.bgMode === "follow" ? "Follows wallpaper" : (root.customBgPath ? "Custom background" : "No background selected")
        font.pixelSize: s(13)
        font.weight: Font.Bold
        font.family: root.fontFamily
        color: heroImg.visible ? "#ffffff" : MatugenColors.textDim
        Layout.alignment: Qt.AlignHCenter
      }
    }

    // Bottom left: select button + mode switch
    RowLayout {
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      anchors.margins: s(12)
      spacing: s(8)

      ClickButton {
        id: selectBtn
        s: root.s
        enabled: root.bgMode === "custom"
        active: root.bgMode === "custom"
        opacity: enabled ? 1 : 0.45
        icon: "\uf03e"
        text: "Select background"
        buttonHeight: 32
        hPadding: 12
        fontSize: 11
        iconSize: 13
        onClicked: {
          if (root.bgMode === "custom")
          bgPicker.active = true
        }
      }

      Rectangle {
        Layout.preferredHeight: s(32)
        Layout.preferredWidth: modeRow.implicitWidth + s(6)
        radius: s(Config.uiRadius)
        color: Qt.rgba(0, 0, 0, 0.45)

        RowLayout {
          id: modeRow
          anchors.centerIn: parent
          spacing: 0

          Repeater {
            model: [ { id: "follow", label: "Follow wallpaper" }, { id: "custom", label: "Custom" } ]
            delegate: Rectangle {
              id: modeBtn
              required property var modelData
              readonly property bool sel: root.bgMode === modeBtn.modelData.id

              Layout.preferredWidth: modeLabel.implicitWidth + s(28)
              Layout.preferredHeight: s(26)
              radius: s(Math.max(0, Config.uiRadius - 2))
              color: modeBtn.sel ? MatugenColors.accent : "transparent"
              Behavior on color { ColorAnimation { duration: 150 } }

              Text {
                id: modeLabel
                anchors.centerIn: parent
                text: modeBtn.modelData.label
                font.pixelSize: s(11)
                font.weight: Font.Bold
                font.family: root.fontFamily
                color: modeBtn.sel ? MatugenColors.accentText : "#ffffff"
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: LockLayout.bgMode = modeBtn.modelData.id
              }
            }
          }
        }
      }
    }

    // Bottom right: file name + folder
    ColumnLayout {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: s(12)
      spacing: s(1)
      visible: root.previewPath !== ""

      Text {
        Layout.alignment: Qt.AlignRight
        text: root.previewPath ? root.previewPath.split("/").pop() : ""
        font.pixelSize: s(12)
        font.weight: Font.Bold
        font.family: root.fontFamily
        color: "#ffffff"
        elide: Text.ElideLeft
        Layout.maximumWidth: s(280)
      }
      Text {
        Layout.alignment: Qt.AlignRight
        text: root.previewPath ? root.previewPath.substring(0, root.previewPath.lastIndexOf("/")) : ""
        font.pixelSize: s(10)
        font.family: root.fontFamily
        color: Qt.rgba(1, 1, 1, 0.75)
        elide: Text.ElideLeft
        Layout.maximumWidth: s(280)
      }
    }
  }

  // ---------- rows ----------

  SettingRow {
    visible: root.matches("Lock screen layout edit")
    icon: "\uf023"
    title: "Lock screen"
    description: "Customize the layout of your lock screen"

    control: Component {
      ClickButton {
        s: root.s
        variant: "primary"
        icon: "\uf044"
        text: "Edit lock screen"
        buttonHeight: 34
        hPadding: 12
        iconSize: 13
        onClicked: editorLoader.active = true
      }
    }
  }

  SettingRow {
    visible: root.matches("Blur background on input")
    icon: "\uf043"
    title: "Blur on input"
    description: "Blur the background when you start typing your password"

    control: Component {
      ToggleSwitch {
        s: root.s
        checked: root.blurOnInput
        onToggled: LockLayout.blurOnInput = !LockLayout.blurOnInput
      }
    }
  }

  SettingRow {
    visible: root.matches("Attempt limits")
    icon: "\uf132"
    title: "Attempt limits"
    description: "Temporarily block password entry after too many failed attempts"

    control: Component {
      ToggleSwitch {
        s: root.s
        checked: root.attemptLimits
        onToggled: LockLayout.attemptLimits = !LockLayout.attemptLimits
      }
    }
  }

  SettingRow {
    visible: root.attemptLimits && root.matches("Password attempts")
    icon: "\uf084"
    title: "Password attempts"
    description: "Failed attempts before password entry is blocked for 30 seconds"

    control: Component {
      Rectangle {
        width: stepRow.implicitWidth + root.s(12)
        height: root.s(34)
        radius: root.s(Config.uiRadius)
        color: Qt.rgba(1, 1, 1, 0.06)

        RowLayout {
          id: stepRow
          anchors.centerIn: parent
          spacing: root.s(6)

          Rectangle {
            Layout.preferredWidth: root.s(26); Layout.preferredHeight: root.s(26)
            radius: root.s(6)
            color: dec.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
            opacity: root.maxAttempts > 1 ? 1 : 0.35
            Text { anchors.centerIn: parent; text: "\uf053"; font.pixelSize: root.s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text }
            MouseArea {
              id: dec
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: LockLayout.maxAttempts = Math.max(1, LockLayout.maxAttempts - 1)
            }
          }

          Text {
            Layout.preferredWidth: root.s(28)
            horizontalAlignment: Text.AlignHCenter
            text: root.maxAttempts
            font.pixelSize: root.s(12)
            font.weight: Font.Bold
            font.family: root.fontFamily
            color: MatugenColors.text
          }

          Rectangle {
            Layout.preferredWidth: root.s(26); Layout.preferredHeight: root.s(26)
            radius: root.s(6)
            color: inc.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
            opacity: root.maxAttempts < 10 ? 1 : 0.35
            Text { anchors.centerIn: parent; text: "\uf054"; font.pixelSize: root.s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text }
            MouseArea {
              id: inc
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: LockLayout.maxAttempts = Math.min(10, LockLayout.maxAttempts + 1)
            }
          }
        }
      }
    }
  }

  Loader {
    id: bgPicker
    active: false
    parent: root.Window.window ? root.Window.window.contentItem : root
    anchors.fill: parent
    z: 1000
    sourceComponent: FilePickerDialog {
      titleText: "Choose lock background"
      nameFilters: ["png", "jpg", "jpeg", "webp", "bmp"]
      places: [
        { name: "Home", icon: "\udb80\udedc", path: Quickshell.env("HOME") || "" },
        { name: "Downloads", icon: "\udb80\uddda", path: (Quickshell.env("HOME") || "") + "/Downloads" },
        { name: "Pictures", icon: "\udb80\ude4f", path: (Quickshell.env("HOME") || "") + "/Pictures" }
      ]
      onAccepted: (path) => {
        LockLayout.customBgPath = path.replace(/^file:\/\//, "")
        LockLayout.bgMode = "custom"
        bgPicker.active = false
      }
      onCancelled: bgPicker.active = false
    }
  }

  LazyLoader {
    id: editorLoader
    active: false

    LockEditor {
      wallpaperPath: root.previewPath
      onClosed: editorLoader.active = false
    }
  }
}
