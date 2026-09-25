import "Singletons"
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Bluetooth

Item {
  id: root

  Component.onCompleted: {
        Scaler.currentWidth = Screen.width
        Scaler.currentHeight = Screen.height
    }
  function s(val) { return Scaler.s(val) }

  IpcHandler {
    target: "bluetooth"
    function toggle(): void {
      root.btMenuOpen = !root.btMenuOpen
    }
  }

  property bool btMenuOpen: false
  property var selectedDevice: null

  onBtMenuOpenChanged: {
    if (!btMenuOpen) {
      selectedDevice = null
      if (btAdapter) btAdapter.discovering = false
    } else if (btAdapter && btAdapter.enabled) {
      btAdapter.discovering = true
    }
  }

  readonly property var btAdapter: (typeof Bluetooth !== "undefined" && Bluetooth) ? Bluetooth.defaultAdapter : null
  readonly property bool btPowered: btAdapter ? btAdapter.enabled : false
  readonly property var btDevices: (typeof Bluetooth !== "undefined" && Bluetooth && Bluetooth.devices) ? Bluetooth.devices.values : []
  readonly property var btConnected: btDevices.find(function(d) { return d && d.connected }) || null
  readonly property string statusText: btConnected ? ((btConnected.deviceName || btConnected.name) || "Connected") : (btPowered ? "Bluetooth" : "Bluetooth Off")

  readonly property var myDevices: btDevices.filter(function(d) { return d && d.paired })
  readonly property var otherDevices: btDevices.filter(function(d) { return d && !d.paired })

  onBtPoweredChanged: {
    if (btPowered && btMenuOpen && btAdapter) btAdapter.discovering = true
  }

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
        width: s(720)
        height: s(520)
        x: Config.barPosition === "left" ? s(80) : (Config.barPosition === "right" ? (Screen.width - width - s(80)) : (Screen.width - width - s(8)))
        y: Config.barPosition === "bottom" ? (Screen.height - height - s(70)) : (Config.barPosition === "left" || Config.barPosition === "right" ? (Screen.height - height - s(85)) : s(70))
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
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: ""; color: MatugenColors.border; font.pixelSize: s(28); font.family: "JetBrainsMono Nerd Font" }
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
              spacing: s(14)

              Column {
                width: parent.width; spacing: s(4)
                visible: root.myDevices.length > 0

                Text {
                  text: "My Devices"
                  color: MatugenColors.textMuted
                  font.pixelSize: s(10)
                  font.weight: Font.DemiBold
                  font.family: "JetBrainsMono Nerd Font"
                  leftPadding: s(4)
                }

                Column {
                  width: parent.width; spacing: s(4)
                  Repeater {
                    model: root.myDevices
                    Rectangle {
                      required property var modelData
                      width: parent.width; height: s(42); radius: s(8)
                      color: modelData.connected ? MatugenColors.bgElevated2 : rowHoverMy.containsMouse ? MatugenColors.bgElevated2 : MatugenColors.bgElevated
                      border.width: modelData.connected ? 1 : 0
                      border.color: MatugenColors.accent
                      Behavior on color { ColorAnimation { duration: 120 } }

                      Text {
                        text: "󰂯"
                        color: modelData.connected ? MatugenColors.accent : MatugenColors.border
                        font.pixelSize: s(15)
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.left: parent.left; anchors.leftMargin: s(12)
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      Text {
                        text: (modelData.deviceName || modelData.name) || "Unknown Device"
                        color: modelData.connected ? MatugenColors.text : MatugenColors.textMuted
                        font.pixelSize: s(12)
                        font.family: "JetBrainsMono Nerd Font"
                        font.weight: modelData.connected ? Font.DemiBold : Font.Normal
                        anchors.left: parent.left; anchors.leftMargin: s(37)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: statusPillMy.left; anchors.rightMargin: s(10)
                        elide: Text.ElideRight
                      }

                      Rectangle {
                        id: statusPillMy
                        anchors.right: infoBtnMy.left; anchors.rightMargin: s(8)
                        anchors.verticalCenter: parent.verticalCenter
                        width: statusLabelMy.implicitWidth + s(14); height: s(20); radius: s(10)
                        color: modelData.connected
                          ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16)
                          : MatugenColors.bgElevated2
                        Text {
                          id: statusLabelMy
                          anchors.centerIn: parent
                          text: modelData.connected ? "Connected" : "Not Connected"
                          color: modelData.connected ? MatugenColors.accent : MatugenColors.textMuted
                          font.pixelSize: s(9)
                          font.family: "JetBrainsMono Nerd Font"
                          font.weight: Font.DemiBold
                        }
                      }

                      Rectangle {
                        id: infoBtnMy
                        anchors.right: parent.right; anchors.rightMargin: s(12)
                        anchors.verticalCenter: parent.verticalCenter
                        width: s(22); height: s(22); radius: s(11)
                        color: infoAreaMy.containsMouse ? MatugenColors.bgElevated2 : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                          anchors.centerIn: parent
                          text: "i"
                          color: MatugenColors.textMuted
                          font.pixelSize: s(12)
                          font.family: "JetBrainsMono Nerd Font"
                          font.italic: true
                          font.weight: Font.Bold
                        }
                        MouseArea {
                          id: infoAreaMy
                          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: root.selectedDevice = modelData
                        }
                      }

                      MouseArea {
                        id: rowHoverMy
                        anchors.left: parent.left; anchors.right: infoBtnMy.left
                        anchors.top: parent.top; anchors.bottom: parent.bottom
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          if (!modelData) return
                          if (modelData.connected) modelData.disconnect()
                          else modelData.connect()
                        }
                      }
                    }
                  }
                }
              }

              Column {
                width: parent.width; spacing: s(4)
                visible: root.otherDevices.length > 0

                Text {
                  text: "Other Devices"
                  color: MatugenColors.textMuted
                  font.pixelSize: s(10)
                  font.weight: Font.DemiBold
                  font.family: "JetBrainsMono Nerd Font"
                  leftPadding: s(4)
                }

                Column {
                  width: parent.width; spacing: s(4)
                  Repeater {
                    model: root.otherDevices
                    Rectangle {
                      required property var modelData
                      width: parent.width; height: s(42); radius: s(8)
                      color: modelData.connected ? MatugenColors.bgElevated2 : rowHoverOther.containsMouse ? MatugenColors.bgElevated2 : MatugenColors.bgElevated
                      border.width: modelData.connected ? 1 : 0
                      border.color: MatugenColors.accent
                      Behavior on color { ColorAnimation { duration: 120 } }

                      Text {
                        text: "󰂯"
                        color: modelData.connected ? MatugenColors.accent : MatugenColors.border
                        font.pixelSize: s(15)
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.left: parent.left; anchors.leftMargin: s(12)
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      Text {
                        text: (modelData.deviceName || modelData.name) || "Unknown Device"
                        color: modelData.connected ? MatugenColors.text : MatugenColors.textMuted
                        font.pixelSize: s(12)
                        font.family: "JetBrainsMono Nerd Font"
                        font.weight: modelData.connected ? Font.DemiBold : Font.Normal
                        anchors.left: parent.left; anchors.leftMargin: s(37)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: statusPillOther.left; anchors.rightMargin: s(10)
                        elide: Text.ElideRight
                      }

                      Rectangle {
                        id: statusPillOther
                        anchors.right: infoBtnOther.left; anchors.rightMargin: s(8)
                        anchors.verticalCenter: parent.verticalCenter
                        width: statusLabelOther.implicitWidth + s(14); height: s(20); radius: s(10)
                        color: modelData.connected
                          ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16)
                          : MatugenColors.bgElevated2
                        Text {
                          id: statusLabelOther
                          anchors.centerIn: parent
                          text: modelData.connected ? "Connected" : "Not Connected"
                          color: modelData.connected ? MatugenColors.accent : MatugenColors.textMuted
                          font.pixelSize: s(9)
                          font.family: "JetBrainsMono Nerd Font"
                          font.weight: Font.DemiBold
                        }
                      }

                      Rectangle {
                        id: infoBtnOther
                        anchors.right: parent.right; anchors.rightMargin: s(12)
                        anchors.verticalCenter: parent.verticalCenter
                        width: s(22); height: s(22); radius: s(11)
                        color: infoAreaOther.containsMouse ? MatugenColors.bgElevated2 : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                          anchors.centerIn: parent
                          text: "i"
                          color: MatugenColors.textMuted
                          font.pixelSize: s(12)
                          font.family: "JetBrainsMono Nerd Font"
                          font.italic: true
                          font.weight: Font.Bold
                        }
                        MouseArea {
                          id: infoAreaOther
                          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: root.selectedDevice = modelData
                        }
                      }

                      MouseArea {
                        id: rowHoverOther
                        anchors.left: parent.left; anchors.right: infoBtnOther.left
                        anchors.top: parent.top; anchors.bottom: parent.bottom
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          if (!modelData) return
                          if (modelData.connected) modelData.disconnect()
                          else modelData.connect()
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        Rectangle {
          id: infoPanel
          anchors.fill: parent
          z: 10
          color: MatugenColors.bgBase
          visible: root.selectedDevice !== null
          radius: s(14)

          property var dev: root.selectedDevice

          Column {
            anchors.fill: parent
            anchors.margins: s(16)
            spacing: s(12)

            Item {
              width: parent.width; height: s(32)

              Rectangle {
                id: backBtn
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: s(26); height: s(26); radius: s(8)
                color: backArea.containsMouse ? MatugenColors.bgElevated2 : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                  anchors.centerIn: parent
                  text: "󰅁"
                  color: MatugenColors.text
                  font.pixelSize: s(15)
                  font.family: "JetBrainsMono Nerd Font"
                }
                MouseArea {
                  id: backArea
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: root.selectedDevice = null
                }
              }

              Text {
                anchors.centerIn: parent
                text: "Device Info"
                color: MatugenColors.text
                font.pixelSize: s(13)
                font.weight: Font.Bold
                font.family: "JetBrainsMono Nerd Font"
              }
            }

            Rectangle {
              width: parent.width; height: 1
              color: MatugenColors.borderSoft ? MatugenColors.borderSoft : MatugenColors.border
              opacity: 0.6
            }

            Column {
              width: parent.width; spacing: s(4)
              topPadding: s(8)
              visible: infoPanel.dev !== null

              Text {
                text: infoPanel.dev ? ((infoPanel.dev.deviceName || infoPanel.dev.name) || "Unknown Device") : ""
                color: MatugenColors.text
                font.pixelSize: s(16)
                font.weight: Font.Bold
                font.family: "JetBrainsMono Nerd Font"
              }
            }

            Column {
              width: parent.width; spacing: s(2)
              topPadding: s(10)

              Repeater {
                model: infoPanel.dev ? [
                  { label: "Status", value: infoPanel.dev.connected ? "Connected" : "Not Connected" },
                  { label: "Paired", value: infoPanel.dev.paired ? "Yes" : "No" },
                  { label: "Trusted", value: infoPanel.dev.trusted ? "Yes" : "No" },
                  { label: "Battery", value: infoPanel.dev.batteryAvailable ? Math.round(infoPanel.dev.battery * 100) + "%" : "N/A" },
                  { label: "MAC Address", value: infoPanel.dev.address || "Unknown" }
                ] : []

                Item {
                  width: parent.width; height: s(36)

                  Text {
                    text: modelData.label
                    color: MatugenColors.textMuted
                    font.pixelSize: s(12)
                    font.family: "JetBrainsMono Nerd Font"
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: modelData.value
                    color: MatugenColors.text
                    font.pixelSize: s(12)
                    font.family: "JetBrainsMono Nerd Font"
                    font.weight: Font.DemiBold
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 1
                    color: MatugenColors.borderSoft ? MatugenColors.borderSoft : MatugenColors.border
                    opacity: 0.3
                  }
                }
              }
            }

            Item { width: 1; height: s(6) }

            Rectangle {
              width: parent.width; height: s(38); radius: s(10)
              color: infoPanel.dev && infoPanel.dev.connected ? MatugenColors.bgElevated2 : MatugenColors.accent
              visible: infoPanel.dev !== null

              Text {
                anchors.centerIn: parent
                text: infoPanel.dev && infoPanel.dev.connected ? "Disconnect" : "Connect"
                color: infoPanel.dev && infoPanel.dev.connected ? MatugenColors.text : MatugenColors.accentText
                font.pixelSize: s(12)
                font.weight: Font.DemiBold
                font.family: "JetBrainsMono Nerd Font"
              }

              MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (!infoPanel.dev) return
                  if (infoPanel.dev.connected) infoPanel.dev.disconnect()
                  else infoPanel.dev.connect()
                }
              }
            }
          }
        }
      }
    }
  }
}
