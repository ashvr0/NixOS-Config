import QtQuick
import Quickshell

PanelWindow {
  id: barWindow
  anchors {
    top: true
    left: true
    right: true
  }

  implicitHeight: 56
  margins {
    top: 10
    left: 10
    right: 10
  }
  exclusiveZone: implicitHeight + 8
  color: "transparent"

  Workspaces {
    id: workspaces
    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
    height: parent.height
  }

  MusicPlayer {
    anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
    height: parent.height
  }

  Power {
    id: power
    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
    height: parent.height
  }

  Calendar {
    id: clock
    anchors { right: power.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
    height: parent.height
  }

  SystemStats {
    id: systemStats
    anchors { right: clock.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
    height: parent.height
  }

  Keyboard {
    id: keyboard
    anchors { right: systemStats.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
    height: parent.height
  }

  SystemTray {
    id: tray
    anchors { right: keyboard.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
    height: parent.height
  }
}
