import QtQuick
import ".."
import "../Singletons"
import "../weather"

Item {
  id: root
  anchors.fill: parent

  // Set by DesktopWidgetFrame from the widget's stored `size` field.
  // Deliberately not derived from width/height: small/medium/large are a
  // user choice with distinct layouts (icon-only vs. hourly strip vs. full
  // week), not an automatic reflow breakpoint.
  property string sizeClass: "small"

  Rectangle {
    anchors.fill: parent
    radius: 18
    color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.6)
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1
  }

  Loader {
    anchors.fill: parent
    anchors.margins: 14
    clip: true
    sourceComponent: {
      switch (root.sizeClass) {
        case "small": return smallComp
        case "medium": return mediumComp
        default: return largeComp
      }
    }
  }

  // ── Small: icon, temp, location — nothing else fits ──
  Component {
    id: smallComp
    Column {
      anchors.centerIn: parent
      spacing: 4

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Weather.ownmIconToGlyph(Weather.iconCode)
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: Math.min(root.width, root.height) * 0.3
        color: MatugenColors.text
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Weather.hasError ? "--" : (Weather.currentTemp + "°")
        font.family: Config.fontFamily
        font.weight: Font.Bold
        font.pixelSize: Math.min(root.width, root.height) * 0.2
        color: MatugenColors.text
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Weather.hasError ? Weather.errorText : (Weather.locationName || "--")
        font.family: Config.fontFamily
        font.pixelSize: Math.min(root.width, root.height) * 0.08
        color: MatugenColors.textMuted
        elide: Text.ElideRight
        width: root.width * 0.9
        horizontalAlignment: Text.AlignHCenter
      }
    }
  }

  // ── Medium: header row + hourly strip, like the macOS "London" card ──
  Component {
    id: mediumComp
    Column {
      width: parent.width
      spacing: 12

      Item {
        width: parent.width
        height: Math.max(headerCol.implicitHeight, hiLoCol.implicitHeight)

        Column {
          id: headerCol
          anchors.left: parent.left
          spacing: 2
          Text {
            text: Weather.hasError ? "--" : (Weather.locationName || "--")
            font.family: Config.fontFamily
            font.weight: Font.DemiBold
            font.pixelSize: 15
            color: MatugenColors.text
            elide: Text.ElideRight
            width: root.width * 0.55
          }
          Text {
            text: Weather.hasError ? "--" : (Weather.currentTemp + "°")
            font.family: Config.fontFamily
            font.weight: Font.Light
            font.pixelSize: 40
            color: MatugenColors.text
          }
        }

        Column {
          id: hiLoCol
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: 2
          Text {
            anchors.right: parent.right
            text: Weather.hasError ? "" : Weather.condition
            font.family: Config.fontFamily
            font.pixelSize: 12
            color: MatugenColors.textMuted
          }
          Text {
            anchors.right: parent.right
            text: Weather.hasError ? "" : ("H:" + Weather.highTemp + "°  L:" + Weather.lowTemp + "°")
            font.family: Config.fontFamily
            font.pixelSize: 12
            color: MatugenColors.textMuted
          }
        }
      }

      Row {
        width: parent.width
        spacing: 0

        Repeater {
          model: Weather.hasError ? [] : Weather.hourly.slice(0, 5)
          delegate: Column {
            required property var modelData
            width: parent.width / 5
            spacing: 4

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Weather.formatHour(modelData.time)
              font.family: Config.fontFamily
              font.pixelSize: 10
              color: MatugenColors.textMuted
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Weather.ownmIconToGlyph(modelData.icon)
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 14
              color: MatugenColors.text
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: modelData.temp + "°"
              font.family: Config.fontFamily
              font.weight: Font.DemiBold
              font.pixelSize: 12
              color: MatugenColors.text
            }
          }
        }
      }
    }
  }

  // ── Large: header, hourly strip, and a daily list with range bars ──
  Component {
    id: largeComp
    Column {
      width: parent.width
      spacing: 10

      Item {
        width: parent.width
        height: Math.max(largeHeaderCol.implicitHeight, largeHiLoCol.implicitHeight)

        Column {
          id: largeHeaderCol
          anchors.left: parent.left
          spacing: 2
          Text {
            text: Weather.hasError ? "--" : (Weather.locationName || "--")
            font.family: Config.fontFamily
            font.weight: Font.DemiBold
            font.pixelSize: 16
            color: MatugenColors.text
          }
          Text {
            text: Weather.hasError ? "--" : (Weather.currentTemp + "°")
            font.family: Config.fontFamily
            font.weight: Font.Light
            font.pixelSize: 44
            color: MatugenColors.text
          }
        }

        Column {
          id: largeHiLoCol
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: 4

          Text {
            anchors.right: parent.right
            text: Weather.hasError ? "" : Weather.ownmIconToGlyph(Weather.iconCode)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 20
            color: MatugenColors.text
          }
          Text {
            anchors.right: parent.right
            text: Weather.hasError ? "" : Weather.condition
            font.family: Config.fontFamily
            font.pixelSize: 12
            color: MatugenColors.textMuted
          }
          Text {
            anchors.right: parent.right
            text: Weather.hasError ? "" : ("H:" + Weather.highTemp + "°  L:" + Weather.lowTemp + "°")
            font.family: Config.fontFamily
            font.pixelSize: 12
            color: MatugenColors.textMuted
          }
        }
      }

      Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

      Row {
        width: parent.width
        spacing: 0

        Repeater {
          model: Weather.hasError ? [] : Weather.hourly.slice(0, 6)
          delegate: Column {
            required property var modelData
            width: parent.width / 6
            spacing: 4

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Weather.formatHour(modelData.time)
              font.family: Config.fontFamily
              font.pixelSize: 10
              color: MatugenColors.textMuted
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Weather.ownmIconToGlyph(modelData.icon)
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 14
              color: MatugenColors.text
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: modelData.temp + "°"
              font.family: Config.fontFamily
              font.weight: Font.DemiBold
              font.pixelSize: 12
              color: MatugenColors.text
            }
          }
        }
      }

      Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

      Column {
        width: parent.width
        spacing: 6

        // Daily range bars are scaled against the week's min/max, not each
        // row's own low/high, so the bars are visually comparable day to
        // day - matching how the macOS widget lines them up.
        readonly property real weekMin: Weather.hasError || Weather.daily.length === 0 ? 0 : Math.min(...Weather.daily.map(d => d.lo))
        readonly property real weekMax: Weather.hasError || Weather.daily.length === 0 ? 1 : Math.max(...Weather.daily.map(d => d.hi))

        Repeater {
          model: Weather.hasError ? [] : Weather.daily.slice(0, 5)
          delegate: Row {
            required property var modelData
            width: parent.width
            spacing: 8

            Text {
              width: 34
              text: modelData.label
              font.family: Config.fontFamily
              font.pixelSize: 12
              color: MatugenColors.text
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              width: 20
              text: Weather.ownmIconToGlyph(modelData.icon)
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 13
              color: MatugenColors.text
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              width: 26
              text: modelData.lo + "°"
              font.family: Config.fontFamily
              font.pixelSize: 11
              color: MatugenColors.textMuted
              anchors.verticalCenter: parent.verticalCenter
            }
            Item {
              width: parent.width - 34 - 20 - 26 - 26 - 24
              height: 4
              anchors.verticalCenter: parent.verticalCenter

              readonly property real span: Math.max(1, parent.parent.weekMax - parent.parent.weekMin)
              readonly property real startFrac: (modelData.lo - parent.parent.weekMin) / span
              readonly property real endFrac: (modelData.hi - parent.parent.weekMin) / span

              Rectangle {
                anchors.fill: parent
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.1)
              }
              Rectangle {
                x: parent.width * parent.startFrac
                width: parent.width * (parent.endFrac - parent.startFrac)
                height: parent.height
                radius: 2
                gradient: Gradient {
                  orientation: Gradient.Horizontal
                  GradientStop { position: 0.0; color: "#6ec6e0" }
                  GradientStop { position: 1.0; color: "#f2c94c" }
                }
              }
            }
            Text {
              width: 26
              text: modelData.hi + "°"
              font.family: Config.fontFamily
              font.weight: Font.DemiBold
              font.pixelSize: 11
              color: MatugenColors.text
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }
    }
  }
}
