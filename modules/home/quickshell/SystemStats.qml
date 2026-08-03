import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
  id: root
  implicitWidth: barRow.implicitWidth + 20 * Config.uiScale

  // Entrance
  property int  cascadeIndex: 1
  property bool entered: false
  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }
  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } } }
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

  // Floating pill background. Always hidden now — Bar.qml draws one
  // continuous surface behind the whole right zone in both bar styles,
  // so this module no longer needs its own separate box.
  Rectangle {
    id: pillBg
    visible: false
    height: 50 * Config.uiScale
    width: barRow.implicitWidth + 24 * Config.uiScale
    radius: 14 * Config.uiScale
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter

    color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.82)

    border.color: Qt.rgba(1, 1, 1, 0.09)
    border.width: 1 * Config.uiScale
  }

  // Bar row
  Row {
    id: barRow
    anchors.verticalCenter: parent.verticalCenter
    anchors.right: parent.right
    anchors.rightMargin: 14 * Config.uiScale
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
}
