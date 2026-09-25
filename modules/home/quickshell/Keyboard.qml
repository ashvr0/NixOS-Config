import "Singletons"
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
  id: root
  property bool vertical: Config.barVertical
  property real counterRotation: vertical ? (Config.barPosition === "left" ? 90 : -90) : 0

  implicitWidth: vertical ? s(50) : (contentRow.implicitWidth + s(16))
  implicitHeight: vertical ? (contentRow.implicitHeight + s(16)) : (parent ? parent.height : s(50))
  property int cascadeIndex: 2
  property string layoutFull: "English (US)"
  property string layoutShort: {
    var first = layoutFull.split(" ")[0]
    return first.length >= 2 ? first.substring(0, 2).toUpperCase() : "??"
  }
  property bool entered: false

  Component.onCompleted: {
        Scaler.currentWidth = Screen.width
        Scaler.currentHeight = Screen.height
    }

  function s(val) {
    return Scaler.s(val)
  }

  Rectangle {
    id: pillBg
    anchors.fill: parent
    radius: s(Config.uiRadius + 4)
    color: "transparent"
    border.color: "transparent"
    border.width: 1
  }

  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }
  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } } }
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

  Process {
    id: kbProc
    command: ["bash", "-c", "hyprctl devices -j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(this.text)
          var layout = "English (US)"
          if (data.keyboards && data.keyboards.length > 0) {
            for (var i = 0; i < data.keyboards.length; i++) {
              var k = data.keyboards[i]
              if (k.main === true && k.active_keymap) {
                layout = k.active_keymap
                break
              }
            }
            if (layout === "English (US)") {
              layout = data.keyboards[0].active_keymap || layout
            }
          }
          if (layout && layout.length > 0) {
            root.layoutFull = layout
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: switchProc
    command: ["hyprctl", "switchxkblayout", "main", "next"]
    onExited: kbProc.running = true
  }

  Timer {
    interval: 1000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: { if (kbProc.running) kbProc.terminate(); kbProc.running = true }
  }

  Row {
    id: contentRow
    anchors.centerIn: parent
    spacing: s(6)

    Text {
      text: "󰌌"
      color: MatugenColors.text
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: s(14)
    }

    Text {
      id: kbLabel
      text: root.layoutShort
      color: MatugenColors.text
      font.pixelSize: s(13)
      font.weight: Font.Black
      font.family: "JetBrainsMono Nerd Font"
      width: implicitWidth
    }
  }

  MouseArea {
    id: pillMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: { if (!switchProc.running) switchProc.running = true }
  }
}