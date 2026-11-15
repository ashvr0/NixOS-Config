import ".."
import "../Singletons"
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Networking as QsNet
import Quickshell.Bluetooth as QsBt
import "../Singletons/PopupPlace.js" as Place
import "../Components"

Item {
  id: root

  // ClickButton that only fires held() after being pressed for holdMs.
  component HoldButton : ClickButton {
    id: hold

    property int holdMs: 600
    property real holdProgress: 0
    signal held()

    s: function(v) { return Scaler.s(v) }
    fill: true
    clip: true
    buttonHeight: 72
    iconSize: 20
    Layout.preferredWidth: 1

    onPressedChanged: {
      holdProgress = 0
      if (pressed) holdTimer.start()
      else holdTimer.stop()
    }

    Timer {
      id: holdTimer
      interval: 16
      repeat: true
      onTriggered: {
        hold.holdProgress = Math.min(1, hold.holdProgress + interval / hold.holdMs)
        if (hold.holdProgress >= 1) {
          holdTimer.stop()
          hold.holdProgress = 0
          hold.held()
        }
      }
    }

    Rectangle {
      visible: hold.holdProgress > 0
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      width: parent.width
      height: parent.height * hold.holdProgress
      radius: parent.radius
      color: Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.35)
    }
  }

  Component.onCompleted: {
        Scaler.currentWidth = Screen.width
        Scaler.currentHeight = Screen.height
    }
  function s(val) { return Scaler.s(val) }
  readonly property int sliderTrackWidth: Math.max(100, Math.floor(mainColumn.width / s(1)) - 80)
  property real anchorY: Screen.height / 2
  function updateAnchor() {
    var ref = (root.width > 0 && root.height > 0) ? root : root.parent
    if (!ref) return
    var p = ref.mapToItem(null, ref.width / 2, ref.height / 2)
    root.anchorY = p.y + (Config.barVertical ? s(10) : 0)
  }
  IpcHandler {
    target: "powermenu"
    function toggle(): void {
      root.menuOpen = !root.menuOpen
    }
  }

  implicitWidth: s(26)
  implicitHeight: parent ? parent.height : s(50)

  property int cascadeIndex: 5
  property bool menuOpen: false
  onMenuOpenChanged: if (menuOpen) { root.updateAnchor(); brightnessGetProc.running = true }
  property bool entered: false
  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }
  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } } }
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

  Process { id: shutdownProc; command: ["systemctl", "poweroff"] }
  Process { id: restartProc;  command: ["systemctl", "reboot"] }
  Process { id: sleepProc;    command: ["systemctl", "suspend"] }

  Process {
    id: logoutProc
    command: ["sh", "-c", "hyprctl dispatch exit 2>/tmp/qs-logout.log || pkill -SIGTERM Hyprland"]
    stderr: SplitParser {
      onRead: data => console.warn("logout failed:", data)
    }
  }
  Process {
    id: lockProc
    command: ["qs", "-p", Quickshell.env("HOME") + "/.config/quickshell/Lock.qml"]
  }

  property bool nightLightOn: false

  Process {
    id: nightLightOnProc
    command: ["hyprsunset", "-t", "4000"]
  }
  Process {
    id: nightLightOffProc
    command: ["pkill", "hyprsunset"]
  }
  function toggleNightLight() {
    root.nightLightOn = !root.nightLightOn
    if (root.nightLightOn) nightLightOnProc.running = true
    else nightLightOffProc.running = true
  }

  property bool dndOn: false
  function toggleDnd() {
    root.dndOn = !root.dndOn
    if (typeof Notifs !== "undefined") Notifs.silent = root.dndOn
  }

  readonly property var btAdapter: QsBt.Bluetooth.defaultAdapter
  readonly property bool wifiOn: QsNet.Networking.wifiEnabled
  readonly property bool bluetoothOn: btAdapter ? btAdapter.enabled : false
  readonly property bool airplaneModeOn: !wifiOn && !bluetoothOn

  function toggleWifi() {
    QsNet.Networking.wifiEnabled = !QsNet.Networking.wifiEnabled
  }

  function toggleBluetooth() {
    if (btAdapter) btAdapter.enabled = !btAdapter.enabled
  }

  function toggleAirplaneMode() {
    const enable = !root.airplaneModeOn
    QsNet.Networking.wifiEnabled = !enable
    if (btAdapter) btAdapter.enabled = !enable
  }

  Audio { id: audioModule; enableIpc: false }
  readonly property alias volumeLevel: audioModule.volumeLevel
  readonly property alias volumeMuted: audioModule.muted
  readonly property alias volumeIcon: audioModule.volumeIcon

  property int brightnessPct: 100
  property bool brightnessAvailable: true
  property int _brightnessMax: 100
  readonly property string ddcBus: "0"
  readonly property string ddcVcpBrightness: "10"

  Process {
    id: brightnessGetProc
    command: ["ddcutil", "-b", root.ddcBus, "getvcp", root.ddcVcpBrightness, "--brief"]
    running: true
    stdout: SplitParser {
      onRead: data => {
        const parts = data.trim().split(/\s+/)
        if (parts.length >= 5 && parts[0] === "VCP") {
          const current = parseInt(parts[3], 10)
          const max = parseInt(parts[4], 10)
          if (!isNaN(current) && max > 0) {
            root._brightnessMax = max
            root.brightnessPct = Math.round((current / max) * 100)
            root.brightnessAvailable = true
          }
        }
      }
    }
    stderr: SplitParser {
      onRead: data => {
        console.warn("ddcutil getvcp failed:", data)
        root.brightnessAvailable = false
      }
    }
  }

  Process {
    id: brightnessSetProc
    stderr: SplitParser {
      onRead: data => console.warn("ddcutil setvcp failed:", data)
    }
  }

  property int _pendingBrightnessPct: -1
  Timer {
    id: brightnessSetDebounce
    interval: 120
    onTriggered: {
      if (root._pendingBrightnessPct < 0) return
      const target = Math.round((root._pendingBrightnessPct / 100) * root._brightnessMax)
      brightnessSetProc.command = ["ddcutil", "-b", root.ddcBus, "setvcp", root.ddcVcpBrightness, target.toString()]
      brightnessSetProc.running = true
      root._pendingBrightnessPct = -1
    }
  }
  function setBrightness(pct) {
    const clamped = Math.max(0, Math.min(100, Math.round(pct)))
    root.brightnessPct = clamped
    root._pendingBrightnessPct = clamped
    brightnessSetDebounce.restart()
  }

  property real cpuPct: SystemStats.cpuPercent
  property real ramPct: SystemStats.ramPercent
  readonly property string ramUsedStr: SystemStats.totalRamGb > 0
    ? (SystemStats.totalRamGb * SystemStats.ramPercent / 100).toFixed(1) + "G / " + SystemStats.totalRamGb.toFixed(1) + "G"
    : "--"
  readonly property string tempStr: SystemStats.tempC > 0
    ? (Config.tempUnitFahrenheit
        ? Math.round(SystemStats.tempC * 9 / 5 + 32) + "°F"
        : Math.round(SystemStats.tempC) + "°C")
    : "--"
  property real diskPct: SystemStats.diskPercent
  readonly property string diskUsedStr: SystemStats.diskUsedStr !== "" && SystemStats.diskTotalStr !== ""
    ? SystemStats.diskUsedStr + " / " + SystemStats.diskTotalStr
    : "--"
  readonly property string netStr: "↓" + SystemStats.netRxText + " ↑" + SystemStats.netTxText
  readonly property string uptimeStr: {
    const sec = SystemStats.uptimeSeconds
    if (!sec) return "--"
    const h = Math.floor(sec / 3600)
    const m = Math.floor((sec % 3600) / 60)
    return h + ":" + (m < 10 ? "0" : "") + m
  }
  readonly property string nixosVersionStr: SystemStats.osName !== "" ? SystemStats.osName : "NixOS"

  readonly property var latestGroup: Notifs.groups.length > 0 ? Notifs.groups[0] : null
  readonly property bool hasNotif: root.latestGroup !== null
  readonly property string lastNotifSummary: root.latestGroup ? root.latestGroup.newest.summary : "No new notifications (groups: " + Notifs.groups.length + ")"
  readonly property string lastNotifBody: root.latestGroup ? root.latestGroup.newest.body : ""

  Text {
    anchors.centerIn: parent
    text: "⏻"
    font.pixelSize: s(18)
    font.family: "JetBrainsMono Nerd Font"
    color: root.menuOpen ? MatugenColors.accent : MatugenColors.text
    Behavior on color { ColorAnimation { duration: 200 } }
  }

  MouseArea {
    id: pillMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.menuOpen = !root.menuOpen
  }

  // Power menu popup
  PanelWindow {
    id: powerPopup
    visible: animOpacity > 0.01
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qs-power-popup"
    anchors { top: true; left: true; right: true; bottom: true }

    property real animOpacity: root.menuOpen ? 1.0 : 0.0
    Behavior on animOpacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    MouseArea {
      anchors.fill: parent
      onClicked: root.menuOpen = false
    }

    FocusScope {
      anchors.fill: parent
      focus: root.menuOpen
      Keys.onEscapePressed: root.menuOpen = false

      Rectangle {
        id: powerCard
        width: s(720)
        x: Place.place(Config.barPosition, width, height, root.anchorY, Screen.width, Screen.height, root.s).x
        y: Place.place(Config.barPosition, width, height, root.anchorY, Screen.width, Screen.height, root.s).y
        radius: s(10)
        clip: true
        focus: true
        color: MatugenColors.bgBase
        border.color: MatugenColors.border
        border.width: 2

        opacity: powerPopup.animOpacity
        scale: 0.94 + 0.06 * powerPopup.animOpacity
        transform: Translate { y: (1 - powerPopup.animOpacity) * -10 }
        implicitHeight: mainColumn.implicitHeight + s(98)
        height: implicitHeight
        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Keys.onEscapePressed: root.menuOpen = false
        MouseArea { anchors.fill: parent }

        Column {
          id: mainColumn
          anchors.fill: parent
          anchors.margins: s(16)
          spacing: s(14)

          Item {
            width: parent.width
            height: s(54)

            Row {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: s(10)

              Rectangle {
                width: s(40)
                height: s(40)
                radius: s(20)
                clip: true
                color: Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.2)
                border.color: MatugenColors.accent
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter

                Image {
                  id: avatarImg
                  anchors.fill: parent
                  anchors.margins: 2
                  source: Config.profilePicturePath ? "file://" + Config.profilePicturePath : ""
                  fillMode: Image.PreserveAspectCrop
                  visible: false
                  cache: false
                  asynchronous: true
                  smooth: true
                }

                // Mask the loaded image into a circle instead of relying on the
                // square Image being visually clipped by nothing.
                MultiEffect {
                  anchors.fill: avatarImg
                  source: avatarImg
                  visible: avatarImg.status === Image.Ready
                  maskEnabled: true
                  maskSource: avatarMask
                }

                Item {
                  id: avatarMask
                  anchors.fill: avatarImg
                  layer.enabled: true
                  visible: false
                  Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                  }
                }

                Text {
                  anchors.centerIn: parent
                  visible: avatarImg.status !== Image.Ready
                  text: "󰀄"
                  font.pixelSize: s(18)
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.accent
                }
              }

              Column {
                spacing: s(1)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  text: Quickshell.env("USER") || "user"
                  font.pixelSize: s(13)
                  font.weight: Font.Medium
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.text
                }

                Text {
                  text: root.nixosVersionStr
                  font.pixelSize: s(10)
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.textMuted
                }

                Text {
                  text: "Uptime • " + root.uptimeStr
                  font.pixelSize: s(10)
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.textMuted
                }
              }
            }

            ClickButton {
              id: headerLogoutBtn
              s: root.s
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              icon: "󰍃"
              text: "Logout"
              fontSize: 11
              iconSize: 13
              buttonHeight: 34
              hPadding: 14
              onClicked: {
                root.menuOpen = false
                logoutProc.running = true
              }
            }
          }

          Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

          RowLayout {
            width: parent.width
            spacing: s(8)

            HoldButton { icon: "󰌾"; holdMs: 350;  onHeld: { root.menuOpen = false; lockProc.running = true } }
            HoldButton { icon: "󰒲"; holdMs: 600;  onHeld: { root.menuOpen = false; sleepProc.running = true } }

            Rectangle {
              Layout.preferredWidth: s(8)
              Layout.preferredHeight: s(48)
              Layout.alignment: Qt.AlignVCenter
              radius: s(4)
              color: Qt.rgba(1, 1, 1, 0.08)
            }

            HoldButton { icon: "󰜉"; holdMs: 1200; onHeld: { root.menuOpen = false; restartProc.running = true } }
            HoldButton { icon: "⏻"; holdMs: 1800; onHeld: { root.menuOpen = false; shutdownProc.running = true } }
          }

          Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

          // ── Quick controls: sound + brightness ──
          Column {
            width: parent.width
            spacing: s(10)

            RowLayout {
              width: parent.width
              spacing: s(10)

              Text {
                text: root.volumeMuted ? "\u{f026}" : root.volumeIcon
                font.pixelSize: s(15)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.accent
                Layout.preferredWidth: s(18)
              }

              ValueSlider {
                s: root.s
                from: 0
                to: 100
                value: root.volumeMuted ? 0 : Math.min(100, Math.round(root.volumeLevel))
                suffix: "%"
                trackWidth: root.sliderTrackWidth
                labelWidth: 44
                onMoved: function(v) { audioModule.setVolume(v) }
              }
            }

            RowLayout {
              width: parent.width
              spacing: s(10)

              Text {
                text: "\u{f0eb}"
                font.pixelSize: s(15)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.accent
                Layout.preferredWidth: s(18)
              }

              ValueSlider {
                s: root.s
                enabled: root.brightnessAvailable
                from: 0
                to: 100
                value: root.brightnessPct
                suffix: "%"
                trackWidth: root.sliderTrackWidth
                labelWidth: 44
                onMoved: function(v) { root.setBrightness(v) }
              }
            }
          }

          Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

          Grid {
            width: parent.width
            columns: 2
            rowSpacing: s(8)
            columnSpacing: s(8)

            Repeater {
              model: [
                { label: "CPU",  icon: "󰻠", value: root.cpuPct.toFixed(0) + "%",  pct: root.cpuPct },
                { label: "RAM",  icon: "󰍛", value: root.ramUsedStr,               pct: root.ramPct },
                { label: "Temp", icon: "󰔏", value: root.tempStr,                  pct: -1 },
                { label: "Disk", icon: "󰋊", value: root.diskUsedStr,              pct: root.diskPct }
              ]

              delegate: Rectangle {
                required property var modelData
                width: (mainColumn.width - s(8)) / 2
                height: s(62)
                radius: s(10)
                color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

                Row {
                  anchors.left: parent.left
                  anchors.leftMargin: s(10)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: s(10)

                  Text {
                    text: modelData.icon
                    font.pixelSize: s(15)
                    font.family: "JetBrainsMono Nerd Font"
                    color: MatugenColors.accent
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Column {
                    spacing: s(2)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                      text: modelData.label
                      font.pixelSize: s(9)
                      font.family: "JetBrainsMono Nerd Font"
                      color: MatugenColors.textMuted
                    }

                    Text {
                      text: modelData.value
                      font.pixelSize: s(13)
                      font.weight: Font.Medium
                      font.family: "JetBrainsMono Nerd Font"
                      color: MatugenColors.text
                    }
                  }
                }

                Rectangle {
                  visible: modelData.pct >= 0
                  anchors.bottom: parent.bottom
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.bottomMargin: s(4)
                  anchors.leftMargin: s(10)
                  anchors.rightMargin: s(10)
                  height: s(3)
                  radius: s(2)
                  color: Qt.rgba(1, 1, 1, 0.08)

                  Rectangle {
                    height: parent.height
                    radius: s(2)
                    width: parent.width * Math.min(1, modelData.pct / 100)
                    color: MatugenColors.accent
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                  }
                }
              }
            }
          }

          Rectangle {
            width: parent.width
            height: s(48)
            radius: s(10)
            color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

            Row {
              anchors.left: parent.left
              anchors.leftMargin: s(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: s(10)

              Text {
                text: "󰈀"
                font.pixelSize: s(14)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.accent
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: root.netStr
                font.pixelSize: s(12)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.text
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
          // Power Profiles
          Rectangle {
            visible: PowerProfiles.hasPerformanceProfile
            width: parent.width
            height: s(48)
            radius: s(10)
            color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

            Row {
              anchors.left: parent.left
              anchors.leftMargin: s(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: s(12)

              Text {
                text: "󰓅"
                font.pixelSize: s(14)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.accent
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: {
                  switch (PowerProfiles.profile) {
                    case PowerProfile.PowerSaver: return "Power Saver"
                    case PowerProfile.Performance: return "Performance"
                    default: return "Balanced"
                  }
                }
                font.pixelSize: s(12)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.text
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            SegmentedControl {
              s: root.s
              anchors.right: parent.right
              anchors.rightMargin: s(10)
              anchors.verticalCenter: parent.verticalCenter
              buttonWidth: 130
              buttonHeight: 32
              choices: [
                { id: "saver",       label: "󰌪 Saver" },
                { id: "balanced",    label: "  Balanced" },
                { id: "performance", label: "󱐋 Performance" }
              ]
              current: {
                switch (PowerProfiles.profile) {
                  case PowerProfile.PowerSaver: return "saver"
                  case PowerProfile.Performance: return "performance"
                  default: return "balanced"
                }
              }
              onPicked: function(id) {
                if (id === "saver") PowerProfiles.profile = PowerProfile.PowerSaver
                else if (id === "performance") PowerProfiles.profile = PowerProfile.Performance
                else PowerProfiles.profile = PowerProfile.Balanced
              }
            }
          }

          RowLayout {
            width: parent.width
            spacing: s(8)

            Repeater {
              model: [
                { icon: "󰛨", active: root.nightLightOn,  toggle: function() { root.toggleNightLight() } },
                { icon: "󰂛", active: root.dndOn,          toggle: function() { root.toggleDnd() } },
                { icon: "󰖩", active: root.wifiOn,         toggle: function() { root.toggleWifi() } },
                { icon: "󰂯", active: root.bluetoothOn,    toggle: function() { root.toggleBluetooth() } },
                { icon: "󰀝", active: root.airplaneModeOn, toggle: function() { root.toggleAirplaneMode() } }
              ]

              delegate: ClickButton {
                id: quickToggleBtn
                required property var modelData
                s: root.s
                fill: true
                Layout.preferredWidth: 1
                buttonHeight: 72
                iconSize: 20
                icon: modelData.icon
                active: modelData.active
                onClicked: modelData.toggle()
              }
            }
          }

      // Notifs box
          Rectangle {
            id: notifPanel
            width: parent.width
            // Fixed height regardless of how many notifications/groups
            // exist — 1 notification, 5, or 0 all get the same box size.
            // The list inside scrolls if content exceeds this.
            height: s(440)
            radius: s(10)
            color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)
            clip: true

            Row {
              id: notifHeader
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.margins: s(10)
              spacing: s(10)

              Text {
                text: root.hasNotif ? "󰂚" : "󰂛"
                font.pixelSize: s(14)
                font.family: "JetBrainsMono Nerd Font"
                color: root.hasNotif ? MatugenColors.accent : MatugenColors.textMuted
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "NOTIFICATIONS"
                font.pixelSize: s(10)
                font.weight: Font.Bold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.textMuted
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Row {
              id: notifHeaderActions
              anchors.top: parent.top
              anchors.right: parent.right
              anchors.margins: s(7)
              spacing: s(6)

              ClickButton {
                id: clearBtn
                s: root.s
                visible: root.hasNotif
                text: "Clear"
                icon: "\u2715"
                fontSize: 11
                iconSize: 10
                buttonHeight: 24
                hPadding: 8
                onClicked: Notifs.clearHistory()
              }
            }

            Rectangle {
              anchors.top: notifHeader.bottom
              anchors.topMargin: s(8)
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: s(10)
              anchors.rightMargin: s(10)
              height: 1
              color: Qt.rgba(1, 1, 1, 0.06)
            }

            Column {
              id: notifEmptyState
              visible: !root.hasNotif
              anchors.top: notifHeader.bottom
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.right: parent.right
              spacing: s(8)

              Item {
                width: 1
                height: (parent.height - emptyIcon.implicitHeight - emptyLabel.implicitHeight - s(8)) / 2
              }

              Text {
                id: emptyIcon
                text: "󰂛"
                font.pixelSize: s(22)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.textMuted
                anchors.horizontalCenter: parent.horizontalCenter
              }

              Text {
                id: emptyLabel
                text: "No notifications"
                font.pixelSize: s(11)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.textMuted
                anchors.horizontalCenter: parent.horizontalCenter
              }
            }

            ListView {
              id: notifList
              visible: root.hasNotif
              anchors.top: notifHeader.bottom
              anchors.topMargin: s(14)
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              anchors.leftMargin: s(10)
              anchors.rightMargin: s(10)
              anchors.bottomMargin: s(10)
              clip: true
              spacing: s(14)
              boundsBehavior: Flickable.StopAtBounds
              pressDelay: 120
              model: Notifs.groups

              add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                NumberAnimation { property: "y"; from: -20; duration: 200; easing.type: Easing.OutCubic }
              }
              remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: 150 }
              }
              displaced: Transition {
                NumberAnimation { property: "y"; duration: 200; easing.type: Easing.OutCubic }
              }

              delegate: Item {
                id: notifRow
                required property var modelData
                required property int index
                property bool expanded: false
                readonly property int memberCount: (notifRow.modelData.all || [notifRow.modelData.newest]).length
                readonly property bool isGroup: memberCount > 1
                readonly property bool bodyIsLong: (notifRow.modelData.newest.body || "").length > 0
                readonly property bool canExpandSingle: !notifRow.isGroup && notifRow.bodyIsLong

                property string timeText: ""
                function computeTimeText() {
                  let ts = notifRow.modelData.newest.timestamp || Date.now()
                  let diffSec = Math.floor((Date.now() - ts) / 1000)
                  if (diffSec < 60) { notifRow.timeText = "Just now"; return }
                  let diffMin = Math.floor(diffSec / 60)
                  if (diffMin < 60) { notifRow.timeText = diffMin + " min ago"; return }
                  let diffHr = Math.floor(diffMin / 60)
                  if (diffHr < 24) { notifRow.timeText = diffHr + "h ago"; return }
                  notifRow.timeText = Math.floor(diffHr / 24) + "d ago"
                }
                Component.onCompleted: computeTimeText()
                Timer { interval: 15000; running: true; repeat: true; onTriggered: notifRow.computeTimeText() }

                width: notifList.width
                height: notifRow.dismissing ? 0 : (cardCol.implicitHeight + s(10))
                clip: true

                Behavior on height {
                  enabled: !notifSwipeArea.pressed
                  NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                property real dragX: 0
                property bool dismissing: false
                readonly property real dismissThreshold: width * 0.35

                function dismiss() {
                  if (notifRow.dismissing) return
                  notifRow.dismissing = true
                  if (typeof Notifs.dismissGroup === "function") {
                    Notifs.dismissGroup(notifRow.modelData)
                  } else if (typeof Notifs.dismiss === "function") {
                    Notifs.dismiss(notifRow.modelData)
                  }
                }

                function dismissMember(entry) {
                  if (typeof Notifs.dismissEntry === "function") {
                    Notifs.dismissEntry(entry)
                  }
                }

                Rectangle {
                  id: rowBg
                  anchors.fill: parent
                  radius: s(8)
                  color: notifSwipeArea.pressed ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
                  Behavior on color { ColorAnimation { duration: 120 } }
                }

                Column {
                  id: cardCol
                  x: notifRow.dragX
                  width: parent.width
                  opacity: 1 - Math.min(1, Math.abs(notifRow.dragX) / notifRow.width)
                  Behavior on x { enabled: !notifSwipeArea.pressed; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                  Behavior on opacity { enabled: !notifSwipeArea.pressed; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                  spacing: s(8)

                  // ---- Summary row: icon, app name / summary / body, count badge, chevron ----
                  Item {
                    id: summaryRow
                    width: parent.width
                    height: Math.max(rowCol.implicitHeight, s(28))

                    Rectangle {
                      id: notifRowIconTile
                      anchors.top: parent.top
                      width: s(28)
                      height: s(28)
                      radius: s(9)
                      color: Qt.rgba(1, 1, 1, 0.06)

                      Image {
                        id: notifRowImg
                        anchors.fill: parent
                        anchors.margins: notifRow.modelData.newest.image ? 0 : 5
                        asynchronous: true
                        source: {
                          let n = notifRow.modelData.newest
                          let ic = n.image || n.imagePath || n.icon || n.iconPath || ""
                          if (!ic) return ""
                          if (ic.startsWith("file://") || ic.startsWith("image://") || ic.startsWith("http://") || ic.startsWith("https://")) return ic
                          return ic.startsWith("/") ? "file://" + ic : "image://icon/" + ic
                        }
                        sourceSize: Qt.size(32, 32)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        visible: status === Image.Ready && source !== ""
                      }

                      Text {
                        anchors.centerIn: parent
                        visible: !notifRowImg.visible
                        text: (notifRow.modelData.newest.appName || "?").charAt(0).toUpperCase()
                        font.pixelSize: s(11)
                        font.weight: Font.Bold
                        font.family: "JetBrainsMono Nerd Font"
                        color: MatugenColors.accent
                      }
                    }

                    Column {
                      id: rowCol
                      anchors.left: notifRowIconTile.right
                      anchors.leftMargin: s(10)
                      anchors.right: rightControls.left
                      anchors.rightMargin: s(8)
                      anchors.verticalCenter: notifRowIconTile.verticalCenter
                      spacing: 2

                      Row {
                        width: parent.width
                        spacing: s(6)

                        Text {
                          text: notifRow.modelData.newest.appName || "System"
                          font.pixelSize: s(12)
                          font.weight: Font.Bold
                          font.family: "JetBrainsMono Nerd Font"
                          color: MatugenColors.text
                          elide: Text.ElideRight
                        }

                        Text {
                          text: "\u00b7"
                          font.pixelSize: s(11)
                          font.family: "JetBrainsMono Nerd Font"
                          color: MatugenColors.textDim
                        }

                        Text {
                          text: notifRow.timeText
                          font.pixelSize: s(10)
                          font.family: "JetBrainsMono Nerd Font"
                          color: MatugenColors.textDim
                        }
                      }

                      Text {
                        visible: !notifRow.isGroup && (notifRow.modelData.newest.summary || "").length > 0
                        text: notifRow.modelData.newest.summary || ""
                        font.pixelSize: s(11)
                        font.weight: Font.Bold
                        font.family: "JetBrainsMono Nerd Font"
                        color: MatugenColors.text
                        elide: Text.ElideRight
                        width: parent.width
                      }

                      Text {
                        visible: !notifRow.isGroup && notifRow.bodyIsLong
                        text: notifRow.modelData.newest.body || ""
                        font.pixelSize: s(10)
                        font.family: "JetBrainsMono Nerd Font"
                        color: MatugenColors.textMuted
                        width: parent.width
                        wrapMode: notifRow.expanded ? Text.Wrap : Text.NoWrap
                        maximumLineCount: notifRow.expanded ? 0 : 1
                        elide: notifRow.expanded ? Text.ElideNone : Text.ElideRight
                        Behavior on maximumLineCount { NumberAnimation { duration: 0 } }
                      }
                    }

                    Row {
                      id: rightControls
                      anchors.right: parent.right
                      anchors.verticalCenter: notifRowIconTile.verticalCenter
                      spacing: s(6)

                      Rectangle {
                        visible: notifRow.isGroup
                        width: countLabel.implicitWidth + s(10)
                        height: s(18)
                        radius: s(9)
                        color: Qt.rgba(1, 1, 1, 0.08)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                          id: countLabel
                          anchors.centerIn: parent
                          text: notifRow.memberCount
                          font.pixelSize: s(10)
                          font.weight: Font.Bold
                          font.family: "JetBrainsMono Nerd Font"
                          color: MatugenColors.text
                        }
                      }

                      Text {
                        visible: notifRow.isGroup || notifRow.canExpandSingle
                        text: notifRow.expanded ? "\uf077" : "\uf078"
                        font.pixelSize: s(11)
                        font.family: "JetBrainsMono Nerd Font"
                        color: MatugenColors.textMuted
                        anchors.verticalCenter: parent.verticalCenter
                      }
                    }
                  }

                  // ---- Expanded member list (only for grouped notifications) ----
                  Column {
                    id: expandedCol
                    visible: notifRow.isGroup && notifRow.expanded
                    width: parent.width
                    spacing: s(8)
                    leftPadding: s(38)

                    Repeater {
                      model: notifRow.isGroup ? notifRow.modelData.all : []
                      delegate: Rectangle {
                        id: memberRow
                        required property var modelData
                        width: expandedCol.width - expandedCol.leftPadding
                        height: memberInnerCol.implicitHeight + s(16)
                        radius: s(7)
                        color: Qt.rgba(1, 1, 1, 0.04)

                        property bool memberExpanded: false
                        readonly property bool memberBodyIsLong: (memberRow.modelData.body || "").length > 0
                        property string memberTimeText: ""
                        function computeMemberTimeText() {
                          let ts = memberRow.modelData.timestamp || Date.now()
                          let diffSec = Math.floor((Date.now() - ts) / 1000)
                          if (diffSec < 60) { memberRow.memberTimeText = "Just now"; return }
                          let diffMin = Math.floor(diffSec / 60)
                          if (diffMin < 60) { memberRow.memberTimeText = diffMin + " min ago"; return }
                          let diffHr = Math.floor(diffMin / 60)
                          if (diffHr < 24) { memberRow.memberTimeText = diffHr + "h ago"; return }
                          memberRow.memberTimeText = Math.floor(diffHr / 24) + "d ago"
                        }
                        Component.onCompleted: computeMemberTimeText()
                        Timer { interval: 15000; running: true; repeat: true; onTriggered: memberRow.computeMemberTimeText() }

                        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                        // Small icon per member, matching the reference
                        // (each ungrouped entry keeps its own icon/title).
                        Rectangle {
                          id: memberIconTile
                          anchors.left: parent.left
                          anchors.verticalCenter: parent.verticalCenter
                          anchors.margins: s(8)
                          width: s(22)
                          height: s(22)
                          radius: s(7)
                          color: Qt.rgba(1, 1, 1, 0.06)

                          Image {
                            anchors.fill: parent
                            anchors.margins: memberRow.modelData.image ? 0 : 4
                            asynchronous: true
                            source: {
                              let n = memberRow.modelData
                              let ic = n.image || n.imagePath || n.icon || n.iconPath || ""
                              if (!ic) return ""
                              if (ic.startsWith("file://") || ic.startsWith("image://") || ic.startsWith("http://") || ic.startsWith("https://")) return ic
                              return ic.startsWith("/") ? "file://" + ic : "image://icon/" + ic
                            }
                            sourceSize: Qt.size(26, 26)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: status === Image.Ready && source !== ""
                          }

                          Text {
                            anchors.centerIn: parent
                            visible: parent.children[0].status !== Image.Ready
                            text: (memberRow.modelData.appName || "?").charAt(0).toUpperCase()
                            font.pixelSize: s(9)
                            font.weight: Font.Bold
                            font.family: "JetBrainsMono Nerd Font"
                            color: MatugenColors.accent
                          }
                        }

                        Column {
                          id: memberInnerCol
                          anchors.left: memberIconTile.right
                          anchors.leftMargin: s(8)
                          anchors.right: memberDismiss.left
                          anchors.rightMargin: s(6)
                          anchors.verticalCenter: parent.verticalCenter
                          spacing: 2

                          Row {
                            width: parent.width
                            spacing: s(6)
                            Text {
                              text: memberRow.modelData.summary || ""
                              font.pixelSize: s(11)
                              font.weight: Font.Bold
                              font.family: "JetBrainsMono Nerd Font"
                              color: MatugenColors.text
                              elide: Text.ElideRight
                            }
                            Text {
                              text: "\u00b7"
                              font.pixelSize: s(10)
                              font.family: "JetBrainsMono Nerd Font"
                              color: MatugenColors.textDim
                            }
                            Text {
                              text: memberRow.memberTimeText
                              font.pixelSize: s(10)
                              font.family: "JetBrainsMono Nerd Font"
                              color: MatugenColors.textDim
                            }
                          }
                          Text {
                            visible: memberRow.memberBodyIsLong
                            text: memberRow.modelData.body || ""
                            font.pixelSize: s(10)
                            font.family: "JetBrainsMono Nerd Font"
                            color: MatugenColors.textMuted
                            width: parent.width
                            wrapMode: memberRow.memberExpanded ? Text.Wrap : Text.NoWrap
                            maximumLineCount: memberRow.memberExpanded ? 0 : 1
                            elide: memberRow.memberExpanded ? Text.ElideNone : Text.ElideRight
                          }
                        }

                        // Per-member chevron to expand its own full text,
                        // matching the reference's "each ungrouped
                        // notification has icon + title + description with
                        // an arrow to expand it".
                        Text {
                          visible: memberRow.memberBodyIsLong
                          anchors.right: memberDismiss.left
                          anchors.rightMargin: s(8)
                          anchors.verticalCenter: parent.verticalCenter
                          text: memberRow.memberExpanded ? "\uf077" : "\uf078"
                          font.pixelSize: s(10)
                          font.family: "JetBrainsMono Nerd Font"
                          color: MatugenColors.textMuted

                          MouseArea {
                            anchors.fill: parent
                            anchors.margins: -s(6)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: memberRow.memberExpanded = !memberRow.memberExpanded
                          }
                        }

                        CloseButton {
                          id: memberDismiss
                          s: root.s
                          size: 20
                          iconSize: 8
                          anchors.right: parent.right
                          anchors.rightMargin: s(8)
                          anchors.verticalCenter: parent.verticalCenter
                          onClicked: notifRow.dismissMember(memberRow.modelData)
                        }
                      }
                    }
                  }
                }

                MouseArea {
                  id: notifSwipeArea
                  x: cardCol.x + summaryRow.x
                  y: cardCol.y + summaryRow.y
                  width: summaryRow.width
                  height: summaryRow.height
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  preventStealing: true

                  property real pressStartX: 0
                  property bool didDrag: false
                  readonly property real dragActivationThreshold: s(12)

                  onPressed: (mouse) => {
                    pressStartX = mouse.x
                    didDrag = false
                  }
                  onPositionChanged: (mouse) => {
                    if (!pressed) return
                    let delta = mouse.x - pressStartX
                    if (Math.abs(delta) > notifSwipeArea.dragActivationThreshold) {
                      didDrag = true
                      notifRow.dragX = delta
                    }
                  }
                  onReleased: {
                    if (!didDrag) {
                      notifRow.dragX = 0
                      if (notifRow.isGroup || notifRow.canExpandSingle) {
                        notifRow.expanded = !notifRow.expanded
                      }
                      return
                    }
                    if (Math.abs(notifRow.dragX) > notifRow.dismissThreshold) {
                      notifRow.dragX = notifRow.dragX < 0 ? -notifRow.width : notifRow.width
                      notifRow.dismiss()
                    } else {
                      notifRow.dragX = 0
                    }
                  }
                  onCanceled: { notifRow.dragX = 0 }
                }

                Rectangle {
                  anchors.bottom: parent.bottom
                  width: parent.width
                  height: 1
                  color: Qt.rgba(1, 1, 1, 0.05)
                  visible: notifRow.index < notifList.count - 1 && !notifRow.dismissing
                }
              }
            }
          }
        }
      }
    }
  }
}
