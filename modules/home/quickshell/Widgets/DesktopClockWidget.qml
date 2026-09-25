import QtQuick
import Quickshell
import ".."
import "../Singletons"

Item {
  id: root
  anchors.fill: parent

  // Set by DesktopWidgetFrame's control panel; falls back to digital.
  // Sizing itself comes from Config.clockVariants (digital 638x338,
  // analog 480x370) applied by the frame when the variant is switched.
  property string variant: "digital"

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  Rectangle {
    anchors.fill: parent
    radius: 18
    visible: root.variant !== "minimal"
    color: MatugenColors.bgBase
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1
  }

  // ── Minimal ──
  Text {
    anchors.centerIn: parent
    visible: root.variant === "minimal"
    text: {
      let fmt = Config.clock24h ? "hh:mm" : "h:mm AP"
      if (Config.showClockSeconds) fmt = Config.clock24h ? "hh:mm:ss" : "h:mm:ss AP"
      return Qt.formatDateTime(clock.date, fmt)
    }
    color: MatugenColors.text
    font.pixelSize: Math.min(root.width, root.height) * 0.22
    font.weight: Font.Bold
    font.family: Config.fontFamily
  }

  // ── Digital ──
  Column {
    anchors.centerIn: parent
    spacing: 2
    visible: root.variant !== "analog" && root.variant !== "minimal"

    Text {
      text: {
        let fmt = Config.clock24h ? "hh:mm" : "h:mm AP"
        if (Config.showClockSeconds) fmt = Config.clock24h ? "hh:mm:ss" : "h:mm:ss AP"
        return Qt.formatDateTime(clock.date, fmt)
      }
      color: MatugenColors.text
      font.pixelSize: Math.min(root.width, root.height) * 0.22
      font.weight: Font.Bold
      font.family: Config.fontFamily
      anchors.horizontalCenter: parent.horizontalCenter
    }

    Text {
      text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
      color: MatugenColors.textMuted
      font.pixelSize: Math.min(root.width, root.height) * 0.08
      font.family: Config.fontFamily
      anchors.horizontalCenter: parent.horizontalCenter
    }
  }

  // ── Analog ──
  Item {
    id: dial
    anchors.centerIn: parent
    visible: root.variant === "analog"
    readonly property real dSize: Math.min(root.width, root.height) * 0.86
    width: dSize
    height: dSize

    readonly property real seconds: clock.date.getSeconds()
    readonly property real minutes: clock.date.getMinutes() + seconds / 60
    readonly property real hours: (clock.date.getHours() % 12) + minutes / 60

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: "transparent"
      border.width: Math.max(2, parent.width * 0.02)
      border.color: Qt.rgba(1, 1, 1, 0.16)
    }

    // Ticks: two rings, hour marks (thick/long, every 30°) and minute
    // marks (thin/short, every 6°, with every 5th one matching the hour
    // tick's size). Each tick sits inside a full-size wrapper Item that
    // is itself rotated around its own center - rotating the wrapper
    // avoids the origin math that caused ticks to drift off-center.
    Repeater {
      model: 12
      delegate: Item {
        id: hourTickWrap
        required property int index
        width: dial.width
        height: dial.height
        anchors.centerIn: dial
        rotation: hourTickWrap.index * 30
        transformOrigin: Item.Center

        Rectangle {
          width: Math.max(2, dial.width * 0.012)
          height: dial.height * 0.07
          radius: width / 2
          color: MatugenColors.textMuted
          anchors.horizontalCenter: parent.horizontalCenter
          y: dial.height * 0.03
        }
      }
    }

    Repeater {
      model: 60
      delegate: Item {
        id: minuteTickWrap
        required property int index
        width: dial.width
        height: dial.height
        anchors.centerIn: dial
        rotation: minuteTickWrap.index * 6
        transformOrigin: Item.Center
        visible: minuteTickWrap.index % 5 !== 0 // hour ring already covers these

        Rectangle {
          width: Math.max(1, dial.width * 0.006)
          height: dial.height * 0.035
          radius: width / 2
          color: MatugenColors.textMuted
          anchors.horizontalCenter: parent.horizontalCenter
          y: dial.height * 0.03
          opacity: 0.7
        }
      }
    }

    // Hour hand
    Rectangle {
      width: Math.max(3, parent.width * 0.028)
      height: parent.height * 0.26
      radius: width / 2
      color: MatugenColors.text
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.verticalCenter
      transformOrigin: Item.Bottom
      rotation: parent.hours * 30
    }

    // Minute hand
    Rectangle {
      width: Math.max(2, parent.width * 0.02)
      height: parent.height * 0.36
      radius: width / 2
      color: MatugenColors.text
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.verticalCenter
      transformOrigin: Item.Bottom
      rotation: parent.minutes * 6
    }

    // Second hand
    Rectangle {
      visible: Config.showClockSeconds
      width: Math.max(1, parent.width * 0.008)
      height: parent.height * 0.4
      radius: width / 2
      color: MatugenColors.accent
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.verticalCenter
      transformOrigin: Item.Bottom
      rotation: parent.seconds * 6
    }

    Rectangle {
      width: parent.width * 0.04
      height: width
      radius: width / 2
      anchors.centerIn: parent
      color: MatugenColors.accent
    }
  }
}
