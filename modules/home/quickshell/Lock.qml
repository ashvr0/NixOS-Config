import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

ShellRoot {
  id: root

  property string userName: "User"
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
        Behavior on scale { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }

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
            bigClock.text = Qt.formatDateTime(d, "hh:mm")
            bigDate.text = Qt.formatDateTime(d, "dddd, MMMM d")
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
        Behavior on scale { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }

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
    }
  }
}
