import QtQuick
import Quickshell
import Quickshell.Hyprland
import ".."
import "../Singletons"

Item {
    id: root

    Component.onCompleted: {
    Scaler.currentWidth = Screen.width
    Scaler.currentHeight = Screen.height
}

    function s(val) {
        return Scaler.s(val)
    }

    implicitWidth: pillBg.width
    implicitHeight: pillBg.height

    property bool vertical: Config.barVertical
    property int cascadeIndex: 0
    property int wsCount: Config.workspaceCount
    property bool orbStyle: Config.workspaceStyle === "orbs"

    property int pillH: orbStyle ? s(28) : s(36)
    property int spacing: orbStyle ? s(10) : s(6)
    property int padding: orbStyle ? s(16) : s(20)
    property int radius: s(Config.uiRadius)
    property int buttonRadius: s(Math.max(0, Config.uiRadius - 4))
    property int fontSize: s(13)
    property int orbSize: s(8)
    property int orbSizeActive: s(10)

    property int step: pillH + spacing

    readonly property var visibleIds: {
        var list = Hyprland.workspaces.values
        var focusedId = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
        var out = []
        for (var id = 1; id <= root.wsCount; id++) {
            if (!Config.hideEmptyWorkspaces || id === focusedId) {
                out.push(id)
                continue
            }
            for (var i = 0; i < list.length; i++) {
                if (list[i].id === id) { out.push(id); break }
            }
        }
        return out
    }

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

        height: root.vertical ? (wsLayout.height + root.padding) : s(50)
        width: root.vertical ? s(50) : (wsLayout.width + root.padding)
        radius: root.radius

        color: Qt.rgba(
            MatugenColors.bgBase.r,
            MatugenColors.bgBase.g,
            MatugenColors.bgBase.b,
        )

        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1

        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            id: activeHighlight

            width: root.orbStyle ? root.orbSizeActive : (root.vertical ? root.pillH : root.pillH)
            height: root.orbStyle ? root.orbSizeActive : root.pillH
            radius: root.orbStyle ? width / 2 : root.buttonRadius

            visible: !root.orbStyle
            color: MatugenColors.accent
            z: 0

            property int curIdx: {
                var focusedId = Hyprland.focusedWorkspace
                    ? Hyprland.focusedWorkspace.id
                    : 0
                var idx = root.visibleIds.indexOf(focusedId)
                if (idx < 0) return activeHighlight.curIdx
                return idx
            }

            x: root.vertical ? (pillBg.width - root.pillH) / 2 : (wsLayout.x + curIdx * root.step)
            y: root.vertical ? (wsLayout.y + curIdx * root.step) : (pillBg.height - root.pillH) / 2

            Behavior on x {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutExpo
                }
            }

            Behavior on y {
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

            Behavior on height {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutExpo
                }
            }
        }

        Flow {
            id: wsLayout

            x: (pillBg.width - width) / 2
            y: (pillBg.height - height) / 2
            width: root.vertical ? root.pillH : (Math.max(1, root.visibleIds.length) * root.step - root.spacing)
            height: root.vertical ? (Math.max(1, root.visibleIds.length) * root.step - root.spacing) : root.pillH
            spacing: root.spacing
            flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight

            Repeater {
                model: root.visibleIds
                delegate: wsButtonComponent
            }
        }

        Component {
            id: wsButtonComponent

            Item {
                id: wsButton

                readonly property int wsId: modelData

                property bool isFocused: Hyprland.focusedWorkspace
                    && Hyprland.focusedWorkspace.id === wsButton.wsId

                property bool isOccupied: {
                    var list = Hyprland.workspaces.values
                    for (var i = 0; i < list.length; i++) {
                        if (list[i].id === wsButton.wsId)
                            return true
                    }
                    return false
                }

                property bool isHovered: wsMouse.containsMouse

                width: root.pillH
                height: root.pillH

                scale: (!root.orbStyle && isHovered && !isFocused) ? 1.1 : 1.0

                Behavior on scale {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    id: numberBg
                    visible: !root.orbStyle
                    anchors.fill: parent
                    radius: root.buttonRadius
                    color: "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: wsButton.wsId.toString()

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
                }

                Rectangle {
                    id: orb
                    visible: root.orbStyle
                    anchors.centerIn: parent
                    width: wsButton.isFocused ? (root.pillH - s(6)) : (wsButton.isOccupied ? s(10) : s(6))
                    height: wsButton.isFocused ? s(10) : (wsButton.isOccupied ? s(10) : s(6))
                    radius: height / 2

                    Behavior on width {
                        NumberAnimation { duration: 320; easing.type: Easing.OutExpo }
                    }
                    Behavior on height {
                        NumberAnimation { duration: 320; easing.type: Easing.OutExpo }
                    }

                    color: wsButton.isFocused
                        ? MatugenColors.accent
                        : (wsButton.isOccupied
                            ? Qt.rgba(MatugenColors.text.r, MatugenColors.text.g, MatugenColors.text.b, 0.5)
                            : Qt.rgba(MatugenColors.text.r, MatugenColors.text.g, MatugenColors.text.b, 0.2))

                    Behavior on color { ColorAnimation { duration: 200 } }

                    Rectangle {
                        visible: wsButton.isFocused
                        anchors.fill: parent
                        anchors.margins: -1
                        radius: parent.radius + 1
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(MatugenColors.text.r, MatugenColors.text.g, MatugenColors.text.b, 0.2)
                    }

                    Rectangle {
                        id: glowRing
                        visible: wsButton.isFocused
                        anchors.centerIn: parent
                        width: parent.width + 4
                        height: parent.height + 4
                        radius: height / 2
                        color: "transparent"
                        border.width: 2
                        border.color: Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.15)

                        SequentialAnimation on opacity {
                            running: wsButton.isFocused
                            loops: Animation.Infinite

                            NumberAnimation { to: 0.3; duration: 1500; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.8; duration: 1500; easing.type: Easing.InOutSine }
                        }
                    }
                }

                MouseArea {
                    id: wsMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: Hyprland.dispatch(
                        "hl.dsp.focus({workspace=" + wsButton.wsId + "})"
                    )
                }
            }
        }
    }
}
