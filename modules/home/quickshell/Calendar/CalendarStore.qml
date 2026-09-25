pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Single source of truth for calendar events.
//
// Lives in Singletons/ on purpose: Calendar.qml is instantiated twice (once for
// the horizontal bar, once for the vertical bar), so keeping the store inside
// the module meant two FileViews fighting over the same file and two reminder
// timers firing duplicate notifications.
//
// Storage moved to ~/.local/state/quickshell/ because ~/.config/quickshell is a
// read only nix store symlink under home-manager, which is why saves silently
// vanished. Old files at the previous location are imported once on first load.
Item {
    id: store

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string stateDir: homeDir + "/.local/state/quickshell"
    readonly property string storePath: stateDir + "/calendar-events.json"
    readonly property string legacyPath: homeDir + "/.config/quickshell/Calendar/calendar-events.json"

    readonly property var eventColors: [
        "#f87171", "#fb923c", "#fbbf24", "#a3e635",
        "#34d399", "#22d3ee", "#60a5fa", "#a78bfa", "#f472b6"
    ]

    readonly property var dayNames: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    readonly property var dayInitials: ["S", "M", "T", "W", "T", "F", "S"]

    property var events: []
    property bool loaded: false

    // eventId@occurrenceKey#unit:amount -> timestamp it was delivered
    property var firedKeys: ({})
    property bool notificationsEnabled: true

    // How late an alert may be and still be shown. Anything older is marked as
    // seen without a popup so a shell restart never dumps a pile of stale alerts.
    readonly property int lateGraceMs: 15 * 60 * 1000

    // ---------------------------------------------------------------- dates --

    function _pad2(n) { return n < 10 ? "0" + n : "" + n }

    function key(y, monthIndex, day) {
        return y + "-" + _pad2(monthIndex + 1) + "-" + _pad2(day)
    }

    function keyFromDate(d) {
        return key(d.getFullYear(), d.getMonth(), d.getDate())
    }

    function dateFromKey(k) {
        var p = (k || "").split("-")
        if (p.length !== 3) return new Date()
        return new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]))
    }

    function todayKey() { return keyFromDate(new Date()) }

    function cmp(a, b) { return a < b ? -1 : (a > b ? 1 : 0) }

    function daysInMonth(y, monthIndex) {
        return new Date(y, monthIndex + 1, 0).getDate()
    }

    function diffDays(fromKey, toKey) {
        var a = dateFromKey(fromKey).getTime()
        var b = dateFromKey(toKey).getTime()
        return Math.round((b - a) / 86400000)
    }

    function addDays(k, n) {
        var d = dateFromKey(k)
        d.setDate(d.getDate() + n)
        return keyFromDate(d)
    }

    function formatKeyShort(k) {
        if (!k) return ""
        var d = dateFromKey(k)
        return Qt.locale().standaloneMonthName(d.getMonth(), Locale.ShortFormat) + " " + d.getDate()
    }

    function formatKeyLong(k) {
        if (!k) return ""
        var d = dateFromKey(k)
        return Qt.locale().dayName(d.getDay(), Locale.LongFormat) + ", "
             + Qt.locale().standaloneMonthName(d.getMonth(), Locale.LongFormat) + " " + d.getDate()
    }

    function use24h() {
        try { return Config.clock24h === true } catch (e) { return false }
    }

    function minToTime(min) {
        if (min === undefined || min === null) return ""
        var h = Math.floor(min / 60) % 24
        var m = ((min % 60) + 60) % 60
        var mm = _pad2(m)
        if (use24h()) return _pad2(h) + ":" + mm
        var ap = h >= 12 ? "PM" : "AM"
        var h12 = (h % 12 === 0) ? 12 : (h % 12)
        return h12 + ":" + mm + " " + ap
    }

    // ------------------------------------------------------------ recurrence --

    function _rep(ev) {
        var r = ev && ev.repeat ? ev.repeat : null
        return {
            freq: r && r.freq ? r.freq : "none",
            every: r && r.every ? Math.max(1, r.every) : 1,
            days: r && r.days ? r.days : [],
            endMode: r && r.endMode ? r.endMode : "never",
            endDate: r && r.endDate ? r.endDate : "",
            count: r && r.count ? Math.max(1, r.count) : 10,
            custom: !!(r && r.custom)
        }
    }

    function isRepeating(ev) {
        return _rep(ev).freq !== "none"
    }

    // Next occurrence start strictly after fromKey. Steps by frequency instead
    // of walking days so yearly rules stay cheap.
    function nextOccurrence(ev, fromKey) {
        var rep = _rep(ev)
        var start = dateFromKey(ev.startDate)
        var d = dateFromKey(fromKey)

        if (rep.freq === "daily") {
            d.setDate(d.getDate() + rep.every)
            return keyFromDate(d)
        }

        if (rep.freq === "weekly") {
            var days = (rep.days && rep.days.length > 0)
                ? rep.days.slice().sort(function (a, b) { return a - b })
                : [start.getDay()]
            var cur = d.getDay()
            for (var i = 0; i < days.length; i++) {
                if (days[i] > cur) {
                    var sameWeek = dateFromKey(fromKey)
                    sameWeek.setDate(sameWeek.getDate() + (days[i] - cur))
                    return keyFromDate(sameWeek)
                }
            }
            var jump = dateFromKey(fromKey)
            jump.setDate(jump.getDate() - cur + 7 * rep.every + days[0])
            return keyFromDate(jump)
        }

        if (rep.freq === "monthly") {
            var dom = start.getDate()
            var y = d.getFullYear()
            var m = d.getMonth()
            for (var k = 0; k < 240; k++) {
                m += rep.every
                while (m > 11) { m -= 12; y += 1 }
                if (daysInMonth(y, m) >= dom) return key(y, m, dom)
            }
            return ""
        }

        if (rep.freq === "yearly") {
            var yy = d.getFullYear() + rep.every
            for (var j = 0; j < 40; j++) {
                if (daysInMonth(yy, start.getMonth()) >= start.getDate())
                    return key(yy, start.getMonth(), start.getDate())
                yy += rep.every
            }
            return ""
        }

        return ""
    }

    // A weekly rule can start on a day that is not in its own weekday set, so
    // the first real occurrence is not always the start date.
    function firstOccurrence(ev) {
        var rep = _rep(ev)
        if (rep.freq !== "weekly") return ev.startDate
        if (!rep.days || rep.days.length === 0) return ev.startDate
        var d = dateFromKey(ev.startDate)
        if (rep.days.indexOf(d.getDay()) !== -1) return ev.startDate
        for (var i = 1; i <= 7; i++) {
            var nd = dateFromKey(ev.startDate)
            nd.setDate(nd.getDate() + i)
            if (rep.days.indexOf(nd.getDay()) !== -1) return keyFromDate(nd)
        }
        return ev.startDate
    }

    property var _endCache: ({})

    function _endSignature(ev) {
        return ev.id + "|" + ev.startDate + "|" + JSON.stringify(ev.repeat || {})
    }

    // "" means the series never ends.
    function seriesEndKey(ev) {
        var rep = _rep(ev)
        if (rep.freq === "none") return ev.startDate
        if (rep.endMode === "never") return ""
        if (rep.endMode === "on") return rep.endDate || ""

        var sig = _endSignature(ev)
        if (store._endCache[sig] !== undefined) return store._endCache[sig]

        var k = firstOccurrence(ev)
        var n = 1
        var guard = 0
        while (n < rep.count && guard < 4000) {
            var nk = nextOccurrence(ev, k)
            if (nk === "") break
            k = nk
            n += 1
            guard += 1
        }
        store._endCache[sig] = k
        return k
    }

    // Does an occurrence of ev *start* on dateKey?
    function occursOn(ev, dateKey) {
        if (!ev || !ev.startDate) return false
        if (cmp(dateKey, ev.startDate) < 0) return false

        var rep = _rep(ev)
        if (rep.freq === "none") return dateKey === ev.startDate

        var endK = seriesEndKey(ev)
        if (endK !== "" && cmp(dateKey, endK) > 0) return false

        var s = dateFromKey(ev.startDate)
        var d = dateFromKey(dateKey)

        if (rep.freq === "daily")
            return diffDays(ev.startDate, dateKey) % rep.every === 0

        if (rep.freq === "weekly") {
            var days = (rep.days && rep.days.length > 0) ? rep.days : [s.getDay()]
            if (days.indexOf(d.getDay()) === -1) return false
            var sWeek = dateFromKey(ev.startDate)
            sWeek.setDate(sWeek.getDate() - sWeek.getDay())
            var dWeek = dateFromKey(dateKey)
            dWeek.setDate(dWeek.getDate() - dWeek.getDay())
            var weeks = Math.round(diffDays(keyFromDate(sWeek), keyFromDate(dWeek)) / 7)
            return weeks >= 0 && weeks % rep.every === 0
        }

        if (rep.freq === "monthly") {
            if (d.getDate() !== s.getDate()) return false
            var md = (d.getFullYear() - s.getFullYear()) * 12 + (d.getMonth() - s.getMonth())
            return md >= 0 && md % rep.every === 0
        }

        if (rep.freq === "yearly") {
            if (d.getDate() !== s.getDate() || d.getMonth() !== s.getMonth()) return false
            var yd = d.getFullYear() - s.getFullYear()
            return yd >= 0 && yd % rep.every === 0
        }

        return false
    }

    function repeatSummary(rep, startKey) {
        if (!rep || !rep.freq || rep.freq === "none") return "Never"
        var every = Math.max(1, rep.every || 1)
        var out = ""

        if (rep.freq === "daily")
            out = every === 1 ? "Every day" : ("Every " + every + " days")
        else if (rep.freq === "weekly") {
            out = every === 1 ? "Every week" : ("Every " + every + " weeks")
            var days = (rep.days && rep.days.length > 0)
                ? rep.days.slice().sort(function (a, b) { return a - b })
                : (startKey ? [dateFromKey(startKey).getDay()] : [])
            if (days.length > 0) {
                var names = []
                for (var i = 0; i < days.length; i++) names.push(store.dayNames[days[i]])
                out += " on " + names.join(", ")
            }
        }
        else if (rep.freq === "monthly")
            out = every === 1 ? "Every month" : ("Every " + every + " months")
        else if (rep.freq === "yearly")
            out = every === 1 ? "Every year" : ("Every " + every + " years")

        var mode = rep.endMode || "never"
        if (mode === "on" && rep.endDate) out += ", until " + formatKeyShort(rep.endDate)
        else if (mode === "after") out += ", " + Math.max(1, rep.count || 1) + " times"
        return out
    }

    // --------------------------------------------------------------- lookup --

    function spanDays(ev) {
        return Math.max(0, Math.min(366, diffDays(ev.startDate, ev.endDate || ev.startDate)))
    }

    // Every occurrence that covers dateKey, expanded from the repeat rule.
    function eventsForDate(dateKey) {
        var out = []
        if (!dateKey) return out
        var list = store.events
        for (var i = 0; i < list.length; i++) {
            var ev = list[i]
            var span = spanDays(ev)
            for (var off = 0; off <= span; off++) {
                var occStart = off === 0 ? dateKey : addDays(dateKey, -off)
                if (!occursOn(ev, occStart)) continue
                var occEnd = span === 0 ? occStart : addDays(occStart, span)
                var inst = Object.assign({}, ev)
                inst.occStart = occStart
                inst.occEnd = occEnd
                inst.repeating = isRepeating(ev)
                inst.rangePos = span === 0 ? "single"
                    : (dateKey === occStart ? "start" : (dateKey === occEnd ? "end" : "middle"))
                out.push(inst)
                break
            }
        }
        out.sort(function (a, b) {
            if (a.allDay !== b.allDay) return a.allDay ? -1 : 1
            if (a.startMin !== b.startMin) return a.startMin - b.startMin
            return a.title < b.title ? -1 : 1
        })
        return out
    }

    function hasEvents(dateKey) {
        return eventsForDate(dateKey).length > 0
    }

    // dateKey -> up to three distinct colors, for the dots under day numbers.
    function colorMap(fromKey, toKey) {
        var map = ({})
        var k = fromKey
        var guard = 0
        while (cmp(k, toKey) <= 0 && guard < 200) {
            var list = eventsForDate(k)
            if (list.length > 0) {
                var cols = []
                for (var i = 0; i < list.length && cols.length < 3; i++) {
                    if (cols.indexOf(list[i].color) === -1) cols.push(list[i].color)
                }
                map[k] = cols
            }
            k = addDays(k, 1)
            guard += 1
        }
        return map
    }

    function eventById(id) {
        for (var i = 0; i < store.events.length; i++)
            if (store.events[i].id === id) return store.events[i]
        return null
    }

    // Next upcoming occurrence from today, used for the bar tooltip / summary.
    function nextUpcoming() {
        var now = new Date()
        var k = keyFromDate(now)
        var nowMin = now.getHours() * 60 + now.getMinutes()
        for (var d = 0; d < 60; d++) {
            var list = eventsForDate(k)
            for (var i = 0; i < list.length; i++) {
                var ev = list[i]
                if (d === 0 && !ev.allDay && ev.endMin < nowMin) continue
                return ev
            }
            k = addDays(k, 1)
        }
        return null
    }

    // ------------------------------------------------------------- mutation --

    function _uid() {
        return "ev_" + Date.now() + "_" + Math.floor(Math.random() * 100000)
    }

    function _normalize(payload, base) {
        var ev = base ? Object.assign({}, base) : {}
        ev.id = ev.id || _uid()
        ev.title = (payload.title !== undefined ? payload.title : ev.title) || "Untitled"
        ev.allDay = payload.allDay !== undefined ? !!payload.allDay : !!ev.allDay
        ev.startDate = payload.startDate || ev.startDate || todayKey()
        ev.endDate = payload.endDate || ev.endDate || ev.startDate
        ev.startMin = payload.startMin !== undefined ? payload.startMin : (ev.startMin !== undefined ? ev.startMin : 9 * 60)
        ev.endMin = payload.endMin !== undefined ? payload.endMin : (ev.endMin !== undefined ? ev.endMin : 10 * 60)
        ev.color = payload.color || ev.color || store.eventColors[0]
        ev.notes = payload.notes !== undefined ? payload.notes : (ev.notes || "")
        ev.travelTime = payload.travelTime !== undefined ? payload.travelTime : (ev.travelTime || 0)
        ev.reminders = (payload.reminders !== undefined ? payload.reminders : (ev.reminders || [])).slice(0, 10)
        ev.repeat = payload.repeat !== undefined ? payload.repeat : (ev.repeat || { freq: "none" })

        if (cmp(ev.endDate, ev.startDate) < 0) ev.endDate = ev.startDate
        if (!ev.allDay && ev.startDate === ev.endDate && ev.endMin <= ev.startMin)
            ev.endMin = Math.min(24 * 60 - 1, ev.startMin + 60)
        return ev
    }

    function addEvent(payload) {
        var ev = _normalize(payload, null)
        var list = store.events.slice()
        list.push(ev)
        store.events = list
        store._endCache = ({})
        _persist()
        primeEvent(ev)
        return ev.id
    }

    function updateEvent(id, payload) {
        var list = store.events.slice()
        var updated = null
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                updated = _normalize(payload, list[i])
                list[i] = updated
                break
            }
        }
        store.events = list
        store._endCache = ({})
        _persist()
        if (updated) primeEvent(updated)
    }

    function removeEvent(id) {
        store.events = store.events.filter(function (e) { return e.id !== id })
        store._endCache = ({})
        var keep = ({})
        for (var k in store.firedKeys) {
            if (k.indexOf(id + "@") !== 0) keep[k] = store.firedKeys[k]
        }
        store.firedKeys = keep
        _persist()
    }

    // -------------------------------------------------------------- storage --

    Process {
        id: loadProc
        command: ["bash", "-c",
            "cat '" + store.storePath + "' 2>/dev/null || cat '" + store.legacyPath + "' 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: store._applyRaw(this.text)
        }
    }

    Component.onCompleted: loadProc.running = true

    function _applyRaw(raw) {
        try {
            var data = JSON.parse(raw && raw.trim().length > 0 ? raw : "{}")
            if (data && Array.isArray(data.events)) {
                var clean = []
                for (var i = 0; i < data.events.length; i++) {
                    var ev = data.events[i]
                    if (ev && ev.id && ev.startDate) clean.push(_normalize(ev, ev))
                }
                store.events = clean
            }
            if (data && data.fired && typeof data.fired === "object")
                store.firedKeys = _pruneFired(data.fired)
        } catch (e) {
            store.events = []
        }
        store.loaded = true
        store._endCache = ({})
        primeAll()
        reminderTick.start()
        checkReminders()
    }

    function _pruneFired(map) {
        var cutoff = Date.now() - 30 * 24 * 60 * 60 * 1000
        var out = ({})
        for (var k in map) {
            var t = map[k]
            if (typeof t === "number" && t > cutoff) out[k] = t
        }
        return out
    }

    Timer {
        id: saveDebounce
        interval: 200
        onTriggered: store._writeNow()
    }

    function _persist() {
        if (!store.loaded) return
        saveDebounce.restart()
    }

    function _writeNow() {
        if (!store.loaded) return
        var json = JSON.stringify({
            version: 2,
            events: store.events,
            fired: store.firedKeys
        }, null, 2)

        Quickshell.execDetached(["bash", "-c",
            "mkdir -p '" + store.stateDir + "' && cat > '" + store.storePath + ".tmp' << 'CALEOF'\n"
            + json
            + "\nCALEOF\nmv '" + store.storePath + ".tmp' '" + store.storePath + "'"])
    }

    // ------------------------------------------------------------- reminders --

    function occurrenceStartDate(ev, occKey) {
        var d = dateFromKey(occKey)
        if (ev.allDay) d.setHours(9, 0, 0, 0)
        else d.setHours(Math.floor(ev.startMin / 60), ev.startMin % 60, 0, 0)
        return d
    }

    function reminderTimeMs(ev, occKey, rem) {
        var ms = occurrenceStartDate(ev, occKey).getTime()
        ms -= Math.max(0, ev.travelTime || 0) * 60000
        var amount = Math.max(0, rem.amount || 0)
        switch (rem.unit) {
            case "minutes": ms -= amount * 60000; break
            case "hours":   ms -= amount * 3600000; break
            case "days":    ms -= amount * 86400000; break
            case "weeks":   ms -= amount * 7 * 86400000; break
        }
        return ms
    }

    function _fireKey(ev, occKey, rem) {
        return ev.id + "@" + occKey + "#" + rem.unit + ":" + rem.amount
    }

    function reminderLabel(rem, allDay) {
        var a = rem.amount || 0
        if (a === 0) return allDay ? "Today" : "Now"
        if (rem.unit === "minutes") return "In " + a + " minute" + (a === 1 ? "" : "s")
        if (rem.unit === "hours") return "In " + a + " hour" + (a === 1 ? "" : "s")
        if (rem.unit === "days") return "In " + a + " day" + (a === 1 ? "" : "s")
        if (rem.unit === "weeks") return "In " + a + " week" + (a === 1 ? "" : "s")
        return ""
    }

    function _alertBody(ev, occKey, rem) {
        var when = ""
        if (ev.allDay) {
            when = (rem.amount || 0) === 0
                ? "All day today"
                : reminderLabel(rem, true) + ", all day on " + formatKeyShort(occKey)
        } else {
            var range = minToTime(ev.startMin) + " to " + minToTime(ev.endMin)
            var lead = reminderLabel(rem, false)
            when = (rem.amount || 0) === 0 ? ("Starting now, " + range) : (lead + ", " + range)
            if (occKey !== todayKey()) when += " on " + formatKeyShort(occKey)
        }
        var notes = (ev.notes || "").trim()
        if (notes.length > 0) when += "\n" + notes.split("\n")[0]
        return when
    }

    function _notify(ev, occKey, rem) {
        var summary = ev.title
        var body = _alertBody(ev, occKey, rem)
        var sent = false
        try {
            if (typeof Notifs !== "undefined" && Notifs && Notifs.sendLocal) {
                Notifs.sendLocal(summary, body, "Calendar", "calendar")
                sent = true
            }
        } catch (e) {
            sent = false
        }
        if (!sent) {
            Quickshell.execDetached(["notify-send", "-a", "Calendar", "-i", "calendar", summary, body])
        }
    }

    Timer {
        id: reminderTick
        interval: 20000
        repeat: true
        running: false
        onTriggered: store.checkReminders()
    }

    // Walk a window around today so week long lead times still land.
    function _forEachPendingReminder(cb) {
        var todayK = todayKey()
        var fromK = addDays(todayK, -9)
        var toK = addDays(todayK, 9)

        for (var i = 0; i < store.events.length; i++) {
            var ev = store.events[i]
            var rems = ev.reminders || []
            if (rems.length === 0) continue

            var k = fromK
            var guard = 0
            while (cmp(k, toK) <= 0 && guard < 40) {
                if (occursOn(ev, k)) {
                    for (var r = 0; r < rems.length; r++) cb(ev, k, rems[r])
                }
                k = addDays(k, 1)
                guard += 1
            }
        }
    }

    // Mark everything already in the past as delivered, without popping it.
    function primeAll() {
        var now = Date.now()
        var map = Object.assign({}, store.firedKeys)
        var dirty = false
        _forEachPendingReminder(function (ev, occKey, rem) {
            var fk = _fireKey(ev, occKey, rem)
            if (map[fk] !== undefined) return
            var t = reminderTimeMs(ev, occKey, rem)
            if (t <= now - store.lateGraceMs) { map[fk] = now; dirty = true }
        })
        if (dirty) { store.firedKeys = map; _persist() }
    }

    // Same idea for a single event that was just created or edited: an alert
    // whose time already passed should not pop the instant you hit Save.
    function primeEvent(ev) {
        if (!ev || !ev.reminders || ev.reminders.length === 0) return
        var now = Date.now()
        var map = Object.assign({}, store.firedKeys)
        var dirty = false
        var todayK = todayKey()
        var k = addDays(todayK, -9)
        var guard = 0
        while (cmp(k, addDays(todayK, 9)) <= 0 && guard < 40) {
            if (occursOn(ev, k)) {
                for (var r = 0; r < ev.reminders.length; r++) {
                    var rem = ev.reminders[r]
                    var fk = _fireKey(ev, k, rem)
                    if (map[fk] === undefined && reminderTimeMs(ev, k, rem) <= now) {
                        map[fk] = now
                        dirty = true
                    }
                }
            }
            k = addDays(k, 1)
            guard += 1
        }
        if (dirty) { store.firedKeys = map; _persist() }
    }

    function checkReminders() {
        if (!store.loaded || !store.notificationsEnabled) return
        var now = Date.now()
        var map = Object.assign({}, store.firedKeys)
        var dirty = false
        var due = []

        _forEachPendingReminder(function (ev, occKey, rem) {
            var fk = _fireKey(ev, occKey, rem)
            if (map[fk] !== undefined) return
            var t = reminderTimeMs(ev, occKey, rem)
            if (t > now) return
            map[fk] = now
            dirty = true
            if (now - t <= store.lateGraceMs) due.push({ ev: ev, occ: occKey, rem: rem })
        })

        if (dirty) {
            store.firedKeys = map
            _persist()
        }
        for (var i = 0; i < due.length; i++)
            _notify(due[i].ev, due[i].occ, due[i].rem)
    }

    // Lets you verify the alert pipeline without waiting for a real event.
    function testAlert() {
        var now = new Date()
        _notify({
            title: "Calendar alert test",
            allDay: false,
            startMin: now.getHours() * 60 + now.getMinutes(),
            endMin: now.getHours() * 60 + now.getMinutes() + 60,
            notes: ""
        }, todayKey(), { amount: 0, unit: "minutes" })
    }
}
