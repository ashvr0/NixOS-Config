import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
  id: root
  implicitWidth: barRow.implicitWidth + 20

  Audio {
    id: audioModule
  }

  Network {
    id: networkModule
  }

  // Bound properties from modules
  property alias volumeLevel:    audioModule.volumeLevel
  property alias volumeIcon:     audioModule.volumeIcon
  property alias sinkName:       audioModule.sinkName
  property alias volumeMenuOpen: audioModule.volumeMenuOpen
  property alias muted:          audioModule.muted
  property alias osdVisible:     audioModule.osdVisible

  property alias networkMenuOpen: networkModule.networkMenuOpen
  property alias wifiName:        networkModule.statusText
  property alias wifiPowered:     networkModule.wifiPowered
  property alias btPowered:       networkModule.btPowered

  // Entrance
  property int  cascadeIndex: 1
  property bool entered: false
  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }
  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutBack } } }
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

  // Floating pill background
  Rectangle {
    id: pillBg
    height: 50
    width: barRow.implicitWidth + 24
    radius: 14
    color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.75)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
  }

  // Bar row
  Row {
    id: barRow
    anchors.verticalCenter: parent.verticalCenter
    anchors.right: parent.right
    anchors.rightMargin: 14
    spacing: 16

    Item {
      width: volInner.implicitWidth; height: 56
      Row {
        id: volInner; spacing: 8
        anchors.verticalCenter: parent.verticalCenter

        Text { text: root.volumeIcon; font.pixelSize: 13; color: root.volumeMenuOpen ? MatugenColors.accent : MatugenColors.textMuted; anchors.verticalCenter: parent.verticalCenter }

        Item {
          width: 60; height: 56
          Rectangle {
            width: parent.width; height: 4; radius: 2; color: MatugenColors.borderSoft
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
              width: parent.width * Math.min(root.volumeLevel, 100) / 100
              height: parent.height; radius: 2
              color: root.volumeLevel > 100 ? MatugenColors.warning : MatugenColors.accent
            }
          }
        }

        Text { text: root.volumeLevel + "%"; font.pixelSize: 10; color: root.volumeMenuOpen ? MatugenColors.accent : MatugenColors.text; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
      }
      MouseArea {
        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
        onClicked: {
          root.volumeMenuOpen = !root.volumeMenuOpen
          if (root.networkMenuOpen) root.networkMenuOpen = false
        }
      }
    }

    Item { width: 1; height: 56; Rectangle { anchors.centerIn: parent; width: 1; height: 18; color: MatugenColors.borderSoft } }

    // WiFi
    Item {
      width: wifiInner.implicitWidth; height: 56
      Row {
        id: wifiInner; spacing: 5
        anchors.verticalCenter: parent.verticalCenter
        Text { text: networkModule.ethConnected ? "󰈀" : "󰤨"; font.pixelSize: 13; color: root.networkMenuOpen ? MatugenColors.accent : MatugenColors.textMuted; anchors.verticalCenter: parent.verticalCenter }
        Text { text: root.wifiName; font.pixelSize: 10; color: root.networkMenuOpen ? MatugenColors.accent : MatugenColors.text; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: Math.min(implicitWidth, 90) }
      }
      MouseArea {
        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
        onClicked: {
          root.networkMenuOpen = !root.networkMenuOpen
          if (root.volumeMenuOpen) root.volumeMenuOpen = false
        }
      }
    }
  }
}
