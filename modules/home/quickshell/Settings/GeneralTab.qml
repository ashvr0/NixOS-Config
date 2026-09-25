import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import ".."
import "../Singletons"

ColumnLayout {
  id: root

  property alias weatherLocationInput: weatherLocationInput
  property alias layoutDropdown: layoutDropdown
  required property var s
  required property var matches

  // Temperature
  required property bool useFahrenheit
  required property var toggleTempUnit

  // Weather
  required property string weatherLocation
  required property var setWeatherLocation
  required property var queueLocationLookup
  required property var pickLocationSuggestion
  required property var locationSuggestions
  required property bool locationLookupBusy
  property bool locationConfirmedValid: false

  // Keyboard layouts
  required property var currentLayouts
  required property var removeLayout
  required property var availableLayoutCodes
  required property var addLayout

  // Switch key
  required property var switchOptionChoices
  required property string layoutSwitchOption
  required property var setSwitchOption

  // Profile picture
  required property string profilePicturePath
  required property var setProfilePicturePath

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
      }
    }
  }
  // Profile
  SettingRow {
    visible: root.matches("Profile picture")
    icon: "󰋩"
    title: "Profile picture"
    description: "Choose your profile picture"

    control: Component {
      RowLayout {
        spacing: root.s(8)

        Rectangle {
          Layout.preferredWidth: root.s(190)
          Layout.preferredHeight: root.s(30)
          radius: root.s(8)
          color: Qt.rgba(1, 1, 1, 0.06)

          Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: root.s(10)
            anchors.rightMargin: root.s(28)
            text: root.profilePicturePath !== "" ? root.profilePicturePath : "no file selected"
            font.pixelSize: root.s(11)
            font.family: "JetBrainsMono Nerd Font"
            color: root.profilePicturePath !== "" ? MatugenColors.textDim : MatugenColors.textDim
            elide: Text.ElideMiddle
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: root.s(8)
            text: "󰅀"
            font.pixelSize: root.s(11)
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.textDim
          }
        }

        Rectangle {
          id: profilePicSelectBtn
          Layout.preferredWidth: profilePicSelectRow.implicitWidth + root.s(20)
          Layout.preferredHeight: root.s(30)
          radius: root.s(8)
          color: profilePicSelectMa.containsMouse ? Qt.lighter(MatugenColors.accent, 1.1) : MatugenColors.accent
          Behavior on color { ColorAnimation { duration: 150 } }

          RowLayout {
            id: profilePicSelectRow
            anchors.centerIn: parent
            spacing: root.s(6)
            Text { text: "󰉖"; font.pixelSize: root.s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accentText }
            Text { text: "Select"; font.pixelSize: root.s(12); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accentText }
          }

          MouseArea {
            id: profilePicSelectMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: profilePicPickerLoader.active = true
          }
        }

        Rectangle {
          id: profilePicPreviewFrame
          Layout.preferredWidth: root.s(72)
          Layout.preferredHeight: root.s(72)
          radius: root.s(Config.uiRadius)
          color: Qt.rgba(1, 1, 1, 0.06)
          border.width: 1
          border.color: Qt.rgba(1, 1, 1, 0.1)

          Rectangle {
            id: profilePicMask
            anchors.fill: parent
            radius: root.s(Config.uiRadius)
            color: "black"
            visible: false
            layer.enabled: true
          }

          Loader {
            id: profilePicImgLoader
            anchors.fill: parent
            visible: false
            active: root.profilePicturePath !== ""
            sourceComponent: Image {
              source: root.profilePicturePath !== "" ? "file://" + root.profilePicturePath : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              cache: false
            }
          }

          MultiEffect {
            anchors.fill: parent
            source: profilePicImgLoader.item
            maskEnabled: true
            maskSource: profilePicMask
            visible: root.profilePicturePath !== ""
          }

          Text {
            anchors.centerIn: parent
            visible: root.profilePicturePath === ""
            text: "󰀄"
            font.pixelSize: root.s(22)
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.textDim
          }
        }
      }
    }
  }

  Loader {
  id: profilePicPickerLoader
  active: false
  z: 1000
  parent: root.Window.window ? root.Window.window.contentItem : root
  anchors.fill: parent ? parent : undefined

  sourceComponent: FilePickerDialog {
    titleText: "Choose profile picture"
    nameFilters: ["png", "jpg", "jpeg", "webp", "bmp", "gif"]
    places: [
      { name: "Home", icon: "󰋜", path: Quickshell.env("HOME") || "" },
      { name: "Downloads", icon: "󰇚", path: (Quickshell.env("HOME") || "") + "/Downloads" },
      { name: "Pictures", icon: "󰉏", path: (Quickshell.env("HOME") || "") + "/Pictures" },
    ]
    onAccepted: function(path) {
      root.setProfilePicturePath(path)
      profilePicPickerLoader.active = false
    }
    onCancelled: profilePicPickerLoader.active = false
  }
}

  // Weather
  SettingRow {
    visible: root.matches("Temperature unit")
    icon: "󰔏"
    title: "Temperature unit"
    description: "Choose between Celsius and Fahrenheit"

    control: Component {
      Rectangle {
        width: root.s(70); height: root.s(26); radius: root.s(13)
        color: Qt.rgba(1, 1, 1, 0.08)
        Rectangle {
          width: root.s(33); height: root.s(22); radius: root.s(11)
          anchors.verticalCenter: parent.verticalCenter
          x: root.useFahrenheit ? parent.width - width - root.s(2) : root.s(2)
          color: MatugenColors.accent
          Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
          Text { anchors.centerIn: parent; text: root.useFahrenheit ? "°F" : "°C"; font.pixelSize: root.s(10); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.bgBase }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleTempUnit() }
      }
    }
  }

  ColumnLayout {
    visible: root.matches("Weather location")
    Layout.fillWidth: true
    spacing: s(4)

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: s(48)
      radius: s(Config.uiRadius)
      color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)
      border.width: weatherLocationInput.activeFocus ? 1 : 0
      border.color: root.locationConfirmedValid
        ? Qt.rgba(0.4, 0.85, 0.5, 0.6)
        : Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.5)

      RowLayout {
        anchors.fill: parent
        anchors.margins: s(10)
        spacing: s(8)

        Text { text: "󰖐"; font.pixelSize: s(22); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: s(2)

          Text { text: "Weather location"; font.pixelSize: s(13); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text }

          Item {
            Layout.fillWidth: true
            implicitHeight: weatherLocationInput.implicitHeight

            TextInput {
              id: weatherLocationInput
              anchors.left: parent.left
              anchors.right: parent.right
              verticalAlignment: TextInput.AlignVCenter
              font.pixelSize: s(12)
              font.family: "JetBrainsMono Nerd Font"
              color: MatugenColors.textDim
              clip: true

              // Reject digits and stray symbols at input time; only letters,
              // spaces, and normal place-name punctuation are accepted.
              validator: RegularExpressionValidator { regularExpression: /^[\p{L}\s'.,-]*$/u }

              onTextChanged: root.queueLocationLookup()

              onAccepted: {
                if (root.locationSuggestions.length > 0) {
                  root.pickLocationSuggestion(root.locationSuggestions[0].label)
                } else {
                  root.setWeatherLocation(text)
                }
              }
              onActiveFocusChanged: {
                if (!activeFocus) {
                  root.setWeatherLocation(text)
                  root.locationSuggestions = []
                }
              }

              Connections {
                target: root
                function onWeatherLocationChanged() {
                  if (!weatherLocationInput.activeFocus) weatherLocationInput.text = root.weatherLocation
                }
              }
              Component.onCompleted: {
                text = root.weatherLocation
                root.locationConfirmedValid = text.trim().length > 0
              }
            }

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              visible: weatherLocationInput.text.length === 0 && !weatherLocationInput.activeFocus
              text: "enter location, e.g. Berlin, Germany"
              font.pixelSize: s(12)
              font.family: "JetBrainsMono Nerd Font"
              color: MatugenColors.textDim
            }
          }
        }

        Text {
          visible: root.locationLookupBusy
          text: "…"
          font.pixelSize: s(13)
          font.family: "JetBrainsMono Nerd Font"
          color: MatugenColors.textDim
        }

        Text {
          visible: !root.locationLookupBusy && root.locationConfirmedValid && weatherLocationInput.text.length > 0
          text: "󰄬"
          font.pixelSize: s(13)
          font.family: "JetBrainsMono Nerd Font"
          color: Qt.rgba(0.4, 0.85, 0.5, 1)
        }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      visible: weatherLocationInput.activeFocus && root.locationSuggestions.length > 0
      implicitHeight: suggestionsCol.implicitHeight + s(8)
      radius: s(Config.uiRadius)
      color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.95)
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, 0.08)

      ColumnLayout {
        id: suggestionsCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: s(4)
        spacing: s(2)

        Repeater {
          model: root.locationSuggestions
          delegate: Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: s(28)
            radius: s(5)
            color: suggestionMa.containsMouse ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16) : "transparent"

            Text {
              anchors.left: parent.left
              anchors.leftMargin: s(8)
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.label
              font.pixelSize: s(11)
              font.family: "JetBrainsMono Nerd Font"
              color: MatugenColors.text
            }

            MouseArea {
              id: suggestionMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.pickLocationSuggestion(modelData.label)
            }
          }
        }
      }
    }

    Text {
      Layout.fillWidth: true
      visible: weatherLocationInput.activeFocus && !root.locationLookupBusy &&
               weatherLocationInput.text.trim().length >= 2 && root.locationSuggestions.length === 0
      text: "no matching location found"
      font.pixelSize: s(10)
      font.family: "JetBrainsMono Nerd Font"
      color: MatugenColors.textDim
      wrapMode: Text.WordWrap
    }
  }

// Keyboard Layouts
  Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

  Text { text: "KEYBOARD LAYOUTS"; font.pixelSize: s(10); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.border }

  Flow {
    Layout.fillWidth: true
    spacing: s(6)
    
    Repeater {
      model: root.currentLayouts
      Rectangle {
      width: layoutChipRow.implicitWidth + s(20)
      height: s(28)
      radius: s(6)
      color: MatugenColors.bgElevated
      border.color: Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.4)
      border.width: 1
      
      RowLayout {
        id: layoutChipRow
        anchors.centerIn: parent
        spacing: s(6)

        Text { 
          text: modelData
          font.pixelSize: s(12)
          font.weight: Font.Bold
          font.family: "JetBrainsMono Nerd Font"
          color: MatugenColors.text 
        }
        
        Text {
          text: "✖"
          font.pixelSize: s(11)
          font.family: "JetBrainsMono Nerd Font"
          color: chipRemMa.containsMouse ? MatugenColors.accent : MatugenColors.textDim
          Behavior on color { ColorAnimation { duration: 150 } }
          MouseArea { id: chipRemMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.removeLayout(modelData) }
          }
        }
      }
    }
  }

  Rectangle {
    id: addLayoutBtn
    Layout.fillWidth: true
    Layout.preferredHeight: s(36)
    radius: s(Config.uiRadius)
    color: addLayoutMa.containsMouse || layoutDropdown.visible ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16) : Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)
    Behavior on color { ColorAnimation { duration: 150 } }

    RowLayout {
      anchors.centerIn: parent
      spacing: s(6)
      Text { text: "+"; font.pixelSize: s(13); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text }
      Text { text: "Add layout"; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text }
    }

    MouseArea { id: addLayoutMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: layoutDropdown.visible = !layoutDropdown.visible }
  }

  Rectangle {
    id: layoutDropdown
    Layout.fillWidth: true
    visible: false
    Layout.preferredHeight: visible ? s(220) : 0
    radius: s(Config.uiRadius)
    clip: true
    color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.6)
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: s(8)
      spacing: s(6)

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: s(30)
        radius: s(6)
        color: Qt.rgba(1, 1, 1, 0.06)
        TextInput {
          id: layoutSearchInput
          anchors.fill: parent
          anchors.margins: s(8)
          verticalAlignment: TextInput.AlignVCenter
          font.pixelSize: s(12)
          font.family: "JetBrainsMono Nerd Font"
          color: MatugenColors.text
          clip: true
          Text {
            text: "Search layout code..."
            color: MatugenColors.textDim
            visible: !parent.text
            font: parent.font
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: root.availableLayoutCodes.filter(c => c.toLowerCase().includes(layoutSearchInput.text.toLowerCase()))
        delegate: Rectangle {
          width: ListView.view.width
          height: s(28)
          radius: s(6)
          color: layoutItemMa.containsMouse ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16) : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }
          Text {
            anchors.left: parent.left
            anchors.leftMargin: s(8)
            anchors.verticalCenter: parent.verticalCenter
            text: modelData
            font.pixelSize: s(12)
            font.family: "JetBrainsMono Nerd Font"
            color: root.currentLayouts.includes(modelData) ? MatugenColors.accent : MatugenColors.text
          }
          MouseArea {
            id: layoutItemMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.addLayout(modelData); layoutDropdown.visible = false; layoutSearchInput.text = "" }
          }
        }
      }
    }
  }

  SettingRow {
    icon: "󰌌"
    title: "Layout switch key"
    description: "Key combination used to switch keyboard layouts"

   control: Component {
  RowLayout {
    id: switchOptionRow
    spacing: root.s(8)

    Text {
      text: {
        let found = root.switchOptionChoices.find(function(c) { return c.value === root.layoutSwitchOption })
        return found ? found.label : "Custom"
      }
      font.pixelSize: root.s(12)
      font.weight: Font.Bold
      font.family: "JetBrainsMono Nerd Font"
      color: MatugenColors.accent
    }

    Text {
      text: switchDropdown.visible ? "󰅃" : "󰅀"
      font.pixelSize: root.s(13)
      font.family: "JetBrainsMono Nerd Font"
      color: switchOptMa.containsMouse ? MatugenColors.accent : MatugenColors.textDim
      Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
      id: switchOptMa
      anchors.fill: parent
      anchors.margins: root.s(-6)
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: switchDropdown.visible = !switchDropdown.visible
    }
  }
}
  }

  Rectangle {
    id: switchDropdown
    visible: false
    Layout.fillWidth: true
    height: visible ? (root.switchOptionChoices.length * 30 + 12) : 0
    radius: s(Config.uiRadius)
    clip: true
    color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.6)
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1
    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: s(6)
      spacing: s(2)

      Repeater {
        model: root.switchOptionChoices
        delegate: Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: s(28)
          radius: s(6)
          color: switchItemMa.containsMouse ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16) : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }

          Text {
            anchors.left: parent.left
            anchors.leftMargin: s(8)
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.label
            font.pixelSize: s(12)
            font.family: "JetBrainsMono Nerd Font"
            color: root.layoutSwitchOption === modelData.value ? MatugenColors.accent : MatugenColors.text
          }

          MouseArea {
            id: switchItemMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.setSwitchOption(modelData.value); switchDropdown.visible = false }
          }
        }
      }
    }
  }
}
