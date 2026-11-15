import ".."
import "../Singletons"
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Hyprland

Item {
    id: root
    property bool vertical: Config.barVertical
    property real counterRotation: vertical ? (Config.barPosition === "left" ? 90 : -90) : 0

    implicitWidth: vertical ? s(50) : (contentRow.implicitWidth + s(16))
    implicitHeight: vertical ? (contentRow.implicitHeight + s(16)) : (parent ? parent.height : s(50))
    property int cascadeIndex: 2
    property string layoutFull: "English (US)"
    property string mainKeyboard: ""
    property string layoutShort: {
        var first = layoutFull.split(" ")[0]
        return first.length >= 2 ? first.substring(0, 2).toUpperCase() : "??"
    }
    property bool entered: false

    function s(val) { return Scaler.s(val) }

    Component.onCompleted: {
        Scaler.currentWidth = Screen.width
        Scaler.currentHeight = Screen.height
        kbProc.running = true
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
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text)
                    var kbs = data.keyboards || []
                    if (kbs.length === 0) return

                    var main = kbs[0]
                    for (var i = 0; i < kbs.length; i++) {
                        if (kbs[i].main === true) { main = kbs[i]; break }
                    }

                    root.mainKeyboard = main.name || ""
                    if (main.active_keymap && main.active_keymap.length > 0)
                        root.layoutFull = main.active_keymap
                } catch (e) {}
            }
        }
    }

    // Live updates: Hyprland emits "activelayout>>KEYBOARD,LAYOUT"
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout") return

            var args = event.parse(2)   // [keyboardName, layoutName]
            if (args.length < 2) return

            // Ignore other keyboards once we know which one is main
            if (root.mainKeyboard !== "" && args[0] !== root.mainKeyboard) return
            if (args[1].length > 0) root.layoutFull = args[1]
        }
    }

    Process {
        id: switchProc
        command: ["hyprctl", "switchxkblayout", "main", "next"]
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