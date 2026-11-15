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
  required property string currentWallpaperPath
  required property string wallpaperDir
  required property var setWallpaperDir

  Layout.fillWidth: true
  spacing: s(14)

  // ── Current wallpaper preview ──
  Text { visible: root.matches("Wallpaper"); text: "CURRENT WALLPAPER"; font.pixelSize: s(10); font.weight: Font.Bold; font.family: root.fontFamily; color: MatugenColors.border }

  property string liveWallpaperPath: root.currentWallpaperPath
  property int wallpaperRevision: 0

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
      if (res !== "" && res !== root.liveWallpaperPath) {
        root.liveWallpaperPath = res
        root.wallpaperRevision++
      }
    }
  }

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
      source: root.liveWallpaperPath ? "file://" + root.liveWallpaperPath : ""
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
    ClickButton {
      s: root.s
      variant: "primary"
      icon: "󰸉"
      text: "Select wallpaper"
      buttonHeight: 32
      fontSize: 11
      iconSize: 13
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      anchors.margins: s(12)
      onClicked: Quickshell.execDetached(["qs", "ipc", "call", "wallpaper", "toggle"])
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

  // Wallpaper directory: folder picker icon button + boxed textbox
  SettingRow {
    visible: root.matches("Wallpaper directory")
    icon: "󰉏"
    title: "Wallpaper directory"
    description: "Directory to search for wallpapers"

    control: Component {
      RowLayout {
        spacing: root.s(6)

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
      }
    }
  }

  // Transition controls
  readonly property var transitionDefs: [
    { id: "fade", label: "Fade" },
    { id: "wipe", label: "Wipe" },
    { id: "circle", label: "Circle" },
    { id: "swipe", label: "Swipe" }
  ]

  function enabledSet() { return Config.wallpaperTransitionSet.split(",").filter(x => x.length > 0) }
  function isActive(id) { return Config.wallpaperTransitionMode === "random" || enabledSet().indexOf(id) !== -1 }
  // 0.1 steps up to 1s, 0.5 steps after
  function durStep(v, dir) {
    let st = dir > 0 ? (v < 1 ? 0.1 : 0.5) : (v <= 1 ? 0.1 : 0.5)
    return v + dir * st
  }

  function toggleTransition(id) {
    if (Config.wallpaperTransitionMode === "random") return
    let set = enabledSet()
    let i = set.indexOf(id)
    if (i !== -1) {
      if (set.length === 1) return
      set.splice(i, 1)
    } else {
      set.push(id)
    }
    Config.wallpaperTransitionSet = set.join(",")
  }

  // Duration stepper: 0.1s to 10s. 0.1 steps up to 1s, 0.5 steps after.
  // Sub option row: indented with a thin guide line on the left.
  component SubRow: RowLayout {
    id: subRow
    property string icon: ""
    property string title: ""
    property string description: ""
    property Component control: null
    property bool dimmed: false

    Layout.fillWidth: true
    spacing: root.s(8)
    opacity: dimmed ? 0.45 : 1
    Behavior on opacity { NumberAnimation { duration: 150 } }

    Rectangle {
      Layout.preferredWidth: root.s(2)
      Layout.leftMargin: root.s(8)
      Layout.fillHeight: true
      color: Qt.rgba(1, 1, 1, 0.12)
    }

    SettingRow {
      Layout.fillWidth: true
      icon: subRow.icon
      title: subRow.title
      description: subRow.description
      control: subRow.control
    }
  }

  // Mode header with the random / custom set switch
  Rectangle {
    visible: root.matches("Transition")
    Layout.fillWidth: true
    Layout.preferredHeight: transitionCol.implicitHeight + root.s(20)
    radius: s(Config.uiRadius)
    color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

    ColumnLayout {
      id: transitionCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: root.s(10)
      spacing: root.s(12)

      RowLayout {
        Layout.fillWidth: true
        spacing: root.s(10)

        Text { text: "\udb81\udc50"; font.pixelSize: root.s(22); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: root.s(2)
          Text { text: "Transition"; font.pixelSize: root.s(13); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text }
          Text {
            text: Config.wallpaperTransitionMode === "random"
              ? "Pick randomly from every transition"
              : "Pick randomly from the selected transitions. Click previews to add or remove them"
            font.pixelSize: root.s(11)
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.textDim
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }
        }

        SegmentedControl {
          s: root.s
          choices: [{ id: "random", label: "Random" }, { id: "custom", label: "Custom set" }]
          current: Config.wallpaperTransitionMode
          onPicked: (id) => Config.wallpaperTransitionMode = id
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: root.s(8)

        Repeater {
          model: root.transitionDefs
          delegate: TransitionTile {
            required property var modelData
            tid: modelData.id
            label: modelData.label
            wallpaperPath: root.liveWallpaperPath
            selected: Config.wallpaperTransitionMode !== "random" && root.isActive(modelData.id)
            interactive: Config.wallpaperTransitionMode !== "random"
            onPicked: root.toggleTransition(modelData.id)
          }
        }
      }
    }
  }

  SettingRow {
    visible: root.matches("Fade")
    opacity: root.isActive("fade") ? 1 : 0.45
    icon: "\udb80\udd9b"
    title: "Fade"
    description: "Cross fade smoothly into the new wallpaper"
    control: Component {
      Stepper { s: root.s; value: Config.wallpaperFadeDuration; from: 0.1; to: 10; decimals: 1; suffix: "s"; boxWidth: 64; stepFn: root.durStep; onMoved: (v) => Config.wallpaperFadeDuration = v }
    }
  }

  SettingRow {
    visible: root.matches("Wipe")
    opacity: root.isActive("wipe") ? 1 : 0.45
    icon: "\udb80\udf65"
    title: "Wipe"
    description: "Sweep a line across the screen"
    control: Component {
      Stepper { s: root.s; value: Config.wallpaperWipeDuration; from: 0.1; to: 10; decimals: 1; suffix: "s"; boxWidth: 64; stepFn: root.durStep; onMoved: (v) => Config.wallpaperWipeDuration = v }
    }
  }

  SubRow {
    visible: root.matches("Wipe")
    dimmed: !root.isActive("wipe")
    icon: "\udb80\udf65"
    title: "Orientation"
    description: "Axis the wipe opens along"
    control: Component {
      SegmentedControl {
        s: root.s
        choices: [{ id: "random", label: "Random" }, { id: "horizontal", label: "Horizontal" }, { id: "vertical", label: "Vertical" }]
        current: Config.wallpaperWipeOrientation
        onPicked: (id) => Config.wallpaperWipeOrientation = id
      }
    }
  }

  SettingRow {
    visible: root.matches("Circle")
    opacity: root.isActive("circle") ? 1 : 0.45
    icon: "\uf10c"
    title: "Circle"
    description: "Grow a circle outward until it covers the screen"
    control: Component {
      Stepper { s: root.s; value: Config.wallpaperCircleDuration; from: 0.1; to: 10; decimals: 1; suffix: "s"; boxWidth: 64; stepFn: root.durStep; onMoved: (v) => Config.wallpaperCircleDuration = v }
    }
  }

  SubRow {
    visible: root.matches("Circle")
    dimmed: !root.isActive("circle")
    icon: "\udb80\udf6d"
    title: "Origin"
    description: "Where the circle starts. The desktop menu always starts it where you clicked"
    control: Component {
      SegmentedControl {
        s: root.s
        choices: [{ id: "random", label: "Random" }, { id: "center", label: "Center" }]
        current: Config.wallpaperCircleOrigin
        onPicked: (id) => Config.wallpaperCircleOrigin = id
      }
    }
  }

  SettingRow {
    visible: root.matches("Swipe")
    opacity: root.isActive("swipe") ? 1 : 0.45
    icon: "\udb80\udc56"
    title: "Swipe"
    description: "Sweep across the screen from an edge or a corner"
    control: Component {
      Stepper { s: root.s; value: Config.wallpaperSwipeDuration; from: 0.1; to: 10; decimals: 1; suffix: "s"; boxWidth: 64; stepFn: root.durStep; onMoved: (v) => Config.wallpaperSwipeDuration = v }
    }
  }

  SubRow {
    visible: root.matches("Swipe")
    dimmed: !root.isActive("swipe")
    icon: "\udb80\udde4"
    title: "Direction"
    description: "Edge or corner the swipe starts from"
    control: Component {
      Item {
        id: dirItem
        implicitWidth: root.s(220)
        implicitHeight: root.s(34)

        readonly property var choices: [
          { id: "random", label: "Random" },
          { id: "left", label: "Left" },
          { id: "right", label: "Right" },
          { id: "top", label: "Top" },
          { id: "bottom", label: "Bottom" },
          { id: "top-left", label: "Top left" },
          { id: "top-right", label: "Top right" },
          { id: "bottom-left", label: "Bottom left" },
          { id: "bottom-right", label: "Bottom right" }
        ]
        function labelFor(id) {
          for (let i = 0; i < choices.length; i++) if (choices[i].id === id) return choices[i].label
          return "Random"
        }

        Dropdown {
          s: root.s
          anchors.fill: parent
          boxWidth: 220
          options: dirItem.choices
          labelKey: "label"
          currentIndex: Math.max(0, dirItem.choices.findIndex(c => c.id === Config.wallpaperSwipeDirection))
          onPicked: (i) => Config.wallpaperSwipeDirection = dirItem.choices[i].id
        }
      }
    }
  }
}
