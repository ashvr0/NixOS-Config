import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: root

IpcHandler {
    target: "powermenu"
    function toggle(): void {
      root.menuOpen = !root.menuOpen
    }
  }

  implicitWidth: pillBg.width
  implicitHeight: pillBg.height

  property int cascadeIndex: 5
  property bool menuOpen: false
  property bool entered: false
  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }
  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutBack } } }
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

  Process { id: shutdownProc; command: ["systemctl", "poweroff"] }
  Process { id: restartProc;  command: ["systemctl", "reboot"] }
  Process { id: sleepProc;    command: ["systemctl", "suspend"] }
  Process { id: logoutProc;   command: ["hyprctl", "dispatch", "exit"] }
  Process {
    id: lockProc
    command: ["qs", "-p", Quickshell.env("HOME") + "/.config/quickshell/Lock.qml"]
  }

  // system stats
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

  // CPU
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

  // RAM
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

  // Temp
Process {
  id: tempProc
  command: ["sh", "-c", "sh -c 'for hw in /sys/class/hwmon/hwmon*/temp*_input; do label_file=\"${hw%_input}_label\"; if [ -f \"$label_file\" ]; then label=$(cat \"$label_file\"); case $label in *Package*|*CPU*|*Tctl*|*Tdie*|*Core*) cat $hw; exit;; esac; fi; done'"]

  stdout: SplitParser {
    onRead: data => {
      const v = parseInt(data.trim())
      root.tempStr = isNaN(v) ? "--" : Math.round(v / 1000) + "°C"
    }
  }
}

  // Disk
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

  // Net
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

  // Uptime
  Process {
    id: uptimeProc
    command: ["sh", "-c", "awk '{printf \"%d:%02d\", $1/3600, ($1%3600)/60}' /proc/uptime"]
    stdout: SplitParser {
      onRead: data => {
        root.uptimeStr = data.trim()
      }
    }
  }

  // notification
  readonly property var latestGroup: Notifications.groups.length > 0 ? Notifications.groups[0] : null
  readonly property bool hasNotif: root.latestGroup !== null
  readonly property string lastNotifSummary: root.latestGroup ? root.latestGroup.newest.summary : "No new notifications"
  readonly property string lastNotifBody: root.latestGroup ? root.latestGroup.newest.body : ""

  // pill
  Rectangle {
    id: pillBg
    height: 50
    width: 50
    radius: 14
    color: pillMouse.containsMouse || root.menuOpen ? Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.85) : Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.75)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    anchors.verticalCenter: parent.verticalCenter

    scale: pillMouse.containsMouse ? 1.04 : 1.0
    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
    Behavior on color { ColorAnimation { duration: 200 } }

    Text {
      anchors.centerIn: parent
      text: "⏻"
      font.pixelSize: 18
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
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 70
        anchors.rightMargin: 8
        width: 410
        radius: 10
        clip: true
        focus: true
        color: MatugenColors.bgBase
        border.color: MatugenColors.border
        border.width: 2

        opacity: powerPopup.animOpacity
        scale: 0.94 + 0.06 * powerPopup.animOpacity
        transform: Translate { y: (1 - powerPopup.animOpacity) * -10 }
        implicitHeight: mainColumn.implicitHeight + 32
        height: implicitHeight
        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Keys.onEscapePressed: root.menuOpen = false
        MouseArea { anchors.fill: parent }

        Column {
          id: mainColumn
          anchors.fill: parent
          anchors.margins: 16
          spacing: 14

          // action buttons
          Row {
            width: parent.width
            spacing: 8

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
                width: (mainColumn.width - 4 * 8) / 5
                height: 62
                radius: 12
                color: btnArea.containsMouse ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16) : Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.6)
                Behavior on color { ColorAnimation { duration: 150 } }

                Column {
                  anchors.centerIn: parent
                  spacing: 4

                  Text {
                    text: actionBtn.modelData.icon
                    font.pixelSize: 17
                    font.family: "JetBrainsMono Nerd Font"
                    color: btnArea.containsMouse ? MatugenColors.accent : MatugenColors.text
                    Behavior on color { ColorAnimation { duration: 150 } }
                    anchors.horizontalCenter: parent.horizontalCenter
                  }

                  Text {
                    text: actionBtn.modelData.label
                    font.pixelSize: 10
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

          Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
          }

          Grid {
            width: parent.width
            columns: 2
            rowSpacing: 8
            columnSpacing: 8

            Repeater {
              model: [
                { label: "CPU",  icon: "󰻠", value: root.cpuPct.toFixed(0) + "%",       pct: root.cpuPct },
                { label: "RAM",  icon: "󰍛", value: root.ramUsedStr,                    pct: root.ramPct },
                { label: "Temp", icon: "󰔏", value: root.tempStr,                       pct: -1 },
                { label: "Disk", icon: "󰋊", value: root.diskUsedStr,                   pct: root.diskPct }
              ]

              delegate: Rectangle {
                required property var modelData
                width: (mainColumn.width - 8) / 2
                height: 54
                radius: 10
                color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

                Row {
                  anchors.left: parent.left
                  anchors.leftMargin: 10
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 10

                  Text {
                    text: modelData.icon
                    font.pixelSize: 15
                    font.family: "JetBrainsMono Nerd Font"
                    color: MatugenColors.accent
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Column {
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                      text: modelData.label
                      font.pixelSize: 9
                      font.family: "JetBrainsMono Nerd Font"
                      color: MatugenColors.textMuted
                    }

                    Text {
                      text: modelData.value
                      font.pixelSize: 13
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
                  anchors.bottomMargin: 4
                  anchors.leftMargin: 10
                  anchors.rightMargin: 10
                  height: 3
                  radius: 2
                  color: Qt.rgba(1, 1, 1, 0.08)

                  Rectangle {
                    height: parent.height
                    radius: 2
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
            height: 40
            radius: 10
            color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

            Row {
              anchors.left: parent.left
              anchors.leftMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              spacing: 10

              Text {
                text: "󰈀"
                font.pixelSize: 14
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.accent
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: root.netStr
                font.pixelSize: 12
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.text
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
          }

          Row {
            spacing: 8

            Text {
              text: "󰥔"
              font.pixelSize: 13
              font.family: "JetBrainsMono Nerd Font"
              color: MatugenColors.textMuted
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: "Uptime: " + root.uptimeStr
              font.pixelSize: 11
              font.family: "JetBrainsMono Nerd Font"
              color: MatugenColors.textDim
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Rectangle {
            width: parent.width
            height: 48
            radius: 10
            color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

            Row {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              spacing: 10

              Text {
                text: root.hasNotif ? "󰂚" : "󰂛"
                font.pixelSize: 14
                font.family: "JetBrainsMono Nerd Font"
                color: root.hasNotif ? MatugenColors.accent : MatugenColors.textMuted
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                spacing: 1
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 30

                Text {
                  text: root.lastNotifSummary
                  font.pixelSize: 11
                  font.weight: Font.Medium
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.text
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  visible: root.lastNotifBody.length > 0
                  text: root.lastNotifBody
                  font.pixelSize: 10
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
