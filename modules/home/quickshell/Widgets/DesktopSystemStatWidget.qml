import QtQuick
import ".."
import "../Singletons"

Item {
  id: root
  anchors.fill: parent
  property string variant: "cpu"
  readonly property bool isBattery: root.variant === "battery"
  readonly property bool batteryMissing: root.isBattery && !SystemStats.hasBattery
  readonly property string statLabel: {
    switch (root.variant) {
      case "cpu": return "CPU"
      case "ram": return "RAM"
      case "temp": return "Temp"
      case "disk": return "Disk"
      case "battery": return "Battery"
      default: return ""
    }
  }

  readonly property string statIcon: {
    switch (root.variant) {
      case "cpu": return ""
      case "ram": return ""
      case "temp": return ""
      case "disk": return ""
      case "battery": return SystemStats.batteryCharging ? "󰂄" : ""
      default: return ""
    }
  }

  readonly property real fillPercent: {
    switch (root.variant) {
      case "cpu": return SystemStats.cpuPercent
      case "ram": return SystemStats.ramPercent
      case "temp": return Math.max(0, Math.min(100, (SystemStats.tempC / 100) * 100))
      case "disk": return SystemStats.diskPercent
      case "battery": return SystemStats.batteryPercent
      default: return 0
    }
  }

  readonly property string valueText: {
    switch (root.variant) {
      case "cpu": return Math.round(SystemStats.cpuPercent) + "%"
      case "ram": return (SystemStats.totalRamGb * SystemStats.ramPercent / 100).toFixed(1) + "G"
      case "temp": return Math.round(SystemStats.tempC) + "\u00b0"
      case "disk": return Math.round(SystemStats.diskPercent) + "%"
      case "battery": return Math.round(SystemStats.batteryPercent) + "%"
      default: return ""
    }
  }

  Rectangle {
    id: card
    anchors.fill: parent
    radius: 14
    color: MatugenColors.bgBase
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    clip: true

    // "No battery" state
    Row {
      visible: root.batteryMissing
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: parent.width * 0.08
      spacing: parent.width * 0.05

      Text {
        text: ""
        font.pixelSize: Math.min(root.width, root.height) * 0.18
        font.family: Config.fontFamily
        color: MatugenColors.text
        anchors.verticalCenter: parent.verticalCenter
      }

      Column {
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Text {
          text: "No battery found"
          font.pixelSize: Math.min(root.width, root.height) * 0.11
          font.weight: Font.Bold
          font.family: Config.fontFamily
          color: MatugenColors.text
        }
        Text {
          text: "AC power connected"
          font.pixelSize: Math.min(root.width, root.height) * 0.075
          font.family: Config.fontFamily
          color: MatugenColors.textMuted
        }
      }
    }

    // Normal stat card
    Item {
      anchors.fill: parent
      visible: !root.batteryMissing

      // Bottom fill bar
      Canvas {
        id: fillCanvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Immediate

        property real animatedFill: root.fillPercent / 100
        Behavior on animatedFill {
          NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }
        onAnimatedFillChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
          var ctx = getContext("2d");
          ctx.clearRect(0, 0, width, height);
          if (animatedFill <= 0) return;

          ctx.save();
          var r = card.radius;
          ctx.beginPath();
          ctx.moveTo(r, 0);
          ctx.lineTo(width - r, 0);
          ctx.quadraticCurveTo(width, 0, width, r);
          ctx.lineTo(width, height - r);
          ctx.quadraticCurveTo(width, height, width - r, height);
          ctx.lineTo(r, height);
          ctx.quadraticCurveTo(0, height, 0, height - r);
          ctx.lineTo(0, r);
          ctx.quadraticCurveTo(0, 0, r, 0);
          ctx.closePath();
          ctx.clip();

          var fillY = height * (1.0 - animatedFill);
          ctx.beginPath();
          ctx.rect(0, fillY, width, height - fillY);
          ctx.closePath();

          ctx.fillStyle = MatugenColors.accent.toString();
          ctx.fill();
          ctx.restore();
        }
      }

      Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: parent.height * 0.1
        text: root.statIcon
        font.pixelSize: Math.min(root.width, root.height) * 0.16
        font.family: Config.fontFamily
        color: MatugenColors.textMuted
      }

      Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: parent.height * 0.1
        text: root.statLabel
        font.pixelSize: Math.min(root.width, root.height) * 0.1
        font.family: Config.fontFamily
        color: MatugenColors.textMuted
      }

      Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: parent.height * 0.1
        text: root.valueText
        font.pixelSize: Math.min(root.width, root.height) * 0.22
        font.weight: Font.Bold
        font.family: Config.fontFamily
        color: MatugenColors.text
      }
    }
  }
}