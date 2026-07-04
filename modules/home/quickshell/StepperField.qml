import QtQuick

Rectangle {
    id: root

    property var value
    property var formatFn: function(v) { return v.toString() }
    property var stepFn: function(v, dir) { return v + dir }

    signal stepped(var v)

    height: 30
    radius: 7
    color: MatugenColors.bgElevated2
    border.color: MatugenColors.borderSoft
    border.width: 1

    Row {
        anchors.fill: parent

        Rectangle {
            width: 22; height: parent.height
            color: minusHover.containsMouse ? MatugenColors.bgElevated : "transparent"
            Text { anchors.centerIn: parent; text: "−"; color: MatugenColors.accent; font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font" }
            MouseArea {
                id: minusHover
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.stepped(root.stepFn(root.value, -1))
            }
        }

        Text {
            width: parent.width - 44
            height: parent.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.formatFn(root.value)
            color: MatugenColors.text
            font.pixelSize: 11; font.weight: Font.Bold
            font.family: "JetBrainsMono Nerd Font"
            font.features: ({ "tnum": 1 })
        }

        Rectangle {
            width: 22; height: parent.height
            color: plusHover.containsMouse ? MatugenColors.bgElevated : "transparent"
            Text { anchors.centerIn: parent; text: "+"; color: MatugenColors.accent; font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font" }
            MouseArea {
                id: plusHover
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.stepped(root.stepFn(root.value, 1))
            }
        }
    }
}