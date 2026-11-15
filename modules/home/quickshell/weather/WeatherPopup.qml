import "../Singletons"
import ".."
import "../Singletons/PopupPlace.js" as Place
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
  id: root

  Component.onCompleted: {
        Scaler.currentWidth = weatherPopup.screen ? weatherPopup.screen.width : Screen.width
        Scaler.currentHeight = weatherPopup.screen ? weatherPopup.screen.height : Screen.height
    }
  function s(val) { return Scaler.s(val) }
  property real anchorY: Screen.height / 2
  function updateAnchor() {
    var ref = (root.width > 0 && root.height > 0) ? root : root.parent
    if (!ref) return
    var p = ref.mapToItem(null, ref.width / 2, ref.height / 2)
    root.anchorY = p.y + (Config.barVertical ? s(10) : 0)
  }
  property bool weatherMenuOpen: false
  property int selectedDayIndex: 0
  readonly property var sel: Weather.daily[selectedDayIndex] !== undefined ? Weather.daily[selectedDayIndex] : null
  readonly property bool isToday: selectedDayIndex === 0 || sel === null
  readonly property bool showContent: Weather.ready && !Weather.hasError
  readonly property var hourItems: Weather.hoursForDay(selectedDayIndex)

  onWeatherMenuOpenChanged: {
    if (root.weatherMenuOpen) root.updateAnchor()
    if (root.weatherMenuOpen) {
      root.selectedDayIndex = 0
      Weather.refreshIfStale()
      popupVisualVisible = true
    } else {
      popupVisualVisible = false
    }
  }

  property bool popupVisualVisible: false
  property bool popupWindowVisible: false

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

  PanelWindow {
    id: weatherPopup
    visible: root.popupWindowVisible
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qs-weather-popup"
    anchors { top: true; left: true; right: true; bottom: true }

    // Click outside the card closes the popup
    MouseArea {
      anchors.fill: parent
      onClicked: root.weatherMenuOpen = false
    }

    FocusScope {
      anchors.fill: parent
      focus: root.popupWindowVisible
      Keys.onEscapePressed: root.weatherMenuOpen = false

      Rectangle {
        id: weatherCard
        width: s(724)
        implicitHeight: mainCol.implicitHeight + s(40)
        height: implicitHeight

        // Same placement rules as the calendar card
        readonly property var placement: Place.place(Config.barPosition, width, height, root.anchorY, Screen.width, Screen.height, root.s)
        x: placement.x
        y: placement.y

        radius: s(Config.uiRadius + 4)
        color: MatugenColors.bgBase
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        // Card animates independently of the window visibility so the
        // scale and fade stay visible instead of popping with the window.
        opacity: root.popupVisualVisible ? 1 : 0
        scale: root.popupVisualVisible ? 1 : 0.94
        transformOrigin: Item.Top
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        // Swallow clicks so they do not reach the close area behind
        MouseArea { anchors.fill: parent }

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
            text: (Weather.errorText || "Unable to load weather") + "  (click to retry)"
            font.pixelSize: s(12)
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.error
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            MouseArea { anchors.fill: parent; onClicked: Weather.fetchWeather() }
          }

          // Showing the last saved forecast because the refresh failed
          Text {
            visible: Weather.stale && !Weather.hasError
            Layout.fillWidth: true
            text: "Showing saved data"
            font.pixelSize: s(10)
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.textDim
            horizontalAlignment: Text.AlignHCenter
          }

          // Top row: location/temp on left, icon/condition/hi-lo on right
          RowLayout {
            visible: root.showContent
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
                text: (root.isToday ? Weather.currentTemp : root.sel.hi) + Weather.tempSuffix
                font.pixelSize: s(34)
                font.weight: Font.Bold
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.text
              }
              Text {
                visible: !root.isToday
                text: root.sel ? root.sel.label : ""
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
                text: root.isToday ? Weather.iconGlyph : root.sel.icon
                font.pixelSize: s(30)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.accent
              }
              Text {
                Layout.alignment: Qt.AlignRight
                text: root.isToday ? Weather.condition : (root.sel ? root.sel.condition : "")
                font.pixelSize: s(12)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.textMuted
              }
              Text {
                Layout.alignment: Qt.AlignRight
                text: root.sel ? "H:" + root.sel.hi + "° L:" + root.sel.lo + "°" : ""
                font.pixelSize: s(11)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.textDim
              }
            }
          }

          // Severe weather alerts
          ColumnLayout {
            visible: root.showContent && Weather.alerts.length > 0
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
            visible: root.showContent
            Layout.fillWidth: true
            spacing: s(8)

            Repeater {
              model: root.sel === null ? [] : [
                { glyph: "", label: "Feels", value: (root.isToday ? Weather.feelsLike : root.sel.feels) + Weather.tempSuffix },
                { glyph: "", label: "Humidity", value: (root.isToday ? Weather.humidity : root.sel.humidity) + "%" },
                { glyph: "", label: "Wind", value: (root.isToday ? Weather.windSpeed : root.sel.wind) + " " + Weather.windUnit },
                { glyph: "", label: "Rain", value: (root.isToday ? Weather.rainChance : root.sel.pop) + "%" }
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

          Rectangle { visible: root.showContent; Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

          // Hourly bar-chart graph (Apple weather app style)
          ColumnLayout {
            visible: root.hourItems.length > 0
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

              Item {
                id: tempGraph
                anchors.fill: parent
                readonly property var temps: root.hourItems.map(p => p.temp)
                readonly property real maxT: temps.length > 0 ? Math.max.apply(null, temps) : 0
                readonly property real minT: temps.length > 0 ? Math.min.apply(null, temps) : 0
                readonly property real span: Math.max(1, maxT - minT)

                Row {
                  anchors.fill: parent
                  Repeater {
                    model: root.hourItems
                    delegate: Item {
                      width: tempGraph.width / root.hourItems.length
                      height: tempGraph.height
                      Rectangle {
                        readonly property real norm: (modelData.temp - tempGraph.minT) / tempGraph.span
                        width: parent.width - s(3)
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: s(6)
                        height: Math.max(s(4), norm * (parent.height - s(12)))
                        topLeftRadius: s(3)
                        topRightRadius: s(3)
                        color: MatugenColors.accent
                        opacity: 0.35 + norm * 0.65
                      }
                    }
                  }
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
                  model: root.hourItems
                  delegate: Column {
                    width: hourlyMetrics.width / root.hourItems.length
                    spacing: s(3)

                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: Weather.formatHour(modelData.hour)
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

          Rectangle { visible: root.showContent && Weather.daily.length > 0; Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

          // Daily forecast list, stretched full width
          ColumnLayout {
            visible: root.showContent && Weather.daily.length > 0
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
                  readonly property real span: Math.max(1, Weather.rangeMax - Weather.rangeMin)

                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    radius: s(2)
                    color: MatugenColors.accent
                    x: parent.width * ((modelData.lo - Weather.rangeMin) / parent.span)
                    width: Math.max(s(6), parent.width * ((modelData.hi - modelData.lo) / parent.span))
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
}
