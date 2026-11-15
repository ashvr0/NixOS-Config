// Lock screen editor. Fullscreen overlay modeled on the desktop widget editor:
// dot grid, smart guides, free move and resize, a bottom tray to add elements,
// and a control strip under the selected one. Changes save as you go.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../Singletons"
import ".."

Scope {
  id: scope

  property string wallpaperPath: ""
  signal closed()

  // which layer is being edited: "idle" or "login"
  property string layer: "login"
  property real guideX: -1
  property real guideY: -1
  property string profilePicturePath: ""

  Process {
    command: ["cat", Quickshell.env("HOME") + "/.local/state/quickshell/settings.json"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const d = JSON.parse(this.text)
          if (d.profilePicturePath) scope.profilePicturePath = d.profilePicturePath
        } catch (e) {}
      }
    }
  }

  // Snap a dragged frame to the screen center and to the edges and centers of other frames.
  function calculateSnap(dragged, rawX, rawY) {
    const threshold = 8
    const res = { x: rawX, y: rawY, guideX: -1, guideY: -1 }
    let bestDx = threshold
    let bestDy = threshold

    const dX = [rawX, rawX + dragged.width / 2, rawX + dragged.width]
    const dY = [rawY, rawY + dragged.height / 2, rawY + dragged.height]
    const cx = LockLayout.refW / 2
    const cy = LockLayout.refH / 2

    for (let j = 0; j < 3; j++) {
      const diff = Math.abs(dX[j] - cx)
      if (diff < bestDx) { bestDx = diff; res.x = rawX + (cx - dX[j]); res.guideX = cx }
    }
    for (let j = 0; j < 3; j++) {
      const diff = Math.abs(dY[j] - cy)
      if (diff < bestDy) { bestDy = diff; res.y = rawY + (cy - dY[j]); res.guideY = cy }
    }

    for (let i = 0; i < frames.count; i++) {
      const o = frames.itemAt(i)
      if (!o || o === dragged || !o.visible) continue
      const oX = [o.x, o.x + o.width / 2, o.x + o.width]
      const oY = [o.y, o.y + o.height / 2, o.y + o.height]
      for (let j = 0; j < 3; j++) for (let k = 0; k < 3; k++) {
        const diff = Math.abs(dX[j] - oX[k])
        if (diff < bestDx) { bestDx = diff; res.x = rawX + (oX[k] - dX[j]); res.guideX = oX[k] }
      }
      for (let j = 0; j < 3; j++) for (let k = 0; k < 3; k++) {
        const diff = Math.abs(dY[j] - oY[k])
        if (diff < bestDy) { bestDy = diff; res.y = rawY + (oY[k] - dY[j]); res.guideY = oY[k] }
      }
    }

    res.x = Math.max(0, Math.min(LockLayout.refW - dragged.width, res.x))
    res.y = Math.max(0, Math.min(LockLayout.refH - dragged.height, res.y))
    return res
  }

  PanelWindow {
    id: win
    visible: true
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: "qs-lock-editor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property real u: width > 0 && height > 0
      ? Math.min(width / LockLayout.refW, height / LockLayout.refH) : 1

    Item {
      id: root
      anchors.fill: parent
      focus: true
      Component.onCompleted: root.forceActiveFocus()

      Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Escape) scope.closed()
        else if (e.key === Qt.Key_Delete && LockLayout.selectedId !== "") LockLayout.remove(LockLayout.selectedId)
        e.accepted = true
      }

      // ---------- backdrop ----------

      Rectangle { anchors.fill: parent; color: "#0b0c10" }

      Image {
        anchors.fill: parent
        source: scope.wallpaperPath !== "" ? (scope.wallpaperPath.indexOf("file://") === 0 ? scope.wallpaperPath : "file://" + scope.wallpaperPath.split("/").map(encodeURIComponent).join("/")) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
      }

      Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: scope.layer === "login" ? 0.45 : 0.25
        Behavior on opacity { NumberAnimation { duration: 250 } }
      }

      MouseArea {
        anchors.fill: parent
        onClicked: { LockLayout.selectedId = "" }
      }

      // ---------- 1920 x 1080 canvas, scaled to the screen ----------

      Item {
        id: canvas
        width: LockLayout.refW
        height: LockLayout.refH
        anchors.centerIn: parent
        scale: win.u

        // screen outline + dot grid
        Canvas {
          id: dotGrid
          anchors.fill: parent
          opacity: LockLayout.snapToGrid ? 0.6 : 0.35
          Behavior on opacity { NumberAnimation { duration: 200 } }

          onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = "rgba(255,255,255,0.22)"
            ctx.lineWidth = 2
            ctx.strokeRect(1, 1, width - 2, height - 2)
            ctx.fillStyle = MatugenColors.textDim
            const sp = LockLayout.gridSize * 2
            const r = LockLayout.snapToGrid ? 1.8 : 1.4
            for (let x = sp; x < width; x += sp) {
              for (let y = sp; y < height; y += sp) {
                ctx.beginPath()
                ctx.arc(x, y, r, 0, Math.PI * 2)
                ctx.fill()
              }
            }
          }
          Component.onCompleted: requestPaint()
          Connections {
            target: LockLayout
            function onSnapToGridChanged() { dotGrid.requestPaint() }
          }
        }

        Repeater {
          id: frames
          model: LockLayout.model
          delegate: LockEditFrame {
            editor: scope
            profilePicturePath: scope.profilePicturePath
          }
        }

        // smart guides
        Rectangle {
          x: scope.guideX; y: 0
          width: 1 / win.u; height: parent.height
          color: MatugenColors.accent
          visible: scope.guideX >= 0
          z: 5000
        }
        Rectangle {
          x: 0; y: scope.guideY
          width: parent.width; height: 1 / win.u
          color: MatugenColors.accent
          visible: scope.guideY >= 0
          z: 5000
        }
      }

      // ---------- layer switch (top) ----------

      Rectangle {
        id: layerBar
        anchors.top: parent.top
        anchors.topMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        width: layerRow.implicitWidth + 16
        height: 44
        radius: 14
        color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.94)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)
        z: 9000

        MouseArea { anchors.fill: parent }

        Row {
          id: layerRow
          anchors.centerIn: parent
          spacing: 6

          Repeater {
            model: [
              { id: "idle", label: "Idle screen", icon: "\uf186" },
              { id: "login", label: "Login screen", icon: "\uf023" }
            ]
            delegate: Rectangle {
              required property var modelData
              readonly property bool on: scope.layer === modelData.id
              width: lbl.implicitWidth + 36
              height: 32
              radius: 10
              color: on ? MatugenColors.accentSoft : (lMa.containsMouse ? MatugenColors.bgElevated2 : "transparent")
              border.width: on ? 1 : 0
              border.color: MatugenColors.accent

              Row {
                anchors.centerIn: parent
                spacing: 7
                Text {
                  text: modelData.icon
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 13
                  color: on ? MatugenColors.accent : MatugenColors.textDim
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  id: lbl
                  text: modelData.label
                  font.family: Config.fontFamily
                  font.pixelSize: 12
                  font.weight: Font.Bold
                  color: on ? MatugenColors.accent : MatugenColors.text
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
              MouseArea {
                id: lMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { scope.layer = modelData.id; LockLayout.selectedId = "" }
              }
            }
          }
        }
      }

      Text {
        anchors.top: layerBar.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        text: scope.layer === "idle"
        font.family: Config.fontFamily
        font.pixelSize: 11
        color: Qt.rgba(1, 1, 1, 0.6)
        z: 9000
      }

      // ---------- bottom tray ----------

      component TrayTile: Column {
        id: tile
        property string icon: ""
        property string label: ""
        property bool active: false
        property bool dimmed: false
        signal clicked()
        spacing: 4

        Rectangle {
          width: 56; height: 56; radius: 14
          anchors.horizontalCenter: parent.horizontalCenter
          opacity: tile.dimmed ? 0.35 : 1
          color: tile.active
            ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.28)
            : (tMa.containsMouse && !tile.dimmed ? MatugenColors.bgElevated2 : MatugenColors.bgElevated)
          border.width: tile.active ? 1 : 0
          border.color: MatugenColors.accent
          Behavior on color { ColorAnimation { duration: 120 } }

          Text {
            anchors.centerIn: parent
            text: tile.icon
            font.pixelSize: 20
            font.family: "JetBrainsMono Nerd Font"
            color: tile.active ? MatugenColors.accent : (tile.dimmed ? MatugenColors.textDim : MatugenColors.accent)
          }
          MouseArea {
            id: tMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: !tile.dimmed
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
          }
        }
        Text {
          text: tile.label
          font.pixelSize: 9
          font.weight: Font.Bold
          font.family: Config.fontFamily
          color: MatugenColors.textDim
          anchors.horizontalCenter: parent.horizontalCenter
        }
      }

      Rectangle {
        id: tray
        z: 9000
        readonly property real fit: Math.min(1, (root.width - 40) / width)
        width: trayRow.implicitWidth + 28
        height: 96
        radius: 18
        color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.94)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        scale: fit
        transformOrigin: Item.Bottom

        MouseArea { anchors.fill: parent }

        Row {
          id: trayRow
          anchors.centerIn: parent
          spacing: 14

          // lock elements
          Repeater {
            model: LockLayout.group("lock")
            delegate: TrayTile {
              required property var modelData
              icon: modelData.icon
              label: modelData.label
              dimmed: modelData.unique === true && LockLayout.model.count >= 0 && LockLayout.has(modelData.type)
              onClicked: LockLayout.add(modelData.type, scope.layer, LockLayout.refW / 2, LockLayout.refH / 2)
            }
          }

          Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 56; color: Qt.rgba(1, 1, 1, 0.1) }

          // widgets
          Repeater {
            model: LockLayout.group("widget")
            delegate: TrayTile {
              required property var modelData
              icon: modelData.icon
              label: modelData.label
              onClicked: LockLayout.add(modelData.type, scope.layer, LockLayout.refW / 2, LockLayout.refH / 2)
            }
          }

          Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 56; color: Qt.rgba(1, 1, 1, 0.1) }

          TrayTile {
            icon: "\uf0b2"
            label: "Snap"
            active: LockLayout.snapToGrid
            onClicked: LockLayout.snapToGrid = !LockLayout.snapToGrid
          }
          TrayTile {
            icon: "\uf021"
            label: "Reset"
            onClicked: LockLayout.resetLayer(scope.layer)
          }

          Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 56; color: Qt.rgba(1, 1, 1, 0.1) }

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 80; height: 40; radius: 20
            color: doneMa.containsMouse ? Qt.lighter(MatugenColors.accent, 1.1) : MatugenColors.accent
            Text {
              anchors.centerIn: parent
              text: "Done"
              font.pixelSize: 12
              font.weight: Font.Bold
              font.family: Config.fontFamily
              color: MatugenColors.accentText
            }
            MouseArea {
              id: doneMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: scope.closed()
            }
          }
        }
      }
    }
  }
}
