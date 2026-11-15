import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../Singletons"
import ".."

ShellRoot {
  id: root

  property string userName: "User"
  property int failCount: 0

  function toUrl(p) {
    if (!p) return ""
    if (p.indexOf("file://") === 0) return p
    return "file://" + p.split("/").map(encodeURIComponent).join("/")
  }
readonly property string activeScreenName: (Quickshell.screens && Quickshell.screens.length > 0 && Quickshell.screens[0].name) ? Quickshell.screens[0].name : ""

FileView {
  id: wpStateWatcher
  printErrors: false
  path: root.activeScreenName !== ""
    ? (Quickshell.env("HOME") + "/.cache/wallpaper-picker/current_" + root.activeScreenName)
    : ""
  onLoaded: {
    let res = text().trim()
    if (res !== "") root.wallpaperPath = res
  }
}
  QtObject {
    id: lockState
    property bool inputActive: false
    property bool authenticating: false
    property bool failed: false
    property bool unlocking: false
    property string statusText: "Locked"
    property bool blocked: false
    property int blockLeft: 0
  }

  Timer {
    id: unlockTimer
    interval: 60
    onTriggered: {
      lockRoot.locked = false
      Qt.quit()
    }
  }

  Timer {
    id: blockTimer
    interval: 1000
    repeat: true
    onTriggered: {
      lockState.blockLeft--
      if (lockState.blockLeft <= 0) {
        blockTimer.stop()
        lockState.blocked = false
        lockState.failed = false
        lockState.statusText = "Locked"
        root.failCount = 0
      }
    }
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
        lockState.unlocking = true
        unlockTimer.start()
      } else {
        lockState.failed = true
        lockState.statusText = "Wrong password"
        root.failCount++
        if (LockLayout.attemptLimits && root.failCount >= LockLayout.maxAttempts) {
          lockState.blocked = true
          lockState.blockLeft = 30
          blockTimer.restart()
        }
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
  readonly property string bgPath: (LockLayout.bgMode === "custom" && LockLayout.customBgPath !== "")
    ? LockLayout.customBgPath : root.wallpaperPath

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


  WlSessionLock {
    id: lockRoot
    locked: true

    WlSessionLockSurface {
      id: lockSurface
      color: "black"

      Image {
        id: wallpaperImage
        anchors.fill: parent
        source: root.toUrl(root.bgPath)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: true
        onStatusChanged: {
          if (status === Image.Error) console.warn("Lock background failed to load: " + root.bgPath)
        }
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
        source: LockLayout.bgMode === "custom" ? wallpaperImage : bgImage
        anchors.fill: parent
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        visible: lockState.inputActive && LockLayout.blurOnInput
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
          if (controls.open) controls.open = false
          lockState.inputActive = true
          stage.focusInput()
        }
      }

      Item {
        anchors.fill: parent
        focus: !lockState.inputActive
        Keys.onPressed: (event) => {
          lockState.inputActive = true
          stage.focusInput()
        }
      }

      Item {
        id: stage
        anchors.fill: parent
        readonly property real u: width > 0 && height > 0
          ? Math.min(width / LockLayout.refW, height / LockLayout.refH) : 1

        // 1 = idle layer visible, 0 = login layer visible
        property real idleShow: lockState.inputActive ? 0 : 1
        Behavior on idleShow { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

        function focusNow() {
          for (let i = 0; i < rep.count; i++) {
            const it = rep.itemAt(i)
            if (it && it.focusInput()) return true
          }
          return false
        }

        function focusInput() {
          focusNow()
          // The login layer is still fading in on the first call, so try once more
          focusRetry.restart()
        }

        Timer { id: focusRetry; interval: 160; onTriggered: stage.focusNow() }

        Item {
          id: canvas
          width: LockLayout.refW
          height: LockLayout.refH
          anchors.centerIn: parent
          scale: stage.u

          Repeater {
            id: rep
            model: LockLayout.model

            delegate: Item {
              id: slot

              required property string uid
              required property string lyr
              required property string kind
              required property real ix
              required property real iy
              required property real iw
              required property real ih
              required property real iop
              required property string variant
              required property bool showText

              readonly property real layerVis: slot.lyr === "idle" ? stage.idleShow : 1 - stage.idleShow

              // Login layer size from settings. Items shrink toward the middle of the canvas,
              // so the whole card keeps its shape. The idle layer (clock, date) is untouched.
              readonly property real gs: slot.lyr === "login" ? LockLayout.loginScale : 1.0

              function focusInput() { return face.focusInput() }

              x: LockLayout.refW / 2 + (slot.ix + slot.iw / 2 - LockLayout.refW / 2) * slot.gs - slot.iw / 2
              y: LockLayout.refH / 2 + (slot.iy + slot.ih / 2 - LockLayout.refH / 2) * slot.gs - slot.ih / 2
              width: slot.iw
              height: slot.ih
              opacity: slot.iop * slot.layerVis
              visible: slot.layerVis > 0.01
              scale: (0.96 + 0.04 * slot.layerVis) * slot.gs

              LockElementFace {
                id: face
                anchors.fill: parent
                live: true
                kind: slot.kind
                variant: slot.variant
                showText: slot.showText
                sessionState: lockState
                pamContext: pam
                userName: root.userName
                profilePicturePath: root.profilePicturePath
              }
            }
          }
        }
      }

      // ===== Power menu =====
      Item {
        id: controls
        anchors.fill: parent
        property bool open: false
        readonly property real s: Math.max(0.85, Math.min(1.7, height / 1080))

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
        
        // popup 
        Rectangle {
          id: powerMenu
          anchors.bottom: powerBtn.top
          anchors.right: parent.right
          anchors.bottomMargin: 15 * controls.s
          anchors.rightMargin: 40 * controls.s
          width: 200 * controls.s
          height: controls.open ? (menuLayout.implicitHeight + 20 * controls.s) : 0
          radius: 18
          clip: true
          opacity: controls.open ? 1 : 0

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
              Layout.fillWidth: true; Layout.preferredHeight: 48 * controls.s
              Layout.leftMargin: 10; Layout.rightMargin: 10
              radius: 12
              color: maRestart.containsMouse ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.1) : "transparent"
              Behavior on color { ColorAnimation { duration: 200 } }

              RowLayout {
                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 10
                Text { text: "󰜉"; font.family: "Iosevka Nerd Font"; font.pixelSize: 18 * controls.s; color: MatugenColors.accent }
                Text { text: "Restart"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 * controls.s; font.weight: Font.Medium; color: MatugenColors.text }
              }
              MouseArea {
                id: maRestart; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { controls.open = false; rebootProcess.running = true }
              }
            }

            Rectangle {
              Layout.fillWidth: true; Layout.preferredHeight: 48 * controls.s
              Layout.leftMargin: 10; Layout.rightMargin: 10
              radius: 12
              color: maSleep.containsMouse ? Qt.rgba(MatugenColors.warning.r, MatugenColors.warning.g, MatugenColors.warning.b, 0.1) : "transparent"
              Behavior on color { ColorAnimation { duration: 200 } }

              RowLayout {
                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 10
                Text { text: "󰒲"; font.family: "Iosevka Nerd Font"; font.pixelSize: 18 * controls.s; color: MatugenColors.warning }
                Text { text: "Sleep"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 * controls.s; font.weight: Font.Medium; color: MatugenColors.text }
              }
              MouseArea {
                id: maSleep; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { controls.open = false; suspendProcess.running = true }
              }
            }

            Rectangle {
              Layout.fillWidth: true; Layout.preferredHeight: 48 * controls.s
              Layout.leftMargin: 10; Layout.rightMargin: 10; Layout.bottomMargin: 8
              radius: 12
              color: maShutdown.containsMouse ? Qt.rgba(MatugenColors.error.r, MatugenColors.error.g, MatugenColors.error.b, 0.1) : "transparent"
              Behavior on color { ColorAnimation { duration: 200 } }

              RowLayout {
                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 10
                Text { text: "󰐥"; font.family: "Iosevka Nerd Font"; font.pixelSize: 18 * controls.s; color: MatugenColors.error }
                Text { text: "Shut Down"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 * controls.s; font.weight: Font.Medium; color: MatugenColors.text }
              }
              MouseArea {
                id: maShutdown; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { controls.open = false; poweroffProcess.running = true }
              }
            }
          }
        }
        
        Rectangle {
          id: powerBtn
          anchors.bottom: parent.bottom
          anchors.right: parent.right
          anchors.margins: 32 * controls.s
          width: 32 * controls.s
          height: width
          radius: height / 2

          color: controls.open
                  ? MatugenColors.bgElevated2
                  : (powerBtnMa.containsMouse ? MatugenColors.bgElevated : MatugenColors.bgElevated)
          border.color: controls.open ? MatugenColors.text : Qt.rgba(1, 1, 1, 0.15)
          border.width: 1

          scale: powerBtnMa.pressed ? 0.9 : (powerBtnMa.containsMouse ? 1.08 : 1.0)

          Behavior on color { ColorAnimation { duration: 200 } }
          Behavior on border.color { ColorAnimation { duration: 200 } }
          Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

          Text {
            anchors.centerIn: parent
            text: "󰐥"
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 22 * controls.s
            color: controls.open ? MatugenColors.error : (powerBtnMa.containsMouse ? MatugenColors.text : MatugenColors.textMuted)
            Behavior on color { ColorAnimation { duration: 200 } }
          }

          MouseArea {
            id: powerBtnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              controls.open = !controls.open
              if (!controls.open) stage.focusInput()
            }
          }
        }
      }
    }
  }
}
