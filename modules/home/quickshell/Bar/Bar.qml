import QtQuick
import Quickshell
import Quickshell.Io
import "../Singletons"
import "../Network"
import ".."
import "../weather"

PanelWindow {
  id: barWindowRoot

  property string pos: ["top", "bottom", "left", "right"].includes(Config.barPosition) ? Config.barPosition : "top"
  readonly property bool vertical: pos === "left" || pos === "right"

  property bool positionChanging: false

  // Which layout file is loaded. Switched by hand in onPosChanged so the
  // modules can be detached from the old layout before it is destroyed.
  property bool layoutReady: false
  property bool layoutVertical: false
  readonly property bool fillStyle: Config.barStyle === "fill"
  
  Timer {
    id: positionChangeTimer
    interval: 350
    onTriggered: barWindowRoot.positionChanging = false
  }
  function syncLayoutOrientation() {
    if (barWindowRoot.layoutReady && barWindowRoot.vertical !== barWindowRoot.layoutVertical) {
      barWindowRoot.releaseModules()
      barWindowRoot.layoutVertical = barWindowRoot.vertical
      barWindowRoot.applyLayout()
    }
  }
  onPosChanged: {
    barWindowRoot.positionChanging = true
    positionChangeTimer.restart()
    syncLayoutOrientation()
  }
  onVerticalChanged: {
    barWindowRoot.positionChanging = true
    positionChangeTimer.restart()
    syncLayoutOrientation()
  }

  anchors {
    top: pos !== "bottom"
    bottom: pos !== "top"
    left: pos !== "right"
    right: pos !== "left"
  }

  visible: true

  Component.onCompleted: {
    Scaler.currentWidth = Screen.width
    Scaler.currentHeight = Screen.height
    barWindowRoot.layoutVertical = barWindowRoot.vertical
    barWindowRoot.layoutReady = true
    barWindowRoot.applyLayout()
  }
  function s(val) { return Scaler.s(val) }

  implicitHeight: vertical ? Screen.height : s(56)
  implicitWidth: vertical ? s(56) : Screen.width

  margins {
  top: vertical ? (fillStyle ? 0 : s(10)) : (pos === "top" ? 0 : s(10))
  bottom: vertical ? (fillStyle ? 0 : s(10)) : (pos === "bottom" ? 0 : s(10))
  left: vertical ? (pos === "left" ? 0 : s(10)) : 0
  right: vertical ? (pos === "right" ? 0 : s(10)) : 0
}

  property bool hovered: false
  property bool anyMenuOpen: barWindowRoot.modulesRev >= 0 && ((barWindowRoot.moduleInstances["volume"] && barWindowRoot.moduleInstances["volume"].volumeMenuOpen)
    || (barWindowRoot.moduleInstances["network"] && barWindowRoot.moduleInstances["network"].networkMenuOpen)
    || (barWindowRoot.moduleInstances["bluetooth"] && barWindowRoot.moduleInstances["bluetooth"].btMenuOpen)
    || (barWindowRoot.moduleInstances["power"] && barWindowRoot.moduleInstances["power"].menuOpen)
    || (barWindowRoot.moduleInstances["weather"] && barWindowRoot.moduleInstances["weather"].weatherMenuOpen)
    || (barWindowRoot.moduleInstances["musicplayer"] && barWindowRoot.moduleInstances["musicplayer"].playerExpanded)
    || false)
  property bool revealed: !Config.autoHideBar || barWindowRoot.hovered || barWindowRoot.anyMenuOpen

  function requestHover() { hoverReleaseTimer.stop(); barWindowRoot.hovered = true }
  function requestUnhover() { hoverReleaseTimer.restart() }
  Timer {
    id: hoverReleaseTimer
    interval: Config.autoHideBar ? Config.autoHideDelayMs : 150
    onTriggered: barWindowRoot.hovered = false
  }

  Connections {
    target: barHover
    function onHoveredChanged() {
      if (barHover.hovered) barWindowRoot.requestHover()
      else barWindowRoot.requestUnhover()
    }
  }

 property real barSize: (vertical ? implicitWidth : implicitHeight) + (fillStyle ? 0 : s(8))
  exclusiveZone: Config.autoHideBar ? (barWindowRoot.revealed ? barSize : 0) : barSize
  Behavior on exclusiveZone { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  color: "transparent"
  mask: Region {
    x: 0
    y: 0
    width: Config.autoHideBar && !barWindowRoot.revealed ? 0 : barWindowRoot.width
    height: Config.autoHideBar && !barWindowRoot.revealed ? 0 : barWindowRoot.height
  }

  function resetModules() {
    for (const k of Object.keys(barWindowRoot.clusterInstances)) {
      let c = barWindowRoot.clusterInstances[k]
      if (c) c.destroy()
    }
    for (const k of Object.keys(barWindowRoot.groupWrapperInstances)) {
      let w = barWindowRoot.groupWrapperInstances[k]
      if (w) w.destroy()
    }
    for (const k of Object.keys(barWindowRoot.moduleInstances)) {
      let m = barWindowRoot.moduleInstances[k]
      if (m) m.destroy()
    }
    barWindowRoot.clusterInstances = ({})
    barWindowRoot.groupWrapperInstances = ({})
    barWindowRoot.moduleInstances = ({})
    barWindowRoot.modulesRev++
  }

  HoverHandler {
    id: barHover
  }

  PanelWindow {
    id: edgeTrigger
    visible: Config.autoHideBar
    color: "transparent"
    anchors {
      top: pos !== "bottom"
      bottom: pos !== "top"
      left: pos !== "right"
      right: pos !== "left"
    }
    implicitWidth: vertical ? 6 : Screen.width
    implicitHeight: vertical ? Screen.height : 6
    exclusiveZone: 0
    mask: Region {
      x: 0
      y: 0
      width: edgeTrigger.implicitWidth
      height: edgeTrigger.implicitHeight
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
      onEntered: barWindowRoot.requestHover()
      onExited: barWindowRoot.requestUnhover()
    }
  }

  // ---- shared module engine (orientation independent) ----
  signal zonesChanged()
  property int modulesRev: 0

  Component {
    id: launcherComponent
    Item {
      id: launcherRoot
      width: barWindowRoot.vertical ? barWindowRoot.width : s(50)
      height: barWindowRoot.vertical ? s(50) : barWindowRoot.height

      Rectangle {
        anchors.centerIn: parent
        width: s(50)
        height: s(50)
        radius: s(Config.uiRadius + 4)

        color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, Config.barOpacityPercent / 100)
        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf002"
          font.family: Config.fontFamily
          font.pixelSize: s(13)
          color: launcherArea.containsMouse ? MatugenColors.text : MatugenColors.accent
          Behavior on color { ColorAnimation { duration: 200 } }
        }

        MouseArea {
          id: launcherArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: launcherToggle.running = true
        }

        Process { id: launcherToggle; command: ["qs", "ipc", "call", "launcher", "toggle"] }
      }
    }
  }

  Component {
    id: guidebuttonComponent
    Item {
      id: guideRoot
      width: barWindowRoot.vertical ? barWindowRoot.width : s(50)
      height: barWindowRoot.vertical ? s(50) : barWindowRoot.height

      Rectangle {
        anchors.centerIn: parent
        width: s(50)
        height: s(50)
        radius: s(Config.uiRadius + 4)

        color: Config.barStyle === "solid" ? "transparent" : Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, Config.barOpacityPercent / 100)
        border.color: Config.barStyle === "solid" ? "transparent" : Qt.rgba(1, 1, 1, 0.06)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf059"
          font.family: Config.fontFamily
          font.pixelSize: s(13)
          color: guideArea.containsMouse ? MatugenColors.text : MatugenColors.accent
          Behavior on color { ColorAnimation { duration: 200 } }
        }

        MouseArea {
          id: guideArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: guideToggle.running = true
        }

        Process { id: guideToggle; command: ["qs", "ipc", "call", "guide", "toggle"] }
      }
    }
  }

  Component {
    id: workspacesComponent
    Workspaces { height: barWindowRoot.vertical ? implicitHeight : barWindowRoot.height; width: barWindowRoot.vertical ? barWindowRoot.width : implicitWidth }
  }
  Component {
    id: musicplayerComponent
    MusicPlayer { height: barWindowRoot.vertical ? implicitHeight : barWindowRoot.height; width: barWindowRoot.vertical ? barWindowRoot.width : implicitWidth }
  }
  Component {
    id: systemstatsComponent
    CalendarBar { height: barWindowRoot.vertical ? implicitHeight : barWindowRoot.height }
  }
  Component {
    id: systemtrayComponent
    SystemTray { height: barWindowRoot.vertical ? implicitHeight : barWindowRoot.height; width: barWindowRoot.vertical ? barWindowRoot.width : implicitWidth }
  }
  Component {
    id: keyboardComponent
    Keyboard { height: barWindowRoot.vertical ? implicitHeight : barWindowRoot.height }
  }
  Component {
    id: volumeComponent
    Item {
      id: volRoot
      height: barWindowRoot.vertical ? barWindowRoot.width : barWindowRoot.height
      implicitWidth: volInner.implicitWidth + 18 * Config.uiScale
      width: barWindowRoot.vertical ? barWindowRoot.width : implicitWidth

      Audio { id: audioModule }
      property alias volumeLevel:    audioModule.volumeLevel
      property alias volumeIcon:     audioModule.volumeIcon
      property alias volumeMenuOpen: audioModule.volumeMenuOpen

      Rectangle {
        anchors.fill: parent
        radius: s(Config.uiRadius)
        color: "transparent"
        border.color: "transparent"
        border.width: 1
      }
      MouseArea { id: volHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
      Item {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 3 * Config.uiScale
        width: parent.width - 6 * Config.uiScale; height: 32 * Config.uiScale
        opacity: (volHover.containsMouse || volRoot.volumeMenuOpen) ? 0.6 : 0.32
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Rectangle { anchors.fill: parent; anchors.margins: -4 * Config.uiScale; radius: s(Config.uiRadius - 4 >= 0 ? Config.uiRadius - 4 : 0); color: Qt.rgba(0, 0, 0, 0.05) }
        Rectangle { anchors.fill: parent; anchors.margins: -2 * Config.uiScale; radius: s(Config.uiRadius - 6 >= 0 ? Config.uiRadius - 6 : 0); color: Qt.rgba(0, 0, 0, 0.07) }
        Rectangle {
          anchors.fill: parent; radius: s(Config.uiRadius - 8 >= 0 ? Config.uiRadius - 8 : 0)
          color: volRoot.volumeMenuOpen ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.14) : Qt.rgba(0, 0, 0, 0.10)
          Behavior on color { ColorAnimation { duration: 150 } }
        }
      }
      Row {
        id: volInner; spacing: 9 * Config.uiScale
        anchors.centerIn: parent
        Text { text: volRoot.volumeIcon; font.pixelSize: 15 * Config.uiScale; color: volRoot.volumeMenuOpen ? MatugenColors.accent : MatugenColors.textMuted; anchors.verticalCenter: parent.verticalCenter; Behavior on color { ColorAnimation { duration: 150 } } }
        Text { visible: !barWindowRoot.vertical; text: volRoot.volumeLevel + "%"; font.pixelSize: 12 * Config.uiScale; font.weight: Font.DemiBold; color: volRoot.volumeMenuOpen ? MatugenColors.accent : MatugenColors.text; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter; Behavior on color { ColorAnimation { duration: 150 } } }
      }
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { let next = !volRoot.volumeMenuOpen; if (next) barWindowRoot.closeOtherPopups("volume"); volRoot.volumeMenuOpen = next } }
    }
  }
  Component {
    id: networkComponent
    Item {
      id: netRoot
      height: barWindowRoot.vertical ? barWindowRoot.width : barWindowRoot.height
      implicitWidth: wifiInner.implicitWidth + 18 * Config.uiScale
      width: barWindowRoot.vertical ? barWindowRoot.width : implicitWidth

      Network { id: networkModule }
      property alias networkMenuOpen: networkModule.networkMenuOpen
      property alias wifiName:        networkModule.statusText
      property alias wifiPowered:     networkModule.wifiPowered

      Rectangle {
        anchors.fill: parent
        radius: s(Config.uiRadius)
        color: "transparent"
        border.color: "transparent"
        border.width: 1
      }
      MouseArea { id: wifiHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
      Item {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 3 * Config.uiScale
        width: parent.width - 6 * Config.uiScale; height: 32 * Config.uiScale
        opacity: (wifiHover.containsMouse || netRoot.networkMenuOpen) ? 0.6 : 0.32
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Rectangle { anchors.fill: parent; anchors.margins: -4 * Config.uiScale; radius: s(Config.uiRadius - 4 >= 0 ? Config.uiRadius - 4 : 0); color: Qt.rgba(0, 0, 0, 0.05) }
        Rectangle { anchors.fill: parent; anchors.margins: -2 * Config.uiScale; radius: s(Config.uiRadius - 6 >= 0 ? Config.uiRadius - 6 : 0); color: Qt.rgba(0, 0, 0, 0.07) }
        Rectangle {
          anchors.fill: parent; radius: s(Config.uiRadius - 8 >= 0 ? Config.uiRadius - 8 : 0)
          color: netRoot.networkMenuOpen ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.14) : Qt.rgba(0, 0, 0, 0.10)
          Behavior on color { ColorAnimation { duration: 150 } }
        }
      }
      Row {
        id: wifiInner; spacing: 6 * Config.uiScale
        anchors.centerIn: parent
        Text { text: networkModule.ethConnected ? "󰈀" : "󰤨"; font.pixelSize: 15 * Config.uiScale; color: netRoot.networkMenuOpen ? MatugenColors.accent : MatugenColors.textMuted; anchors.verticalCenter: parent.verticalCenter; Behavior on color { ColorAnimation { duration: 150 } } }
        Text { visible: !barWindowRoot.vertical; text: netRoot.wifiName; font.pixelSize: 12 * Config.uiScale; font.weight: Font.DemiBold; color: netRoot.networkMenuOpen ? MatugenColors.accent : MatugenColors.text; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: Math.min(implicitWidth, 100 * Config.uiScale); Behavior on color { ColorAnimation { duration: 150 } } }
      }
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { let next = !netRoot.networkMenuOpen; if (next) barWindowRoot.closeOtherPopups("network"); netRoot.networkMenuOpen = next } }
    }
  }
  Component {
    id: bluetoothComponent
    Item {
      id: btRoot
      height: barWindowRoot.vertical ? barWindowRoot.width : barWindowRoot.height
      implicitWidth: Math.min(btInner.implicitWidth, 150 * Config.uiScale) + 18 * Config.uiScale
      width: barWindowRoot.vertical ? barWindowRoot.width : implicitWidth

      Bluetooth { id: bluetoothModule }
      property alias btMenuOpen: bluetoothModule.btMenuOpen
      property alias btName:     bluetoothModule.statusText
      property alias btPowered:  bluetoothModule.btPowered

      Rectangle {
        anchors.fill: parent
        radius: s(Config.uiRadius)
        color: "transparent"
        border.color: "transparent"
        border.width: 1
      }
      MouseArea { id: btHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
      Item {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 3 * Config.uiScale
        width: parent.width - 6 * Config.uiScale; height: 32 * Config.uiScale
        opacity: (btHover.containsMouse || btRoot.btMenuOpen) ? 0.6 : 0.32
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Rectangle { anchors.fill: parent; anchors.margins: -4 * Config.uiScale; radius: s(Config.uiRadius - 4 >= 0 ? Config.uiRadius - 4 : 0); color: Qt.rgba(0, 0, 0, 0.05) }
        Rectangle { anchors.fill: parent; anchors.margins: -2 * Config.uiScale; radius: s(Config.uiRadius - 6 >= 0 ? Config.uiRadius - 6 : 0); color: Qt.rgba(0, 0, 0, 0.07) }
        Rectangle {
          anchors.fill: parent; radius: s(Config.uiRadius - 8 >= 0 ? Config.uiRadius - 8 : 0)
          color: btRoot.btMenuOpen ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.14) : Qt.rgba(0, 0, 0, 0.10)
          Behavior on color { ColorAnimation { duration: 150 } }
        }
      }
      Row {
        id: btInner; spacing: 6 * Config.uiScale
        anchors.centerIn: parent
        Text { text: "󰂯"; font.pixelSize: 15 * Config.uiScale; color: btRoot.btMenuOpen ? MatugenColors.accent : (btRoot.btPowered ? MatugenColors.textMuted : MatugenColors.border); anchors.verticalCenter: parent.verticalCenter; Behavior on color { ColorAnimation { duration: 150 } } }
        Text {
          visible: !barWindowRoot.vertical
          text: btRoot.btPowered ? (btRoot.btName.length ? btRoot.btName : "On") : "Bluetooth"
          font.pixelSize: 12 * Config.uiScale
          font.weight: Font.DemiBold
          color: btRoot.btMenuOpen ? MatugenColors.accent : MatugenColors.text
          anchors.verticalCenter: parent.verticalCenter
          elide: Text.ElideRight
          width: Math.min(implicitWidth, 100 * Config.uiScale)
          Behavior on color { ColorAnimation { duration: 150 } }
        }
      }
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { let next = !btRoot.btMenuOpen; if (next) barWindowRoot.closeOtherPopups("bluetooth"); btRoot.btMenuOpen = next } }
    }
  }
  Component {
    id: weatherComponent
    Item {
      id: weatherModuleRoot
      height: barWindowRoot.vertical ? barWindowRoot.width : barWindowRoot.height
      implicitWidth: weatherInner.implicitWidth + 18 * Config.uiScale
      width: barWindowRoot.vertical ? barWindowRoot.width : implicitWidth

      WeatherPopup { id: weatherModule }
      property alias weatherMenuOpen: weatherModule.weatherMenuOpen

      MouseArea { id: weatherHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
      Item {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 3 * Config.uiScale
        width: parent.width - 6 * Config.uiScale; height: 32 * Config.uiScale
        opacity: (weatherHover.containsMouse || weatherModuleRoot.weatherMenuOpen) ? 0.6 : 0.32
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Rectangle { anchors.fill: parent; anchors.margins: -4 * Config.uiScale; radius: s(Config.uiRadius - 4 >= 0 ? Config.uiRadius - 4 : 0); color: Qt.rgba(0, 0, 0, 0.05) }
        Rectangle { anchors.fill: parent; anchors.margins: -2 * Config.uiScale; radius: s(Config.uiRadius - 6 >= 0 ? Config.uiRadius - 6 : 0); color: Qt.rgba(0, 0, 0, 0.07) }
        Rectangle {
          anchors.fill: parent; radius: s(Config.uiRadius - 8 >= 0 ? Config.uiRadius - 8 : 0)
          color: weatherModuleRoot.weatherMenuOpen ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.14) : Qt.rgba(0, 0, 0, 0.10)
          Behavior on color { ColorAnimation { duration: 150 } }
        }
      }
      Row {
        id: weatherInner; spacing: 6 * Config.uiScale
        anchors.centerIn: parent
        Text { text: Weather.iconCode; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 * Config.uiScale; color: weatherModuleRoot.weatherMenuOpen ? MatugenColors.accent : MatugenColors.textMuted; anchors.verticalCenter: parent.verticalCenter; Behavior on color { ColorAnimation { duration: 150 } } }
        Text { visible: !barWindowRoot.vertical; text: Weather.hasError ? "--" : (Weather.currentTemp + Weather.tempSuffix); font.pixelSize: 12 * Config.uiScale; font.weight: Font.DemiBold; color: weatherModuleRoot.weatherMenuOpen ? MatugenColors.accent : MatugenColors.text; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter; Behavior on color { ColorAnimation { duration: 150 } } }
      }
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { let next = !weatherModuleRoot.weatherMenuOpen; if (next) barWindowRoot.closeOtherPopups("weather"); weatherModuleRoot.weatherMenuOpen = next } }
    }
  }
  Component {
    id: settingsComponent
    Settings { height: barWindowRoot.vertical ? implicitHeight : barWindowRoot.height; width: barWindowRoot.vertical ? barWindowRoot.width : implicitWidth }
  }
  Component {
    id: powerComponent
    Item {
      id: powRoot
      Component.onCompleted: { Scaler.currentWidth = Screen.width; Scaler.currentHeight = Screen.height }
      function s(val) { return Scaler.s(val) }
      implicitWidth: s(50)
      implicitHeight: s(50)
      width: barWindowRoot.vertical ? barWindowRoot.width : implicitWidth
      height: barWindowRoot.vertical ? implicitHeight : barWindowRoot.height

      Power { id: powerModule; anchors.centerIn: parent }
      property alias menuOpen: powerModule.menuOpen

      Rectangle {
        anchors.fill: parent
        radius: s(Config.uiRadius + 4)
        color: "transparent"
        border.color: "transparent"
        border.width: 1
      }
      MouseArea { id: powHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
      Item {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 3 * Config.uiScale
        width: parent.width - 6 * Config.uiScale; height: 32 * Config.uiScale
        opacity: (powHover.containsMouse || powRoot.menuOpen) ? 0.6 : 0.32
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Rectangle { anchors.fill: parent; anchors.margins: -4 * Config.uiScale; radius: s(Config.uiRadius - 4 >= 0 ? Config.uiRadius - 4 : 0); color: Qt.rgba(0, 0, 0, 0.05) }
        Rectangle { anchors.fill: parent; anchors.margins: -2 * Config.uiScale; radius: s(Config.uiRadius - 6 >= 0 ? Config.uiRadius - 6 : 0); color: Qt.rgba(0, 0, 0, 0.07) }
        Rectangle {
          anchors.fill: parent; radius: s(Config.uiRadius - 8 >= 0 ? Config.uiRadius - 8 : 0)
          color: powRoot.menuOpen ? Qt.rgba(1, 0.35, 0.35, 0.16) : Qt.rgba(0, 0, 0, 0.10)
          Behavior on color { ColorAnimation { duration: 150 } }
        }
      }
    }
  }
  Component {
    id: guidebuttonWrapperComponent
    Loader { sourceComponent: guidebuttonComponent }
  }
  Component {
    id: launcherWrapperComponent
    Loader { sourceComponent: launcherComponent }
  }

  function componentFor(id) {
    switch (id) {
      case "launcher": return launcherWrapperComponent
      case "workspaces": return workspacesComponent
      case "musicplayer": return musicplayerComponent
      case "systemstats": return systemstatsComponent
      case "systemtray": return systemtrayComponent
      case "keyboard": return keyboardComponent
      case "volume": return volumeComponent
      case "network": return networkComponent
      case "bluetooth": return bluetoothComponent
      case "weather": return weatherComponent
      case "settings": return settingsComponent
      case "power": return powerComponent
      case "guidebutton": return Config.showGuideButton ? guidebuttonWrapperComponent : null
      default: return null
    }
  }

  property var moduleInstances: ({})

  function closeOtherPopups(exceptId) {
    const popupIds = ["volume", "network", "bluetooth", "weather", "power", "musicplayer"]
    for (const id of popupIds) {
      if (id === exceptId) continue
      let inst = barWindowRoot.moduleInstances[id]
      if (!inst) continue
      if (id === "volume" && inst.volumeMenuOpen) inst.volumeMenuOpen = false
      else if (id === "network" && inst.networkMenuOpen) inst.networkMenuOpen = false
      else if (id === "bluetooth" && inst.btMenuOpen) inst.btMenuOpen = false
      else if (id === "weather" && inst.weatherMenuOpen) inst.weatherMenuOpen = false
      else if (id === "power" && inst.menuOpen) inst.menuOpen = false
      else if (id === "musicplayer" && inst.playerExpanded) inst.playerExpanded = false
    }
  }

  function watchPopup(id, inst) {
    if (id === "volume") inst.volumeMenuOpenChanged.connect(function() { if (inst.volumeMenuOpen) barWindowRoot.closeOtherPopups("volume") })
    else if (id === "network") inst.networkMenuOpenChanged.connect(function() { if (inst.networkMenuOpen) barWindowRoot.closeOtherPopups("network") })
    else if (id === "bluetooth") inst.btMenuOpenChanged.connect(function() { if (inst.btMenuOpen) barWindowRoot.closeOtherPopups("bluetooth") })
    else if (id === "weather") inst.weatherMenuOpenChanged.connect(function() { if (inst.weatherMenuOpen) barWindowRoot.closeOtherPopups("weather") })
    else if (id === "power") inst.menuOpenChanged.connect(function() { if (inst.menuOpen) barWindowRoot.closeOtherPopups("power") })
    else if (id === "musicplayer") inst.playerExpandedChanged.connect(function() { if (inst.playerExpanded) barWindowRoot.closeOtherPopups("musicplayer") })
  }

  Component {
    id: groupWrapperComponent
    Item {
      id: wrapper
      required property string moduleId
      required property var moduleInst
      readonly property string groupId: barWindowRoot.groupIdFor(wrapper.moduleId)
      readonly property bool grouped: wrapper.groupId !== ""
      readonly property color groupColor: Qt.color(barWindowRoot.groupColorFor(wrapper.moduleId))
      readonly property bool isPending: barWindowRoot.pendingGroupId === wrapper.moduleId

      width: barWindowRoot.vertical ? barWindowRoot.width : moduleInst.width
      height: barWindowRoot.vertical ? moduleInst.height : barWindowRoot.height

      Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: s(Config.uiRadius - 4 >= 0 ? Config.uiRadius - 4 : 0)
        visible: wrapper.isPending
        color: "transparent"
        border.width: 2
        border.color: MatugenColors.accent
      }

      Component.onCompleted: {
        moduleInst.parent = wrapper
        moduleInst.anchors.centerIn = wrapper
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        propagateComposedEvents: true
        onClicked: (mouse) => {
          if (mouse.button === Qt.RightButton) {
            if (wrapper.grouped && barWindowRoot.pendingGroupId === "") {
              barWindowRoot.ungroupModule(wrapper.moduleId)
            } else {
              barWindowRoot.requestGroupClick(wrapper.moduleId)
            }
            mouse.accepted = true
          }
        }
      }
    }
  }

  function instanceFor(id) {
    if (barWindowRoot.moduleInstances[id]) return barWindowRoot.moduleInstances[id]
    let comp = barWindowRoot.componentFor(id)
    if (!comp) return null
    let inst = comp.createObject(moduleHost)
    barWindowRoot.moduleInstances[id] = inst
    barWindowRoot.modulesRev++
    barWindowRoot.watchPopup(id, inst)
    return inst
  }

  property var groupWrapperInstances: ({})
  function wrapperFor(id) {
    if (barWindowRoot.groupWrapperInstances[id]) return barWindowRoot.groupWrapperInstances[id]
    let inst = barWindowRoot.instanceFor(id)
    if (!inst) return null
    let wrapped = groupWrapperComponent.createObject(moduleHost, { moduleId: id, moduleInst: inst })
    barWindowRoot.groupWrapperInstances[id] = wrapped
    return wrapped
  }

  Item {
    id: moduleHost
    visible: false
  }
  readonly property Item moduleHostItem: moduleHost

  property string pendingGroupId: ""
  property string pendingGroupZone: ""

  readonly property var groupPalette: [
    MatugenColors.accent, "#f38ba8", "#a6e3a1", "#89b4fa", "#f9e2af", "#cba6f7", "#94e2d5", "#fab387"
  ]

  function colorToStr(c) {
    if (!c) return "#808080"
    if (typeof c === "string") return c
    return Qt.rgba(c.r, c.g, c.b, 1).toString()
  }

  function assignGroupColor(gId) {
    let colors = Config.barGroupColors || ({})
    if (colors[gId]) return
    let used = Object.values(colors)
    let palette = barWindowRoot.groupPalette.map(barWindowRoot.colorToStr)
    let chosen = palette.find(c => used.indexOf(c) === -1)
    if (!chosen) chosen = palette[Object.keys(colors).length % palette.length]
    let newColors = Object.assign({}, colors)
    newColors[gId] = chosen
    Config.setBarGroups(Config.barGroups, newColors)
  }

  function groupIdFor(moduleId) {
    let groups = Config.barGroups || ({})
    return groups[moduleId] || ""
  }

  function groupColorFor(moduleId) {
    let gId = barWindowRoot.groupIdFor(moduleId)
    if (!gId) return "transparent"
    let colors = Config.barGroupColors || ({})
    return colors[gId] || "#808080"
  }

  function zoneNameFor(moduleId) {
    if (Config.barLayout.left.includes(moduleId)) return "left"
    if (Config.barLayout.center.includes(moduleId)) return "center"
    return "right"
  }

  function clearPendingGroup() {
    barWindowRoot.pendingGroupId = ""
    barWindowRoot.pendingGroupZone = ""
  }

  function requestGroupClick(moduleId) {
    let zone = barWindowRoot.zoneNameFor(moduleId)
    if (barWindowRoot.pendingGroupId === "") {
      barWindowRoot.pendingGroupId = moduleId
      barWindowRoot.pendingGroupZone = zone
      return
    }
    if (barWindowRoot.pendingGroupId === moduleId) {
      barWindowRoot.clearPendingGroup()
      return
    }
    if (barWindowRoot.pendingGroupZone !== zone) {
      // different zone, can't merge — just reset selection to the new one
      barWindowRoot.pendingGroupId = moduleId
      barWindowRoot.pendingGroupZone = zone
      return
    }
    barWindowRoot.uniteModules(barWindowRoot.pendingGroupId, moduleId)
    barWindowRoot.clearPendingGroup()
  }

  function ungroupModule(moduleId) {
    let groups = Object.assign({}, Config.barGroups || ({}))
    let gId = groups[moduleId]
    if (!gId) return
    delete groups[moduleId]
    let stillUsed = Object.values(groups).indexOf(gId) !== -1
    let colors = Config.barGroupColors || ({})
    if (!stillUsed) {
      colors = Object.assign({}, colors)
      delete colors[gId]
    }
    Config.setBarGroups(groups, colors)
  }

  function uniteModules(aId, bId) {
    let groups = Object.assign({}, Config.barGroups || ({}))
    let gId = groups[bId] || groups[aId] || ("grp_" + bId)
    groups[aId] = gId
    groups[bId] = gId
    Config.barGroups = groups
    barWindowRoot.assignGroupColor(gId)
    Config.saveSettings()
  }

  property var clusterInstances: ({})
  Component {
    id: clusterComponent
    Item {
      id: clusterRoot
      required property var memberIds
      readonly property bool isGroup: clusterRoot.memberIds.length > 1
      implicitWidth: barWindowRoot.vertical ? barWindowRoot.width : clusterRow.implicitWidth
      implicitHeight: barWindowRoot.vertical ? clusterRow.implicitHeight : barWindowRoot.height
      width: implicitWidth
      height: implicitHeight

      Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: s(Config.uiRadius - 4 >= 0 ? Config.uiRadius - 4 : 0)
        visible: clusterRoot.isGroup
        readonly property color groupTint: Qt.color(barWindowRoot.groupColorFor(clusterRoot.memberIds[0]))
        color: Qt.rgba(groupTint.r, groupTint.g, groupTint.b, 0.14)
        border.width: 1
        border.color: Qt.rgba(groupTint.r, groupTint.g, groupTint.b, 0.55)
      }

      Flow {
        id: clusterRow
        anchors.centerIn: parent
        flow: barWindowRoot.vertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: 0
        Component.onCompleted: {
          for (const id of clusterRoot.memberIds) {
            let wrapped = barWindowRoot.wrapperFor(id)
            if (wrapped) wrapped.parent = clusterRow
          }
        }
      }
    }
  }

  function clusterFor(key, memberIds) {
    let existing = barWindowRoot.clusterInstances[key]
    if (existing) return existing
    // drop any stale cluster instances that shared members with this one,
    // reparenting their wrapper children out first so they aren't destroyed
    for (const id of memberIds) {
      for (const k of Object.keys(barWindowRoot.clusterInstances)) {
        if (k !== key && k.split("+").includes(id)) {
          let staleCluster = barWindowRoot.clusterInstances[k]
          for (const memberId of k.split("+")) {
            let w = barWindowRoot.groupWrapperInstances[memberId]
            if (w) w.parent = moduleHost
          }
          staleCluster.destroy()
          delete barWindowRoot.clusterInstances[k]
        }
      }
    }
    let inst = clusterComponent.createObject(moduleHost, { memberIds: memberIds })
    barWindowRoot.clusterInstances[key] = inst
    return inst
  }

  // Detach every cluster from the current layout so destroying the layout
  // does not destroy the module instances inside it.
  function releaseModules() {
    for (const k of Object.keys(barWindowRoot.clusterInstances)) {
      let c = barWindowRoot.clusterInstances[k]
      if (c) c.parent = moduleHost
    }
  }

  Connections {
    target: Config
    function onBarLayoutChanged() { barWindowRoot.zonesChanged(); Config.pruneBarGroups() }
    function onBarGroupsChanged() { barWindowRoot.zonesChanged() }
  }

  // One Loader, started with initial properties so barWindow exists before
  // the layout's own Component.onCompleted runs.
  Loader {
    id: layoutLoader
    anchors.fill: parent
    onStatusChanged: {
      if (status === Loader.Error) console.log("[bar] layout failed to load:", source)
    }
  }

  function applyLayout() {
    const src = barWindowRoot.layoutVertical ? "SideBar.qml" : "TopBar.qml"
    layoutLoader.setSource(src, { barWindow: barWindowRoot })
  }
}
