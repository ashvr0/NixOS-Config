import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth

Item {
  id: root

  IpcHandler {
    target: "network"
    function toggle(): void {
    root.networkMenuOpen = !root.networkMenuOpen
    }
  }

  property bool   networkMenuOpen: false
  property string activeTab:    "wifi"

  property bool   showPasswordPrompt: false
  property var    pendingNetwork: null
  property string typedPassword: ""
  property bool   connectFailed: false
  readonly property int chromeHeight: 12 * 2 + 32 + 10

  readonly property var devices: (typeof Networking !== "undefined" && Networking && Networking.devices) ? Networking.devices.values : []

  function looksWired(d) {
    if (!d) return false
    var t = d.type
    var candidates = ["Wired", "Ethernet", "Wire", "Lan"]
    for (var i = 0; i < candidates.length; i++) {
      if (DeviceType[candidates[i]] !== undefined && t === DeviceType[candidates[i]])
        return true
    }
    var iface = (d.interface || d.name || "").toLowerCase()
    if (iface.indexOf("eth") === 0 || iface.indexOf("enp") === 0 || iface.indexOf("eno") === 0)
      return true
    return false
  }

  readonly property var wifiDevice: devices.find(function(d) { return d && d.type === DeviceType.Wifi }) || null
  readonly property var ethDevice: devices.find(function(d) { return root.looksWired(d) && d.connected }) || null
  readonly property bool ethConnected: ethDevice !== null

  readonly property bool wifiPowered: (typeof Networking !== "undefined" && Networking) ? Networking.wifiEnabled : false
  readonly property var  wifiNetworks: (wifiDevice && wifiDevice.networks) ? wifiDevice.networks.values : []
  readonly property var  wifiNetworksSorted: wifiNetworks.slice().sort(function(a, b) {
    return ((b ? b.signalStrength : 0) || 0) - ((a ? a.signalStrength : 0) || 0)
  })
  readonly property var  wifiActive: wifiNetworks.find(function(n) { return n && n.connected }) || null
  readonly property string wifiName: wifiActive ? (wifiActive.name || "Connected") : (wifiPowered ? "Disconnected" : "Wi-Fi")
  readonly property string statusText: ethConnected ? (ethDevice ? (ethDevice.interface || ethDevice.name || "Ethernet") : "Ethernet")
    : (wifiActive ? (wifiActive.name || "Connected") : (wifiPowered ? "Disconnected" : "Wi-Fi Off"))
  readonly property bool connected: ethConnected || wifiActive !== null

  property var securityMap: ({})
  property var knownProfiles: ({})

  function isSecured(ssid) {
    var sec = securityMap[ssid]
    return sec !== undefined && sec !== "" && sec !== "--"
  }

  function refreshSecurity() {
    secProc.running = true
  }
  function signalGlyph(strength) {
    var s = strength || 0
    if (s >= 80) return "󰤨"
    if (s >= 60) return "󰤥"
    if (s >= 40) return "󰤢"
    if (s >= 20) return "󰤟"
    return "󰤯"
  }

  readonly property var btAdapter: (typeof Bluetooth !== "undefined" && Bluetooth) ? Bluetooth.defaultAdapter : null
  readonly property bool btPowered: btAdapter ? btAdapter.enabled : false
  readonly property var btDevices: (typeof Bluetooth !== "undefined" && Bluetooth && Bluetooth.devices) ? Bluetooth.devices.values : []

  Process {
    id: secProc
    command: ["nmcli", "-t", "-f", "SSID,SECURITY,IN-USE", "dev", "wifi", "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        var map = {}, known = {}
        var lines = this.text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          if (!lines[i].length) continue
          var parts = lines[i].split(/(?<!\\):/)
          if (parts.length < 3) continue
          var ssid = parts[0].replace(/\\:/g, ":")
          if (!ssid.length) continue
          map[ssid] = parts[1]
          known[ssid] = true
          root.knownProfiles = known
          root.securityLoaded = true
        }
        root.securityMap = map
      }
    }
  }

  Process {
    id: rescanProc
    command: ["nmcli", "dev", "wifi", "rescan"]
  }

  onWifiNetworksChanged: if (root.networkMenuOpen) secRefresh.restart()

  Timer {
    id: secRefresh
    interval: 1200
    onTriggered: if (root.networkMenuOpen) secProc.running = true
  }

  onNetworkMenuOpenChanged: {
    if (networkMenuOpen) {
      root.activeTab          = "wifi"
      root.showPasswordPrompt = false
      root.pendingNetwork     = null
      root.typedPassword      = ""
      root.connectFailed      = false
      root.securityLoaded     = false
      if (root.wifiDevice) root.wifiDevice.scannerEnabled = true
      root.refreshSecurity()
    } else {
      if (root.wifiDevice) root.wifiDevice.scannerEnabled = false
    }
  }

  function rescan() {
    rescanProc.running = true
    if (root.wifiDevice) {
      root.wifiDevice.scannerEnabled = false
      root.wifiDevice.scannerEnabled = true
    }
  }

  property bool securityLoaded: false

  function activateNetwork(net) {
    if (!net) return
    var ssid = net.name || ""
    if (net.connected) return

    if (knownProfiles[ssid] === true) {
      directConnectProc.command = ["nmcli", "connection", "up", "id", ssid]
      directConnectProc.targetNet = net
      directConnectProc.running = true
      return
    }

    if (!root.securityLoaded || !isSecured(ssid)) {
      directConnectProc.command = ["nmcli", "dev", "wifi", "connect", ssid]
      directConnectProc.targetNet = net
      directConnectProc.running = true
      return
    }

    root.pendingNetwork = net
    root.typedPassword = ""
    root.connectFailed = false
    root.showPasswordPrompt = true
  }

  Process {
    id: directConnectProc
    property var targetNet: null
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.networkMenuOpen = false
        root.refreshSecurity()
      } else if (directConnectProc.targetNet) {
        root.pendingNetwork = directConnectProc.targetNet
        root.typedPassword = ""
        root.connectFailed = false
        root.showPasswordPrompt = true
      }
    }
  }

  PanelWindow {
    id: netPopup
    visible: root.networkMenuOpen
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-network-popup"

    anchors { top: true; left: true; right: true; bottom: true }

    MouseArea {
      anchors.fill: parent
      onClicked: root.networkMenuOpen = false
    }

    FocusScope {
      anchors.fill: parent
      focus: root.networkMenuOpen
      Keys.onEscapePressed: root.networkMenuOpen = false

      Rectangle {
        id: netCard
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 70
        anchors.rightMargin: 8
        width: 410
        height: root.showPasswordPrompt ? 160 : 320
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        color: MatugenColors.bgBase
        border.color: MatugenColors.border
        border.width: 2
        radius: 10
        clip: true

        MouseArea { anchors.fill: parent }

        // Password prompt
        Column {
          anchors.fill: parent
          anchors.margins: 16
          spacing: 10
          visible: root.showPasswordPrompt

          Row {
            width: parent.width; spacing: 8
            Text { text: "󰤨"; font.pixelSize: 14; color: MatugenColors.accent; anchors.verticalCenter: parent.verticalCenter }
            Text {
              text: root.pendingNetwork ? root.pendingNetwork.name : ""
              font.pixelSize: 12; font.weight: Font.Bold; color: MatugenColors.text
              anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: parent.width - 30
            }
          }

          Rectangle {
            width: parent.width; height: 36; radius: 8
            color: MatugenColors.bgElevated; border.color: MatugenColors.borderSoft; border.width: 1

            TextInput {
              id: pwInput
              anchors.fill: parent
              anchors.leftMargin: 12; anchors.rightMargin: 12
              verticalAlignment: TextInput.AlignVCenter
              echoMode: TextInput.Password
              color: MatugenColors.text; font.pixelSize: 12
              focus: root.showPasswordPrompt

              Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                text: "Password"
                color: MatugenColors.border; font.pixelSize: 12
                visible: pwInput.text.length === 0
              }

              onAccepted: connectBtn.doConnect()
            }
          }

          Text {
            visible: root.connectFailed
            text: "Connection failed"
            color: MatugenColors.accent
            font.pixelSize: 10
          }

          Row {
            width: parent.width; spacing: 8

            Rectangle {
              width: (parent.width - 8) / 2; height: 36; radius: 8
              color: cancelHover.containsMouse ? MatugenColors.bgElevated : MatugenColors.bgElevated2
              Behavior on color { ColorAnimation { duration: 150 } }

              Text { anchors.centerIn: parent; text: "Cancel"; color: MatugenColors.textMuted; font.pixelSize: 11 }
              MouseArea {
                id: cancelHover
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { root.showPasswordPrompt = false; pwInput.text = ""; root.connectFailed = false }
              }
            }

            Rectangle {
              id: connectBtn
              width: (parent.width - 8) / 2; height: 36; radius: 8
              color: connHover.containsMouse ? Qt.lighter(MatugenColors.accent, 1.15) : MatugenColors.accent
              Behavior on color { ColorAnimation { duration: 150 } }

              function doConnect() {
                if (!root.pendingNetwork || !pwInput.text) return
                connProc.command = ["nmcli", "--ask", "dev", "wifi", "connect", root.pendingNetwork.name]
                connProc.pw = pwInput.text
                connProc.running = true
              }

              Text { anchors.centerIn: parent; text: "Connect"; color: MatugenColors.accentText; font.pixelSize: 11; font.weight: Font.Bold }
              MouseArea {
                id: connHover
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: connectBtn.doConnect()
              }
            }
          }

          Process {
            id: connProc
            property string pw: ""
            stdinEnabled: true
            stdout: StdioCollector {}
            stderr: StdioCollector {}
            onStarted: { write(pw + "\n"); pw = "" }
            onExited: function(exitCode) {
              if (exitCode === 0) {
                root.showPasswordPrompt = false
                root.connectFailed = false
                pwInput.text = ""
                root.networkMenuOpen = false
                root.refreshSecurity()
              } else {
                root.connectFailed = true
              }
            }
          }
        }

        //  list view
        Column {
          id: listView
          anchors.fill: parent
          anchors.margins: 12
          spacing: 10
          visible: !root.showPasswordPrompt

          Item {
            id: tabRow
            width: parent.width; height: 32

            Row {
              anchors.left: parent.left
              anchors.top: parent.top; anchors.bottom: parent.bottom
              width: parent.width * 0.55

              Repeater {
                model: [{ key: "wifi", label: "󰤨   Wi-Fi" }, { key: "bt", label: "󰂯   Bluetooth" }]
                Item {
                  width: parent.width / 2; height: 32
                  Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: root.activeTab === modelData.key ? MatugenColors.text : MatugenColors.border
                    font.pixelSize: 11
                    font.weight: root.activeTab === modelData.key ? Font.Bold : Font.Normal
                  }
                  Rectangle {
                    anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 20; height: 2; radius: 1; color: MatugenColors.accent
                    visible: root.activeTab === modelData.key
                  }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.activeTab = modelData.key
                  }
                }
              }
            }

            Row {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: 6

              Rectangle {
                width: 26; height: 26; radius: 6
                visible: root.activeTab === "wifi" && root.wifiPowered
                color: rescanArea.containsMouse ? MatugenColors.bgElevated : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text { anchors.centerIn: parent; text: "󰑐"; font.pixelSize: 13; color: rescanArea.containsMouse ? MatugenColors.text : MatugenColors.border }

                MouseArea {
                  id: rescanArea
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: root.rescan()
                }
              }

              // Wi-Fi power toggle
              Rectangle {
                width: 48; height: 26; radius: 13
                visible: root.activeTab === "wifi"
                color: root.wifiPowered ? MatugenColors.accent : MatugenColors.bgElevated
                Behavior on color { ColorAnimation { duration: 250 } }

                Rectangle {
                  width: 20; height: 20; radius: 10; color: "white"
                  anchors.verticalCenter: parent.verticalCenter
                  x: root.wifiPowered ? parent.width - width - 3 : 3
                  Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                }

                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: if (typeof Networking !== "undefined" && Networking) Networking.wifiEnabled = !Networking.wifiEnabled
                }
              }

              // BT power toggle
              Rectangle {
                width: 48; height: 26; radius: 13
                visible: root.activeTab === "bt"
                color: root.btPowered ? MatugenColors.accent : MatugenColors.bgElevated
                Behavior on color { ColorAnimation { duration: 250 } }

                Rectangle {
                  width: 20; height: 20; radius: 10; color: "white"
                  anchors.verticalCenter: parent.verticalCenter
                  x: root.btPowered ? parent.width - width - 3 : 3
                  Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                }

                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: if (root.btAdapter) root.btAdapter.enabled = !root.btAdapter.enabled
                }
              }
            }
          }

          // Wi-Fi list — Known Networks first, then everything else in range
          Item {
            width: parent.width
            visible: root.activeTab === "wifi"
            height: root.activeTab === "wifi" && !root.showPasswordPrompt
              ? Math.min(wifiListCol.implicitHeight, netCard.height - root.chromeHeight)
              : 0
            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            clip: true

            Item {
              width: parent.width; height: 34; visible: !root.wifiPowered && !root.ethConnected
              Text { anchors.centerIn: parent; text: "Wi-Fi is turned off"; color: MatugenColors.border; font.pixelSize: 11 }
            }
            Item {
              width: parent.width; height: 34
              visible: root.wifiPowered && root.wifiNetworksSorted.length === 0 && !root.ethConnected
              Text { anchors.centerIn: parent; text: "Searching networks…"; color: MatugenColors.border; font.pixelSize: 11 }
            }

            Flickable {
              anchors.fill: parent
              visible: root.ethConnected || (root.wifiPowered && root.wifiNetworksSorted.length > 0)
              contentHeight: wifiListCol.implicitHeight
              clip: true
              boundsBehavior: Flickable.StopAtBounds

              Column {
                id: wifiListCol
                width: parent.width
                spacing: 8

                // Ethernet
                Column {
                  width: parent.width; spacing: 4
                  visible: root.ethConnected

                  Text {
                    text: "ETHERNET"
                    color: MatugenColors.border
                    font.pixelSize: 9; font.weight: Font.Bold
                    leftPadding: 4
                  }

                  Rectangle {
                    width: parent.width; height: 34; radius: 5
                    color: MatugenColors.bgElevated2

                    Row {
                      anchors.verticalCenter: parent.verticalCenter
                      anchors.left: parent.left; anchors.leftMargin: 10
                      spacing: 8

                      Text {
                        text: "󰈀"
                        color: MatugenColors.accent; font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                      }
                      Text {
                        text: root.ethDevice ? (root.ethDevice.interface || root.ethDevice.name || "Ethernet") : "Ethernet"
                        color: MatugenColors.text; font.pixelSize: 11
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: 200
                      }
                    }

                    Text {
                      anchors.right: parent.right; anchors.rightMargin: 10
                      anchors.verticalCenter: parent.verticalCenter
                      text: "✓"; color: MatugenColors.accent; font.pixelSize: 11
                    }
                  }
                }

                // Known Networks 
                Column {
                  width: parent.width; spacing: 4
                  visible: knownRepeater.count > 0

                  Text {
                    text: "KNOWN NETWORKS"
                    color: MatugenColors.border
                    font.pixelSize: 9; font.weight: Font.Bold
                    leftPadding: 4
                  }

                  Repeater {
                    id: knownRepeater
                    model: root.wifiNetworksSorted.filter(function(n) {
                      return n && (n.connected || root.knownProfiles[n.name] === true)
                    })
                    delegate: Rectangle {
                      id: knownRow
                      required property var modelData
                      width: parent.width; height: 34; radius: 5
                      color: modelData.connected ? MatugenColors.bgElevated2 : knownHover.containsMouse ? MatugenColors.bgElevated2 : MatugenColors.bgElevated

                      Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 10
                        spacing: 8

                        Text {
                          text: root.signalGlyph(modelData.signalStrength)
                          color: modelData.connected ? MatugenColors.accent : MatugenColors.border; font.pixelSize: 13
                          anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                          text: root.isSecured(modelData.name) ? "󰌾" : ""
                          color: MatugenColors.border; font.pixelSize: 10
                          anchors.verticalCenter: parent.verticalCenter
                          visible: text !== ""
                        }
                        Text {
                          text: modelData.name !== "" ? modelData.name : "Hidden"
                          color: modelData.connected ? MatugenColors.text : MatugenColors.textMuted; font.pixelSize: 11
                          font.weight: modelData.connected ? Font.Bold : Font.Normal
                          anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: 150
                        }
                      }

                      Row {
                        anchors.right: parent.right; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                          text: modelData.connected ? "✓" : ""
                          color: MatugenColors.accent; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                          width: 20; height: 20; radius: 5
                          color: forgetHover.containsMouse ? MatugenColors.bgElevated : "transparent"
                          Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 10; color: MatugenColors.border }
                          MouseArea {
                            id: forgetHover
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              forgetProc.command = ["nmcli", "connection", "delete", "id", knownRow.modelData.name]
                              forgetProc.running = true
                            }
                          }
                        }
                      }

                      MouseArea {
                        id: knownHover
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        z: -1
                        onClicked: {
                          if (knownRow.modelData.connected) return
                          root.activateNetwork(knownRow.modelData)
                        }
                      }
                    }
                  }
                }

                // Other Networks
                Column {
                  width: parent.width; spacing: 4
                  visible: otherRepeater.count > 0

                  Text {
                    text: "OTHER NETWORKS"
                    color: MatugenColors.border
                    font.pixelSize: 9; font.weight: Font.Bold
                    leftPadding: 4
                  }

                  Repeater {
                    id: otherRepeater
                    model: root.wifiNetworksSorted.filter(function(n) {
                      return n && !n.connected && root.knownProfiles[n.name] !== true
                    })
                    delegate: Rectangle {
                      required property var modelData
                      width: parent.width; height: 34; radius: 5
                      color: wifiHover.containsMouse ? MatugenColors.bgElevated2 : MatugenColors.bgElevated

                      Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 10
                        spacing: 8

                        Text {
                          text: root.signalGlyph(modelData.signalStrength)
                          color: MatugenColors.border; font.pixelSize: 13
                          anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                          text: root.isSecured(modelData.name) ? "󰌾" : ""
                          color: MatugenColors.border; font.pixelSize: 10
                          anchors.verticalCenter: parent.verticalCenter
                          visible: text !== ""
                        }
                        Text {
                          text: modelData.name !== "" ? modelData.name : "Hidden"
                          color: MatugenColors.textMuted; font.pixelSize: 11
                          anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: 200
                        }
                      }

                      MouseArea {
                        id: wifiHover
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.activateNetwork(modelData)
                      }
                    }
                  }
                }
              }
            }

            Process {
              id: forgetProc
              onExited: root.refreshSecurity()
            }
          }

          // BT list
          Column {
            width: parent.width; spacing: 4
            visible: root.activeTab === "bt"

            Item {
              width: parent.width; height: 34; visible: !root.btPowered
              Text { anchors.centerIn: parent; text: "Bluetooth is turned off"; color: MatugenColors.border; font.pixelSize: 11 }
            }
            Item {
              width: parent.width; height: 34; visible: root.btPowered && root.btDevices.length === 0
              Text { anchors.centerIn: parent; text: "Searching…"; color: MatugenColors.border; font.pixelSize: 11 }
            }

            Repeater {
              model: root.btDevices
              Rectangle {
                required property var modelData
                width: parent.width; height: 34; radius: 5
                color: modelData.connected ? MatugenColors.bgElevated2 : btHover.containsMouse ? MatugenColors.bgElevated2 : MatugenColors.bgElevated

                Row {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left; anchors.leftMargin: 10
                  spacing: 8

                  Text { text: "󰂯"; color: modelData.connected ? MatugenColors.accent : MatugenColors.border; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                  Text {
                    text: (modelData.deviceName || modelData.name) || "Unknown"
                    color: modelData.connected ? MatugenColors.text : MatugenColors.textMuted; font.pixelSize: 11
                    font.weight: modelData.connected ? Font.Bold : Font.Normal
                    anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: 210
                  }
                  Text { text: modelData.connected ? "✓" : ""; color: MatugenColors.accent; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                  id: btHover
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (!modelData) return
                    if (modelData.connected) modelData.disconnect()
                    else modelData.connect()
                    root.networkMenuOpen = false
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
