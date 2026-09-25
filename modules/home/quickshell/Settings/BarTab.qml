import QtQuick
import QtQuick.Layouts
import ".."
import "../Singletons"

ColumnLayout {
  id: root

  required property var s
  required property var matches
  required property string fontFamily

  // Bar position
  required property var barPositionChoices
  required property var setBarPosition

  // Bar style / width / transparency / auto-hide use Config directly
  required property bool autoHideBar
  required property var toggleAutoHideBar

  // Bar layout (drag & drop)
  required property var barLayoutDraft
  required property var unplacedDraft
  required property var moveModuleToZone
  required property var commitBarLayout
  required property var resetBarLayout
  required property string draggingModuleId
  required property string previewZone
  required property int previewIdx
  required property var activeDragPill
  required property var controller
  required property var dragSurfaceItem

  // Clock
  required property bool showClockSeconds
  required property var toggleClockSeconds
  required property bool clock24h
  required property var toggleClock24h

  // Groups same-zone-adjacent modules that share a group id into clusters,
  // e.g. ["a","b","c"] with b+c grouped -> [["a"], ["b","c"]].
  function clusterModelFor(zone) {
    let ids = root.barLayoutDraft[zone]
    let clusters = []
    let i = 0
    while (i < ids.length) {
      let id = ids[i]
      let gId = root.controller.groupIdFor(id)
      if (gId === "") {
        clusters.push([id])
        i++
        continue
      }
      let cluster = [id]
      let j = i + 1
      while (j < ids.length && root.controller.groupIdFor(ids[j]) === gId) {
        cluster.push(ids[j])
        j++
      }
      clusters.push(cluster)
      i = j
    }
    return clusters
  }

  Layout.fillWidth: true
  spacing: s(14)
  focus: true

  // Clicking anywhere on the tab that isn't a control (empty space between
  // rows, etc.) should drop focus from any active text field — otherwise a
  // number box can stay "in edit mode" (border/highlight stuck) after the
  // user clicks away instead of pressing Enter/Escape.
  MouseArea {
    anchors.fill: parent
    z: -1
    onClicked: { root.forceActiveFocus(); root.controller.clearPendingGroup() }
  }

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

  Rectangle {
    id: barPosRow
    visible: root.matches("Bar position")
    Layout.fillWidth: true
    Layout.preferredHeight: s(56)
    radius: s(Config.uiRadius)
    color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)
    z: 10

    RowLayout {
      anchors.fill: parent
      anchors.margins: s(10)
      spacing: s(10)

      Text { text: "󰝚"; font.pixelSize: s(22); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: s(2)
        Text { text: "Bar position"; font.pixelSize: s(13); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text }
        Text { text: "Which edge of the screen the bar is docked to"; font.pixelSize: s(11); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textDim; wrapMode: Text.WordWrap; Layout.fillWidth: true }
      }

      Rectangle {
        id: barPosValueBox
        Layout.preferredWidth: barPosValueRow.implicitWidth + s(20)
        Layout.preferredHeight: s(32)
        radius: s(8)
        color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        border.color: barPosDropdown.visible ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.1)
        Behavior on border.color { ColorAnimation { duration: 150 } }

        RowLayout {
          id: barPosValueRow
          anchors.centerIn: parent
          spacing: s(8)

          Text {
            text: {
              let found = root.barPositionChoices.find(function(c) { return c.id === (Config.barPosition || "top") })
              return found ? found.label : "Top"
            }
            font.pixelSize: s(12)
            font.weight: Font.Bold
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.text
          }

          Text {
            text: barPosDropdown.visible ? "󰅃" : "󰅀"
            font.pixelSize: s(13)
            font.family: "JetBrainsMono Nerd Font"
            color: barPosOptMa.containsMouse ? MatugenColors.accent : MatugenColors.textDim
            Behavior on color { ColorAnimation { duration: 150 } }
          }
        }

        MouseArea { id: barPosOptMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: barPosDropdown.visible = !barPosDropdown.visible }
      }
    }

    Rectangle {
      id: barPosDropdown
      visible: false
      parent: barPosRow
      width: s(140)
      height: visible ? (root.barPositionChoices.length * 28 + 12) : 0
      anchors.right: parent.right
      anchors.top: parent.bottom
      anchors.topMargin: s(6)
      radius: s(Config.uiRadius)
      clip: true
      color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.98)
      border.color: Qt.rgba(1, 1, 1, 0.08)
      border.width: 1
      z: 100
      Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: s(6)
        spacing: s(2)

        Repeater {
          model: root.barPositionChoices
          delegate: Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: s(26)
            radius: s(6)
            color: barPosItemMa.containsMouse ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16) : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
              anchors.left: parent.left
              anchors.leftMargin: s(8)
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.label
              font.pixelSize: s(12)
              font.family: "JetBrainsMono Nerd Font"
              color: (Config.barPosition || "top") === modelData.id ? MatugenColors.accent : MatugenColors.text
            }

            MouseArea {
              id: barPosItemMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { root.setBarPosition(modelData.id); barPosDropdown.visible = false }
            }
          }
        }
      }
    }
  }

  SettingRow {
    visible: root.matches("Workspaces")
    icon: "󰽿"
    title: "Workspace count"
    description: "Number of workspaces shown on the bar"

    control: Component {
      RowLayout {
        id: wsCountStepper
        spacing: root.s(4)

        function setCount(n) {
          n = Math.max(1, Math.min(10, n))
          Config.workspaceCount = n
          root.controller.applyWorkspaceCount()
        }

        Rectangle {
          Layout.preferredWidth: root.s(26)
          Layout.preferredHeight: root.s(28)
          radius: root.s(6)
          color: wsDecMa.pressed ? Qt.rgba(1, 1, 1, 0.16) : (wsDecMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08))
          Behavior on color { ColorAnimation { duration: 120 } }
          enabled: Config.workspaceCount > 1
          opacity: enabled ? 1 : 0.4

          Text {
            anchors.centerIn: parent
            text: "\uf053"
            font.pixelSize: root.s(11)
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.accent
          }

          MouseArea {
            id: wsDecMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: wsCountStepper.setCount(Config.workspaceCount - 1)
          }
        }

        Rectangle {
          id: wsCountBox
          Layout.preferredWidth: root.s(46)
          Layout.preferredHeight: root.s(28)
          radius: root.s(6)
          color: Qt.rgba(1, 1, 1, wsCountInput.activeFocus ? 0.12 : 0.08)
          border.width: wsCountInput.activeFocus ? 1 : 0
          border.color: MatugenColors.accent
          Behavior on color { ColorAnimation { duration: 120 } }

          MouseArea {
            // Scroll wheel over the number box: third way to change the count.
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
              if (n > 20) { text = "20"; return }
              if (n >= 1) {
                wsCountStepper.setCount(n)
              }
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
          enabled: Config.workspaceCount < 20
          opacity: enabled ? 1 : 0.4

          Text {
            anchors.centerIn: parent
            text: "\uf054"
            font.pixelSize: root.s(11)
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.accent
          }

          MouseArea {
            id: wsIncMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: wsCountStepper.setCount(Config.workspaceCount + 1)
          }
        }
      }
    }
  }

  SettingRow {
    visible: root.matches("Workspace style")
    icon: "󰽿"
    title: "Workspace style"
    description: "Visual style of workspace indicators"

    control: Component {
      RowLayout {
        spacing: root.s(4)
        Repeater {
          model: [ { id: "numbers", label: "Numbers" }, { id: "orbs", label: "Orbs" } ]
          delegate: Rectangle {
            width: root.s(66); height: root.s(26); radius: root.s(6)
            color: Config.workspaceStyle === modelData.id
              ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.22)
              : (wsStyleMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.08))
            border.width: Config.workspaceStyle === modelData.id ? 1 : 0
            border.color: MatugenColors.accent
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
              anchors.centerIn: parent
              text: modelData.label
              font.pixelSize: root.s(10)
              font.weight: Font.Bold
              font.family: "JetBrainsMono Nerd Font"
              color: Config.workspaceStyle === modelData.id ? MatugenColors.accent : MatugenColors.text
            }

            MouseArea {
              id: wsStyleMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: Config.workspaceStyle = modelData.id
            }
          }
        }
      }
    }
  }

  Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

  SettingRow {
    visible: root.matches("Bar style")
    icon: "󰕮"
    title: "Bar style"
    description: "Separated modules or a solid continuous bar"

    control: Component {
      RowLayout {
        spacing: root.s(4)
        Repeater {
          model: [ { id: "modular", label: "Separated" }, { id: "solid", label: "Solid" } ]
          delegate: Rectangle {
            width: root.s(78); height: root.s(26); radius: root.s(6)
            color: Config.barStyle === modelData.id
              ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.22)
              : (barStyleMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.08))
            border.width: Config.barStyle === modelData.id ? 1 : 0
            border.color: MatugenColors.accent
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
              anchors.centerIn: parent
              text: modelData.label
              font.pixelSize: root.s(10)
              font.weight: Font.Bold
              font.family: "JetBrainsMono Nerd Font"
              color: Config.barStyle === modelData.id ? MatugenColors.accent : MatugenColors.text
            }

            MouseArea {
              id: barStyleMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: Config.barStyle = modelData.id
            }
          }
        }
      }
    }
  }

  SettingRow {
    visible: root.matches("Border radius")
    icon: "󰛐"
    title: "Border radius"
    description: "Corner rounding applied across the UI"

    control: Component {
      RowLayout {
        id: radiusStepper
        spacing: root.s(4)

        function setRadius(n) {
          n = Math.max(0, Math.min(20, n))
          root.controller.setUiRadius(n)
        }

        Rectangle {
          Layout.preferredWidth: root.s(26)
          Layout.preferredHeight: root.s(28)
          radius: root.s(6)
          color: radiusDecMa.pressed ? Qt.rgba(1, 1, 1, 0.16) : (radiusDecMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08))
          Behavior on color { ColorAnimation { duration: 120 } }
          enabled: Config.uiRadius > 0
          opacity: enabled ? 1 : 0.4

          Text {
            anchors.centerIn: parent
            text: "\uf053"
            font.pixelSize: root.s(11)
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.accent
          }

          MouseArea {
            id: radiusDecMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: radiusStepper.setRadius(Config.uiRadius - 1)
          }
        }

        Rectangle {
          Layout.preferredWidth: root.s(56)
          Layout.preferredHeight: root.s(28)
          radius: root.s(6)
          color: Qt.rgba(1, 1, 1, radiusInput.activeFocus ? 0.12 : 0.08)
          border.width: radiusInput.activeFocus ? 1 : 0
          border.color: MatugenColors.accent
          Behavior on color { ColorAnimation { duration: 120 } }

          MouseArea {
            // Scroll wheel over the number box: third way to change the radius.
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            hoverEnabled: true
            onWheel: (wheel) => {
              radiusStepper.setRadius(Config.uiRadius + (wheel.angleDelta.y > 0 ? 1 : -1))
              wheel.accepted = true
            }
          }

          TextInput {
            id: radiusInput
            anchors.fill: parent
            anchors.leftMargin: root.s(8)
            anchors.rightMargin: root.s(4)
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            font.pixelSize: root.s(13)
            font.weight: Font.Bold
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.accent
            selectionColor: MatugenColors.accent
            text: Config.uiRadius + "px"
            validator: IntValidator { bottom: 0; top: 20 }
            inputMethodHints: Qt.ImhDigitsOnly
            onActiveFocusChanged: {
              if (activeFocus) {
                text = String(Config.uiRadius)
                selectAll()
              } else {
                let n = parseInt(text)
                if (isNaN(n)) n = Config.uiRadius
                radiusStepper.setRadius(n)
                text = Config.uiRadius + "px"
              }
            }
            onTextChanged: {
              if (!activeFocus) return
              let n = parseInt(text)
              if (!isNaN(n)) root.controller.setUiRadius(n)
            }
            Keys.onReturnPressed: radiusInput.focus = false
            Keys.onEnterPressed: radiusInput.focus = false
            Keys.onEscapePressed: { text = Config.uiRadius + "px"; radiusInput.focus = false }
          }
        }

        Rectangle {
          Layout.preferredWidth: root.s(26)
          Layout.preferredHeight: root.s(28)
          radius: root.s(6)
          color: radiusIncMa.pressed ? Qt.rgba(1, 1, 1, 0.16) : (radiusIncMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08))
          Behavior on color { ColorAnimation { duration: 120 } }
          enabled: Config.uiRadius < 20
          opacity: enabled ? 1 : 0.4

          Text {
            anchors.centerIn: parent
            text: "\uf054"
            font.pixelSize: root.s(11)
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.accent
          }

          MouseArea {
            id: radiusIncMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: radiusStepper.setRadius(Config.uiRadius + 1)
          }
        }
      }
    }
  }

  SettingRow {
    visible: root.matches("Bar width")
    icon: "󰡍"
    title: "Bar width"
    description: "Percentage of the screen width the bar occupies"

    control: Component {
      RowLayout {
        spacing: root.s(8)
        Item {
          Layout.preferredWidth: root.s(160)
          Layout.preferredHeight: root.s(18)

          Rectangle {
            id: barWidthTrack
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.1)
            clip: true
            readonly property real ratio: Config.barWidthPercent / 100

            Rectangle {
              width: Math.max(parent.radius * 2, barWidthTrack.width * barWidthTrack.ratio)
              height: parent.height
              radius: parent.radius
              color: MatugenColors.accent
              Behavior on width { enabled: !barWidthMa.pressed; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            Rectangle {
              width: root.s(2)
              height: parent.height
              x: Math.max(0, Math.min(parent.width - width, barWidthTrack.width * barWidthTrack.ratio - width / 2))
              color: MatugenColors.bgBase
              opacity: 0.55
              Behavior on x { enabled: !barWidthMa.pressed; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            MouseArea {
              id: barWidthMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              preventStealing: true

              function updateFromX(mx) {
                let ratio = Math.max(0, Math.min(1, mx / barWidthTrack.width))
                Config.barWidthPercent = Math.round(ratio * 100)
              }
              onPressed: (mouse) => updateFromX(mouse.x)
              onPositionChanged: (mouse) => { if (pressed) updateFromX(mouse.x) }
            }
          }
        }

        Text { text: Config.barWidthPercent + "%"; font.pixelSize: root.s(13); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent; Layout.preferredWidth: root.s(40); horizontalAlignment: Text.AlignHCenter }
      }
    }
  }

  SettingRow {
    visible: root.matches("Bar transparency")
    icon: "󰈈"
    title: "Bar transparency"
    description: "Opacity of the bar background"

    control: Component {
      RowLayout {
        spacing: root.s(8)
        Item {
          Layout.preferredWidth: root.s(160)
          Layout.preferredHeight: root.s(18)

          Rectangle {
            id: barOpacityTrack
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.1)
            clip: true
            readonly property real ratio: Config.barOpacityPercent / 100

            Rectangle {
              width: Math.max(parent.radius * 2, barOpacityTrack.width * barOpacityTrack.ratio)
              height: parent.height
              radius: parent.radius
              color: MatugenColors.accent
              Behavior on width { enabled: !barOpacityMa.pressed; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            Rectangle {
              width: root.s(2)
              height: parent.height
              x: Math.max(0, Math.min(parent.width - width, barOpacityTrack.width * barOpacityTrack.ratio - width / 2))
              color: MatugenColors.bgBase
              opacity: 0.55
              Behavior on x { enabled: !barOpacityMa.pressed; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            MouseArea {
              id: barOpacityMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              preventStealing: true

              function updateFromX(mx) {
                let ratio = Math.max(0, Math.min(1, mx / barOpacityTrack.width))
                Config.barOpacityPercent = Math.round(ratio * 100)
              }
              onPressed: (mouse) => updateFromX(mouse.x)
              onPositionChanged: (mouse) => { if (pressed) updateFromX(mouse.x) }
            }
          }
        }

        Text { text: Config.barOpacityPercent + "%"; font.pixelSize: root.s(13); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent; Layout.preferredWidth: root.s(40); horizontalAlignment: Text.AlignHCenter }
      }
    }
  }

  SettingRow {
    visible: root.matches("Auto hide bar")
    icon: "󰈈"
    title: "Auto hide bar"
    description: "Automatically hide the bar when not in use"

    control: Component {
      Rectangle {
        width: root.s(48); height: root.s(26); radius: root.s(13)
        color: root.autoHideBar ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.08)
        Behavior on color { ColorAnimation { duration: 250 } }
        Rectangle {
          width: root.s(20); height: root.s(20); radius: root.s(10); color: "white"
          anchors.verticalCenter: parent.verticalCenter
          x: root.autoHideBar ? parent.width - width - root.s(3) : root.s(3)
          Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleAutoHideBar() }
      }
    }
  }

  Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

  RowLayout {
    visible: root.matches("Bar layout")
    Layout.fillWidth: true
    Text { text: "BAR LAYOUT"; font.pixelSize: s(13); font.weight: Font.Bold; font.family: root.fontFamily; color: MatugenColors.border; Layout.fillWidth: true }
    Text {
      text: "Reset"
      font.pixelSize: s(12)
      font.family: root.fontFamily
      color: resetBarMa.containsMouse ? MatugenColors.accent : MatugenColors.textDim
      MouseArea { id: resetBarMa; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.resetBarLayout() }
    }
  }

  ColumnLayout {
    visible: root.matches("Bar layout")
    Layout.fillWidth: true
    spacing: s(10)

    Text { text: "Drag modules between zones. Changes apply immediately to the bar."; font.pixelSize: s(13); font.family: root.fontFamily; color: MatugenColors.textDim; wrapMode: Text.WordWrap; Layout.fillWidth: true }
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: Math.max(s(72), availableFlow.implicitHeight + s(20))
      radius: s(Config.uiRadius)
      color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.4)
      border.width: 1
      border.color: availableDrop.containsDrag ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.06)
      Behavior on border.color { ColorAnimation { duration: 120 } }

      DropArea {
        id: availableDrop
        anchors.fill: parent
        onEntered: (drag) => { drag.accepted = root.draggingModuleId !== "" }
        onDropped: {
          root.moveModuleToZone(root.draggingModuleId, "unplaced")
          root.commitBarLayout()
          root.controller.previewZone = ""
          root.controller.previewIdx = -1
          if (root.activeDragPill) root.activeDragPill.dropHandled = true
        }
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: s(10)
        spacing: s(6)

        Text { text: "AVAILABLE"; font.pixelSize: s(11); font.weight: Font.Bold; font.family: root.fontFamily; color: MatugenColors.textDim }

        Flow {
          id: availableFlow
          Layout.fillWidth: true
          spacing: s(6)

          move: Transition {
            NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutCubic }
          }
          add: Transition {
            NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutCubic }
          }

          Text {
            visible: root.unplacedDraft.length === 0
            text: "All modules placed"
            font.pixelSize: s(12)
            font.family: root.fontFamily
            color: MatugenColors.textDim
          }

          Repeater {
            model: root.unplacedDraft
            delegate: BarModulePill {
              required property string modelData
              moduleId: modelData
              zone: "unplaced"
              controller: root.controller
              dragSurface: root.dragSurfaceItem
              onRemoveRequested: (id) => { root.moveModuleToZone(id, "unplaced"); root.commitBarLayout() }
            }
          }
        }
      }
    }

    // Left / Center / Right zones, side by side
    RowLayout {
      Layout.fillWidth: true
      spacing: s(10)

      Repeater {
        model: [
          { zone: "left", label: "LEFT" },
          { zone: "center", label: "CENTER" },
          { zone: "right", label: "RIGHT" }
        ]
        delegate: Rectangle {
          id: outerZone
          required property var modelData
          property string zone: modelData.zone
          property string label: modelData.label
          Layout.fillWidth: true
          Layout.preferredHeight: Math.max(s(120), zoneCol.implicitHeight + s(20))
          Layout.alignment: Qt.AlignTop
          radius: s(Config.uiRadius)
          color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)
          border.width: 1
          border.color: zoneDrop.containsDrag ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.06)
          Behavior on border.color { ColorAnimation { duration: 120 } }

          DropArea {
            id: zoneDrop
            anchors.fill: parent
            onEntered: (drag) => { drag.accepted = root.draggingModuleId !== "" }
            onPositionChanged: (drag) => {
              if (root.draggingModuleId === "") return
              root.controller.previewZone = outerZone.zone
              root.controller.previewIdx = zoneDrop.computeInsertIdx(drag.x, drag.y)
            }
            onExited: {
              if (root.previewZone === outerZone.zone) {
                root.controller.previewZone = ""
                root.controller.previewIdx = -1
              }
            }
            onDropped: (drag) => {
              let insertIdx = zoneDrop.computeInsertIdx(drag.x, drag.y)
              root.moveModuleToZone(root.draggingModuleId, outerZone.zone, insertIdx)
              root.commitBarLayout()
              root.controller.previewZone = ""
              root.controller.previewIdx = -1
              if (root.activeDragPill) root.activeDragPill.dropHandled = true
            }
            function computeInsertIdx(dragX, dragY) {
              let local = zoneDrop.mapToItem(pillFlow, dragX, dragY)
              let count = 0
              for (let ci = 0; ci < pillFlow.children.length; ci++) {
                let clusterItem = pillFlow.children[ci]
                if (!clusterItem || clusterItem.memberIds === undefined) continue
                let clusterRow = clusterItem.children.find(c => c.children !== undefined && c.spacing === 0)
                if (!clusterRow) continue
                for (let i = 0; i < clusterRow.children.length; i++) {
                  let child = clusterRow.children[i]
                  if (!child || child.modelData === undefined) continue
                  if (child.modelData === root.draggingModuleId) continue
                  // Measure against the real pill's stable geometry, not the
                  // wrapper's — the wrapper's width/x shift while the preview
                  // gap next to it animates open/closed, which made the
                  // threshold move under the cursor mid-drag.
                  let pill = child.realPill || child
                  let pillPos = pill.mapToItem(pillFlow, 0, 0)
                  let sameRow = Math.abs((pillPos.y + pill.height / 2) - local.y) < pill.height
                  let childCenterX = pillPos.x + pill.width / 2
                  let before = sameRow
                    ? (local.x >= childCenterX)
                    : (local.y >= pillPos.y + pill.height / 2)
                  if (before) count++
                }
              }
              return count
            }
          }

          ColumnLayout {
            id: zoneCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: s(10)
            spacing: s(6)

            Text { text: outerZone.label; font.pixelSize: s(11); font.weight: Font.Bold; font.family: root.fontFamily; color: MatugenColors.textDim }

            Text {
              visible: root.barLayoutDraft[outerZone.zone].length === 0
              text: "Drop here"
              font.pixelSize: s(12)
              font.family: root.fontFamily
              color: MatugenColors.textDim
            }
            Flow {
              id: pillFlow
              Layout.fillWidth: true
              spacing: s(6)

              Repeater {
                id: clusterRepeater
                model: (Config.barGroups, root.clusterModelFor(outerZone.zone))
                delegate: Item {
                  id: clusterSlot
                  required property var modelData
                  required property int index
                  readonly property var memberIds: clusterSlot.modelData
                  readonly property bool isGroup: clusterSlot.memberIds.length > 1
                  readonly property string groupColor: (clusterSlot.isGroup && clusterSlot.memberIds.length > 0) ? (Config.barGroups, root.controller.groupColorFor(clusterSlot.memberIds[0])) : ""
                  readonly property color groupColorObj: clusterSlot.groupColor ? Qt.color(clusterSlot.groupColor) : "transparent"

                  implicitWidth: clusterRow.implicitWidth + (clusterSlot.isGroup ? s(8) : 0)
                  implicitHeight: clusterRow.implicitHeight + (clusterSlot.isGroup ? s(8) : 0)

                  Rectangle {
                    anchors.fill: parent
                    visible: clusterSlot.isGroup
                    radius: s(Config.uiRadius)
                    color: clusterSlot.isGroup ? Qt.rgba(clusterSlot.groupColorObj.r, clusterSlot.groupColorObj.g, clusterSlot.groupColorObj.b, 0.16) : "transparent"
                    border.width: 1
                    border.color: clusterSlot.isGroup ? Qt.rgba(clusterSlot.groupColorObj.r, clusterSlot.groupColorObj.g, clusterSlot.groupColorObj.b, 0.55) : "transparent"
                  }

                  RowLayout {
                    id: clusterRow
                    anchors.centerIn: parent
                    spacing: 0

                    Repeater {
                      model: clusterSlot.memberIds
                      delegate: RowLayout {
                        id: pillSlot
                        required property string modelData
                        required property int index
                        readonly property int flatIndex: root.barLayoutDraft[outerZone.zone].indexOf(pillSlot.modelData)
                        spacing: 0
                        readonly property bool gapActive: root.previewZone === outerZone.zone
                          && root.previewIdx === pillSlot.flatIndex
                          && root.draggingModuleId !== pillSlot.modelData

                        Rectangle {
                          id: gapBefore
                          Layout.preferredWidth: pillSlot.gapActive ? realPill.implicitWidth + s(6) : 0
                          Layout.preferredHeight: realPill.implicitHeight
                          color: pillSlot.gapActive ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.12) : "transparent"
                          radius: s(Config.uiRadius)
                          border.width: pillSlot.gapActive ? 1.5 : 0
                          border.color: MatugenColors.accent
                          Behavior on Layout.preferredWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                          Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Rectangle {
                          // Thin divider between grouped members (not before the first one)
                          visible: clusterSlot.isGroup && pillSlot.index > 0
                          Layout.preferredWidth: visible ? 1 : 0
                          Layout.preferredHeight: realPill.implicitHeight - s(10)
                          Layout.alignment: Qt.AlignVCenter
                          color: Qt.rgba(clusterSlot.groupColorObj.r, clusterSlot.groupColorObj.g, clusterSlot.groupColorObj.b, 0.5)
                        }

                        BarModulePill {
                          id: realPill
                          moduleId: pillSlot.modelData
                          zone: outerZone.zone
                          controller: root.controller
                          dragSurface: root.dragSurfaceItem
                          onRemoveRequested: (id) => { root.moveModuleToZone(id, "unplaced"); root.commitBarLayout() }
                        }
                      }
                    }
                  }
                }
              }
              Rectangle {
                readonly property bool endActive: root.previewZone === outerZone.zone
                  && root.previewIdx === root.barLayoutDraft[outerZone.zone].length
                Layout.preferredWidth: endActive ? s(34) : 0
                Layout.preferredHeight: s(28)
                color: endActive ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.12) : "transparent"
                radius: s(Config.uiRadius)
                border.width: endActive ? 1.5 : 0
                border.color: MatugenColors.accent
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 120 } }
              }
            }
          }
        }
      }
    }
  }

  Rectangle { visible: root.matches("Bar layout"); Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

  SettingRow {
    visible: root.matches("Clock seconds")
    icon: "󰥔"
    title: "Show seconds in clock"
    description: "Display seconds alongside hours and minutes"

    control: Component {
      Rectangle {
        width: root.s(48); height: root.s(26); radius: root.s(13)
        color: root.showClockSeconds ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.08)
        Behavior on color { ColorAnimation { duration: 250 } }
        Rectangle {
          width: root.s(20); height: root.s(20); radius: root.s(10); color: "white"
          anchors.verticalCenter: parent.verticalCenter
          x: root.showClockSeconds ? parent.width - width - root.s(3) : root.s(3)
          Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleClockSeconds() }
      }
    }
  }

  SettingRow {
    visible: root.matches("Clock time format")
    icon: "󰅐"
    title: "Time format"
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
}
