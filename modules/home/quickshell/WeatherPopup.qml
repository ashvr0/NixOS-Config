import "Singletons"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
  id: root

  Component.onCompleted: {
        Scaler.currentWidth = Screen.width
        Scaler.currentHeight = Screen.height
    }
  function s(val) { return Scaler.s(val) }

  property bool weatherMenuOpen: false
  property int selectedDayIndex: 0

  onWeatherMenuOpenChanged: {
    if (root.weatherMenuOpen) {
      root.selectedDayIndex = 0
      Weather.fetchWeather()
      popupVisualVisible = true
    } else {
      popupVisualVisible = false
    }
  }

  property bool popupVisualVisible: false
  property bool popupWindowVisible: false

  property int geometryEpoch: 0
  Timer {
    id: geometrySettleTimer
    interval: 800
    running: true
    repeat: false
    onTriggered: root.geometryEpoch++
  }

  Timer {
    id: closeDelayTimer
    interval: 160
    onTriggered: root.popupWindowVisible = false
  }

  onPopupVisualVisibleChanged: {
    if (root.popupVisualVisible) {
      closeDelayTimer.stop()
      root.popupWindowVisible = true
    } else {
      closeDelayTimer.restart()
    }
  }

  PopupWindow {
    id: weatherPopup
    visible: root.popupWindowVisible
    anchor.window: root.QsWindow.window
    readonly property real popupWidth: s(760)
    anchor.rect.x: {
      root.geometryEpoch // force recompute once boot geometry settles
      if (!root.QsWindow.window) return 0
      var winWidth = root.QsWindow.window.contentItem.width
      var pillLeft = root.mapToItem(root.QsWindow.window.contentItem, 0, 0).x
      var pillRight = pillLeft + root.width
      var desiredX = pillRight - weatherPopup.popupWidth
      return Math.max(s(8), Math.min(winWidth - weatherPopup.popupWidth - s(8), desiredX))
    }
    anchor.rect.y: {
      root.geometryEpoch // force recompute once boot geometry settles
      return root.QsWindow.window ? (root.mapToItem(root.QsWindow.window.contentItem, 0, root.height).y + s(10)) : 0
    }
    implicitWidth: popupWidth
    implicitHeight: weatherCard.implicitHeight + s(20)
    color: "transparent"

    HyprlandFocusGrab {
      id: focusGrab
      windows: [weatherPopup]
      active: root.popupWindowVisible
      onCleared: {
        if (root.weatherMenuOpen) root.weatherMenuOpen = false
      }
    }

    Rectangle {
      id: weatherCard
      anchors.fill: parent
      anchors.margins: s(18)
      implicitHeight: mainCol.implicitHeight + s(40)
      radius: s(Config.uiRadius + 4)
      color: MatugenColors.bgBase
      border.color: Qt.rgba(1, 1, 1, 0.08)
      border.width: 1

      // Card animates independently of the popup window's own visibility so the
      // scale/fade is visible instead of popping in with the window itself.
      opacity: root.popupVisualVisible ? 1 : 0
      scale: root.popupVisualVisible ? 1 : 0.94
      transformOrigin: Item.Top
      Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

      ColumnLayout {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: s(16)
        anchors.bottomMargin: s(32)
        spacing: s(16)

        // Error state
        Text {
          visible: Weather.hasError
          Layout.fillWidth: true
          text: Weather.errorText || "Unable to load weather"
          font.pixelSize: s(12)
          font.family: "JetBrainsMono Nerd Font"
          color: MatugenColors.error
          wrapMode: Text.WordWrap
          horizontalAlignment: Text.AlignHCenter
        }

        // Top row: location/temp on left, icon/condition/hi-lo on right
        RowLayout {
          visible: !Weather.hasError
          Layout.fillWidth: true
          spacing: s(12)

          ColumnLayout {
            Layout.fillWidth: true
            spacing: s(2)
            Text {
              text: Weather.locationName
              font.pixelSize: s(13)
              font.weight: Font.Bold
              font.family: "JetBrainsMono Nerd Font"
              color: MatugenColors.text
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
            Text {
              text: (root.selectedDayIndex === 0
                     ? Weather.currentTemp
                     : (Weather.daily[root.selectedDayIndex] ? Weather.daily[root.selectedDayIndex].hi : Weather.currentTemp))
                    + Weather.tempSuffix
              font.pixelSize: s(34)
              font.weight: Font.Bold
              font.family: "JetBrainsMono Nerd Font"
              color: MatugenColors.text
            }
            Text {
              visible: root.selectedDayIndex !== 0 && Weather.daily[root.selectedDayIndex] !== undefined
              text: Weather.daily[root.selectedDayIndex] ? Weather.daily[root.selectedDayIndex].label : ""
              font.pixelSize: s(11)
              font.family: "JetBrainsMono Nerd Font"
              color: MatugenColors.textDim
            }
          }

          ColumnLayout {
            spacing: s(2)
            Layout.alignment: Qt.AlignRight | Qt.AlignTop

            Text {
              Layout.alignment: Qt.AlignRight
              text: root.selectedDayIndex === 0 || !Weather.daily[root.selectedDayIndex]
                  ? Weather.iconCode
                  : Weather.daily[root.selectedDayIndex].icon
              font.pixelSize: s(30)
              font.family: "JetBrainsMono Nerd Font"
              color: MatugenColors.accent
            }
            Text {
              Layout.alignment: Qt.AlignRight
              text: root.selectedDayIndex === 0 ? Weather.condition : ""
              visible: root.selectedDayIndex === 0
              font.pixelSize: s(12)
              font.family: "JetBrainsMono Nerd Font"
              color: MatugenColors.textMuted
            }
            Text {
              Layout.alignment: Qt.AlignRight
              text: root.selectedDayIndex === 0 || !Weather.daily[root.selectedDayIndex]
                ? "H:" + Weather.highTemp + "° L:" + Weather.lowTemp + "°"
                : "H:" + Weather.daily[root.selectedDayIndex].hi + "° L:" + Weather.daily[root.selectedDayIndex].lo + "°"
              font.pixelSize: s(11)
              font.family: "JetBrainsMono Nerd Font"
              color: MatugenColors.textDim
            }
          }
        }

        // Severe weather alerts
        ColumnLayout {
          visible: !Weather.hasError && Weather.alerts.length > 0
          Layout.fillWidth: true
          spacing: s(6)

          Repeater {
            model: Weather.alerts
            delegate: Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: alertRow.implicitHeight + s(16)
              radius: s(8)
              color: Qt.rgba(MatugenColors.warning.r, MatugenColors.warning.g, MatugenColors.warning.b, 0.12)
              border.color: Qt.rgba(MatugenColors.warning.r, MatugenColors.warning.g, MatugenColors.warning.b, 0.4)
              border.width: 1

              RowLayout {
                id: alertRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: s(10)
                spacing: s(8)

                Text {
                  text: "\uf071"
                  font.pixelSize: s(13)
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.warning
                }
                Text {
                  Layout.fillWidth: true
                  text: modelData.event
                  font.pixelSize: s(12)
                  font.weight: Font.DemiBold
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.text
                  elide: Text.ElideRight
                }
              }
            }
          }
        }

        // Detail row: feels like, humidity, wind, rain chance
        RowLayout {
          visible: !Weather.hasError
          Layout.fillWidth: true
          spacing: s(8)

          Repeater {
            model: [
              { glyph: "", label: "Feels", value: Weather.feelsLike + Weather.tempSuffix },
              { glyph: "", label: "Humidity", value: Weather.humidity + "%" },
              { glyph: "", label: "Wind", value: Weather.windSpeed + " " + Weather.windUnit },
              { glyph: "", label: "Rain", value: Weather.rainChance + "%" }
            ]
            delegate: Rectangle {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              Layout.preferredHeight: s(88)
              radius: s(Config.uiRadius)
              color: Qt.rgba(1, 1, 1, 0.04)
              border.color: Qt.rgba(1, 1, 1, 0.10)
              border.width: 1

              ColumnLayout {
                anchors.centerIn: parent
                spacing: s(8)
                Text {
                  Layout.alignment: Qt.AlignHCenter
                  text: modelData.glyph
                  font.pixelSize: s(20)
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.accent
                }
                Text {
                  Layout.alignment: Qt.AlignHCenter
                  text: modelData.value
                  font.pixelSize: s(18)
                  font.weight: Font.DemiBold
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.text
                }
                Text {
                  Layout.alignment: Qt.AlignHCenter
                  text: modelData.label
                  font.pixelSize: s(11)
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.textDim
                }
              }
            }
          }
        }

        Rectangle { visible: !Weather.hasError; Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

        // Hourly bar-chart graph (Apple weather app style)
        ColumnLayout {
          visible: !Weather.hasError && Weather.hourly.length > 0
          Layout.fillWidth: true
          spacing: s(4)

          Text {
            text: "Hourly"
            font.pixelSize: s(10)
            font.weight: Font.DemiBold
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.textDim
          }

          Item {
            Layout.fillWidth: true
            Layout.preferredHeight: s(70)

            Canvas {
              id: tempGraph
              anchors.fill: parent
              property var pts: Weather.hourly
              onPtsChanged: requestPaint()
              Component.onCompleted: requestPaint()

              onPaint: {
                let ctx = getContext("2d")
                ctx.reset()
                if (pts.length < 1) return

                let temps = pts.map(p => p.temp)
                let maxT = Math.max.apply(null, temps)
                let minT = Math.min.apply(null, temps)
                let range = Math.max(1, maxT - minT)
                let pad = s(6)
                let barGap = s(3)
                let n = pts.length
                let barW = (width - barGap * (n - 1)) / n
                let usableH = height - pad * 2

                for (let i = 0; i < n; i++) {
                  let normalized = (pts[i].temp - minT) / range
                  let barH = Math.max(s(4), normalized * usableH)
                  let x = i * (barW + barGap)
                  let y = pad + (usableH - barH)

                  ctx.fillStyle = MatugenColors.accent
                  ctx.globalAlpha = 0.35 + normalized * 0.65
                  let radius = Math.min(barW / 2, s(3))
                  ctx.beginPath()
                  ctx.moveTo(x, y + barH)
                  ctx.lineTo(x, y + radius)
                  ctx.quadraticCurveTo(x, y, x + radius, y)
                  ctx.lineTo(x + barW - radius, y)
                  ctx.quadraticCurveTo(x + barW, y, x + barW, y + radius)
                  ctx.lineTo(x + barW, y + barH)
                  ctx.closePath()
                  ctx.fill()
                }
                ctx.globalAlpha = 1
              }
            }
          }

          Item {
            Layout.fillWidth: true
            Layout.preferredHeight: hourlyMetrics.implicitHeight

            Row {
              id: hourlyMetrics
              anchors.fill: parent

              Repeater {
                model: Weather.hourly
                delegate: Column {
                  width: hourlyMetrics.width / Weather.hourly.length
                  spacing: s(3)

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.formatHour(modelData.time)
                    font.pixelSize: s(9)
                    font.family: "JetBrainsMono Nerd Font"
                    color: MatugenColors.textDim
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.icon
                    font.pixelSize: s(15)
                    font.family: "JetBrainsMono Nerd Font"
                    color: MatugenColors.accent
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.pop + "%"
                    font.pixelSize: s(9)
                    font.family: "JetBrainsMono Nerd Font"
                    color: MatugenColors.accent
                    opacity: 0.8
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.temp + "°"
                    font.pixelSize: s(11)
                    font.weight: Font.DemiBold
                    font.family: "JetBrainsMono Nerd Font"
                    color: MatugenColors.text
                  }
                }
              }
            }
          }
        }

        Rectangle { visible: !Weather.hasError && Weather.daily.length > 0; Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

        // Daily forecast list, stretched full width
        ColumnLayout {
          visible: !Weather.hasError && Weather.daily.length > 0
          Layout.fillWidth: true
          spacing: s(2)

          Text {
            text: "7-Day Forecast"
            font.pixelSize: s(10)
            font.weight: Font.DemiBold
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.textDim
            Layout.bottomMargin: s(4)
          }

          Repeater {
            model: Weather.daily
            delegate: Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: s(34)
              radius: s(6)
              color: root.selectedDayIndex === index ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectedDayIndex = index
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: s(6)
                anchors.rightMargin: s(6)
                spacing: s(10)

              Text {
                text: modelData.label
                font.pixelSize: s(12)
                font.weight: index === 0 ? Font.Bold : Font.Normal
                font.family: "JetBrainsMono Nerd Font"
                color: root.selectedDayIndex === index ? MatugenColors.accent : MatugenColors.text
                Layout.preferredWidth: s(70)
              }

              Text {
                text: modelData.icon
                font.pixelSize: s(16)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.accent
                Layout.preferredWidth: s(30)
                horizontalAlignment: Text.AlignHCenter
              }

              Text {
                text: modelData.lo + "°"
                font.pixelSize: s(11)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.textDim
                Layout.preferredWidth: s(30)
                horizontalAlignment: Text.AlignRight
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: s(4)
                radius: s(2)
                color: Qt.rgba(1, 1, 1, 0.08)

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  height: parent.height
                  radius: s(2)
                  color: MatugenColors.accent
                  x: {
                    let allHi = Weather.daily.map(d => d.hi)
                    let allLo = Weather.daily.map(d => d.lo)
                    let gMax = Math.max.apply(null, allHi)
                    let gMin = Math.min.apply(null, allLo)
                    let gRange = Math.max(1, gMax - gMin)
                    return parent.width * ((modelData.lo - gMin) / gRange)
                  }
                  width: {
                    let allHi = Weather.daily.map(d => d.hi)
                    let allLo = Weather.daily.map(d => d.lo)
                    let gMax = Math.max.apply(null, allHi)
                    let gMin = Math.min.apply(null, allLo)
                    let gRange = Math.max(1, gMax - gMin)
                    return Math.max(s(6), parent.width * ((modelData.hi - modelData.lo) / gRange))
                  }
                }
              }

              Text {
                text: modelData.hi + "°"
                font.pixelSize: s(11)
                font.weight: Font.DemiBold
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.text
                Layout.preferredWidth: s(30)
                horizontalAlignment: Text.AlignRight
              }
              }
            }
          }
        }

        Text {
          visible: Weather.loading
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: "Loading..."
          font.pixelSize: s(11)
          font.family: "JetBrainsMono Nerd Font"
          color: MatugenColors.textDim
        }
      }
    }
  }
}
