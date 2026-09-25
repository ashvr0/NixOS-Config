import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."
import "../Singletons"

ColumnLayout {
  id: root
  required property var s
  required property var matches
  required property var fontFamily
  required property var menuOpenSetter
  required property var monitorsModel
  required property int resDropdownIdx
  required property var setResDropdownIdx
  required property var resLabel
  required property var commonResolutions
  required property var validScalesForResolution
  required property var setMonitorRes
  required property var stepRefreshRate
  required property var ratesForRes
  required property var setMonitorRate
  required property var setMonitorScale
  required property var transformChoices
  required property var setMonitorTransform
  required property string nightLightMode
  required property string nightLightFrom
  required property string nightLightTo
  required property var nightLightModeChoices
  required property var setNightLightMode
  required property var setNightLightFrom
  required property var setNightLightTo
  required property int autoLockSeconds
  required property var autoLockChoices
  required property var setAutoLockSeconds
  property int nightLightTemp: 50
  property var setNightLightTemp: function(v) { root.nightLightTemp = v }
  property int orientationDropdownIdx: -1
  property bool autoLockDropdownOpen: false
  property bool nightLightScheduleOpen: root.nightLightMode === "Schedule"

  Layout.fillWidth: true
  spacing: s(14)

  RowLayout {
    Layout.fillWidth: true
    Text { text: "DISPLAYS"; font.pixelSize: s(10); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.border; Layout.fillWidth: true }
  }

  Repeater {
    model: root.monitorsModel
    delegate: Rectangle {
      id: monitorCard
      Layout.fillWidth: true
      implicitHeight: monCol.implicitHeight + s(20)
      radius: s(Config.uiRadius)
      color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

      readonly property int monitorIndex: index

      ColumnLayout {
        id: monCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: s(10)
        spacing: s(8)

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: s(210)
          clip: true

          Rectangle {
            id: monitorPreview
            anchors.centerIn: parent
            width: Math.min(parent.width * 0.8, s(650))
            height: Math.min(width * (model.height / model.width), parent.height - s(16))
            radius: s(8)
            color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.9)
            border.color: Qt.rgba(1, 1, 1, 0.25)
            border.width: 2
            clip: true

            ColumnLayout {
              anchors.centerIn: parent
              spacing: s(4)

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "󰍹"
                font.pixelSize: s(22)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.text
              }

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: model.name
                font.pixelSize: s(12)
                font.weight: Font.Bold
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.text
              }

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: model.width + "x" + model.height
                font.pixelSize: s(9)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.textDim
              }
            }
          }

          Rectangle {
            anchors.top: monitorPreview.bottom
            anchors.horizontalCenter: monitorPreview.horizontalCenter
            anchors.topMargin: s(6)
            width: monitorPreview.width * 0.3
            height: s(8)
            radius: s(2)
            color: Qt.rgba(1, 1, 1, 0.25)
            visible: y + height <= parent.height
          }
        }

        // ---------------- RESOLUTION ----------------
        RowLayout {
          Layout.fillWidth: true
          spacing: s(8)

          Text { text: "resolution"; font.pixelSize: s(10); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textDim; Layout.fillWidth: true }

          Item {
            id: resTriggerAnchor
            Layout.preferredWidth: s(150)
            Layout.preferredHeight: s(26)

            Rectangle {
              id: resTriggerBox
              anchors.fill: parent
              radius: s(8)
              color: resBtnMa.containsMouse || resDropdown.opened ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16) : Qt.rgba(1, 1, 1, 0.08)
              border.width: 1
              border.color: Qt.rgba(1, 1, 1, 0.12)
              Behavior on color { ColorAnimation { duration: 150 } }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: s(10)
                anchors.rightMargin: s(8)
                spacing: s(4)

                Text {
                  Layout.fillWidth: true
                  text: root.resLabel(model.width, model.height)
                  font.pixelSize: s(11)
                  font.weight: Font.Bold
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.text
                  elide: Text.ElideRight
                }
                Text {
                  text: resDropdown.opened ? "\uf077" : "\uf078"
                  font.pixelSize: s(9)
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.textDim
                }
              }

              MouseArea {
                id: resBtnMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: resDropdown.opened ? resDropdown.close() : resDropdown.open()
              }
            }

            Popup {
              id: resDropdown
              parent: resTriggerBox
              y: resTriggerBox.height + s(4)
              x: 0
              width: resTriggerBox.width
              height: Math.min(s(200), root.commonResolutions.length * s(28) + s(8))
              padding: s(4)
              closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

              background: Rectangle {
                radius: s(8)
                color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.98)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)
              }

              contentItem: ListView {
                clip: true
                model: root.commonResolutions
                delegate: Rectangle {
                  width: ListView.view.width
                  height: s(26)
                  radius: s(6)
                  readonly property bool selected: root.monitorsModel.get(monitorCard.monitorIndex).width === modelData.w && root.monitorsModel.get(monitorCard.monitorIndex).height === modelData.h
                  color: selected ? MatugenColors.accent : (resItemMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                  Behavior on color { ColorAnimation { duration: 120 } }

                  Text {
                    anchors.centerIn: parent
                    text: root.resLabel(modelData.w, modelData.h)
                    font.pixelSize: s(10)
                    font.weight: Font.Bold
                    font.family: "JetBrainsMono Nerd Font"
                    color: selected ? MatugenColors.bgBase : MatugenColors.text
                  }
                  MouseArea {
                    id: resItemMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.setMonitorRes(monitorCard.monitorIndex, modelData.w, modelData.h); resDropdown.close() }
                  }
                }
              }
            }
          }
        }

        // ---------------- REFRESH RATE ----------------
RowLayout {
  Layout.fillWidth: true
  spacing: s(8)
  Text { text: "refresh"; font.pixelSize: s(10); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textDim; Layout.fillWidth: true }

  RowLayout {
    id: rateStepper
    spacing: s(4)

    readonly property var availRates: (model ? root.ratesForRes(model.availableModes, model.width, model.height) : [60]) || [60]

    function setRate(r) {
      const rates = rateStepper.availRates
      if (rates.length === 0) return
      let nearest = rates[0]
      for (const v of rates) {
        if (Math.abs(v - r) < Math.abs(nearest - r)) nearest = v
      }
      root.setMonitorRate(index, nearest)
    }
    function step(dir) {
      const rates = rateStepper.availRates
      const curIdx = rates.indexOf(model.refreshRate)
      const nextIdx = Math.max(0, Math.min(rates.length - 1, curIdx + dir))
      if (rates[nextIdx] !== undefined) root.setMonitorRate(index, rates[nextIdx])
    }

    Rectangle {
      Layout.preferredWidth: s(26)
      Layout.preferredHeight: s(28)
      radius: s(6)
      color: rateDecMa.pressed ? Qt.rgba(1, 1, 1, 0.16) : (rateDecMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08))
      Behavior on color { ColorAnimation { duration: 120 } }
      enabled: (rateStepper.availRates || [60]).indexOf(model.refreshRate) > 0
      opacity: enabled ? 1 : 0.4

      Text {
        anchors.centerIn: parent
        text: "\uf053"
        font.pixelSize: s(11)
        font.family: "JetBrainsMono Nerd Font"
        color: MatugenColors.accent
      }

      MouseArea {
        id: rateDecMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: rateStepper.step(-1)
      }
    }

    Rectangle {
      Layout.preferredWidth: s(58)
      Layout.preferredHeight: s(28)
      radius: s(6)
      color: Qt.rgba(1, 1, 1, 0.08)

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        onWheel: (wheel) => {
          rateStepper.step(wheel.angleDelta.y > 0 ? -1 : 1)
          wheel.accepted = true
        }
      }

      Text {
        anchors.centerIn: parent
        text: model.refreshRate.toFixed(0) + "Hz"
        font.pixelSize: s(12)
        font.weight: Font.Bold
        font.family: "JetBrainsMono Nerd Font"
        color: MatugenColors.accent
      }
    }

    Rectangle {
      Layout.preferredWidth: s(26)
      Layout.preferredHeight: s(28)
      radius: s(6)
      color: rateIncMa.pressed ? Qt.rgba(1, 1, 1, 0.16) : (rateIncMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08))
      Behavior on color { ColorAnimation { duration: 120 } }
      enabled: (rateStepper.availRates || [60]).indexOf(model.refreshRate) < rateStepper.availRates.length - 1
      opacity: enabled ? 1 : 0.4

      Text {
        anchors.centerIn: parent
        text: "\uf054"
        font.pixelSize: s(11)
        font.family: "JetBrainsMono Nerd Font"
        color: MatugenColors.accent
      }

      MouseArea {
        id: rateIncMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: rateStepper.step(1)
      }
    }
  }
}

        // ---------------- SCALE ----------------
        RowLayout {
          Layout.fillWidth: true
          spacing: s(8)
          Text { text: "scale"; font.pixelSize: s(10); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textDim; Layout.fillWidth: true }

          RowLayout {
            id: scaleStepper
            spacing: s(4)

            readonly property var validScales: root.validScalesForResolution(model.width, model.height)

            function curIdx() {
              const vs = scaleStepper.validScales
              return vs.reduce((best, v, idx) => Math.abs(v - model.scale) < Math.abs(vs[best] - model.scale) ? idx : best, 0)
            }
            function step(dir) {
              const vs = scaleStepper.validScales
              const i = Math.max(0, Math.min(vs.length - 1, scaleStepper.curIdx() + dir))
              root.setMonitorScale(index, vs[i])
            }

            Rectangle {
              Layout.preferredWidth: s(26)
              Layout.preferredHeight: s(28)
              radius: s(6)
              color: scaleDecMa.pressed ? Qt.rgba(1, 1, 1, 0.16) : (scaleDecMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08))
              Behavior on color { ColorAnimation { duration: 120 } }
              enabled: scaleStepper.curIdx() > 0
              opacity: enabled ? 1 : 0.4

              Text {
                anchors.centerIn: parent
                text: "\uf053"
                font.pixelSize: s(11)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.accent
              }

              MouseArea {
                id: scaleDecMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: scaleStepper.step(-1)
              }
            }

            Rectangle {
              Layout.preferredWidth: s(58)
              Layout.preferredHeight: s(28)
              radius: s(6)
              color: Qt.rgba(1, 1, 1, 0.08)

              MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                onWheel: (wheel) => {
                  scaleStepper.step(wheel.angleDelta.y > 0 ? -1 : 1)
                  wheel.accepted = true
                }
              }

              Text {
                anchors.centerIn: parent
                text: model.scale.toFixed(2) + "x"
                font.pixelSize: s(12)
                font.weight: Font.Bold
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.accent
              }
            }

            Rectangle {
              Layout.preferredWidth: s(26)
              Layout.preferredHeight: s(28)
              radius: s(6)
              color: scaleIncMa.pressed ? Qt.rgba(1, 1, 1, 0.16) : (scaleIncMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08))
              Behavior on color { ColorAnimation { duration: 120 } }
              enabled: scaleStepper.curIdx() < scaleStepper.validScales.length - 1
              opacity: enabled ? 1 : 0.4

              Text {
                anchors.centerIn: parent
                text: "\uf054"
                font.pixelSize: s(11)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.accent
              }

              MouseArea {
                id: scaleIncMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: scaleStepper.step(1)
              }
            }
          }
        }

        // ---------------- ORIENTATION ----------------
        RowLayout {
          Layout.fillWidth: true
          spacing: s(8)
          Text { text: "orientation"; font.pixelSize: s(10); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textDim; Layout.fillWidth: true }

          Item {
            id: orientTriggerAnchor
            Layout.preferredWidth: s(120)
            Layout.preferredHeight: s(26)

            Rectangle {
              id: orientTriggerBox
              anchors.fill: parent
              radius: s(8)
              color: orientBtnMa.containsMouse || orientDropdown.opened ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16) : Qt.rgba(1, 1, 1, 0.08)
              border.width: 1
              border.color: Qt.rgba(1, 1, 1, 0.12)
              Behavior on color { ColorAnimation { duration: 150 } }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: s(10)
                anchors.rightMargin: s(8)
                spacing: s(4)

                Text {
                  Layout.fillWidth: true
                  text: (root.transformChoices.find(t => t.id === model.transform) || root.transformChoices[0]).label
                  font.pixelSize: s(11)
                  font.weight: Font.Bold
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.text
                  elide: Text.ElideRight
                }
                Text {
                  text: orientDropdown.opened ? "\uf077" : "\uf078"
                  font.pixelSize: s(9)
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.textDim
                }
              }

              MouseArea {
                id: orientBtnMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: orientDropdown.opened ? orientDropdown.close() : orientDropdown.open()
              }
            }

            Popup {
              id: orientDropdown
              parent: orientTriggerBox
              y: orientTriggerBox.height + s(4)
              x: 0
              width: orientTriggerBox.width
              height: root.transformChoices.length * s(28) + s(8)
              padding: s(4)
              closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

              background: Rectangle {
                radius: s(8)
                color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.98)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)
              }

              contentItem: ColumnLayout {
                spacing: s(2)

                Repeater {
                  model: root.transformChoices
                  delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: s(26)
                    radius: s(6)
                    readonly property bool selected: root.monitorsModel.get(monitorCard.monitorIndex).transform === modelData.id
                    color: selected ? MatugenColors.accent : (orientItemMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                      anchors.centerIn: parent
                      text: modelData.label
                      font.pixelSize: s(10)
                      font.weight: Font.Bold
                      font.family: "JetBrainsMono Nerd Font"
                      color: selected ? MatugenColors.bgBase : MatugenColors.text
                    }
                    MouseArea {
                      id: orientItemMa
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: { root.setMonitorTransform(monitorCard.monitorIndex, modelData.id); orientDropdown.close() }
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

  Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

  Text { visible: root.matches("Night light"); text: "NIGHT LIGHT"; font.pixelSize: s(10); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.border }

  Rectangle {
    visible: root.matches("Night light")
    Layout.fillWidth: true
    implicitHeight: nightCol.implicitHeight + s(20)
    radius: s(Config.uiRadius)
    color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)
    clip: true

    ColumnLayout {
      id: nightCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: s(10)
      spacing: s(10)

      // Main enable toggle
      RowLayout {
        Layout.fillWidth: true
        spacing: s(8)

        Text { text: "\uf186"; font.pixelSize: s(14); font.family: root.fontFamily; color: MatugenColors.accent }
        Text { text: "Night light"; font.pixelSize: s(13); font.family: root.fontFamily; color: MatugenColors.text; Layout.fillWidth: true }

        // Toggle switch
        Rectangle {
          id: nlSwitch
          property bool on: root.nightLightMode !== "Never"
          width: s(44); height: s(24); radius: height / 2
          color: on ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.12)
          Behavior on color { ColorAnimation { duration: 150 } }

          Rectangle {
            width: s(18); height: s(18); radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: nlSwitch.on ? parent.width - width - s(3) : s(3)
            color: "white"
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (nlSwitch.on) {
                root.setNightLightMode("Never")
              } else {
                root.setNightLightMode("On")
              }
            }
          }
        }
      }

      // Color temperature slider — visible when enabled
      ColumnLayout {
        Layout.fillWidth: true
        visible: root.nightLightMode !== "Never"
        spacing: s(6)

        RowLayout {
          Layout.fillWidth: true
          Text { text: "warmth"; font.pixelSize: s(10); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textDim; Layout.fillWidth: true }
          Text { text: root.nightLightTemp + "%"; font.pixelSize: s(10); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent }
        }

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: s(20)

          Rectangle {
            id: nlTempTrack
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: s(6)
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.1)

            Rectangle {
              width: parent.width * (root.nightLightTemp / 100)
              height: parent.height
              radius: height / 2
              color: MatugenColors.accent
            }
          }

          Rectangle {
            width: s(16); height: s(16); radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(nlTempTrack.width - width, nlTempTrack.width * (root.nightLightTemp / 100) - width / 2))
            color: "white"
            border.color: Qt.rgba(0, 0, 0, 0.2)
            border.width: 1
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: (mouse) => updateFromX(mouse.x)
            onPositionChanged: (mouse) => { if (pressed) updateFromX(mouse.x) }
            function updateFromX(x) {
              const pct = Math.max(0, Math.min(1, x / width))
              root.setNightLightTemp(Math.round(pct * 100))
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        visible: root.nightLightMode !== "Never"
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
      }

      // Schedule toggle
      RowLayout {
        Layout.fillWidth: true
        visible: root.nightLightMode !== "Never"
        spacing: s(8)

        Text { text: "\uf017"; font.pixelSize: s(14); font.family: root.fontFamily; color: MatugenColors.accent }
        Text { text: "Automated schedule"; font.pixelSize: s(13); font.family: root.fontFamily; color: MatugenColors.text; Layout.fillWidth: true }

        Rectangle {
          id: schedSwitch
          property bool on: root.nightLightMode === "Schedule"
          width: s(44); height: s(24); radius: height / 2
          color: on ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.12)
          Behavior on color { ColorAnimation { duration: 150 } }

          Rectangle {
            width: s(18); height: s(18); radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: schedSwitch.on ? parent.width - width - s(3) : s(3)
            color: "white"
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setNightLightMode(schedSwitch.on ? "On" : "Schedule")
          }
        }
      }

      // Schedule time range — visible when schedule is on
      RowLayout {
        Layout.fillWidth: true
        visible: root.nightLightMode === "Schedule"
        spacing: s(8)

        Text { text: "from"; font.pixelSize: s(10); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textDim }
        Rectangle {
          Layout.preferredWidth: s(64); Layout.preferredHeight: s(26); radius: s(6)
          color: Qt.rgba(1, 1, 1, 0.08)
          TextInput {
            anchors.fill: parent
            anchors.margins: s(4)
            text: root.nightLightFrom
            font.pixelSize: s(10)
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            selectByMouse: true
            onEditingFinished: root.setNightLightFrom(text)
          }
        }

        Text { text: "to"; font.pixelSize: s(10); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textDim }
        Rectangle {
          Layout.preferredWidth: s(64); Layout.preferredHeight: s(26); radius: s(6)
          color: Qt.rgba(1, 1, 1, 0.08)
          TextInput {
            anchors.fill: parent
            anchors.margins: s(4)
            text: root.nightLightTo
            font.pixelSize: s(10)
            font.family: "JetBrainsMono Nerd Font"
            color: MatugenColors.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            selectByMouse: true
            onEditingFinished: root.setNightLightTo(text)
          }
        }

        Item { Layout.fillWidth: true }
      }
    }
  }

  Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

  Text { visible: root.matches("Auto-lock"); text: "AUTO-LOCK"; font.pixelSize: s(10); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.border }

  Item {
    visible: root.matches("Auto-lock")
    Layout.fillWidth: true
    Layout.preferredHeight: s(44)

    Rectangle {
      id: autoLockRow
      anchors.fill: parent
      radius: s(Config.uiRadius)
      color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

      RowLayout {
        anchors.fill: parent
        anchors.margins: s(10)
        spacing: s(8)

        Text { text: "lock screen after"; font.pixelSize: s(13); font.family: root.fontFamily; color: MatugenColors.text; Layout.fillWidth: true }

        Item {
          id: alTriggerAnchor
          Layout.preferredWidth: s(110)
          Layout.preferredHeight: s(26)

          Rectangle {
            id: alTriggerBox
            anchors.fill: parent
            radius: s(8)
            color: alBtnMa.containsMouse || alDropdown.opened ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16) : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: s(10)
              anchors.rightMargin: s(8)
              spacing: s(4)

              Text {
                Layout.fillWidth: true
                text: (root.autoLockChoices.find(c => c.s === root.autoLockSeconds) || root.autoLockChoices[root.autoLockChoices.length - 1]).label
                font.pixelSize: s(11)
                font.weight: Font.Bold
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.text
                elide: Text.ElideRight
              }
              Text {
                text: alDropdown.opened ? "\uf077" : "\uf078"
                font.pixelSize: s(9)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.textDim
              }
            }

            MouseArea {
              id: alBtnMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: alDropdown.opened ? alDropdown.close() : alDropdown.open()
            }
          }

          Popup {
            id: alDropdown
            parent: alTriggerBox
            y: alTriggerBox.height + s(4)
            x: 0
            width: alTriggerBox.width
            height: Math.min(s(200), root.autoLockChoices.length * s(28) + s(8))
            padding: s(4)
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

            background: Rectangle {
              radius: s(8)
              color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.98)
              border.width: 1
              border.color: Qt.rgba(1, 1, 1, 0.12)
            }

            contentItem: ListView {
              clip: true
              model: root.autoLockChoices
              delegate: Rectangle {
                width: ListView.view.width
                height: s(26)
                radius: s(6)
                readonly property bool selected: root.autoLockSeconds === modelData.s
                color: selected ? MatugenColors.accent : (alItemMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                  anchors.centerIn: parent
                  text: modelData.label
                  font.pixelSize: s(10)
                  font.weight: Font.Bold
                  font.family: "JetBrainsMono Nerd Font"
                  color: selected ? MatugenColors.bgBase : MatugenColors.text
                }
                MouseArea {
                  id: alItemMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { root.setAutoLockSeconds(modelData.s); alDropdown.close() }
                }
              }
            }
          }
        }
      }
    }
  }

  Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

  Text { visible: root.matches("Desktop widgets"); text: "DESKTOP WIDGETS"; font.pixelSize: s(10); font.weight: Font.Bold; font.family: root.fontFamily; color: MatugenColors.border }

  Rectangle {
    visible: root.matches("Desktop widgets")
    Layout.fillWidth: true
    Layout.preferredHeight: s(44)
    radius: s(Config.uiRadius)
    color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

    RowLayout {
      anchors.fill: parent
      anchors.margins: s(10)
      spacing: s(8)

      Text { text: "\uf26c"; font.pixelSize: s(14); font.family: root.fontFamily; color: MatugenColors.accent }
      Text { text: "Edit desktop widgets"; font.pixelSize: s(13); font.family: root.fontFamily; color: MatugenColors.text; Layout.fillWidth: true }

      Rectangle {
        width: s(72); height: s(28); radius: s(14)
        color: editWidgetsMa.containsMouse ? Qt.lighter(MatugenColors.accent, 1.1) : MatugenColors.accent

        Text {
          anchors.centerIn: parent
          text: "Open"
          font.pixelSize: s(11)
          font.weight: Font.Bold
          font.family: root.fontFamily
          color: MatugenColors.accentText
        }

        MouseArea {
          id: editWidgetsMa
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.menuOpenSetter(false)
            desktopEditDelay.start()
          }
        }
      }
    }
  }

  Timer { id: desktopEditDelay; interval: 260; onTriggered: Config.desktopEditMode = true }
}
