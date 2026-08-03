import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Bluetooth

Item {
  id: root

  Scaler {
    id: scaler
    currentWidth: Screen.width
    currentHeight: Screen.height
  }
  function s(val) { return scaler.s(val) }

  IpcHandler {
    target: "bluetooth"
    function toggle(): void {
      root.btMenuOpen = !root.btMenuOpen
    }
  }

  property bool btMenuOpen: false

  readonly property var btAdapter: (typeof Bluetooth !== "undefined" && Bluetooth) ? Bluetooth.defaultAdapter : null
  readonly property bool btPowered: btAdapter ? btAdapter.enabled : false
  readonly property var btDevices: (typeof Bluetooth !== "undefined" && Bluetooth && Bluetooth.devices) ? Bluetooth.devices.values : []
  readonly property var btConnected: btDevices.find(function(d) { return d && d.connected }) || null
  readonly property string statusText: btConnected ? ((btConnected.deviceName || btConnected.name) || "Connected") : (btPowered ? "Bluetooth" : "Bluetooth Off")

  PanelWindow {
    id: btPopup
    visible: root.btMenuOpen
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-bluetooth-popup"

    anchors { top: true; left: true; right: true; bottom: true }

    MouseArea {
      anchors.fill: parent
      onClicked: root.btMenuOpen = false
    }

    FocusScope {
      anchors.fill: parent
      focus: root.btMenuOpen
      Keys.onEscapePressed: root.btMenuOpen = false

      Rectangle {
        id: btCard
        width: s(680)
        height: s(520)
        x: Config.barPosition === "left" ? s(8) : (Screen.width - width - s(8))
        y: Config.barPosition === "bottom" ? (Screen.height - height - s(70)) : s(70)
        color: MatugenColors.bgBase
        border.color: MatugenColors.border
        border.width: 1
        radius: s(14)
        clip: true

        MouseArea { anchors.fill: parent }

        Column {
          id: listView
          anchors.fill: parent
          anchors.margins: s(16)
          spacing: s(12)

          Item {
            id: headerRow
            width: parent.width; height: s(32)

            Row {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: s(9)
              Text { text: "󰂯"; color: MatugenColors.accent; font.pixelSize: s(15); font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Bluetooth"; color: MatugenColors.text; font.pixelSize: s(13); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
            }

            Rectangle {
              width: s(48); height: s(26); radius: s(13)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              color: root.btPowered ? MatugenColors.accent : MatugenColors.bgElevated
              opacity: root.btAdapter ? (toggleArea.pressed ? 0.82 : 1.0) : 0.4
              scale: toggleArea.pressed ? 0.96 : 1.0
              Behavior on color { ColorAnimation { duration: 250 } }
              Behavior on opacity { NumberAnimation { duration: 120 } }
              Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

              Rectangle {
                width: s(20); height: s(20); radius: s(10); color: "white"
                anchors.verticalCenter: parent.verticalCenter
                x: root.btPowered ? parent.width - width - s(3) : s(3)
                Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
              }

              MouseArea {
                id: toggleArea
                anchors.fill: parent
                anchors.margins: -s(8)
                enabled: !!root.btAdapter
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                  var target = !root.btAdapter.enabled
                  root.btAdapter.enabled = target
                }
              }
            }
          }

          Rectangle {
            width: parent.width; height: 1
            color: MatugenColors.borderSoft ? MatugenColors.borderSoft : MatugenColors.border
            opacity: 0.6
          }

          Column {
            width: parent.width; spacing: s(6)
            visible: !root.btPowered
            topPadding: s(50)
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰂲"; color: MatugenColors.border; font.pixelSize: s(28); font.family: "JetBrainsMono Nerd Font" }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Bluetooth is off"; color: MatugenColors.border; font.pixelSize: s(11); font.family: "JetBrainsMono Nerd Font" }
          }
          Column {
            width: parent.width; spacing: s(6)
            visible: root.btPowered && root.btDevices.length === 0
            topPadding: s(50)
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰂶"; color: MatugenColors.border; font.pixelSize: s(28); font.family: "JetBrainsMono Nerd Font" }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Searching for devices…"; color: MatugenColors.border; font.pixelSize: s(11); font.family: "JetBrainsMono Nerd Font" }
          }

          Flickable {
            width: parent.width
            height: root.btPowered ? Math.min(btListCol.implicitHeight, btCard.height - s(80)) : 0
            visible: root.btPowered && root.btDevices.length > 0
            contentHeight: btListCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
              id: btListCol
              width: parent.width
              spacing: s(4)

              Repeater {
                model: root.btDevices
                Rectangle {
                  required property var modelData
                  width: parent.width; height: s(42); radius: s(8)
                  color: modelData.connected ? MatugenColors.bgElevated2 : btHover.containsMouse ? MatugenColors.bgElevated2 : MatugenColors.bgElevated
                  border.width: modelData.connected ? 1 : 0
                  border.color: MatugenColors.accent
                  Behavior on color { ColorAnimation { duration: 120 } }

                  Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: s(12)
                    anchors.right: parent.right; anchors.rightMargin: s(12)
                    spacing: s(10)

                    Text {
                      text: "󰂯"
                      color: modelData.connected ? MatugenColors.accent : MatugenColors.border
                      font.pixelSize: s(15)
                      font.family: "JetBrainsMono Nerd Font"
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      text: (modelData.deviceName || modelData.name) || "Unknown Device"
                      color: modelData.connected ? MatugenColors.text : MatugenColors.textMuted
                      font.pixelSize: s(12)
                      font.family: "JetBrainsMono Nerd Font"
                      font.weight: modelData.connected ? Font.DemiBold : Font.Normal
                      anchors.verticalCenter: parent.verticalCenter
                      elide: Text.ElideRight
                      width: parent.width - s(15) - s(10) - (modelData.connected ? (s(80)) : 0)
                    }
                  }

                  Rectangle {
                    visible: modelData.connected
                    anchors.right: parent.right; anchors.rightMargin: s(12)
                    anchors.verticalCenter: parent.verticalCenter
                    width: connectedLabel.implicitWidth + s(14); height: s(20); radius: s(10)
                    color: Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16)
                    Text {
                      id: connectedLabel
                      anchors.centerIn: parent
                      text: "Connected"
                      color: MatugenColors.accent
                      font.pixelSize: s(9)
                      font.family: "JetBrainsMono Nerd Font"
                      font.weight: Font.DemiBold
                    }
                  }

                  MouseArea {
                    id: btHover
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (!modelData) return
                      if (modelData.connected) modelData.disconnect()
                      else modelData.connect()
                      root.btMenuOpen = false
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
}
