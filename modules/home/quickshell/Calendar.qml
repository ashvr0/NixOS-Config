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
    anchors.margins: 8
    verticalAlignment: TextInput.AlignVCenter
    font.pixelSize: 11
    font.family: "JetBrainsMono Nerd Font"
    color: MatugenColors.text
    clip: true
    text: field.text

    Text {
      anchors.fill: parent
      verticalAlignment: Text.AlignVCenter
      text: field.placeholderText
      color: MatugenColors.textMuted
      font.pixelSize: 11
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

  signal reminderEdited(var reminder)

  readonly property bool active: reminder !== null
  readonly property var options: allDay ? [
    { key: "none",   text: "None",              amount: 0,  unit: "days" },
    { key: "atstart", text: "At start of day",  amount: 0,  unit: "days" },
    { key: "d1",     text: "1 day before",       amount: 1,  unit: "days" },
    { key: "d2",     text: "2 days before",      amount: 2,  unit: "days" },
    { key: "w1",     text: "1 week before",      amount: 1,  unit: "weeks" },
    { key: "custom", text: "Custom",             amount: -1, unit: "custom" }
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
    { key: "d2",     text: "2 days before",       amount: 2,  unit: "days" },
    { key: "custom", text: "Custom",              amount: -1, unit: "custom" }
  ]

  function matchIndex() {
    if (!root.active) return 0
    for (var i = 0; i < options.length; i++) {
      var o = options[i]
      if (o.key === "none" || o.key === "custom") continue
      if (o.amount === root.reminder.amount && o.unit === root.reminder.unit) return i
    }
    return options.length - 1
  }

  readonly property string currentText: {
    if (!root.active) return "None"
    var idx = matchIndex()
    if (options[idx].key === "custom") {
      var amt = root.reminder.amount
      var u = root.reminder.unit
      var uLabel = u === "minutes" ? (amt === 1 ? "minute" : "minutes")
                 : u === "hours"   ? (amt === 1 ? "hour" : "hours")
                 : u === "days"    ? (amt === 1 ? "day" : "days")
                 : (amt === 1 ? "week" : "weeks")
      return amt + " " + uLabel + " before"
    }
    return options[idx].text
  }

  width: parent ? parent.width : 200
  height: 34
  z: expanded ? 1000 : 1
  clip: false

  property bool expanded: false
  property bool customMode: false
  property int customAmount: 10
  property string customUnit: allDay ? "days" : "minutes"

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
        font.pixelSize: 10
        font.family: "JetBrainsMono Nerd Font"
      }

      Text {
        text: root.currentText
        color: MatugenColors.text
        font.pixelSize: 11
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
      font.pixelSize: 8
      font.family: "JetBrainsMono Nerd Font"
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.customMode = false
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
    onClicked: { root.expanded = false; root.customMode = false }
  }

  Rectangle {
    id: dropdown
    parent: calPopup.contentItem
    x: { var p = root.mapToItem(calPopup.contentItem, 0, 34 + 4); return root.x, root.y, p.x }
    y: { var p = root.mapToItem(calPopup.contentItem, 0, 34 + 4); return root.x, root.y, p.y }
    width: root.width
    height: root.customMode ? customCol.implicitHeight + 16 : optCol.implicitHeight + 8
    radius: 8
    color: MatugenColors.bgElevated2
    border.width: 1
    border.color: MatugenColors.borderSoft
    visible: root.expanded
    z: 1000
    clip: true

    Column {
      id: optCol
      visible: !root.customMode
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
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.text
            color: MatugenColors.text
            font.pixelSize: 10
            font.family: "JetBrainsMono Nerd Font"
          }

          MouseArea {
            id: optHover
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (modelData.key === "none") {
                root.reminderEdited(null)
                root.expanded = false
              } else if (modelData.key === "custom") {
                root.customAmount = root.allDay ? 1 : 10
                root.customUnit = root.allDay ? "days" : "minutes"
                root.customMode = true
              } else {
                root.reminderEdited({ amount: modelData.amount, unit: modelData.unit })
                root.expanded = false
              }
            }
          }
        }
      }
    }

    Column {
      id: customCol
      visible: root.customMode
      width: parent.width
      anchors.margins: 8
      anchors.fill: parent
      spacing: 8

      Row {
        width: parent.width
        spacing: 6

        Rectangle {
          width: 22; height: 24; radius: 5
          color: custMinus.containsMouse ? MatugenColors.bgElevated : "transparent"
          Text { anchors.centerIn: parent; text: "−"; color: MatugenColors.accent; font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font" }
          MouseArea {
            id: custMinus
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: {
              var minV = root.customUnit === "days" && root.allDay ? 0 : 1
              root.customAmount = Math.max(minV, root.customAmount - 1)
            }
          }
        }

        Text {
          width: 30
          horizontalAlignment: Text.AlignHCenter
          anchors.verticalCenter: parent.verticalCenter
          text: root.customAmount.toString()
          color: MatugenColors.text
          font.pixelSize: 12; font.weight: Font.Bold
          font.family: "JetBrainsMono Nerd Font"
        }

        Rectangle {
          width: 22; height: 24; radius: 5
          color: custPlus.containsMouse ? MatugenColors.bgElevated : "transparent"
          Text { anchors.centerIn: parent; text: "+"; color: MatugenColors.accent; font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font" }
          MouseArea {
            id: custPlus
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: {
              var maxV = root.customUnit === "minutes" ? 59 : (root.customUnit === "hours" ? 23 : (root.customUnit === "days" ? 14 : 4))
              root.customAmount = Math.min(maxV, root.customAmount + 1)
            }
          }
        }

        Row {
          spacing: 2
          anchors.verticalCenter: parent.verticalCenter
          Repeater {
            model: root.allDay ? ["days", "weeks"] : ["minutes", "hours", "days", "weeks"]
            Rectangle {
              required property string modelData
              height: 24
              width: unitTxt.implicitWidth + 12
              radius: 5
              color: root.customUnit === modelData ? MatugenColors.accent : (unitOptHover.containsMouse ? MatugenColors.bgElevated : "transparent")
              Behavior on color { ColorAnimation { duration: 120 } }

              Text {
                id: unitTxt
                anchors.centerIn: parent
                text: modelData
                color: root.customUnit === modelData ? MatugenColors.accentText : MatugenColors.text
                font.pixelSize: 9
                font.family: "JetBrainsMono Nerd Font"
              }

              MouseArea {
                id: unitOptHover
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.customUnit = modelData
                  var maxV = modelData === "minutes" ? 59 : (modelData === "hours" ? 23 : (modelData === "days" ? 14 : 4))
                  var minV = modelData === "days" && root.allDay ? 0 : 1
                  root.customAmount = Math.max(minV, Math.min(maxV, root.customAmount))
                }
              }
            }
          }
        }
      }

      Rectangle {
        width: parent.width
        height: 26
        radius: 6
        color: custConfirmHover.containsMouse ? Qt.lighter(MatugenColors.accent, 1.1) : MatugenColors.accent
        Behavior on color { ColorAnimation { duration: 120 } }
        Text {
          anchors.centerIn: parent
          text: "Set"
          color: MatugenColors.accentText
          font.pixelSize: 10; font.weight: Font.Bold
          font.family: "JetBrainsMono Nerd Font"
        }
        MouseArea {
          id: custConfirmHover
          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.reminderEdited({ amount: root.customAmount, unit: root.customUnit })
            root.customMode = false
            root.expanded = false
          }
        }
      }
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
  height: 24
  radius: 4
  color: segInput.activeFocus ? MatugenColors.bgElevated2 : (segHover.containsMouse ? MatugenColors.bgElevated2 : "transparent")
  border.width: segInput.activeFocus ? 1 : 0
  border.color: MatugenColors.accent

  TextInput {
    id: segInput
    anchors.centerIn: parent
    text: seg.display
    color: MatugenColors.text
    font.pixelSize: 11
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

    Text { text: "/"; color: MatugenColors.textMuted; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }

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

    Text { text: "/"; color: MatugenColors.textMuted; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }

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
      display: root._pad2(root._hour12)
      minVal: 1; maxVal: 12; padLen: 2
      onCommitted: function(v) {
        var h24 = root._isPM ? (v === 12 ? 12 : v + 12) : (v === 12 ? 0 : v)
        root.minutesEdited(h24 * 60 + root._minPart)
      }
      onWheeled: function(dir) {
        var nv = root.minutes + dir * 60
        if (nv < 0) nv += 1440
        if (nv >= 1440) nv -= 1440
        root.minutesEdited(nv)
      }
    }

    Text { visible: root.showTime; text: ":"; color: MatugenColors.textMuted; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }

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

    Item { width: root.showTime ? 6 : 0; height: 1 }

    Rectangle {
      visible: root.showTime
      width: ampmTxt.implicitWidth + 8; height: 24; radius: 4
      color: ampmHover.containsMouse ? MatugenColors.bgElevated2 : "transparent"
      anchors.verticalCenter: parent.verticalCenter
      Text {
        id: ampmTxt
        anchors.centerIn: parent
        text: root._isPM ? "PM" : "AM"
        color: MatugenColors.text
        font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
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

  implicitWidth: pillBg.width
  implicitHeight: pillBg.height

  property int cascadeIndex: 3
  property bool entered: false
  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }
  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutBack } } }
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

    function _uid() {
      return "ev_" + Date.now() + "_" + Math.floor(Math.random() * 100000)
    }

    function _cmpDate(a, b) {
      return a < b ? -1 : (a > b ? 1 : 0)
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
        reminders: (payload.reminders || []).slice(0, 2)
      }
      if (_cmpDate(ev.endDate, ev.startDate) < 0) ev.endDate = ev.startDate
      var list = events.slice()
      list.push(ev)
      events = list
      return ev.id
    }

    function updateEvent(id, payload) {
      var list = events.slice()
      for (var i = 0; i < list.length; i++) {
        if (list[i].id === id) {
          var ev = Object.assign({}, list[i], payload)
          ev.endDate = payload.endDate || payload.startDate || ev.endDate
          if (_cmpDate(ev.endDate, ev.startDate) < 0) ev.endDate = ev.startDate
          ev.reminders = (payload.reminders || ev.reminders || []).slice(0, 2)
          list[i] = ev
          break
        }
      }
      events = list
    }

    function removeEvent(id) {
      events = events.filter(function(e) { return e.id !== id })
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

  // Clock Pill
  Rectangle {
    id: pillBg
    height: 50
    width: col.implicitWidth + 28
    radius: 14
    color: pillMouse.containsMouse || calPopup.calendarOpen ? Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.85) : Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.75)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    anchors.verticalCenter: parent.verticalCenter

    scale: pillMouse.containsMouse ? 1.04 : 1.0
    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
    Behavior on color { ColorAnimation { duration: 200 } }

    Column {
      id: col
      anchors.centerIn: parent
      spacing: 2

      Text {
        text: Qt.formatDateTime(clock.date, "hh:mm:ss")
        color: MatugenColors.text
        font.pixelSize: 15
        font.weight: Font.Bold
        font.family: "JetBrainsMono Nerd Font"
        anchors.horizontalCenter: parent.horizontalCenter
      }

      Text {
        text: Qt.formatDateTime(clock.date, "ddd MMM d")
        color: calPopup.calendarOpen ? MatugenColors.accent : MatugenColors.textMuted
        font.pixelSize: 10
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
      var ampm = h >= 24 ? "" : ""
      var h24 = h % 24 === 0 ? 24 : h % 24
      var mm = m < 10 ? "0" + m : "" + m
      return h24 + ":" + mm + " " + ampm
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

      Rectangle {
        id: calCard
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 70
        anchors.rightMargin: 8
        width: 410
        radius: 10
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

        Column {
          id: calColumn
          anchors.fill: parent
          anchors.margins: 16
          spacing: 12

          Item {
            width: parent.width
            height: 26

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: Qt.locale().standaloneMonthName(calGrid.viewMonth, Locale.LongFormat) + "  " + calGrid.viewYear
              color: MatugenColors.text; font.pixelSize: 13; font.weight: Font.Bold
              font.family: "JetBrainsMono Nerd Font"
            }

            Row {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: 4

              Rectangle {
                width: 26; height: 26; radius: 6
                color: prevMonthArea.containsMouse ? MatugenColors.bgElevated : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                  anchors.centerIn: parent
                  text: "‹"
                  color: MatugenColors.accent; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"
                }
                MouseArea {
                  id: prevMonthArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    calGrid.viewMonth -= 1
                    if (calGrid.viewMonth < 0) {
                      calGrid.viewMonth = 11
                      calGrid.viewYear -= 1
                    }
                  }
                }
              }

              Rectangle {
                width: 26; height: 26; radius: 6
                color: nextMonthArea.containsMouse ? MatugenColors.bgElevated : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                  anchors.centerIn: parent
                  text: "›"
                  color: MatugenColors.accent; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"
                }
                MouseArea {
                  id: nextMonthArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    calGrid.viewMonth += 1
                    if (calGrid.viewMonth > 11) {
                      calGrid.viewMonth = 0
                      calGrid.viewYear += 1
                    }
                  }
                }
              }

              Rectangle {
                width: 26; height: 26; radius: 6
                color: addEventHover.containsMouse ? MatugenColors.accentSoft : MatugenColors.bgElevated
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                  anchors.centerIn: parent
                  text: "+"
                  color: MatugenColors.accent
                  font.pixelSize: 14; font.weight: Font.Bold
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
                    editForm.reminder1 = null
                    editForm.reminder2 = null
                  }
                }
              }
            }
          }

          Row {
            width: parent.width
            height: 24
            Repeater {
              model: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
              Text {
                required property string modelData
                width: parent.width / 7
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: MatugenColors.textMuted; font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"
              }
            }
          }

          GridLayout {
            id: calGrid
            width: parent.width
            columns: 7
            property int viewMonth: 0
            property int viewYear: 2024
            property var datesMap: eventStore.datesWithEvents()

            Repeater {
              model: 42
              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
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
                  font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
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
          }

          Item {
            width: parent.width
            height: dayPanel.panelHeight
            clip: true

            Rectangle {
              anchors.fill: parent
              radius: 10
              color: MatugenColors.bgElevated2
              opacity: dayPanel.mode !== "hidden" ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            Column {
              id: dayPanel
              width: parent.width
              anchors.margins: dayPanel.mode !== "hidden" ? 12 : 0
              spacing: 8

              property string selectedDate: ""
              property string mode: "hidden"
              property string editingId: ""
              property real panelHeight: mode !== "hidden" ? contentCol.implicitHeight + 24 : 0

              Behavior on anchors.margins { NumberAnimation { duration: 200 } }
              Behavior on panelHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

              function minToTime(m) { return calPopup._minToTime(m) }

              Column {
                id: contentCol
                width: parent.width
                spacing: 8

                Text {
                  visible: dayPanel.mode === "list"
                  text: calPopup._formatKeyShort(dayPanel.selectedDate)
                  color: MatugenColors.text; font.pixelSize: 12; font.weight: Font.Bold
                  font.family: "JetBrainsMono Nerd Font"
                }

                Column {
                  visible: dayPanel.mode === "list"
                  width: parent.width
                  spacing: 6

                  Repeater {
                    model: dayPanel.mode === "list" ? eventStore.eventsForDate(dayPanel.selectedDate) : []
                    Rectangle {
                      required property var modelData
                      width: parent.width
                      height: 50; radius: 8
                      color: eventHover.containsMouse ? Qt.darker(modelData.color, 1.15) : modelData.color
                      opacity: 0.8
                      Behavior on color { ColorAnimation { duration: 150 } }

                      Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 2

                        Text {
                          text: modelData.title
                          color: "white"
                          font.pixelSize: 11; font.weight: Font.Bold
                          font.family: "JetBrainsMono Nerd Font"
                        }

                        Text {
                          text: modelData.allDay ? "All-day" : (calPopup._minToTime(modelData.startMin) + " – " + calPopup._minToTime(modelData.endMin))
                          color: "white"
                          font.pixelSize: 9
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
                          editForm.reminder1 = modelData.reminders[0] || null
                          editForm.reminder2 = modelData.reminders[1] || null
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
                    font.pixelSize: 10
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
                    property var reminder1: null
                    property var reminder2: null


                    function reminderList() {
                      var list = []
                      if (reminder1) list.push(reminder1)
                      if (reminder2) list.push(reminder2)
                      return list
                    }
                  }

                  TextField {
                    id: titleField
                    width: parent.width
                    height: 34
                    placeholderText: "Title"
                    text: editForm.title
                    onTextChanged: if (text !== editForm.title) editForm.title = text
                  }

                  Item {
                    width: parent.width
                    height: 22

                    Text {
                      anchors.left: parent.left
                      anchors.leftMargin: 4
                      anchors.verticalCenter: parent.verticalCenter
                      text: "All-day"
                      color: MatugenColors.text
                      font.pixelSize: 10
                      font.family: "JetBrainsMono Nerd Font"
                    }

                    Rectangle {
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      width: 32; height: 18; radius: 9
                      color: editForm.allDay ? MatugenColors.accent : "transparent"
                      border.color: MatugenColors.borderSoft
                      border.width: editForm.allDay ? 0 : 1
                      Behavior on color { ColorAnimation { duration: 150 } }
                      Rectangle {
                        width: 12; height: 12; radius: 6
                        color: editForm.allDay ? MatugenColors.bgBase : MatugenColors.borderSoft
                        anchors.verticalCenter: parent.verticalCenter
                        x: editForm.allDay ? parent.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                      }
                      MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: editForm.allDay = !editForm.allDay
                      }
                    }
                  }

                  Column {
                    width: parent.width; spacing: 8

                    Row {
                      width: parent.width; height: 34; spacing: 6

                      Text {
                        id: startsLabel
                        width: 48
                        leftPadding: 4
                        text: "Starts:"
                        color: MatugenColors.textMuted
                        font.pixelSize: 10
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      Rectangle {
                        width: parent.width - startsLabel.width - parent.spacing
                        height: 34; radius: 8
                        color: MatugenColors.bgElevated

                        DateTimeField {
                          anchors.left: parent.left
                          anchors.leftMargin: 6
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
                      width: parent.width; height: 34; spacing: 6

                      Text {
                        id: endsLabel
                        width: 48
                        leftPadding: 4
                        text: "Ends:"
                        color: MatugenColors.textMuted
                        font.pixelSize: 10
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      Rectangle {
                        width: parent.width - endsLabel.width - parent.spacing
                        height: 34; radius: 8
                        color: MatugenColors.bgElevated

                        DateTimeField {
                          anchors.left: parent.left
                          anchors.leftMargin: 6
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

                  Column {
                    width: parent.width; spacing: 6
                    Text { text: "Color"; color: MatugenColors.textMuted; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; leftPadding: 4 }
                    Row {
                      leftPadding: 4
                      spacing: 8
                      Repeater {
                        model: eventStore.palette
                        Rectangle {
                          required property string modelData
                          width: 22; height: 22; radius: 11
                          color: modelData
                          border.width: editForm.color === modelData ? 2 : 0
                          border.color: MatugenColors.text
                          scale: swatchHover.containsMouse ? 1.15 : 1.0
                          Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                          MouseArea {
                            id: swatchHover
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: editForm.color = modelData
                          }
                        }
                      }
                    }
                  }

                  Column {
                    width: parent.width; spacing: 8
                    z: 50
                    Text { text: "Alerts"; color: MatugenColors.textMuted; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; leftPadding: 4 }

                    AlertField {
                      width: parent.width
                      label: "Alert:"
                      allDay: editForm.allDay
                      reminder: editForm.reminder1
                      onReminderEdited: function(r) { editForm.reminder1 = r }
                    }

                    AlertField {
                      width: parent.width
                      label: "2nd alert:"
                      allDay: editForm.allDay
                      reminder: editForm.reminder2
                      onReminderEdited: function(r) { editForm.reminder2 = r }
                    }
                  }

                  Row {
                    width: parent.width - 8
                    anchors.right: parent.right
                    height: 34
                    spacing: 8

                    Rectangle {
                      width: dayPanel.editingId !== "" ? (parent.width - 8) * 0.32 : 0
                      height: 34; radius: 8
                      visible: dayPanel.editingId !== ""
                      color: deleteHover.containsMouse ? MatugenColors.error : MatugenColors.bgElevated2
                      Behavior on color { ColorAnimation { duration: 150 } }
                      Text {
                        anchors.centerIn: parent
                        text: "Delete"
                        color: deleteHover.containsMouse ? MatugenColors.bgBase : MatugenColors.error
                        font.pixelSize: 11; font.weight: Font.Bold
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
                      height: 34; radius: 8
                      color: saveHover.containsMouse ? Qt.lighter(MatugenColors.accent, 1.1) : MatugenColors.accent
                      opacity: editForm.title.trim().length > 0 ? 1.0 : 0.5
                      Behavior on color { ColorAnimation { duration: 150 } }
                      Text {
                        anchors.centerIn: parent
                        text: "Save"
                        color: MatugenColors.accentText
                        font.pixelSize: 11; font.weight: Font.Bold
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
                            reminders: editForm.reminderList()
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
          }
        }
      }
    }
  }
}
