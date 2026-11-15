import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import ".."
import "../Singletons"
import "../weather"
import "../Components"

ColumnLayout {
  id: root

  property alias weatherLocationInput: weatherLocationInput
  property alias layoutDropdown: layoutDropdown
  required property var s
  required property var matches

  // Temperature
  required property bool useFahrenheit
  required property var toggleTempUnit

  // Weather polling + auto location
  required property int weatherPollMinutes
  required property var pollLabel
  required property var stepWeatherPoll
  required property string weatherLocationMode
  required property var autoDetectLocation
  required property var setWeatherCoords

  property bool locationEditOpen: false
  property string editMode: "city"
  property string coordError: ""

  function applyCoords() {
    let la = parseFloat(latInput.text)
    let lo = parseFloat(lonInput.text)
    if (isNaN(la) || isNaN(lo)) { root.coordError = "enter both latitude and longitude"; return }
    if (la < -90 || la > 90) { root.coordError = "latitude must be between -90 and 90"; return }
    if (lo < -180 || lo > 180) { root.coordError = "longitude must be between -180 and 180"; return }
    root.coordError = ""
    root.setWeatherCoords(la, lo)
    root.locationEditOpen = false
  }

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

  // Profile
  SettingRow {
    visible: root.matches("Profile picture")
    icon: "󰋩"
    title: "Profile picture"
    description: "Choose your profile picture"

    control: Component {
      RowLayout {
        spacing: root.s(8)

        // Editable path field
        Rectangle {
          id: profilePicField
          Layout.preferredWidth: root.s(190)
          Layout.preferredHeight: root.s(30)
          radius: root.s(8)
          color: Qt.rgba(1, 1, 1, 0.06)
          border.width: profilePicInput.activeFocus ? 1 : 0
          border.color: Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.5)

          function commit() {
            let p = profilePicInput.text.trim()
            if (p.startsWith("file://")) p = p.substring(7)
            if (p !== root.profilePicturePath) root.setProfilePicturePath(p)
            profilePicInput.text = p
          }

          TextInput {
            id: profilePicInput
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: root.s(10)
            anchors.rightMargin: root.s(28)
            font.pixelSize: root.s(11)
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.text
            selectionColor: MatugenColors.accent
            selectedTextColor: MatugenColors.accentText
            selectByMouse: true
            clip: true

            onAccepted: { profilePicField.commit(); focus = false }
            onActiveFocusChanged: if (!activeFocus) profilePicField.commit()
            Keys.onEscapePressed: { text = root.profilePicturePath; focus = false }

            // Keep the field in sync when the saved path changes from elsewhere
            // (for example after picking a file in the dialog).
            Connections {
              target: root
              function onProfilePicturePathChanged() {
                if (!profilePicInput.activeFocus) profilePicInput.text = root.profilePicturePath
              }
            }
            Component.onCompleted: text = root.profilePicturePath

            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: profilePicInput.text.length === 0 && !profilePicInput.activeFocus
              text: "no file selected"
              font: profilePicInput.font
              color: MatugenColors.textDim
            }
          }

          Text {
            id: profilePicChevron
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: root.s(8)
            text: "󰅀"
            font.pixelSize: root.s(11)
            font.family: "JetBrainsMono Nerd Font"
            color: profilePicChevronMa.containsMouse ? MatugenColors.accent : MatugenColors.textDim
            Behavior on color { ColorAnimation { duration: 150 } }

            MouseArea {
              id: profilePicChevronMa
              anchors.fill: parent
              anchors.margins: root.s(-6)
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: profilePicPickerLoader.active = true
            }
          }
        }

        ClickButton {
          s: root.s
          variant: "primary"
          icon: "󰉖"
          text: "Select"
          onClicked: profilePicPickerLoader.active = true
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
    visible: active
    z: 1000
    parent: root.Window.window ? root.Window.window.contentItem : root
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

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

  // Weather polling
  SettingRow {
    visible: root.matches("Weather polling")
    icon: "󰔟"
    title: "Weather polling"
    description: "How often the weather is refreshed"

    control: Component {
      RowLayout {
        spacing: root.s(6)

        IconButton { s: root.s; icon: "󰅁"; onClicked: root.stepWeatherPoll(-1) }

        Text {
          Layout.preferredWidth: root.s(56)
          horizontalAlignment: Text.AlignHCenter
          text: root.pollLabel(root.weatherPollMinutes)
          font.pixelSize: root.s(12); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"
          color: MatugenColors.accent
        }

        IconButton { s: root.s; icon: "󰅂"; onClicked: root.stepWeatherPoll(1) }
      }
    }
  }

  // Location
  ColumnLayout {
    visible: root.matches("Location") || root.matches("Weather location")
    Layout.fillWidth: true
    spacing: s(4)

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.max(s(48), locHeaderRow.implicitHeight + s(20))
      radius: s(Config.uiRadius)
      color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

      RowLayout {
        id: locHeaderRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: s(10)
        spacing: s(10)

        Text { text: "󰍎"; font.pixelSize: s(22); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent; Layout.alignment: Qt.AlignVCenter }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: s(2)

          Text { text: "Location"; font.pixelSize: s(13); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text }
          Text { text: "Configure weather location"; font.pixelSize: s(11); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textDim }
          Text {
            Layout.fillWidth: true
            text: (Weather.locationName && Weather.locationName !== "--") ? Weather.locationName : "No location set"
            font.pixelSize: s(12); font.weight: Font.DemiBold; font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.accent
            elide: Text.ElideRight
          }
        }

        // Auto-detect (IP, fetched once)
        ClickButton {
          s: root.s
          active: root.weatherLocationMode === "auto"
          icon: "󰆋"
          text: Weather.ipLookupBusy ? "Detecting..." : "Auto-detect"
          onClicked: root.autoDetectLocation()
        }

        // Pencil: opens the manual entry dropdown
        IconButton {
          s: root.s
          size: 30
          icon: "󰏫"
          active: root.locationEditOpen
          onClicked: root.locationEditOpen = !root.locationEditOpen
        }
      }
    }

    // Manual entry dropdown
    Rectangle {
      Layout.fillWidth: true
      visible: root.locationEditOpen
      implicitHeight: editCol.implicitHeight + s(20)
      radius: s(Config.uiRadius)
      color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, 0.08)

      ColumnLayout {
        id: editCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: s(10)
        spacing: s(8)

        RowLayout {
          spacing: s(6)
          Repeater {
            model: [ { key: "city", label: "City" }, { key: "coords", label: "Coordinates" } ]
            delegate: Rectangle {
              Layout.preferredWidth: tabText.implicitWidth + s(20)
              Layout.preferredHeight: s(26)
              radius: s(6)
              property bool sel: root.editMode === modelData.key
              color: sel ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)
              Text { id: tabText; anchors.centerIn: parent; text: modelData.label; font.pixelSize: s(11); font.weight: Font.DemiBold; font.family: "JetBrainsMono Nerd Font"; color: parent.sel ? MatugenColors.accent : MatugenColors.textDim }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.editMode = modelData.key }
            }
          }
        }

        // ---- City by text ----
        ColumnLayout {
          visible: root.editMode === "city"
          Layout.fillWidth: true
          spacing: s(4)

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: s(34)
            radius: s(8)
            color: Qt.rgba(1, 1, 1, 0.06)
            border.width: weatherLocationInput.activeFocus ? 1 : 0
            border.color: root.locationConfirmedValid
              ? Qt.rgba(0.4, 0.85, 0.5, 0.6)
              : Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.5)

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: s(10)
              anchors.rightMargin: s(10)
              spacing: s(8)

              Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                TextInput {
                  id: weatherLocationInput
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  font.pixelSize: s(12)
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.text
                  clip: true

                  // Letters, spaces and normal place-name punctuation only
                  validator: RegularExpressionValidator { regularExpression: /^[\p{L}\s'.,-]*$/u }

                  onTextChanged: root.queueLocationLookup()

                  onAccepted: {
                    if (root.locationSuggestions.length > 0) {
                      root.pickLocationSuggestion(root.locationSuggestions[0].label)
                    } else if (text.trim().length > 0) {
                      root.setWeatherLocation(text)
                    }
                    root.locationEditOpen = false
                  }
                  onActiveFocusChanged: {
                    // Only commit real edits, so merely focusing doesn't flip the mode to city
                    if (!activeFocus) {
                      if (text.trim().length > 0 && text.trim() !== root.weatherLocation) root.setWeatherLocation(text)
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
                  text: "enter city, e.g. New York, United States"
                  font.pixelSize: s(12)
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.textDim
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
            radius: s(8)
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
                    onClicked: { root.pickLocationSuggestion(modelData.label); root.locationEditOpen = false }
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

        // ---- Latitude / longitude ----
        ColumnLayout {
          visible: root.editMode === "coords"
          Layout.fillWidth: true
          spacing: s(6)

          RowLayout {
            Layout.fillWidth: true
            spacing: s(8)

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              Layout.preferredHeight: s(34)
              radius: s(8)
              color: Qt.rgba(1, 1, 1, 0.06)
              border.width: latInput.activeFocus ? 1 : 0
              border.color: Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.5)

              TextInput {
                id: latInput
                anchors.fill: parent
                anchors.leftMargin: s(10)
                anchors.rightMargin: s(10)
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: s(12)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.text
                clip: true
                validator: RegularExpressionValidator { regularExpression: /^-?\d{0,3}(\.\d{0,6})?$/ }
                onTextChanged: root.coordError = ""
                onAccepted: lonInput.forceActiveFocus()
                Text { anchors.verticalCenter: parent.verticalCenter; visible: latInput.text.length === 0; text: "latitude, e.g. 40.7128"; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textDim }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              Layout.preferredHeight: s(34)
              radius: s(8)
              color: Qt.rgba(1, 1, 1, 0.06)
              border.width: lonInput.activeFocus ? 1 : 0
              border.color: Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.5)

              TextInput {
                id: lonInput
                anchors.fill: parent
                anchors.leftMargin: s(10)
                anchors.rightMargin: s(10)
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: s(12)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.text
                clip: true
                validator: RegularExpressionValidator { regularExpression: /^-?\d{0,3}(\.\d{0,6})?$/ }
                onTextChanged: root.coordError = ""
                onAccepted: root.applyCoords()
                Text { anchors.verticalCenter: parent.verticalCenter; visible: lonInput.text.length === 0; text: "longitude, e.g. -74.0060"; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textDim }
              }
            }

            ClickButton {
              s: root.s
              variant: "primary"
              buttonHeight: 34
              text: "Apply"
              onClicked: root.applyCoords()
            }
          }

          Text {
            Layout.fillWidth: true
            visible: root.coordError.length > 0
            text: root.coordError
            font.pixelSize: s(10)
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.error
            wrapMode: Text.WordWrap
          }
        }
      }
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

  ClickButton {
    id: addLayoutBtn
    s: root.s
    variant: "ghost"
    fill: true
    buttonHeight: 36
    text: "+ Add layout"
    onClicked: layoutDropdown.visible = !layoutDropdown.visible
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
      Dropdown {
        s: root.s
        boxWidth: 170
        options: root.switchOptionChoices
        labelKey: "label"
        text: root.switchOptionChoices.some(c => c.value === root.layoutSwitchOption) ? "" : "Custom"
        currentIndex: root.switchOptionChoices.findIndex(c => c.value === root.layoutSwitchOption)
        onPicked: (i) => root.setSwitchOption(root.switchOptionChoices[i].value)
      }
    }
  }
}
