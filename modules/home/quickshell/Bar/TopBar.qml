import QtQuick
import Quickshell.Services.SystemTray as TrayService
import "../Singletons"
import ".."

// Horizontal layout (top or bottom edge). Loaded by Bar.qml.
// Bar.qml owns the window, the modules and the grouping logic.
// This file only decides where the zones go and draws the backgrounds.
Item {
  id: content
  property var barWindow
  anchors.fill: parent

  function s(val) { return Scaler.s(val) }

  visible: content.barWindow ? !content.barWindow.positionChanging : false
  opacity: visible ? 1 : 0

  transform: Translate {
    y: (!content.barWindow || content.barWindow.revealed) ? 0 : (content.barWindow.pos === "top" ? -content.height : content.height)
    Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  }

  readonly property bool solidStyle: Config.barStyle === "solid"
  readonly property bool fillStyle: Config.barStyle === "fill"
  property int zoneChildRevision: 0
// Fill style: covers the whole bar window, flush with the screen edges
Rectangle {
  x: 0
  y: 0
  width: content.width
  height: content.height
  radius: 0
  color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, Config.barOpacityPercent / 100)
  visible: content.fillStyle

  // thin line on the edge facing the desktop
  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    height: 1
    y: (content.barWindow && content.barWindow.pos === "top") ? parent.height - 1 : 0
    color: Qt.rgba(1, 1, 1, 0.06)
  }
}

  // Main background spanning all zones (solid style)
  Rectangle {
    readonly property bool leftHasContent: content.zoneChildRevision >= 0 && leftZone.children.length > 0
    readonly property bool centerHasContent: content.zoneChildRevision >= 0 && centerZone.children.length > 0
    readonly property bool rightHasContent: content.zoneChildRevision >= 0 && rightZoneMain.children.length > 0
    readonly property real spanStart: leftHasContent ? leftZone.x
      : (centerHasContent ? centerZone.x : rightZoneMainContainer.x)
    readonly property real spanEnd: rightHasContent
      ? (rightZoneMainContainer.x + rightZoneMainContainer.width)
      : (centerHasContent ? (centerZone.x + centerZone.width) : (leftZone.x + leftZone.width))
    x: spanStart - content.s(10)
    y: (content.height - content.s(50)) / 2
    width: spanEnd - spanStart + content.s(20)
    height: content.s(50)
    radius: content.s(Config.uiRadius)
    color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, Config.barOpacityPercent / 100)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    visible: content.solidStyle && (leftHasContent || centerHasContent || rightHasContent)
  }

  // Right main pill (modular style)
  Rectangle {
    x: rightZoneMainContainer.x - content.s(10)
    y: (content.height - content.s(50)) / 2
    width: rightZoneMainContainer.width + content.s(20)
    height: content.s(50)
    radius: content.s(Config.uiRadius)
    color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, Config.barOpacityPercent / 100)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    visible: !content.solidStyle && !content.fillStyle && content.zoneChildRevision >= 0 && rightZoneMain.children.length > 0
  }

  // Tray pill
  Rectangle {
    x: rightZoneTrayContainer.x - content.s(10)
    y: (content.height - content.s(50)) / 2
    width: rightZoneTrayContainer.width + content.s(20)
    height: content.s(50)
    radius: content.s(Config.uiRadius)
    color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, Config.barOpacityPercent / 100)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    visible: content.solidStyle && TrayService.SystemTray.items.values.length > 0
  }

  readonly property real minGap: content.s(16)
  readonly property real edgeInset: Math.max(content.s(10),
    (content.width / 2) * (1 - Config.barWidthPercent / 100))

  readonly property real leftRawX: content.edgeInset
  readonly property real rightRawX: content.width - rightZoneMainContainer.width - content.s(6) - content.edgeInset

  // Center zone half extent, measured
  readonly property real centerHalfW: centerZone.width / 2
  readonly property real centerMidX: content.width / 2

  Flow {
    id: leftZone
    x: Math.min(content.leftRawX, content.centerMidX - content.centerHalfW - content.minGap - width)
    y: (content.height - height) / 2
    flow: Flow.LeftToRight
    spacing: content.s(4)
  }

  Flow {
    id: centerZone
    x: (content.width - width) / 2
    y: (content.height - height) / 2
    flow: Flow.LeftToRight
    spacing: content.s(4)
  }

  readonly property real rightZoneGap: content.s(25)

  // Tray plus main plus the gap between them are clamped as one block against the center zone
  readonly property real rightBlockExtra: rightZoneTrayContainer.trayGap > 0
    ? rightZoneTrayContainer.width + rightZoneTrayContainer.trayGap
    : 0

  Item {
    id: rightZoneMainContainer
    x: Math.max(content.rightRawX, content.centerMidX + content.centerHalfW + content.minGap + content.rightBlockExtra)
    y: (content.height - height) / 2
    implicitWidth: rightZoneMain.implicitWidth
    implicitHeight: content.s(50)
    width: implicitWidth
    height: implicitHeight

    Flow {
      id: rightZoneMain
      x: (parent.width - width) / 2
      y: (parent.height - height) / 2
      flow: Flow.LeftToRight
      spacing: content.s(20)
    }
  }

  Item {
    id: rightZoneTrayContainer
    readonly property real trayGap: TrayService.SystemTray.items.values.length > 0 ? content.rightZoneGap : 0
    x: rightZoneMainContainer.x - width - trayGap
    y: (content.height - height) / 2
    implicitWidth: rightZoneTray.implicitWidth
    implicitHeight: content.solidStyle ? content.s(50) : rightZoneTray.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Flow {
      id: rightZoneTray
      x: (parent.width - width) / 2
      y: (parent.height - height) / 2
      flow: Flow.LeftToRight
      spacing: content.s(10)
    }
  }

  function syncZones() {
    if (!content.barWindow) return
    const host = content.barWindow.moduleHostItem
    const rightMainIds = Config.barLayout.right.filter(id => id !== "systemtray")
    const rightTrayIds = Config.barLayout.right.filter(id => id === "systemtray")
    const zones = [
      { row: leftZone, ids: Config.barLayout.left },
      { row: centerZone, ids: Config.barLayout.center },
      { row: rightZoneMain, ids: rightMainIds },
      { row: rightZoneTray, ids: rightTrayIds }
    ]
    for (const z of zones) {
      // Consecutive ids in the same group collapse into one cluster so the
      // Flow lays grouped modules out with zero gap between them.
      let clusters = []
      let i = 0
      while (i < z.ids.length) {
        let id = z.ids[i]
        let gId = content.barWindow.groupIdFor(id)
        if (gId === "") {
          clusters.push([id])
          i++
          continue
        }
        let cluster = [id]
        let j = i + 1
        while (j < z.ids.length && content.barWindow.groupIdFor(z.ids[j]) === gId) {
          cluster.push(z.ids[j])
          j++
        }
        clusters.push(cluster)
        i = j
      }
      for (let ci = 0; ci < clusters.length; ci++) {
        let cluster = clusters[ci]
        let clusterItem = content.barWindow.clusterFor(cluster.join("+"), cluster)
        clusterItem.parent = host
        clusterItem.parent = z.row
        clusterItem.z = ci
      }
    }
  }

  function relayoutZones() {
    if (!content.barWindow) return
    const host = content.barWindow.moduleHostItem
    for (const inst of Object.values(content.barWindow.moduleInstances)) {
      if (!inst) continue
      const originalParent = inst.parent
      inst.parent = host
      inst.parent = originalParent
    }
    content.syncZones()
    // children.length based bindings can go stale after reparenting
    Qt.callLater(content.forceZoneVisibilityRefresh)
  }

  function forceZoneVisibilityRefresh() {
    content.zoneChildRevision = content.zoneChildRevision + 1
  }

  Component.onCompleted: {
    content.syncZones()
    Qt.callLater(content.forceZoneVisibilityRefresh)
  }

  // barWindow can arrive after the first completion pass, so sync again when it does
  onBarWindowChanged: {
    if (content.barWindow) {
      content.syncZones()
      Qt.callLater(content.forceZoneVisibilityRefresh)
    }
  }

  Connections {
    target: content.barWindow || null
    function onZonesChanged() { content.syncZones() }
    function onPositionChangingChanged() {
      if (!content.barWindow.positionChanging) Qt.callLater(content.relayoutZones)
    }
  }
}
