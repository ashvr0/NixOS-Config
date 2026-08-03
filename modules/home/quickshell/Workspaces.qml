import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    Scaler {
        id: scaler
        currentWidth: Screen.width
        currentHeight: Screen.height
    }

    function s(val) {
        return scaler.s(val)
    }

    implicitWidth: pillBg.width
    implicitHeight: pillBg.height

    property int cascadeIndex: 0
    property int wsCount: Config.workspaceCount

    property int pillH: s(36)
    property int spacing: s(6)
    property int padding: s(20)
    property int radius: s(14)
    property int buttonRadius: s(10)
    property int fontSize: s(13)

    property int step: pillH + spacing

    property bool entered: false

    Timer {
        interval: 200 + root.cascadeIndex * 80
        running: true
        onTriggered: root.entered = true
    }

    opacity: entered ? 1 : 0

    transform: Translate {
        y: root.entered ? 0 : s(14)

        Behavior on y {
            NumberAnimation {
                duration: 450
                easing.type: Easing.OutCubic
            }
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: pillBg

        height: s(50)
        width: wsLayout.implicitWidth + root.padding
        radius: root.radius

        color: Qt.rgba(
            MatugenColors.bgBase.r,
            MatugenColors.bgBase.g,
            MatugenColors.bgBase.b,
            0.75
        )

        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1

        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            id: activeHighlight

            y: (pillBg.height - root.pillH) / 2
            width: root.pillH
            height: root.pillH
            radius: root.buttonRadius

            color: MatugenColors.accent
            z: 0

            property int curIdx: {
                var wsList = Hyprland.workspaces.values
                var focusedId = Hyprland.focusedWorkspace
                    ? Hyprland.focusedWorkspace.id
                    : 0

                var stillExists = false
                for (var i = 0; i < wsList.length; i++) {
                    if (wsList[i].id === focusedId) {
                        stillExists = true
                        break
                    }
                }

                if (!stillExists || focusedId <= 0)
                    return activeHighlight.curIdx

                return focusedId - 1
            }

            Connections {
                target: Hyprland.workspaces
                function onValuesChanged() {
                    activeHighlight.x = Qt.binding(function() {
                        return wsLayout.x + activeHighlight.curIdx * root.step
                    })
                }
            }

            x: wsLayout.x + curIdx * root.step

            Behavior on x {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutExpo
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutExpo
                }
            }
        }

        Row {
            id: wsLayout

            anchors.centerIn: parent
            spacing: root.spacing

            Repeater {
                model: root.wsCount

                Rectangle {
                    id: wsButton

                    width: root.pillH
                    height: root.pillH
                    radius: root.buttonRadius
                    color: "transparent"

                    property bool isFocused: Hyprland.focusedWorkspace
                        && Hyprland.focusedWorkspace.id === (index + 1)

                    property bool isOccupied: {
                        var list = Hyprland.workspaces.values
                        for (var i = 0; i < list.length; i++) {
                            if (list[i].id === (index + 1))
                                return true
                        }
                        return false
                    }

                    property bool isHovered: wsMouse.containsMouse

                    scale: isHovered && !isFocused ? 1.1 : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: (index + 1).toString()

                        font.pixelSize: root.fontSize
                        font.weight: wsButton.isFocused
                            ? Font.Black
                            : (wsButton.isOccupied
                                ? Font.Bold
                                : Font.Normal)

                        color: wsButton.isFocused
                            ? MatugenColors.accentText
                            : wsButton.isHovered
                                ? MatugenColors.text
                                : wsButton.isOccupied
                                    ? MatugenColors.accent
                                    : MatugenColors.border

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                    }

                    MouseArea {
                        id: wsMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: Hyprland.dispatch(
                            "hl.dsp.focus({workspace=" + (index + 1) + "})"
                        )
                    }
                }
            }
        }
    }
}