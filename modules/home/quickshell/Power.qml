import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower

Item {
  id: root

  Scaler {
    id: scaler
    currentWidth: Screen.width
    currentHeight: Screen.height
  }
  function s(val) { return scaler.s(val) }

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
  property bool entered: false
  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }
  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } } }
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

  Process { id: shutdownProc; command: ["systemctl", "poweroff"] }
  Process { id: restartProc;  command: ["systemctl", "reboot"] }
  Process { id: sleepProc;    command: ["systemctl", "suspend"] }
  Process { id: logoutProc;   command: ["hyprctl", "dispatch", "exit"] }
  Process {
    id: lockProc
    command: ["qs", "-p", Quickshell.env("HOME") + "/.config/quickshell/Lock.qml"]
  }

  property real cpuPct: 0
  property real ramPct: 0
  property string ramUsedStr: "--"
  property string tempStr: "--"
  property real diskPct: 0
  property string diskUsedStr: "--"
  property string netStr: "0 KB/s"
  property string uptimeStr: "--"

  property var _prevCpuIdle: 0
  property var _prevCpuTotal: 0
  property var _prevRx: -1
  property var _prevTx: -1

  Timer {
    interval: 2000
    running: root.menuOpen
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      cpuProc.running = true
      ramProc.running = true
      tempProc.running = true
      diskProc.running = true
      netProc.running = true
      uptimeProc.running = true
    }
  }

  Process {
    id: cpuProc
    command: ["sh", "-c", "head -n1 /proc/stat"]
    stdout: SplitParser {
      onRead: data => {
        const parts = data.trim().split(/\s+/).slice(1).map(Number)
        const idle = parts[3] + parts[4]
        const total = parts.reduce((a, b) => a + b, 0)
        const prevIdle = root._prevCpuIdle
        const prevTotal = root._prevCpuTotal
        const totalDiff = total - prevTotal
        const idleDiff = idle - prevIdle
        if (prevTotal > 0 && totalDiff > 0) {
          root.cpuPct = Math.max(0, Math.min(100, 100 * (1 - idleDiff / totalDiff)))
        }
        root._prevCpuIdle = idle
        root._prevCpuTotal = total
      }
    }
  }

  Process {
    id: ramProc
    command: ["sh", "-c", "grep -E 'MemTotal|MemAvailable' /proc/meminfo"]
    stdout: SplitParser {
      splitMarker: ""
      onRead: data => {
        const lines = data.trim().split("\n")
        let total = 0, avail = 0
        for (const l of lines) {
          const m = l.match(/(\d+)/)
          if (!m) continue
          if (l.startsWith("MemTotal")) total = parseInt(m[1])
          if (l.startsWith("MemAvailable")) avail = parseInt(m[1])
        }
        if (total > 0) {
          const used = total - avail
          root.ramPct = 100 * used / total
          root.ramUsedStr = (used / 1024 / 1024).toFixed(1) + "G / " + (total / 1024 / 1024).toFixed(1) + "G"
        }
      }
    }
  }

  Process {
    id: tempProc
    command: ["sh", "-c", "sh -c 'for hw in /sys/class/hwmon/hwmon*/temp*_input; do label_file=\"${hw%_input}_label\"; if [ -f \"$label_file\" ]; then label=$(cat \"$label_file\"); case $label in *Package*|*CPU*|*Tctl*|*Tdie*|*Core*) cat $hw; exit;; esac; fi; done'"]
    stdout: SplitParser {
      onRead: data => {
        const v = parseInt(data.trim())
        if (isNaN(v)) { root.tempStr = "--"; return }
        const celsius = v / 1000
        root.tempStr = Config.tempUnitFahrenheit
          ? Math.round(celsius * 9 / 5 + 32) + "°F"
          : Math.round(celsius) + "°C"
      }
    }
  }

  Process {
    id: diskProc
    command: ["sh", "-c", "df -BG --output=used,size / | tail -n1"]
    stdout: SplitParser {
      onRead: data => {
        const parts = data.trim().split(/\s+/)
        if (parts.length >= 2) {
          const used = parseInt(parts[0])
          const size = parseInt(parts[1])
          if (size > 0) {
            root.diskPct = 100 * used / size
            root.diskUsedStr = used + "G / " + size + "G"
          }
        }
      }
    }
  }

  Process {
    id: netProc
    command: ["sh", "-c", "cat /proc/net/dev | tail -n+3 | grep -v ' lo:' | awk '{rx+=$2; tx+=$10} END {print rx, tx}'"]
    stdout: SplitParser {
      onRead: data => {
        const parts = data.trim().split(/\s+/).map(Number)
        if (parts.length < 2) return
        const [rx, tx] = parts
        if (root._prevRx >= 0) {
          const rxRate = (rx - root._prevRx) / 2 / 1024
          const txRate = (tx - root._prevTx) / 2 / 1024
          root.netStr = "↓" + rxRate.toFixed(0) + " ↑" + txRate.toFixed(0) + " KB/s"
        }
        root._prevRx = rx
        root._prevTx = tx
      }
    }
  }

  Process {
    id: uptimeProc
    command: ["sh", "-c", "awk '{printf \"%d:%02d\", $1/3600, ($1%3600)/60}' /proc/uptime"]
    stdout: SplitParser {
      onRead: data => { root.uptimeStr = data.trim() }
    }
  }

  readonly property var latestGroup: Notifs.groups.length > 0 ? Notifs.groups[0] : null
  readonly property bool hasNotif: root.latestGroup !== null
  readonly property string lastNotifSummary: root.latestGroup ? root.latestGroup.newest.summary : "No new notifications"
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
        width: s(680)
        x: Config.barPosition === "left" ? s(8) : (Screen.width - width - s(8))
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
        implicitHeight: mainColumn.implicitHeight + s(48)
        height: implicitHeight
        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Keys.onEscapePressed: root.menuOpen = false
        MouseArea { anchors.fill: parent }

        Column {
          id: mainColumn
          anchors.fill: parent
          anchors.margins: s(16)
          spacing: s(14)

          Row {
            width: parent.width
            spacing: s(8)

            Repeater {
              model: [
                { label: "Lock",     icon: "󰌾", action: function() { lockProc.running = true } },
                { label: "Sleep",    icon: "󰒲", action: function() { sleepProc.running = true } },
                { label: "Logout",   icon: "󰍃", action: function() { logoutProc.running = true } },
                { label: "Restart",  icon: "󰜉", action: function() { restartProc.running = true } },
                { label: "Shutdown", icon: "⏻", action: function() { shutdownProc.running = true } }
              ]

              delegate: Rectangle {
                id: actionBtn
                required property var modelData
                width: (mainColumn.width - 4 * s(8)) / 5
                height: s(72)
                radius: s(12)
                color: btnArea.containsMouse ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16) : Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.6)
                Behavior on color { ColorAnimation { duration: 150 } }

                Column {
                  anchors.centerIn: parent
                  spacing: s(4)

                  Text {
                    text: actionBtn.modelData.icon
                    font.pixelSize: s(17)
                    font.family: "JetBrainsMono Nerd Font"
                    color: btnArea.containsMouse ? MatugenColors.accent : MatugenColors.text
                    Behavior on color { ColorAnimation { duration: 150 } }
                    anchors.horizontalCenter: parent.horizontalCenter
                  }

                  Text {
                    text: actionBtn.modelData.label
                    font.pixelSize: s(10)
                    font.weight: Font.Medium
                    font.family: "JetBrainsMono Nerd Font"
                    color: btnArea.containsMouse ? MatugenColors.text : MatugenColors.textDim
                    Behavior on color { ColorAnimation { duration: 150 } }
                    anchors.horizontalCenter: parent.horizontalCenter
                  }
                }

                MouseArea {
                  id: btnArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.menuOpen = false
                    actionBtn.modelData.action()
                  }
                }
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

          Row {
            spacing: s(8)

            Text {
              text: "󰥔"
              font.pixelSize: s(13)
              font.family: "JetBrainsMono Nerd Font"
              color: MatugenColors.textMuted
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: "Uptime: " + root.uptimeStr
              font.pixelSize: s(11)
              font.family: "JetBrainsMono Nerd Font"
              color: MatugenColors.textDim
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Rectangle {
            visible: PowerProfiles.available
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
              spacing: s(4)

              Repeater {
                model: [
                  { profile: PowerProfile.PowerSaver, icon: "󰡳" },
                  { profile: PowerProfile.Balanced,   icon: "󰊚" },
                  { profile: PowerProfile.Performance, icon: "󱐋" }
                ]

                delegate: Rectangle {
                  required property var modelData
                  readonly property bool active: PowerProfiles.profile === modelData.profile
                  width: s(48)
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

          Rectangle {
            width: parent.width
            height: s(56)
            radius: s(10)
            color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

            Row {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: s(10)
              anchors.rightMargin: s(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: s(10)

              Text {
                text: root.hasNotif ? "󰂚" : "󰂛"
                font.pixelSize: s(14)
                font.family: "JetBrainsMono Nerd Font"
                color: root.hasNotif ? MatugenColors.accent : MatugenColors.textMuted
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                spacing: 1
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - s(30)

                Text {
                  text: root.lastNotifSummary
                  font.pixelSize: s(11)
                  font.weight: Font.Medium
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.text
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  visible: root.lastNotifBody.length > 0
                  text: root.lastNotifBody
                  font.pixelSize: s(10)
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.textMuted
                  elide: Text.ElideRight
                  width: parent.width
                }
              }
            }
          }
        }
      }
    }
  }
}
