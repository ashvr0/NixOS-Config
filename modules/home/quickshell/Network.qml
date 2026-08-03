import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Networking

Item {
  id: root

  Scaler {
    id: scaler
    currentWidth: Screen.width
    currentHeight: Screen.height
  }
  function s(val) { return scaler.s(val) }

  IpcHandler {
    target: "network"
    function toggle(): void {
      root.networkMenuOpen = !root.networkMenuOpen
    }
  }

  property bool   networkMenuOpen: false

  property bool   showPasswordPrompt: false
  property var    pendingNetwork: null
  property string typedPassword: ""
  property bool   connectFailed: false
  readonly property int chromeHeight: s(12) * 2 + s(32) + s(10)

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

  function refreshSecurity() { secProc.running = true }

  function signalGlyph(strength) {
    var s = strength || 0
    if (s >= 80) return "󰤨"
    if (s >= 60) return "󰤥"
    if (s >= 40) return "󰤢"
    if (s >= 20) return "󰤟"
    return "󰤯"
  }

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

  Process { id: rescanProc; command: ["nmcli", "dev", "wifi", "rescan"] }

  onWifiNetworksChanged: if (root.networkMenuOpen) secRefresh.restart()

  Timer {
    id: secRefresh
    interval: 1200
    onTriggered: if (root.networkMenuOpen) secProc.running = true
  }

  onNetworkMenuOpenChanged: {
    if (networkMenuOpen) {
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
        width: s(680)
        height: root.showPasswordPrompt ? s(160) : s(520)
        x: Config.barPosition === "left" ? s(8) : (Screen.width - width - s(8))
        y: Config.barPosition === "bottom" ? (Screen.height - height - s(70)) : s(70)
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
                connProc.command = ["nmcli", "--ask", "dev", "wifi", "connect", root.pendingNetwork.name]
                connProc.pw = pwInput.text
                connProc.running = true
              }

              Text { anchors.centerIn: parent; text: "Connect"; color: MatugenColors.accentText; font.pixelSize: s(11); font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold }
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

        // List view
        Column {
          id: listView
          anchors.fill: parent
          anchors.margins: s(16)
          spacing: s(12)
          visible: !root.showPasswordPrompt

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
            Item {
              width: parent.width; height: s(34)
              visible: root.wifiPowered && root.wifiNetworksSorted.length === 0 && !root.ethConnected
              Text { anchors.centerIn: parent; text: "Searching networks…"; color: MatugenColors.textMuted; font.pixelSize: s(11); font.family: "JetBrainsMono Nerd Font" }
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
                spacing: s(10)

                Column {
                  width: parent.width; spacing: s(6)
                  visible: root.ethConnected

                  Text { text: "ETHERNET"; color: MatugenColors.textMuted; font.pixelSize: s(9); font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold; leftPadding: s(4) }

                  Rectangle {
                    width: parent.width; height: s(42); radius: s(8)
                    color: MatugenColors.bgElevated2
                    border.color: MatugenColors.accent
                    border.width: 1

                    Row {
                      anchors.verticalCenter: parent.verticalCenter
                      anchors.left: parent.left; anchors.leftMargin: s(12)
                      spacing: s(10)

                      Text { text: "󰈀"; color: MatugenColors.accent; font.pixelSize: s(15); font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
                      Text {
                        text: root.ethDevice ? (root.ethDevice.interface || root.ethDevice.name || "Ethernet") : "Ethernet"
                        color: MatugenColors.text; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: parent.parent.width - s(90)
                      }
                    }

                    Rectangle {
                      anchors.right: parent.right; anchors.rightMargin: s(10)
                      anchors.verticalCenter: parent.verticalCenter
                      width: connBadge.implicitWidth + s(14); height: s(20); radius: s(10)
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
                }

                Column {
                  width: parent.width; spacing: s(6)
                  visible: knownRepeater.count > 0

                  Text { text: "KNOWN NETWORKS"; color: MatugenColors.textMuted; font.pixelSize: s(9); font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold; leftPadding: s(4) }

                  Repeater {
                    id: knownRepeater
                    model: root.wifiNetworksSorted.filter(function(n) {
                      return n && (n.connected || root.knownProfiles[n.name] === true)
                    })
                    delegate: Rectangle {
                      id: knownRow
                      required property var modelData
                      width: parent.width; height: s(42); radius: s(8)
                      color: modelData.connected ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.12) : (knownHover.containsMouse ? MatugenColors.bgElevated2 : Qt.rgba(1,1,1,0.02))
                      border.color: modelData.connected ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.3) : "transparent"
                      border.width: 1
                      Behavior on color { ColorAnimation { duration: 120 } }

                      Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: s(12)
                        spacing: s(10)

                        Text { text: root.signalGlyph(modelData.signalStrength); color: modelData.connected ? MatugenColors.accent : MatugenColors.textMuted; font.pixelSize: s(15); font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: root.isSecured(modelData.name) ? "󰌾" : ""; color: MatugenColors.textMuted; font.pixelSize: s(10); font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter; visible: text !== "" }
                        Text {
                          text: modelData.name !== "" ? modelData.name : "Hidden"
                          color: modelData.connected ? MatugenColors.text : MatugenColors.textMuted; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"
                          font.weight: modelData.connected ? Font.DemiBold : Font.Normal
                          anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: parent.parent.width - s(140)
                        }
                      }

                      Row {
                        anchors.right: parent.right; anchors.rightMargin: s(10)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: s(8)

                        Text { text: modelData.connected ? "\uf00c" : ""; color: MatugenColors.accent; font.pixelSize: s(11); font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }

                        Rectangle {
                          width: s(22); height: s(22); radius: s(6)
                          color: forgetHover.containsMouse ? MatugenColors.bgElevated : "transparent"
                          Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: s(10); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textMuted }
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
                      return n && !n.connected && root.knownProfiles[n.name] !== true
                    })
                    delegate: Rectangle {
                      required property var modelData
                      width: parent.width; height: s(42); radius: s(8)
                      color: wifiHover.containsMouse ? MatugenColors.bgElevated2 : Qt.rgba(1,1,1,0.02)
                      Behavior on color { ColorAnimation { duration: 120 } }

                      Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: s(12)
                        spacing: s(10)

                        Text { text: root.signalGlyph(modelData.signalStrength); color: MatugenColors.textMuted; font.pixelSize: s(15); font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: root.isSecured(modelData.name) ? "󰌾" : ""; color: MatugenColors.textMuted; font.pixelSize: s(10); font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter; visible: text !== "" }
                        Text { text: modelData.name !== "" ? modelData.name : "Hidden"; color: MatugenColors.textMuted; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: parent.parent.width - s(60) }
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

            Process { id: forgetProc; onExited: root.refreshSecurity() }
          }
        }
      }
    }
  }
}
