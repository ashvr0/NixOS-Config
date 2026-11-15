import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import ".."
import "../Singletons"

PanelWindow {
    id: root

    WlrLayershell.namespace: "qs-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"

    readonly property string pos: (typeof Config !== "undefined" && Config && Config.notifPosition) ? Config.notifPosition : "top-right"
    readonly property bool anchorTop: pos.startsWith("top")
    readonly property bool anchorBottom: pos.startsWith("bottom")
    readonly property bool anchorLeft: pos.endsWith("left")
    readonly property bool anchorRight: pos.endsWith("right")
    readonly property bool anchorHCenter: !anchorLeft && !anchorRight

    anchors {
        top: root.anchorTop
        bottom: root.anchorBottom
        // When centered horizontally (pos is "top" or "bottom"), anchor both
        // edges to span the screen width - PanelWindow anchors don't support
        // horizontalCenter, so the content itself is centered inside instead.
        left: root.anchorLeft || root.anchorHCenter
        right: root.anchorRight || root.anchorHCenter
    }
    margins {
        top: 60
        bottom: 20
        left: 20
        right: 20
    }

    implicitWidth: root.anchorHCenter ? Screen.width : 340
    implicitHeight: list.contentHeight

    Behavior on implicitHeight {
        NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
    }

    ListView {
        id: list
        width: 340
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        x: root.anchorHCenter ? Math.round((parent.width - width) / 2) : (root.anchorRight ? parent.width - width : 0)
        model: Notifs.popups
        spacing: 10
        interactive: false
        verticalLayoutDirection: root.anchorBottom ? ListView.BottomToTop : ListView.TopToBottom

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 250 }
            NumberAnimation { property: "x"; from: 60; to: 0; duration: 250; easing.type: Easing.OutQuint }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: 120 }
        }
        displaced: Transition {
            // Was 250ms — combined with the delegate's own y-Behavior this
            // made the reflow after a swipe-dismiss feel like it took 1-2
            // seconds. Only one of these should really be animating position
            // at a time; keeping this one fast and letting it be the single
            // source of truth for the reflow.
            NumberAnimation { properties: "y"; duration: 120; easing.type: Easing.OutCubic }
        }

        delegate: Item {
            id: delegateRoot
            required property var modelData
            width: list.width
            height: (Math.max(iconTile.height, col.implicitHeight) + 24) + (canExpand ? expandProgress * expandedExtraHeight : 0)

            // Only the height Behavior lives here now. A y-Behavior was
            // added earlier alongside the ListView's own `displaced`
            // transition below, but having both animate the same property
            // means each removal could re-trigger/compound the other,
            // which is what made the reflow feel like it took 1-2 seconds
            // instead of being instant/snappy. `displaced` below is now the
            // single source of truth for repositioning.
            Behavior on height {
                enabled: !vDragArea.activeVerticalDrag
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            readonly property bool critical: modelData.urgency === NotificationUrgency.Critical

            // ---- Horizontal swipe-to-dismiss ----
            property real dragX: 0
            readonly property real dismissThreshold: width * 0.35
            property bool dismissing: false

            function dismiss() {
                if (delegateRoot.dismissing) return
                delegateRoot.dismissing = true
                Notifs.removePopup(delegateRoot.modelData);
            }

            // ---- Expand/collapse (vertical drag) ----
            property bool expanded: false
            property real expandProgress: 0
            readonly property real expandedExtraHeight: 60

            readonly property bool hasLongBody: (modelData.body || "").length > 90
            readonly property bool hasActions: !!(modelData.actions && modelData.actions.length > 0)
            readonly property bool canExpand: hasLongBody || hasActions

            Behavior on expandProgress {
                enabled: !vDragArea.activeVerticalDrag
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }

            function setExpanded(v) {
                delegateRoot.expanded = v
                delegateRoot.expandProgress = v ? 1 : 0
            }

            // ---- Read state ----
            property bool readState: modelData.read !== undefined ? modelData.read : true

            function forceRead(v) {
                delegateRoot.readState = v
            }

            function markReadIfNeeded() {
                if (delegateRoot.readState === false) {
                    delegateRoot.readState = true
                    if (typeof Notifs !== "undefined"
                        && Notifs
                        && delegateRoot.modelData
                        && delegateRoot.modelData.uid !== undefined) {
                        Notifs.markAsRead(delegateRoot.modelData.uid)
                    }
                }
            }

            onModelDataChanged: {
                delegateRoot.readState = modelData.read !== undefined ? modelData.read : true
            }

            // ---- Timestamp / time text ----
            property real timestamp: modelData.timestamp || Date.now()
            property string timeText: "";

            function computeTimeText() {
                const now = new Date();
                const ts = new Date(delegateRoot.timestamp);
                const diffMs = now.getTime() - ts.getTime();
                const diffSec = Math.floor(diffMs / 1000);
                const diffMin = Math.floor(diffSec / 60);

                function pad(n) { return n < 10 ? "0" + n : "" + n }

                const use24h = (typeof TimeConfig !== "undefined" && TimeConfig && TimeConfig.use24Hour !== undefined)
                    ? TimeConfig.use24Hour
                    : true;

                function hm(d) {
                    if (use24h) {
                        return pad(d.getHours()) + ":" + pad(d.getMinutes());
                    } else {
                        let h = d.getHours() % 12;
                        if (h === 0) h = 12;
                        const ampm = d.getHours() < 12 ? "AM" : "PM";
                        return h + ":" + pad(d.getMinutes()) + " " + ampm;
                    }
                }

                if (diffSec < 60) {
                    delegateRoot.timeText = "Just now";
                    return;
                }
                if (diffMin < 60) {
                    delegateRoot.timeText = diffMin + " min ago";
                    return;
                }

                const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
                const startOfTsDay = new Date(ts.getFullYear(), ts.getMonth(), ts.getDate());
                const dayDiff = Math.round((startOfToday.getTime() - startOfTsDay.getTime()) / 86400000);

                if (dayDiff === 0) {
                    delegateRoot.timeText = hm(ts);
                    return;
                }
                if (dayDiff === 1) {
                    delegateRoot.timeText = "Yesterday " + hm(ts);
                    return;
                }
                if (dayDiff > 1 && dayDiff < 7) {
                    const weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
                    delegateRoot.timeText = weekdays[ts.getDay()] + " " + hm(ts);
                    return;
                }

                delegateRoot.timeText = ts.getFullYear() + "-" + pad(ts.getMonth() + 1) + "-" + pad(ts.getDate()) + " " + hm(ts);
            }

            onTimestampChanged: delegateRoot.computeTimeText()
            Component.onCompleted: delegateRoot.computeTimeText()

            Timer {
                interval: 10000
                running: true
                repeat: true
                onTriggered: delegateRoot.computeTimeText()
            }

            Rectangle {
                id: card
                anchors.fill: parent
                radius: 12
                color: MatugenColors.bgBase
                border.color: MatugenColors.borderSoft
                border.width: 1

                x: delegateRoot.dragX
                opacity: 1 - Math.min(1, Math.abs(delegateRoot.dragX) / delegateRoot.width)
                Behavior on x {
                    enabled: !vDragArea.pressed
                    NumberAnimation { duration: 220; easing.type: Easing.OutExpo }
                }
                Behavior on opacity {
                    enabled: !vDragArea.pressed
                    NumberAnimation { duration: 220; easing.type: Easing.OutExpo }
                }

                MouseArea {
                    id: vDragArea
                    anchors.fill: parent
                    anchors.rightMargin: 28

                    // gesture-lock state
                    property real startX: 0
                    property real startY: 0
                    property real startExpandProgress: 0
                    property bool didDrag: false
                    property bool axisLocked: false
                    property bool horizontalLocked: false
                    property bool verticalLocked: false
                    readonly property real lockThreshold: 6

                    // whether we're actively performing a vertical drag right now
                    property bool activeVerticalDrag: pressed && verticalLocked

                    preventStealing: false

                    // stable top-level root to map coordinates against so deltas
                    // don't jitter as the delegate itself moves/resizes.
                    property Item stableRoot: root.contentItem ? root.contentItem : root

                    onPressed: mouse => {
                        const p = vDragArea.mapToItem(vDragArea.stableRoot, mouse.x, mouse.y)
                        startX = p.x
                        startY = p.y
                        startExpandProgress = delegateRoot.expandProgress
                        didDrag = false
                        axisLocked = false
                        horizontalLocked = false
                        verticalLocked = false
                        preventStealing = false
                    }

                    onPositionChanged: mouse => {
                        const p = vDragArea.mapToItem(vDragArea.stableRoot, mouse.x, mouse.y)
                        const dx = p.x - startX
                        const dy = p.y - startY

                        if (!axisLocked) {
                            if (Math.abs(dx) > lockThreshold || Math.abs(dy) > lockThreshold) {
                                axisLocked = true
                                if (Math.abs(dx) > Math.abs(dy)) {
                                    horizontalLocked = true
                                } else if (delegateRoot.canExpand) {
                                    verticalLocked = true
                                } else {
                                    // no expand content available; treat as horizontal-only surface
                                    horizontalLocked = true
                                }
                                preventStealing = true
                            }
                        }

                        if (horizontalLocked) {
                            didDrag = true
                            delegateRoot.dragX = dx
                        } else if (verticalLocked) {
                            didDrag = true
                            // rubber-band: dragging down increases expandProgress
                            const delta = dy / delegateRoot.expandedExtraHeight
                            let prog = startExpandProgress + delta
                            prog = Math.max(-0.15, Math.min(1.15, prog))
                            delegateRoot.expandProgress = Math.max(0, Math.min(1, prog))
                        }
                    }

                    onReleased: {
                        if (horizontalLocked) {
                            if (!didDrag) {
                                axisLocked = false; horizontalLocked = false; verticalLocked = false
                                preventStealing = false
                                return
                            }
                            if (Math.abs(delegateRoot.dragX) > delegateRoot.dismissThreshold) {
                                delegateRoot.dragX = delegateRoot.dragX < 0 ? -delegateRoot.width : delegateRoot.width
                                delegateRoot.dismiss()
                            } else {
                                delegateRoot.dragX = 0
                            }
                        } else if (verticalLocked) {
                            const prog = delegateRoot.expandProgress
                            if (delegateRoot.expanded) {
                                // currently expanded: collapse if dragged up past 65% -> below 0.65
                                delegateRoot.setExpanded(prog >= 0.35)
                            } else {
                                // currently collapsed: expand if dragged down past 35%
                                delegateRoot.setExpanded(prog >= 0.35)
                            }
                        } else if (!didDrag) {
                            // plain tap: mark as read
                            delegateRoot.markReadIfNeeded()
                        }

                        axisLocked = false
                        horizontalLocked = false
                        verticalLocked = false
                        preventStealing = false
                    }

                    onCanceled: {
                        delegateRoot.dragX = 0
                        delegateRoot.setExpanded(delegateRoot.expanded)
                        axisLocked = false
                        horizontalLocked = false
                        verticalLocked = false
                        preventStealing = false
                    }
                }

                // Invisible anchor so col's anchors.right: dismiss.left still works
                // without an X button or unread dot taking up visual space.
                Item {
                    id: dismiss
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    width: 0
                    height: 1
                }

                Rectangle {
                    id: iconTile
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 12
                    width: 48
                    height: 48
                    radius: 9
                    color: MatugenColors.bgElevated
                    border.width: 1
                    border.color: MatugenColors.borderSoft
                    clip: true

                    Image {
                        id: toastImg
                        anchors.fill: parent
                        asynchronous: true
                        source: {
                            let ic = delegateRoot.modelData.image || delegateRoot.modelData.imagePath || delegateRoot.modelData.icon || delegateRoot.modelData.iconPath || "";
                            if (!ic) return "";
                            if (ic.startsWith("file://") || ic.startsWith("image://") || ic.startsWith("http://") || ic.startsWith("https://")) return ic;
                            return ic.startsWith("/") ? "file://" + ic : "image://icon/" + ic;
                        }
                        sourceSize: Qt.size(96, 96)
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        visible: status === Image.Ready && source !== ""
                    }

                    Image {
                        id: appIconFallback
                        anchors.fill: parent
                        anchors.margins: 8
                        asynchronous: true
                        visible: !toastImg.visible && status === Image.Ready && source !== ""
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        source: {
                            if (toastImg.visible) return "";
                            let entry = delegateRoot.modelData.desktopEntry;
                            let appId = entry && entry.id ? entry.id : (delegateRoot.modelData.groupKey || delegateRoot.modelData.appName || "");
                            return appId ? "image://icon/" + appId : "";
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !toastImg.visible && !appIconFallback.visible
                        text: {
                            let name = (delegateRoot.modelData.appName && delegateRoot.modelData.appName.length) ? delegateRoot.modelData.appName : "?";
                            return name.charAt(0).toUpperCase();
                        }
                        color: delegateRoot.critical ? MatugenColors.error : MatugenColors.accent
                        font.pixelSize: 16
                        font.bold: true
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

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

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

                        Text {
                            text: delegateRoot.timeText
                            color: MatugenColors.textDim
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }
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
                        maximumLineCount: delegateRoot.canExpand
                            ? (2 + Math.round(delegateRoot.expandProgress * 8))
                            : 2
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        id: actionsRow
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        spacing: 6
                        visible: delegateRoot.hasActions && delegateRoot.expandProgress > 0.05
                        opacity: delegateRoot.expandProgress
                        clip: true

                        Repeater {
                            model: delegateRoot.modelData.actions || []
                            delegate: Rectangle {
                                required property var modelData
                                radius: 6
                                color: MatugenColors.bgElevated
                                border.width: 1
                                border.color: MatugenColors.borderSoft
                                implicitHeight: actionLabel.implicitHeight + 10
                                implicitWidth: actionLabel.implicitWidth + 16

                                Text {
                                    id: actionLabel
                                    anchors.centerIn: parent
                                    text: modelData.text || modelData.label || ""
                                    color: MatugenColors.text
                                    font.pixelSize: 11
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.invoke) modelData.invoke();
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
