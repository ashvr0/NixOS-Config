import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "Scaler.js" as LayoutMath

Item {
  id: root
  implicitWidth: pillBg.width
  implicitHeight: pillBg.height
    Scaler {
        id: scaler
        currentWidth: Screen.width
        currentHeight: Screen.height
    }

    function s(val) {
        return scaler.s(val)
    }

    // Card geometry for the popup, driven by the registry so it stays in
    // sync with the "music" entry rather than a locally hardcoded size.
    readonly property var musicLayout: LayoutMath.getLayout(
        "music", 0, 0, Screen.width, Screen.height, Config.uiScale
    )
  IpcHandler {
    target: "music"
    function toggle(): void {
        root.playerExpanded = !root.playerExpanded
        }
      }

      readonly property var player: {
        var list = Mpris.players.values
        if (!list || list.length === 0)
        return null

        for (var i = 0; i < list.length; i++) {
          if (list[i] && list[i].isPlaying)
          return list[i]
        }
        return list[0]
      }

      // Normalizes position/length values that some MPRIS backends report
      // in microseconds instead of seconds. If a value is implausibly
      // large for a media duration/position, treat it as microseconds.
      function normalizeSeconds(val) {
        if (!val || val <= 0) return 0
        // Anything over ~10 hours in "seconds" is almost certainly
        // actually microseconds from a backend that didn't convert.
        if (val > 36000) return val / 1000000
        return val
      }

      function formatTime(sec) {
        var normalized = normalizeSeconds(sec)
        if (!normalized || normalized <= 0)
        return "0:00"

        var total = Math.floor(normalized)
        var hours = Math.floor(total / 3600)
        var minutes = Math.floor((total % 3600) / 60)
        var seconds = total % 60
        var mm = (hours > 0 && minutes < 10) ? "0" + minutes : String(minutes)
        var ss = (seconds < 10 ? "0" : "") + seconds

        return hours > 0 ? (hours + ":" + mm + ":" + ss) : (minutes + ":" + ss)
    }

readonly property string artist: player && player.trackArtist ? player.trackArtist : ""
readonly property string album: player && player.trackAlbum ? player.trackAlbum : ""
readonly property string title: player && player.trackTitle ? player.trackTitle : ""

// Normalizes trackArtUrl so bare filesystem paths (some MPRIS bridges,
// including browser/mpv based YouTube playback, omit the file:// scheme)
// still resolve in Image. Falls back to empty so the placeholder note
// icon shows instead of a broken image.
readonly property string coverPath: {
    if (!player || !player.trackArtUrl) return ""
    var url = String(player.trackArtUrl).trim()
    if (url.length === 0) return ""
    if (url.indexOf("://") === -1) return "file://" + url
    return url
}

readonly property string positionStr: formatTime(progressTrack.displayPosition)
readonly property string lengthStr: formatTime(player ? player.length : 0)
readonly property bool isPlaying: player && player.isPlaying
readonly property string status: player
    ? (player.isPlaying ? "Playing" : "Paused")
    : "Stopped"

  property bool entered: false
  property int cascadeIndex: 1
  property bool playerExpanded: false
  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }

  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutBack } } }
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

  // Pill 
  Rectangle {
    id: pillBg
    height: s(50)
    width: barRow.implicitWidth + s(24)
    radius: s(14)
    color: pillHover.containsMouse || root.playerExpanded
      ? Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.85)
      : Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.75)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    anchors.verticalCenter: parent.verticalCenter

    scale: pillHover.containsMouse ? 1.03 : 1.0
    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
    Behavior on color { ColorAnimation { duration: 200 } }
    Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

    MouseArea {
      id: pillHover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.playerExpanded = !root.playerExpanded
    }

    Row {
      id: barRow
      anchors.centerIn: parent
      spacing: s(8)
      height: s(32)

      Rectangle {
        width: s(32); height: s(32); radius: s(8)
        color: MatugenColors.bgElevated
        border.color: MatugenColors.borderSoft; border.width: 1
        anchors.verticalCenter: parent.verticalCenter

        Image {
          id: miniCoverImg
          anchors.fill: parent
          source: coverPath
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          mipmap: true
          visible: false
        }

        Rectangle {
          id: miniCoverMask
          anchors.fill: parent
          radius: s(8)
          visible: false
          layer.enabled: true
        }

        MultiEffect {
          source: miniCoverImg
          anchors.fill: parent
          maskEnabled: true
          maskSource: miniCoverMask
          visible: coverPath !== "" && miniCoverImg.status === Image.Ready
        }

        Text {
          anchors.centerIn: parent; text: "♪"
          font.pixelSize: s(16); color: MatugenColors.borderSoft
          visible: coverPath === "" || miniCoverImg.status !== Image.Ready
        }
      }

      Column {
        spacing: 1
        anchors.verticalCenter: parent.verticalCenter
        width: s(190)

        Text {
          text: player ? player.trackTitle : "Not Playing"
          color: MatugenColors.text; font.pixelSize: s(12); font.weight: Font.Bold
          elide: Text.ElideRight; width: parent.width
        }

        Text {
          text: root.artist
          color: MatugenColors.textMuted; font.pixelSize: s(10)
          elide: Text.ElideRight; width: parent.width
        }
      }

      Row {
        spacing: s(6)
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
          model: ["⏮", root.isPlaying ? "⏸" : "▶", "⏭"]

          Rectangle {
            width: s(22); height: s(22)
            radius: index === 1 ? s(11) : s(6)
            property bool isHovered: miniMouse.containsMouse
            color: index === 1 && root.isPlaying ? MatugenColors.accent : (isHovered ? MatugenColors.bgElevated : "transparent")
            scale: isHovered ? 1.15 : 1.0
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
              anchors.centerIn: parent; text: modelData; font.pixelSize: s(10)
              color: index === 1 && root.isPlaying ? MatugenColors.accentText : MatugenColors.text
            }

            MouseArea {
              id: miniMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (index === 0 && player) player.previous()
                else if (index === 1 && player) player.togglePlaying()
                else if (index === 2 && player) player.next()
              }
            }
          }
        }
      }
    }
  }

  // Popup Menu
  PanelWindow {
    id: popup
    visible: root.playerExpanded || animOpacity > 0.01
    implicitWidth: s(640)
    implicitHeight: s(285)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qs-music-popup"

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"

    property real animOpacity: root.playerExpanded ? 1.0 : 0.0
    Behavior on animOpacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    MouseArea {
      anchors.fill: parent
      onClicked: root.playerExpanded = false
    }

    FocusScope {
      anchors.fill: parent
      focus: root.playerExpanded
      Keys.onEscapePressed: root.playerExpanded = false

      Rectangle {
        width: root.musicLayout ? root.musicLayout.w : s(640)
        height: root.musicLayout ? root.musicLayout.h : s(285)
        x: {
          // Center the popup under the pill's real position on screen,
          // clamped so it never runs off either edge. The pill can be
          // anywhere along the bar (it's horizontally centered by
          // default, and the bar itself may be rotated for left/right
          // placement), so anchoring to a screen edge like the other
          // popups do would put this one in the wrong place.
          var pillGlobal = pillBg.mapToItem(null, pillBg.width / 2, 0)
          var desiredX = pillGlobal.x - width / 2
          return Math.max(s(8), Math.min(Screen.width - width - s(8), desiredX))
        }
        y: Config.barPosition === "bottom"
          ? (Screen.height - height - (root.musicLayout ? root.musicLayout.ry : s(70)))
          : (root.musicLayout ? root.musicLayout.ry : s(70))
        color: MatugenColors.bgBase
        border.color: MatugenColors.border
        border.width: 2
        radius: s(10)

        opacity: popup.animOpacity
        scale: 0.94 + 0.06 * popup.animOpacity
        transform: Translate { y: (1 - popup.animOpacity) * -10 }
        MouseArea { anchors.fill: parent }

        Row {
          anchors.fill: parent
          anchors.margins: s(18)
          spacing: s(16)

          Rectangle {
            width: s(200); height: s(200)
            anchors.verticalCenter: parent.verticalCenter
            radius: s(13)
            color: MatugenColors.bgElevated
            border.color: MatugenColors.borderSoft; border.width: 1

            Image {
              id: coverImg
              anchors.fill: parent
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              source: coverPath
              mipmap: true
              visible: false
            }

            Rectangle {
              id: coverMask
              anchors.fill: parent
              radius: s(13)
              visible: false
              layer.enabled: true
            }

            MultiEffect {
              source: coverImg
              anchors.fill: parent
              maskEnabled: true
              maskSource: coverMask
              visible: root.coverPath !== "" && coverImg.status === Image.Ready
            }

            Text {
              anchors.centerIn: parent; text: "♪"
              font.pixelSize: s(64); color: MatugenColors.borderSoft
              visible: root.coverPath === "" || coverImg.status !== Image.Ready
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - s(216)
            spacing: 0

            Item {
              id: marqueeItem
              width: parent.width
              height: s(20)
              clip: true

              property bool shouldScroll: titleText.implicitWidth > marqueeItem.width

              Row {
                id: marqueeRow
                x: 0
                height: parent.height
                spacing: s(40)

                Text {
                  id: titleText
                  text: player ? player.trackTitle : "Not Playing"
                  color: MatugenColors.text
                  font.pixelSize: s(15)
                  font.weight: Font.Bold
                  height: parent.height
                  verticalAlignment: Text.AlignVCenter
                }

                Text {
                  text: player ? player.trackTitle : "Not Playing"
                  color: MatugenColors.text
                  font.pixelSize: s(15)
                  font.weight: Font.Bold
                  height: parent.height
                  verticalAlignment: Text.AlignVCenter
                  visible: marqueeItem.shouldScroll
                }
              }

              SequentialAnimation {
                id: marqueeAnim
                loops: Animation.Infinite
                running: marqueeItem.shouldScroll && titleText.implicitWidth > 0 && root.playerExpanded
                PauseAnimation { duration: 2000 }
                NumberAnimation {
                  target: marqueeRow; property: "x"
                  from: 0; to: -(titleText.implicitWidth + s(40))
                  duration: titleText.implicitWidth * 15
                  easing.type: Easing.Linear
                }
                PauseAnimation { duration: 1000 }
              }

              onShouldScrollChanged: {
                if (!marqueeItem.shouldScroll) { marqueeAnim.stop(); marqueeRow.x = 0 }
                else marqueeAnim.restart()
              }

              Connections {
                target: root
                function onPlayerExpandedChanged() {
                  if (root.playerExpanded && player) progressTrack.displayPosition = player.position
                  }
                }

              Rectangle {
                anchors.left: parent.left
                width: s(24); height: parent.height
                visible: marqueeItem.shouldScroll
                z: 1
                gradient: Gradient {
                  orientation: Gradient.Horizontal
                  GradientStop { position: 0.0; color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 1) }
                  GradientStop { position: 1.0; color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0) }
                }
              }

              Rectangle {
                anchors.right: parent.right
                width: s(24); height: parent.height
                visible: marqueeItem.shouldScroll
                z: 1
                gradient: Gradient {
                  orientation: Gradient.Horizontal
                  GradientStop { position: 0.0; color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0) }
                  GradientStop { position: 1.0; color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 1) }
                }
              }
            }

            Text {
              text: root.artist
              color: MatugenColors.textMuted; font.pixelSize: s(12)
              elide: Text.ElideRight; width: parent.width
            }

            Text {
              text: root.album
              color: MatugenColors.textDim; font.pixelSize: s(10)
              elide: Text.ElideRight; width: parent.width
              visible: root.album !== ""
            }

            Item { width: 1; height: s(20) }

            Item {
              id: progressTrack
              width: parent.width
              height: s(16)

              property bool dragging: false
              property real dragPct: 0
              property real displayPosition: player ? player.position : 0

              readonly property real shownPct: dragging
              ? dragPct
              : (player && player.length > 0
              ? root.normalizeSeconds(displayPosition) / root.normalizeSeconds(player.length) * 100
              : 0)

              Connections {
                target: player
                function onPositionChanged() {
                  progressTrack.displayPosition = player.position
                }
              }

              Timer {
                interval: 500
                running: root.playerExpanded && root.isPlaying && !progressTrack.dragging
                repeat: true
                onTriggered: {
                  if (player) progressTrack.displayPosition = Math.min(player.length, progressTrack.displayPosition + 0.5)
                }
              }

              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: s(8); radius: s(3)
                color: MatugenColors.bgElevated

                Rectangle {
                  width: parent.width * (progressTrack.shownPct / 100)
                  height: parent.height; radius: s(3)
                  color: MatugenColors.accent
                  Behavior on width {
                    enabled: !progressTrack.dragging
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                  }
                }
              }

              Rectangle {
                width: s(13); height: s(13); radius: s(7)
                color: MatugenColors.text
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(parent.width - width, parent.width * (progressTrack.shownPct / 100) - width / 2))
                visible: timelineArea.containsMouse || progressTrack.dragging
                scale: progressTrack.dragging ? 1.2 : 1.0
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
              }

              MouseArea {
                id: timelineArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                function pctFromX(mx) {
                  return Math.max(0, Math.min(100, (mx / width) * 100))
                }

                onPressed: (mouse) => {
                  if (!player || player.length <= 0) return
                  progressTrack.dragging = true
                  progressTrack.dragPct = pctFromX(mouse.x)
                }
                onPositionChanged: (mouse) => {
                  if (progressTrack.dragging)
                    progressTrack.dragPct = pctFromX(mouse.x)
                }
                onReleased: (mouse) => {
                  if (!progressTrack.dragging) return
                  var pct = pctFromX(mouse.x)
                  if (player && player.length > 0) {
                    var targetSeconds = (pct / 100) * root.normalizeSeconds(player.length)
                    var currentSeconds = root.normalizeSeconds(progressTrack.displayPosition)
                    player.seek(targetSeconds - currentSeconds)
                  }
                  progressTrack.dragging = false
                }
              }
            }

            Row {
              width: parent.width
              Text { text: root.positionStr; color: MatugenColors.textDim; font.pixelSize: s(10); font.family: "JetBrainsMono Nerd Font" }
              Item { width: parent.width - s(50); height: 1 }
              Text { text: root.lengthStr; color: MatugenColors.textDim; font.pixelSize: s(10); font.family: "JetBrainsMono Nerd Font" }
            }

            Item { width: 1; height: s(16) }

            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: s(20)

              Repeater {
                model: ["⏮", root.isPlaying ? "⏸" : "▶", "⏭"]

                Rectangle {
                  width: index === 1 ? s(54) : s(44)
                  height: index === 1 ? s(54) : s(44)
                  radius: index === 1 ? s(27) : s(10)
                  property bool isHovered: popupMouse.containsMouse
                  color: index === 1 && root.isPlaying ? MatugenColors.accent : (isHovered ? MatugenColors.bgElevated : "transparent")
                  scale: isHovered ? (index === 1 ? 1.08 : 1.1) : 1.0
                  Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                  Behavior on color { ColorAnimation { duration: 150 } }

                  Text {
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: index === 1 ? s(30) : s(26)
                    color: index === 1 && root.isPlaying ? MatugenColors.accentText : MatugenColors.text
                  }

                  MouseArea {
                    id: popupMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (index === 0 && player) player.previous()
                      else if (index === 1 && player) player.togglePlaying()
                      else if (index === 2 && player) player.next()
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
