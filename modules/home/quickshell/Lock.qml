import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import Quickshell.Widgets
import "./Singletons"

ShellRoot {
  id: root

  Component.onCompleted: {
    if (Weather.locationName === "--" || !Weather.locationName) Weather.fetchWeather()
  }

  property string userName: "User"
  property bool powerMenuOpen: false

  QtObject {
    id: lockState
    property bool inputActive: false
    property bool authenticating: false
    property bool failed: false
    property string statusText: "Locked"
  }

  Timer {
    id: pamStartTimer
    interval: 50
    onTriggered: pam.start()
  }

  PamContext {
    id: pam
    Component.onCompleted: pamStartTimer.start()

    onCompleted: (result) => {
      lockState.authenticating = false
      if (result === PamResult.Success) {
        lockRoot.locked = false
        Qt.quit()
      } else {
        lockState.failed = true
        lockState.statusText = "Wrong password"
        pamStartTimer.start()
      }
    }
  }

  Process {
    id: userProc
    command: ["whoami"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: root.userName = this.text.trim() || "User"
    }
  }

  Process {
    id: suspendProcess
    command: ["systemctl", "suspend"]
  }

  Process {
    id: poweroffProcess
    command: ["systemctl", "poweroff"]
  }

  Process {
    id: rebootProcess
    command: ["systemctl", "reboot"]
  }

property string screenshotPath: Quickshell.env("HOME") + "/.cache/lock_screenshot.png"
property bool screenshotReady: false

Process {
  id: screenshotProc
  command: ["bash", "-c", "grim -l 0 '" + root.screenshotPath + "'"]
  running: true
  onExited: function(exitCode) {
    root.screenshotReady = (exitCode === 0)
  }
}

  property string fallbackProfilePicturePath: Quickshell.env("HOME") + "/.config/hypr/profile.jpg"
  property string profilePicturePath: root.fallbackProfilePicturePath
  property string wallpaperPath: ""

  Process {
    id: wallpaperQuery
    command: ["bash", "-c", "awww query | grep -oP 'image: \\K.*'"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        let p = this.text.trim()
        if (p) root.wallpaperPath = p
      }
    }
  }

  Process {
    id: profilePicSettingsRead
    command: ["cat", Quickshell.env("HOME") + "/.local/state/quickshell/settings.json"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          let data = JSON.parse(this.text)
          if (data.profilePicturePath) root.profilePicturePath = data.profilePicturePath
          if (data.wallpaperPath) root.wallpaperPath = data.wallpaperPath
        } catch (e) {}
      }
    }
  }


  readonly property var player: {
    var list = Mpris.players.values
    if (!list || list.length === 0) return null
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].isPlaying) return list[i]
    }
    return list[0]
  }

  function normalizeSeconds(val) {
    if (!val || val <= 0) return 0
    if (val > 36000) return val / 1000000
    return val
  }

  function formatTime(sec) {
    var normalized = normalizeSeconds(sec)
    if (!normalized || normalized <= 0) return "0:00"
    var total = Math.floor(normalized)
    var minutes = Math.floor(total / 60)
    var seconds = total % 60
    var ss = (seconds < 10 ? "0" : "") + seconds
    return minutes + ":" + ss
  }

  readonly property string coverPath: {
    if (!player || !player.trackArtUrl) return ""
    var url = String(player.trackArtUrl).trim()
    if (url.length === 0) return ""
    if (url.indexOf("://") === -1) return "file://" + url
    return url
  }

  // ===== System stats (from SystemStats singleton) =====
  readonly property real cpuPercent: SystemStats.cpuPercent
  readonly property real ramPercent: SystemStats.ramPercent
  readonly property real tempC: SystemStats.tempC
  readonly property real diskPercent: SystemStats.diskPercent
  readonly property string diskUsedText: SystemStats.diskUsedStr
  readonly property string diskTotalText: SystemStats.diskTotalStr
  readonly property real netRxBps: SystemStats.netRxBps
  readonly property real netTxBps: SystemStats.netTxBps
  readonly property string netRxText: SystemStats.netRxText
  readonly property string netTxText: SystemStats.netTxText

  WlSessionLock {
    id: lockRoot
    locked: true

    WlSessionLockSurface {
      id: lockSurface
      color: "black"

      Image {
        id: wallpaperImage
        anchors.fill: parent
        source: root.wallpaperPath ? "file://" + root.wallpaperPath : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: true
      }

      Image {
        id: bgImage
        anchors.fill: parent
        source: root.screenshotReady ? "file://" + root.screenshotPath : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: false
      }

      MultiEffect {
        source: bgImage
        anchors.fill: parent
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        visible: lockState.inputActive
      }

      Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: lockState.inputActive ? 0.45 : 0.25
        Behavior on opacity { NumberAnimation { duration: 400 } }
      }

      MouseArea {
        anchors.fill: parent
        onClicked: {
          if (root.powerMenuOpen) root.powerMenuOpen = false
          lockState.inputActive = true
          pinField.forceActiveFocus()
        }
      }

      Item {
        anchors.fill: parent
        focus: !lockState.inputActive
        Keys.onPressed: (event) => {
          lockState.inputActive = true
          pinField.forceActiveFocus()
        }
      }

      ColumnLayout {
        id: clockBlock
        anchors.centerIn: parent
        anchors.verticalCenterOffset: lockState.inputActive ? -130 : 0
        spacing: -6

        opacity: lockState.inputActive ? 0 : 1
        scale: lockState.inputActive ? 0.9 : 1.0
        visible: opacity > 0.01

        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 550; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        Text {
          id: bigClock
          Layout.alignment: Qt.AlignHCenter
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 130
          font.weight: Font.Bold
          color: MatugenColors.text
        }

        Text {
          id: bigDate
          Layout.alignment: Qt.AlignHCenter
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 20
          font.weight: Font.Medium
          color: MatugenColors.textMuted
        }

        Timer {
          interval: 1000; running: true; repeat: true; triggeredOnStart: true
          onTriggered: {
            const d = new Date()
            bigClock.text = Qt.formatDateTime(d, Config.clock24h ? "hh:mm" : "h:mm AP")
            bigDate.text = Qt.formatDateTime(d, "dddd, MMMM d")
          }
        }
      }

      // ===== Login popup box: left (weather/stats/music), middle (time/login/kb), right (notifs) =====
      Rectangle {
        id: authBox
        anchors.centerIn: parent
        width: 1220
        height: 540
        radius: 26
        clip: true

        opacity: lockState.inputActive ? 1 : 0
        scale: lockState.inputActive ? 1.0 : 0.92
        visible: opacity > 0.01

        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        color: MatugenColors.bgElevated
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)

        RowLayout {
          anchors.fill: parent
          anchors.margins: 8
          spacing: 20

          // ----- Left column: weather / sys stats / music -----
          ColumnLayout {
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            spacing: 0

            // Weather
            Item {
              Layout.fillWidth: true
              Layout.preferredHeight: 182

              Rectangle {
                anchors.fill: parent
                anchors.margins: 10
                radius: 16
                color: MatugenColors.bgBase

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: 14
                  spacing: 10

                  // Left: icon top, temp + feels-like bottom
                  ColumnLayout {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                      text: Weather.ownmIconToGlyph(Weather.iconCode)
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 40
                      color: MatugenColors.accent
                      Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                    }

                    Item { Layout.fillHeight: true }

                    ColumnLayout {
                      Layout.alignment: Qt.AlignBottom | Qt.AlignLeft
                      spacing: 1
                      Text {
                        text: Weather.currentTemp + Weather.tempSuffix
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 30
                        font.weight: Font.Black
                        color: MatugenColors.text
                      }
                      Text {
                        text: "Feels Like " + Weather.feelsLike + Weather.tempSuffix
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color: MatugenColors.textMuted
                      }
                    }
                  }

                  // Right: city/condition top, forecast row bottom
                  ColumnLayout {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1.3
                    Layout.fillWidth: true
                    spacing: 0

                    ColumnLayout {
                      Layout.alignment: Qt.AlignTop | Qt.AlignRight
                      Layout.fillWidth: true
                      spacing: 1
                      Text {
                        Layout.fillWidth: true
                        text: Weather.locationName
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: MatugenColors.text
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                      }
                      Text {
                        Layout.fillWidth: true
                        text: Weather.condition
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: MatugenColors.textMuted
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                      }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                      Layout.alignment: Qt.AlignBottom | Qt.AlignRight
                      spacing: 8
                      Repeater {
                        model: Weather.daily.slice(0, 4)
                        ColumnLayout {
                          spacing: 2
                          Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.hi + "°"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: MatugenColors.textMuted
                          }
                          Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Weather.ownmIconToGlyph(modelData.icon)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 18
                            color: MatugenColors.accent
                          }
                          Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.label
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 9
                            color: MatugenColors.textMuted
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            // System stats
            Item {
              Layout.fillWidth: true
              Layout.preferredHeight: 186

              GridLayout {
                anchors.fill: parent
                anchors.margins: 10
                columns: 2
                rows: 2
                columnSpacing: 8
                rowSpacing: 8

                component StatTile: Rectangle {
                  id: tile
                  property string icon: ""
                  property string label: ""
                  property string valueText: ""
                  property real pct: 0
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  radius: 12
                  color: MatugenColors.bgBase
                  clip: true

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 4
                      Text { text: tile.icon; font.pixelSize: 12; color: MatugenColors.accent }
                      Text {
                        Layout.fillWidth: true
                        text: tile.label
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color: MatugenColors.textMuted
                        elide: Text.ElideRight
                      }
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                      text: tile.valueText
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 15
                      font.weight: Font.Bold
                      color: MatugenColors.text
                    }

                    Rectangle {
                      Layout.fillWidth: true
                      Layout.preferredHeight: 4
                      radius: 2
                      color: Qt.rgba(1,1,1,0.08)
                      visible: tile.pct >= 0

                      Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, tile.pct / 100))
                        height: parent.height
                        radius: 2
                        color: MatugenColors.accent
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                      }
                    }
                  }
                }

                StatTile {
                  icon: "\uf2db"
                  label: "CPU"
                  valueText: Math.round(root.cpuPercent) + "%"
                  pct: root.cpuPercent
                }
                StatTile {
                  icon: "\uf538"
                  label: "RAM"
                  valueText: Math.round(root.ramPercent) + "%"
                  pct: root.ramPercent
                }
                StatTile {
                  icon: "\uf0a0"
                  label: "Disk"
                  valueText: Math.round(root.diskPercent) + "%"
                  pct: root.diskPercent
                }
                StatTile {
                  icon: "\uf6ff"
                  label: "Net"
                  valueText: root.netRxText
                  pct: -1
                }
              }

              Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.08) }
            }

            // Music
Item {
  Layout.fillWidth: true
  Layout.fillHeight: true

  Rectangle {
    anchors.fill: parent
    anchors.margins: 10
    radius: 16
    color: MatugenColors.bgBase
  }

  id: miniPop

  property real displayPosition: root.player ? root.player.position : 0
  property bool dragging: false
  property real dragPct: 0
  readonly property real shownPct: dragging
    ? dragPct
    : (root.player && root.player.length > 0
        ? root.normalizeSeconds(displayPosition) / root.normalizeSeconds(root.player.length) * 100
        : 0)

  Connections {
    target: root.player
    function onPositionChanged() {
      if (root.player) miniPop.displayPosition = root.player.position
    }
  }
  Timer {
    interval: 500
    running: root.player && root.player.isPlaying && !miniPop.dragging
    repeat: true
    onTriggered: {
      if (root.player) miniPop.displayPosition = Math.min(root.player.length, miniPop.displayPosition + 0.5)
    }
  }

  ColumnLayout {
    anchors.centerIn: parent
    width: parent.width - 32
    spacing: 6

    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      Item {
        id: musicArt
        Layout.preferredWidth: 44
        Layout.preferredHeight: 44

        Rectangle {
          anchors.fill: parent
          radius: 10
          color: MatugenColors.bgBase
          visible: coverImg.status !== Image.Ready
          Text {
            anchors.centerIn: parent
            text: "♪"
            font.pixelSize: 18
            color: MatugenColors.textMuted
          }
        }

        Image {
          id: coverImg
          anchors.fill: parent
          source: root.coverPath
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          mipmap: true
          visible: false
        }

        Rectangle {
          id: coverMask
          width: 44; height: 44
          radius: 10
          color: "white"
          visible: false
          layer.enabled: true
        }

        MultiEffect {
          anchors.fill: parent
          source: coverImg
          maskEnabled: true
          maskSource: coverMask
          visible: coverImg.status === Image.Ready
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Text {
          Layout.fillWidth: true
          text: root.player && root.player.trackTitle ? root.player.trackTitle : "Nothing playing"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 13
          font.weight: Font.Bold
          color: root.player ? MatugenColors.text : MatugenColors.textMuted
          elide: Text.ElideRight
        }
        Text {
          Layout.fillWidth: true
          text: root.player && root.player.trackArtist ? root.player.trackArtist : ""
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 11
          color: MatugenColors.textMuted
          elide: Text.ElideRight
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: 4
      spacing: 6
      opacity: root.player ? 1.0 : 0.4

      Text {
        text: root.formatTime(miniPop.displayPosition)
        color: MatugenColors.textMuted
        font.pixelSize: 9
        font.family: "JetBrainsMono Nerd Font"
      }

      Item {
        Layout.fillWidth: true
        height: 14

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width; height: 4; radius: 2
          color: MatugenColors.bgBase

          Rectangle {
            width: parent.width * (miniPop.shownPct / 100)
            height: parent.height; radius: 2
            color: MatugenColors.accent
            Behavior on width {
              enabled: !miniPop.dragging
              NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }
          }
        }

        Rectangle {
          width: 9; height: 9; radius: 5
          color: MatugenColors.text
          anchors.verticalCenter: parent.verticalCenter
          x: Math.max(0, Math.min(parent.width - width, parent.width * (miniPop.shownPct / 100) - width / 2))
          visible: root.player && (seekArea.containsMouse || miniPop.dragging)
        }

        MouseArea {
          id: seekArea
          anchors.fill: parent
          hoverEnabled: true
          enabled: root.player !== null
          cursorShape: root.player ? Qt.PointingHandCursor : Qt.ArrowCursor
          preventStealing: true

          function pctFromX(mx) { return Math.max(0, Math.min(100, (mx / width) * 100)) }

          onPressed: (mouse) => {
            if (!root.player || root.player.length <= 0) return
            miniPop.dragging = true
            miniPop.dragPct = pctFromX(mouse.x)
          }
          onPositionChanged: (mouse) => {
            if (miniPop.dragging) miniPop.dragPct = pctFromX(mouse.x)
          }
          onReleased: (mouse) => {
            if (!miniPop.dragging) return
            var pct = pctFromX(mouse.x)
            if (root.player && root.player.length > 0) {
              var targetSeconds = (pct / 100) * root.normalizeSeconds(root.player.length)
              var currentSeconds = root.normalizeSeconds(miniPop.displayPosition)
              root.player.seek(targetSeconds - currentSeconds)
            }
            miniPop.dragging = false
          }
        }
      }

      Text {
        text: root.player ? root.formatTime(root.player.length) : "0:00"
        color: MatugenColors.textMuted
        font.pixelSize: 9
        font.family: "JetBrainsMono Nerd Font"
      }
    }

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: 4
      spacing: 14
      opacity: root.player ? 1.0 : 0.4

      Text {
        text: "⏮"
        font.pixelSize: 14
        color: MatugenColors.text
        MouseArea { anchors.fill: parent; enabled: root.player !== null; cursorShape: root.player ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: if (root.player) root.player.previous() }
      }
      Text {
        text: root.player && root.player.isPlaying ? "⏸" : "▶"
        font.pixelSize: 15
        color: MatugenColors.accent
        MouseArea { anchors.fill: parent; enabled: root.player !== null; cursorShape: root.player ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: if (root.player) root.player.togglePlaying() }
      }
      Text {
        text: "⏭"
        font.pixelSize: 14
        color: MatugenColors.text
        MouseArea { anchors.fill: parent; enabled: root.player !== null; cursorShape: root.player ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: if (root.player) root.player.next() }
      }
    }
  }
}
          }

          Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Qt.rgba(1,1,1,0.08) }

          // ----- Middle column: login -----
          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 34
            Layout.bottomMargin: 30
            spacing: 16

            Item { 
              Layout.preferredHeight: 8 
            }

            Item {
              Layout.alignment: Qt.AlignHCenter
              width: 160
              height: 160
              
              Image {
                id: profileImg
                anchors.fill: parent
                source: "file://" + root.profilePicturePath
                fillMode: Image.PreserveAspectCrop
                smooth: true
                visible: false
                asynchronous: true
              }

              Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: MatugenColors.bgElevated
                visible: profileImg.status !== Image.Ready

                Text {
                  anchors.centerIn: parent
                  text: root.userName.length > 0 ? root.userName.charAt(0).toUpperCase() : "?"
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 36
                  font.weight: Font.Bold
                  color: MatugenColors.textMuted
                }
              }

              MultiEffect {
                anchors.fill: profileImg
                source: profileImg
                maskEnabled: true
                maskSource: profileMask
                visible: profileImg.status === Image.Ready
              }

              Item {
                id: profileMask
                width: profileImg.width
                height: profileImg.height
                layer.enabled: true
                visible: false

                Rectangle {
                  anchors.fill: parent
                  radius: width / 2
                  color: "white"
                }
              }

            }

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: root.userName
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 20
              font.weight: Font.Bold
              color: MatugenColors.text
            }

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: lockState.failed ? "Wrong pin — try again" : (lockState.authenticating ? "Authenticating ..." : "Enter your pin")
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 13
              color: lockState.failed ? MatugenColors.error : MatugenColors.textMuted
              Behavior on color { ColorAnimation { duration: 200 } }
            }

            Rectangle {
              id: pinPill
              Layout.alignment: Qt.AlignHCenter
              width: 280; height: 54; radius: 4
              clip: true

              color: lockState.failed ? Qt.rgba(MatugenColors.error.r, MatugenColors.error.g, MatugenColors.error.b, 0.12) : MatugenColors.bgElevated
              border.width: 2
              border.color: lockState.failed ? MatugenColors.error
                          : lockState.authenticating ? MatugenColors.warning
                          : pinField.text.length > 0 ? MatugenColors.accent
                          : Qt.rgba(1, 1, 1, 0.08)

              Behavior on color { ColorAnimation { duration: 200 } }
              Behavior on border.color { ColorAnimation { duration: 200 } }

              transform: Translate { id: shakeT; x: 0 }
              SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: shakeT; property: "x"; from: 0; to: -10; duration: 90 }
                NumberAnimation { target: shakeT; property: "x"; from: -10; to: 10; duration: 90 }
                NumberAnimation { target: shakeT; property: "x"; from: 10; to: -6; duration: 90 }
                NumberAnimation { target: shakeT; property: "x"; from: -6; to: 0; duration: 90 }
              }
              Connections {
                target: lockState
                function onFailedChanged() { if (lockState.failed) shakeAnim.restart() }
              }

              Row {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -18
                spacing: 10
                Repeater {
                  model: pinField.text.length
                  Rectangle {
                    width: 10; height: 10; radius: 5
                    color: lockState.failed ? MatugenColors.error : MatugenColors.text
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }

              Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -18
                text: "Password"
                color: Qt.rgba(1, 1, 1, 0.3)
                font.pixelSize: 14
                font.family: "JetBrainsMono Nerd Font"
                visible: pinField.text.length === 0
              }

              TextInput {
                id: pinField
                anchors.fill: parent
                anchors.rightMargin: 44
                opacity: 0
                echoMode: TextInput.Password
                enabled: lockState.inputActive
                selectByMouse: true
                activeFocusOnTab: true

                onTextChanged: lockState.failed = false

                Keys.onEscapePressed: {
                  lockState.inputActive = false
                  text = ""
                }

                onAccepted: {
                  if (text.length > 0 && pam.responseRequired && !lockState.authenticating) {
                    lockState.authenticating = true
                    lockState.statusText = "Authenticating"
                    lockState.failed = false
                    pam.respond(text)
                    text = ""
                  }
                }
              }

              MouseArea {
                anchors.left: parent.left
                anchors.right: enterBtn.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                cursorShape: Qt.IBeamCursor
                onClicked: (mouse) => {
                  lockState.inputActive = true
                  pinField.forceActiveFocus()
                  var pos = pinField.positionAt(mouse.x, mouse.y)
                  pinField.cursorPosition = pos
                }
              }

              Rectangle {
                id: enterBtn
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 44
                color: enterBtnMa.containsMouse
                        ? MatugenColors.accent
                        : Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.18)

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                  anchors.centerIn: parent
                  text: "󰌑"
                  font.family: "Iosevka Nerd Font"
                  font.pixelSize: 18
                  color: enterBtnMa.containsMouse ? MatugenColors.accentText : MatugenColors.accent
                }

                MouseArea {
                  id: enterBtnMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (pinField.text.length > 0 && pam.responseRequired && !lockState.authenticating) {
                      lockState.authenticating = true
                      lockState.statusText = "Authenticating"
                      lockState.failed = false
                      pam.respond(pinField.text)
                      pinField.text = ""
                    }
                  }
                }
              }
            }

            // Keyboard layout indicator
            Rectangle {
              Layout.alignment: Qt.AlignHCenter
              width: kbText.implicitWidth + 18
              height: 26
              radius: 7
              color: kbLayoutMa.containsMouse ? MatugenColors.bgElevated2 : MatugenColors.bgBase
              Behavior on color { ColorAnimation { duration: 150 } }

              Text {
                id: kbText
                anchors.centerIn: parent
                text: Config.keyboardLayout ? Config.keyboardLayout.toUpperCase() : "󰌌 EN"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                font.weight: Font.Medium
                color: MatugenColors.text
              }

              MouseArea {
                id: kbLayoutMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (Config.cycleKeyboardLayout) {
                    Config.cycleKeyboardLayout()
                  } else {
                    kbSwitchProc.running = true
                  }
                }
              }
            }

            Process {
              id: kbSwitchProc
              command: ["bash", "-c", "hyprctl switchxkblayout all next"]
            }

            Item { Layout.fillHeight: true }
          }

          Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Qt.rgba(1,1,1,0.08) }

          // ----- Right column: notifications -----
          Item {
            Layout.preferredWidth: 380
            Layout.fillHeight: true

            Rectangle {
              anchors.fill: parent
              anchors.margins: 10
              radius: 16
              color: MatugenColors.bgBase
            }

            ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 0

            RowLayout {
              Layout.fillWidth: true
              Layout.topMargin: 10
              Layout.leftMargin: 6
              Layout.rightMargin: 4
              spacing: 6
              
              Text {
                Layout.fillWidth: true
                text: "Notifications"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                font.weight: Font.Bold
                color: MatugenColors.text
              }

              Rectangle {
                width: muteText.implicitWidth + 18; height: 26; radius: 7
                color: Notifs.silent ? MatugenColors.accent : MatugenColors.bgBase
                Text {
                  id: muteText
                  anchors.centerIn: parent
                  text: Notifs.silent ? "Unmute" : "Mute"
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 10
                  font.weight: Font.Medium
                  color: Notifs.silent ? MatugenColors.accentText : MatugenColors.text
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: Notifs.silent = !Notifs.silent
                }
              }

              Rectangle {
                width: clearText.implicitWidth + 18; height: 26; radius: 7
                color: MatugenColors.bgBase
                Text {
                  id: clearText
                  anchors.centerIn: parent
                  text: "Clear"
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 10
                  font.weight: Font.Medium
                  color: MatugenColors.text
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: Notifs.clearHistory()
                }
              }
            }

            ListView {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.margins: 14
              clip: true
              spacing: 8
              model: Notifs.history

              delegate: Rectangle {
                width: ListView.view.width
                height: notifCol.implicitHeight + 20
                radius: 14
                color: MatugenColors.bgBase

                ColumnLayout {
                  id: notifCol
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.margins: 10
                  spacing: 2

                  Text {
                    Layout.fillWidth: true
                    text: modelData.appName
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: MatugenColors.accent
                    elide: Text.ElideRight
                  }
                  Text {
                    Layout.fillWidth: true
                    text: modelData.summary
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: MatugenColors.text
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                  }
                  Text {
                    Layout.fillWidth: true
                    text: modelData.body
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: MatugenColors.textMuted
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                  }
                }
              }

              Text {
                anchors.centerIn: parent
                visible: Notifs.history.length === 0
                text: "No notifications"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: MatugenColors.textMuted
              }
            }
            }
          }
        }
      }

      Rectangle {
        id: powerMenu
        anchors.bottom: powerBtn.top
        anchors.right: parent.right
        anchors.bottomMargin: 15
        anchors.rightMargin: 40
        width: 220
        height: root.powerMenuOpen ? (menuLayout.implicitHeight + 20) : 0
        radius: 18
        clip: true
        opacity: root.powerMenuOpen ? 1 : 0

        color: MatugenColors.bgElevated
        border.color: Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.25)
        border.width: 1

        Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 250 } }

        ColumnLayout {
          id: menuLayout
          anchors.top: parent.top
          anchors.topMargin: 10
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: 6

          Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 48
            Layout.leftMargin: 10; Layout.rightMargin: 10
            radius: 12
            color: maRestart.containsMouse ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.1) : "transparent"
            Behavior on color { ColorAnimation { duration: 200 } }

            RowLayout {
              anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 10
              Text { text: "󰜉"; font.family: "Iosevka Nerd Font"; font.pixelSize: 18; color: MatugenColors.accent }
              Text { text: "Restart"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; font.weight: Font.Medium; color: MatugenColors.text }
            }
            MouseArea {
              id: maRestart; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: { root.powerMenuOpen = false; rebootProcess.running = true }
            }
          }

          Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 48
            Layout.leftMargin: 10; Layout.rightMargin: 10
            radius: 12
            color: maSleep.containsMouse ? Qt.rgba(MatugenColors.warning.r, MatugenColors.warning.g, MatugenColors.warning.b, 0.1) : "transparent"
            Behavior on color { ColorAnimation { duration: 200 } }

            RowLayout {
              anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 10
              Text { text: "󰒲"; font.family: "Iosevka Nerd Font"; font.pixelSize: 18; color: MatugenColors.warning }
              Text { text: "Sleep"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; font.weight: Font.Medium; color: MatugenColors.text }
            }
            MouseArea {
              id: maSleep; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: { root.powerMenuOpen = false; suspendProcess.running = true }
            }
          }

          Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 48
            Layout.leftMargin: 10; Layout.rightMargin: 10; Layout.bottomMargin: 8
            radius: 12
            color: maShutdown.containsMouse ? Qt.rgba(MatugenColors.error.r, MatugenColors.error.g, MatugenColors.error.b, 0.1) : "transparent"
            Behavior on color { ColorAnimation { duration: 200 } }

            RowLayout {
              anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 10
              Text { text: "󰐥"; font.family: "Iosevka Nerd Font"; font.pixelSize: 18; color: MatugenColors.error }
              Text { text: "Shut Down"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; font.weight: Font.Medium; color: MatugenColors.text }
            }
            MouseArea {
              id: maShutdown; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: { root.powerMenuOpen = false; poweroffProcess.running = true }
            }
          }
        }
      }
      Rectangle {
        id: powerBtn
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 40
        width: 52
        height: width
        radius: height / 2

        color: root.powerMenuOpen
                ? MatugenColors.bgElevated2
                : (powerBtnMa.containsMouse ? MatugenColors.bgElevated : MatugenColors.bgElevated)
        border.color: root.powerMenuOpen ? MatugenColors.text : Qt.rgba(1, 1, 1, 0.15)
        border.width: 1

        scale: powerBtnMa.pressed ? 0.9 : (powerBtnMa.containsMouse ? 1.08 : 1.0)

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        Text {
          anchors.centerIn: parent
          text: "󰐥"
          font.family: "Iosevka Nerd Font"
          font.pixelSize: 22
          color: root.powerMenuOpen ? MatugenColors.error : (powerBtnMa.containsMouse ? MatugenColors.text : MatugenColors.textMuted)
          Behavior on color { ColorAnimation { duration: 200 } }
        }

        MouseArea {
          id: powerBtnMa
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.powerMenuOpen = !root.powerMenuOpen
            if (!root.powerMenuOpen) pinField.forceActiveFocus()
          }
        }
      }
    }
  }
}
