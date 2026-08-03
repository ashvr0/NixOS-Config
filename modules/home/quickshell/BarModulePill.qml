import QtQuick
import QtQuick.Layouts

Rectangle {
  id: pill
  required property string moduleId
  required property string zone
  // The Settings root Item, passed in by whoever instantiates this pill.
  // Used to report drag state (draggingModuleId/draggingFromZone) so the
  // DropAreas in Settings.qml know what's being dragged and from where.
  property var controller: null
  // The scrollable surface (mainFlick) the drop zones actually live inside.
  // Reparenting here instead of controller keeps the pill's coordinate
  // space aligned with the DropAreas even while the list is scrolled.
  property var dragSurface: null

  signal removeRequested(string moduleId)

  readonly property var iconMap: ({
    launcher: "󰣇", workspaces: "󰆝", musicplayer: "󰝚",
    systemtray: "󰵆", systemstats: "󰍛", guidebutton: "󰋖", settings: "󰒓", power: "⏻",
    keyboard: "󰌌", volume: "󰕾", network: "󰤨", bluetooth: "󰂯"
  })
  readonly property string moduleLabel: Config.barModuleLabel(pill.moduleId)
  readonly property string moduleIcon: pill.iconMap[pill.moduleId] || "󰘔"

  // Measures the label's natural (unelided) width independent of the
  // pill's own width. label.paintedWidth can't be used here: that Text
  // is anchored between icon.right and the pill's right edge, so its width is
  // derived FROM the pill's width — reading it back into contentWidth
  // (which drives implicitWidth) was a circular binding that fired every
  // frame (see "Binding loop detected for property contentWidth").
  TextMetrics {
    id: labelMetrics
    font: label.font
    text: pill.moduleLabel
  }

  property int contentWidth: s(8) + s(12) + s(3) + labelMetrics.width + s(8)
  Layout.preferredWidth: contentWidth
  Layout.preferredHeight: s(28)
  implicitWidth: contentWidth
  implicitHeight: s(28)
  radius: s(Config.uiRadius)
  color: dragArea.drag.active
    ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.22)
    : (dragArea.containsMouse ? MatugenColors.bgElevated2 : Qt.rgba(1, 1, 1, 0.05))
  border.width: dragArea.drag.active ? 1.5 : 1
  border.color: dragArea.drag.active ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.08)
  Behavior on color { ColorAnimation { duration: 120 } }
  Behavior on border.width { NumberAnimation { duration: 120 } }

  // Smoothly slide into position whenever the Layout repositions this
  // pill (e.g. a sibling pill was added/removed/reordered in the same
  // zone). Disabled while actively being dragged so it doesn't fight the
  // live drag position, and disabled on first creation so a freshly
  // dropped pill doesn't slide in from (0,0).
  Behavior on x { enabled: !dragArea.drag.active && pill.settled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  Behavior on y { enabled: !dragArea.drag.active && pill.settled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

  property bool settled: false
  Timer { interval: 0; running: true; onTriggered: pill.settled = true }

  // Gentle pop-in the first time this pill instance appears (e.g. right
  // after being dropped into a new zone, when the Repeater there spins
  // up a fresh delegate for it).
  scale: entryDone ? 1 : 0.85
  opacity: !entryDone ? 0 : (dragArea.drag.active ? 0.92 : 1)
  property bool entryDone: false
  Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
  Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  Component.onCompleted: entryDone = true

  Drag.active: dragArea.drag.active
  // Keep Drag's own position tracking in sync with the pill's actual x/y
  // every frame. DropArea.containsDrag / onEntered / onExited hit-test
  // against this, so without an explicit updatePosition() call here the
  // drag protocol lags a frame behind the manually-set x/y below, which is
  // what made drops register against the wrong zone (or none at all) and
  // made the pill appear to snap back to where it started.
  Drag.hotSpot.x: width / 2
  Drag.hotSpot.y: height / 2
  Drag.keys: ["barmodule"]

  // Local scaler so this component works standalone wherever it's used.
  Scaler { id: scaler; currentWidth: Screen.width }
  function s(val) { return scaler.s(val) }

  Text {
    id: icon
    anchors.left: parent.left
    anchors.leftMargin: s(8)
    anchors.verticalCenter: parent.verticalCenter
    text: pill.moduleIcon
    font.pixelSize: s(12)
    font.family: "JetBrainsMono Nerd Font"
    color: MatugenColors.accent
  }

  Text {
    id: label
    anchors.left: icon.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: s(3)
    horizontalAlignment: Text.AlignLeft
    text: pill.moduleLabel
    font.pixelSize: s(10)
    font.family: Config.fontFamily
    color: MatugenColors.text
  }

  // Close button removed — pills are icon + label only now. Removal from
  // a zone happens by dragging back into the unplaced tray instead.

  // While a drag is in progress this pill is reparented to the Settings
  // root so it is no longer managed by the Layout/Flow it normally lives
  // in. Layout items have their x/y driven by the layout every relayout
  // pass, which fights the drag and snaps the pill back before it can
  // ever visually reach another zone. Reparenting frees x/y for the
  // duration of the drag; originalParent restores it afterward.
  property Item originalParent: null
  property bool dropHandled: false

  // Hide (rather than let float over other tabs) if the controller's tab
  // changes while this pill is mid-drag or has been reparented to
  // dragSurface and not yet restored.
  visible: !controller || controller.currentTab === "appearance"

  MouseArea {
    id: dragArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    // drag.target must be set for drag.active to ever become true. Without
    // it, dragArea.drag.active stays false for the whole gesture: Drag.active
    // (below) never activates, DropArea.containsDrag never fires, drops
    // silently fail, and the "Behavior on x/y" (gated on !drag.active) fights
    // the manual position updates below and animates the pill back to (0,0)
    // in its original zone the instant the mouse moves. This was the actual
    // cause of the snap-back-to-left glitch.
    drag.target: pill
    drag.axis: Drag.XAndYAxis
    drag.threshold: 0

    // Offset from the pill's top-left to the point inside it where the
    // mouse first grabbed, in the pill's own local coordinates. Used to
    // keep that same point under the cursor for the whole drag instead
    // of snapping the pill's top-left to the cursor.
    property real grabOffsetX: 0
    property real grabOffsetY: 0

    onPressed: (mouse) => {
      mouse.accepted = true
      pill.originalParent = pill.parent
      pill.dropHandled = false

      // Capture the pill's on-screen position BEFORE reparenting, in the
      // target's coordinate space. Reparenting alone does not preserve
      // visual position (Item.parent change keeps local x/y, not global
      // position), so without this the pill jumps to whatever x/y it
      // happened to have from the old Layout the instant it's reparented
      // — which reads as "snapped back to the left" since Layout-managed
      // items are frequently at x:0 relative to their old parent.
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

    // Recompute the pill's position directly from the cursor on every
    // move instead of relying on drag.target's own delta tracking, which
    // drifts once dragArea (and the pill) have been reparented mid-press:
    // its deltas end up measured against the wrong coordinate space and
    // against only dragArea's own width rather than the full pill.
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

      // pill.dropHandled is set synchronously by the DropArea's own
      // onDropped handler (called from within Drag.drop() above, before
      // this point) whenever it actually applied the move to
      // barLayoutDraft/unplacedDraft. Relying on that instead of
      // Drag.drop()'s return value: that return value is the requested
      // drop action enum (e.g. Qt.MoveAction), which is truthy even when
      // no DropArea ever accepted the drop, so it can't distinguish a
      // real move from a drop into empty space. That mismatch was why
      // dragging a module to a new zone never visibly moved it — this
      // code treated every release as "moved", destroyed the floating
      // pill, but the model itself was never actually updated for drops
      // that landed outside a DropArea's accept region.
      if (pill.dropHandled) {
        pill.originalParent = null
        pill.destroy()
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
}
