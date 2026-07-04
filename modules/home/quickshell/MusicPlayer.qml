import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

Item {
  id: root

  IpcHandler {
    target: "music"
    function toggle(): void {
        root.playerExpanded = !root.playerExpanded
    }
}

  implicitWidth: pillBg.width
  implicitHeight: pillBg.height

  property int cascadeIndex: 1
  property bool playerExpanded: false

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

function formatTime(sec) {
    if (!sec || sec <= 0)
        return "0:00"

    var total = Math.floor(sec)
    var minutes = Math.floor(total / 60)
    var seconds = total % 60

    return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
}

readonly property string artist: player && player.trackArtist ? player.trackArtist : ""
readonly property string album: player && player.trackAlbum ? player.trackAlbum : ""
readonly property string title: player && player.trackTitle ? player.trackTitle : ""
readonly property string coverPath: player && player.trackArtUrl ? player.trackArtUrl : ""
readonly property string positionStr: formatTime(player ? player.position : 0)
readonly property string lengthStr: formatTime(player ? player.length : 0)
readonly property bool isPlaying: player && player.isPlaying
readonly property string status: player
    ? (player.isPlaying ? "Playing" : "Paused")
    : "Stopped"

  property bool entered: false
  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }

  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutBack } } }
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

  // Pill not popup
  Rectangle {
    id: pillBg
    height: 50
    width: barRow.implicitWidth + 24
    radius: 14
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
      spacing: 8
      height: 32

      Rectangle {
        width: 32; height: 32; radius: 8
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
          radius: 8
          visible: false
          layer.enabled: true
        }

        MultiEffect {
          source: miniCoverImg
          anchors.fill: parent
          maskEnabled: true
          maskSource: miniCoverMask
          visible: coverPath !== ""
        }

        Text {
          anchors.centerIn: parent; text: "♪"
          font.pixelSize: 16; color: MatugenColors.borderSoft
          visible: coverPath === ""
        }
      }

      Column {
        spacing: 1
        anchors.verticalCenter: parent.verticalCenter
        width: 190

        // title of songs
        Text {
          text: player ? player.trackTitle : "Not Playing"
          color: MatugenColors.text; font.pixelSize: 12; font.weight: Font.Bold
          elide: Text.ElideRight; width: parent.width
        }

        Text {
          text: root.artist
          color: MatugenColors.textMuted; font.pixelSize: 10
          elide: Text.ElideRight; width: parent.width
        }
      }

      Row {
        spacing: 6
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
          model: ["⏮", root.isPlaying ? "⏸" : "▶", "⏭"]

          Rectangle {
            width: 22; height: 22; radius: 6
            property bool isHovered: miniMouse.containsMouse
            color: index === 1 && root.isPlaying ? MatugenColors.accent : (isHovered ? MatugenColors.bgElevated : "transparent")
            scale: isHovered ? 1.15 : 1.0
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
              anchors.centerIn: parent; text: modelData; font.pixelSize: 10
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

  // Popup
  PanelWindow {
    id: popup
    visible: root.playerExpanded || animOpacity > 0.01
    implicitWidth: 640
    implicitHeight: 285

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
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 70
        width: 640
        height: 285
        color: MatugenColors.bgBase
        border.color: MatugenColors.border
        border.width: 2
        radius: 10

        opacity: popup.animOpacity
        scale: 0.94 + 0.06 * popup.animOpacity
        transform: Translate { y: (1 - popup.animOpacity) * -10 }
        MouseArea { anchors.fill: parent }

        Row {
          anchors.fill: parent
          anchors.margins: 18
          spacing: 16

          Rectangle {
            width: 200; height: 200
            anchors.verticalCenter: parent.verticalCenter
            radius: 13
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
              radius: 13
              visible: false
              layer.enabled: true
            }

            MultiEffect {
              source: coverImg
              anchors.fill: parent
              maskEnabled: true
              maskSource: coverMask
              visible: root.coverPath !== ""
            }

            Text {
              anchors.centerIn: parent; text: "♪"
              font.pixelSize: 64; color: MatugenColors.borderSoft
              visible: root.coverPath === ""
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 216
            spacing: 0

            Item {
              id: marqueeItem
              width: parent.width
              height: 20
              clip: true

              property bool shouldScroll: titleText.implicitWidth > marqueeItem.width

              Row {
                id: marqueeRow
                x: 0
                height: parent.height
                spacing: 40

                Text {
                  id: titleText
                  text: player ? player.trackTitle : "Not Playing"
                  color: MatugenColors.text
                  font.pixelSize: 15
                  font.weight: Font.Bold
                  height: parent.height
                  verticalAlignment: Text.AlignVCenter
                }

                Text {
                  text: player ? player.trackTitle : "Not Playing"
                  color: MatugenColors.text
                  font.pixelSize: 15
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
                  from: 0; to: -(titleText.implicitWidth + 40)
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
                  if (!root.playerExpanded) { marqueeAnim.stop(); marqueeRow.x = 0 }
                }
              }

              Rectangle {
                anchors.left: parent.left
                width: 24; height: parent.height
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
                width: 24; height: parent.height
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
              color: MatugenColors.textMuted; font.pixelSize: 12
              elide: Text.ElideRight; width: parent.width
            }

            Text {
              text: root.album
              color: MatugenColors.textDim; font.pixelSize: 10
              elide: Text.ElideRight; width: parent.width
              visible: root.album !== ""
            }

            Item { width: 1; height: 20 }

            Item {
              id: progressTrack
              width: parent.width
              height: 16

              property bool dragging: false
              property real dragPct: 0
              property real displayPosition: player ? player.position : 0

              readonly property real shownPct: dragging
              ? dragPct
              : (player && player.length > 0
              ? displayPosition / player.length * 100
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
                width: parent.width; height: 8; radius: 3
                color: MatugenColors.bgElevated

                Rectangle {
                  width: parent.width * (progressTrack.shownPct / 100)
                  height: parent.height; radius: 3
                  color: MatugenColors.accent
                  Behavior on width {
                    enabled: !progressTrack.dragging
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                  }
                }
              }

              Rectangle {
                width: 13; height: 13; radius: 7
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
                  progressTrack.dragging = true
                  progressTrack.dragPct = pctFromX(mouse.x)
                }
                onPositionChanged: (mouse) => {
                  if (progressTrack.dragging)
                    progressTrack.dragPct = pctFromX(mouse.x)
                }
                onReleased: (mouse) => {
                  var pct = pctFromX(mouse.x)
                  if (player) {
                    player.seek((pct / 100) * player.length - player.position)
                  }
                  progressTrack.dragging = false
                }
              }
            }

            
            Row {
              width: parent.width
              Text { text: root.positionStr; color: MatugenColors.textDim; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
              Item { width: parent.width - 50; height: 1 }
              Text { text: root.lengthStr; color: MatugenColors.textDim; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
            }

            Item { width: 1; height: 16 }

            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: 20

              Repeater {
                model: ["⏮", root.isPlaying ? "⏸" : "▶", "⏭"]

                Rectangle {
                  width: index === 1 ? 54 : 44
                  height: index === 1 ? 54 : 44
                  radius: index === 1 ? 27 : 10
                  property bool isHovered: popupMouse.containsMouse
                  color: index === 1 && root.isPlaying ? MatugenColors.accent : (isHovered ? MatugenColors.bgElevated : "transparent")
                  scale: isHovered ? (index === 1 ? 1.08 : 1.1) : 1.0
                  Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                  Behavior on color { ColorAnimation { duration: 150 } }

                  Text {
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: index === 1 ? 30 : 26
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