pragma ComponentBehavior: Bound
import "../Singletons"
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray

Item {
    id: root

    // ===== Controller state (shared, singleton-like via this one instance) =====
    property bool isVisible: false
    property string activeItemId: ""
    property real targetX: 0
    property real targetY: 0
    property bool alignRight: false
    property bool alignBottom: false
    property var screen: null
    property bool menuHovered: false
    property int hoveredItems: 0

    Timer {
        id: hideTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (!root.menuHovered && root.hoveredItems <= 0) root.isVisible = false;
        }
    }

    function itemEntered(itemId, scr, posX, posY, isRight, isBottom) {
        hoveredItems++;
        hideTimer.stop();
        show(itemId, scr, posX, posY, isRight, isBottom);
    }
    function itemExited() {
        hoveredItems = Math.max(0, hoveredItems - 1);
        if (hoveredItems <= 0 && !menuHovered) requestHide();
    }
    function show(itemId, scr, posX, posY, isRight, isBottom) {
        hideTimer.stop();
        root.screen = scr;
        root.targetX = posX;
        root.targetY = posY;
        root.alignRight = isRight;
        root.alignBottom = isBottom;
        root.activeItemId = itemId;
        root.isVisible = true;
    }
    function hide() {
        hideTimer.stop();
        hoveredItems = 0;
        root.activeItemId = "";
        root.isVisible = false;
    }
    function requestHide() {
        if (!root.menuHovered && root.hoveredItems <= 0) hideTimer.restart();
    }
    function cancelHide() { hideTimer.stop(); }

    // ===== Popout window =====
    PanelWindow {
        id: trayMenuWindow

        screen: root.screen

        WlrLayershell.namespace: "traymenu"
        WlrLayershell.layer: WlrLayer.Overlay
        focusable: false
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        mask: Region {
            Region {
                item: (root.isVisible || menuContainer.animProgress > 0.001) ? menuContainer : null
            }
        }

        anchors { top: true; bottom: true; left: true; right: true }

        Component.onCompleted: {
        Scaler.currentWidth = Screen.width
        Scaler.currentHeight = Screen.height
    }
        function s(val) { return Scaler.s(val); }

        property real cornerRadius: s(Config.uiRadius)
        property real menuMargin: s(20)

        visible: root.isVisible || menuContainer.animProgress > 0.001

        function idFor(it) {
            if (!it) return "";
            if (it.id !== undefined && it.id !== null && it.id !== "") return String(it.id);
            return (it.title || "") + "|" + (it.icon || "");
        }

        property var activeItem: {
            if (!root.activeItemId) return null;
            let arr = SystemTray.items.values;
            if (!arr) return null;
            for (let i = 0; i < arr.length; i++) {
                if (trayMenuWindow.idFor(arr[i]) === root.activeItemId) return arr[i];
            }
            return null;
        }

        onActiveItemChanged: {
            if (!activeItem && root.isVisible) root.hide();
        }

        property var activeMenuHandle: activeItem ? activeItem.menu : null

        QsMenuOpener {
            id: menuOpener
            menu: trayMenuWindow.activeMenuHandle
        }

        property real menuWidth: s(200)
        property real itemHeight: s(32)
        property int menuCount: {
            if (!menuOpener.children) return 0;
            if (menuOpener.children.values) return menuOpener.children.values.length;
            if (menuOpener.children.count !== undefined) return menuOpener.children.count;
            return 0;
        }
        property real menuHeight: Math.max(s(40), (menuCount * itemHeight) + s(16))

        Item {
            id: rootContainer
            anchors.fill: parent

            Item {
                id: menuContainer
                width: trayMenuWindow.menuWidth
                height: trayMenuWindow.menuHeight

                property real animProgress: 0

                x: {
                    let baseX = root.targetX;
                    if (root.alignRight) baseX -= width;
                    return Math.max(trayMenuWindow.s(4), Math.min(baseX, rootContainer.width - width - trayMenuWindow.s(4)));
                }
                y: {
                    let baseY = root.targetY;
                    if (root.alignBottom) baseY -= (height + trayMenuWindow.menuMargin);
                    else baseY += trayMenuWindow.menuMargin;
                    return Math.max(trayMenuWindow.s(4), Math.min(baseY, rootContainer.height - height - trayMenuWindow.s(4)));
                }

                opacity: animProgress
                scale: 0.9 + (0.1 * animProgress)
                visible: animProgress > 0.001

                states: State {
                    name: "shown"
                    when: root.isVisible
                    PropertyChanges { target: menuContainer; animProgress: 1 }
                }
                transitions: Transition {
                    NumberAnimation { property: "animProgress"; duration: 160; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: trayMenuWindow.cornerRadius
                    color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 1.0)
                    border.color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    clip: true

                    MouseArea { anchors.fill: parent; preventStealing: true }

                    HoverHandler {
                        onHoveredChanged: {
                            root.menuHovered = hovered;
                            if (hovered) root.cancelHide();
                            else root.requestHide();
                        }
                    }

                    ListView {
                        id: listView
                        anchors.fill: parent
                        anchors.margins: trayMenuWindow.s(8)
                        model: menuOpener.children
                        clip: true
                        spacing: 0
                        interactive: contentHeight > height

                        delegate: Item {
                            id: itemDelegate
                            required property var modelData
                            width: listView.width
                            height: trayMenuWindow.itemHeight

                            property bool isSep: modelData ? modelData.isSeparator : false

                            Rectangle {
                                anchors.fill: parent
                                visible: !itemDelegate.isSep
                                radius: trayMenuWindow.s(4)
                                color: itemMouse.containsMouse ? MatugenColors.bgElevated : "transparent"
                                opacity: (itemDelegate.modelData && itemDelegate.modelData.enabled) ? 1.0 : 0.4

                                Image {
                                    id: itemIcon
                                    anchors.left: parent.left
                                    anchors.leftMargin: trayMenuWindow.s(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: (itemDelegate.modelData && itemDelegate.modelData.icon) ? trayMenuWindow.s(16) : 0
                                    height: trayMenuWindow.s(16)
                                    source: (itemDelegate.modelData && itemDelegate.modelData.icon) ? itemDelegate.modelData.icon : ""
                                    sourceSize: Qt.size(trayMenuWindow.s(16), trayMenuWindow.s(16))
                                    visible: width > 0
                                }

                                Text {
                                    anchors.left: itemIcon.visible ? itemIcon.right : parent.left
                                    anchors.leftMargin: trayMenuWindow.s(8)
                                    anchors.right: parent.right
                                    anchors.rightMargin: trayMenuWindow.s(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (itemDelegate.modelData && itemDelegate.modelData.text) ? itemDelegate.modelData.text : ""
                                    color: MatugenColors.text
                                    font.pixelSize: trayMenuWindow.s(13)
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }

                                MouseArea {
                                    id: itemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: itemDelegate.modelData ? itemDelegate.modelData.enabled : false
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: { root.cancelHide(); root.menuHovered = true; }
                                    onExited: { root.requestHide(); }
                                    onClicked: {
                                        if (itemDelegate.modelData) {
                                            itemDelegate.modelData.triggered();
                                            root.hide();
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width - trayMenuWindow.s(16)
                                height: 1
                                color: MatugenColors.borderSoft
                                anchors.centerIn: parent
                                visible: itemDelegate.isSep
                            }
                        }
                    }
                }
            }
        }
    }
}
