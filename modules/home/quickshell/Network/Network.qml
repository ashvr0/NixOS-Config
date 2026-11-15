import ".."
import "../Singletons"
import "../Singletons/PopupPlace.js" as Place
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Networking

Item {
  id: root

  Component.onCompleted: {
        Scaler.currentWidth = Screen.width
        Scaler.currentHeight = Screen.height
    }
  function s(val) { return Scaler.s(val) }
  property real anchorY: Screen.height / 2
  function updateAnchor() {
    var ref = (root.width > 0 && root.height > 0) ? root : root.parent
    if (!ref) return
    var p = ref.mapToItem(null, ref.width / 2, ref.height / 2)
    root.anchorY = p.y + (Config.barVertical ? s(70) : 0)
  }
  IpcHandler {
    target: "network"
    function toggle(): void {
      root.networkMenuOpen = !root.networkMenuOpen
    }
  }

  property bool   networkMenuOpen: false
  property var    selectedNetwork: null

  property bool   showPasswordPrompt: false
  property var    pendingNetwork: null
  property string typedPassword: ""
  property bool   connectFailed: false
  readonly property int chromeHeight: s(12) * 2 + s(32) + s(10)

  // --- Device discovery -------------------------------------------------
  readonly property var devices: (typeof Networking !== "undefined" && Networking && Networking.devices) ? Networking.devices.values : []

  readonly property var wifiDevice: devices.find(function(d) { return d && d.type === DeviceType.Wifi }) || null
  readonly property var ethDevice: devices.find(function(d) { return d && d.type === DeviceType.Wired }) || null

  // WiredDevice exposes hasLink; fall back to connected if unavailable.
  readonly property bool ethHasLink: !!ethDevice && (ethDevice.hasLink !== undefined ? ethDevice.hasLink : ethDevice.connected)
  readonly property bool ethConnected: !!ethDevice && ethDevice.connected

  readonly property bool wifiPowered: (typeof Networking !== "undefined" && Networking) ? Networking.wifiEnabled : false

  // wifiDevice.networks is an ObjectModel<Network>; .values gives a plain array of WifiNetwork
  readonly property var  wifiNetworks: (wifiDevice && wifiDevice.networks) ? wifiDevice.networks.values : []
  readonly property var  wifiNetworksSorted: wifiNetworks.slice().sort(function(a, b) {
    return ((b ? b.signalStrength : 0) || 0) - ((a ? a.signalStrength : 0) || 0)
  })
  readonly property var  wifiActive: wifiNetworks.find(function(n) { return n && n.connected }) || null
  readonly property string wifiName: wifiActive ? (wifiActive.name || "Connected") : (wifiPowered ? "Disconnected" : "Wi-Fi")
  readonly property string statusText: ethConnected ? (ethDevice ? (ethDevice.name || "Ethernet") : "Ethernet")
    : (wifiActive ? (wifiActive.name || "Connected") : (wifiPowered ? "Disconnected" : "Wi-Fi Off"))
  readonly property bool connected: ethConnected || wifiActive !== null

  // --- Security / signal helpers -----------------------------------------
  function securityLabel(sec) {
    switch (sec) {
      case WifiSecurityType.Open: return "None"
      case WifiSecurityType.WpaPsk: return "WPA"
      case WifiSecurityType.Wpa2Psk: return "WPA2"
      case WifiSecurityType.Sae: return "WPA3"
      case WifiSecurityType.WpaEap: return "WPA-Enterprise"
      case WifiSecurityType.Wpa2Eap: return "WPA2-Enterprise"
      case WifiSecurityType.Wpa3SuiteB192: return "WPA3-Enterprise"
      case WifiSecurityType.DynamicWep: return "WEP"
      case WifiSecurityType.StaticWep: return "WEP"
      case WifiSecurityType.Leap: return "LEAP"
      case WifiSecurityType.Owe: return "Enhanced Open"
      default: return "Unknown"
    }
  }

  function isSecured(net) {
    return !!net && net.security !== undefined && net.security !== WifiSecurityType.Open
  }

  function isPskSecurity(sec) {
    return sec === WifiSecurityType.WpaPsk || sec === WifiSecurityType.Wpa2Psk || sec === WifiSecurityType.Sae
  }

  function signalGlyph(strengthFrac) {
    // Network.signalStrength is 0.0-1.0
    var s = Math.round((strengthFrac || 0) * 100)
    if (s >= 80) return "󰤨"
    if (s >= 60) return "󰤥"
    if (s >= 40) return "󰤢"
    if (s >= 20) return "󰤟"
    return "󰤯"
  }

  function refreshSecurity() {
    // No-op: security/known/signal now come live from the Networking API.
    // Kept for call-site compatibility.
  }

  Process { id: rescanProc; command: ["nmcli", "dev", "wifi", "rescan"] }

  property string ethIp: ""
  property string ethMac: ""
  property string ethSpeed: ""

  Process {
    id: ethInfoProc
    running: false
    command: root.ethDevice ? ["bash", "-c",
      "nmcli -g GENERAL.HWADDR,CAPABILITIES.SPEED device show " + root.ethDevice.name + " 2>/dev/null; " +
      "nmcli -g IP4.ADDRESS device show " + root.ethDevice.name + " 2>/dev/null | cut -d/ -f1; " +
      "cat /sys/class/net/" + root.ethDevice.name + "/speed 2>/dev/null"
    ] : ["true"]
    stdout: StdioCollector {
      onStreamFinished: {
        let lines = this.text.trim().split("\n")
        root.ethMac = lines[0] || ""
        root.ethIp = lines[2] || ""
        let spd = lines[3] || lines[1] || ""
        root.ethSpeed = (spd && spd !== "-1") ? (spd + " Mbps") : ""
      }
    }
  }

  function refreshEthInfo() {
    if (root.ethDevice && root.ethConnected) {
      ethInfoProc.running = false
      ethInfoProc.running = true
    }
  }

  function rescan() {
    // Prefer the native scanner toggle; nmcli rescan as a nudge/fallback.
    if (root.wifiDevice) {
      root.wifiDevice.scannerEnabled = false
      root.wifiDevice.scannerEnabled = true
    }
    rescanProc.running = true
  }

  onNetworkMenuOpenChanged: {
    if (networkMenuOpen) root.updateAnchor()
    if (networkMenuOpen) {
      root.showPasswordPrompt = false
      root.pendingNetwork     = null
      root.typedPassword      = ""
      root.connectFailed      = false
      root.selectedNetwork    = null
      if (root.wifiDevice) root.wifiDevice.scannerEnabled = true
      root.refreshEthInfo()
    } else {
      root.selectedNetwork = null
      if (root.wifiDevice) root.wifiDevice.scannerEnabled = false
    }
  }

  // --- Connection actions --------------------------------------------
  // net is a WifiNetwork (from Networking.devices[].networks.values)
  function activateNetwork(net) {
    if (!net || net.connected) return

    if (net.known === true) {
      net.connect()
      return
    }

    if (!isSecured(net)) {
      net.connect()
      return
    }

    root.pendingNetwork = net
    root.typedPassword = ""
    root.connectFailed = false
    root.showPasswordPrompt = true
  }

  Connections {
    target: root.pendingNetwork
    ignoreUnknownSignals: true
    function onConnectionFailed(reason) {
      root.connectFailed = true
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
        width: s(720)
        height: root.showPasswordPrompt ? s(160) : s(520)
        x: Place.place(Config.barPosition, width, height, root.anchorY, Screen.width, Screen.height, root.s).x
        y: Place.place(Config.barPosition, width, height, root.anchorY, Screen.width, Screen.height, root.s).y
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        color: MatugenColors.bgBase
        border.color: MatugenColors.border
        border.width: 1
        radius: s(14)
        clip: true

        MouseArea { anchors.fill: parent }

        // Password prompt
        Column {
          anchors.fill: parent
          anchors.margins: s(16)
          spacing: s(10)
          visible: root.showPasswordPrompt

          Row {
            width: parent.width; spacing: s(8)
            Text { text: "󰤨"; font.pixelSize: s(14); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent; anchors.verticalCenter: parent.verticalCenter }
            Text {
              text: root.pendingNetwork ? root.pendingNetwork.name : ""
              font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold; color: MatugenColors.text
              anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: parent.width - s(30)
            }
          }

          Rectangle {
            width: parent.width; height: s(36); radius: s(8)
            color: MatugenColors.bgElevated; border.color: pwInput.activeFocus ? MatugenColors.accent : MatugenColors.borderSoft; border.width: 1
            Behavior on border.color { ColorAnimation { duration: 150 } }

            TextInput {
              id: pwInput
              anchors.fill: parent
              anchors.leftMargin: s(12); anchors.rightMargin: s(12)
              verticalAlignment: TextInput.AlignVCenter
              echoMode: TextInput.Password
              color: MatugenColors.text; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"
              focus: root.showPasswordPrompt

              Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                text: "Password"
                color: MatugenColors.border; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"
                visible: pwInput.text.length === 0
              }

              onAccepted: connectBtn.doConnect()
            }
          }

          Text {
            visible: root.connectFailed
            text: "Connection failed"
            color: MatugenColors.accent
            font.pixelSize: s(10)
            font.family: "JetBrainsMono Nerd Font"
          }

          Row {
            width: parent.width; spacing: s(8)

            Rectangle {
              width: (parent.width - s(8)) / 2; height: s(36); radius: s(8)
              color: cancelHover.containsMouse ? MatugenColors.bgElevated : MatugenColors.bgElevated2
              Behavior on color { ColorAnimation { duration: 150 } }
              Text { anchors.centerIn: parent; text: "Cancel"; color: MatugenColors.textMuted; font.pixelSize: s(11); font.family: "JetBrainsMono Nerd Font" }
              MouseArea {
                id: cancelHover
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { root.showPasswordPrompt = false; pwInput.text = ""; root.connectFailed = false }
              }
            }

            Rectangle {
              id: connectBtn
              width: (parent.width - s(8)) / 2; height: s(36); radius: s(8)
              color: connHover.containsMouse ? Qt.lighter(MatugenColors.accent, 1.15) : MatugenColors.accent
              Behavior on color { ColorAnimation { duration: 150 } }

              function doConnect() {
                if (!root.pendingNetwork || !pwInput.text) return
                root.connectFailed = false
                // WifiNetwork.connectWithPsk(psk) — only valid for WpaPsk/Wpa2Psk/Sae security
                root.pendingNetwork.connectWithPsk(pwInput.text)
                root.showPasswordPrompt = false
                pwInput.text = ""
                root.networkMenuOpen = false
              }

              Text { anchors.centerIn: parent; text: "Connect"; color: MatugenColors.accentText; font.pixelSize: s(11); font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold }
              MouseArea {
                id: connHover
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: connectBtn.doConnect()
              }
            }
          }
        }

        // List view
        Column {
          id: listView
          anchors.fill: parent
          anchors.margins: s(16)
          spacing: s(12)
          visible: !root.showPasswordPrompt
          enabled: root.selectedNetwork === null

          Item {
            id: headerRow
            width: parent.width; height: s(32)

            Row {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: s(9)
              Text { text: "󰤨"; color: MatugenColors.accent; font.pixelSize: s(15); font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Wi-Fi"; color: MatugenColors.text; font.pixelSize: s(13); font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
            }

            Row {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: s(6)

              Rectangle {
                width: s(26); height: s(26); radius: s(6)
                visible: root.wifiPowered
                color: rescanArea.containsMouse ? MatugenColors.bgElevated : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
                Text { anchors.centerIn: parent; text: "󰑐"; font.pixelSize: s(13); font.family: "JetBrainsMono Nerd Font"; color: rescanArea.containsMouse ? MatugenColors.text : MatugenColors.textMuted }
                MouseArea {
                  id: rescanArea
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: root.rescan()
                }
              }

              Rectangle {
                width: s(48); height: s(26); radius: s(13)
                color: root.wifiPowered ? MatugenColors.accent : MatugenColors.bgElevated
                Behavior on color { ColorAnimation { duration: 250 } }
                Rectangle {
                  width: s(20); height: s(20); radius: s(10); color: "white"
                  anchors.verticalCenter: parent.verticalCenter
                  x: root.wifiPowered ? parent.width - width - s(3) : s(3)
                  Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                }
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: if (typeof Networking !== "undefined" && Networking) Networking.wifiEnabled = !Networking.wifiEnabled
                }
              }
            }
          }

          Rectangle { width: parent.width; height: 1; color: MatugenColors.borderSoft ? MatugenColors.borderSoft : MatugenColors.border; opacity: 0.6 }

          // Wi-Fi list
          Item {
            width: parent.width
            visible: true
            height: !root.showPasswordPrompt
              ? Math.min(wifiListCol.implicitHeight, netCard.height - root.chromeHeight - s(13))
              : 0
            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            clip: true

            Item {
              width: parent.width; height: s(34); visible: !root.wifiPowered && !root.ethConnected
              Text { anchors.centerIn: parent; text: "Wi-Fi is turned off"; color: MatugenColors.textMuted; font.pixelSize: s(11); font.family: "JetBrainsMono Nerd Font" }
            }
            Column {
              width: parent.width; spacing: s(6)
              visible: root.wifiPowered && root.wifiNetworksSorted.length === 0 && !root.ethConnected
              topPadding: s(50)
              Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰤩"; color: MatugenColors.border; font.pixelSize: s(28); font.family: "JetBrainsMono Nerd Font" }
              Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Searching for Networks…"; color: MatugenColors.border; font.pixelSize: s(11); font.family: "JetBrainsMono Nerd Font" }
            }

            Flickable {
              id: wifiFlick
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              anchors.rightMargin: s(18)
              visible: root.ethConnected || (root.wifiPowered && root.wifiNetworksSorted.length > 0)
              contentHeight: wifiListCol.implicitHeight
              clip: true
              boundsBehavior: Flickable.StopAtBounds

              ScrollBar.vertical: ScrollBar {
                id: wifiScrollBar
                policy: wifiFlick.contentHeight > wifiFlick.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                anchors.right: parent.right
                anchors.rightMargin: -s(14)
                width: s(5)
                contentItem: Rectangle {
                  implicitWidth: s(5)
                  radius: width / 2
                  color: MatugenColors.textMuted
                  opacity: wifiScrollBar.pressed ? 0.9 : 0.5
                  Behavior on opacity { NumberAnimation { duration: 120 } }
                }
                background: Rectangle {
                  implicitWidth: s(5)
                  radius: width / 2
                  color: MatugenColors.border
                  opacity: 0.2
                }
              }

              Column {
                id: wifiListCol
                width: parent.width
                spacing: s(10)

                Column {
                  width: parent.width; spacing: s(6)
                  visible: root.ethConnected

                  Text { text: "ETHERNET"; color: MatugenColors.textMuted; font.pixelSize: s(9); font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold; leftPadding: s(4) }

                  Rectangle {
                    id: ethRow
                    width: parent.width; height: s(42); radius: s(8)
                    color: MatugenColors.bgElevated2

                    Row {
                      anchors.verticalCenter: parent.verticalCenter
                      anchors.left: parent.left; anchors.leftMargin: s(12)
                      spacing: s(10)

                      Text { text: "󰈀"; color: MatugenColors.accent; font.pixelSize: s(15); font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
                      Text {
                        text: root.ethDevice ? (root.ethDevice.name || "Ethernet") : "Ethernet"
                        color: MatugenColors.text; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                        width: Math.min(implicitWidth, ethRow.width - ethIconRow.width - s(80))
                      }
                    }

                    Row {
                      id: ethIconRow
                      anchors.right: ethInfoBtn.left; anchors.rightMargin: s(8)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: s(8)

                      Rectangle {
                        width: connBadge.implicitWidth + s(14); height: s(20); radius: s(10)
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16)
                        Text {
                          id: connBadge
                          anchors.centerIn: parent
                          text: "Connected"
                          color: MatugenColors.accent
                          font.pixelSize: s(9); font.family: "JetBrainsMono Nerd Font"; font.weight: Font.DemiBold
                        }
                      }
                    }

                    Rectangle {
                      id: ethInfoBtn
                      anchors.right: parent.right; anchors.rightMargin: s(12)
                      anchors.verticalCenter: parent.verticalCenter
                      width: s(22); height: s(22); radius: s(11)
                      color: ethInfoArea.containsMouse ? MatugenColors.bgElevated : "transparent"
                      Behavior on color { ColorAnimation { duration: 120 } }
                      Text {
                        anchors.centerIn: parent
                        text: "i"
                        color: MatugenColors.textMuted
                        font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"
                        font.italic: true; font.weight: Font.Bold
                      }
                      MouseArea {
                        id: ethInfoArea
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedNetwork = root.ethDevice
                      }
                    }
                  }
                }

                Column {
                  width: parent.width; spacing: s(6)
                  visible: knownRepeater.count > 0

                  Text { text: "KNOWN NETWORKS"; color: MatugenColors.textMuted; font.pixelSize: s(9); font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold; leftPadding: s(4) }

                  Repeater {
                    id: knownRepeater
                    model: root.wifiNetworksSorted.filter(function(n) {
                      return n && (n.connected || n.known === true)
                    })
                    delegate: Rectangle {
                      id: knownRow
                      required property var modelData
                      width: parent.width; height: s(42); radius: s(8)
                      color: modelData.connected ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.12) : (knownHover.containsMouse ? MatugenColors.bgElevated2 : Qt.rgba(1,1,1,0.02))
                      border.color: modelData.connected ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.3) : "transparent"
                      border.width: 1
                      Behavior on color { ColorAnimation { duration: 120 } }

                      Text {
                        text: modelData.name !== "" ? modelData.name : "Hidden"
                        color: modelData.connected ? MatugenColors.text : MatugenColors.textMuted; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"
                        font.weight: modelData.connected ? Font.DemiBold : Font.Normal
                        anchors.left: parent.left; anchors.leftMargin: s(12)
                        anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                        anchors.right: knownIconRow.left; anchors.rightMargin: s(10)
                      }

                      Row {
                        id: knownIconRow
                        anchors.right: knownInfoBtn.left; anchors.rightMargin: s(8)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: s(8)

                        Text {
                          text: root.isSecured(modelData) ? "󰌾" : "󰌿"
                          color: MatugenColors.textMuted
                          font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"
                          anchors.verticalCenter: parent.verticalCenter
                          opacity: root.isSecured(modelData) ? 1.0 : 0.5
                        }

                        Text {
                          text: root.signalGlyph(modelData.signalStrength)
                          color: modelData.connected ? MatugenColors.accent : MatugenColors.textMuted
                          font.pixelSize: s(15); font.family: "JetBrainsMono Nerd Font"
                          anchors.verticalCenter: parent.verticalCenter
                        }
                      }

                      Rectangle {
                        id: knownInfoBtn
                        anchors.right: parent.right; anchors.rightMargin: s(12)
                        anchors.verticalCenter: parent.verticalCenter
                        width: s(22); height: s(22); radius: s(11)
                        color: knownInfoArea.containsMouse ? MatugenColors.bgElevated2 : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                          anchors.centerIn: parent
                          text: "i"
                          color: MatugenColors.textMuted
                          font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"
                          font.italic: true; font.weight: Font.Bold
                        }
                        MouseArea {
                          id: knownInfoArea
                          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: root.selectedNetwork = modelData
                        }
                      }

                      MouseArea {
                        id: knownHover
                        anchors.left: parent.left; anchors.right: knownInfoBtn.left
                        anchors.top: parent.top; anchors.bottom: parent.bottom
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (knownRow.modelData.connected) return; root.activateNetwork(knownRow.modelData) }
                      }
                    }
                  }
                }

                Column {
                  width: parent.width; spacing: s(6)
                  visible: otherRepeater.count > 0

                  Text { text: "OTHER NETWORKS"; color: MatugenColors.textMuted; font.pixelSize: s(9); font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold; leftPadding: s(4) }

                  Repeater {
                    id: otherRepeater
                    model: root.wifiNetworksSorted.filter(function(n) {
                      return n && !n.connected && n.known !== true
                    })
                    delegate: Rectangle {
                      id: otherRow
                      required property var modelData
                      width: parent.width; height: s(42); radius: s(8)
                      color: wifiHover.containsMouse ? MatugenColors.bgElevated2 : Qt.rgba(1,1,1,0.02)
                      Behavior on color { ColorAnimation { duration: 120 } }

                      Text {
                        text: modelData.name !== "" ? modelData.name : "Hidden"
                        color: MatugenColors.textMuted; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"
                        anchors.left: parent.left; anchors.leftMargin: s(12)
                        anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                        anchors.right: otherIconRow.left; anchors.rightMargin: s(10)
                      }

                      Row {
                        id: otherIconRow
                        anchors.right: otherInfoBtn.left; anchors.rightMargin: s(8)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: s(8)

                        Text {
                          text: root.isSecured(modelData) ? "󰌾" : "󰌿"
                          color: MatugenColors.textMuted
                          font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"
                          anchors.verticalCenter: parent.verticalCenter
                          opacity: root.isSecured(modelData) ? 1.0 : 0.5
                        }

                        Text {
                          text: root.signalGlyph(modelData.signalStrength)
                          color: MatugenColors.textMuted
                          font.pixelSize: s(15); font.family: "JetBrainsMono Nerd Font"
                          anchors.verticalCenter: parent.verticalCenter
                        }
                      }

                      Rectangle {
                        id: otherInfoBtn
                        anchors.right: parent.right; anchors.rightMargin: s(12)
                        anchors.verticalCenter: parent.verticalCenter
                        width: s(22); height: s(22); radius: s(11)
                        color: otherInfoArea.containsMouse ? MatugenColors.bgElevated2 : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                          anchors.centerIn: parent
                          text: "i"
                          color: MatugenColors.textMuted
                          font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"
                          font.italic: true; font.weight: Font.Bold
                        }
                        MouseArea {
                          id: otherInfoArea
                          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: root.selectedNetwork = modelData
                        }
                      }

                      MouseArea {
                        id: wifiHover
                        anchors.left: parent.left; anchors.right: otherInfoBtn.left
                        anchors.top: parent.top; anchors.bottom: parent.bottom
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.activateNetwork(modelData)
                      }
                    }
                  }
                }
              }
            }
          }
        }

        Rectangle {
          id: netInfoPanel
          anchors.fill: parent
          z: 10
          color: MatugenColors.bgBase
          visible: root.selectedNetwork !== null
          radius: s(14)

          property var net: root.selectedNetwork
          readonly property bool isEth: net === root.ethDevice

          Column {
            anchors.fill: parent
            anchors.margins: s(16)
            spacing: s(12)

            Item {
              width: parent.width; height: s(32)

              Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: s(26); height: s(26); radius: s(8)
                color: netBackArea.containsMouse ? MatugenColors.bgElevated2 : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                  anchors.centerIn: parent
                  text: "󰅁"
                  color: MatugenColors.text
                  font.pixelSize: s(15); font.family: "JetBrainsMono Nerd Font"
                }
                MouseArea {
                  id: netBackArea
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: root.selectedNetwork = null
                }
              }

              Text {
                anchors.centerIn: parent
                text: netInfoPanel.isEth ? "Ethernet Info" : "Network Info"
                color: MatugenColors.text
                font.pixelSize: s(13); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"
              }
            }

            Rectangle { width: parent.width; height: 1; color: MatugenColors.borderSoft ? MatugenColors.borderSoft : MatugenColors.border; opacity: 0.6 }

            Text {
              text: netInfoPanel.net ? (netInfoPanel.isEth ? (netInfoPanel.net.name || "Ethernet") : (netInfoPanel.net.name !== "" ? netInfoPanel.net.name : "Hidden Network")) : ""
              color: MatugenColors.text
              font.pixelSize: s(16); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"
              topPadding: s(8)
            }

            Column {
              width: parent.width; spacing: s(2)
              topPadding: s(10)

              // Note: BSSID/channel/frequency/link-rate are not exposed by
              // Quickshell.Networking's WifiNetwork — only name, security,
              // signalStrength, known, connected. Shown fields limited accordingly.
              Repeater {
                model: netInfoPanel.net ? (netInfoPanel.isEth ? [
                  { label: "Status", value: netInfoPanel.net.connected ? "Connected" : "Not Connected" },
                  { label: "Type", value: "Ethernet" },
                  { label: "Speed", value: root.ethSpeed !== "" ? root.ethSpeed : "Unknown" },
                  { label: "IP Address", value: root.ethIp !== "" ? root.ethIp : "Unknown" },
                  { label: "MAC Address", value: root.ethMac !== "" ? root.ethMac : "Unknown" }
                ] : [
                  { label: "Status", value: netInfoPanel.net.connected ? "Connected" : "Not Connected" },
                  { label: "Security", value: root.securityLabel(netInfoPanel.net.security) },
                  { label: "Signal Strength", value: Math.round((netInfoPanel.net.signalStrength || 0) * 100) + "%" },
                  { label: "Known", value: netInfoPanel.net.known ? "Yes" : "No" }
                ]) : []

                Item {
                  width: parent.width; height: s(36)

                  Text {
                    text: modelData.label
                    color: MatugenColors.textMuted
                    font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: modelData.value
                    color: MatugenColors.text
                    font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"
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

            Row {
              width: parent.width; spacing: s(8)
              visible: netInfoPanel.net !== null && !netInfoPanel.isEth

              Rectangle {
                width: netInfoPanel.net && netInfoPanel.net.connected ? parent.width : (parent.width - s(8)) / 2
                height: s(38); radius: s(10)
                color: netInfoPanel.net && netInfoPanel.net.connected ? MatugenColors.bgElevated2 : MatugenColors.accent

                Text {
                  anchors.centerIn: parent
                  text: netInfoPanel.net && netInfoPanel.net.connected ? "Disconnect" : "Connect"
                  color: netInfoPanel.net && netInfoPanel.net.connected ? MatugenColors.text : MatugenColors.accentText
                  font.pixelSize: s(12); font.weight: Font.DemiBold; font.family: "JetBrainsMono Nerd Font"
                }

                MouseArea {
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (!netInfoPanel.net) return
                    if (netInfoPanel.net.connected) {
                      netInfoPanel.net.disconnect()
                      root.selectedNetwork = null
                    } else {
                      root.activateNetwork(netInfoPanel.net)
                      root.selectedNetwork = null
                    }
                  }
                }
              }

              Rectangle {
                visible: netInfoPanel.net && !netInfoPanel.net.connected && netInfoPanel.net.known === true
                width: (parent.width - s(8)) / 2; height: s(38); radius: s(10)
                color: netForgetHover.containsMouse ? MatugenColors.bgElevated : MatugenColors.bgElevated2
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                  anchors.centerIn: parent
                  text: "Forget"
                  color: MatugenColors.textMuted
                  font.pixelSize: s(12); font.weight: Font.DemiBold; font.family: "JetBrainsMono Nerd Font"
                }

                MouseArea {
                  id: netForgetHover
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (!netInfoPanel.net) return
                    netInfoPanel.net.forget()
                    root.selectedNetwork = null
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
