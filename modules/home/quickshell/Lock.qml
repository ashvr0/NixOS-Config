import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris

ShellRoot {
  id: root

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

  // wallpaper bg
  property string fallbackWallpaper: Quickshell.env("HOME") + "/.config/hypr/wallpapers/winter.png"
  property string wallpaperPath: ""

  property string profilePicturePath: Quickshell.env("HOME") + "/.config/hypr/profile.jpg"

  Process {
    id: wallpaperQuery
    command: ["awww", "query"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        var match = this.text.match(/image:\s*(\S+)/)
        root.wallpaperPath = (match && match[1]) ? match[1] : root.fallbackWallpaper
      }
    }
    onExited: function(exitCode) {
      if (root.wallpaperPath === "") root.wallpaperPath = root.fallbackWallpaper
    }
  }

  // MPRIS - active player
  readonly property var player: {
    var list = Mpris.players.values
    if (!list || list.length === 0) return null
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].isPlaying) return list[i]
    }
    return list[0]
  }

  WlSessionLock {
    id: lockRoot
    locked: true

    WlSessionLockSurface {
      id: lockSurface

      Image {
        id: bgImage
        anchors.fill: parent
        source: root.wallpaperPath !== "" ? "file://" + root.wallpaperPath : ""
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
        anchors.verticalCenterOffset: lockState.inputActive ? -130 : -30
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

        // --- MINI MUSIC PLAYER ---
        Rectangle {
          id: miniPlayer
          Layout.alignment: Qt.AlignHCenter
          Layout.topMargin: 24
          visible: root.player !== null
          width: 320
          height: 72
          radius: 20

          color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.7)
          border.width: 1
          border.color: Qt.rgba(1, 1, 1, 0.08)

          RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Rectangle {
              Layout.preferredWidth: 48
              Layout.preferredHeight: 48
              radius: 10
              color: MatugenColors.bgBase
              clip: true

              Image {
                anchors.fill: parent
                source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
              }

              Text {
                anchors.centerIn: parent
                text: "♪"
                font.pixelSize: 20
                color: MatugenColors.textMuted
                visible: !(root.player && root.player.trackArtUrl)
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              Text {
                Layout.fillWidth: true
                text: root.player && root.player.trackTitle ? root.player.trackTitle : "Nothing playing"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                font.weight: Font.Bold
                color: MatugenColors.text
                elide: Text.ElideRight
              }

              Text {
                Layout.fillWidth: true
                text: root.player && root.player.trackArtist ? root.player.trackArtist : ""
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: MatugenColors.textMuted
                elide: Text.ElideRight
              }
            }

            RowLayout {
              spacing: 4

              Rectangle {
                width: 32; height: 32; radius: 16
                color: prevMa.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                Text {
                  anchors.centerIn: parent
                  text: "⏮"
                  font.pixelSize: 14
                  color: MatugenColors.text
                }
                MouseArea {
                  id: prevMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: if (root.player) root.player.previous()
                }
              }

              Rectangle {
                width: 36; height: 36; radius: 18
                color: MatugenColors.accent
                Text {
                  anchors.centerIn: parent
                  text: root.player && root.player.isPlaying ? "⏸" : "▶"
                  font.pixelSize: 14
                  color: MatugenColors.accentText
                }
                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: if (root.player) root.player.togglePlaying()
                }
              }

              Rectangle {
                width: 32; height: 32; radius: 16
                color: nextMa.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                Text {
                  anchors.centerIn: parent
                  text: "⏭"
                  font.pixelSize: 14
                  color: MatugenColors.text
                }
                MouseArea {
                  id: nextMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: if (root.player) root.player.next()
                }
              }
            }
          }
        }
      }
      
      // Welcome back section
      ColumnLayout {
        id: authBlock
        anchors.centerIn: parent
        anchors.verticalCenterOffset: lockState.inputActive ? -10 : 90
        spacing: 18

        opacity: lockState.inputActive ? 1 : 0
        scale: lockState.inputActive ? 1.0 : 0.9
        visible: opacity > 0.01

        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 550; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        // profile picture
        Item {
          Layout.alignment: Qt.AlignHCenter
          width: 94
          height: 94

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

          Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: lockState.failed
                ? MatugenColors.error
                : (lockState.authenticating
                    ? MatugenColors.warning
                    : MatugenColors.accent)

            Behavior on border.color {
                ColorAnimation { duration: 250 }
            }
          }
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: "Welcome back, " + root.userName
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 22
          font.weight: Font.Bold
          color: MatugenColors.text
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: lockState.failed ? "Wrong password — try again" : (lockState.authenticating ? "Checking..." : "Enter your password")
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 13
          color: lockState.failed ? MatugenColors.error : MatugenColors.textMuted
          Behavior on color { ColorAnimation { duration: 200 } }
        }

        // This is the pin/password
        Rectangle {
          id: pinPill
          Layout.alignment: Qt.AlignHCenter
          width: 280; height: 54; radius: 27
          clip: true

          color: lockState.failed ? Qt.rgba(MatugenColors.error.r, MatugenColors.error.g, MatugenColors.error.b, 0.12) : Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.7)
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
            text: "Password"
            color: Qt.rgba(1, 1, 1, 0.3)
            font.pixelSize: 14
            font.family: "JetBrainsMono Nerd Font"
            visible: pinField.text.length === 0
          }

          TextInput {
            id: pinField
            anchors.fill: parent
            opacity: 0
            echoMode: TextInput.Password
            enabled: lockState.inputActive

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
        }
      }

      // --- POWER MENU (shutdown / restart / sleep only) ---
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

        color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.95)
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

      // Power button, bottom right
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
                : (powerBtnMa.containsMouse ? Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.8) : Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.4))
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
