// One lock screen element. Used by the real lock screen (live: true) and by the
// editor (live: false, static preview of the password field).
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../Singletons"
import ".."
import "../weather"

Item {
  id: face

  property string kind: ""
  property string variant: ""
  property bool showText: true
  property bool live: false
  property var sessionState: null
  property var pamContext: null
  property string userName: Quickshell.env("USER") || "user"
  property string profilePicturePath: ""

  readonly property string fontName: "JetBrainsMono Nerd Font"
  readonly property var defSize: LockLayout.sizeFor(face.kind, face.variant)
  // Scale of the content relative to the element's default size
  readonly property real k: Math.max(0.35, Math.min(width / Math.max(1, defSize.w), height / Math.max(1, defSize.h)))

  readonly property bool failed: face.sessionState ? face.sessionState.failed : false
  readonly property bool authing: face.sessionState ? face.sessionState.authenticating : false
  readonly property bool blocked: face.sessionState ? face.sessionState.blocked : false
  readonly property int blockLeft: face.sessionState ? face.sessionState.blockLeft : 0
  readonly property string statusLabel: face.blocked ? "Blocked " + face.blockLeft + "s"
    : face.failed ? "Wrong pin"
    : face.authing ? "Authenticating"
    : "Enter PIN"

  function focusInput() {
    return loader.item && loader.item.focusInput ? loader.item.focusInput() : false
  }

  // ===== Media player =====
  readonly property var player: {
    var list = Mpris.players.values
    if (!list || list.length === 0) return null
    for (var i = 0; i < list.length; i++) if (list[i] && list[i].isPlaying) return list[i]
    return list[0]
  }
  readonly property string coverPath: {
    if (!player || !player.trackArtUrl) return ""
    var url = String(player.trackArtUrl).trim()
    if (url.length === 0) return ""
    if (url.indexOf("://") === -1) return "file://" + url
    return url
  }
  function normalizeSeconds(val) {
    if (!val || val <= 0) return 0
    if (val > 36000) return val / 1000000
    return val
  }
  function formatTime(sec) {
    var n = normalizeSeconds(sec)
    if (!n || n <= 0) return "0:00"
    var total = Math.floor(n)
    var s = total % 60
    return Math.floor(total / 60) + ":" + (s < 10 ? "0" : "") + s
  }

  SystemClock { id: clk; precision: SystemClock.Seconds }

  // ===== Small reusable pieces =====

  component Pill: Rectangle {
    id: pill
    property string icon: ""
    property string label: ""
    property color labelColor: MatugenColors.text
    property bool showLabel: true
    property string fontName: "JetBrainsMono Nerd Font"
    property bool live: false
    property bool clickable: false
    signal clicked()

    radius: height * 0.3
    color: MatugenColors.bgBase
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    clip: true

    Row {
      anchors.centerIn: parent
      spacing: pill.height * 0.2
      Text {
        visible: pill.icon !== ""
        text: pill.icon
        font.family: pill.fontName
        font.pixelSize: pill.height * 0.42
        color: MatugenColors.textMuted
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        visible: pill.showLabel && pill.label !== ""
        text: pill.label
        font.family: pill.fontName
        font.pixelSize: pill.height * 0.36
        font.weight: Font.Medium
        color: pill.labelColor
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: pill.clickable && pill.live
      cursorShape: Qt.PointingHandCursor
      onClicked: pill.clicked()
    }
  }

  // Stat tile whose fill rises from the bottom
  component StatTile: Rectangle {
    id: tile
    property string icon: ""
    property string label: ""
    property string valueText: ""
    property string subText: ""
    property real pct: -1
    property string fontName: "JetBrainsMono Nerd Font"
    property bool showText: true
    readonly property real m: Math.min(width, height)

    radius: Math.min(14, m * 0.14)
    color: MatugenColors.bgBase
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    clip: true

    Canvas {
      id: fillCanvas
      anchors.fill: parent
      renderTarget: Canvas.FramebufferObject
      renderStrategy: Canvas.Immediate

      property real animatedFill: Math.max(0, tile.pct) / 100
      Behavior on animatedFill { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
      onAnimatedFillChanged: requestPaint()
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()

      Connections {
        target: MatugenColors
        function onAccentChanged() { fillCanvas.requestPaint() }
      }

      onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        if (animatedFill <= 0) return
        var fillY = height * (1.0 - animatedFill)
        ctx.fillStyle = MatugenColors.accent.toString()
        ctx.fillRect(0, fillY, width, height - fillY)
      }
    }

    Text {
      anchors.left: parent.left; anchors.top: parent.top; anchors.margins: tile.height * 0.1
      text: tile.icon
      font.family: tile.fontName
      font.pixelSize: tile.m * 0.16
      color: MatugenColors.textMuted
    }
    Text {
      visible: tile.showText
      anchors.right: parent.right; anchors.top: parent.top; anchors.margins: tile.height * 0.1
      text: tile.label
      font.family: tile.fontName
      font.pixelSize: tile.m * 0.11
      color: MatugenColors.textMuted
    }
    Text {
      visible: tile.showText
      anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: tile.height * 0.1
      text: tile.subText
      font.family: tile.fontName
      font.pixelSize: tile.m * 0.11
      color: MatugenColors.textMuted
    }
    Text {
      anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: tile.height * 0.1
      text: tile.valueText
      font.family: tile.fontName
      font.pixelSize: tile.m * 0.22
      font.weight: Font.Bold
      color: MatugenColors.text
    }
  }

  // ===== Kind switch =====

  Loader {
    id: loader
    anchors.fill: parent
    visible: !(face.kind === "battery" && face.live && !SystemStats.hasBattery)
    sourceComponent: {
      switch (face.kind) {
        case "panel": return panelComp
        case "clock": return clockComp
        case "date": return dateComp
        case "avatar": return avatarComp
        case "user": return userComp
        case "status": return statusComp
        case "password": return passwordComp
        case "keyboard": return keyboardComp
        case "battery": return batteryComp
        case "notifications": return notifComp
        case "weather": return weatherComp
        case "music": return musicComp
        case "cpu": return cpuComp
        case "ram": return ramComp
        case "temp": return tempComp
        case "disk": return diskComp
        case "net": return netComp
      }
      return null
    }
  }

  // ----- card -----
  Component {
    id: panelComp
    Rectangle {
      radius: Math.min(width, height) * 0.045
      color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.84)
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, 0.10)
    }
  }

  // ----- clock / date -----
  Component {
    id: clockComp
    Item {
      readonly property string fmt: Config.clock24h ? "HH" : "h"
      Text {
        visible: face.variant !== "stacked"
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        fontSizeMode: Text.Fit
        minimumPixelSize: 8
        font.pixelSize: Math.max(10, parent.height * 0.9)
        font.family: face.fontName
        font.weight: Font.Bold
        color: MatugenColors.text
        text: face.variant === "seconds"
          ? Qt.formatDateTime(clk.date, Config.clock24h ? "HH:mm:ss" : "h:mm:ss AP")
          : Qt.formatDateTime(clk.date, Config.clock24h ? "HH:mm" : "h:mm AP")
      }
      Column {
        visible: face.variant === "stacked"
        anchors.fill: parent
        Text {
          width: parent.width; height: parent.height / 2
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          fontSizeMode: Text.Fit
          minimumPixelSize: 8
          font.pixelSize: Math.max(10, height * 0.95)
          font.family: face.fontName
          font.weight: Font.Bold
          color: MatugenColors.text
          text: Qt.formatDateTime(clk.date, Config.clock24h ? "HH" : "h")
        }
        Text {
          width: parent.width; height: parent.height / 2
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          fontSizeMode: Text.Fit
          minimumPixelSize: 8
          font.pixelSize: Math.max(10, height * 0.95)
          font.family: face.fontName
          font.weight: Font.Bold
          color: MatugenColors.accent
          text: Qt.formatDateTime(clk.date, "mm")
        }
      }
    }
  }

  Component {
    id: dateComp
    Text {
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      fontSizeMode: Text.Fit
      minimumPixelSize: 8
      font.pixelSize: Math.max(10, height * 0.8)
      font.family: face.fontName
      font.weight: Font.Medium
      color: MatugenColors.textMuted
      text: Qt.formatDateTime(clk.date, "dddd, MMMM d")
    }
  }

  // ----- avatar -----
  Component {
    id: avatarComp
    Item {
      id: av
      readonly property real d: Math.min(width, height)

      Item {
        anchors.centerIn: parent
        width: av.d; height: av.d

        Image {
          id: profileImg
          anchors.fill: parent
          source: face.profilePicturePath ? "file://" + face.profilePicturePath : ""
          fillMode: Image.PreserveAspectCrop
          smooth: true
          visible: false
          asynchronous: true
        }
        Rectangle {
          anchors.fill: parent
          radius: width / 2
          color: MatugenColors.bgBase
          visible: profileImg.status !== Image.Ready
          Text {
            anchors.centerIn: parent
            text: face.userName.length > 0 ? face.userName.charAt(0).toUpperCase() : "?"
            font.family: face.fontName
            font.pixelSize: av.d * 0.3
            font.weight: Font.Bold
            color: MatugenColors.textMuted
          }
        }
        MultiEffect {
          anchors.fill: parent
          source: profileImg
          maskEnabled: true
          maskSource: avMask
          visible: profileImg.status === Image.Ready
        }
        Item {
          id: avMask
          anchors.fill: parent
          layer.enabled: true
          visible: false
          Rectangle { anchors.fill: parent; radius: width / 2; color: "white" }
        }
        Rectangle {
          anchors.fill: parent
          radius: width / 2
          color: "transparent"
          border.width: 2
          border.color: Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.45)
        }
      }
    }
  }

  // ----- pills -----
  Component {
    id: userComp
    Pill { icon: "\uf007"; label: face.userName; showLabel: face.showText; live: face.live }
  }

  Component {
    id: statusComp
    Pill {
      icon: face.blocked ? "\uf023" : "\uf13e"
      label: face.statusLabel
      showLabel: face.showText
      live: face.live
      labelColor: face.failed || face.blocked ? MatugenColors.error : MatugenColors.text
    }
  }

  Component {
    id: keyboardComp
    Pill {
      icon: "\uf11c"
      label: Config.keyboardLayout ? Config.keyboardLayout.toUpperCase() : "EN"
      showLabel: face.showText
      live: face.live
      clickable: true
      onClicked: {
        if (Config.cycleKeyboardLayout) Config.cycleKeyboardLayout()
        else kbSwitchProc.running = true
      }
      Process { id: kbSwitchProc; command: ["bash", "-c", "hyprctl switchxkblayout all next"] }
    }
  }

  Component {
    id: batteryComp
    Pill {
      icon: SystemStats.batteryCharging ? "\uf0e7" : "\uf240"
      label: SystemStats.hasBattery ? Math.round(SystemStats.batteryPercent) + "%" : "100%"
      showLabel: face.showText
      live: face.live
    }
  }

  // ----- password -----
  Component {
    id: passwordComp
    Item {
      id: pw

      property bool showPassword: false
      readonly property bool minimal: face.variant === "minimal"
      readonly property bool canSubmit: pinField.text.length > 0 && !face.authing && !face.blocked && face.pamContext !== null
      readonly property real h: height

      function focusInput() { pinField.forceActiveFocus(); return true }

      function submit() {
        if (canSubmit && face.pamContext.responseRequired) {
          face.sessionState.authenticating = true
          face.sessionState.statusText = "Authenticating"
          face.sessionState.failed = false
          face.pamContext.respond(pinField.text)
          pinField.text = ""
          showPassword = false
        }
      }

      Rectangle {
        id: eyeBtn
        visible: !pw.minimal
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: pw.h * 0.9
        height: pw.h
        radius: pw.h * 0.26
        color: eyeMa.containsMouse ? MatugenColors.bgElevated2 : MatugenColors.bgBase
        border.width: 1
        border.color: pw.showPassword ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.08)
        Behavior on color { ColorAnimation { duration: 150 } }
        Text {
          anchors.centerIn: parent
          text: pw.showPassword ? "\uf070" : "\uf06e"
          font.family: face.fontName
          font.pixelSize: pw.h * 0.32
          color: pw.showPassword ? MatugenColors.accent : MatugenColors.textMuted
        }
        MouseArea {
          id: eyeMa
          anchors.fill: parent
          hoverEnabled: true
          enabled: face.live
          cursorShape: Qt.PointingHandCursor
          onClicked: { pw.showPassword = !pw.showPassword; pinField.forceActiveFocus() }
        }
      }

      Rectangle {
        id: pinPill
        anchors.left: pw.minimal ? parent.left : eyeBtn.right
        anchors.leftMargin: pw.minimal ? 0 : pw.h * 0.17
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: pw.h
        radius: pw.minimal ? 0 : pw.h * 0.26
        clip: true
        color: pw.minimal ? "transparent"
             : face.failed ? Qt.rgba(MatugenColors.error.r, MatugenColors.error.g, MatugenColors.error.b, 0.12)
             : MatugenColors.bgBase
        border.width: pw.minimal ? 0 : 1
        border.color: face.failed ? MatugenColors.error
                    : face.authing ? MatugenColors.warning
                    : pinField.text.length > 0 ? MatugenColors.accent
                    : Qt.rgba(1, 1, 1, 0.08)
        Behavior on color { ColorAnimation { duration: 200 } }
        transform: Translate { id: shakeT; x: 0 }

        SequentialAnimation {
          id: shakeAnim
          NumberAnimation { target: shakeT; property: "x"; from: 0; to: -10; duration: 90 }
          NumberAnimation { target: shakeT; property: "x"; from: -10; to: 10; duration: 90 }
          NumberAnimation { target: shakeT; property: "x"; from: 10; to: -6; duration: 90 }
          NumberAnimation { target: shakeT; property: "x"; from: -6; to: 0; duration: 90 }
        }
        Connections {
          target: face.sessionState
          ignoreUnknownSignals: true
          function onFailedChanged() {
            if (face.sessionState.failed) { shakeAnim.restart(); pinField.forceActiveFocus() }
          }
        }

        // underline for the minimal variant
        Rectangle {
          visible: pw.minimal
          anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
          height: 2
          color: face.failed ? MatugenColors.error : (pinField.text.length > 0 ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.25))
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: pw.h * 0.3
          anchors.verticalCenter: parent.verticalCenter
          text: "\uf023"
          font.family: face.fontName
          font.pixelSize: pw.h * 0.28
          color: MatugenColors.textMuted
        }

        Item {
          anchors.left: parent.left
          anchors.leftMargin: pw.h * 0.87
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.right: parent.right
          anchors.rightMargin: pw.h * 1.0
          clip: true

          Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: pw.h * 0.13
            visible: !pw.showPassword
            Repeater {
              model: pinField.text.length
              Rectangle {
                width: pw.h * 0.2; height: width; radius: width / 2
                color: face.failed ? MatugenColors.error : MatugenColors.text
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            visible: pw.showPassword && pinField.text.length > 0
            text: pinField.text
            elide: Text.ElideLeft
            font.family: face.fontName
            font.pixelSize: pw.h * 0.3
            color: face.failed ? MatugenColors.error : MatugenColors.text
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: face.blocked ? "Try again in " + face.blockLeft + "s" : "Password"
            color: face.blocked ? MatugenColors.error : Qt.rgba(1, 1, 1, 0.3)
            font.pixelSize: pw.h * 0.28
            font.family: face.fontName
            visible: pinField.text.length === 0
          }
        }

        TextInput {
          id: pinField
          anchors.fill: parent
          anchors.rightMargin: pw.h * 1.0
          opacity: 0
          echoMode: TextInput.Password
          enabled: face.live && face.sessionState !== null && face.sessionState.inputActive && !face.blocked
          selectByMouse: true
          activeFocusOnTab: true
          onTextChanged: if (face.sessionState) face.sessionState.failed = false
          Keys.onEscapePressed: {
            if (face.sessionState) face.sessionState.inputActive = false
            pw.showPassword = false
            text = ""
          }
          onAccepted: pw.submit()
        }

        MouseArea {
          anchors.left: parent.left
          anchors.right: enterBtn.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          enabled: face.live
          cursorShape: Qt.IBeamCursor
          onClicked: {
            if (face.sessionState) face.sessionState.inputActive = true
            pinField.forceActiveFocus()
          }
        }

        Rectangle {
          id: enterBtn
          anchors.right: parent.right
          anchors.rightMargin: pw.h * 0.1
          anchors.verticalCenter: parent.verticalCenter
          width: pw.h * 0.78
          height: width
          radius: pw.h * 0.2
          color: !pw.canSubmit ? Qt.rgba(1, 1, 1, 0.05)
               : (enterMa.containsMouse ? MatugenColors.accent
                  : Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.22))
          Behavior on color { ColorAnimation { duration: 150 } }
          Text {
            anchors.centerIn: parent
            text: "\uf061"
            font.family: face.fontName
            font.pixelSize: pw.h * 0.3
            color: !pw.canSubmit ? Qt.rgba(1, 1, 1, 0.22)
                 : (enterMa.containsMouse ? MatugenColors.accentText : MatugenColors.accent)
          }
          MouseArea {
            id: enterMa
            anchors.fill: parent
            enabled: pw.canSubmit
            hoverEnabled: true
            cursorShape: pw.canSubmit ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: pw.submit()
          }
        }
      }
    }
  }

  // ----- weather -----
  Component {
    id: weatherComp
    Rectangle {
      radius: 16 * face.k
      color: MatugenColors.bgBase
      border.color: Qt.rgba(1, 1, 1, 0.06)
      border.width: 1
      clip: true

      RowLayout {
        anchors.fill: parent
        anchors.margins: 14 * face.k
        spacing: 10 * face.k

        ColumnLayout {
          Layout.fillHeight: true
          Layout.preferredWidth: 1
          Layout.fillWidth: true
          spacing: 0

          Text {
            text: Weather.iconCode
            font.family: face.fontName
            font.pixelSize: 36 * face.k
            color: MatugenColors.accent
            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
          }
          Item { Layout.fillHeight: true }
          ColumnLayout {
            Layout.alignment: Qt.AlignBottom | Qt.AlignLeft
            spacing: 1
            Text {
              text: Weather.currentTemp + Weather.tempSuffix
              font.family: face.fontName
              font.pixelSize: 28 * face.k
              font.weight: Font.Black
              color: MatugenColors.text
            }
            Text {
              visible: face.variant !== "compact"
              text: "Feels Like " + Weather.feelsLike + Weather.tempSuffix
              font.family: face.fontName
              font.pixelSize: 11 * face.k
              color: MatugenColors.textMuted
            }
          }
        }

        ColumnLayout {
          visible: face.variant !== "compact"
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
              font.family: face.fontName
              font.pixelSize: 13 * face.k
              font.weight: Font.Bold
              color: MatugenColors.text
              horizontalAlignment: Text.AlignRight
              elide: Text.ElideRight
            }
            Text {
              Layout.fillWidth: true
              text: Weather.condition
              font.family: face.fontName
              font.pixelSize: 11 * face.k
              color: MatugenColors.textMuted
              horizontalAlignment: Text.AlignRight
              elide: Text.ElideRight
            }
          }
          Item { Layout.fillHeight: true }
          RowLayout {
            Layout.alignment: Qt.AlignBottom | Qt.AlignRight
            spacing: 8 * face.k
            Repeater {
              model: Weather.daily.slice(0, 4)
              ColumnLayout {
                spacing: 2
                Text {
                  Layout.alignment: Qt.AlignHCenter
                  text: modelData.hi + "\u00b0"
                  font.family: face.fontName
                  font.pixelSize: 11 * face.k
                  color: MatugenColors.textMuted
                }
                Text {
                  Layout.alignment: Qt.AlignHCenter
                  text: modelData.icon
                  font.family: face.fontName
                  font.pixelSize: 18 * face.k
                  color: MatugenColors.accent
                }
                Text {
                  Layout.alignment: Qt.AlignHCenter
                  text: modelData.label
                  font.family: face.fontName
                  font.pixelSize: 10 * face.k
                  color: MatugenColors.textMuted
                }
              }
            }
          }
        }
      }
    }
  }

  // ----- music -----
  Component {
    id: musicComp
    Rectangle {
      id: mus
      radius: 16 * face.k
      color: MatugenColors.bgBase
      border.color: Qt.rgba(1, 1, 1, 0.06)
      border.width: 1
      clip: true

      property real displayPosition: face.player ? face.player.position : 0
      readonly property bool cover: face.variant === "cover"

      Connections {
        target: face.player
        ignoreUnknownSignals: true
        function onPositionChanged() { if (face.player) mus.displayPosition = face.player.position }
      }
      Timer {
        interval: 500
        running: face.live && face.player && face.player.isPlaying
        repeat: true
        onTriggered: if (face.player) mus.displayPosition = Math.min(face.player.length, mus.displayPosition + 0.5)
      }

      RowLayout {
        anchors.fill: parent
        anchors.margins: 12 * face.k
        spacing: 10 * face.k

        Item {
          Layout.fillHeight: true
          Layout.preferredWidth: mus.cover ? mus.width - 24 * face.k : height
          Layout.maximumWidth: mus.cover ? 99999 : height

          Rectangle {
            anchors.fill: parent
            radius: 12 * face.k
            color: MatugenColors.bgElevated
            visible: coverImg.status !== Image.Ready
            Text {
              anchors.centerIn: parent
              text: "\u266a"
              font.pixelSize: parent.height * 0.38
              color: MatugenColors.textMuted
            }
          }
          Image {
            id: coverImg
            anchors.fill: parent
            source: face.coverPath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            mipmap: true
            visible: false
          }
          Rectangle {
            id: coverMask
            anchors.fill: parent
            radius: 12 * face.k
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
          MouseArea {
            anchors.fill: parent
            enabled: face.live && mus.cover && face.player !== null
            onClicked: face.player.togglePlaying()
          }
        }

        ColumnLayout {
          visible: !mus.cover
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          spacing: 2
          Text {
            Layout.fillWidth: true
            text: face.player && face.player.trackTitle ? face.player.trackTitle : "Nothing playing"
            font.family: face.fontName
            font.pixelSize: 13 * face.k
            font.weight: Font.Bold
            color: face.player ? MatugenColors.text : MatugenColors.textMuted
            elide: Text.ElideRight
          }
          Text {
            Layout.fillWidth: true
            text: face.player && face.player.trackArtist ? face.player.trackArtist : ""
            font.family: face.fontName
            font.pixelSize: 11 * face.k
            color: MatugenColors.textMuted
            elide: Text.ElideRight
          }
          Text {
            Layout.fillWidth: true
            text: face.player ? face.formatTime(mus.displayPosition) + " / " + face.formatTime(face.player.length) : "0:00 / 0:00"
            font.family: face.fontName
            font.pixelSize: 10 * face.k
            color: MatugenColors.textMuted
            opacity: face.player ? 1.0 : 0.5
          }
        }

        RowLayout {
          visible: !mus.cover
          Layout.alignment: Qt.AlignVCenter
          spacing: 9 * face.k
          opacity: face.player ? 1.0 : 0.4
          Text {
            text: "\u23ee"
            font.pixelSize: 15 * face.k
            color: MatugenColors.text
            MouseArea { anchors.fill: parent; anchors.margins: -4; enabled: face.live && face.player !== null; cursorShape: Qt.PointingHandCursor; onClicked: face.player.previous() }
          }
          Text {
            text: face.player && face.player.isPlaying ? "\u23f8" : "\u25b6"
            font.pixelSize: 19 * face.k
            color: MatugenColors.accent
            MouseArea { anchors.fill: parent; anchors.margins: -4; enabled: face.live && face.player !== null; cursorShape: Qt.PointingHandCursor; onClicked: face.player.togglePlaying() }
          }
          Text {
            text: "\u23ed"
            font.pixelSize: 15 * face.k
            color: MatugenColors.text
            MouseArea { anchors.fill: parent; anchors.margins: -4; enabled: face.live && face.player !== null; cursorShape: Qt.PointingHandCursor; onClicked: face.player.next() }
          }
        }
      }
    }
  }

  // ----- stat tiles -----
  Component {
    id: cpuComp
    StatTile { showText: face.showText; icon: "\uf2db"; label: "CPU"; valueText: Math.round(SystemStats.cpuPercent) + "%"; pct: SystemStats.cpuPercent }
  }
  Component {
    id: ramComp
    StatTile {
      showText: face.showText
      icon: "\uf538"; label: "RAM"
      valueText: (SystemStats.totalRamGb * SystemStats.ramPercent / 100).toFixed(1) + "G"
      pct: SystemStats.ramPercent
    }
  }
  Component {
    id: tempComp
    StatTile { showText: face.showText; icon: "\uf2c9"; label: "Temp"; valueText: Math.round(SystemStats.tempC) + "\u00b0"; pct: Math.max(0, Math.min(100, SystemStats.tempC)) }
  }
  Component {
    id: diskComp
    StatTile {
      showText: face.showText
      icon: "\uf0a0"
      label: SystemStats.diskTotalStr
      subText: SystemStats.diskUsedStr
      valueText: Math.round(SystemStats.diskPercent) + "%"
      pct: SystemStats.diskPercent
    }
  }
  Component {
    id: netComp
    StatTile {
      id: nt
      showText: face.showText
      icon: "\uf1eb"; label: "Net"; pct: -1
      Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: nt.height * 0.1
        spacing: 5
        Row {
          spacing: 6
          Text { text: "\uf019"; font.family: face.fontName; font.pixelSize: nt.m * 0.09; color: MatugenColors.accent }
          Text { text: SystemStats.netRxText; font.family: face.fontName; font.pixelSize: nt.m * 0.09; color: MatugenColors.text }
        }
        Row {
          spacing: 6
          Text { text: "\uf093"; font.family: face.fontName; font.pixelSize: nt.m * 0.09; color: MatugenColors.accent }
          Text { text: SystemStats.netTxText; font.family: face.fontName; font.pixelSize: nt.m * 0.09; color: MatugenColors.text }
        }
      }
    }
  }

  // ----- notifications -----
  Component {
    id: notifComp
    Rectangle {
      radius: 16 * face.k
      color: MatugenColors.bgBase
      border.color: Qt.rgba(1, 1, 1, 0.06)
      border.width: 1
      clip: true

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12 * face.k
        spacing: 8 * face.k

        RowLayout {
          Layout.fillWidth: true
          spacing: 6 * face.k
          Text {
            Layout.fillWidth: true
            text: "Notifications"
            font.family: face.fontName
            font.pixelSize: 13 * face.k
            font.weight: Font.Bold
            color: MatugenColors.text
          }
          Pill {
            Layout.preferredHeight: 28 * face.k
            Layout.preferredWidth: 70 * face.k
            icon: "\uf1f8"; label: "Clear"; clickable: true; live: face.live
            onClicked: Notifs.clearHistory()
          }
          Pill {
            Layout.preferredHeight: 28 * face.k
            Layout.preferredWidth: 82 * face.k
            icon: Notifs.silent ? "\uf1f6" : "\uf0f3"
            label: Notifs.silent ? "Unmute" : "Silent"
            clickable: true
            live: face.live
            onClicked: Notifs.silent = !Notifs.silent
          }
        }

        ListView {
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          spacing: 6 * face.k
          model: Notifs.history
          delegate: Rectangle {
            width: ListView.view.width
            height: notifCol.implicitHeight + 18 * face.k
            radius: 12 * face.k
            color: MatugenColors.bgElevated
            ColumnLayout {
              id: notifCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: 10 * face.k
              spacing: 2
              Text {
                Layout.fillWidth: true
                text: modelData.appName
                font.family: face.fontName
                font.pixelSize: 11 * face.k
                color: MatugenColors.accent
                elide: Text.ElideRight
              }
              Text {
                Layout.fillWidth: true
                text: modelData.summary
                font.family: face.fontName
                font.pixelSize: 12 * face.k
                font.weight: Font.Bold
                color: MatugenColors.text
                elide: Text.ElideRight
              }
              Text {
                Layout.fillWidth: true
                text: modelData.body
                font.family: face.fontName
                font.pixelSize: 11 * face.k
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
            font.family: face.fontName
            font.pixelSize: 11 * face.k
            color: MatugenColors.textMuted
          }
        }
      }
    }
  }
}
