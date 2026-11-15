import QtQuick
import Quickshell.Services.SystemTray as TrayService
import "../Singletons"
import ".."

// Vertical layout (left or right edge). Loaded by Bar.qml.
Item {
  id: content
  property var barWindow
  anchors.fill: parent

  function s(val) { return Scaler.s(val) }
readonly property bool fillStyle: Config.barStyle === "fill"
  visible: content.barWindow ? !content.barWindow.positionChanging : false
  opacity: visible ? 1 : 0

  transform: Translate {
    x: (!content.barWindow || content.barWindow.revealed) ? 0 : (content.barWindow.pos === "left" ? -content.width : content.width)
    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  }

  readonly property bool solidStyle: Config.barStyle === "solid"
  property int zoneChildRevision: 0
Rectangle {
  x: 0
  y: 0
  width: content.width
  height: content.height
  radius: 0
  color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, Config.barOpacityPercent / 100)
  visible: content.fillStyle

  Rectangle {
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: 1
    x: (content.barWindow && content.barWindow.pos === "left") ? parent.width - 1 : 0
    color: Qt.rgba(1, 1, 1, 0.06)
  }
}
  Rectangle {
    readonly property bool leftHasContent: content.zoneChildRevision >= 0 && leftZone.children.length > 0
    readonly property bool centerHasContent: content.zoneChildRevision >= 0 && centerZone.children.length > 0
    readonly property bool rightHasContent: content.zoneChildRevision >= 0 && rightZoneMain.children.length > 0
    readonly property real spanStart: leftHasContent ? leftZone.y
      : (centerHasContent ? centerZone.y : rightZoneMainContainer.y)
    readonly property real spanEnd: rightHasContent
      ? (rightZoneMainContainer.y + rightZoneMainContainer.height)
      : (centerHasContent ? (centerZone.y + centerZone.height) : (leftZone.y + leftZone.height))
    x: (content.width - content.s(50)) / 2
    y: spanStart - content.s(10)
    width: content.s(50)
    height: spanEnd - spanStart + content.s(20)
    radius: content.s(Config.uiRadius)
    color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, Config.barOpacityPercent / 100)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    visible: content.solidStyle && (leftHasContent || centerHasContent || rightHasContent)
  }

  Rectangle {
    x: (content.width - content.s(50)) / 2
    y: rightZoneMainContainer.y - content.s(10)
    width: content.s(50)
    height: rightZoneMainContainer.height + content.s(20)
    radius: content.s(Config.uiRadius)
    color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, Config.barOpacityPercent / 100)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    visible: !content.solidStyle && !content.fillStyle && content.zoneChildRevision >= 0 && rightZoneMain.children.length > 0
  }

  Rectangle {
    x: (content.width - content.s(50)) / 2
    y: rightZoneTrayContainer.y - content.s(10)
    width: content.s(50)
    height: rightZoneTrayContainer.height + content.s(20)
    radius: content.s(Config.uiRadius)
    color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, Config.barOpacityPercent / 100)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    visible: content.solidStyle && TrayService.SystemTray.items.values.length > 0
  }

  readonly property real minGap: content.s(16)
  readonly property real edgeInset: Math.max(content.s(10),
    (content.height / 2) * (1 - Config.barWidthPercent / 100))

  readonly property real leftRawY: content.edgeInset
  readonly property real rightRawY: content.height - rightZoneMainContainer.height - content.s(6) - content.edgeInset

  Flow {
    id: leftZone
    x: (content.width - width) / 2
    y: content.leftRawY
    flow: Flow.TopToBottom
    spacing: content.s(4)
  }

  readonly property real rightZoneGap: content.s(25)

  readonly property real rightTopY: rightZoneTrayContainer.trayGap > 0
    ? rightZoneTrayContainer.y
    : rightZoneMainContainer.y

  Flow {
    id: centerZone
    x: (content.width - width) / 2
    y: Math.max(leftZone.y + leftZone.height + content.minGap,
        Math.min((content.height - height) / 2, content.rightTopY - content.minGap - height))
    flow: Flow.TopToBottom
    spacing: content.s(4)
  }

  Item {
    id: rightZoneMainContainer
    x: (content.width - width) / 2
    y: content.rightRawY
    implicitWidth: content.s(50)
    implicitHeight: rightZoneMain.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Flow {
      id: rightZoneMain
      x: (parent.width - width) / 2
      y: (parent.height - height) / 2
      flow: Flow.TopToBottom
      spacing: content.s(20)
    }
  }

  Item {
    id: rightZoneTrayContainer
    readonly property real trayGap: TrayService.SystemTray.items.values.length > 0 ? content.rightZoneGap : 0
    x: (content.width - width) / 2
    y: rightZoneMainContainer.y - height - trayGap
    implicitWidth: content.solidStyle ? content.s(50) : rightZoneTray.implicitWidth
    implicitHeight: rightZoneTray.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Flow {
      id: rightZoneTray
      x: (parent.width - width) / 2
      y: (parent.height - height) / 2
      flow: Flow.TopToBottom
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
    Qt.callLater(content.forceZoneVisibilityRefresh)
  }

  function forceZoneVisibilityRefresh() {
    content.zoneChildRevision = content.zoneChildRevision + 1
  }

  Component.onCompleted: {
    content.syncZones()
    Qt.callLater(content.forceZoneVisibilityRefresh)
    console.log("[sidebar] bar h:", content.height, "left:", leftZone.y, leftZone.height, "center:", centerZone.y, centerZone.height, "right:", rightZoneMainContainer.y, rightZoneMainContainer.height)
  }

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