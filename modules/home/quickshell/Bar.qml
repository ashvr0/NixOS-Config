import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray as TrayService

PanelWindow {
  id: barWindow

  property string pos: Config.barPosition || "top"
  property bool vertical: pos === "left" || pos === "right"

  anchors {
    top: pos !== "bottom"
    bottom: pos !== "top"
    left: pos !== "right"
    right: pos !== "left"
  }

  Scaler {
    id: scaler
    currentWidth: Screen.width
    currentHeight: Screen.height
  }
  function s(val) { return scaler.s(val) }

  implicitHeight: barWindow.vertical ? Screen.height : s(56)
  implicitWidth: barWindow.vertical ? s(56) : Screen.width

  margins {
    top: pos === "bottom" ? 0 : s(10)
    bottom: pos === "top" ? 0 : s(10)
    left: pos === "right" ? 0 : s(10)
    right: pos === "left" ? 0 : s(10)
  }

  // Auto-hide: exclusiveZone drops to 0 so the bar stops reserving screen
  // space (windows can use that area), and a separate always-present
  // trigger strip (edgeTrigger below) at the screen edge detects hover to
  // reveal it. The bar's own mask is only ever fully-open or fully-closed
  // (never a partial/growing rect) so it can't flicker mid-transition, and
  // hover state is shared between the trigger strip and the bar itself so
  // moving from the trigger onto a bar module doesn't register as leaving.
  property bool hovered: false
  property bool revealed: !Config.autoHideBar || barWindow.hovered

  // Neither HoverHandler nor edgeTrigger's hover is "sticky" across the
  // gap between the two windows, so unhover from either one starts a
  // short timer instead of instantly dropping hovered — if the other
  // picks up hover before it fires, the drop is cancelled. This is what
  // actually stops the flicker: without it, briefly having neither
  // hovered=true during the handoff (e.g. cursor crossing from
  // edgeTrigger onto the bar itself) would hide the bar for one frame
  // and immediately re-show it.
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

  property real barSize: (barWindow.vertical ? implicitWidth : implicitHeight) + s(8)
  exclusiveZone: Config.autoHideBar ? (barWindow.revealed ? barSize : 0) : barSize
  Behavior on exclusiveZone { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  color: "transparent"
  mask: Config.autoHideBar && !barWindow.revealed
    ? Qt.region(0, 0, 0, 0)
    : Qt.region(0, 0, width, height)

  // HoverHandler (not MouseArea) tracks hover here: MouseArea's
  // entered/exited only fires reliably when nothing underneath grabs
  // hover first, and bar modules (Workspaces, MusicPlayer, etc.) each
  // have their own hoverEnabled MouseAreas that do exactly that — with a
  // plain MouseArea, moving the cursor across module boundaries produced
  // rapid spurious exited/entered pairs (barWindow.hovered flickering
  // true/false every frame), which made the whole bar flicker up and
  // down. HoverHandler listens passively at the PointerHandler level and
  // isn't blocked by other items claiming the hover/mouse grab.
  HoverHandler {
    id: barHover
  }

  // Thin always-mapped trigger strip pinned to the same edge as the bar.
  // Exists purely to detect "cursor approaching the edge" even while the
  // bar itself is unmapped/hidden (mask is empty), since a fully-masked
  // window receives no hover events at all.
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
    implicitWidth: barWindow.vertical ? 6 : Screen.width
    implicitHeight: barWindow.vertical ? Screen.height : 6
    exclusiveZone: 0
    mask: Qt.region(0, 0, implicitWidth, implicitHeight)

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
      onEntered: barWindow.requestHover()
      onExited: barWindow.requestUnhover()
    }
  }

  // Content is always laid out as a horizontal strip internally since the
  // module components assume a horizontal reading order. For left/right
  // bar placement we rotate the whole strip 90 degrees rather than
  // reflowing each child's internal layout.
  Item {
    id: content
    anchors.centerIn: parent
    width: barWindow.vertical ? barWindow.height : barWindow.width
    height: barWindow.vertical ? barWindow.width : barWindow.height
    rotation: barWindow.vertical ? (pos === "left" ? -90 : 90) : 0

    transform: Translate {
      x: !barWindow.vertical ? 0 : (barWindow.revealed ? 0 : (pos === "left" ? -content.width : content.width))
      y: barWindow.vertical ? 0 : (barWindow.revealed ? 0 : (pos === "top" ? -content.height : content.height))
      Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
      Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    Component {
      id: launcherComponent
      Rectangle {
        width: s(50)
        height: s(50)
        radius: s(Config.uiRadius + 4)
        anchors.verticalCenter: parent.verticalCenter

        color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.75)
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

    Component {
      id: guidebuttonComponent
      Rectangle {
        width: s(50)
        height: s(50)
        radius: s(Config.uiRadius + 4)
        anchors.verticalCenter: parent.verticalCenter

        color: Config.barStyle === "solid" ? "transparent" : Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.75)
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

    Component {
      id: workspacesComponent
      Workspaces { height: content.height }
    }
    Component {
      id: musicplayerComponent
      MusicPlayer { height: content.height }
    }
    Component {
      id: systemstatsComponent
      SystemStats { height: content.height }
    }
    Component {
      id: systemtrayComponent
      SystemTray { height: content.height }
    }
    Component {
      id: keyboardComponent
      Keyboard { height: content.height }
    }
    Component {
      id: volumeComponent
      Item {
        id: volRoot
        height: content.height
        implicitWidth: volInner.implicitWidth + 18 * Config.uiScale

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
          Text { text: volRoot.volumeLevel + "%"; font.pixelSize: 12 * Config.uiScale; font.weight: Font.DemiBold; color: volRoot.volumeMenuOpen ? MatugenColors.accent : MatugenColors.text; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter; Behavior on color { ColorAnimation { duration: 150 } } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: volRoot.volumeMenuOpen = !volRoot.volumeMenuOpen }
      }
    }
    Component {
      id: networkComponent
      Item {
        id: netRoot
        height: content.height
        implicitWidth: wifiInner.implicitWidth + 18 * Config.uiScale

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
          Text { text: netRoot.wifiName; font.pixelSize: 12 * Config.uiScale; font.weight: Font.DemiBold; color: netRoot.networkMenuOpen ? MatugenColors.accent : MatugenColors.text; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: Math.min(implicitWidth, 100 * Config.uiScale); Behavior on color { ColorAnimation { duration: 150 } } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: netRoot.networkMenuOpen = !netRoot.networkMenuOpen }
      }
    }
    Component {
      id: bluetoothComponent
      Item {
        id: btRoot
        height: content.height
        implicitWidth: Math.min(btInner.implicitWidth, 150 * Config.uiScale) + 18 * Config.uiScale

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
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: btRoot.btMenuOpen = !btRoot.btMenuOpen }
      }
    }
    Component {
      id: settingsComponent
      Settings { height: content.height }
    }
    Component {
      id: powerComponent
      Item {
        id: powRoot
        Scaler { id: powScaler; currentWidth: Screen.width; currentHeight: Screen.height }
        function s(val) { return powScaler.s(val) }
        implicitWidth: s(50)
        implicitHeight: s(50)
        height: content.height

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
        case "settings": return settingsComponent
        case "power": return powerComponent
        case "guidebutton": return Config.showGuideButton ? guidebuttonWrapperComponent : null
        default: return null
      }
    }

    // Every module instance is created exactly ONCE, up front, and kept
    // alive in moduleHost for the lifetime of the bar. This is the fix
    // for modules like SystemStats crashing/losing popup state when
    // dragged between bar zones in the layout editor: previously each
    // zone was a Repeater over Config.barLayout.<zone> with a fresh
    // Loader delegate per entry, so moving a module to a different zone
    // meant Qt destroyed the old delegate (and everything inside it,
    // including SystemStats's nested Settings/Power/Calendar and their
    // IpcHandlers) and built a brand new one — colliding IpcHandler
    // registrations mid-teardown is what crashed quickshell. Now moving
    // a module only changes which zone Row it's reparented into; the
    // instance itself, and everything nested inside it, is never
    // destroyed just because its position in the bar changed.
    property var moduleInstances: ({})

    function instanceFor(id) {
      if (content.moduleInstances[id]) return content.moduleInstances[id]
      let comp = content.componentFor(id)
      if (!comp) return null
      let inst = comp.createObject(moduleHost)
      content.moduleInstances[id] = inst
      return inst
    }

    // Off-screen parking spot for module instances whose id isn't in any
    // current zone list (e.g. guidebutton when Config.showGuideButton is
    // false). Keeps them alive without being visible anywhere.
    Item {
      id: moduleHost
      visible: false
    }

    // "solid" bar style draws one continuous surface behind each zone's
    // modules with no gaps, instead of every module carrying its own
    // separate pill background. The modules themselves are unchanged;
    // only the wrapping surface and inter-module spacing differ.
    readonly property bool solidStyle: Config.barStyle === "solid"

    // In solid style, the entire bar — left zone through right-main zone —
    // renders as ONE continuous connected surface (not separate left+center
    // and right-main spans with a gap between them). This single Rectangle
    // spans from the leftmost occupied zone to the rightmost occupied
    // zone, whichever those happen to be, so it still looks right if any
    // zone is empty. Only shown in solid style: separated style handles
    // the right zone's connected look via the dedicated Rectangle below,
    // and leaves left/center as individual per-module pills.
    Rectangle {
      readonly property bool leftHasContent: leftZone.children.length > 0
      readonly property bool centerHasContent: centerZone.children.length > 0
      readonly property bool rightHasContent: rightZoneMain.children.length > 0
      readonly property real spanLeft: leftHasContent ? leftZone.x
        : (centerHasContent ? centerZone.x : rightZoneMainContainer.x)
      readonly property real spanRight: rightHasContent ? (rightZoneMainContainer.x + rightZoneMainContainer.width)
        : (centerHasContent ? (centerZone.x + centerZone.width) : (leftZone.x + leftZone.width))
      x: spanLeft - s(10)
      y: (content.height - s(50)) / 2
      width: spanRight - spanLeft + s(20)
      height: s(50)
      radius: s(14)
      color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.75)
      border.color: Qt.rgba(1, 1, 1, 0.06)
      border.width: 1
      visible: content.solidStyle && (leftHasContent || centerHasContent || rightHasContent)
    }

    // Right zone's main modules (everything except the tray) always render
    // as one connected surface, in both solid and separated bar styles.
    // This is drawn regardless of content.solidStyle: in solid style it's
    // redundant with the big connected Rectangle above (both cover the
    // same area), and in separated style it's what makes the right zone
    // read as a single pill instead of individually-gapped module pills,
    // while left/center zones keep their separated per-module look.
    Rectangle {
      x: rightZoneMainContainer.x - s(10)
      y: (content.height - s(50)) / 2
      width: rightZoneMainContainer.width + s(20)
      height: s(50)
      radius: s(14)
      color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.75)
      border.color: Qt.rgba(1, 1, 1, 0.06)
      border.width: 1
      visible: rightZoneMain.children.length > 0
    }

    // Right zone's tray pill: always kept separate from the main connected
    // surface with its own gap, in both bar styles. In separated style,
    // SystemTray still renders its own individual icon backgrounds inside
    // this pill (unchanged), matching how it already looked before.
    Rectangle {
      x: rightZoneTrayContainer.x - s(10)
      y: (content.height - s(50)) / 2
      width: rightZoneTrayContainer.width + s(20)
      height: s(50)
      radius: s(14)
      color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.75)
      border.color: Qt.rgba(1, 1, 1, 0.06)
      border.width: 1
      visible: content.solidStyle && TrayService.SystemTray.items.values.length > 0
    }

    // barWidthPercent (0-100, Settings.qml) controls how far the left and
    // right zones sit from the bar's edges, i.e. how close they are pulled
    // toward the center module. 100% = hug the edges (max spread from
    // center); 0% = pulled in all the way toward center.
    readonly property real edgeInset: s(160) * (1 - Config.barWidthPercent / 100)

    Row {
      id: leftZone
      anchors { left: parent.left; leftMargin: content.edgeInset; verticalCenter: parent.verticalCenter }
      spacing: s(4)
    }

    Row {
      id: centerZone
      anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
      spacing: s(4)
    }

    // Gap between the tray pill and the rest of the right zone. s(16) on
    // top of the s(10) each Rectangle already insets gives a clear visual
    // break instead of the two pills nearly touching.
    readonly property real rightZoneGap: s(25)

    Item {
      id: rightZoneMainContainer
      anchors {
        right: parent.right
        rightMargin: s(6) + content.edgeInset
        verticalCenter: parent.verticalCenter
      }
      width: rightZoneMain.width
      height: s(50)

      Row {
        id: rightZoneMain
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: s(20)
      }
    }

    Item {
      id: rightZoneTrayContainer
      anchors {
        right: rightZoneMainContainer.left
        rightMargin: TrayService.SystemTray.items.values.length > 0 ? content.rightZoneGap : 0
        verticalCenter: parent.verticalCenter
      }
      width: rightZoneTray.width
      height: content.solidStyle ? s(50) : rightZoneTray.height

      Row {
        id: rightZoneTray
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: s(10)
      }
    }

    // Rebuilds each zone Row's children to match Config.barLayout,
    // reparenting existing instances (creating them on first use) rather
    // than destroying/recreating anything. Runs whenever the layout
    // changes and once at startup.
    //
    // Row lays children out in children-array order, not by any z or
    // index property, so getting the visual order right means the
    // reparent calls below must happen in z.ids order — reparenting an
    // item that's already a child just moves it to the end of the
    // array, which is exactly the "insert at position i" behavior we
    // want when done in order for i = 0, 1, 2, ...
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
        for (let i = 0; i < z.ids.length; i++) {
          let inst = content.instanceFor(z.ids[i])
          if (!inst) continue
          if (inst.parent !== z.row) {
            inst.parent = z.row
          } else {
            // Already in this row: force it to the end of the children
            // array (matching insertion order) by reparenting through
            // moduleHost. A same-parent reassignment is a no-op in QML
            // and does not reorder children.
            inst.parent = moduleHost
            inst.parent = z.row
          }
        }
      }
    }

    Component.onCompleted: content.syncZones()
    Connections {
      target: Config
      function onBarLayoutChanged() { content.syncZones() }
    }
  }
}
