import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".."
import "../Singletons"
import "../Components"

Item {
    id: root
    implicitHeight: col.implicitHeight

    property var s
    property var matches

    // Settings card the file picker is drawn on (settingsCard in Settings.qml)
    property Item popupLayer: null

    // Kept so Settings.qml can still pass them. The tab reads and writes Config directly.
    property string notifPosition: "top-right"
    property var setNotifPosition: function(pos) {}
    property bool doNotDisturb: false
    property var toggleDoNotDisturb: function() {}
    property var sendTestNotification: function() {}
    property bool notifSound: true
    property var toggleNotifSound: function() {}
    property string notifSoundFile: ""
    property var pickNotifSoundFile: function() {}
    property bool notifHideLockDescription: false
    property var toggleNotifHideLockDescription: function() {}

    onVisibleChanged: if (!visible) soundPicker.visible = false

    readonly property color cardColor: Qt.rgba(1, 1, 1, 0.04)
    readonly property string iconFont: "JetBrainsMono Nerd Font"

    property var positionChoices: [
        { id: "top-left", label: "Top Left" },
        { id: "top-center", label: "Top Center" },
        { id: "top-right", label: "Top Right" },
        { id: "bottom-left", label: "Bottom Left" },
        { id: "bottom-center", label: "Bottom Center" },
        { id: "bottom-right", label: "Bottom Right" }
    ]

    function fileName(path) {
        return path.substring(path.lastIndexOf("/") + 1)
    }

    function chooseSound() {
        soundPicker.visible = true
        soundPicker.openWithOptionalPath(Config.notifSoundFile)
    }

    Process { id: previewProc }

    component SettingCard: Rectangle {
        id: card
        property var s
        property string icon: ""
        property string title: ""
        property string desc: ""
        property string extra: ""
        default property alias controls: ctrlRow.data

        Layout.fillWidth: true
        implicitHeight: cardRow.implicitHeight + s(28)
        radius: s(12)
        color: root.cardColor

        RowLayout {
            id: cardRow
            anchors.fill: parent
            anchors.leftMargin: s(16)
            anchors.rightMargin: s(16)
            anchors.topMargin: s(14)
            anchors.bottomMargin: s(14)
            spacing: s(14)

            Text {
                Layout.preferredWidth: s(22)
                horizontalAlignment: Text.AlignHCenter
                text: card.icon
                font.pixelSize: s(16)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.accent
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: s(2)

                Text {
                    text: card.title
                    color: MatugenColors.text
                    font.pixelSize: s(13)
                    font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                }
                Text {
                    text: card.desc
                    color: MatugenColors.textDim
                    font.pixelSize: s(11)
                    font.family: "JetBrainsMono Nerd Font"
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
                Text {
                    visible: card.extra !== ""
                    text: card.extra
                    color: MatugenColors.accent
                    font.pixelSize: s(11)
                    font.family: "JetBrainsMono Nerd Font"
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }

            RowLayout {
                id: ctrlRow
                spacing: s(10)
            }
        }
    }

    ColumnLayout {
        id: col
        width: root.width
        spacing: s(12)

        SettingCard {
            s: root.s
            icon: "\uf124"
            title: "Notification position"
            desc: "Choose where notification popups appear on screen"
            visible: root.matches("Notification Position")

            Dropdown {
                s: root.s
                boxWidth: 170
                options: root.positionChoices
                labelKey: "label"
                currentIndex: Math.max(0, root.positionChoices.findIndex(c => c.id === Config.notifPosition))
                onPicked: (i) => Config.notifPosition = root.positionChoices[i].id
            }
        }

        SettingCard {
            s: root.s
            icon: "\uf1f6"
            title: "Do not disturb"
            desc: "Silence incoming notification popups"
            visible: root.matches("Do Not Disturb")

            ToggleSwitch {
                s: root.s
                on: root.doNotDisturb
                onToggled: root.toggleDoNotDisturb()
            }
        }

        SettingCard {
            s: root.s
            icon: "\uf023"
            title: "Hide description on lockscreen"
            desc: "Show only the app icon and app name for each notification"
            visible: root.matches("Lockscreen Hide Description Preview")

            ToggleSwitch {
                s: root.s
                on: Config.notifHideLockDescription === true
                onToggled: Config.notifHideLockDescription = !Config.notifHideLockDescription
            }
        }

        SettingCard {
            s: root.s
            icon: "\uf028"
            title: "Notification sound"
            desc: "Play a sound when a notification arrives"
            extra: Config.notifSoundFile !== "" ? root.fileName(Config.notifSoundFile) : "No sound file selected"
            visible: root.matches("Notification Sound")

            ClickButton {
                s: root.s
                variant: "primary"
                buttonHeight: 34
                hPadding: 14
                icon: "\uf07b"
                text: "Choose"
                onClicked: root.chooseSound()
            }

            ToggleSwitch {
                s: root.s
                on: root.notifSound
                onToggled: root.toggleNotifSound()
            }
        }

        SettingCard {
            s: root.s
            icon: "\uf0f3"
            title: "Test notification"
            desc: "Send a test notification to preview the current position and style"
            visible: root.matches("Test Notification")

            ClickButton {
                s: root.s
                variant: "primary"
                buttonHeight: 34
                hPadding: 14
                icon: "\uf1d8"
                text: "Send test"
                onClicked: root.sendTestNotification()
            }
        }
    }

    // File picker for the notification sound, drawn on popupLayer
    FilePickerDialog {
        id: soundPicker
        parent: root.popupLayer ? root.popupLayer : root
        visible: false
        z: 1000
        titleText: "Choose notification sound"
        nameFilters: ["wav", "mp3", "ogg", "oga", "flac", "opus"]
        onAccepted: (path) => {
            soundPicker.visible = false
            Config.notifSoundFile = path
            previewProc.running = false
            previewProc.command = ["pw-play", path]
            previewProc.running = true
        }
        onCancelled: soundPicker.visible = false
    }
}
