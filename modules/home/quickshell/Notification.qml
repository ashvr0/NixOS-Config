import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

PanelWindow {
    id: root

    WlrLayershell.namespace: "qs-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"

    anchors { top: true; right: true }
    margins { top: 60; right: 20 }

    width: 340
    height: list.contentHeight

    Behavior on height {
        NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
    }

    ListView {
        id: list
        anchors.fill: parent
        model: Notifs.popups
        spacing: 10
        interactive: false

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 250 }
            NumberAnimation { property: "x"; from: 60; to: 0; duration: 250; easing.type: Easing.OutQuint }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: 200 }
        }
        displaced: Transition {
            NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutQuint }
        }

        delegate: Item {
            id: delegateRoot
            required property var modelData
            width: list.width
            height: Math.max(iconTile.height, col.implicitHeight) + 24

            readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
            readonly property var acts: (modelData.actions || []).filter(a => a.text.length > 0)

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: MatugenColors.bgBase
                border.color: MatugenColors.borderSoft
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        for (let a of (delegateRoot.modelData.actions || [])) {
                            if (a.identifier === "default") { a.invoke(); break; }
                        }
                        Notifs.removePopup(delegateRoot.modelData);
                    }
                }

                Rectangle {
                    id: iconTile
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 12
                    width: 28
                    height: 28
                    radius: 9
                    color: MatugenColors.bgElevated
                    border.width: 1
                    border.color: MatugenColors.borderSoft

                    Image {
                        id: toastImg
                        anchors.fill: parent
                        anchors.margins: delegateRoot.modelData.image ? 0 : 6
                        source: delegateRoot.modelData.appIcon || ""
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        visible: source.toString().length > 0
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        visible: !toastImg.visible
                        width: 7
                        height: 7
                        radius: 2
                        rotation: 45
                        color: delegateRoot.critical ? MatugenColors.error : MatugenColors.accent
                    }
                }

                Text {
                    id: dismiss
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    text: "\u2715"
                    color: dismissArea.containsMouse ? MatugenColors.text : MatugenColors.textDim
                    font.pixelSize: 11

                    Behavior on color { ColorAnimation { duration: 150 } }

                    MouseArea {
                        id: dismissArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.removePopup(delegateRoot.modelData)
                    }
                }

                ColumnLayout {
                    id: col
                    anchors.left: iconTile.right
                    anchors.leftMargin: 10
                    anchors.right: dismiss.left
                    anchors.rightMargin: 8
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 3

                    Text {
                        Layout.fillWidth: true
                        text: (delegateRoot.modelData.appName && delegateRoot.modelData.appName.length) ? delegateRoot.modelData.appName : "System"
                        color: MatugenColors.textDim
                        font.pixelSize: 9
                        font.bold: true
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.2
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Rectangle {
                            visible: delegateRoot.critical
                            width: 6
                            height: 6
                            radius: 3
                            color: MatugenColors.error
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            Layout.fillWidth: true
                            text: delegateRoot.modelData.summary || ""
                            color: MatugenColors.text
                            font.pixelSize: 14
                            font.bold: true
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: (delegateRoot.modelData.body || "") !== ""
                        text: delegateRoot.modelData.body || ""
                        color: MatugenColors.textMuted
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 6
                        visible: delegateRoot.acts.length > 0

                        Repeater {
                            model: delegateRoot.acts
                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                height: 26
                                width: actText.implicitWidth + 18
                                radius: 999
                                color: index === 0 ? MatugenColors.accentSoft : MatugenColors.bgElevated
                                border.width: 1
                                border.color: index === 0 ? MatugenColors.accent : MatugenColors.borderSoft

                                Text {
                                    id: actText
                                    anchors.centerIn: parent
                                    text: parent.modelData.text
                                    color: parent.index === 0 ? MatugenColors.accentText : MatugenColors.text
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        parent.modelData.invoke();
                                        Notifs.removePopup(delegateRoot.modelData);
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
