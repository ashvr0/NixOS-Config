// One element inside the lock editor: drag to move, 8 handles to resize, and a control strip
// (size, ratio, opacity, aspect lock, reset, delete, show text, variant) under the selected element.
import QtQuick
import "../Singletons"
import ".."

Item {
  id: frame

  required property int index
  required property string uid
  required property string lyr
  required property string kind
  required property real ix
  required property real iy
  required property real iw
  required property real ih
  required property real iop
  required property string variant
  required property bool showText

  property var editor: null
  property string profilePicturePath: ""

  property bool interacting: false
  property real px: 0
  property real py: 0
  property real pw: 0
  property real ph: 0
  property bool lockAspect: false
  property bool variantOpen: false

  readonly property bool selected: LockLayout.selectedId === frame.uid
  readonly property var def: LockLayout.def(frame.kind)
  readonly property real minW: def ? def.minW : 40
  readonly property real minH: def ? def.minH : 24
  readonly property real maxW: def ? def.maxW : 1920
  readonly property real maxH: def ? def.maxH : 1080
  readonly property bool hasVariants: def && def.variants !== undefined && def.variants.length > 1

  visible: frame.editor ? frame.lyr === frame.editor.layer : true
  x: frame.interacting ? frame.px : frame.ix
  y: frame.interacting ? frame.py : frame.iy
  width: frame.interacting ? frame.pw : frame.iw
  height: frame.interacting ? frame.ph : frame.ih
  z: frame.selected ? 1000 : frame.index

  function commit(nx, ny, nw, nh) {
    LockLayout.update(frame.uid, {
      ix: Math.round(nx), iy: Math.round(ny), iw: Math.round(nw), ih: Math.round(nh)
    })
    frame.interacting = false
  }

  function clampW(v) { return Math.min(frame.maxW, Math.max(frame.minW, v)) }
  function clampH(v) { return Math.min(frame.maxH, Math.max(frame.minH, v)) }

  function gcd(a, b) { return b === 0 ? a : gcd(b, a % b) }

  // ---------- content ----------

  LockElementFace {
    anchors.fill: parent
    kind: frame.kind
    variant: frame.variant
    showText: frame.showText
    profilePicturePath: frame.profilePicturePath
    opacity: frame.iop
  }

  // ---------- chrome: border, move, resize ----------

  Rectangle {
    id: chrome
    anchors.fill: parent
    anchors.margins: -4
    radius: 10
    color: "transparent"
    border.width: frame.selected ? 2 : 1
    border.color: frame.selected ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.25)

    MouseArea {
      id: dragMa
      anchors.fill: parent
      cursorShape: Qt.SizeAllCursor

      property real mx0: 0
      property real my0: 0
      property real sx: 0
      property real sy: 0

      onPressed: (m) => {
        LockLayout.selectedId = frame.uid
        frame.variantOpen = false
        const p = dragMa.mapToItem(frame.parent, m.x, m.y)
        mx0 = p.x; my0 = p.y; sx = frame.x; sy = frame.y
      }

      onPositionChanged: (m) => {
        if (!pressed) return
        const p = dragMa.mapToItem(frame.parent, m.x, m.y)
        if (!frame.interacting) {
          frame.pw = frame.width; frame.ph = frame.height
          frame.px = frame.x; frame.py = frame.y
          frame.interacting = true
        }
        let nx = sx + p.x - mx0
        let ny = sy + p.y - my0

        if (LockLayout.snapToGrid) {
          nx = Math.round(nx / LockLayout.gridSize) * LockLayout.gridSize
          ny = Math.round(ny / LockLayout.gridSize) * LockLayout.gridSize
          nx = Math.max(0, Math.min(LockLayout.refW - frame.width, nx))
          ny = Math.max(0, Math.min(LockLayout.refH - frame.height, ny))
        } else if (frame.editor) {
          const snap = frame.editor.calculateSnap(frame, nx, ny)
          nx = snap.x; ny = snap.y
          frame.editor.guideX = snap.guideX
          frame.editor.guideY = snap.guideY
        }
        frame.px = nx
        frame.py = ny
      }

      onReleased: {
        if (frame.interacting) frame.commit(frame.px, frame.py, frame.width, frame.height)
        if (frame.editor) { frame.editor.guideX = -1; frame.editor.guideY = -1 }
      }
    }

    // ax/ay: -1 = left/top edge, 0 = middle, 1 = right/bottom edge
    Repeater {
      model: frame.selected ? [
        { ax: -1, ay: -1 }, { ax: 0, ay: -1 }, { ax: 1, ay: -1 },
        { ax: -1, ay: 0 },                      { ax: 1, ay: 0 },
        { ax: -1, ay: 1 },  { ax: 0, ay: 1 },  { ax: 1, ay: 1 }
      ] : []

      delegate: MouseArea {
        id: handle
        required property var modelData
        readonly property int ax: modelData.ax
        readonly property int ay: modelData.ay
        readonly property real hs: 14

        width: ax === 0 ? chrome.width - hs : hs
        height: ay === 0 ? chrome.height - hs : hs
        x: ax === -1 ? -hs / 2 : (ax === 0 ? hs / 2 : chrome.width - hs / 2)
        y: ay === -1 ? -hs / 2 : (ay === 0 ? hs / 2 : chrome.height - hs / 2)
        z: 10
        cursorShape: {
          if (ax === 0) return Qt.SizeVerCursor
          if (ay === 0) return Qt.SizeHorCursor
          return (ax === ay) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
        }

        property real sx: 0
        property real sy: 0
        property real sw: 0
        property real sh: 0
        property real mx0: 0
        property real my0: 0

        // small visible knob on corners
        Rectangle {
          visible: handle.ax !== 0 && handle.ay !== 0
          anchors.centerIn: parent
          width: 10; height: 10; radius: 3
          color: MatugenColors.accent
        }

        onPressed: (m) => {
          const p = handle.mapToItem(frame.parent, m.x, m.y)
          mx0 = p.x; my0 = p.y
          sx = frame.x; sy = frame.y; sw = frame.width; sh = frame.height
          frame.px = sx; frame.py = sy; frame.pw = sw; frame.ph = sh
          frame.interacting = true
        }

        onPositionChanged: (m) => {
          if (!pressed) return
          const p = handle.mapToItem(frame.parent, m.x, m.y)
          const dx = p.x - mx0
          const dy = p.y - my0
          let nx = sx, ny = sy, nw = sw, nh = sh

          if (ax === 1) nw = frame.clampW(sw + dx)
          else if (ax === -1) { nw = frame.clampW(sw - dx); nx = sx + sw - nw }

          if (ay === 1) nh = frame.clampH(sh + dy)
          else if (ay === -1) { nh = frame.clampH(sh - dy); ny = sy + sh - nh }

          if (frame.lockAspect && ax !== 0 && ay !== 0) {
            const ratio = sw / sh
            nh = frame.clampH(nw / ratio)
            nw = frame.clampW(nh * ratio)
            if (ax === -1) nx = sx + sw - nw
            if (ay === -1) ny = sy + sh - nh
          }

          frame.px = nx; frame.py = ny; frame.pw = nw; frame.ph = nh
        }

        onReleased: {
          const g = LockLayout.snapToGrid
          const gs = LockLayout.gridSize
          let fx = g ? Math.round(frame.px / gs) * gs : frame.px
          let fy = g ? Math.round(frame.py / gs) * gs : frame.py
          let fw = g ? Math.round(frame.pw / gs) * gs : frame.pw
          let fh = g ? Math.round(frame.ph / gs) * gs : frame.ph
          fw = frame.clampW(fw)
          fh = frame.clampH(fh)
          frame.commit(fx, fy, fw, fh)
        }
      }
    }
  }

  // ---------- control strip ----------

  component Chip: Rectangle {
    id: chip
    property string text: ""
    property string icon: ""
    property color iconColor: MatugenColors.text
    property color hoverColor: MatugenColors.accentSoft
    property bool active: false
    property bool clickable: false
    signal clicked()

    height: 26
    width: chipRow.implicitWidth + 16
    radius: 7
    color: chip.active ? MatugenColors.accentSoft
         : (chip.clickable && chipMa.containsMouse ? chip.hoverColor : MatugenColors.bgElevated2)
    border.width: 1
    border.color: chip.active ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.06)

    Row {
      id: chipRow
      anchors.centerIn: parent
      spacing: 5
      Text {
        visible: chip.icon !== ""
        text: chip.icon
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: chip.active ? MatugenColors.accent : chip.iconColor
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        visible: chip.text !== ""
        text: chip.text
        font.family: Config.fontFamily
        font.pixelSize: 10
        font.weight: Font.Bold
        color: chip.active ? MatugenColors.accent : MatugenColors.text
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      id: chipMa
      anchors.fill: parent
      enabled: chip.clickable
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.clicked()
    }
  }

  Item {
    id: panel
    visible: opacity > 0
    opacity: frame.selected ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    readonly property bool above: frame.y + frame.height + panelCol.implicitHeight + 24 > LockLayout.refH
    width: Math.max(frame.width, 330)
    height: panelCol.implicitHeight
    anchors.horizontalCenter: parent.horizontalCenter
    y: above ? -height - 12 : frame.height + 12
    z: 50

    MouseArea { anchors.fill: parent }

    Column {
      id: panelCol
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 7

      // Row 1: size, ratio, opacity, aspect lock, reset, delete
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        Chip { text: Math.round(frame.width) + "x" + Math.round(frame.height) }
        Chip {
          text: {
            const r = frame.height > 0 ? frame.width / frame.height : 1
            return r.toFixed(2) + ":1"
          }
        }
        Chip { text: Math.round(frame.iop * 100) + "%" }
        Chip {
          icon: "\uf0ec"
          clickable: true
          active: frame.lockAspect
          onClicked: frame.lockAspect = !frame.lockAspect
        }
        Chip {
          icon: "\uf021"
          clickable: true
          onClicked: {
            const v = frame.hasVariants ? frame.def.variants[0].id : ""
            const sz = LockLayout.sizeFor(frame.kind, v)
            LockLayout.update(frame.uid, { iop: 1.0, showText: true, variant: v, iw: sz.w, ih: sz.h })
          }
        }
        Chip {
          icon: "\uf1f8"
          iconColor: "#e05555"
          hoverColor: "#e05555"
          clickable: true
          onClicked: LockLayout.remove(frame.uid)
        }
      }

      // Row 2: show text, variant dropdown, opacity slider
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8

        // Show text toggle
        Row {
          visible: frame.def && frame.def.hasText === true
          spacing: 6
          anchors.verticalCenter: parent.verticalCenter
          Text {
            text: "Show text"
            font.family: Config.fontFamily
            font.pixelSize: 10
            font.weight: Font.Bold
            color: MatugenColors.text
            anchors.verticalCenter: parent.verticalCenter
          }
          Rectangle {
            width: 34; height: 18; radius: 9
            anchors.verticalCenter: parent.verticalCenter
            color: frame.showText ? MatugenColors.accent : MatugenColors.bgElevated2
            Behavior on color { ColorAnimation { duration: 150 } }
            Rectangle {
              width: 14; height: 14; radius: 7
              anchors.verticalCenter: parent.verticalCenter
              x: frame.showText ? parent.width - width - 2 : 2
              color: frame.showText ? MatugenColors.accentText : MatugenColors.text
              Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: LockLayout.update(frame.uid, { showText: !frame.showText })
            }
          }
        }

        // Variant dropdown
        Item {
          visible: frame.hasVariants
          width: 120; height: 26
          anchors.verticalCenter: parent.verticalCenter

          Rectangle {
            anchors.fill: parent
            radius: 7
            color: varMa.containsMouse ? MatugenColors.bgElevated : MatugenColors.bgElevated2
            border.width: 1
            border.color: frame.variantOpen ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.06)

            Text {
              anchors.left: parent.left
              anchors.leftMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              text: {
                if (!frame.hasVariants) return ""
                for (const v of frame.def.variants) if (v.id === frame.variant) return v.label
                return frame.def.variants[0].label
              }
              font.family: Config.fontFamily
              font.pixelSize: 10
              font.weight: Font.Bold
              color: MatugenColors.text
            }
            Text {
              anchors.right: parent.right
              anchors.rightMargin: 9
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf078"
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 10
              color: MatugenColors.textDim
              rotation: frame.variantOpen ? 180 : 0
              Behavior on rotation { NumberAnimation { duration: 140 } }
            }
            MouseArea {
              id: varMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: frame.variantOpen = !frame.variantOpen
            }
          }

          Column {
            visible: frame.variantOpen
            y: 30
            width: parent.width
            spacing: 2
            z: 200
            Repeater {
              model: frame.hasVariants ? frame.def.variants : []
              delegate: Rectangle {
                required property var modelData
                width: 120; height: 26; radius: 7
                color: optMa.containsMouse ? MatugenColors.accentSoft : MatugenColors.bgElevated2
                border.width: 1
                border.color: frame.variant === modelData.id ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.06)
                Text {
                  anchors.centerIn: parent
                  text: modelData.label
                  font.family: Config.fontFamily
                  font.pixelSize: 10
                  font.weight: Font.Bold
                  color: frame.variant === modelData.id ? MatugenColors.accent : MatugenColors.text
                }
                MouseArea {
                  id: optMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    LockLayout.update(frame.uid, { variant: modelData.id, iw: modelData.w, ih: modelData.h })
                    frame.variantOpen = false
                  }
                }
              }
            }
          }
        }

        // Opacity slider
        Rectangle {
          width: opRow.implicitWidth + 20
          height: 26
          radius: 7
          color: MatugenColors.bgElevated2
          border.width: 1
          border.color: Qt.rgba(1, 1, 1, 0.06)
          anchors.verticalCenter: parent.verticalCenter

          Row {
            id: opRow
            spacing: 8
            anchors.centerIn: parent

            Text {
              text: Math.round(frame.iop * 100) + "%"
              font.family: Config.fontFamily
              font.pixelSize: 10
              font.weight: Font.Bold
              color: MatugenColors.accent
              width: 30
              anchors.verticalCenter: parent.verticalCenter
            }
            Item {
              width: 110; height: 18
              anchors.verticalCenter: parent.verticalCenter

              Rectangle {
                id: opTrack
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                color: MatugenColors.borderSoft
                Rectangle {
                  width: opTrack.width * frame.iop
                  height: parent.height
                  radius: parent.radius
                  color: MatugenColors.accent
                }
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function setFromX(mx) {
                  const ratio = Math.max(0.15, Math.min(1, mx / width))
                  LockLayout.update(frame.uid, { iop: Math.round(ratio * 100) / 100 })
                }
                onPressed: (m) => setFromX(m.x)
                onPositionChanged: (m) => { if (pressed) setFromX(m.x) }
              }
            }
          }
        }
      }
    }
  }
}
