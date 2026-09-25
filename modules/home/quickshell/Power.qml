import "Singletons"
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import "./Singletons"

Item {
  id: root

  Component.onCompleted: {
        Scaler.currentWidth = Screen.width
        Scaler.currentHeight = Screen.height
    }
  function s(val) { return Scaler.s(val) }

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
  onMenuOpenChanged: if (menuOpen) brightnessGetProc.running = true
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
  property bool airplaneModeOn: false

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

  Process {
    id: airplaneOnProc
    command: ["rfkill", "block", "all"]
  }
  Process {
    id: airplaneOffProc
    command: ["rfkill", "unblock", "all"]
  }
  function toggleAirplaneMode() {
    root.airplaneModeOn = !root.airplaneModeOn
    if (root.airplaneModeOn) airplaneOnProc.running = true
    else airplaneOffProc.running = true
  }

  property bool dndOn: false
  function toggleDnd() {
    root.dndOn = !root.dndOn
    if (typeof Notifs !== "undefined") Notifs.silent = root.dndOn
  }

  property bool wifiOn: true
  Process {
    id: wifiOnProc
    command: ["nmcli", "radio", "wifi", "on"]
  }
  Process {
    id: wifiOffProc
    command: ["nmcli", "radio", "wifi", "off"]
  }
  function toggleWifi() {
    root.wifiOn = !root.wifiOn
    if (root.wifiOn) wifiOnProc.running = true
    else wifiOffProc.running = true
  }

  property bool bluetoothOn: true
  Process {
    id: bluetoothOnProc
    command: ["bluetoothctl", "power", "on"]
  }
  Process {
    id: bluetoothOffProc
    command: ["bluetoothctl", "power", "off"]
  }
  function toggleBluetooth() {
    root.bluetoothOn = !root.bluetoothOn
    if (root.bluetoothOn) bluetoothOnProc.running = true
    else bluetoothOffProc.running = true
  }

  Audio { id: audioModule }
  readonly property alias volumeLevel: audioModule.volumeLevel
  readonly property alias volumeMuted: audioModule.muted
  readonly property alias volumeIcon: audioModule.volumeIcon

  property int brightnessPct: 100
  property bool brightnessAvailable: true
  property int _brightnessMax: 100
  // LG UltraFine is an external display — no /sys/class/backlight device
  // exists for it, so brightness goes over DDC/CI via ddcutil instead of
  // brightnessctl. VCP code 10 is the standard DDC/CI brightness control.
  // Bus is hardcoded from `ddcutil detect` rather than auto-scanned on every
  // call — scanning all /dev/i2c-* buses adds real latency per invocation.
  readonly property string ddcBus: "0"
  readonly property string ddcVcpBrightness: "10"

  Process {
    id: brightnessGetProc
    command: ["ddcutil", "-b", root.ddcBus, "getvcp", root.ddcVcpBrightness, "--brief"]
    running: true
    stdout: SplitParser {
      // --brief format on this system: "VCP 10 C <current> <max>" — decimal,
      // with a type-flag field ("C" = continuous) between the code and values.
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
        x: Config.barPosition === "left" ? s(80) : (Config.barPosition === "right" ? (Screen.width - width - s(80)) : (Screen.width - width - s(8)))
        y: Config.barPosition === "bottom" ? (Screen.height - height - s(70)) : s(70)
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

            Rectangle {
              id: headerLogoutBtn
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: s(90)
              height: s(34)
              radius: s(8)
              color: headerLogoutArea.containsMouse ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16) : Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.6)
              Behavior on color { ColorAnimation { duration: 150 } }

              Row {
                anchors.centerIn: parent
                spacing: s(6)

                Text {
                  text: "󰍃"
                  font.pixelSize: s(13)
                  font.family: "JetBrainsMono Nerd Font"
                  color: headerLogoutArea.containsMouse ? MatugenColors.accent : MatugenColors.text
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: "Logout"
                  font.pixelSize: s(11)
                  font.weight: Font.Medium
                  font.family: "JetBrainsMono Nerd Font"
                  color: headerLogoutArea.containsMouse ? MatugenColors.accent : MatugenColors.text
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              MouseArea {
                id: headerLogoutArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.menuOpen = false
                  logoutProc.running = true
                }
              }
            }
          }

          Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

          Row {
            width: parent.width
            spacing: s(8)

            Repeater {
              model: [
                { label: "Lock",     icon: "󰌾", action: function() { lockProc.running = true }, spacer: false },
                { label: "Sleep",    icon: "󰒲", action: function() { sleepProc.running = true }, spacer: false },
                { label: "",         icon: "",  action: function() {}, spacer: true },
                { label: "Restart",  icon: "󰜉", action: function() { restartProc.running = true }, spacer: false },
                { label: "Shutdown", icon: "⏻", action: function() { shutdownProc.running = true }, spacer: false }
              ]

              delegate: Rectangle {
                id: actionBtn
                required property var modelData
                width: modelData.spacer ? s(8) : (mainColumn.width - 4 * s(8) - s(8)) / 4
                height: modelData.spacer ? s(48) : s(72)
                anchors.verticalCenter: modelData.spacer ? parent.verticalCenter : undefined
                radius: modelData.spacer ? s(4) : s(12)
                color: modelData.spacer ? Qt.rgba(1, 1, 1, 0.08) : (btnArea.containsMouse ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16) : Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.6))
                Behavior on color { ColorAnimation { duration: 150 } }
                clip: true

                property real holdProgress: 0
                readonly property int holdDurationMs: 600
                readonly property int stepMs: 16

                Timer {
                  id: holdTimer
                  interval: actionBtn.stepMs
                  repeat: true
                  running: false
                  onTriggered: {
                    actionBtn.holdProgress = Math.min(1, actionBtn.holdProgress + actionBtn.stepMs / actionBtn.holdDurationMs)
                    if (actionBtn.holdProgress >= 1) {
                      holdTimer.stop()
                      root.menuOpen = false
                      actionBtn.holdProgress = 0
                      actionBtn.modelData.action()
                    }
                  }
                }

                Rectangle {
                  visible: !actionBtn.modelData.spacer && actionBtn.holdProgress > 0
                  anchors.bottom: parent.bottom
                  anchors.left: parent.left
                  width: parent.width
                  height: parent.height * actionBtn.holdProgress
                  radius: parent.radius
                  color: Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.35)
                }

                Text {
                  visible: !actionBtn.modelData.spacer
                  anchors.centerIn: parent
                  text: actionBtn.modelData.icon
                  font.pixelSize: s(20)
                  font.family: "JetBrainsMono Nerd Font"
                  color: btnArea.containsMouse ? MatugenColors.accent : MatugenColors.text
                  Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                  id: btnArea
                  anchors.fill: parent
                  enabled: !actionBtn.modelData.spacer
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onPressed: {
                    actionBtn.holdProgress = 0
                    holdTimer.start()
                  }
                  onReleased: {
                    holdTimer.stop()
                    actionBtn.holdProgress = 0
                  }
                  onCanceled: {
                    holdTimer.stop()
                    actionBtn.holdProgress = 0
                  }
                }
              }
            }
          }

          Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

          // ── Quick controls: sound + brightness ──
          Column {
            width: parent.width
            spacing: s(10)

            Row {
              width: parent.width
              spacing: s(10)

              Text {
                text: root.volumeMuted ? "\u{f026}" : root.volumeIcon
                font.pixelSize: s(15)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.accent
                anchors.verticalCenter: parent.verticalCenter
                width: s(18)
              }

              Item {
                id: volSliderRoot
                width: parent.width - s(70)
                height: s(18)
                anchors.verticalCenter: parent.verticalCenter

                readonly property real frac: root.volumeMuted ? 0 : Math.min(100, root.volumeLevel) / 100

                Rectangle {
                  id: volTrack
                  anchors.fill: parent
                  radius: height / 2
                  color: Qt.rgba(1, 1, 1, 0.08)
                  clip: true

                  Rectangle {
                    width: Math.max(parent.radius * 2, parent.width * volSliderRoot.frac)
                    height: parent.height
                    radius: parent.radius
                    color: MatugenColors.accent
                    Behavior on width { enabled: !volSliderArea.pressed; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                  }

                  Rectangle {
                    width: s(2)
                    height: parent.height
                    x: Math.max(0, Math.min(parent.width - width, parent.width * volSliderRoot.frac - width / 2))
                    color: MatugenColors.bgBase
                    opacity: 0.55
                    Behavior on x { enabled: !volSliderArea.pressed; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                  }
                }

                MouseArea {
                  id: volSliderArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onPressed: (mouse) => audioModule.setVolume(Math.round(Math.max(0, Math.min(1, mouse.x / width)) * 100))
                  onPositionChanged: (mouse) => { if (pressed) audioModule.setVolume(Math.round(Math.max(0, Math.min(1, mouse.x / width)) * 100)) }
                }
              }

              Text {
                text: root.volumeMuted ? "Mute" : root.volumeLevel + "%"
                font.pixelSize: s(11)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.textMuted
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                width: s(34)
              }
            }

            Row {
              width: parent.width
              spacing: s(10)

              Text {
                text: "\u{f0eb}"
                font.pixelSize: s(15)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.accent
                anchors.verticalCenter: parent.verticalCenter
                width: s(18)
              }

              Item {
                id: brightSliderRoot
                width: parent.width - s(70)
                height: s(18)
                anchors.verticalCenter: parent.verticalCenter

                readonly property real frac: root.brightnessPct / 100

                Rectangle {
                  id: brightTrack
                  anchors.fill: parent
                  radius: height / 2
                  color: Qt.rgba(1, 1, 1, 0.08)
                  clip: true

                  Rectangle {
                    width: Math.max(parent.radius * 2, parent.width * brightSliderRoot.frac)
                    height: parent.height
                    radius: parent.radius
                    color: MatugenColors.accent
                    Behavior on width { enabled: !brightSliderArea.pressed; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                  }

                  Rectangle {
                    width: s(2)
                    height: parent.height
                    x: Math.max(0, Math.min(parent.width - width, parent.width * brightSliderRoot.frac - width / 2))
                    color: MatugenColors.bgBase
                    opacity: 0.55
                    Behavior on x { enabled: !brightSliderArea.pressed; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                  }
                }

                MouseArea {
                  id: brightSliderArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onPressed: (mouse) => root.setBrightness(Math.max(0, Math.min(1, mouse.x / width)) * 100)
                  onPositionChanged: (mouse) => { if (pressed) root.setBrightness(Math.max(0, Math.min(1, mouse.x / width)) * 100) }
                }
              }

              Text {
                text: root.brightnessAvailable ? (root.brightnessPct + "%") : "N/A"
                font.pixelSize: s(11)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.textMuted
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                width: s(34)
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

            Row {
              anchors.right: parent.right
              anchors.rightMargin: s(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: s(12)

              Repeater {
                model: [
                  { profile: PowerProfile.PowerSaver, icon: "󰌪 Saver" },
                  { profile: PowerProfile.Balanced,   icon: "  Balanced" },
                  { profile: PowerProfile.Performance, icon: "󱐋 Performance" }
                ]

                delegate: Rectangle {
                  required property var modelData
                  readonly property bool active: PowerProfiles.profile === modelData.profile
                  width: s(130)
                  height: s(32)
                  radius: s(8)
                  color: active ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.25)
                                : (ppArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                  Behavior on color { ColorAnimation { duration: 150 } }

                  Text {
                    anchors.centerIn: parent
                    text: parent.modelData.icon
                    font.pixelSize: s(14)
                    font.family: "JetBrainsMono Nerd Font"
                    color: parent.active ? MatugenColors.accent : MatugenColors.textDim
                  }

                  MouseArea {
                    id: ppArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PowerProfiles.profile = parent.modelData.profile
                  }
                }
              }
            }
          }

          Row {
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

              delegate: Rectangle {
                id: quickToggleBtn
                required property var modelData
                width: (mainColumn.width - 4 * s(8)) / 5
                height: s(72)
                radius: s(12)
                color: modelData.active
                  ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.22)
                  : (quickToggleArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.6))
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                  anchors.centerIn: parent
                  text: quickToggleBtn.modelData.icon
                  font.pixelSize: s(20)
                  font.family: "JetBrainsMono Nerd Font"
                  color: quickToggleBtn.modelData.active ? MatugenColors.accent : MatugenColors.text
                  Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                  id: quickToggleArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: quickToggleBtn.modelData.toggle()
                }
              }
            }
          }

      // Notifs box
          Rectangle {
            id: notifPanel
            width: parent.width
            height: root.hasNotif ? Math.max(s(400), Math.min(notifList.contentHeight + s(50), s(620))) : s(440)
            radius: s(10)
            color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)
            clip: true
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

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

              Rectangle {
                id: clearBtn
                visible: root.hasNotif
                width: clearRow.implicitWidth + s(16)
                height: s(8)
                radius: s(8)
                anchors.verticalCenter: parent.verticalCenter
                color: clearArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                  id: clearRow
                  anchors.centerIn: parent
                  spacing: s(5)
                  Text {
                    text: "\u2715"
                    font.pixelSize: s(10)
                    font.family: "JetBrainsMono Nerd Font"
                    color: MatugenColors.textMuted
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Text {
                    text: "Clear"
                    font.pixelSize: s(11)
                    font.weight: Font.Medium
                    font.family: "JetBrainsMono Nerd Font"
                    color: MatugenColors.textMuted
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                MouseArea {
                  id: clearArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: Notifs.clearHistory()
                }
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
              // groups is one entry per distinct notification, newest first —
              // that's the list a user expects here, not just the single latest one.
              model: Notifs.groups

              delegate: Item {
                id: notifRow
                required property var modelData
                required property int index
                property bool expanded: false
                readonly property int memberCount: (notifRow.modelData.all || [notifRow.modelData.newest]).length
                readonly property bool isGroup: memberCount > 1

                width: notifList.width
                height: cardCol.implicitHeight + s(10)
                clip: false

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

                      Text {
                        text: (notifRow.modelData.newest.appName || "System").toUpperCase()
                        font.pixelSize: s(9)
                        font.weight: Font.Bold
                        font.letterSpacing: 1
                        font.family: "JetBrainsMono Nerd Font"
                        color: MatugenColors.textDim
                        elide: Text.ElideRight
                        width: parent.width
                      }

                      Text {
                        text: notifRow.modelData.newest.summary || ""
                        font.pixelSize: s(12)
                        font.weight: Font.Bold
                        font.family: "JetBrainsMono Nerd Font"
                        color: MatugenColors.text
                        elide: Text.ElideRight
                        width: parent.width
                      }

                      Text {
                        visible: (notifRow.modelData.newest.body || "").length > 0
                        text: notifRow.modelData.newest.body || ""
                        font.pixelSize: s(10)
                        font.family: "JetBrainsMono Nerd Font"
                        color: MatugenColors.textMuted
                        elide: Text.ElideRight
                        width: parent.width
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
                        visible: notifRow.isGroup
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
                        height: memberCol.implicitHeight + s(16)
                        radius: s(7)
                        color: Qt.rgba(1, 1, 1, 0.04)

                        Column {
                          id: memberCol
                          anchors.left: parent.left
                          anchors.right: memberDismiss.left
                          anchors.verticalCenter: parent.verticalCenter
                          anchors.margins: s(8)
                          spacing: 2

                          Text {
                            text: memberRow.modelData.summary || ""
                            font.pixelSize: s(11)
                            font.weight: Font.Bold
                            font.family: "JetBrainsMono Nerd Font"
                            color: MatugenColors.text
                            elide: Text.ElideRight
                            width: parent.width
                          }
                          Text {
                            visible: (memberRow.modelData.body || "").length > 0
                            text: memberRow.modelData.body || ""
                            font.pixelSize: s(10)
                            font.family: "JetBrainsMono Nerd Font"
                            color: MatugenColors.textMuted
                            elide: Text.ElideRight
                            width: parent.width
                          }
                        }

                        Text {
                          id: memberDismiss
                          anchors.right: parent.right
                          anchors.verticalCenter: parent.verticalCenter
                          anchors.margins: s(10)
                          text: "\u2715"
                          font.pixelSize: s(10)
                          font.family: "JetBrainsMono Nerd Font"
                          color: memberDismissArea.containsMouse ? MatugenColors.text : MatugenColors.textMuted
                          Behavior on color { ColorAnimation { duration: 120 } }

                          MouseArea {
                            id: memberDismissArea
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: notifRow.dismissMember(memberRow.modelData)
                          }
                        }
                      }
                    }
                  }
                }

                Behavior on height {
                  enabled: !notifSwipeArea.pressed
                  NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                MouseArea {
                  id: notifSwipeArea
                  anchors.fill: summaryRow
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  preventStealing: true

                  property real pressStartX: 0
                  property bool didDrag: false

                  onPressed: (mouse) => {
                    pressStartX = mouse.x
                    didDrag = false
                  }
                  onPositionChanged: (mouse) => {
                    if (!pressed) return
                    let delta = mouse.x - pressStartX
                    if (Math.abs(delta) > s(4)) didDrag = true
                    // Swipe either direction to dismiss.
                    notifRow.dragX = delta
                  }
                  onReleased: {
                    if (!didDrag) {
                      // Plain tap: toggle expand for groups, dismiss for singles.
                      if (notifRow.isGroup) {
                        notifRow.expanded = !notifRow.expanded
                      } else {
                        notifRow.dismiss()
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
                  visible: notifRow.index < notifList.count - 1
                }
              }
            }
          }
        }
      }
    }
  }
}
