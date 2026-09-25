import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import ".."
import "../Singletons"

Item {
  id: root
  anchors.fill: parent

  // "wide" = original horizontal strip (small cover, left-aligned info).
  // "large" = tall layout with a big centered cover, title/artist below,
  // then timeline, time labels, and controls - matches a full player
  // rather than a compact status strip.
  property string variant: "wide"

  readonly property var player: {
    let list = Mpris.players.values
    if (!list || list.length === 0) return null
    for (let i = 0; i < list.length; i++) {
      if (list[i] && list[i].isPlaying) return list[i]
    }
    return list[0]
  }
  readonly property bool hasTrack: player !== null

  function normalizeSeconds(val) {
    if (!val || val <= 0) return 0
    if (val > 36000) return val / 1000000 // player reported microseconds
    return val
  }

  function formatTime(sec) {
    let normalized = normalizeSeconds(sec)
    if (!normalized || normalized <= 0) return "0:00"
    let total = Math.floor(normalized)
    let hours = Math.floor(total / 3600)
    let minutes = Math.floor((total % 3600) / 60)
    let seconds = total % 60
    let mm = (hours > 0 && minutes < 10) ? "0" + minutes : String(minutes)
    let ss = (seconds < 10 ? "0" : "") + seconds
    return hours > 0 ? (hours + ":" + mm + ":" + ss) : (minutes + ":" + ss)
  }

  readonly property string coverPath: {
    if (!player || !player.trackArtUrl) return ""
    let url = String(player.trackArtUrl).trim()
    if (url.length === 0) return ""
    if (url.indexOf("://") === -1) return "file://" + url
    return url
  }

  Rectangle {
    anchors.fill: parent
    radius: 20
    color: MatugenColors.bgBase
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1
  }

  // Shared position tracking, driven by a 500ms timer while playing so the
  // scrubber advances smoothly without polling the player every frame.
  QtObject {
    id: shared
    property bool dragging: false
    property real dragPct: 0
    property real displayPosition: root.player ? root.player.position : 0
    readonly property real shownPct: dragging
      ? dragPct
      : (root.player && root.player.length > 0
        ? root.normalizeSeconds(displayPosition) / root.normalizeSeconds(root.player.length) * 100
        : 0)
  }

  Connections {
    target: root.player
    function onPositionChanged() {
      if (root.player) shared.displayPosition = root.player.position
    }
  }

  Timer {
    interval: 500
    running: root.hasTrack && root.player.isPlaying && !shared.dragging
    repeat: true
    onTriggered: {
      if (root.player) shared.displayPosition = Math.min(root.player.length, shared.displayPosition + 0.5)
    }
  }

  Loader {
    anchors.fill: parent
    sourceComponent: root.variant === "large" ? largeComp : wideComp
  }

  // ── Wide: original horizontal strip layout ──
  Component {
    id: wideComp

    Row {
      anchors.fill: parent
      anchors.margins: 16
      spacing: 16

      readonly property real coverSize: Math.min(width * 0.42, height - 32)

      Rectangle {
        id: coverBox
        width: parent.coverSize
        height: parent.coverSize
        radius: 14
        anchors.verticalCenter: parent.verticalCenter
        color: Qt.rgba(1, 1, 1, 0.06)
        clip: true

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
          anchors.fill: parent
          radius: 14
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
          anchors.centerIn: parent
          visible: root.coverPath === "" || coverImg.status !== Image.Ready
          text: "\uf001"
          font.pixelSize: parent.width * 0.3
          font.family: "JetBrainsMono Nerd Font"
          color: MatugenColors.textDim
        }
      }

      Column {
        width: parent.width - parent.coverSize - parent.spacing
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Text {
          width: parent.width
          text: root.hasTrack && root.player.trackTitle ? root.player.trackTitle : "Not playing"
          color: MatugenColors.text
          font.pixelSize: Math.min(root.width, root.height) * 0.075
          font.weight: Font.Bold
          font.family: Config.fontFamily
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: root.hasTrack ? root.player.trackArtist : ""
          color: MatugenColors.textMuted
          font.pixelSize: Math.min(root.width, root.height) * 0.05
          font.family: Config.fontFamily
          elide: Text.ElideRight
        }

        MusicTimeline {
          width: parent.width
          dotSize: 12
          trackHeight: 7
        }

        Item {
          width: parent.width
          height: 14

          Text {
            anchors.left: parent.left
            text: root.formatTime(shared.displayPosition)
            color: MatugenColors.textDim
            font.pixelSize: 10
            font.family: "JetBrainsMono Nerd Font"
          }
          Text {
            anchors.right: parent.right
            text: root.hasTrack ? root.formatTime(root.player.length) : "0:00"
            color: MatugenColors.textDim
            font.pixelSize: 10
            font.family: "JetBrainsMono Nerd Font"
          }
        }

        MusicControls {
          anchors.horizontalCenter: parent.horizontalCenter
          iconScale: 0.12
          spacing: 25
        }
      }
    }
  }

  // ── Large: tall layout, big centered cover, everything stacked ──
  Component {
    id: largeComp

    Column {
      anchors.fill: parent
      anchors.margins: 22
      spacing: 16

      readonly property real coverSize: Math.min(width, height * 0.55)

      Rectangle {
        id: coverBoxLarge
        width: parent.coverSize
        height: parent.coverSize
        anchors.horizontalCenter: parent.horizontalCenter
        radius: 20
        color: Qt.rgba(1, 1, 1, 0.06)
        clip: true

        Image {
          id: coverImgLarge
          anchors.fill: parent
          source: root.coverPath
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          mipmap: true
          visible: false
        }

        Rectangle {
          id: coverMaskLarge
          anchors.fill: parent
          radius: 20
          visible: false
          layer.enabled: true
        }

        MultiEffect {
          source: coverImgLarge
          anchors.fill: parent
          maskEnabled: true
          maskSource: coverMaskLarge
          visible: root.coverPath !== "" && coverImgLarge.status === Image.Ready
        }

        Text {
          anchors.centerIn: parent
          visible: root.coverPath === "" || coverImgLarge.status !== Image.Ready
          text: "\uf001"
          font.pixelSize: parent.width * 0.28
          font.family: "JetBrainsMono Nerd Font"
          color: MatugenColors.textDim
        }
      }

      Column {
        width: parent.width
        spacing: 4

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: root.hasTrack && root.player.trackTitle ? root.player.trackTitle : "Not playing"
          color: MatugenColors.text
          font.pixelSize: 18
          font.weight: Font.Bold
          font.family: Config.fontFamily
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: root.hasTrack ? root.player.trackArtist : ""
          color: MatugenColors.textMuted
          font.pixelSize: 13
          font.family: Config.fontFamily
          elide: Text.ElideRight
        }
      }

      Item { width: 1; height: 4 } // breathing room before the timeline

      MusicTimeline {
        width: parent.width
        dotSize: 14
        trackHeight: 8
      }

      Item {
        width: parent.width
        height: 14

        Text {
          anchors.left: parent.left
          text: root.formatTime(shared.displayPosition)
          color: MatugenColors.textDim
          font.pixelSize: 11
          font.family: "JetBrainsMono Nerd Font"
        }
        Text {
          anchors.right: parent.right
          text: root.hasTrack ? root.formatTime(root.player.length) : "0:00"
          color: MatugenColors.textDim
          font.pixelSize: 11
          font.family: "JetBrainsMono Nerd Font"
        }
      }

      MusicControls {
        anchors.horizontalCenter: parent.horizontalCenter
        iconScale: 0.1
        spacing: 26
      }
    }
  }

  // ── Shared timeline scrubber, used by both variants ──
  component MusicTimeline: Item {
    id: timeline
    height: dotSize
    property real dotSize: 12
    property real trackHeight: 7

    Rectangle {
      id: trackBg
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      height: timeline.trackHeight
      radius: timeline.trackHeight / 2
      color: Qt.rgba(1, 1, 1, 0.12)

      Rectangle {
        width: parent.width * (shared.shownPct / 100)
        height: parent.height
        radius: parent.radius
        color: MatugenColors.accent
        Behavior on width { enabled: !shared.dragging; NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
      }
    }

    Rectangle {
      width: timeline.dotSize; height: timeline.dotSize; radius: timeline.dotSize / 2
      color: MatugenColors.text
      anchors.verticalCenter: parent.verticalCenter
      x: Math.max(0, Math.min(parent.width - width, parent.width * (shared.shownPct / 100) - width / 2))
      scale: shared.dragging ? 1.35 : 1.0
      Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
    }

    MouseArea {
      anchors.fill: parent
      anchors.margins: -6
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      preventStealing: true

      function pctFromX(mx) {
        return Math.max(0, Math.min(100, (mx / timeline.width) * 100))
      }

      onPressed: (mouse) => {
        if (!root.hasTrack || root.player.length <= 0) return
        shared.dragging = true
        shared.dragPct = pctFromX(mouse.x)
      }
      onPositionChanged: (mouse) => {
        if (shared.dragging) shared.dragPct = pctFromX(mouse.x)
      }
      onReleased: (mouse) => {
        if (!shared.dragging) return
        let pct = pctFromX(mouse.x)
        if (root.hasTrack && root.player.length > 0) {
          let targetSeconds = (pct / 100) * root.normalizeSeconds(root.player.length)
          let currentSeconds = root.normalizeSeconds(shared.displayPosition)
          root.player.seek(targetSeconds - currentSeconds)
        }
        shared.dragging = false
      }
    }
  }

  // ── Shared prev/play/next controls, used by both variants ──
  component MusicControls: Row {
    id: controls
    property real iconScale: 0.1 // multiplied by min(root.width, root.height)

    Text {
      text: "\uf048"
      font.pixelSize: Math.min(root.width, root.height) * controls.iconScale * 0.85
      font.family: "JetBrainsMono Nerd Font"
      color: prevMa.containsMouse ? MatugenColors.accent : MatugenColors.text
      MouseArea { id: prevMa; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.hasTrack && root.player.previous() }
    }

    Text {
      text: root.hasTrack && root.player.isPlaying ? "\uf04c" : "\uf04b"
      font.pixelSize: Math.min(root.width, root.height) * controls.iconScale
      font.family: "JetBrainsMono Nerd Font"
      color: playMa.containsMouse ? MatugenColors.accent : MatugenColors.text
      MouseArea { id: playMa; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.hasTrack && root.player.togglePlaying() }
    }

    Text {
      text: "\uf051"
      font.pixelSize: Math.min(root.width, root.height) * controls.iconScale * 0.85
      font.family: "JetBrainsMono Nerd Font"
      color: nextMa.containsMouse ? MatugenColors.accent : MatugenColors.text
      MouseArea { id: nextMa; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.hasTrack && root.player.next() }
    }
  }
}
