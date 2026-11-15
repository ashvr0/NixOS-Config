import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../Singletons"

Item {
  id: root

  property bool vertical: Config.barVertical
  property real counterRotation: vertical ? (Config.barPosition === "left" ? 90 : -90) : 0

  Component.onCompleted: {
    Scaler.currentWidth = Screen.width
    Scaler.currentHeight = Screen.height
  }
  function s(val) { return Scaler.s(val) }

  implicitWidth: vertical ? s(50) : (barRow.implicitWidth + 20 * Config.uiScale)
  implicitHeight: vertical ? (barColumn.implicitHeight + 20 * Config.uiScale) : s(56)

  // Entrance
  property int  cascadeIndex: 1
  property bool entered: false
  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }
  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } } }
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

  Rectangle {
    id: pillBg
    visible: false
    height: root.vertical ? (barColumn.implicitHeight + 24 * Config.uiScale) : 50 * Config.uiScale
    width: root.vertical ? s(50) : (barRow.implicitWidth + 24 * Config.uiScale)
    radius: 14 * Config.uiScale
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter

    color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.82)

    border.color: Qt.rgba(1, 1, 1, 0.09)
    border.width: 1 * Config.uiScale
  }

  // Bar row (horizontal bar)
  Row {
    id: barRow
    visible: !root.vertical
    anchors.verticalCenter: parent.verticalCenter
    x: 6 * Config.uiScale
    spacing: 16 * Config.uiScale

    // Calendar
    Item {
      width: calendarModule.implicitWidth + 14 * Config.uiScale; height: 56 * Config.uiScale

      MouseArea {
        id: calHoverBg
        anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton
      }

      Item {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 3 * Config.uiScale
        width: parent.width - 4 * Config.uiScale; height: 32 * Config.uiScale
        opacity: (calHoverBg.containsMouse || calendarModule.calendarOpen) ? 0.6 : 0.32
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Rectangle { anchors.fill: parent; anchors.margins: -4 * Config.uiScale; radius: 14 * Config.uiScale; color: Qt.rgba(0, 0, 0, 0.05) }
        Rectangle { anchors.fill: parent; anchors.margins: -2 * Config.uiScale; radius: 12 * Config.uiScale; color: Qt.rgba(0, 0, 0, 0.07) }
        Rectangle {
          anchors.fill: parent; radius: 10 * Config.uiScale
          color: calendarModule.calendarOpen ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.14) : Qt.rgba(0, 0, 0, 0.10)
          Behavior on color { ColorAnimation { duration: 150 } }
        }
      }

      Calendar {
        id: calendarModule
        anchors.centerIn: parent
      }
    }
  }

  // Bar column (vertical bar)
  Column {
    id: barColumn
    visible: root.vertical
    anchors.horizontalCenter: parent.horizontalCenter
    y: 6 * Config.uiScale
    spacing: 16 * Config.uiScale

    Item {
      width: 56 * Config.uiScale; height: calendarModuleV.implicitHeight + 14 * Config.uiScale

      MouseArea {
        id: calHoverBgV
        anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton
      }

      Item {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 3 * Config.uiScale
        height: parent.height - 4 * Config.uiScale; width: 32 * Config.uiScale
        opacity: (calHoverBgV.containsMouse || calendarModuleV.calendarOpen) ? 0.6 : 0.32
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Rectangle { anchors.fill: parent; anchors.margins: -4 * Config.uiScale; radius: 14 * Config.uiScale; color: Qt.rgba(0, 0, 0, 0.05) }
        Rectangle { anchors.fill: parent; anchors.margins: -2 * Config.uiScale; radius: 12 * Config.uiScale; color: Qt.rgba(0, 0, 0, 0.07) }
        Rectangle {
          anchors.fill: parent; radius: 10 * Config.uiScale
          color: calendarModuleV.calendarOpen ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.14) : Qt.rgba(0, 0, 0, 0.10)
          Behavior on color { ColorAnimation { duration: 150 } }
        }
      }

      Calendar {
        id: calendarModuleV
        anchors.centerIn: parent
      }
    }
  }
}
