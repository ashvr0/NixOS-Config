import "../Singletons"
import QtQuick
import QtCore
import Quickshell
import Quickshell.Services.SystemTray

Item {
  id: root
  implicitWidth: pillBg.width
  implicitHeight: pillBg.height

  property bool vertical: Config.barVertical

  Component.onCompleted: {
        Scaler.currentWidth = Screen.width
        Scaler.currentHeight = Screen.height
    }
  function s(val) { return Scaler.s(val) }

  property int cascadeIndex: 4
  property bool entered: false
  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }
  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } } }
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
  visible: pillBg.width > 0 && pillBg.height > 0

  TraySystemMenu {
    id: trayMenu
  }

  // ===== Persisted manual ordering =====
    Settings {
    id: trayOrderSettings
    location: "file://" + Quickshell.env("HOME") + "/.local/state/quickshell/tray-order.ini"
    category: "SystemTray"
    property var order: []
  }

  function itemId(it) {
    if (!it) return "";
    // Prefer a stable identifier if the service exposes one.
    if (it.id !== undefined && it.id !== null && it.id !== "") return String(it.id);
    return (it.title || "") + "|" + (it.icon || "");
  }

  // Sorted view of SystemTray.items.values according to trayOrderSettings.order.
  property var sortedItems: {
    let items = SystemTray.items.values;
    let ord = trayOrderSettings.order || [];
    let known = [];
    let unknown = [];
    for (let i = 0; i < items.length; i++) {
      let id = root.itemId(items[i]);
      let pos = ord.indexOf(id);
      if (pos === -1) unknown.push(items[i]);
      else known.push({ pos: pos, item: items[i] });
    }
    known.sort((a, b) => a.pos - b.pos);
    return known.map(k => k.item).concat(unknown);
  }

  // Call to persist a new order after a drag-drop reorder.
  function commitOrder(orderedItems) {
    let ids = orderedItems.map(it => root.itemId(it));
    trayOrderSettings.order = ids;
  }

  // Move the icon at fromIndex to beforeIndex within the current sortedItems
  // and persist the result. Handles moving an icon all the way to either end.
  function moveIcon(fromIndex, toIndex) {
    let arr = root.sortedItems.slice();
    if (fromIndex < 0 || fromIndex >= arr.length) return;
    toIndex = Math.max(0, Math.min(toIndex, arr.length - 1));
    let [moved] = arr.splice(fromIndex, 1);
    arr.splice(toIndex, 0, moved);
    root.commitOrder(arr);
  }

  Rectangle {
    id: pillBg
    height: root.vertical ? (SystemTray.items.values.length > 0 ? trayRow.implicitHeight + s(20) : 0) : s(50)
    width: root.vertical ? s(50) : (SystemTray.items.values.length > 0 ? trayRow.implicitWidth + s(20) : 0)
    radius: s(Config.uiRadius)
    color: Config.solidBarActive ? "transparent" : Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b)
    border.color: Config.solidBarActive ? "transparent" : Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    anchors.centerIn: parent
    clip: true

    Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
    Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

    Flow {
      id: trayRow
      anchors.centerIn: parent
      flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
      spacing: s(12)

      Repeater {
        model: root.sortedItems
        delegate: trayIconComponent
      }
    }

    Component {
      id: trayIconComponent

      Item {
        id: trayIcon
        width: s(20); height: s(20)

        required property var modelData
        required property int index

        property bool isHovered: trayMouse.containsMouse
        property bool isDragging: false
        // Visual offset while dragging; snaps back once dropped.
        property real dragX: 0
        property real dragY: 0

        scale: isHovered && !isDragging ? 1.18 : (isDragging ? 1.1 : 1.0)
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        z: isDragging ? 10 : 0
        opacity: isDragging ? 0.85 : 1.0

        x: dragX
        y: dragY
        Behavior on x { enabled: !trayIcon.isDragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: !trayIcon.isDragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Image {
          anchors.fill: parent
          source: trayIcon.modelData.icon || ""
          fillMode: Image.PreserveAspectFit
          sourceSize: Qt.size(s(20), s(20))
        }

        MouseArea {
          id: trayMouse
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          drag.target: undefined // manual drag handling below so we can snap to slots

          property point pressPos: Qt.point(0, 0)
          property bool dragArmed: false
          readonly property int dragThreshold: 6

          function openDropdown() {
            if (!trayIcon.modelData.menu) return;
            let pos = trayIcon.mapToGlobal(0, trayIcon.height);
            let screenObj = Quickshell.screens.find(sc => {
              return pos.x >= sc.x && pos.x <= sc.x + sc.width && pos.y >= sc.y && pos.y <= sc.y + sc.height;
            }) || Quickshell.screens[0];
            trayMenu.itemEntered(
              root.itemId(trayIcon.modelData),
              screenObj,
              pos.x - (screenObj ? screenObj.x : 0),
              pos.y - (screenObj ? screenObj.y : 0),
              false,
              root.vertical
            );
          }

          onEntered: {
            if (!trayIcon.isDragging && trayIcon.modelData.menu) openDropdown();
          }
          onExited: {
            trayMenu.itemExited();
          }

          onPressed: (mouse) => {
            pressPos = Qt.point(mouse.x, mouse.y);
            dragArmed = false;
          }

          onPositionChanged: (mouse) => {
            if (mouse.buttons & Qt.LeftButton) {
              let dx = mouse.x - pressPos.x;
              let dy = mouse.y - pressPos.y;
              if (!dragArmed && (Math.abs(dx) > dragThreshold || Math.abs(dy) > dragThreshold)) {
                dragArmed = true;
                trayIcon.isDragging = true;
                trayMenu.itemExited();
              }
              if (dragArmed) {
                let globalPos = trayIcon.mapToItem(trayRow, mouse.x, mouse.y);
                trayIcon.dragX = globalPos.x - pressPos.x;
                trayIcon.dragY = globalPos.y - pressPos.y;

                // Figure out which slot we're hovering to reorder live.
                let count = trayRow.children.length;
                let targetIndex = trayIcon.index;
                for (let i = 0; i < count; i++) {
                  let other = trayRow.children[i];
                  if (!other || other === trayIcon) continue;
                  let otherCenter = root.vertical
                    ? other.y + other.height / 2
                    : other.x + other.width / 2;
                  let myCenter = root.vertical
                    ? trayIcon.dragY + trayIcon.height / 2
                    : trayIcon.dragX + trayIcon.width / 2;
                  if (root.vertical) {
                    if (myCenter < otherCenter && trayIcon.index > i) targetIndex = Math.min(targetIndex, i);
                    if (myCenter > otherCenter && trayIcon.index < i) targetIndex = Math.max(targetIndex, i);
                  } else {
                    if (myCenter < otherCenter && trayIcon.index > i) targetIndex = Math.min(targetIndex, i);
                    if (myCenter > otherCenter && trayIcon.index < i) targetIndex = Math.max(targetIndex, i);
                  }
                }
                if (targetIndex !== trayIcon.index) {
                  root.moveIcon(trayIcon.index, targetIndex);
                }
              }
            }
          }

          onReleased: (mouse) => {
            if (dragArmed) {
              trayIcon.isDragging = false;
              trayIcon.dragX = 0;
              trayIcon.dragY = 0;
              dragArmed = false;
              return;
            }
          }

          onClicked: (mouse) => {
            if (dragArmed) { dragArmed = false; return; }
            if (mouse.button === Qt.LeftButton) {
              if (trayIcon.modelData.onlyMenu && trayIcon.modelData.menu) {
                openDropdown();
              } else if (typeof trayIcon.modelData.activate === "function") {
                trayIcon.modelData.activate()
              }
            } else if (mouse.button === Qt.MiddleButton) {
              if (typeof trayIcon.modelData.secondaryActivate === "function") {
                trayIcon.modelData.secondaryActivate()
              }
            } else if (mouse.button === Qt.RightButton) {
              if (trayIcon.modelData.menu) {
                openDropdown();
              }
            }
          }
        }
      }
    }
  }
}
