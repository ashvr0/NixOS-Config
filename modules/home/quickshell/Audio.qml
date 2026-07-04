import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire

Item {
  id: root

IpcHandler {
    target: "audio"
    function toggle(): void {
    root.volumeMenuOpen = !root.volumeMenuOpen
    }
}

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var sinkAudio: sink ? sink.audio : null

  property bool volumeMenuOpen: false
  property bool osdVisible: false
  property bool osdFirstRun: true

  property int    volumeLevel: sinkAudio ? Math.round(sinkAudio.volume * 100) : 0
  property bool   muted:       sinkAudio ? sinkAudio.muted : false
  property string sinkName:    sink ? (sink.description || sink.nickname || sink.name || "Audio Output") : "Audio Output"
  property string volumeIcon: {
    if (root.muted || root.volumeLevel === 0) return "󰝟"
    if (root.volumeLevel >= 70) return "󰕾"
    if (root.volumeLevel >= 30) return "󰖀"
    return "󰕿"
  }

  PwObjectTracker { objects: root.sink ? [root.sink] : [] }

  // OSD display
  property int  _lastVol:   volumeLevel
  property bool _lastMuted: muted
  onVolumeLevelChanged: _checkOsd()
  onMutedChanged: _checkOsd()
  function _checkOsd() {
    var changed = volumeLevel !== _lastVol || muted !== _lastMuted
    if (!osdFirstRun && changed && !volumeMenuOpen) {
      osdVisible = true
      osdHideTimer.restart()
    }
    osdFirstRun = false
    _lastVol = volumeLevel
    _lastMuted = muted
  }

  Timer { id: osdHideTimer; interval: 1200; onTriggered: root.osdVisible = false }

  function setVolume(pct) {
    var clamped = Math.max(0, Math.min(150, pct))
    if (root.sinkAudio) root.sinkAudio.volume = clamped / 100
    if (!root.volumeMenuOpen) {
      root.osdVisible = true
      osdHideTimer.restart()
    }
  }

  function toggleMute() {
    if (root.sinkAudio) root.sinkAudio.muted = !root.sinkAudio.muted
    root.osdVisible = true
    osdHideTimer.restart()
  }

  // Volume OSD
  PanelWindow {
    id: volOsd
    visible: osdAnim > 0.01
    color: "transparent"
    implicitWidth: 220
    implicitHeight: 120

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "qs-volume-osd"

    anchors.bottom: true
    margins.bottom: 80

    property real osdAnim: root.osdVisible ? 1.0 : 0.0
    Behavior on osdAnim { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    Rectangle {
      anchors.centerIn: parent
      width: 188
      height: 106
      radius: 26
      color: root.muted ? Qt.rgba(MatugenColors.bgElevated2.r, MatugenColors.bgElevated2.g, MatugenColors.bgElevated2.b, 0.92) : Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.88)
      border.color: Qt.rgba(1, 1, 1, 0.08)
      border.width: 1

      opacity: volOsd.osdAnim
      scale: 0.85 + 0.15 * volOsd.osdAnim
      transform: Translate { y: (1 - volOsd.osdAnim) * -8 }

      Column {
        anchors.centerIn: parent
        spacing: 8

        Text {
          text: root.muted ? "\u{f026}" : root.volumeIcon
          font.pixelSize: 28
          color: root.muted ? MatugenColors.textMuted : MatugenColors.accent
          anchors.horizontalCenter: parent.horizontalCenter
        }

        Rectangle {
          width: 130; height: 6; radius: 3; color: MatugenColors.bgElevated
          anchors.horizontalCenter: parent.horizontalCenter

          Rectangle {
            width: parent.width * (root.muted ? 0 : Math.min(root.volumeLevel, 100) / 100)
            height: parent.height; radius: 3
            color: root.volumeLevel > 100 ? MatugenColors.warning : MatugenColors.accent
            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
          }
        }

        Text {
          text: root.muted ? "Muted" : root.volumeLevel + "%"
          font.pixelSize: 11
          font.family: "JetBrainsMono Nerd Font"
          color: root.muted ? MatugenColors.textMuted : MatugenColors.textDim
          anchors.horizontalCenter: parent.horizontalCenter
        }
      }
    }
  }

  // Volume popup
  PanelWindow {
    id: volPopup
    visible: root.volumeMenuOpen
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qs-volume-popup"

    anchors { top: true; left: true; right: true; bottom: true }

    MouseArea {
      anchors.fill: parent
      onClicked: root.volumeMenuOpen = false
    }

    FocusScope {
      anchors.fill: parent
      focus: root.volumeMenuOpen
      Keys.onEscapePressed: root.volumeMenuOpen = false

      Rectangle {
        id: volCard
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 70
        anchors.rightMargin: 8
        width: 410
        height: volCardCol.implicitHeight + 32
        radius: 10
        color: MatugenColors.bgBase
        border.color: MatugenColors.border
        border.width: 2

        MouseArea { anchors.fill: parent }

        Column {
          id: volCardCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 16
          spacing: 14

          Row {
            width: parent.width
            spacing: 10

            Text {
              text: root.volumeIcon
              font.pixelSize: 20
              color: MatugenColors.accent
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 1
              width: parent.width - 30 - 10

              Text {
                text: root.sinkName
                color: MatugenColors.text
                font.pixelSize: 12
                font.weight: Font.Bold
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                text: root.volumeLevel + "%"
                color: MatugenColors.textMuted
                font.pixelSize: 10
                font.family: "JetBrainsMono Nerd Font"
              }
            }
          }

          Item {
            id: volTrack
            width: parent.width
            height: 20

            property bool dragging: false

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width; height: 6; radius: 3; color: MatugenColors.bgElevated

              Rectangle {
                width: parent.width * Math.min(root.volumeLevel, 100) / 100
                height: parent.height; radius: 3
                color: root.volumeLevel > 100 ? MatugenColors.warning : MatugenColors.accent
                Behavior on width { enabled: !volTrack.dragging; NumberAnimation { duration: 200 } }
              }
            }

            Rectangle {
              width: 14; height: 14; radius: 7
              color: MatugenColors.text
              anchors.verticalCenter: parent.verticalCenter
              x: Math.max(0, Math.min(parent.width - width, parent.width * Math.min(root.volumeLevel, 100) / 100 - width / 2))
              scale: volTrack.dragging || volSliderArea.containsMouse ? 1.2 : 1.0
              Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
            }

            MouseArea {
              id: volSliderArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              preventStealing: true

              function pctFromX(mx) {
                return Math.round(Math.max(0, Math.min(150, (mx / width) * 150)))
              }

              onPressed: (mouse) => {
                volTrack.dragging = true
                root.setVolume(pctFromX(mouse.x))
              }
              onPositionChanged: (mouse) => { if (volTrack.dragging) root.setVolume(pctFromX(mouse.x)) }
              onReleased: (mouse) => { volTrack.dragging = false }
              onWheel: (wheel) => { root.setVolume(root.volumeLevel + (wheel.angleDelta.y > 0 ? 5 : -5)) }
              onDoubleClicked: root.toggleMute()
            }
          }
        }
      }
    }
  }
}
