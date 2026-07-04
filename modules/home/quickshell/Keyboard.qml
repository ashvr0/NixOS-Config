import QtQuick
import Quickshell.Io

Item {
  id: root
  implicitWidth: pillBg.width
  implicitHeight: pillBg.height

  property int cascadeIndex: 2
  property string layoutFull: "English (US)"
  property string layoutShort: {
    var first = layoutFull.split(" ")[0]
    return first.length >= 2 ? first.substring(0, 2).toUpperCase() : "??"
  }

  property bool entered: false
  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }
  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutBack } } }
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

  Process { id: switchProc; command: ["hyprctl", "switchxkblayout", "main", "next"] }

  Timer {
    interval: 1000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: { if (kbProc.running) kbProc.terminate(); kbProc.running = true }
  }

  Rectangle {
    id: pillBg
    height: 50
    width: kbLabel.implicitWidth + 24
    radius: 14
    color: pillMouse.containsMouse ? Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.85) : Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.75)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    anchors.verticalCenter: parent.verticalCenter

    scale: pillMouse.containsMouse ? 1.05 : 1.0
    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
    Behavior on color { ColorAnimation { duration: 200 } }
    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

    Text {
      id: kbLabel
      anchors.centerIn: parent
      text: root.layoutShort
      color: MatugenColors.text
      font.pixelSize: 13
      font.weight: Font.Black
      font.family: "JetBrainsMono Nerd Font"
    }

    MouseArea {
      id: pillMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: switchProc.running = true
    }
  }
}
