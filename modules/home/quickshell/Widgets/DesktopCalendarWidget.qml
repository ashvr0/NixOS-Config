import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../Singletons"

Item {
  id: root
  anchors.fill: parent
  property string variant: "month"

  Loader {
    anchors.fill: parent
    sourceComponent: {
      switch (root.variant) {
        case "small": return smallComp
        case "wide": return wideComp
        case "date": return dateComp
        default: return monthComp
      }
    }
  }

  QtObject {
    id: eventsData

    readonly property date today: new Date()

    function _keyFromDate(d) {
      var mm = (d.getMonth() + 1) < 10 ? "0" + (d.getMonth() + 1) : "" + (d.getMonth() + 1)
      var dd = d.getDate() < 10 ? "0" + d.getDate() : "" + d.getDate()
      return d.getFullYear() + "-" + mm + "-" + dd
    }

    readonly property string todayKey: _keyFromDate(eventsData.today)
    readonly property int nowMin: eventsData.today.getHours() * 60 + eventsData.today.getMinutes()

    property var events: []

    function _load() {
      try {
        var raw = eventsFile.text
        if (raw && raw.trim().length > 0) {
          var data = JSON.parse(raw)
          if (data && Array.isArray(data.events)) eventsData.events = data.events
        }
      } catch (e) {}
    }

    function fmtTime(min) {
      var h = Math.floor(min / 60)
      var m = min % 60
      var ampm = h >= 12 ? "PM" : "AM"
      var h12 = h % 12 === 0 ? 12 : h % 12
      var mStr = m < 10 ? "0" + m : "" + m
      return h12 + ":" + mStr + " " + ampm
    }

    function fmtEventDate(dateKey) {
      var parts = dateKey.split("-")
      var d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]))
      return Qt.formatDate(d, "ddd d MMM").toUpperCase()
    }

    readonly property var todaysEvents: {
      var out = []
      for (var i = 0; i < events.length; i++) {
        var ev = events[i]
        if (todayKey >= ev.startDate && todayKey <= (ev.endDate || ev.startDate)) out.push(ev)
      }
      out.sort(function(a, b) {
        if (a.allDay !== b.allDay) return a.allDay ? -1 : 1
        return (a.startMin || 0) - (b.startMin || 0)
      })
      return out
    }

    readonly property string nextEventLabel: {
      if (todaysEvents.length === 0) return "No Events Today"
      var ev = todaysEvents[0]
      if (ev.allDay) return ev.title
      return fmtTime(ev.startMin) + " " + ev.title
    }

    readonly property var currentEvent: {
      var happening = null
      var upcoming = null
      for (var i = 0; i < todaysEvents.length; i++) {
        var ev = todaysEvents[i]
        if (ev.allDay) { if (!happening) happening = ev; continue }
        if (nowMin >= ev.startMin && nowMin <= ev.endMin) { happening = ev; break }
        if (!upcoming && ev.startMin > nowMin) upcoming = ev
      }
      return happening || upcoming || null
    }

    readonly property string currentEventLabel: {
      if (!currentEvent) return "No Events Today"
      if (currentEvent.allDay) return currentEvent.title
      return fmtTime(currentEvent.startMin) + " " + currentEvent.title
    }

    readonly property var futureEvents: {
      var out = []
      for (var i = 0; i < events.length; i++) {
        var ev = events[i]
        if (ev.startDate > todayKey) out.push(ev)
      }
      out.sort(function(a, b) { return a.startDate < b.startDate ? -1 : (a.startDate > b.startDate ? 1 : 0) })
      return out.slice(0, 4)
    }
  }

  FileView {
    id: eventsFile
    path: Quickshell.env("HOME") + "/.config/quickshell/Calendar/calendar-events.json"
    printErrors: true
    watchChanges: true
    onLoaded: eventsData._load()
    onLoadFailed: function(error) {}
    onFileChanged: reload()
    Component.onCompleted: reload()
  }

  component CalendarCard: Rectangle {
    radius: 18
    color: MatugenColors.bgBase
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1
  }

  // ── Month grid ──────────────────────────────────────────────────
  Component {
    id: monthComp

    Item {
      id: monthRoot
      anchors.fill: parent

      property date viewDate: new Date()
      readonly property date today: new Date()
      readonly property int viewYear: viewDate.getFullYear()
      readonly property int viewMonth: viewDate.getMonth()
      function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate() }
      function firstWeekday(y, m) { return new Date(y, m, 1).getDay() }

      readonly property var gridCells: {
        let cells = []
        let total = daysInMonth(viewYear, viewMonth)
        let lead = firstWeekday(viewYear, viewMonth)
        for (let i = 0; i < lead; i++) cells.push(null)
        for (let d = 1; d <= total; d++) cells.push(d)
        return cells
      }

      function isToday(d) {
        return d !== null
          && monthRoot.today.getFullYear() === monthRoot.viewYear
          && monthRoot.today.getMonth() === monthRoot.viewMonth
          && monthRoot.today.getDate() === d
      }

      CalendarCard { anchors.fill: parent }

      Column {
        id: mainCol
        anchors.fill: parent
        anchors.margins: Math.min(monthRoot.width, monthRoot.height) * 0.06
        spacing: 8

        // Header: month/year + nav arrows
        Row {
          width: parent.width
          height: Math.min(monthRoot.width, monthRoot.height) * 0.1

          Text {
            text: "\uf104"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Math.min(monthRoot.width, monthRoot.height) * 0.06
            color: prevMa.containsMouse ? MatugenColors.accent : MatugenColors.textDim
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.12
            MouseArea { id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: monthRoot.viewDate = new Date(monthRoot.viewYear, monthRoot.viewMonth - 1, 1) }
          }

          Text {
            text: Qt.formatDate(monthRoot.viewDate, "MMMM yyyy")
            font.family: Config.fontFamily
            font.weight: Font.Bold
            font.pixelSize: Math.min(monthRoot.width, monthRoot.height) * 0.065
            color: MatugenColors.text
            horizontalAlignment: Text.AlignHCenter
            width: parent.width * 0.76
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: "\uf105"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Math.min(monthRoot.width, monthRoot.height) * 0.06
            color: nextMa.containsMouse ? MatugenColors.accent : MatugenColors.textDim
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.12
            MouseArea { id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: monthRoot.viewDate = new Date(monthRoot.viewYear, monthRoot.viewMonth + 1, 1) }
          }
        }

        // Weekday header
        Row {
          width: parent.width
          Repeater {
            model: ["S", "M", "T", "W", "T", "F", "S"]
            delegate: Text {
              required property string modelData
              width: mainCol.width / 7
              horizontalAlignment: Text.AlignHCenter
              text: modelData
              font.pixelSize: Math.min(monthRoot.width, monthRoot.height) * 0.04
              font.weight: Font.Bold
              font.family: Config.fontFamily
              color: MatugenColors.textDim
            }
          }
        }
        
        Grid {
          id: dayGrid
          width: mainCol.width
          columns: 7
          readonly property real cellSize: mainCol.width / 7

          Repeater {
            model: monthRoot.gridCells
            delegate: Item {
              required property var modelData
              width: dayGrid.cellSize
              height: dayGrid.cellSize

              Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) * 0.72
                height: width
                radius: width / 2
                visible: modelData !== null
                color: monthRoot.isToday(modelData) ? MatugenColors.accent : "transparent"

                Text {
                  anchors.centerIn: parent
                  text: modelData !== null ? modelData : ""
                  font.pixelSize: Math.min(monthRoot.width, monthRoot.height) * 0.045
                  font.weight: monthRoot.isToday(modelData) ? Font.Bold : Font.Normal
                  font.family: Config.fontFamily
                  color: monthRoot.isToday(modelData) ? MatugenColors.accentText : MatugenColors.text
                }
              }
            }
          }
        }
      }
    }
  }

  // ── Small (today + next event) ─────────────────────────────────
  Component {
    id: smallComp

    Item {
      id: smallRoot
      anchors.fill: parent

      CalendarCard { anchors.fill: parent }

      Column {
        anchors.fill: parent
        anchors.margins: Math.min(smallRoot.width, smallRoot.height) * 0.14
        spacing: Math.min(smallRoot.width, smallRoot.height) * 0.04

        Text {
          text: Qt.formatDate(eventsData.today, "ddd").toUpperCase()
          font.family: Config.fontFamily
          font.weight: Font.Bold
          font.pixelSize: Math.min(smallRoot.width, smallRoot.height) * 0.09
          color: MatugenColors.textDim
        }

        Text {
          text: eventsData.today.getDate()
          font.family: Config.fontFamily
          font.weight: Font.Bold
          font.pixelSize: Math.min(smallRoot.width, smallRoot.height) * 0.15
          color: MatugenColors.text
        }

        Item { width: 1; height: Math.min(smallRoot.width, smallRoot.height) * 0.02 }

        Text {
          width: parent.width
          text: eventsData.nextEventLabel
          font.family: Config.fontFamily
          font.pixelSize: Math.min(smallRoot.width, smallRoot.height) * 0.06
          color: MatugenColors.textDim
          wrapMode: Text.WordWrap
          maximumLineCount: 2
          elide: Text.ElideRight
        }
      }
    }
  }

  // ── Wide (today + up next) ──────────────────────────────────────
  Component {
    id: wideComp

    Item {
      id: wideRoot
      anchors.fill: parent

      CalendarCard { anchors.fill: parent }

      Row {
        anchors.fill: parent
        anchors.margins: Math.min(wideRoot.width, wideRoot.height) * 0.12
        spacing: Math.min(wideRoot.width, wideRoot.height) * 0.1

        // Left: today + current event
        Column {
          width: parent.width * 0.42
          height: parent.height
          spacing: Math.min(wideRoot.width, wideRoot.height) * 0.04

          Text {
            text: Qt.formatDate(eventsData.today, "dddd").toUpperCase()
            font.family: Config.fontFamily
            font.weight: Font.Bold
            font.pixelSize: Math.min(wideRoot.width, wideRoot.height) * 0.1
            color: MatugenColors.textDim
          }

          Text {
            text: eventsData.today.getDate()
            font.family: Config.fontFamily
            font.weight: Font.Bold
            font.pixelSize: Math.min(wideRoot.width, wideRoot.height) * 0.3
            color: MatugenColors.text
          }

          Item { width: 1; height: Math.min(wideRoot.width, wideRoot.height) * 0.02 }

          Text {
            width: parent.width
            text: eventsData.currentEventLabel
            font.family: Config.fontFamily
            font.pixelSize: Math.min(wideRoot.width, wideRoot.height) * 0.075
            color: MatugenColors.textDim
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
          }
        }

        // Right: future events
        Column {
          width: parent.width * 0.58 - parent.spacing
          height: parent.height
          spacing: Math.min(wideRoot.width, wideRoot.height) * 0.05

          Text {
            text: "Up Next"
            font.family: Config.fontFamily
            font.weight: Font.Bold
            font.pixelSize: Math.min(wideRoot.width, wideRoot.height) * 0.08
            color: MatugenColors.text
          }

          Column {
            width: parent.width
            spacing: Math.min(wideRoot.width, wideRoot.height) * 0.045
            visible: eventsData.futureEvents.length === 0

            Text {
              width: parent.width
              text: "Keep track of your upcoming events and meetings."
              font.family: Config.fontFamily
              font.pixelSize: Math.min(wideRoot.width, wideRoot.height) * 0.065
              color: MatugenColors.textDim
              wrapMode: Text.WordWrap
            }
          }

          Column {
            width: parent.width
            spacing: Math.min(wideRoot.width, wideRoot.height) * 0.045
            visible: eventsData.futureEvents.length > 0

            Repeater {
              model: eventsData.futureEvents
              delegate: Row {
                required property var modelData
                width: parent.width
                spacing: Math.min(wideRoot.width, wideRoot.height) * 0.04

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Math.min(wideRoot.width, wideRoot.height) * 0.02
                  height: width
                  radius: width / 2
                  color: modelData.color || "#e8503a"
                }

                Column {
                  width: parent.width - Math.min(wideRoot.width, wideRoot.height) * 0.06
                  spacing: 1

                  Text {
                    text: eventsData.fmtEventDate(modelData.startDate)
                    font.family: Config.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: Math.min(wideRoot.width, wideRoot.height) * 0.055
                    color: MatugenColors.textDim
                  }

                  Text {
                    width: parent.width
                    text: modelData.title
                    font.family: Config.fontFamily
                    font.pixelSize: Math.min(wideRoot.width, wideRoot.height) * 0.07
                    color: MatugenColors.text
                    elide: Text.ElideRight
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  // ── Date only ────────────────────────────────────────────────────
  Component {
    id: dateComp

    Item {
      id: dateRoot
      anchors.fill: parent

      readonly property date today: new Date()

      CalendarCard { anchors.fill: parent }

      Column {
        anchors.centerIn: parent
        width: parent.width * 0.9
        spacing: Math.min(dateRoot.width, dateRoot.height) * 0.05

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: Qt.formatDate(dateRoot.today, "ddd MMM")
          font.family: Config.fontFamily
          font.weight: Font.Bold
          font.pixelSize: Math.min(dateRoot.width, dateRoot.height) * 0.14
          color: MatugenColors.textDim
          topPadding: Math.min(dateRoot.width, dateRoot.height) * 0.10
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: dateRoot.today.getDate()
          font.family: Config.fontFamily
          font.weight: Font.Bold
          font.pixelSize: Math.min(dateRoot.width, dateRoot.height) * 0.5
          color: MatugenColors.text
        }
      }
    }
  }
}
