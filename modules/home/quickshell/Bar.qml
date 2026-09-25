import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray as TrayService
import "Singletons"

PanelWindow {
  id: barWindow

  property string pos: ["top", "bottom", "left", "right"].includes(Config.barPosition) ? Config.barPosition : "top"
  readonly property bool vertical: pos === "left" || pos === "right"

  property bool positionChanging: false
  Timer {
    id: positionChangeTimer
    interval: 200
    onTriggered: barWindow.positionChanging = false
  }
  onPosChanged: {
    barWindow.positionChanging = true
    positionChangeTimer.restart()
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
    }
  function s(val) { return Scaler.s(val) }

  implicitHeight: vertical ? Screen.height : s(56)
  implicitWidth: vertical ? s(56) : Screen.width

  margins {
    top: vertical ? s(10) : (pos === "top" ? 0 : s(10))
    bottom: vertical ? s(10) : (pos === "bottom" ? 0 : s(10))
    left: vertical ? (pos === "left" ? 0 : s(10)) : 0
    right: vertical ? (pos === "right" ? 0 : s(10)) : 0
  }

  property bool hovered: false
  property bool anyMenuOpen: (content.moduleInstances["volume"] && content.moduleInstances["volume"].volumeMenuOpen)
    || (content.moduleInstances["network"] && content.moduleInstances["network"].networkMenuOpen)
    || (content.moduleInstances["bluetooth"] && content.moduleInstances["bluetooth"].btMenuOpen)
    || (content.moduleInstances["power"] && content.moduleInstances["power"].menuOpen)
    || (content.moduleInstances["weather"] && content.moduleInstances["weather"].weatherMenuOpen)
    || (content.moduleInstances["musicplayer"] && content.moduleInstances["musicplayer"].playerExpanded)
    || false
  property bool revealed: !Config.autoHideBar || barWindow.hovered || barWindow.anyMenuOpen

  function requestHover() { hoverReleaseTimer.stop(); barWindow.hovered = true }
  function requestUnhover() { hoverReleaseTimer.restart() }
  Timer {
    id: hoverReleaseTimer
    interval: 150
    onTriggered: barWindow.hovered = false
  }

  Connections {
    target: barHover
    function onHoveredChanged() {
      if (barHover.hovered) barWindow.requestHover()
      else barWindow.requestUnhover()
    }
  }

  property real barSize: (vertical ? implicitWidth : implicitHeight) + s(8)
  exclusiveZone: Config.autoHideBar ? (barWindow.revealed ? barSize : 0) : barSize
  Behavior on exclusiveZone { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  color: "transparent"
  mask: Region {
    x: 0
    y: 0
    width: Config.autoHideBar && !barWindow.revealed ? 0 : barWindow.width
    height: Config.autoHideBar && !barWindow.revealed ? 0 : barWindow.height
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
      onEntered: barWindow.requestHover()
      onExited: barWindow.requestUnhover()
    }
  }

  Item {
    id: content
    anchors.centerIn: parent
    width: barWindow.width
    height: barWindow.height
    visible: !barWindow.positionChanging
    opacity: visible ? 1 : 0
    readonly property bool vertical: barWindow.vertical
    readonly property real thickness: vertical ? content.width : content.height

    transform: Translate {
      x: !barWindow.vertical ? 0 : (barWindow.revealed ? 0 : (pos === "left" ? -content.width : content.width))
      y: barWindow.vertical ? 0 : (barWindow.revealed ? 0 : (pos === "top" ? -content.height : content.height))
      Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
      Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    Component {
      id: launcherComponent
      Item {
        id: launcherRoot
        width: content.vertical ? content.width : s(50)
        height: content.vertical ? s(50) : content.height

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
        width: content.vertical ? content.width : s(50)
        height: content.vertical ? s(50) : content.height

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
      Workspaces { height: content.vertical ? undefined : content.height; width: content.vertical ? content.width : undefined }
    }
    Component {
      id: musicplayerComponent
      MusicPlayer { height: content.vertical ? undefined : content.height; width: content.vertical ? content.width : undefined }
    }
    Component {
      id: systemstatsComponent
      CalendarBar { height: content.vertical ? undefined : content.height }
    }
    Component {
      id: systemtrayComponent
      SystemTray { height: content.vertical ? undefined : content.height; width: content.vertical ? content.width : undefined }
    }
    Component {
      id: keyboardComponent
      Keyboard { height: content.vertical ? undefined : content.height }
    }
    Component {
      id: volumeComponent
      Item {
        id: volRoot
        height: content.vertical ? content.width : content.height
        implicitWidth: volInner.implicitWidth + 18 * Config.uiScale
        width: content.vertical ? content.width : implicitWidth

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
          Text { visible: !content.vertical; text: volRoot.volumeLevel + "%"; font.pixelSize: 12 * Config.uiScale; font.weight: Font.DemiBold; color: volRoot.volumeMenuOpen ? MatugenColors.accent : MatugenColors.text; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter; Behavior on color { ColorAnimation { duration: 150 } } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { let next = !volRoot.volumeMenuOpen; if (next) content.closeOtherPopups("volume"); volRoot.volumeMenuOpen = next } }
      }
    }
    Component {
      id: networkComponent
      Item {
        id: netRoot
        height: content.vertical ? content.width : content.height
        implicitWidth: wifiInner.implicitWidth + 18 * Config.uiScale
        width: content.vertical ? content.width : implicitWidth

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
          Text { visible: !content.vertical; text: netRoot.wifiName; font.pixelSize: 12 * Config.uiScale; font.weight: Font.DemiBold; color: netRoot.networkMenuOpen ? MatugenColors.accent : MatugenColors.text; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: Math.min(implicitWidth, 100 * Config.uiScale); Behavior on color { ColorAnimation { duration: 150 } } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { let next = !netRoot.networkMenuOpen; if (next) content.closeOtherPopups("network"); netRoot.networkMenuOpen = next } }
      }
    }
    Component {
      id: bluetoothComponent
      Item {
        id: btRoot
        height: content.vertical ? content.width : content.height
        implicitWidth: Math.min(btInner.implicitWidth, 150 * Config.uiScale) + 18 * Config.uiScale
        width: content.vertical ? content.width : implicitWidth

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
            visible: !content.vertical
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
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { let next = !btRoot.btMenuOpen; if (next) content.closeOtherPopups("bluetooth"); btRoot.btMenuOpen = next } }
      }
    }
    Component {
      id: weatherComponent
      Item {
        id: weatherModuleRoot
        height: content.vertical ? content.width : content.height
        implicitWidth: weatherInner.implicitWidth + 18 * Config.uiScale
        width: content.vertical ? content.width : implicitWidth

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
          Text { visible: !content.vertical; text: Weather.hasError ? "--" : (Weather.currentTemp + Weather.tempSuffix); font.pixelSize: 12 * Config.uiScale; font.weight: Font.DemiBold; color: weatherModuleRoot.weatherMenuOpen ? MatugenColors.accent : MatugenColors.text; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter; Behavior on color { ColorAnimation { duration: 150 } } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { let next = !weatherModuleRoot.weatherMenuOpen; if (next) content.closeOtherPopups("weather"); weatherModuleRoot.weatherMenuOpen = next } }
      }
    }
    Component {
      id: settingsComponent
      Settings { height: content.vertical ? undefined : content.height; width: content.vertical ? content.width : undefined }
    }
    Component {
      id: powerComponent
      Item {
        id: powRoot
        Component.onCompleted: { Scaler.currentWidth = Screen.width; Scaler.currentHeight = Screen.height }
        function s(val) { return Scaler.s(val) }
        implicitWidth: s(50)
        implicitHeight: s(50)
        width: content.vertical ? content.width : implicitWidth
        height: content.vertical ? implicitHeight : content.height

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
        let inst = content.moduleInstances[id]
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
      if (id === "volume") inst.volumeMenuOpenChanged.connect(function() { if (inst.volumeMenuOpen) content.closeOtherPopups("volume") })
      else if (id === "network") inst.networkMenuOpenChanged.connect(function() { if (inst.networkMenuOpen) content.closeOtherPopups("network") })
      else if (id === "bluetooth") inst.btMenuOpenChanged.connect(function() { if (inst.btMenuOpen) content.closeOtherPopups("bluetooth") })
      else if (id === "weather") inst.weatherMenuOpenChanged.connect(function() { if (inst.weatherMenuOpen) content.closeOtherPopups("weather") })
      else if (id === "power") inst.menuOpenChanged.connect(function() { if (inst.menuOpen) content.closeOtherPopups("power") })
      else if (id === "musicplayer") inst.playerExpandedChanged.connect(function() { if (inst.playerExpanded) content.closeOtherPopups("musicplayer") })
    }

    Component {
      id: groupWrapperComponent
      Item {
        id: wrapper
        required property string moduleId
        required property var moduleInst
        readonly property string groupId: content.groupIdFor(wrapper.moduleId)
        readonly property bool grouped: wrapper.groupId !== ""
        readonly property color groupColor: Qt.color(content.groupColorFor(wrapper.moduleId))
        readonly property bool isPending: content.pendingGroupId === wrapper.moduleId

        width: content.vertical ? content.width : moduleInst.width
        height: content.vertical ? moduleInst.height : content.height

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
              if (wrapper.grouped && content.pendingGroupId === "") {
                content.ungroupModule(wrapper.moduleId)
              } else {
                content.requestGroupClick(wrapper.moduleId)
              }
              mouse.accepted = true
            }
          }
        }
      }
    }

    function instanceFor(id) {
      if (content.moduleInstances[id]) return content.moduleInstances[id]
      let comp = content.componentFor(id)
      if (!comp) return null
      let inst = comp.createObject(moduleHost)
      content.moduleInstances[id] = inst
      content.watchPopup(id, inst)
      return inst
    }

    property var groupWrapperInstances: ({})
    function wrapperFor(id) {
      if (content.groupWrapperInstances[id]) return content.groupWrapperInstances[id]
      let inst = content.instanceFor(id)
      if (!inst) return null
      let wrapped = groupWrapperComponent.createObject(moduleHost, { moduleId: id, moduleInst: inst })
      content.groupWrapperInstances[id] = wrapped
      return wrapped
    }

    Item {
      id: moduleHost
      visible: false
    }

    readonly property bool solidStyle: Config.barStyle === "solid"
    property int zoneChildRevision: 0

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
      let palette = content.groupPalette.map(content.colorToStr)
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
      let gId = content.groupIdFor(moduleId)
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
      content.pendingGroupId = ""
      content.pendingGroupZone = ""
    }

    function requestGroupClick(moduleId) {
      let zone = content.zoneNameFor(moduleId)
      if (content.pendingGroupId === "") {
        content.pendingGroupId = moduleId
        content.pendingGroupZone = zone
        return
      }
      if (content.pendingGroupId === moduleId) {
        content.clearPendingGroup()
        return
      }
      if (content.pendingGroupZone !== zone) {
        // different zone, can't merge — just reset selection to the new one
        content.pendingGroupId = moduleId
        content.pendingGroupZone = zone
        return
      }
      content.uniteModules(content.pendingGroupId, moduleId)
      content.clearPendingGroup()
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
      content.assignGroupColor(gId)
      Config.saveSettings()
    }

    Rectangle {
      readonly property bool leftHasContent: content.zoneChildRevision >= 0 && leftZone.children.length > 0
      readonly property bool centerHasContent: content.zoneChildRevision >= 0 && centerZone.children.length > 0
      readonly property bool rightHasContent: content.zoneChildRevision >= 0 && rightZoneMain.children.length > 0
      readonly property real spanStart: leftHasContent ? (content.vertical ? leftZone.y : leftZone.x)
        : (centerHasContent ? (content.vertical ? centerZone.y : centerZone.x)
          : (content.vertical ? rightZoneMainContainer.y : rightZoneMainContainer.x))
      readonly property real spanEnd: rightHasContent
        ? (content.vertical ? (rightZoneMainContainer.y + rightZoneMainContainer.height) : (rightZoneMainContainer.x + rightZoneMainContainer.width))
        : (centerHasContent ? (content.vertical ? (centerZone.y + centerZone.height) : (centerZone.x + centerZone.width))
          : (content.vertical ? (leftZone.y + leftZone.height) : (leftZone.x + leftZone.width)))
      x: content.vertical ? (content.width - s(50)) / 2 : spanStart - s(10)
      y: content.vertical ? spanStart - s(10) : (content.height - s(50)) / 2
      width: content.vertical ? s(50) : spanEnd - spanStart + s(20)
      height: content.vertical ? spanEnd - spanStart + s(20) : s(50)
      radius: s(Config.uiRadius)
      color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, Config.barOpacityPercent / 100)
      border.color: Qt.rgba(1, 1, 1, 0.06)
      border.width: 1
      visible: content.solidStyle && (leftHasContent || centerHasContent || rightHasContent)
    }

    Rectangle {
      x: content.vertical ? (content.width - s(50)) / 2 : rightZoneMainContainer.x - s(10)
      y: content.vertical ? rightZoneMainContainer.y - s(10) : (content.height - s(50)) / 2
      width: content.vertical ? s(50) : rightZoneMainContainer.width + s(20)
      height: content.vertical ? rightZoneMainContainer.height + s(20) : s(50)
      radius: s(Config.uiRadius)
      color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, Config.barOpacityPercent / 100)
      border.color: Qt.rgba(1, 1, 1, 0.06)
      border.width: 1
      visible: !content.solidStyle && content.zoneChildRevision >= 0 && rightZoneMain.children.length > 0
    }

    Rectangle {
      x: content.vertical ? (content.width - s(50)) / 2 : rightZoneTrayContainer.x - s(10)
      y: content.vertical ? rightZoneTrayContainer.y - s(10) : (content.height - s(50)) / 2
      width: content.vertical ? s(50) : rightZoneTrayContainer.width + s(20)
      height: content.vertical ? rightZoneTrayContainer.height + s(20) : s(50)
      radius: s(Config.uiRadius)
      color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, Config.barOpacityPercent / 100)
      border.color: Qt.rgba(1, 1, 1, 0.06)
      border.width: 1
      visible: content.solidStyle && TrayService.SystemTray.items.values.length > 0
    }

    readonly property real minGap: s(16)
    readonly property real edgeInset: Math.max(s(10),
      (content.vertical ? content.height / 2 : content.width / 2) * (1 - Config.barWidthPercent / 100))

    // Raw (unclamped) positions from edgeInset
    readonly property real leftRawX: content.edgeInset
    readonly property real leftRawY: content.edgeInset
    readonly property real rightRawX: parent && rightZoneMainContainer ? parent.width - rightZoneMainContainer.width - s(6) - content.edgeInset : 0
    readonly property real rightRawY: parent && rightZoneMainContainer ? parent.height - rightZoneMainContainer.height - s(6) - content.edgeInset : 0

    // Center zone's actual half-extent (measured, not assumed)
    readonly property real centerHalfW: centerZone.width / 2
    readonly property real centerHalfH: centerZone.height / 2
    readonly property real centerMidX: parent ? parent.width / 2 : 0
    readonly property real centerMidY: parent ? parent.height / 2 : 0

    Flow {
      id: leftZone
      x: content.vertical
         ? (parent.width - width) / 2
         : Math.min(content.leftRawX, content.centerMidX - content.centerHalfW - content.minGap - width)
      y: content.vertical
         ? Math.min(content.leftRawY, content.centerMidY - content.centerHalfH - content.minGap - height)
         : (parent.height - height) / 2
      flow: content.vertical ? Flow.TopToBottom : Flow.LeftToRight
      spacing: s(4)
    }

    Flow {
      id: centerZone
      x: (parent.width - width) / 2
      y: (parent.height - height) / 2
      flow: content.vertical ? Flow.TopToBottom : Flow.LeftToRight
      spacing: s(4)
    }
    readonly property real rightZoneGap: s(25)

    // Combined width of tray + main + gap between them, used so the
    // pair is clamped as a single block against centerZone's edge.
    readonly property real rightBlockExtra: rightZoneTrayContainer && rightZoneTrayContainer.trayGap > 0
      ? rightZoneTrayContainer.width + rightZoneTrayContainer.trayGap
      : 0

    Item {
      id: rightZoneMainContainer
      x: content.vertical
         ? (parent.width - width) / 2
         : Math.max(content.rightRawX, content.centerMidX + content.centerHalfW + content.minGap + content.rightBlockExtra)
      y: content.vertical
         ? Math.max(content.rightRawY, content.centerMidY + content.centerHalfH + content.minGap + content.rightBlockExtra)
         : (parent.height - height) / 2
      implicitWidth: content.vertical ? s(50) : rightZoneMain.implicitWidth
      implicitHeight: content.vertical ? rightZoneMain.implicitHeight : s(50)
      width: implicitWidth
      height: implicitHeight

      Flow {
        id: rightZoneMain
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        flow: content.vertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: s(20)
      }
    }

    Item {
      id: rightZoneTrayContainer
      readonly property real trayGap: TrayService.SystemTray.items.values.length > 0 ? content.rightZoneGap : 0
      x: content.vertical ? (parent.width - width) / 2 : (rightZoneMainContainer.x - width - trayGap)
      y: content.vertical ? (rightZoneMainContainer.y - height - trayGap) : (parent.height - height) / 2
      implicitWidth: content.vertical ? (content.solidStyle ? s(50) : rightZoneTray.implicitWidth) : rightZoneTray.implicitWidth
      implicitHeight: content.vertical ? rightZoneTray.implicitHeight : (content.solidStyle ? s(50) : rightZoneTray.implicitHeight)
      width: implicitWidth
      height: implicitHeight

      Flow {
        id: rightZoneTray
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        flow: content.vertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: s(10)
      }
    }
    function syncZones() {
      const rightMainIds = Config.barLayout.right.filter(id => id !== "systemtray")
      const rightTrayIds = Config.barLayout.right.filter(id => id === "systemtray")
      const zones = [
        { row: leftZone, ids: Config.barLayout.left },
        { row: centerZone, ids: Config.barLayout.center },
        { row: rightZoneMain, ids: rightMainIds },
        { row: rightZoneTray, ids: rightTrayIds }
      ]
      for (const z of zones) {
        // Collapse consecutive same-group ids into one cluster wrapper so
        // Flow lays grouped modules out with zero gap between them.
        let clusters = []
        let i = 0
        while (i < z.ids.length) {
          let id = z.ids[i]
          let gId = content.groupIdFor(id)
          if (gId === "") {
            clusters.push([id])
            i++
            continue
          }
          let cluster = [id]
          let j = i + 1
          while (j < z.ids.length && content.groupIdFor(z.ids[j]) === gId) {
            cluster.push(z.ids[j])
            j++
          }
          clusters.push(cluster)
          i = j
        }
        for (let ci = 0; ci < clusters.length; ci++) {
          let cluster = clusters[ci]
          let clusterKey = cluster.join("+")
          let clusterItem = content.clusterFor(clusterKey, cluster)
          clusterItem.parent = moduleHost
          clusterItem.parent = z.row
          clusterItem.z = ci
        }
      }
    }

    property var clusterInstances: ({})
    Component {
      id: clusterComponent
      Item {
        id: clusterRoot
        required property var memberIds
        readonly property bool isGroup: clusterRoot.memberIds.length > 1
        implicitWidth: content.vertical ? content.width : clusterRow.implicitWidth
        implicitHeight: content.vertical ? clusterRow.implicitHeight : content.height
        width: implicitWidth
        height: implicitHeight

        Rectangle {
          anchors.fill: parent
          anchors.margins: -2
          radius: s(Config.uiRadius - 4 >= 0 ? Config.uiRadius - 4 : 0)
          visible: clusterRoot.isGroup
          readonly property color groupTint: Qt.color(content.groupColorFor(clusterRoot.memberIds[0]))
          color: Qt.rgba(groupTint.r, groupTint.g, groupTint.b, 0.14)
          border.width: 1
          border.color: Qt.rgba(groupTint.r, groupTint.g, groupTint.b, 0.55)
        }

        Flow {
          id: clusterRow
          anchors.centerIn: parent
          flow: content.vertical ? Flow.TopToBottom : Flow.LeftToRight
          spacing: 0
          Component.onCompleted: {
            for (const id of clusterRoot.memberIds) {
              let wrapped = content.wrapperFor(id)
              if (wrapped) wrapped.parent = clusterRow
            }
          }
        }
      }
    }

    function clusterFor(key, memberIds) {
      let existing = content.clusterInstances[key]
      if (existing) return existing
      // drop any stale cluster instances that shared members with this one,
      // reparenting their wrapper children out first so they aren't destroyed
      for (const id of memberIds) {
        for (const k of Object.keys(content.clusterInstances)) {
          if (k !== key && k.split("+").includes(id)) {
            let staleCluster = content.clusterInstances[k]
            for (const memberId of k.split("+")) {
              let w = content.groupWrapperInstances[memberId]
              if (w) w.parent = moduleHost
            }
            staleCluster.destroy()
            delete content.clusterInstances[k]
          }
        }
      }
      let inst = clusterComponent.createObject(moduleHost, { memberIds: memberIds })
      content.clusterInstances[key] = inst
      return inst
    }

    function relayoutZones() {
      const allInstances = Object.values(content.moduleInstances)
      for (const inst of allInstances) {
        if (!inst) continue
        const originalParent = inst.parent
        inst.parent = moduleHost
        inst.parent = originalParent
      }
      content.syncZones()
      // children.length-based visible bindings (rightHasContent etc)
      // can get stuck stale after reparenting through moduleHost.
      // Force them to re-evaluate next tick.
      Qt.callLater(content.forceZoneVisibilityRefresh)
    }

    function forceZoneVisibilityRefresh() {
      content.zoneChildRevision = content.zoneChildRevision + 1
    }

    Component.onCompleted: content.syncZones()
    Connections {
      target: Config
      function onBarLayoutChanged() { content.syncZones(); Config.pruneBarGroups() }
      function onBarGroupsChanged() { content.syncZones() }
    }
    Connections {
      target: barWindow
      function onPositionChangingChanged() {
        if (!barWindow.positionChanging) Qt.callLater(content.relayoutZones)
      }
    }
  }
}
