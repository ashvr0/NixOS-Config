import QtQuick
import QtQuick.Layouts
import "../.."
import "../../Singletons"
import "../../Components"
import "../../Bar"

ColumnLayout {
  id: root

  required property var s
  required property var matches
  required property string fontFamily

  // Bar position
  required property var barPositionChoices
  required property var setBarPosition

  // Bar style / width / transparency / auto-hide use Config directly
  required property bool autoHideBar
  required property var toggleAutoHideBar

  // Bar layout (drag & drop)
  required property var barLayoutDraft
  required property var unplacedDraft
  required property var moveModuleToZone
  required property var commitBarLayout
  required property var resetBarLayout
  required property string draggingModuleId
  required property string previewZone
  required property int previewIdx
  required property var activeDragPill
  required property var controller
  required property var dragSurfaceItem

  // Groups same-zone-adjacent modules that share a group id into clusters,
  // e.g. ["a","b","c"] with b+c grouped -> [["a"], ["b","c"]].
  function clusterModelFor(zone) {
    let ids = root.barLayoutDraft[zone]
    let clusters = []
    let i = 0
    while (i < ids.length) {
      let id = ids[i]
      let gId = root.controller.groupIdFor(id)
      if (gId === "") {
        clusters.push([id])
        i++
        continue
      }
      let cluster = [id]
      let j = i + 1
      while (j < ids.length && root.controller.groupIdFor(ids[j]) === gId) {
        cluster.push(ids[j])
        j++
      }
      clusters.push(cluster)
      i = j
    }
    return clusters
  }

  Layout.fillWidth: true
  spacing: s(14)
  focus: true


  Rectangle {
    id: barPosRow
    visible: root.matches("Bar position")
    Layout.fillWidth: true
    Layout.preferredHeight: s(56)
    radius: s(Config.uiRadius)
    color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)
    z: 10

    RowLayout {
      anchors.fill: parent
      anchors.margins: s(10)
      spacing: s(10)

      Text { 
        text: "󱂬"
        font.pixelSize: s(22)
        font.family: "JetBrainsMono Nerd Font"
        color: MatugenColors.accent
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: s(2)

        Text { 
          text: "Bar position"
          font.pixelSize: s(13)
          font.weight: Font.Bold
          font.family: "JetBrainsMono Nerd Font"
          color: MatugenColors.text 
        }
        Text { 
          text: "Which edge of the screen the bar is docked to"
          font.pixelSize: s(11)
          font.family: "JetBrainsMono Nerd Font"
          color: MatugenColors.textDim 
          wrapMode: Text.WordWrap
          Layout.fillWidth: true 
          }
      }

      Dropdown {
        s: root.s
        Layout.alignment: Qt.AlignVCenter
        boxWidth: 130
        options: root.barPositionChoices
        labelKey: "label"
        currentIndex: Math.max(0, root.barPositionChoices.findIndex(c => c.id === (Config.barPosition || "top")))
        onPicked: (i) => root.setBarPosition(root.barPositionChoices[i].id)
      }
    }
  }

  SettingRow {
    visible: root.matches("Bar style")
    icon: "󰕮"
    title: "Bar style"
    description: "Separated, solid, or a filled bar look"

    control: Component {
      SegmentedControl {
        s: root.s
        choices: [ { id: "modular", label: "Separated" }, { id: "solid", label: "Solid" }, { id: "fill", label: "Fill" } ]
        current: Config.barStyle
        onPicked: (id) => Config.barStyle = id
      }
    }
  }

  SettingRow {
    visible: root.matches("Border radius")
    icon: "󰛐"
    title: "Border radius"
    description: "Corner rounding applied across the UI"

    control: Component {
      Stepper {
        s: root.s
        from: 0
        to: 25
        value: Config.uiRadius
        suffix: "px"
        editable: true
        liveEdit: true
        onMoved: (v) => root.controller.setUiRadius(v)
      }
    }
  }

  SettingRow {
    visible: root.matches("Bar width")
    icon: "󰡍"
    title: "Bar width"
    description: "Percentage of the screen width the bar occupies"

    control: Component {
      ValueSlider {
        s: root.s
        from: 0
        to: 100
        value: Config.barWidthPercent
        suffix: "%"
        labelWidth: 40
        onMoved: (v) => Config.barWidthPercent = v
      }
    }
  }

  SettingRow {
    visible: root.matches("Bar transparency")
    icon: "󰈈"
    title: "Bar transparency"
    description: "Opacity of the bar background"

    control: Component {
      ValueSlider {
        s: root.s
        from: 0
        to: 100
        value: Config.barOpacityPercent
        suffix: "%"
        labelWidth: 40
        onMoved: (v) => Config.barOpacityPercent = v
      }
    }
  }

  SettingRow {
    visible: root.matches("Auto hide bar")
    icon: "󰈈"
    title: "Auto hide bar"
    description: "Automatically hide the bar when not in use"

    control: Component {
      ToggleSwitch {
        s: root.s
        checked: root.autoHideBar
        onToggled: root.toggleAutoHideBar()
      }
    }
  }
  SettingRow {
    visible: root.autoHideBar && root.matches("Auto hide delay")
    icon: "󰔟"
    title: "Auto hide delay"
    description: "How long to wait before the bar hides"

    control: Component {
      ValueSlider {
        s: root.s
        from: 250
        to: 10000
        step: 50
        value: Config.autoHideDelayMs
        suffix: "ms"
        labelWidth: 60
        onMoved: (v) => Config.autoHideDelayMs = v
      }
    }
  }

  Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

  RowLayout {
    visible: root.matches("Bar layout")
    Layout.fillWidth: true
    Text { text: "BAR LAYOUT"; font.pixelSize: s(13); font.weight: Font.Bold; font.family: root.fontFamily; color: MatugenColors.border; Layout.fillWidth: true }
    Text {
      text: "Reset"
      font.pixelSize: s(12)
      font.family: root.fontFamily
      color: resetBarMa.containsMouse ? MatugenColors.accent : MatugenColors.textDim
      MouseArea { id: resetBarMa; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.resetBarLayout() }
    }
  }

  ColumnLayout {
    visible: root.matches("Bar layout")
    Layout.fillWidth: true
    spacing: s(10)

    Text { text: "Drag modules between zones. Changes apply immediately to the bar."; font.pixelSize: s(13); font.family: root.fontFamily; color: MatugenColors.textDim; wrapMode: Text.WordWrap; Layout.fillWidth: true }
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: Math.max(s(72), availableFlow.implicitHeight + s(20))
      radius: s(Config.uiRadius)
      color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.4)
      border.width: 1
      border.color: availableDrop.containsDrag ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.06)
      Behavior on border.color { ColorAnimation { duration: 120 } }

      MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: { root.forceActiveFocus(); root.controller.clearPendingGroup() }
      }

      DropArea {
        id: availableDrop
        anchors.fill: parent
        keys: ["barmodule"]
        onDropped: {
          let id = root.draggingModuleId
          if (id === "") return
          if (root.activeDragPill) root.activeDragPill.dropHandled = true
          root.controller.previewZone = ""
          root.controller.previewIdx = -1
          Qt.callLater(function() {
            root.moveModuleToZone(id, "unplaced")
            root.commitBarLayout()
          })
        }
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: s(10)
        spacing: s(6)

        Text { text: "AVAILABLE"; font.pixelSize: s(11); font.weight: Font.Bold; font.family: root.fontFamily; color: MatugenColors.textDim }

        Flow {
          id: availableFlow
          Layout.fillWidth: true
          spacing: s(6)

          move: Transition {
            NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutCubic }
          }
          add: Transition {
            NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutCubic }
          }

          Text {
            visible: root.unplacedDraft.length === 0
            text: "All modules placed"
            font.pixelSize: s(12)
            font.family: root.fontFamily
            color: MatugenColors.textDim
          }

          Repeater {
            model: root.unplacedDraft
            delegate: BarModulePill {
              required property string modelData
              moduleId: modelData
              zone: "unplaced"
              controller: root.controller
              dragSurface: root.dragSurfaceItem
              onRemoveRequested: (id) => { root.moveModuleToZone(id, "unplaced"); root.commitBarLayout() }
            }
          }
        }
      }
    }

    // Left / Center / Right zones.
    RowLayout {
      id: zonesRow
      Layout.fillWidth: true
      spacing: s(10)

      Repeater {
        model: [
          { zone: "left", label: "LEFT" },
          { zone: "center", label: "CENTER" },
          { zone: "right", label: "RIGHT" }
        ]
        delegate: Rectangle {
          id: outerZone
          required property var modelData
          property string zone: modelData.zone
          property string label: modelData.label

          // Drop indicator position, in outerZone coordinates.
          property real indX: 0
          property real indY: 0
          property real indH: s(28)

          // Same width for every zone (equal preferred width + fillWidth),
          // and fillHeight makes the shorter zones stretch to the tallest one.
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredWidth: 1
          Layout.minimumWidth: 0
          Layout.preferredHeight: Math.max(s(120), zoneCol.implicitHeight + s(20))
          radius: s(Config.uiRadius)
          color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)
          border.width: 1
          border.color: zoneDrop.containsDrag ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.06)
          Behavior on border.color { ColorAnimation { duration: 120 } }

          // Click on empty zone space clears a pending group. It sits under the
          // pills, so it never competes with them for the click.
          MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: { root.forceActiveFocus(); root.controller.clearPendingGroup() }
          }
          // Real pill items of this zone in order, skipping the dragged one.
          function pillItems() {
            let out = []
            for (let ci = 0; ci < clusterRepeater.count; ci++) {
              let slot = clusterRepeater.itemAt(ci)

              if (!slot) continue
              let rep = slot.memberRepeater
              for (let pi = 0; pi < rep.count; pi++) {
                let ps = rep.itemAt(pi)
                if (!ps || ps.modelData === root.draggingModuleId) continue
                out.push(ps.pill)
              }
            }
            return out
          }

          // px, py are in pillFlow coordinates.
          function insertIdxAt(px, py) {
            let pills = outerZone.pillItems()
            let count = 0
            for (let i = 0; i < pills.length; i++) {
              let p = pills[i]
              let pos = p.mapToItem(pillFlow, 0, 0)
              let cy = pos.y + p.height / 2
              let sameRow = Math.abs(cy - py) < p.height / 2 + pillFlow.spacing / 2
              let before = sameRow ? (px >= pos.x + p.width / 2) : (py >= cy)
              if (before) count++
            }
            return count
          }

          function updateIndicator(idx) {
            let pills = outerZone.pillItems()
            if (pills.length === 0) {
              let o = pillFlow.mapToItem(outerZone, 0, 0)
              outerZone.indX = o.x
              outerZone.indY = o.y
              outerZone.indH = s(28)
            } else if (idx < pills.length) {
              let p = pills[idx]
              let o = p.mapToItem(outerZone, 0, 0)
              outerZone.indX = o.x - s(5)
              outerZone.indY = o.y
              outerZone.indH = p.height
            } else {
              let p = pills[pills.length - 1]
              let o = p.mapToItem(outerZone, 0, 0)
              outerZone.indX = o.x + p.width + s(2)
              outerZone.indY = o.y
              outerZone.indH = p.height
            }
          }

          DropArea {
            id: zoneDrop
            anchors.fill: parent
            keys: ["barmodule"]
            onEntered: (drag) => {
              if (root.draggingModuleId === "") return
              let local = zoneDrop.mapToItem(pillFlow, drag.x, drag.y)
              let idx = outerZone.insertIdxAt(local.x, local.y)
              root.controller.previewZone = outerZone.zone
              root.controller.previewIdx = idx
              outerZone.updateIndicator(idx)
            }
            onPositionChanged: (drag) => {
              if (root.draggingModuleId === "") return
              let local = zoneDrop.mapToItem(pillFlow, drag.x, drag.y)
              let idx = outerZone.insertIdxAt(local.x, local.y)
              root.controller.previewZone = outerZone.zone
              root.controller.previewIdx = idx
              outerZone.updateIndicator(idx)
            }
            onExited: {
              if (root.previewZone === outerZone.zone) {
                root.controller.previewZone = ""
                root.controller.previewIdx = -1
              }
            }
            onDropped: (drag) => {
              let id = root.draggingModuleId
              if (id === "") return
              let local = zoneDrop.mapToItem(pillFlow, drag.x, drag.y)
              let insertIdx = outerZone.insertIdxAt(local.x, local.y)
              let targetZone = outerZone.zone
              if (root.activeDragPill) root.activeDragPill.dropHandled = true
              root.controller.previewZone = ""
              root.controller.previewIdx = -1
              // Move after this event finishes. Changing the draft rebuilds the
              // pills, and destroying the pill that is still being dragged
              // is what caused the glitching.
              Qt.callLater(function() {
                root.moveModuleToZone(id, targetZone, insertIdx)
                root.commitBarLayout()
              })
            }
          }

          ColumnLayout {
            id: zoneCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: s(10)
            spacing: s(6)

            Text { text: outerZone.label; font.pixelSize: s(11); font.weight: Font.Bold; font.family: root.fontFamily; color: MatugenColors.textDim }

            Text {
              visible: root.barLayoutDraft[outerZone.zone].length === 0
              text: "Drop here"
              font.pixelSize: s(12)
              font.family: root.fontFamily
              color: MatugenColors.textDim
            }
            Flow {
              id: pillFlow
              Layout.fillWidth: true
              spacing: s(6)
              move: Transition { NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutCubic } }

              Repeater {
                id: clusterRepeater
                model: (Config.barGroups, root.clusterModelFor(outerZone.zone))
                delegate: Item {
                  id: clusterSlot
                  required property var modelData
                  required property int index
                  readonly property var memberIds: clusterSlot.modelData
                  readonly property bool isGroup: clusterSlot.memberIds.length > 1
                  readonly property string groupColor: (clusterSlot.isGroup && clusterSlot.memberIds.length > 0) ? (Config.barGroups, root.controller.groupColorFor(clusterSlot.memberIds[0])) : ""
                  readonly property color groupColorObj: clusterSlot.groupColor ? Qt.color(clusterSlot.groupColor) : "transparent"
                  readonly property var memberRepeater: memberRepeater
                  visible: clusterSlot.isGroup || clusterSlot.memberIds[0] !== root.draggingModuleId

                  implicitWidth: clusterRow.implicitWidth + (clusterSlot.isGroup ? s(8) : 0)
                  implicitHeight: clusterRow.implicitHeight + (clusterSlot.isGroup ? s(8) : 0)

                  Rectangle {
                    anchors.fill: parent
                    visible: clusterSlot.isGroup
                    radius: s(Config.uiRadius)
                    color: clusterSlot.isGroup ? Qt.rgba(clusterSlot.groupColorObj.r, clusterSlot.groupColorObj.g, clusterSlot.groupColorObj.b, 0.16) : "transparent"
                    border.width: 1
                    border.color: clusterSlot.isGroup ? Qt.rgba(clusterSlot.groupColorObj.r, clusterSlot.groupColorObj.g, clusterSlot.groupColorObj.b, 0.55) : "transparent"
                  }

                  RowLayout {
                    id: clusterRow
                    anchors.centerIn: parent
                    spacing: 0

                    Repeater {
                      id: memberRepeater
                      model: clusterSlot.memberIds
                      delegate: RowLayout {
                        id: pillSlot
                        required property string modelData
                        required property int index
                        readonly property Item pill: realPill
                        spacing: 0

                        Rectangle {
                          // Thin divider between grouped members (not before the first one)
                          visible: clusterSlot.isGroup && pillSlot.index > 0
                          Layout.preferredWidth: visible ? 1 : 0
                          Layout.preferredHeight: realPill.implicitHeight - s(10)
                          Layout.alignment: Qt.AlignVCenter
                          color: Qt.rgba(clusterSlot.groupColorObj.r, clusterSlot.groupColorObj.g, clusterSlot.groupColorObj.b, 0.5)
                        }

                        BarModulePill {
                          id: realPill
                          moduleId: pillSlot.modelData
                          zone: outerZone.zone
                          controller: root.controller
                          dragSurface: root.dragSurfaceItem
                          onRemoveRequested: (id) => { root.moveModuleToZone(id, "unplaced"); root.commitBarLayout() }
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          // Insertion marker. It floats above the layout, so nothing shifts
          // while you drag and the drop position stays stable.
          Rectangle {
            visible: root.previewZone === outerZone.zone && root.draggingModuleId !== ""
            x: outerZone.indX
            y: outerZone.indY
            width: s(3)
            height: outerZone.indH
            radius: width / 2
            color: MatugenColors.accent
            z: 50
            Behavior on x { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
          }
        }
      }
    }
  }
}
