import QtQuick
import QtQuick.Layouts
import "../.."
import "../../Singletons"
import "../../Components"

ColumnLayout {
  id: root

  required property var s
  required property var matches
  required property var controller

  // Clock toggles live in Settings.qml
  required property bool showClockSeconds
  required property var toggleClockSeconds
  required property bool clock24h
  required property var toggleClock24h

  readonly property int minWorkspaces: 1
  readonly property int maxWorkspaces: 10
  readonly property int minMediaWidth: 80
  readonly property int maxMediaWidth: 300

  Layout.fillWidth: true
  spacing: s(14)
  focus: true

  function anyMatch(labels) {
    for (let i = 0; i < labels.length; i++)
      if (root.matches(labels[i])) return true
    return false
  }

  // Clicking empty space drops focus from any text field
  TapHandler {
    onTapped: root.forceActiveFocus()
  }

  // ---------- shared building blocks ----------

  component SectionTitle: Text {
    font.pixelSize: root.s(14)
    font.weight: Font.Bold
    font.family: "JetBrainsMono Nerd Font"
    color: MatugenColors.text
  }

  // ---------- Workspaces ----------

  ColumnLayout {
    visible: root.anyMatch(["Workspaces", "Workspace count", "Hide empty workspaces", "Workspace style"])
    Layout.fillWidth: true
    spacing: root.s(8)

    SectionTitle { text: "Workspaces" }

    SettingRow {
      visible: root.matches("Workspace count") || root.matches("Workspaces")
      icon: "󰽿"
      title: "Workspace count"
      description: "Number of workspaces shown on the bar"

      control: Component {
        RowLayout {
          id: wsCountStepper
          spacing: root.s(4)

          function setCount(n) {
            n = Math.max(root.minWorkspaces, Math.min(root.maxWorkspaces, n))
            if (n === Config.workspaceCount) return
            Config.workspaceCount = n
            root.controller.applyWorkspaceCount()
          }

          Rectangle {
            Layout.preferredWidth: root.s(26)
            Layout.preferredHeight: root.s(28)
            radius: root.s(6)
            color: wsDecMa.pressed ? Qt.rgba(1, 1, 1, 0.16) : (wsDecMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08))
            Behavior on color { ColorAnimation { duration: 120 } }
            enabled: Config.workspaceCount > root.minWorkspaces
            opacity: enabled ? 1 : 0.4

            Text { anchors.centerIn: parent; text: "\uf053"; font.pixelSize: root.s(11); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent }
            MouseArea { id: wsDecMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: wsCountStepper.setCount(Config.workspaceCount - 1) }
          }

          Rectangle {
            Layout.preferredWidth: root.s(46)
            Layout.preferredHeight: root.s(28)
            radius: root.s(6)
            color: Qt.rgba(1, 1, 1, wsCountInput.activeFocus ? 0.12 : 0.08)
            border.width: wsCountInput.activeFocus ? 1 : 0
            border.color: MatugenColors.accent
            Behavior on color { ColorAnimation { duration: 120 } }

            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.NoButton
              hoverEnabled: true
              onWheel: (wheel) => {
                wsCountStepper.setCount(Config.workspaceCount + (wheel.angleDelta.y > 0 ? 1 : -1))
                wheel.accepted = true
              }
            }

            TextInput {
              id: wsCountInput
              anchors.fill: parent
              verticalAlignment: TextInput.AlignVCenter
              horizontalAlignment: TextInput.AlignHCenter
              font.pixelSize: root.s(13)
              font.weight: Font.Bold
              font.family: "JetBrainsMono Nerd Font"
              color: MatugenColors.accent
              selectionColor: MatugenColors.accent
              selectedTextColor: MatugenColors.accentText
              text: Config.workspaceCount
              maximumLength: 2
              inputMethodHints: Qt.ImhDigitsOnly

              onActiveFocusChanged: {
                if (activeFocus) {
                  selectAll()
                } else {
                  let n = parseInt(text)
                  if (isNaN(n)) n = Config.workspaceCount
                  wsCountStepper.setCount(n)
                  text = Config.workspaceCount
                }
              }
              onTextChanged: {
                if (!activeFocus) return
                let digits = text.replace(/[^0-9]/g, "")
                if (digits !== text) { text = digits; return }
                if (digits === "") return
                let n = parseInt(digits)
                if (n > root.maxWorkspaces) { text = String(root.maxWorkspaces); return }
                if (n >= root.minWorkspaces) wsCountStepper.setCount(n)
              }
              Keys.onReturnPressed: wsCountInput.focus = false
              Keys.onEnterPressed: wsCountInput.focus = false
              Keys.onEscapePressed: { text = Config.workspaceCount; wsCountInput.focus = false }
            }
          }

          Rectangle {
            Layout.preferredWidth: root.s(26)
            Layout.preferredHeight: root.s(28)
            radius: root.s(6)
            color: wsIncMa.pressed ? Qt.rgba(1, 1, 1, 0.16) : (wsIncMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08))
            Behavior on color { ColorAnimation { duration: 120 } }
            enabled: Config.workspaceCount < root.maxWorkspaces
            opacity: enabled ? 1 : 0.4

            Text { anchors.centerIn: parent; text: "\uf054"; font.pixelSize: root.s(11); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent }
            MouseArea { id: wsIncMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: wsCountStepper.setCount(Config.workspaceCount + 1) }
          }
        }
      }
    }

    SettingRow {
      visible: root.matches("Hide empty workspaces") || root.matches("Workspaces")
      icon: "󰈈"
      title: "Hide empty workspaces"
      description: "Show only occupied workspaces and the active one"

      control: Component {
        ToggleSwitch {
          s: root.s
          checked: Config.hideEmptyWorkspaces
          onToggled: Config.hideEmptyWorkspaces = !Config.hideEmptyWorkspaces
        }
      }
    }

    SettingRow {
      visible: root.matches("Workspace style") || root.matches("Workspaces")
      icon: "󰽿"
      title: "Workspace style"
      description: "Visual style of workspace indicators"

      control: Component {
        SegmentedControl {
          s: root.s
          buttonWidth: 66
          choices: [ { id: "numbers", label: "Numbers" }, { id: "orbs", label: "Orbs" } ]
          current: Config.workspaceStyle
          onPicked: (id) => Config.workspaceStyle = id
        }
      }
    }
  }

  Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

  // ---------- Time & date ----------

  ColumnLayout {
    visible: root.anyMatch(["Time & date clock", "Show date", "Clock seconds show seconds", "Clock time format 12 24 hour", "Time format string"])
    Layout.fillWidth: true
    spacing: root.s(8)

    SectionTitle { text: "Time & date" }

    SettingRow {
      visible: root.anyMatch(["Show date", "Time & date clock"])
      icon: "󰃭"
      title: "Show date"
      description: "Display the date text alongside the clock"

      control: Component {
        ToggleSwitch {
          s: root.s
          checked: Config.showClockDate
          onToggled: Config.showClockDate = !Config.showClockDate
        }
      }
    }

    SettingRow {
      visible: root.anyMatch(["Clock seconds show seconds", "Time & date clock"])
      icon: "󰥔"
      title: "Show seconds in clock"
      description: "Display seconds alongside hours and minutes"

      control: Component {
        ToggleSwitch {
          s: root.s
          checked: root.showClockSeconds
          onToggled: root.toggleClockSeconds()
        }
      }
    }

    SettingRow {
      visible: root.anyMatch(["Clock time format 12 24 hour", "Time & date clock"])
      icon: "󰅐"
      title: "12 or 24 hour clock"
      description: "12-hour or 24-hour clock display"

      control: Component {
        Rectangle {
          width: root.s(70); height: root.s(26); radius: root.s(13)
          color: Qt.rgba(1, 1, 1, 0.08)
          Rectangle {
            width: root.s(33); height: root.s(22); radius: root.s(11)
            anchors.verticalCenter: parent.verticalCenter
            x: root.clock24h ? parent.width - width - root.s(2) : root.s(2)
            color: MatugenColors.accent
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Text { anchors.centerIn: parent; text: root.clock24h ? "24h" : "12h"; font.pixelSize: root.s(10); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.bgBase }
          }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleClock24h() }
        }
      }
    }

    SettingRow {
      visible: root.anyMatch(["Time format string", "Time & date clock"])
      icon: "󰅐"
      title: "Time format"
      description: "Format string (e.g. HH:mm:ss or hh:mm AP). Leave empty to use the options above"

      control: Component {
        Rectangle {
          id: fmtBox
          width: root.s(150); height: root.s(30); radius: root.s(8)
          color: Qt.rgba(1, 1, 1, 0.06)
          border.width: fmtInput.activeFocus ? 1 : 0
          border.color: Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.5)

          readonly property string effectiveFormat:
            (root.clock24h ? "HH" : "hh") + ":mm" + (root.showClockSeconds ? ":ss" : "") + (root.clock24h ? "" : " AP")

          function commit() {
            let f = fmtInput.text.trim()
            if (f !== Config.clockFormat) Config.clockFormat = f
            fmtInput.text = f
          }

          TextInput {
            id: fmtInput
            anchors.fill: parent
            anchors.leftMargin: root.s(10)
            anchors.rightMargin: root.s(10)
            verticalAlignment: TextInput.AlignVCenter
            font.pixelSize: root.s(12)
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.text
            selectionColor: MatugenColors.accent
            selectedTextColor: MatugenColors.accentText
            selectByMouse: true
            clip: true

            onAccepted: { fmtBox.commit(); focus = false }
            onActiveFocusChanged: if (!activeFocus) fmtBox.commit()
            Keys.onEscapePressed: { text = Config.clockFormat; focus = false }

            Component.onCompleted: text = Config.clockFormat

            Connections {
              target: Config
              function onClockFormatChanged() {
                if (!fmtInput.activeFocus) fmtInput.text = Config.clockFormat
              }
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: fmtInput.text.length === 0
              text: fmtBox.effectiveFormat
              font: fmtInput.font
              color: MatugenColors.textDim
            }
          }
        }
      }
    }
  }

  Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

  // ---------- Media ----------

  ColumnLayout {
    visible: root.anyMatch(["Media", "Secondary info", "Media width", "Show icon", "Show controls"])
    Layout.fillWidth: true
    spacing: root.s(8)

    SectionTitle { text: "Media" }

    // Live preview of the media module
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: root.s(64)
      radius: root.s(Config.uiRadius)
      color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)
      clip: true

      RowLayout {
        anchors.centerIn: parent
        spacing: root.s(12)

        Rectangle {
          visible: Config.mediaShowIcon
          Layout.preferredWidth: root.s(36)
          Layout.preferredHeight: root.s(36)
          radius: root.s(Config.uiRadius)
          color: Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16)
          border.width: 1
          border.color: MatugenColors.accent
          Text { anchors.centerIn: parent; text: "󰎇"; font.pixelSize: root.s(16); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent }
        }

        ColumnLayout {
          Layout.preferredWidth: root.s(Config.mediaWidth)
          Layout.maximumWidth: root.s(Config.mediaWidth)
          spacing: root.s(1)
          Behavior on Layout.preferredWidth { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

          Text {
            Layout.fillWidth: true
            text: "Song title"
            elide: Text.ElideRight
            font.pixelSize: root.s(12)
            font.weight: Font.Bold
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.text
          }
          Text {
            Layout.fillWidth: true
            text: Config.mediaSecondaryInfo === "duration" ? "01:24 / 03:45" : "Song author"
            elide: Text.ElideRight
            font.pixelSize: root.s(10)
            font.weight: Font.Bold
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.textDim
          }
        }

        RowLayout {
          visible: Config.mediaShowControls
          spacing: root.s(4)

          Repeater {
            model: ["󰒮", "󰏤", "󰒭"]
            delegate: Rectangle {
              required property string modelData
              Layout.preferredWidth: root.s(28)
              Layout.preferredHeight: root.s(28)
              radius: root.s(6)
              color: Qt.rgba(1, 1, 1, 0.08)
              Text { anchors.centerIn: parent; text: parent.modelData; font.pixelSize: root.s(13); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text }
            }
          }
        }
      }
    }

    SettingRow {
      visible: root.anyMatch(["Secondary info", "Media"])
      icon: "󰅐"
      title: "Secondary info"
      description: "Choose whether to show the song duration or its author"

      control: Component {
        SegmentedControl {
          s: root.s
          buttonWidth: 74
          choices: [ { id: "duration", label: "Duration" }, { id: "author", label: "Author" } ]
          current: Config.mediaSecondaryInfo
          onPicked: (id) => Config.mediaSecondaryInfo = id
        }
      }
    }

    SettingRow {
      visible: root.anyMatch(["Media width", "Media"])
      icon: "󰡍"
      title: "Width"
      description: "Width of the song title area (80px to 300px)"

      control: Component {
        ValueSlider {
          s: root.s
          from: root.minMediaWidth
          to: root.maxMediaWidth
          value: Math.max(root.minMediaWidth, Math.min(root.maxMediaWidth, Config.mediaWidth))
          suffix: "px"
          onMoved: (v) => Config.mediaWidth = v
        }
      }
    }

    SettingRow {
      visible: root.anyMatch(["Show icon", "Media"])
      icon: "󰎇"
      title: "Show icon"
      description: "Display the album art or music icon"

      control: Component {
        ToggleSwitch {
          s: root.s
          checked: Config.mediaShowIcon
          onToggled: Config.mediaShowIcon = !Config.mediaShowIcon
        }
      }
    }

    SettingRow {
      visible: root.anyMatch(["Show controls", "Media"])
      icon: "󰐊"
      title: "Show controls"
      description: "Display the previous, play and next buttons"

      control: Component {
        ToggleSwitch {
          s: root.s
          checked: Config.mediaShowControls
          onToggled: Config.mediaShowControls = !Config.mediaShowControls
        }
      }
    }
  }
}
