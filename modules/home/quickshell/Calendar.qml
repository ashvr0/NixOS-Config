import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: root

IpcHandler {
    target: "calendar"
    function toggle(): void {
      calPopup.toggle()
    }
  }

component TextField : Rectangle {
  id: field
  radius: 8
  color: MatugenColors.bgElevated
  border.width: focus ? 1 : 0
  border.color: MatugenColors.accent

  property string text: ""
  property string placeholderText: ""

  TextInput {
    id: input
    anchors.fill: parent
    anchors.margins: s(8)
    verticalAlignment: TextInput.AlignVCenter
    font.pixelSize: s(11)
    font.family: "JetBrainsMono Nerd Font"
    color: MatugenColors.text
    clip: true
    text: field.text

    Text {
      anchors.fill: parent
      verticalAlignment: Text.AlignVCenter
      text: field.placeholderText
      color: MatugenColors.textMuted
      font.pixelSize: s(11)
      font.family: "JetBrainsMono Nerd Font"
      visible: field.text.length === 0
    }

    onTextEdited: field.text = text
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.IBeamCursor
    onClicked: input.forceActiveFocus()
  }
}

component AlertField : Item {
  id: root

  property string label: ""
  property bool allDay: false
  property var reminder: null
  property var usedKeys: []

  signal reminderEdited(var reminder)

  readonly property bool active: reminder !== null
  readonly property var allOptions: allDay ? [
    { key: "none",   text: "None",              amount: 0,  unit: "days" },
    { key: "atstart", text: "At start of day",  amount: 0,  unit: "days" },
    { key: "d1",     text: "1 day before",       amount: 1,  unit: "days" },
    { key: "d2",     text: "2 days before",      amount: 2,  unit: "days" },
    { key: "w1",     text: "1 week before",      amount: 1,  unit: "weeks" }
  ] : [
    { key: "none",   text: "None",               amount: 0,  unit: "minutes" },
    { key: "atstart", text: "At time of event",  amount: 0,  unit: "minutes" },
    { key: "m5",     text: "5 minutes before",    amount: 5,  unit: "minutes" },
    { key: "m10",    text: "10 minutes before",   amount: 10, unit: "minutes" },
    { key: "m15",    text: "15 minutes before",   amount: 15, unit: "minutes" },
    { key: "m30",    text: "30 minutes before",   amount: 30, unit: "minutes" },
    { key: "h1",     text: "1 hour before",       amount: 1,  unit: "hours" },
    { key: "h2",     text: "2 hours before",      amount: 2,  unit: "hours" },
    { key: "d1",     text: "1 day before",        amount: 1,  unit: "days" },
    { key: "d2",     text: "2 days before",       amount: 2,  unit: "days" }
  ]

  function keyFor(o) { return o.unit + ":" + o.amount }

  readonly property string myKey: root.active ? keyFor(root.reminder) : ""

  readonly property var options: {
    var out = []
    for (var i = 0; i < allOptions.length; i++) {
      var o = allOptions[i]
      if (o.key === "none") { out.push(o); continue }
      var k = keyFor(o)
      if (k === root.myKey || root.usedKeys.indexOf(k) === -1) out.push(o)
    }
    return out
  }

  function matchIndex() {
    if (!root.active) return 0
    for (var i = 0; i < options.length; i++) {
      var o = options[i]
      if (o.key === "none") continue
      if (o.amount === root.reminder.amount && o.unit === root.reminder.unit) return i
    }
    return 0
  }

  readonly property string currentText: {
    if (!root.active) return "None"
    var idx = matchIndex()
    return options[idx].text
  }

  width: parent ? parent.width : 200
  height: 34
  z: expanded ? 1000 : 1
  clip: false

  property bool expanded: false

  Rectangle {
    id: fieldBg
    width: parent.width
    height: 34
    radius: 8
    color: MatugenColors.bgElevated
    border.width: root.expanded ? 1 : 0
    border.color: MatugenColors.accent

    Row {
      anchors.left: parent.left
      anchors.right: caret.left
      anchors.leftMargin: 10
      anchors.rightMargin: 6
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6

      Text {
        text: root.label
        color: MatugenColors.textMuted
        font.pixelSize: s(10)
        font.family: "JetBrainsMono Nerd Font"
      }

      Text {
        text: root.currentText
        color: MatugenColors.text
        font.pixelSize: s(11)
        font.family: "JetBrainsMono Nerd Font"
        elide: Text.ElideRight
      }
    }

    Text {
      id: caret
      anchors.right: parent.right
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      text: root.expanded ? "▲" : "▼"
      color: MatugenColors.textMuted
      font.pixelSize: s(8)
      font.family: "JetBrainsMono Nerd Font"
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.expanded = !root.expanded
      }
    }
  }

  MouseArea {
    id: scrim
    parent: calPopup.contentItem
    anchors.fill: parent
    visible: root.expanded
    z: 999
    onClicked: { root.expanded = false }
  }

  Rectangle {
    id: dropdown
    parent: calPopup.contentItem
    x: { var p = root.mapToItem(calPopup.contentItem, 0, 34 + 4); return root.x, root.y, p.x }
    y: { var p = root.mapToItem(calPopup.contentItem, 0, 34 + 4); return root.x, root.y, p.y }
    width: root.width
    height: optCol.implicitHeight + 8
    radius: 8
    color: MatugenColors.bgElevated2
    border.width: 1
    border.color: MatugenColors.borderSoft
    visible: root.expanded
    z: 1000
    clip: true

    Column {
      id: optCol
      width: parent.width
      anchors.margins: 4
      anchors.fill: parent
      spacing: 1

      Repeater {
        model: root.options
        Rectangle {
          required property var modelData
          required property int index
          width: parent.width
          height: 26
          radius: 5
          color: optHover.containsMouse ? MatugenColors.bgElevated : "transparent"

          Text {
            anchors.left: parent.left
            anchors.leftMargin: s(8)
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.text
            color: MatugenColors.text
            font.pixelSize: s(10)
            font.family: "JetBrainsMono Nerd Font"
          }

          MouseArea {
            id: optHover
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (modelData.key === "none") {
                root.reminderEdited(null)
              } else {
                root.reminderEdited({ amount: modelData.amount, unit: modelData.unit })
              }
              root.expanded = false
            }
          }
        }
      }
    }
  }
}

component Slider2 : Item {
  id: slider
  property real value: 0
  property real minVal: 0
  property real maxVal: 255
  signal moved(real v)

  height: s(14)

  Rectangle {
    id: track
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    height: s(4); radius: s(2)
    color: MatugenColors.bgElevated
  }

  Rectangle {
    width: Math.max(s(4), track.width * (slider.value - slider.minVal) / (slider.maxVal - slider.minVal))
    height: s(4); radius: s(2)
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    color: MatugenColors.accent
  }

  Rectangle {
    width: s(12); height: s(12); radius: s(6)
    anchors.verticalCenter: parent.verticalCenter
    x: Math.max(0, Math.min(track.width - width, track.width * (slider.value - slider.minVal) / (slider.maxVal - slider.minVal) - width / 2))
    color: MatugenColors.text
  }

  MouseArea {
    anchors.fill: parent
    onPositionChanged: function(mouse) {
      if (pressed) {
        var frac = Math.max(0, Math.min(1, mouse.x / width))
        slider.moved(slider.minVal + frac * (slider.maxVal - slider.minVal))
      }
    }
    onPressed: function(mouse) {
      var frac = Math.max(0, Math.min(1, mouse.x / width))
      slider.moved(slider.minVal + frac * (slider.maxVal - slider.minVal))
    }
  }
}

component SegmentInput : Rectangle {
  id: seg
  property string display: ""
  property int minVal: 0
  property int maxVal: 99
  property int padLen: 2
  signal committed(int value)
  signal wheeled(int direction)

  width: segInput.implicitWidth + 10
  height: s(24)
  radius: s(4)
  color: segInput.activeFocus ? MatugenColors.bgElevated2 : (segHover.containsMouse ? MatugenColors.bgElevated2 : "transparent")
  border.width: segInput.activeFocus ? 1 : 0
  border.color: MatugenColors.accent

  TextInput {
    id: segInput
    anchors.centerIn: parent
    text: seg.display
    color: MatugenColors.text
    font.pixelSize: s(11)
    font.family: "JetBrainsMono Nerd Font"
    font.features: ({ "tnum": 1 })
    validator: IntValidator { bottom: 0; top: 9999 }
    selectByMouse: true
    horizontalAlignment: TextInput.AlignHCenter
    inputMethodHints: Qt.ImhDigitsOnly

    property string editBuffer: ""
    property bool editingNow: false

    onTextChanged: {
      if (!activeFocus) return
      if (!editingNow) { editingNow = true; editBuffer = "" }
    }

    onActiveFocusChanged: {
      if (activeFocus) {
        editingNow = true
        editBuffer = ""
        selectAll()
      } else {
        if (editingNow && editBuffer.length > 0) {
          var v = parseInt(editBuffer)
          if (!isNaN(v)) seg.committed(Math.max(seg.minVal, Math.min(seg.maxVal, v)))
        }
        editingNow = false
        text = seg.display
      }
    }

    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Up) {
        seg.wheeled(1)
        event.accepted = true
      } else if (event.key === Qt.Key_Down) {
        seg.wheeled(-1)
        event.accepted = true
      } else if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
        var digit = event.text
        editBuffer = (editBuffer.length >= seg.padLen) ? digit : editBuffer + digit
        text = editBuffer
        event.accepted = true
        if (editBuffer.length >= seg.padLen) {
          var v = parseInt(editBuffer)
          seg.committed(Math.max(seg.minVal, Math.min(seg.maxVal, v)))
          segInput.focus = false
          seg.forceActiveFocus()
        }
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Tab) {
        if (editBuffer.length > 0) {
          var vv = parseInt(editBuffer)
          if (!isNaN(vv)) seg.committed(Math.max(seg.minVal, Math.min(seg.maxVal, vv)))
        }
        editingNow = false
        event.accepted = event.key !== Qt.Key_Tab
        if (event.key !== Qt.Key_Tab) { segInput.focus = false; seg.forceActiveFocus() }
      } else if (event.key === Qt.Key_Escape) {
        editingNow = false
        text = seg.display
        segInput.focus = false
        seg.forceActiveFocus()
        event.accepted = true
      }
    }
  }

  MouseArea {
    id: segHover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.IBeamCursor
    acceptedButtons: Qt.LeftButton
    onClicked: segInput.forceActiveFocus()
    onWheel: function(wheel) {
      seg.wheeled(wheel.angleDelta.y > 0 ? 1 : -1)
    }
  }
}


component DateTimeField : Item {
  id: root

  property string dateKey: ""
  property int minutes: 0 
  property bool showTime: true

  signal dateKeyEdited(string newKey)
  signal minutesEdited(int newMinutes)

  readonly property var _parts: dateKey !== "" ? dateKey.split("-") : ["2024", "01", "01"]
  readonly property int _year: parseInt(_parts[0])
  readonly property int _month: parseInt(_parts[1])
  readonly property int _day: parseInt(_parts[2])
  readonly property int _hour24: Math.floor(minutes / 60)
  readonly property int _minPart: minutes % 60
  readonly property int _hour12: (_hour24 % 12 === 0) ? 12 : (_hour24 % 12)
  readonly property bool _isPM: _hour24 >= 12

  function _pad2(n) { return n < 10 ? "0" + n : "" + n }
  function _daysInMonth(y, m) { return new Date(y, m, 0).getDate() }

  function _buildKey(y, m, d) {
    if (m < 1) m = 1
    if (m > 12) m = 12
    var dim = _daysInMonth(y, m)
    if (d < 1) d = 1
    if (d > dim) d = dim
    return y + "-" + _pad2(m) + "-" + _pad2(d)
  }

  height: 34
  width: rowLayout.implicitWidth

  Row {
    id: rowLayout
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0

    SegmentInput {
      display: root._pad2(root._month)
      minVal: 1; maxVal: 12; padLen: 2
      onCommitted: function(v) {
        var nm = v, ny = root._year
        root.dateKeyEdited(root._buildKey(ny, nm, root._day))
      }
      onWheeled: function(dir) {
        var nm = root._month + dir
        var ny = root._year
        if (nm > 12) { nm = 1; ny += 1 }
        if (nm < 1) { nm = 12; ny -= 1 }
        root.dateKeyEdited(root._buildKey(ny, nm, root._day))
      }
    }

    Text { text: "/"; color: MatugenColors.textMuted; font.pixelSize: s(11); font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }

    SegmentInput {
      display: root._pad2(root._day)
      minVal: 1; maxVal: root._daysInMonth(root._year, root._month); padLen: 2
      onCommitted: function(v) {
        root.dateKeyEdited(root._buildKey(root._year, root._month, v))
      }
      onWheeled: function(dir) {
        var dim = root._daysInMonth(root._year, root._month)
        var nd = root._day + dir
        if (nd > dim) nd = 1
        if (nd < 1) nd = dim
        root.dateKeyEdited(root._buildKey(root._year, root._month, nd))
      }
    }

    Text { text: "/"; color: MatugenColors.textMuted; font.pixelSize: s(11); font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }

    SegmentInput {
      display: root._pad2(root._year % 100)
      minVal: 0; maxVal: 99; padLen: 2
      onCommitted: function(v) {
        var century = Math.floor(root._year / 100) * 100
        root.dateKeyEdited(root._buildKey(century + v, root._month, root._day))
      }
      onWheeled: function(dir) {
        root.dateKeyEdited(root._buildKey(root._year + dir, root._month, root._day))
      }
    }

    Item { width: root.showTime ? 10 : 0; height: 1 }

    SegmentInput {
      visible: root.showTime
      display: root._pad2(Config.clock24h ? root._hour24 : root._hour12)
      minVal: Config.clock24h ? 0 : 1; maxVal: Config.clock24h ? 23 : 12; padLen: 2
      onCommitted: function(v) {
        var h24 = Config.clock24h ? v : (root._isPM ? (v === 12 ? 12 : v + 12) : (v === 12 ? 0 : v))
        root.minutesEdited(h24 * 60 + root._minPart)
      }
      onWheeled: function(dir) {
        var nv = root.minutes + dir * 60
        if (nv < 0) nv += 1440
        if (nv >= 1440) nv -= 1440
        root.minutesEdited(nv)
      }
    }

    Text { visible: root.showTime; text: ":"; color: MatugenColors.textMuted; font.pixelSize: s(11); font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }

    SegmentInput {
      visible: root.showTime
      display: root._pad2(root._minPart)
      minVal: 0; maxVal: 59; padLen: 2
      onCommitted: function(v) {
        root.minutesEdited(root._hour24 * 60 + v)
      }
      onWheeled: function(dir) {
        var nv = root.minutes + dir * 5
        if (nv < 0) nv += 1440
        if (nv >= 1440) nv -= 1440
        root.minutesEdited(nv)
      }
    }

    Item { width: root.showTime && !Config.clock24h ? 6 : 0; height: 1 }

    Rectangle {
      visible: root.showTime && !Config.clock24h
      width: ampmTxt.implicitWidth + 8; height: s(24); radius: s(4)
      color: ampmHover.containsMouse ? MatugenColors.bgElevated2 : "transparent"
      anchors.verticalCenter: parent.verticalCenter
      Text {
        id: ampmTxt
        anchors.centerIn: parent
        text: root._isPM ? "PM" : "AM"
        color: MatugenColors.text
        font.pixelSize: s(11); font.family: "JetBrainsMono Nerd Font"
      }
      MouseArea {
        id: ampmHover
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: {
          var nv = root.minutes + (root._isPM ? -720 : 720)
          if (nv < 0) nv += 1440
          if (nv >= 1440) nv -= 1440
          root.minutesEdited(nv)
        }
        onWheel: function(wheel) {
          var nv = root.minutes + (root._isPM ? -720 : 720)
          if (nv < 0) nv += 1440
          if (nv >= 1440) nv -= 1440
          root.minutesEdited(nv)
        }
      }
    }
  }
}

  implicitWidth: col.implicitWidth + s(16)
  implicitHeight: parent ? parent.height : s(50)
  property alias calendarOpen: calPopup.calendarOpen

  Scaler {
    id: scaler
    currentWidth: Screen.width
    currentHeight: Screen.height
  }
  function s(val) { return scaler.s(val) }

  property int cascadeIndex: 3
  property bool entered: false
  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }
  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } } }
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  // EventStore
  QtObject {
    id: eventStore

    readonly property var palette: [
      "#f87171", "#fb923c", "#fbbf24", "#a3e635",
      "#34d399", "#22d3ee", "#60a5fa", "#a78bfa", "#f472b6"
    ]
    property var events: []
    property bool loaded: false

    function _uid() {
      return "ev_" + Date.now() + "_" + Math.floor(Math.random() * 100000)
    }

    function _cmpDate(a, b) {
      return a < b ? -1 : (a > b ? 1 : 0)
    }

    function _persist() {
      if (!eventStore.loaded) return
      eventsFile.setText(JSON.stringify({ events: eventStore.events }, null, 2))
    }

    function _load() {
      try {
        var raw = eventsFile.text
        if (raw && raw.trim().length > 0) {
          var data = JSON.parse(raw)
          if (data && Array.isArray(data.events)) {
            eventStore.events = data.events
          }
        }
      } catch (e) {
        // Corrupt or missing file: start with an empty event list rather
        // than crashing the calendar.
      }
      eventStore.loaded = true
    }

    function addEvent(payload) {
      var ev = {
        id: _uid(),
        title: payload.title,
        allDay: !!payload.allDay,
        startDate: payload.startDate,
        endDate: payload.endDate || payload.startDate,
        startMin: payload.startMin !== undefined ? payload.startMin : 9 * 60,
        endMin: payload.endMin !== undefined ? payload.endMin : 10 * 60,
        color: payload.color || palette[0],
        notes: payload.notes || "",
        travelTime: payload.travelTime !== undefined ? payload.travelTime : 0,
        repeat: payload.repeat || { freq: "none", every: 1 },
        reminders: (payload.reminders || []).slice(0, 2)
      }
      if (_cmpDate(ev.endDate, ev.startDate) < 0) ev.endDate = ev.startDate
      var list = events.slice()
      list.push(ev)
      events = list
      _persist()
      return ev.id
    }

    function updateEvent(id, payload) {
      var list = events.slice()
      for (var i = 0; i < list.length; i++) {
        if (list[i].id === id) {
          var ev = Object.assign({}, list[i], payload)
          ev.endDate = payload.endDate || payload.startDate || ev.endDate
          if (_cmpDate(ev.endDate, ev.startDate) < 0) ev.endDate = ev.startDate
          ev.notes = payload.notes !== undefined ? payload.notes : (ev.notes || "")
          ev.travelTime = payload.travelTime !== undefined ? payload.travelTime : (ev.travelTime || 0)
          ev.repeat = payload.repeat || ev.repeat || { freq: "none", every: 1 }
          ev.reminders = (payload.reminders || ev.reminders || []).slice(0, 2)
          list[i] = ev
          break
        }
      }
      events = list
      _persist()
    }

    function removeEvent(id) {
      events = events.filter(function(e) { return e.id !== id })
      _persist()
    }

    function datesWithEvents() {
      var map = {}
      for (var i = 0; i < events.length; i++) {
        var ev = events[i]
        var d = _dateFromKey(ev.startDate)
        var end = _dateFromKey(ev.endDate)
        while (_cmpDate(_keyFromDate(d), _keyFromDate(end)) <= 0) {
          var k = _keyFromDate(d)
          if (!map[k]) map[k] = ev.color
          d.setDate(d.getDate() + 1)
        }
      }
      return map
    }

    function eventsForDate(dateKey) {
      var out = []
      for (var i = 0; i < events.length; i++) {
        var ev = events[i]
        if (_cmpDate(dateKey, ev.startDate) >= 0 && _cmpDate(dateKey, ev.endDate) <= 0) {
          var pos = "single"
          if (ev.startDate !== ev.endDate) {
            if (dateKey === ev.startDate) pos = "start"
            else if (dateKey === ev.endDate) pos = "end"
            else pos = "middle"
          }
          var copy = Object.assign({}, ev)
          copy.rangePos = pos
          out.push(copy)
        }
      }
      out.sort(function(a, b) {
        if (a.allDay !== b.allDay) return a.allDay ? -1 : 1
        return a.startMin - b.startMin
      })
      return out
    }

    function rangeInfoForDate(dateKey, ev) {
      if (ev.startDate === ev.endDate) return "single"
      if (dateKey === ev.startDate) return "start"
      if (dateKey === ev.endDate) return "end"
      return "middle"
    }

    function _dateFromKey(key) {
      var parts = key.split("-")
      return new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]))
    }

    function _keyFromDate(d) {
      var mm = (d.getMonth() + 1) < 10 ? "0" + (d.getMonth() + 1) : "" + (d.getMonth() + 1)
      var dd = d.getDate() < 10 ? "0" + d.getDate() : "" + d.getDate()
      return d.getFullYear() + "-" + mm + "-" + dd
    }

    function reminderFireDate(ev, reminder) {
      var anchor = _dateFromKey(ev.startDate)
      if (ev.allDay) {
        anchor.setHours(9, 0, 0, 0)
      } else {
        anchor.setHours(Math.floor(ev.startMin / 60), ev.startMin % 60, 0, 0)
      }
      var ms = anchor.getTime()
      var amount = reminder.amount
      switch (reminder.unit) {
        case "minutes": ms -= amount * 60 * 1000; break
        case "hours":   ms -= amount * 60 * 60 * 1000; break
        case "days":    ms -= amount * 24 * 60 * 60 * 1000; break
        case "weeks":   ms -= amount * 7 * 24 * 60 * 60 * 1000; break
      }
      return new Date(ms)
    }
  }

  FileView {
    id: eventsFile
    path: Quickshell.env("HOME") + "/.config/quickshell/calendar-events.json"
    printErrors: false
    watchChanges: false
    onLoaded: eventStore._load()
    onLoadFailed: function(error) {
      // File doesn't exist yet on first run: treat as an empty event list
      // rather than leaving eventStore stuck in an unloaded state.
      eventStore.loaded = true
    }
    Component.onCompleted: reload()
  }

  // Clock content
  Column {
    id: col
    anchors.centerIn: parent
    spacing: 2

    Text {
      text: {
        var fmt = Config.clock24h ? "hh:mm" : "h:mm AP"
        if (Config.showClockSeconds) fmt = Config.clock24h ? "hh:mm:ss" : "h:mm:ss AP"
        return Qt.formatDateTime(clock.date, fmt)
      }
      color: MatugenColors.text
      font.pixelSize: s(15)
      font.weight: Font.Bold
      font.family: "JetBrainsMono Nerd Font"
      anchors.horizontalCenter: parent.horizontalCenter
    }

    Text {
      text: Qt.formatDateTime(clock.date, "ddd MMM d")
      color: calPopup.calendarOpen ? MatugenColors.accent : MatugenColors.textMuted
      font.pixelSize: s(10)
      font.family: "JetBrainsMono Nerd Font"
      anchors.horizontalCenter: parent.horizontalCenter
      Behavior on color { ColorAnimation { duration: 200 } }
    }
  }

  MouseArea {
    id: pillMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: calPopup.toggle()
  }

  // Calendar Popup
  PanelWindow {
    id: calPopup

    property bool calendarOpen: false
    property var clockDate: clock.date

    function open() { calendarOpen = true }
    function close() { calendarOpen = false }
    function toggle() { calendarOpen = !calendarOpen }

    visible: animOpacity > 0.01
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qs-calendar-popup"
    anchors { top: true; left: true; right: true; bottom: true }

    property real animOpacity: calendarOpen ? 1.0 : 0.0
    Behavior on animOpacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    onCalendarOpenChanged: {
      if (calendarOpen) {
        calGrid.viewMonth = clockDate.getMonth()
        calGrid.viewYear  = clockDate.getFullYear()
        dayPanel.selectedDate = calGrid._keyFor(clockDate.getFullYear(), clockDate.getMonth(), clockDate.getDate())
        dayPanel.mode = "list"
      } else {
        dayPanel.mode = "list"
      }
    }

    function _minToTime(min) {
      if (min === undefined) return ""
      var h = Math.floor(min / 60), m = min % 60
      var mm = m < 10 ? "0" + m : "" + m
      if (Config.clock24h) {
        var hh = (h % 24) < 10 ? "0" + (h % 24) : "" + (h % 24)
        return hh + ":" + mm
      }
      var ampm = h >= 12 ? "PM" : "AM"
      var h12 = h % 12 === 0 ? 12 : h % 12
      return h12 + ":" + mm + " " + ampm
    }

    function _keyFor(year, month, day) {
      var mm = (month + 1) < 10 ? "0" + (month + 1) : "" + (month + 1)
      var dd = day < 10 ? "0" + day : "" + day
      return year + "-" + mm + "-" + dd
    }

    function _addDaysToKey(key, n) {
      var parts = key.split("-")
      var d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]))
      d.setDate(d.getDate() + n)
      return _keyFor(d.getFullYear(), d.getMonth(), d.getDate())
    }

    function _formatKeyShort(key) {
      if (key === "") return ""
      var parts = key.split("-")
      var d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]))
      return Qt.locale().standaloneMonthName(d.getMonth(), Locale.ShortFormat) + " " + d.getDate()
    }

    MouseArea {
      anchors.fill: parent
      onClicked: calPopup.close()
    }

    FocusScope {
      id: popupRoot
      anchors.fill: parent
      focus: calPopup.calendarOpen
      Keys.onEscapePressed: {
        if (dayPanel.mode === "edit") dayPanel.mode = "list"
        else if (dayPanel.selectedDate !== "") dayPanel.selectedDate = ""
        else calPopup.close()
      }
    // popup
      Rectangle {
        id: calCard
        width: s(685)
        x: Config.barPosition === "left" ? s(8) : (Screen.width - width - s(8))
        y: Config.barPosition === "bottom" ? (Screen.height - height - s(70)) : s(70)
        radius: s(10)
        clip: true
        focus: true
        color: MatugenColors.bgBase
        border.color: MatugenColors.border
        border.width: 2

        opacity: calPopup.animOpacity
        scale: 0.94 + 0.06 * calPopup.animOpacity
        transform: Translate { y: (1 - calPopup.animOpacity) * -10 }
        implicitHeight: calColumn.implicitHeight + 32
        height: implicitHeight
        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Keys.onEscapePressed: calPopup.close()
        MouseArea { anchors.fill: parent }

        Row {
          id: calColumn
          anchors.fill: parent
          anchors.margins: s(16)
          spacing: s(16)
          // calaendar side
          Column {
            id: calSide
            width: s(320)
            spacing: s(12)
            property string zoomLevel: "day" // "day" | "months" | "years"
            readonly property int minYear: 1970
            readonly property int maxYear: 2100

          Item {
            width: parent.width
            height: 26

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: calSide.zoomLevel === "years"
                ? "Years"
                : (calSide.zoomLevel === "months" ? calGrid.viewYear.toString()
                  : Qt.locale().standaloneMonthName(calGrid.viewMonth, Locale.LongFormat) + "  " + calGrid.viewYear)
              color: MatugenColors.text; font.pixelSize: s(13); font.weight: Font.Bold
              font.family: "JetBrainsMono Nerd Font"

              MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (calSide.zoomLevel === "day") calSide.zoomLevel = "months"
                  else if (calSide.zoomLevel === "months") calSide.zoomLevel = "years"
                }
              }
            }

            Row {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: 4

              Rectangle {
                width: s(26); height: s(26); radius: s(6)
                color: prevMonthArea.containsMouse ? MatugenColors.bgElevated : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                  anchors.centerIn: parent
                  text: "‹"
                  color: MatugenColors.accent; font.pixelSize: s(16); font.family: "JetBrainsMono Nerd Font"
                }
                MouseArea {
                  id: prevMonthArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (calSide.zoomLevel === "years") {
                      yearsGrid.startYear = Math.max(calSide.minYear, yearsGrid.startYear - 12)
                    } else if (calSide.zoomLevel === "months") {
                      calGrid.viewYear = Math.max(calSide.minYear, calGrid.viewYear - 1)
                    } else {
                      calGrid.viewMonth -= 1
                      if (calGrid.viewMonth < 0) {
                        calGrid.viewMonth = 11
                        calGrid.viewYear -= 1
                      }
                    }
                  }
                }
              }

              Rectangle {
                width: s(26); height: s(26); radius: s(6)
                color: nextMonthArea.containsMouse ? MatugenColors.bgElevated : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                  anchors.centerIn: parent
                  text: "›"
                  color: MatugenColors.accent; font.pixelSize: s(16); font.family: "JetBrainsMono Nerd Font"
                }
                MouseArea {
                  id: nextMonthArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (calSide.zoomLevel === "years") {
                      yearsGrid.startYear = Math.min(calSide.maxYear - 11, yearsGrid.startYear + 12)
                    } else if (calSide.zoomLevel === "months") {
                      calGrid.viewYear = Math.min(calSide.maxYear, calGrid.viewYear + 1)
                    } else {
                      calGrid.viewMonth += 1
                      if (calGrid.viewMonth > 11) {
                        calGrid.viewMonth = 0
                        calGrid.viewYear += 1
                      }
                    }
                  }
                }
              }

              Rectangle {
                width: s(26); height: s(26); radius: s(6)
                color: addEventHover.containsMouse ? MatugenColors.accentSoft : MatugenColors.bgElevated
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                  anchors.centerIn: parent
                  text: "+"
                  color: MatugenColors.accent
                  font.pixelSize: s(14); font.weight: Font.Bold
                  font.family: "JetBrainsMono Nerd Font"
                  rotation: dayPanel.mode === "edit" && dayPanel.editingId === "" ? 45 : 0
                  Behavior on rotation { NumberAnimation { duration: 150 } }
                }
                MouseArea {
                  id: addEventHover
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (dayPanel.mode === "edit" && dayPanel.editingId === "") {
                      dayPanel.mode = dayPanel.selectedDate !== "" ? "list" : "hidden"
                      return
                    }
                    dayPanel.selectedDate = dayPanel.selectedDate !== "" ? dayPanel.selectedDate : calGrid._keyFor(calGrid.viewYear, calGrid.viewMonth, calPopup.clockDate.getDate())
                    dayPanel.editingId = ""
                    dayPanel.mode = "edit"
                    editForm.title = ""
                    editForm.startDate = dayPanel.selectedDate
                    editForm.endDate = dayPanel.selectedDate
                    editForm.allDay = false
                    editForm.startMin = 9 * 60
                    editForm.endMin = 10 * 60
                    editForm.color = eventStore.palette[0]
                    editForm.reminders = []
                    editForm.notes = ""
                    editForm.travelTime = 0
                    editForm.repeatFreq = "none"
                    editForm.repeatCustomText = ""
                  }
                }
              }
            }
          }

          Row {
            width: parent.width
            height: s(24)
            visible: calSide.zoomLevel === "day"
            Repeater {
              model: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
              Text {
                required property string modelData
                width: parent.width / 7
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: MatugenColors.textMuted; font.pixelSize: s(9); font.family: "JetBrainsMono Nerd Font"
              }
            }
          }

          GridLayout {
            id: calGrid
            width: parent.width
            columns: 7
            visible: opacity > 0.01
            opacity: calSide.zoomLevel === "day" ? 1 : 0
            scale: calSide.zoomLevel === "day" ? 1 : 1.08
            height: calSide.zoomLevel === "day" ? implicitHeight : 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            property int viewMonth: 0
            property int viewYear: 2024
            property var datesMap: eventStore.datesWithEvents()

            Repeater {
              model: 42
              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: s(56)
                required property int index

                property int day: {
                  var first = new Date(calGrid.viewYear, calGrid.viewMonth, 1).getDay()
                  var daysInMonth = new Date(calGrid.viewYear, calGrid.viewMonth + 1, 0).getDate()
                  var idx = index
                  if (idx < first) {
                    var prevDays = new Date(calGrid.viewYear, calGrid.viewMonth, 0).getDate()
                    return prevDays - first + idx + 1
                  }
                  var dayInMonth = idx - first + 1
                  if (dayInMonth <= daysInMonth) return dayInMonth
                  return dayInMonth - daysInMonth
                }

                property bool isCurrentMonth: {
                  var first = new Date(calGrid.viewYear, calGrid.viewMonth, 1).getDay()
                  var daysInMonth = new Date(calGrid.viewYear, calGrid.viewMonth + 1, 0).getDate()
                  return index >= first && index < first + daysInMonth
                }

                color: dayMouse.containsMouse ? MatugenColors.bgElevated : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
                radius: 6

                Rectangle {
                  anchors.fill: parent
                  radius: 6
                  color: "transparent"
                  border.width: parent.day === calPopup.clockDate.getDate() && parent.isCurrentMonth && calPopup.clockDate.getMonth() === calGrid.viewMonth && calPopup.clockDate.getFullYear() === calGrid.viewYear ? 1 : 0
                  border.color: MatugenColors.accent
                }

                Rectangle {
                  anchors.fill: parent
                  anchors.margins: 1
                  radius: 5
                  color: "transparent"
                  property string evColor: parent.isCurrentMonth ? (calGrid.datesMap[calGrid._keyFor(calGrid.viewYear, calGrid.viewMonth, day)] || "") : ""
                  border.width: evColor !== "" ? 2 : 0
                  border.color: evColor !== "" ? evColor : "transparent"
                }

                Text {
                  anchors.centerIn: parent
                  text: day.toString()
                  color: isCurrentMonth ? MatugenColors.text : MatugenColors.textMuted
                  font.pixelSize: s(11); font.family: "JetBrainsMono Nerd Font"
                  opacity: isCurrentMonth ? 1.0 : 0.3
                }

                MouseArea {
                  id: dayMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (isCurrentMonth) {
                      dayPanel.selectedDate = calGrid._keyFor(calGrid.viewYear, calGrid.viewMonth, day)
                      dayPanel.mode = "list"
                    }
                  }
                }
              }
            }

            function _keyFor(year, month, day) {
              var mm = (month + 1) < 10 ? "0" + (month + 1) : "" + (month + 1)
              var dd = day < 10 ? "0" + day : "" + day
              return year + "-" + mm + "-" + dd
            }
          } // end calGrid

          GridLayout {
            id: monthsGrid
            width: parent.width
            columns: 3
            columnSpacing: s(8)
            rowSpacing: s(8)
            visible: opacity > 0.01
            opacity: calSide.zoomLevel === "months" ? 1 : 0
            scale: calSide.zoomLevel === "months" ? 1 : 0.92
            height: calSide.zoomLevel === "months" ? implicitHeight : 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Repeater {
              model: 12
              Rectangle {
                required property int index
                Layout.fillWidth: true
                Layout.preferredHeight: s(56)
                radius: 8
                color: monthMouse.containsMouse ? MatugenColors.bgElevated
                  : (index === calGrid.viewMonth ? MatugenColors.bgElevated2 : "transparent")
                border.width: index === calPopup.clockDate.getMonth() && calGrid.viewYear === calPopup.clockDate.getFullYear() ? 1 : 0
                border.color: MatugenColors.accent
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                  anchors.centerIn: parent
                  text: Qt.locale().standaloneMonthName(index, Locale.ShortFormat)
                  color: MatugenColors.text
                  font.pixelSize: s(12); font.weight: Font.DemiBold
                  font.family: "JetBrainsMono Nerd Font"
                }

                MouseArea {
                  id: monthMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    calGrid.viewMonth = index
                    calSide.zoomLevel = "day"
                  }
                }
              }
            }
          } // end monthsGrid

          GridLayout {
            id: yearsGrid
            width: parent.width
            columns: 3
            columnSpacing: s(8)
            rowSpacing: s(8)
            visible: opacity > 0.01
            opacity: calSide.zoomLevel === "years" ? 1 : 0
            scale: calSide.zoomLevel === "years" ? 1 : 0.92
            height: calSide.zoomLevel === "years" ? implicitHeight : 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            // Base of the visible 12-year block. Reset relative to the
            // current view year whenever the years grid is opened, so it
            // always centers on wherever the user currently is instead of
            // drifting from a stale value left over from a previous visit.
            property int startYear: calGrid.viewYear - (calGrid.viewYear % 12)

            WheelHandler {
              target: null
              onWheel: function(event) {
                var dir = event.angleDelta.y > 0 ? -12 : 12
                yearsGrid.startYear = Math.max(calSide.minYear, Math.min(calSide.maxYear - 11, yearsGrid.startYear + dir))
              }
            }

            Repeater {
              model: 12
              Rectangle {
                required property int index
                readonly property int yearValue: yearsGrid.startYear + index
                Layout.fillWidth: true
                Layout.preferredHeight: s(56)
                radius: 8
                color: yearMouse.containsMouse ? MatugenColors.bgElevated
                  : (yearValue === calGrid.viewYear ? MatugenColors.bgElevated2 : "transparent")
                border.width: yearValue === calPopup.clockDate.getFullYear() ? 1 : 0
                border.color: MatugenColors.accent
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                  anchors.centerIn: parent
                  text: yearValue.toString()
                  color: MatugenColors.text
                  font.pixelSize: s(12); font.weight: Font.DemiBold
                  font.family: "JetBrainsMono Nerd Font"
                }

                MouseArea {
                  id: yearMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    calGrid.viewYear = yearValue
                    calSide.zoomLevel = "months"
                  }
                }
              }
            }
          } // end yearsGrid

          } // end calSide

          Column {
            id: daySide
            width: parent.width - calSide.width - parent.spacing

          Item {
            width: parent.width
            height: dayPanel.panelHeight
            clip: true

            Rectangle {
              anchors.fill: parent
              radius: s(10)
              color: MatugenColors.bgElevated2
              opacity: dayPanel.mode !== "hidden" ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            Column {
              id: dayPanel
              width: parent.width
              anchors.margins: dayPanel.mode !== "hidden" ? s(12) : 0
              spacing: s(8)

              property string selectedDate: ""
              property string mode: "hidden"
              property string editingId: ""
              property real panelHeight: mode !== "hidden" ? contentCol.implicitHeight + s(24) : 0

              Behavior on anchors.margins { NumberAnimation { duration: 200 } }
              Behavior on panelHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

              function minToTime(m) { return calPopup._minToTime(m) }

              Column {
                id: contentCol
                width: parent.width
                spacing: s(8)

                Text {
                  visible: dayPanel.mode === "list"
                  text: calPopup._formatKeyShort(dayPanel.selectedDate)
                  color: MatugenColors.text; font.pixelSize: s(12); font.weight: Font.Bold
                  font.family: "JetBrainsMono Nerd Font"
                }

                Column {
                  visible: dayPanel.mode === "list"
                  width: parent.width
                  spacing: s(6)

                  Repeater {
                    model: dayPanel.mode === "list" ? eventStore.eventsForDate(dayPanel.selectedDate) : []
                    Rectangle {
                      required property var modelData
                      width: parent.width
                      height: s(50); radius: s(8)
                      color: eventHover.containsMouse ? Qt.darker(modelData.color, 1.15) : modelData.color
                      opacity: 0.8
                      Behavior on color { ColorAnimation { duration: 150 } }

                      Column {
                        anchors.fill: parent
                        anchors.margins: s(8)
                        spacing: s(2)

                        Item {
                          width: parent.width
                          height: titleText.implicitHeight

                          Text {
                            id: titleText
                            width: parent.width
                            text: modelData.title
                            color: "white"
                            font.pixelSize: s(11); font.weight: Font.Bold
                            font.family: "JetBrainsMono Nerd Font"
                            elide: Text.ElideRight
                            maximumLineCount: 1
                          }

                          // Right-edge fade: only shown when the title is
                          // actually being truncated, so short titles stay
                          // crisp. Fades to the card's own background color
                          // rather than to transparent, since the card
                          // itself is a solid color block.
                          Rectangle {
                            visible: titleText.truncated
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: s(18)
                            gradient: Gradient {
                              orientation: Gradient.Horizontal
                              GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
                              GradientStop { position: 1.0; color: eventHover.containsMouse ? Qt.darker(modelData.color, 1.15) : modelData.color }
                            }
                          }
                        }

                        Text {
                          text: modelData.allDay ? "All-day" : (calPopup._minToTime(modelData.startMin) + " – " + calPopup._minToTime(modelData.endMin))
                          color: "white"
                          font.pixelSize: s(9)
                          font.family: "JetBrainsMono Nerd Font"
                          opacity: 0.9
                        }
                      }

                      MouseArea {
                        id: eventHover
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          dayPanel.editingId = modelData.id
                          dayPanel.mode = "edit"
                          editForm.title = modelData.title
                          editForm.startDate = modelData.startDate
                          editForm.endDate = modelData.endDate
                          editForm.allDay = modelData.allDay
                          editForm.startMin = modelData.startMin
                          editForm.endMin = modelData.endMin
                          editForm.color = modelData.color
                          editForm.reminders = (modelData.reminders || []).slice(0, editForm.maxReminders)
                          editForm.notes = modelData.notes || ""
                          editForm.travelTime = modelData.travelTime || 0
                          editForm.repeatFreq = (modelData.repeat && modelData.repeat.freq) || "none"
                          editForm.repeatCustomText = (modelData.repeat && modelData.repeat.text) || ""
                        }
                      }
                    }
                  }

                  Text {
                    visible: dayPanel.mode === "list" && eventStore.eventsForDate(dayPanel.selectedDate).length === 0
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "No events"
                    color: MatugenColors.textMuted
                    font.pixelSize: s(10)
                    font.family: "JetBrainsMono Nerd Font"
                    opacity: 0.7
                  }
                }

                Column {
                  visible: dayPanel.mode === "edit"
                  width: parent.width
                  spacing: 10

                  QtObject {
                    id: editForm
                    property string title: ""
                    property string startDate: ""
                    property string endDate: ""
                    property bool allDay: false
                    property int startMin: 9 * 60
                    property int endMin: 10 * 60
                    property string color: eventStore.palette[0]
                    property var reminders: []
                    property string notes: ""
                    property int travelTime: 0
                    property string repeatFreq: "none"
                    property string repeatCustomText: ""

                    readonly property int maxReminders: 10

                    // Canonical top-to-bottom ordering: at time of event,
                    // 5/10/15/30 min, 1/2 hr, 1/2 day, 1 week. Reminders
                    // auto-sort into this order whenever one is set.
                    readonly property var sortOrder: [
                      "minutes:0", "minutes:5", "minutes:10", "minutes:15", "minutes:30",
                      "hours:1", "hours:2", "days:1", "days:2", "weeks:1",
                      "days:0"
                    ]

                    function _remKey(r) { return r.unit + ":" + r.amount }

                    function _sortReminders(list) {
                      return list.slice().sort(function(a, b) {
                        var ia = editForm.sortOrder.indexOf(editForm._remKey(a))
                        var ib = editForm.sortOrder.indexOf(editForm._remKey(b))
                        return ia - ib
                      })
                    }

                    function usedKeysExcept(idx) {
                      var out = []
                      for (var i = 0; i < editForm.reminders.length; i++) {
                        if (i === idx) continue
                        out.push(editForm._remKey(editForm.reminders[i]))
                      }
                      return out
                    }

                    // Number of AlertField rows to actually show: every
                    // set reminder, plus exactly one empty slot after them
                    // (to set the next one), capped at maxReminders. This
                    // is what makes a new empty alert appear only after
                    // the previous one is set, instead of showing all 10
                    // slots up front.
                    readonly property int visibleReminderSlots: Math.min(editForm.maxReminders, editForm.reminders.length + 1)

                    function setReminderAt(idx, r) {
                      var list = editForm.reminders.slice()
                      if (r === null) {
                        // Clearing a slot removes it (and anything after
                        // it collapses up), rather than leaving a gap.
                        list.splice(idx, 1)
                      } else if (idx < list.length) {
                        list[idx] = r
                      } else {
                        list.push(r)
                      }
                      editForm.reminders = editForm._sortReminders(list)
                    }

                    function reminderList() {
                      return editForm.reminders.slice(0, editForm.maxReminders)
                    }

                    function repeatValue() {
                      if (repeatFreq === "custom") return { freq: "custom", text: repeatCustomText }
                      return { freq: repeatFreq }
                    }
                  }

                  TextField {
                    id: titleField
                    width: parent.width
                    height: s(34)
                    placeholderText: "Title"
                    text: editForm.title
                    onTextChanged: if (text !== editForm.title) editForm.title = text
                  }

                  Column {
                    width: parent.width; spacing: 8

                    Row {
                      width: parent.width; height: s(34); spacing: s(6)

                      Text {
                        id: startsLabel
                        width: s(48)
                        leftPadding: 4
                        text: "Starts:"
                        color: MatugenColors.textMuted
                        font.pixelSize: s(10)
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      Rectangle {
                        width: parent.width - startsLabel.width - parent.spacing
                        height: s(34); radius: s(8)
                        color: MatugenColors.bgElevated

                        DateTimeField {
                          anchors.left: parent.left
                          anchors.leftMargin: s(6)
                          anchors.verticalCenter: parent.verticalCenter
                          dateKey: editForm.startDate
                          minutes: editForm.startMin
                          showTime: !editForm.allDay
                          onDateKeyEdited: function(k) {
                            if (k <= editForm.endDate) editForm.startDate = k
                            else { editForm.startDate = k; editForm.endDate = k }
                          }
                          onMinutesEdited: function(v) {
                            editForm.startMin = v
                            if (editForm.startDate === editForm.endDate && editForm.endMin <= v)
                              editForm.endMin = Math.min(23 * 60 + 45, v + 60)
                          }
                        }
                      }
                    }

                    Row {
                      width: parent.width; height: s(34); spacing: s(6)

                      Text {
                        id: endsLabel
                        width: s(48)
                        leftPadding: 4
                        text: "Ends:"
                        color: MatugenColors.textMuted
                        font.pixelSize: s(10)
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      Rectangle {
                        width: parent.width - endsLabel.width - parent.spacing
                        height: s(34); radius: s(8)
                        color: MatugenColors.bgElevated

                        DateTimeField {
                          anchors.left: parent.left
                          anchors.leftMargin: s(6)
                          anchors.verticalCenter: parent.verticalCenter
                          dateKey: editForm.endDate
                          minutes: editForm.endMin
                          showTime: !editForm.allDay
                          onDateKeyEdited: function(k) {
                            if (k >= editForm.startDate) editForm.endDate = k
                            else { editForm.endDate = k; editForm.startDate = k }
                          }
                          onMinutesEdited: function(v) {
                            if (editForm.startDate === editForm.endDate)
                              editForm.endMin = Math.max(v, editForm.startMin + 15)
                            else
                              editForm.endMin = v
                          }
                        }
                      }
                    }
                  }

                  Row {
                    width: parent.width; height: s(34); spacing: s(6)

                    Text {
                      width: s(48)
                      leftPadding: 4
                      text: "All day:"
                      color: MatugenColors.textMuted
                      font.pixelSize: s(10)
                      font.family: "JetBrainsMono Nerd Font"
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                      width: s(40); height: s(22); radius: s(11)
                      anchors.verticalCenter: parent.verticalCenter
                      color: editForm.allDay ? MatugenColors.accent : MatugenColors.bgElevated
                      Behavior on color { ColorAnimation { duration: 120 } }

                      Rectangle {
                        width: s(16); height: s(16); radius: s(8)
                        anchors.verticalCenter: parent.verticalCenter
                        x: editForm.allDay ? parent.width - width - s(3) : s(3)
                        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        color: MatugenColors.bgBase
                      }

                      MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: editForm.allDay = !editForm.allDay
                      }
                    }
                  }

                  Column {
                    width: parent.width; spacing: 8
                    z: 40
                    Text { text: "Repeat"; color: MatugenColors.textMuted; font.pixelSize: s(10); font.family: "JetBrainsMono Nerd Font"; leftPadding: 4 }

                    Row {
                      width: parent.width
                      spacing: s(4)

                      Repeater {
                        model: [
                          { key: "none",    text: "Never" },
                          { key: "daily",   text: "Daily" },
                          { key: "weekly",  text: "Weekly" },
                          { key: "monthly", text: "Monthly" },
                          { key: "yearly",  text: "Yearly" },
                          { key: "custom",  text: "Custom" }
                        ]
                        Rectangle {
                          required property var modelData
                          width: (parent.width - s(4) * 5) / 6
                          height: s(26)
                          radius: 6
                          color: editForm.repeatFreq === modelData.key ? MatugenColors.accent : (repeatOptHover.containsMouse ? MatugenColors.bgElevated : MatugenColors.bgElevated2)
                          Behavior on color { ColorAnimation { duration: 120 } }

                          Text {
                            anchors.centerIn: parent
                            text: modelData.text
                            color: editForm.repeatFreq === modelData.key ? MatugenColors.accentText : MatugenColors.text
                            font.pixelSize: s(9)
                            font.family: "JetBrainsMono Nerd Font"
                          }

                          MouseArea {
                            id: repeatOptHover
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              editForm.repeatFreq = modelData.key
                            }
                          }
                        }
                      }
                    }

                    TextField {
                      width: parent.width
                      height: s(30)
                      visible: editForm.repeatFreq === "custom"
                      placeholderText: "e.g. every 2 weeks on Friday"
                      text: editForm.repeatCustomText
                      onTextChanged: if (text !== editForm.repeatCustomText) editForm.repeatCustomText = text
                    }
                  }

                  Column {
                    width: parent.width; spacing: 6
                    Text { text: "Travel time"; color: MatugenColors.textMuted; font.pixelSize: s(10); font.family: "JetBrainsMono Nerd Font"; leftPadding: 4 }

                    component TravelTimeField : Item {
                      id: ttRoot
                      property int minutes: 0
                      signal minutesEdited(int m)

                      readonly property var options: [
                        { text: "None",        value: 0 },
                        { text: "5 minutes",   value: 5 },
                        { text: "15 minutes",  value: 15 },
                        { text: "30 minutes",  value: 30 },
                        { text: "1 hour",      value: 60 },
                        { text: "1 hour 30 min", value: 90 },
                        { text: "2 hours",     value: 120 }
                      ]
                      readonly property string currentText: {
                        for (var i = 0; i < options.length; i++) if (options[i].value === ttRoot.minutes) return options[i].text
                        return ttRoot.minutes + " min"
                      }

                      width: parent ? parent.width : 200
                      height: 34
                      z: expanded ? 1000 : 1

                      property bool expanded: false

                      Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: MatugenColors.bgElevated
                        border.width: ttRoot.expanded ? 1 : 0
                        border.color: MatugenColors.accent

                        Text {
                          anchors.left: parent.left
                          anchors.leftMargin: 10
                          anchors.verticalCenter: parent.verticalCenter
                          text: ttRoot.currentText
                          color: MatugenColors.text
                          font.pixelSize: s(11)
                          font.family: "JetBrainsMono Nerd Font"
                        }

                        Text {
                          anchors.right: parent.right
                          anchors.rightMargin: 10
                          anchors.verticalCenter: parent.verticalCenter
                          text: ttRoot.expanded ? "▲" : "▼"
                          color: MatugenColors.textMuted
                          font.pixelSize: s(8)
                          font.family: "JetBrainsMono Nerd Font"
                        }

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: ttRoot.expanded = !ttRoot.expanded
                        }
                      }

                      MouseArea {
                        parent: calPopup.contentItem
                        anchors.fill: parent
                        visible: ttRoot.expanded
                        z: 999
                        onClicked: ttRoot.expanded = false
                      }

                      Rectangle {
                        parent: calPopup.contentItem
                        x: { var p = ttRoot.mapToItem(calPopup.contentItem, 0, 34 + 4); return p.x }
                        y: { var p = ttRoot.mapToItem(calPopup.contentItem, 0, 34 + 4); return p.y }
                        width: ttRoot.width
                        height: ttCol.implicitHeight + 8
                        radius: 8
                        color: MatugenColors.bgElevated2
                        border.width: 1
                        border.color: MatugenColors.borderSoft
                        visible: ttRoot.expanded
                        z: 1000
                        clip: true

                        Column {
                          id: ttCol
                          width: parent.width
                          anchors.margins: 4
                          anchors.fill: parent
                          spacing: 1

                          Repeater {
                            model: ttRoot.options
                            Rectangle {
                              required property var modelData
                              width: parent.width
                              height: 26
                              radius: 5
                              color: ttOptHover.containsMouse ? MatugenColors.bgElevated : "transparent"

                              Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.text
                                color: MatugenColors.text
                                font.pixelSize: s(10)
                                font.family: "JetBrainsMono Nerd Font"
                              }

                              MouseArea {
                                id: ttOptHover
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                  ttRoot.minutesEdited(modelData.value)
                                  ttRoot.expanded = false
                                }
                              }
                            }
                          }
                        }
                      }
                    }

                    TravelTimeField {
                      width: parent.width
                      minutes: editForm.travelTime
                      onMinutesEdited: function(m) { editForm.travelTime = m }
                    }
                  }

                  Column {
                    width: parent.width; spacing: 6
                    Text { text: "Notes"; color: MatugenColors.textMuted; font.pixelSize: s(10); font.family: "JetBrainsMono Nerd Font"; leftPadding: 4 }

                    Rectangle {
                      width: parent.width
                      height: s(60)
                      radius: 8
                      color: MatugenColors.bgElevated
                      border.width: notesInput.activeFocus ? 1 : 0
                      border.color: MatugenColors.accent

                      Flickable {
                        anchors.fill: parent
                        anchors.margins: s(8)
                        clip: true
                        contentHeight: notesInput.implicitHeight
                        TextEdit {
                          id: notesInput
                          width: parent.width
                          wrapMode: TextEdit.Wrap
                          font.pixelSize: s(11)
                          font.family: "JetBrainsMono Nerd Font"
                          color: MatugenColors.text
                          text: editForm.notes
                          onTextChanged: if (text !== editForm.notes) editForm.notes = text

                          Text {
                            anchors.fill: parent
                            text: "Add notes..."
                            color: MatugenColors.textMuted
                            font.pixelSize: s(11)
                            font.family: "JetBrainsMono Nerd Font"
                            visible: notesInput.text.length === 0
                          }
                        }
                      }
                    }
                  }

                  Column {
                    id: colorSection
                    width: parent.width; spacing: 6
                    z: 60
                    Text { text: "Color"; color: MatugenColors.textMuted; font.pixelSize: s(10); font.family: "JetBrainsMono Nerd Font"; leftPadding: 4 }
                    Row {
                      leftPadding: s(4)
                      spacing: s(8)
                      Repeater {
                        model: eventStore.palette
                        Rectangle {
                          required property string modelData
                          width: s(22); height: s(22); radius: s(11)
                          color: modelData
                          border.width: editForm.color === modelData ? 2 : 0
                          border.color: MatugenColors.text
                          scale: swatchHover.containsMouse ? 1.15 : 1.0
                          Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                          MouseArea {
                            id: swatchHover
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: editForm.color = modelData
                          }
                        }
                      }

                      // Custom-color swatch: shows the current color when
                      // it's not one of the defaults, otherwise acts as a
                      // plain "+" button to open the picker.
                      Rectangle {
                        id: customSwatch
                        readonly property bool isCustomActive: eventStore.palette.indexOf(editForm.color) === -1
                        width: s(22); height: s(22); radius: s(11)
                        color: isCustomActive ? editForm.color : MatugenColors.bgElevated
                        border.width: isCustomActive ? 2 : 1
                        border.color: isCustomActive ? MatugenColors.text : MatugenColors.borderSoft
                        scale: customSwatchHover.containsMouse ? 1.15 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                        Text {
                          visible: !customSwatch.isCustomActive
                          anchors.centerIn: parent
                          text: "+"
                          color: MatugenColors.textMuted
                          font.pixelSize: s(12); font.weight: Font.Bold
                          font.family: "JetBrainsMono Nerd Font"
                        }

                        MouseArea {
                          id: customSwatchHover
                          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            colorPicker.pendingHex = customSwatch.isCustomActive ? editForm.color : "#f87171"
                            colorPicker.open = !colorPicker.open
                          }
                        }
                      }
                    }

                    MouseArea {
                      parent: calPopup.contentItem
                      anchors.fill: parent
                      visible: colorPicker.open
                      z: 999
                      onClicked: colorPicker.open = false
                    }

                    Rectangle {
                      id: colorPicker
                      parent: calPopup.contentItem
                      property bool open: false
                      property string pendingHex: "#f87171"

                      x: { var p = colorSection.mapToItem(calPopup.contentItem, 0, colorSection.height + 4); return p.x }
                      y: { var p = colorSection.mapToItem(calPopup.contentItem, 0, colorSection.height + 4); return p.y }
                      width: 220
                      height: pickerCol.implicitHeight + 20
                      radius: 10
                      color: MatugenColors.bgElevated2
                      border.width: 1
                      border.color: MatugenColors.borderSoft
                      visible: open
                      z: 1000
                      clip: true

                      Column {
                        id: pickerCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Rectangle {
                          width: parent.width; height: s(28); radius: 6
                          color: {
                            try { return colorPicker.pendingHex } catch (e) { return "#000000" }
                          }
                          border.width: 1
                          border.color: MatugenColors.borderSoft
                        }

                        TextField {
                          id: hexField
                          width: parent.width
                          height: s(30)
                          placeholderText: "#rrggbb"
                          text: colorPicker.pendingHex
                          onTextChanged: {
                            if (text !== colorPicker.pendingHex) colorPicker.pendingHex = text
                          }
                        }

                        Row {
                          width: parent.width
                          spacing: 6

                          Repeater {
                            model: ["r", "g", "b"]
                            Column {
                              required property string modelData
                              width: (parent.width - 12) / 3
                              spacing: 2

                              readonly property int channelVal: {
                                var h = colorPicker.pendingHex
                                if (!/^#[0-9a-fA-F]{6}$/.test(h)) return 0
                                var off = modelData === "r" ? 1 : (modelData === "g" ? 3 : 5)
                                return parseInt(h.substr(off, 2), 16)
                              }

                              Text {
                                text: modelData.toUpperCase() + ": " + parent.channelVal
                                color: MatugenColors.textMuted
                                font.pixelSize: s(9)
                                font.family: "JetBrainsMono Nerd Font"
                              }

                              Slider2 {
                                width: parent.width
                                value: parent.channelVal
                                onMoved: function(v) {
                                  var h = colorPicker.pendingHex
                                  if (!/^#[0-9a-fA-F]{6}$/.test(h)) h = "#000000"
                                  var r = parseInt(h.substr(1, 2), 16)
                                  var g = parseInt(h.substr(3, 2), 16)
                                  var b = parseInt(h.substr(5, 2), 16)
                                  var nv = Math.max(0, Math.min(255, Math.round(v)))
                                  if (modelData === "r") r = nv
                                  else if (modelData === "g") g = nv
                                  else b = nv
                                  function hx(n) { var s2 = n.toString(16); return s2.length < 2 ? "0" + s2 : s2 }
                                  colorPicker.pendingHex = "#" + hx(r) + hx(g) + hx(b)
                                }
                              }
                            }
                          }
                        }

                        Rectangle {
                          width: parent.width
                          height: s(26)
                          radius: s(6)
                          color: applyHover.containsMouse ? Qt.lighter(MatugenColors.accent, 1.1) : MatugenColors.accent
                          opacity: /^#[0-9a-fA-F]{6}$/.test(colorPicker.pendingHex) ? 1.0 : 0.5
                          Behavior on color { ColorAnimation { duration: 120 } }
                          Text {
                            anchors.centerIn: parent
                            text: "Apply"
                            color: MatugenColors.accentText
                            font.pixelSize: s(10); font.weight: Font.Bold
                            font.family: "JetBrainsMono Nerd Font"
                          }
                          MouseArea {
                            id: applyHover
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              if (!/^#[0-9a-fA-F]{6}$/.test(colorPicker.pendingHex)) return
                              editForm.color = colorPicker.pendingHex
                              colorPicker.open = false
                            }
                          }
                        }
                      }
                    }
                  }

                  Column {
                    width: parent.width; spacing: 8
                    z: 50
                    Text { text: "Alerts"; color: MatugenColors.textMuted; font.pixelSize: s(10); font.family: "JetBrainsMono Nerd Font"; leftPadding: 4 }

                    Repeater {
                      model: editForm.visibleReminderSlots
                      AlertField {
                        required property int index
                        width: parent.width
                        label: index === 0 ? "Alert:" : ("Alert " + (index + 1) + ":")
                        allDay: editForm.allDay
                        reminder: index < editForm.reminders.length ? editForm.reminders[index] : null
                        usedKeys: editForm.usedKeysExcept(index)
                        onReminderEdited: function(r) { editForm.setReminderAt(index, r) }
                      }
                    }
                  }

                  Row {
                    width: parent.width - 8
                    anchors.right: parent.right
                    height: s(34)
                    spacing: s(8)

                    Rectangle {
                      width: dayPanel.editingId !== "" ? (parent.width - 8) * 0.32 : 0
                      height: s(34); radius: s(8)
                      visible: dayPanel.editingId !== ""
                      color: deleteHover.containsMouse ? MatugenColors.error : MatugenColors.bgElevated2
                      Behavior on color { ColorAnimation { duration: 150 } }
                      Text {
                        anchors.centerIn: parent
                        text: "Delete"
                        color: deleteHover.containsMouse ? MatugenColors.bgBase : MatugenColors.error
                        font.pixelSize: s(11); font.weight: Font.Bold
                        font.family: "JetBrainsMono Nerd Font"
                      }
                      MouseArea {
                        id: deleteHover
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          eventStore.removeEvent(dayPanel.editingId)
                          dayPanel.mode = "list"
                          editForm.title = ""
                        }
                      }
                    }

                    Rectangle {
                      width: dayPanel.editingId !== "" ? parent.width - (parent.width - 8) * 0.32 - 8 : parent.width
                      height: s(34); radius: s(8)
                      color: saveHover.containsMouse ? Qt.lighter(MatugenColors.accent, 1.1) : MatugenColors.accent
                      opacity: editForm.title.trim().length > 0 ? 1.0 : 0.5
                      Behavior on color { ColorAnimation { duration: 150 } }
                      Text {
                        anchors.centerIn: parent
                        text: "Save"
                        color: MatugenColors.accentText
                        font.pixelSize: s(11); font.weight: Font.Bold
                        font.family: "JetBrainsMono Nerd Font"
                      }
                      MouseArea {
                        id: saveHover
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          if (editForm.title.trim().length === 0) return
                          var payload = {
                            title: editForm.title.trim(),
                            startDate: editForm.startDate,
                            endDate: editForm.endDate,
                            allDay: editForm.allDay,
                            startMin: editForm.startMin,
                            endMin: editForm.endMin,
                            color: editForm.color,
                            reminders: editForm.reminderList(),
                            notes: editForm.notes,
                            travelTime: editForm.travelTime,
                            repeat: editForm.repeatValue()
                          }
                          if (dayPanel.editingId === "")
                            eventStore.addEvent(payload)
                          else
                            eventStore.updateEvent(dayPanel.editingId, payload)
                          dayPanel.mode = "list"
                          editForm.title = ""
                        }
                      }
                    }
                  }
                }
              }
            }
          } // end dayPanel Item

          } // end daySide
        }
      }
    }
  }
}
