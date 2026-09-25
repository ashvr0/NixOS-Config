import QtQuick
import QtQuick.Layouts
import ".."
import "../Singletons"

ColumnLayout {
    id: root
    spacing: s(14)

    property var s
    property var matches

    property string notifPosition: "top-right"
    property var setNotifPosition: function(pos) {}

    property bool doNotDisturb: false
    property var toggleDoNotDisturb: function() {}

    property var sendTestNotification: function() {}

    property var positionChoices: [
        { id: "top-left", label: "Top Left" },
        { id: "bottom-left", label: "Bottom Left" },
        { id: "top-right", label: "Top Right" },
        { id: "bottom-right", label: "Bottom Right" },
        { id: "top-center", label: "Top Center" },
        { id: "bottom-center", label: "Bottom Center" }
    ]

    // ── Position ──
    ColumnLayout {
        Layout.fillWidth: true
        spacing: s(8)
        visible: root.matches("Notification Position")

        Text {
            text: "Notification Position"
            color: MatugenColors.text
            font.pixelSize: s(13)
            font.bold: true
            font.family: "JetBrainsMono Nerd Font"
        }

        Text {
            text: "Choose where notification popups appear on screen."
            color: MatugenColors.textDim
            font.pixelSize: s(11)
            font.family: "JetBrainsMono Nerd Font"
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: s(4)
            columns: 3
            columnSpacing: s(8)
            rowSpacing: s(8)

            Repeater {
                model: root.positionChoices
                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: s(36)
                    radius: s(8)
                    color: root.notifPosition === modelData.id
                        ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.85)
                        : (posMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : MatugenColors.bgElevated)
                    border.width: 1
                    border.color: root.notifPosition === modelData.id ? "transparent" : MatugenColors.borderSoft
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: s(11)
                        font.family: "JetBrainsMono Nerd Font"
                        font.weight: root.notifPosition === modelData.id ? Font.Bold : Font.Normal
                        color: root.notifPosition === modelData.id ? MatugenColors.accentText : MatugenColors.text
                    }

                    MouseArea {
                        id: posMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setNotifPosition(modelData.id)
                    }
                }
            }
        }
    }

    // ── Do Not Disturb ──
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: s(4)
        spacing: s(10)
        visible: root.matches("Do Not Disturb")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: s(2)

            Text {
                text: "Do Not Disturb"
                color: MatugenColors.text
                font.pixelSize: s(13)
                font.bold: true
                font.family: "JetBrainsMono Nerd Font"
            }
            Text {
                text: "Silence incoming notification popups."
                color: MatugenColors.textDim
                font.pixelSize: s(11)
                font.family: "JetBrainsMono Nerd Font"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }

        Rectangle {
            Layout.preferredWidth: s(42)
            Layout.preferredHeight: s(24)
            radius: s(12)
            color: root.doNotDisturb ? MatugenColors.accent : MatugenColors.bgElevated
            border.width: 1
            border.color: root.doNotDisturb ? "transparent" : MatugenColors.borderSoft
            Behavior on color { ColorAnimation { duration: 150 } }

            Rectangle {
                width: s(18)
                height: s(18)
                radius: s(9)
                color: MatugenColors.accentText
                anchors.verticalCenter: parent.verticalCenter
                x: root.doNotDisturb ? parent.width - width - s(3) : s(3)
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleDoNotDisturb()
            }
        }
    }

    // ── Test ──
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: s(4)
        spacing: s(8)
        visible: root.matches("Test Notification")

        Text {
            text: "Test"
            color: MatugenColors.text
            font.pixelSize: s(13)
            font.bold: true
            font.family: "JetBrainsMono Nerd Font"
        }

        Text {
            text: "Send a test notification to preview the current position and style."
            color: MatugenColors.textDim
            font.pixelSize: s(11)
            font.family: "JetBrainsMono Nerd Font"
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.preferredWidth: s(150)
            Layout.preferredHeight: s(34)
            radius: s(8)
            color: testMa.containsMouse
                ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.85)
                : MatugenColors.bgElevated
            border.width: 1
            border.color: MatugenColors.borderSoft
            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors.centerIn: parent
                spacing: s(6)

                Text {
                    text: "\uf0f3"
                    font.pixelSize: s(12)
                    font.family: "JetBrainsMono Nerd Font"
                    color: testMa.containsMouse ? MatugenColors.accentText : MatugenColors.text
                }
                Text {
                    text: "Send Test"
                    font.pixelSize: s(12)
                    font.family: "JetBrainsMono Nerd Font"
                    color: testMa.containsMouse ? MatugenColors.accentText : MatugenColors.text
                }
            }

            MouseArea {
                id: testMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.sendTestNotification()
            }
        }
    }

    Item { Layout.fillHeight: true }
}
