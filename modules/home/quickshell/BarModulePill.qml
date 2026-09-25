import "Singletons"
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Rectangle {
  id: pill
  required property string moduleId
  required property string zone
  property var controller: null
  property var dragSurface: null

  signal removeRequested(string moduleId)

  readonly property var iconMap: ({
    launcher: "󰣇", workspaces: "󰆝", musicplayer: "󰝚",
    systemtray: "󰵆", systemstats: "󰍛", guidebutton: "󰋖", settings: "󰒓", power: "⏻",
    keyboard: "󰌌", volume: "󰕾", network: "󰤨", bluetooth: "󰂯", weather: ""
  })
  readonly property string moduleLabel: Config.barModuleLabel(pill.moduleId)
  readonly property string moduleIcon: pill.iconMap[pill.moduleId] || "󰘔"
  TextMetrics {
    id: labelMetrics
    font: label.font
    text: pill.moduleLabel
  }

  readonly property bool isFirstInGroup: pill.controller && pill.inGroup && pill.controller.isFirstInGroup && pill.controller.isFirstInGroup(pill.moduleId)
  readonly property bool isLastInGroup: pill.controller && pill.inGroup && pill.controller.isLastInGroup && pill.controller.isLastInGroup(pill.moduleId)
  readonly property real leftPad: pill.inGroup ? (pill.isFirstInGroup ? s(10) : s(4)) : s(10)
  readonly property real rightPad: pill.inGroup ? (pill.isLastInGroup ? s(10) : s(4)) : s(10)

  property int contentWidth: pill.leftPad + s(14) + s(5) + labelMetrics.width + pill.rightPad
  Layout.preferredWidth: contentWidth
  Layout.preferredHeight: s(34)
  implicitWidth: contentWidth
  implicitHeight: s(34)
  radius: pill.inGroup ? 0 : s(Config.uiRadius)
  color: pill.inGroup
    ? "transparent"
    : (dragArea.drag.active
      ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.24)
      : (dragArea.containsMouse ? MatugenColors.bgElevated2 : Qt.rgba(1, 1, 1, 0.05)))
  border.width: pill.inGroup ? 0 : (dragArea.drag.active ? 2 : (pill.isPending ? 2 : 1))
  border.color: dragArea.drag.active ? MatugenColors.accent : (pill.isPending ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.08))
  layer.enabled: dragArea.drag.active
  layer.effect: MultiEffect {
    shadowEnabled: true
    shadowColor: Qt.rgba(0, 0, 0, 0.35)
    shadowBlur: 0.6
    shadowVerticalOffset: 2
  }
  Behavior on color { ColorAnimation { duration: 120 } }
  Behavior on border.width { NumberAnimation { duration: 120 } }
  Behavior on x { enabled: !dragArea.drag.active && pill.settled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  Behavior on y { enabled: !dragArea.drag.active && pill.settled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  property bool settled: false
  Timer { interval: 0; running: true; onTriggered: pill.settled = true }
  scale: entryDone ? 1 : 0.85
  opacity: !entryDone ? 0 : (dragArea.drag.active ? 0.92 : 1)
  property bool entryDone: false
  Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
  Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  Component.onCompleted: {
    entryDone = true
    Scaler.currentWidth = Screen.width
  }

  Drag.active: dragArea.drag.active
  Drag.hotSpot.x: width / 2
  Drag.hotSpot.y: height / 2
  Drag.keys: ["barmodule"]
  function s(val) { return Scaler.s(val) }

  Text {
    id: icon
    anchors.left: parent.left
    anchors.leftMargin: pill.leftPad
    anchors.verticalCenter: parent.verticalCenter
    text: pill.moduleIcon
    font.pixelSize: s(15)
    font.family: "JetBrainsMono Nerd Font"
    color: MatugenColors.accent
  }

  Text {
    id: label
    anchors.left: icon.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: s(5)
    horizontalAlignment: Text.AlignLeft
    text: pill.moduleLabel
    font.pixelSize: s(13)
    font.family: Config.fontFamily
    color: MatugenColors.text
  }
  property Item originalParent: null
  property bool dropHandled: false
  visible: !controller || controller.currentTab === "bar"
  readonly property bool isPending: pill.controller && pill.controller.pendingGroupId === pill.moduleId
  readonly property bool inGroup: pill.controller && pill.controller.groupIdFor(pill.moduleId) !== "" && !dragArea.drag.active

  MouseArea {
    id: dragArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    drag.target: pill
    drag.axis: Drag.XAndYAxis
    drag.threshold: 0
    property real grabOffsetX: 0
    property real grabOffsetY: 0

    onPressed: (mouse) => {
      mouse.accepted = true
      pill.originalParent = pill.parent
      pill.dropHandled = false
      if (pill.controller) pill.controller.clearPendingGroup()
      let target = pill.dragSurface || pill.controller
      dragArea.grabOffsetX = mouse.x
      dragArea.grabOffsetY = mouse.y

      if (target) {
        let pressGlobal = dragArea.mapToItem(target, mouse.x, mouse.y)
        let newX = pressGlobal.x - dragArea.grabOffsetX
        let newY = pressGlobal.y - dragArea.grabOffsetY
        pill.parent = target
        pill.x = newX
        pill.y = newY
      }
      pill.z = 1000

      if (pill.controller) {
        pill.controller.draggingModuleId = pill.moduleId
        pill.controller.draggingFromZone = pill.zone
        pill.controller.activeDragPill = pill
      }
    }
    onPositionChanged: (mouse) => {
      if (!pressed) return
      let target = pill.dragSurface || pill.controller
      if (!target) return
      let current = dragArea.mapToItem(target, mouse.x, mouse.y)
      pill.x = current.x - dragArea.grabOffsetX
      pill.y = current.y - dragArea.grabOffsetY
    }

    onReleased: (mouse) => {
      mouse.accepted = true
      pill.Drag.drop()

      if (pill.controller) {
        pill.controller.draggingModuleId = ""
        pill.controller.draggingFromZone = ""
        pill.controller.previewZone = ""
        pill.controller.previewIdx = -1
        pill.controller.activeDragPill = null
      }
      pill.z = 0
      if (pill.dropHandled) {
        pill.originalParent = null
        return
      }

      if (pill.originalParent) {
        pill.parent = pill.originalParent
        pill.originalParent = null
      }
      pill.x = 0
      pill.y = 0
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.RightButton
    propagateComposedEvents: true
    onClicked: (mouse) => {
      if (mouse.button !== Qt.RightButton) return
      if (!pill.controller) return
      mouse.accepted = true
      let alreadyGrouped = pill.controller.groupIdFor(pill.moduleId) !== ""
      if (alreadyGrouped && pill.controller.pendingGroupId === "") {
        pill.controller.ungroupModule(pill.moduleId)
      } else {
        pill.controller.requestGroupClick(pill.moduleId)
      }
    }
  }
}
