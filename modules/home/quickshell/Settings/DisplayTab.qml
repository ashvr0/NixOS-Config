import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."
import "../Singletons"
import "../Components"

ColumnLayout {
  id: root
  required property var s
  required property var matches
  required property var fontFamily
  required property var menuOpenSetter
  required property var monitorsModel
  required property int resDropdownIdx
  required property var setResDropdownIdx
  required property var resLabel
  required property var commonResolutions
  required property var validScalesForResolution
  required property var setMonitorRes
  required property var stepRefreshRate
  required property var ratesForRes
  required property var setMonitorRate
  required property var setMonitorScale
  required property var transformChoices
  required property var setMonitorTransform
  required property string nightLightMode
  required property string nightLightFrom
  required property string nightLightTo
  required property var nightLightModeChoices
  required property var setNightLightMode
  required property var setNightLightFrom
  required property var setNightLightTo
  required property int autoLockSeconds
  required property var autoLockChoices
  required property var setAutoLockSeconds
  property int nightLightTemp: 50
  property var setNightLightTemp: function(v) { root.nightLightTemp = v }
  property int orientationDropdownIdx: -1
  property bool autoLockDropdownOpen: false
  property bool nightLightScheduleOpen: root.nightLightMode === "Schedule"

  Layout.fillWidth: true
  spacing: s(14)

  // ---------------- SHARED COMPONENTS ----------------

  // choices: [{ label: string, selected: bool }]
  // ---------------- DISPLAYS ----------------
  Repeater {
    model: root.monitorsModel
    delegate: Rectangle {
      id: monitorCard
      Layout.fillWidth: true
      implicitHeight: monCol.implicitHeight + s(20)
      radius: s(Config.uiRadius)
      color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

      readonly property int monitorIndex: index

      ColumnLayout {
        id: monCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: s(10)
        spacing: s(6)

        Item {
          id: previewArea
          Layout.fillWidth: true
          Layout.preferredHeight: s(190)

          readonly property bool rotated: [1, 3, 5, 7].indexOf(model.transform) >= 0
          readonly property real aspect: {
            const a = model.width / Math.max(1, model.height)
            return rotated ? 1 / a : a
          }
          readonly property real standH: s(14)
          readonly property real maxW: Math.min(width * 0.85, s(460))
          readonly property real maxH: height - standH - s(8)
          readonly property real pw: Math.min(maxW, maxH * aspect)
          readonly property real ph: pw / aspect

          Rectangle {
            id: monitorPreview
            width: previewArea.pw
            height: previewArea.ph
            x: (previewArea.width - width) / 2
            y: (previewArea.height - height - previewArea.standH) / 2
            radius: s(8)
            color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.9)
            border.color: Qt.rgba(1, 1, 1, 0.25)
            border.width: 2
            clip: true

            ColumnLayout {
              anchors.centerIn: parent
              spacing: s(3)

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "󰍹"
                font.pixelSize: s(20)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.text
              }
              Text {
                Layout.alignment: Qt.AlignHCenter
                text: model.name
                font.pixelSize: s(12)
                font.weight: Font.Bold
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.text
              }
              Text {
                Layout.alignment: Qt.AlignHCenter
                text: model.width + "x" + model.height + " @ " + model.refreshRate.toFixed(0) + "Hz"
                font.pixelSize: s(9)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.textDim
              }
            }
          }

          // stand neck
          Rectangle {
            anchors.horizontalCenter: monitorPreview.horizontalCenter
            anchors.top: monitorPreview.bottom
            width: s(6)
            height: s(6)
            color: Qt.rgba(1, 1, 1, 0.25)
          }
          // stand base
          Rectangle {
            anchors.horizontalCenter: monitorPreview.horizontalCenter
            anchors.top: monitorPreview.bottom
            anchors.topMargin: s(6)
            width: Math.max(s(40), monitorPreview.width * 0.25)
            height: s(6)
            radius: s(3)
            color: Qt.rgba(1, 1, 1, 0.25)
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }

        // ---- Resolution ----
        SettingRow {
          flat: true
          icon: "\uf108"
          title: "Resolution"
          description: "Screen size in pixels"

          control: Component {
            Dropdown {
              s: root.s
              boxWidth: 130
              text: model.width + "x" + model.height
              options: root.commonResolutions.map(r => r.w + "x" + r.h)
              currentIndex: root.commonResolutions.findIndex(r => r.w === model.width && r.h === model.height)
              onPicked: (i) => {
                const r = root.commonResolutions[i]
                root.setMonitorRes(monitorCard.monitorIndex, r.w, r.h)
              }
            }
          }
        }

        // ---- Refresh rate ----
        SettingRow {
          flat: true
          icon: "\uf021"
          title: "Refresh rate"
          description: "How many times per second the screen updates"

          control: Component {
            Stepper {
              s: root.s
              id: rateStepper
              readonly property var availRates: (model ? root.ratesForRes(model.availableModes, model.width, model.height) : [60]) || [60]
              readonly property int curIdx: availRates.indexOf(model.refreshRate)
              value: Math.max(0, curIdx)
              from: 0
              to: availRates.length - 1
              boxWidth: 72
              valueText: model.refreshRate.toFixed(0) + "Hz"
              onMoved: (v) => { if (availRates[v] !== undefined) root.setMonitorRate(monitorCard.monitorIndex, availRates[v]) }
            }
          }
        }

        // ---- Scale ----
        SettingRow {
          flat: true
          icon: "\uf065"
          title: "Scale"
          description: "Make everything bigger or smaller"

          control: Component {
            Stepper {
              s: root.s
              id: scaleStepper
              readonly property var validScales: root.validScalesForResolution(model.width, model.height)
              readonly property int curIdx: validScales.reduce((best, v, idx) => Math.abs(v - model.scale) < Math.abs(validScales[best] - model.scale) ? idx : best, 0)
              value: curIdx
              from: 0
              to: validScales.length - 1
              boxWidth: 72
              valueText: model.scale.toFixed(2) + "x"
              onMoved: (v) => root.setMonitorScale(monitorCard.monitorIndex, validScales[v])
            }
          }
        }

        // ---- Orientation ----
        SettingRow {
          flat: true
          icon: "\uf01e"
          title: "Orientation"
          description: "Rotate or flip the display"

          control: Component {
            Dropdown {
              boxWidth: 130
              s: root.s
              options: root.transformChoices
              labelKey: "label"
              currentIndex: Math.max(0, root.transformChoices.findIndex(t => t.id === model.transform))
              onPicked: (i) => root.setMonitorTransform(monitorCard.monitorIndex, root.transformChoices[i].id)
            }
          }
        }
      }
    }
  }

  Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

  // ---------------- NIGHT LIGHT ----------------

  Text { visible: root.matches("Night light"); text: "NIGHT LIGHT"; font.pixelSize: s(10); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.border }

  SettingRow {
    visible: root.matches("Night light")
    icon: "\uf186"
    title: "Night light"
    description: "Warm the screen colors to reduce eye strain"

    control: Component {
      ToggleSwitch {
        s: root.s
        on: root.nightLightMode !== "Never"
        onToggled: root.setNightLightMode(on ? "Never" : "On")
      }
    }
  }

  SettingRow {
    visible: root.matches("Night light") && root.nightLightMode !== "Never"
    icon: "\uf2c9"
    title: "Warmth"
    description: "Color temperature: " + root.nightLightTemp + "%"

    control: Component {
      Item {
        width: root.s(180)
        height: root.s(20)

        Rectangle {
          id: nlTempTrack
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          height: root.s(6)
          radius: height / 2
          color: Qt.rgba(1, 1, 1, 0.1)

          Rectangle {
            width: parent.width * (root.nightLightTemp / 100)
            height: parent.height
            radius: height / 2
            color: MatugenColors.accent
          }
        }

        Rectangle {
          width: root.s(16); height: root.s(16); radius: width / 2
          anchors.verticalCenter: parent.verticalCenter
          x: Math.max(0, Math.min(nlTempTrack.width - width, nlTempTrack.width * (root.nightLightTemp / 100) - width / 2))
          color: "white"
          border.color: Qt.rgba(0, 0, 0, 0.2)
          border.width: 1
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onPressed: (mouse) => updateFromX(mouse.x)
          onPositionChanged: (mouse) => { if (pressed) updateFromX(mouse.x) }
          function updateFromX(x) {
            const pct = Math.max(0, Math.min(1, x / width))
            root.setNightLightTemp(Math.round(pct * 100))
          }
        }
      }
    }
  }

  SettingRow {
    visible: root.matches("Night light") && root.nightLightMode !== "Never"
    icon: "\uf017"
    title: "Automated schedule"
    description: "Turn on night light only during set hours"

    control: Component {
      ToggleSwitch {
        s: root.s
        on: root.nightLightMode === "Schedule"
        onToggled: root.setNightLightMode(on ? "On" : "Schedule")
      }
    }
  }

  SettingRow {
    visible: root.matches("Night light") && root.nightLightMode === "Schedule"
    icon: "\uf073"
    title: "Schedule hours"
    description: "Start and end time (HH:MM)"

    control: Component {
      RowLayout {
        spacing: root.s(6)

        Rectangle {
          Layout.preferredWidth: root.s(64); Layout.preferredHeight: root.s(26); radius: root.s(6)
          color: Qt.rgba(1, 1, 1, 0.08)
          TextInput {
            anchors.fill: parent
            anchors.margins: root.s(4)
            text: root.nightLightFrom
            font.pixelSize: root.s(11)
            font.weight: Font.Bold
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            selectByMouse: true
            onEditingFinished: root.setNightLightFrom(text)
          }
        }

        Text { text: "to"; font.pixelSize: root.s(10); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textDim }

        Rectangle {
          Layout.preferredWidth: root.s(64); Layout.preferredHeight: root.s(26); radius: root.s(6)
          color: Qt.rgba(1, 1, 1, 0.08)
          TextInput {
            anchors.fill: parent
            anchors.margins: root.s(4)
            text: root.nightLightTo
            font.pixelSize: root.s(11)
            font.weight: Font.Bold
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            selectByMouse: true
            onEditingFinished: root.setNightLightTo(text)
          }
        }
      }
    }
  }

  Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

  // ---------------- AUTO-LOCK ----------------

  Text { visible: root.matches("Auto-lock"); text: "AUTO-LOCK"; font.pixelSize: s(10); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.border }

  SettingRow {
    visible: root.matches("Auto-lock")
    icon: "\uf023"
    title: "Lock screen"
    description: "Lock automatically after being idle"

    control: Component {
      Dropdown {
        s: root.s
        boxWidth: 110
        options: root.autoLockChoices
        labelKey: "label"
        currentIndex: {
          const i = root.autoLockChoices.findIndex(c => c.s === root.autoLockSeconds)
          return i >= 0 ? i : root.autoLockChoices.length - 1
        }
        onPicked: (i) => root.setAutoLockSeconds(root.autoLockChoices[i].s)
      }
    }
  }

  Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

  // ---------------- DESKTOP WIDGETS ----------------

  Text { visible: root.matches("Desktop widgets"); text: "DESKTOP WIDGETS"; font.pixelSize: s(10); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.border }

  SettingRow {
    visible: root.matches("Desktop widgets")
    icon: "\uf26c"
    title: "Edit desktop widgets"
    description: "Move and arrange widgets on your desktop"

    control: Component {
      ClickButton {
        s: root.s
        variant: "primary"
        text: "Open"
        buttonHeight: 28
        hPadding: 20
        fontSize: 11
        onClicked: {
          root.menuOpenSetter(false)
          desktopEditDelay.start()
        }
      }
    }
  }

  Timer { id: desktopEditDelay; interval: 260; onTriggered: Config.desktopEditMode = true }
}
