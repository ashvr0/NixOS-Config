pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: notifs

    property bool silent: false
    property var popups: []
    property var history: []
    property int _uidCounter: 0

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        imageSupported: true

        onNotification: notification => {
            notification.tracked = true
            notifs._uidCounter++

            let extractedActions = []
            for (const a of (notification.actions || [])) {
                extractedActions.push({ id: a.identifier, text: a.text })
            }

            const entry = {
                uid: notifs._uidCounter,
                appName: notification.appName || "System",
                summary: notification.summary || "",
                body: notification.body || "",
                appIcon: notification.appIcon || "",
                image: notification.image || "",
                urgency: notification.urgency,
                actions: extractedActions,
                notification: notification,
                timestamp: Date.now(),
                read: false
            }

            notifs.history = [entry].concat(notifs.history)

            if (!notifs.silent) {
                notifs.popups = notifs.popups.concat([entry])
                popupExpire(entry)
            }
        }
    }

    // Power menu reads from these. Entries are grouped by app (groupKey falls
    // back to appName) so multiple notifications from the same app collapse
    // into one card with an expandable list, newest group first.
    readonly property var groups: {
        let order = []
        let byKey = {}
        for (const entry of notifs.history) {
            const key = entry.groupKey || entry.appName || "unknown"
            if (!byKey[key]) {
                byKey[key] = { key: key, newest: entry, all: [] }
                order.push(key)
            }
            byKey[key].all.push(entry)
        }
        return order.map(key => byKey[key])
    }

    function removePopup(entry) {
        notifs.popups = notifs.popups.filter(e => e !== entry)
    }

    function markAsRead(uid) {
        if (uid === undefined) return

        notifs.popups = notifs.popups.map(e => {
            if (e.uid === uid && !e.read) {
                return Object.assign({}, e, { read: true })
            }
            return e
        })

        notifs.history = notifs.history.map(e => {
            if (e.uid === uid && !e.read) {
                return Object.assign({}, e, { read: true })
            }
            return e
        })
    }

    function popupExpire(entry) {
        let t = Qt.createQmlObject(
            'import QtQuick; Timer { interval: 6000; running: true; repeat: false }',
            notifs
        )
        t.triggered.connect(() => {
            notifs.removePopup(entry)
            t.destroy()
        })
    }

    function sendTestNotification() {
        notifs._uidCounter++
        const entry = {
            uid: notifs._uidCounter,
            appName: "Notifications",
            summary: "Test notification",
            body: "This is what your notifications look like.",
            appIcon: "",
            image: "",
            urgency: NotificationUrgency.Normal,
            actions: [],
            notification: null,
            timestamp: Date.now(),
            read: false
        }
        notifs.history = [entry].concat(notifs.history)
        if (!notifs.silent) {
            notifs.popups = notifs.popups.concat([entry])
            popupExpire(entry)
        }
    }

    function clearHistory() {
        notifs.history = []
    }

    function dismissGroup(group) {
        if (!group) return
        const uids = new Set((group.all || [group.newest]).map(e => e.uid))
        notifs.history = notifs.history.filter(e => !uids.has(e.uid))
        for (const e of (group.all || [group.newest])) {
            notifs.removePopup(e)
        }
    }

    function dismissEntry(entry) {
        if (!entry) return
        notifs.history = notifs.history.filter(e => e.uid !== entry.uid)
        notifs.removePopup(entry)
    }
}
