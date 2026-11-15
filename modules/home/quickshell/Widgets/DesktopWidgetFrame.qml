import QtQuick
import QtQuick.Window
import "../Components"
import ".."
import "../Singletons"

Item {
  id: frame

  required property var widgetData
  property real boundsWidth: 1920
  property real boundsHeight: 1080
  property var desktopRoot: null
  property bool resizing: false
  readonly property bool selected: Config.desktopSelectedWidgetId === widgetId

  readonly property string widgetId: widgetData ? widgetData.id : ""
  readonly property string widgetType: widgetData ? widgetData.type : ""
  readonly property var defaults: Config.desktopWidgetTypes.find(t => t.type === frame.widgetType)

  x: widgetData ? widgetData.x : 0
  y: widgetData ? widgetData.y : 0
  width: widgetData ? widgetData.w : 200
  height: widgetData ? widgetData.h : 140

  readonly property real widgetOpacity: (widgetData && widgetData.opacity !== undefined) ? widgetData.opacity : 1.0
  readonly property int widgetRotation: (widgetData && widgetData.rotation !== undefined) ? widgetData.rotation : 0
  // 90/270: frame box is the rotated (visual) box, content is laid out swapped.
  readonly property bool sideways: widgetRotation % 180 !== 0
  readonly property string clockVariant: (widgetData && widgetData.variant !== undefined) ? widgetData.variant : "digital"
  readonly property string calendarVariant: (widgetData && widgetData.variant !== undefined) ? widgetData.variant : "month"
  readonly property string musicVariant: (widgetData && widgetData.variant !== undefined) ? widgetData.variant : "wide"
  readonly property string weatherSize: (widgetData && widgetData.size !== undefined) ? widgetData.size : "small"
  readonly property string systemStatVariant: (widgetData && widgetData.variant !== undefined) ? widgetData.variant : "cpu"
  readonly property real gridSize: 20

  // Size limits in frame (visual) space; swapped when sideways.
  readonly property real minW: { let v = defaults ? (sideways ? defaults.minH : defaults.minW) : undefined; return v !== undefined ? v : (sideways ? 140 : 180) }
  readonly property real minH: { let v = defaults ? (sideways ? defaults.minW : defaults.minH) : undefined; return v !== undefined ? v : (sideways ? 180 : 140) }
  readonly property real maxW: { let v = defaults ? (sideways ? defaults.maxH : defaults.maxW) : undefined; return v !== undefined ? v : 1200 }
  readonly property real maxH: { let v = defaults ? (sideways ? defaults.maxW : defaults.maxH) : undefined; return v !== undefined ? v : 1200 }

  Behavior on x { enabled: !dragMa.drag.active && !frame.resizing; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
  Behavior on y { enabled: !dragMa.drag.active && !frame.resizing; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

  z: frame.selected ? 100 : 0

  // Rotate 90 deg: swap w/h around the center so the border follows.
  function rotateStep() {
    let next = (frame.widgetRotation + 90) % 360
    let nw = Math.round(frame.height)
    let nh = Math.round(frame.width)
    let nx = Math.max(0, Math.round(frame.x + (frame.width - nw) / 2))
    let ny = Math.max(0, Math.round(frame.y + (frame.height - nh) / 2))
    Config.updateDesktopWidget(frame.widgetId, { rotation: next, w: nw, h: nh, x: nx, y: ny })
  }

  Item {
    id: contentWrap
    anchors.centerIn: parent
    width: frame.sideways ? frame.height : frame.width
    height: frame.sideways ? frame.width : frame.height
    opacity: frame.widgetOpacity
    rotation: frame.widgetRotation
    Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    Loader {
      id: contentLoader
      anchors.fill: parent
      sourceComponent: {
        switch (frame.widgetType) {
          case "clock": return clockComp
          case "calendar": return calendarComp
          case "musicplayer": return musicComp
          case "weather": return weatherComp
          case "image": return imageComp
          case "systemstat": return systemStatComp
          case "cava": return cavaComp
          default: return null
        }
      }
      onLoaded: {
        if (frame.widgetType === "clock" && item) item.variant = frame.clockVariant
        if (frame.widgetType === "calendar" && item) item.variant = frame.calendarVariant
        if (frame.widgetType === "musicplayer" && item) item.variant = frame.musicVariant
        if (frame.widgetType === "weather" && item) item.sizeClass = frame.weatherSize
        if (frame.widgetType === "image" && item) item.imagePath = (frame.widgetData && frame.widgetData.imagePath) || ""
        if (frame.widgetType === "systemstat" && item) item.variant = frame.systemStatVariant
      }
    }

    Connections {
      target: frame
      function onClockVariantChanged() {
        if (frame.widgetType === "clock" && contentLoader.item) contentLoader.item.variant = frame.clockVariant
      }
      function onCalendarVariantChanged() {
        if (frame.widgetType === "calendar" && contentLoader.item) contentLoader.item.variant = frame.calendarVariant
      }
      function onMusicVariantChanged() {
        if (frame.widgetType === "musicplayer" && contentLoader.item) contentLoader.item.variant = frame.musicVariant
      }
      function onWeatherSizeChanged() {
        if (frame.widgetType === "weather" && contentLoader.item) contentLoader.item.sizeClass = frame.weatherSize
      }
      function onWidgetDataChanged() {
        if (frame.widgetType === "image" && contentLoader.item) {
          contentLoader.item.imagePath = (frame.widgetData && frame.widgetData.imagePath) || ""
        }
      }
      function onSystemStatVariantChanged() {
        if (frame.widgetType === "systemstat" && contentLoader.item) contentLoader.item.variant = frame.systemStatVariant
      }
    }
  }

  Component { id: clockComp; DesktopClockWidget {} }
  Component { id: calendarComp; DesktopCalendarWidget {} }
  Component { id: musicComp; DesktopMusicWidget {} }
  Component { id: weatherComp; DesktopWeatherWidget {} }
  Component { id: imageComp; DesktopImageWidget {} }
  Component { id: systemStatComp; DesktopSystemStatWidget {} }
  Component { id: cavaComp; DesktopCavaWidget {} }

  MouseArea {
    anchors.fill: parent
    visible: Config.desktopEditMode
    enabled: Config.desktopEditMode
    z: -1
    onClicked: Config.desktopSelectedWidgetId = frame.selected ? "" : frame.widgetId
  }

  // Edit chrome: border + move + 8 resize handles (corners and sides).
  Rectangle {
    id: chrome
    anchors.fill: parent
    anchors.margins: -4
    radius: 10
    color: "transparent"
    border.width: frame.selected ? 2 : 1
    border.color: frame.selected ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.25)
    visible: Config.desktopEditMode

    MouseArea {
      id: dragMa
      anchors.fill: parent
      drag.target: frame
      drag.minimumX: 0
      drag.minimumY: 0
      drag.maximumX: Math.max(0, frame.boundsWidth - frame.width)
      drag.maximumY: Math.max(0, frame.boundsHeight - frame.height)
      cursorShape: Qt.SizeAllCursor
      onClicked: Config.desktopSelectedWidgetId = frame.selected ? "" : frame.widgetId

      onPositionChanged: {
        if (!drag.active) return
        if (Config.desktopSnapToGrid) {
          let sx = Math.round(frame.x / frame.gridSize) * frame.gridSize
          let sy = Math.round(frame.y / frame.gridSize) * frame.gridSize
          if (frame.x !== sx) frame.x = sx
          if (frame.y !== sy) frame.y = sy
          return
        }

        if (frame.desktopRoot) {
          let snapInfo = frame.desktopRoot.calculateSnap(frame, frame.x, frame.y)
          frame.x = snapInfo.x
          frame.y = snapInfo.y
          frame.desktopRoot.activeGuideX = snapInfo.guideX
          frame.desktopRoot.activeGuideY = snapInfo.guideY
        }
      }

      onReleased: {
        let gx = Config.desktopSnapToGrid ? Math.round(frame.x / frame.gridSize) * frame.gridSize : frame.x
        let gy = Config.desktopSnapToGrid ? Math.round(frame.y / frame.gridSize) * frame.gridSize : frame.y
        frame.x = gx
        frame.y = gy
        if (frame.desktopRoot) {
          frame.desktopRoot.activeGuideX = -1
          frame.desktopRoot.activeGuideY = -1
        }
        Config.updateDesktopWidget(frame.widgetId, { x: Math.round(gx), y: Math.round(gy) })
      }
    }

    // ax/ay: -1 = left/top edge, 0 = middle, 1 = right/bottom edge.
    Repeater {
      model: [
        { ax: -1, ay: -1 }, { ax: 0, ay: -1 }, { ax: 1, ay: -1 },
        { ax: -1, ay: 0 },                      { ax: 1, ay: 0 },
        { ax: -1, ay: 1 },  { ax: 0, ay: 1 },  { ax: 1, ay: 1 }
      ]
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

        onPressed: (mouse) => {
          frame.resizing = true
          sx = frame.x; sy = frame.y; sw = frame.width; sh = frame.height
          let p = handle.mapToItem(frame.parent, mouse.x, mouse.y)
          mx0 = p.x; my0 = p.y
        }

        onPositionChanged: (mouse) => {
          if (!pressed) return
          let p = handle.mapToItem(frame.parent, mouse.x, mouse.y)
          let dx = p.x - mx0
          let dy = p.y - my0
          let nx = sx, ny = sy, nw = sw, nh = sh

          if (ax === 1) nw = Math.min(frame.maxW, Math.max(frame.minW, sw + dx))
          else if (ax === -1) { nw = Math.min(frame.maxW, Math.max(frame.minW, sw - dx)); nx = sx + sw - nw }

          if (ay === 1) nh = Math.min(frame.maxH, Math.max(frame.minH, sh + dy))
          else if (ay === -1) { nh = Math.min(frame.maxH, Math.max(frame.minH, sh - dy)); ny = sy + sh - nh }

          frame.x = nx; frame.y = ny
          frame.width = nw; frame.height = nh
        }

        onReleased: {
          let g = Config.desktopSnapToGrid
          let gs = frame.gridSize
          let fx = g ? Math.round(frame.x / gs) * gs : frame.x
          let fy = g ? Math.round(frame.y / gs) * gs : frame.y
          let fw = g ? Math.round(frame.width / gs) * gs : frame.width
          let fh = g ? Math.round(frame.height / gs) * gs : frame.height
          fw = Math.min(frame.maxW, Math.max(frame.minW, fw))
          fh = Math.min(frame.maxH, Math.max(frame.minH, fh))
          frame.resizing = false
          Config.updateDesktopWidget(frame.widgetId, {
            x: Math.round(fx), y: Math.round(fy), w: Math.round(fw), h: Math.round(fh)
          })
        }
      }
    }
  }

  // ── Control panel ──
  Rectangle {
    id: controlPanel
    visible: opacity > 0
    opacity: Config.desktopEditMode && frame.selected ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    width: Math.max(frame.width, 220)
    height: panelCol.implicitHeight + 20
    anchors.top: parent.bottom
    anchors.topMargin: 10
    anchors.horizontalCenter: parent.horizontalCenter
    radius: 12
    color: "transparent"
    border.color: "transparent"
    border.width: 0
    z: 50

    MouseArea { anchors.fill: parent }

    Column {
      id: panelCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 10
      spacing: 8

      // Clock variant picker
      Row {
        visible: frame.widgetType === "clock"
        spacing: 6
        anchors.horizontalCenter: parent.horizontalCenter

        Repeater {
          model: Config.clockVariants
          delegate: Rectangle {
            required property var modelData
            width: 70; height: 26; radius: 6
            color: frame.clockVariant === modelData.size
              ? MatugenColors.accentSoft
              : MatugenColors.bgElevated2

            Text {
              anchors.centerIn: parent
              text: modelData.label
              font.pixelSize: 10
              font.weight: Font.Bold
              font.family: Config.fontFamily
              color: frame.clockVariant === modelData.size ? MatugenColors.accent : MatugenColors.text
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: Config.updateDesktopWidget(frame.widgetId, {
                variant: modelData.size,
                rotation: 0,
                w: modelData.w,
                h: modelData.h
              })
            }
          }
        }
      }

      // Calendar variant picker
      Row {
        visible: frame.widgetType === "calendar"
        spacing: 6
        anchors.horizontalCenter: parent.horizontalCenter

        Repeater {
          model: Config.calendarVariants
          delegate: Rectangle {
            required property var modelData
            width: 90; height: 26; radius: 6
            color: frame.calendarVariant === modelData.variant
              ? MatugenColors.accentSoft
              : MatugenColors.bgElevated2

            Text {
              anchors.centerIn: parent
              text: modelData.label
              font.pixelSize: 10
              font.weight: Font.Bold
              font.family: Config.fontFamily
              color: frame.calendarVariant === modelData.variant ? MatugenColors.accent : MatugenColors.text
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: Config.updateDesktopWidget(frame.widgetId, {
                variant: modelData.variant,
                rotation: 0,
                w: modelData.w,
                h: modelData.h
              })
            }
          }
        }
      }

      // Music player variant picker
      Row {
        visible: frame.widgetType === "musicplayer"
        spacing: 6
        anchors.horizontalCenter: parent.horizontalCenter

        Repeater {
          model: Config.musicVariants
          delegate: Rectangle {
            required property var modelData
            width: 70; height: 26; radius: 6
            color: frame.musicVariant === modelData.variant
              ? MatugenColors.accentSoft
              : MatugenColors.bgElevated2

            Text {
              anchors.centerIn: parent
              text: modelData.label
              font.pixelSize: 10
              font.weight: Font.Bold
              font.family: Config.fontFamily
              color: frame.musicVariant === modelData.variant ? MatugenColors.accent : MatugenColors.text
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: Config.updateDesktopWidget(frame.widgetId, {
                variant: modelData.variant,
                rotation: 0,
                w: modelData.w,
                h: modelData.h
              })
            }
          }
        }
      }

      // System stat variant picker
      Row {
        visible: frame.widgetType === "systemstat"
        spacing: 6
        anchors.horizontalCenter: parent.horizontalCenter

        Repeater {
          model: Config.systemStatVariants
          delegate: Rectangle {
            required property var modelData
            width: 62; height: 26; radius: 6
            color: frame.systemStatVariant === modelData.variant
              ? MatugenColors.accentSoft
              : MatugenColors.bgElevated2

            Text {
              anchors.centerIn: parent
              text: modelData.label
              font.pixelSize: 10
              font.weight: Font.Bold
              font.family: Config.fontFamily
              color: frame.systemStatVariant === modelData.variant ? MatugenColors.accent : MatugenColors.text
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: Config.updateDesktopWidget(frame.widgetId, { variant: modelData.variant })
            }
          }
        }
      }

      // Weather size picker
      Row {
        visible: frame.widgetType === "weather"
        spacing: 6
        anchors.horizontalCenter: parent.horizontalCenter

        Repeater {
          model: Config.weatherSizePresets
          delegate: Rectangle {
            required property var modelData
            width: 62; height: 26; radius: 6
            color: frame.weatherSize === modelData.size
              ? MatugenColors.accentSoft
              : MatugenColors.bgElevated2

            Text {
              anchors.centerIn: parent
              text: modelData.label
              font.pixelSize: 10
              font.weight: Font.Bold
              font.family: Config.fontFamily
              color: frame.weatherSize === modelData.size ? MatugenColors.accent : MatugenColors.text
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: Config.updateDesktopWidget(frame.widgetId, {
                size: modelData.size,
                rotation: 0,
                w: modelData.w,
                h: modelData.h
              })
            }
          }
        }
      }

      // Choose image button (image widget only)
      Rectangle {
        visible: frame.widgetType === "image"
        anchors.horizontalCenter: parent.horizontalCenter
        width: 130; height: 26; radius: 6
        color: chooseImgMa.containsMouse ? MatugenColors.accentSoft : MatugenColors.bgElevated2

        Text {
          anchors.centerIn: parent
          text: "Choose image..."
          font.pixelSize: 10
          font.weight: Font.Bold
          font.family: Config.fontFamily
          color: MatugenColors.text
        }

        MouseArea {
          id: chooseImgMa
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: imagePickerLoader.active = true
        }
      }

      // Opacity slider
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: opRow.implicitWidth + 20
        height: 30
        radius: 8
        color: MatugenColors.bgElevated2

        Row {
          id: opRow
          spacing: 8
          anchors.centerIn: parent

          Text {
            text: "\uf042"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: MatugenColors.textDim
            anchors.verticalCenter: parent.verticalCenter
          }

          Item {
            width: 120; height: 18
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
              id: opTrack
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width
              height: 4
              radius: 2
              color: MatugenColors.borderSoft

              Rectangle {
                width: opTrack.width * frame.widgetOpacity
                height: parent.height
                radius: parent.radius
                color: MatugenColors.accent
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              function setFromX(mx) {
                let ratio = Math.max(0.15, Math.min(1, mx / width))
                Config.updateDesktopWidget(frame.widgetId, { opacity: Math.round(ratio * 100) / 100 })
              }
              onPressed: (mouse) => setFromX(mouse.x)
              onPositionChanged: (mouse) => { if (pressed) setFromX(mouse.x) }
            }
          }

          Text {
            text: Math.round(frame.widgetOpacity * 100) + "%"
            font.pixelSize: 10
            font.weight: Font.Bold
            font.family: Config.fontFamily
            color: MatugenColors.accent
            anchors.verticalCenter: parent.verticalCenter
            width: 32
          }
        }
      }

      // Size readout + reset + rotate + remove
      Row {
        spacing: 8
        anchors.horizontalCenter: parent.horizontalCenter

        Rectangle {
          width: sizeLabel.implicitWidth + 14
          height: 22
          radius: 6
          color: MatugenColors.bgElevated2
          anchors.verticalCenter: parent.verticalCenter

          Text {
            id: sizeLabel
            anchors.centerIn: parent
            text: Math.round(frame.width) + "x" + Math.round(frame.height)
            font.pixelSize: 10
            font.weight: Font.Bold
            font.family: Config.fontFamily
            color: MatugenColors.text
          }
        }

        // Reset
        Rectangle {
          width: 22; height: 22; radius: 6
          anchors.verticalCenter: parent.verticalCenter
          color: resetMa.containsMouse ? MatugenColors.accentSoft : MatugenColors.bgElevated2

          Text {
            anchors.centerIn: parent
            text: "\uf021"
            font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font"
            color: resetMa.containsMouse ? MatugenColors.accent : MatugenColors.text
          }

          MouseArea {
            id: resetMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              let def = frame.defaults
              let patch = { opacity: 1.0, rotation: 0 }
              if (frame.widgetType === "clock") {
                patch.variant = "digital"
                patch.w = def ? def.w : 200
                patch.h = def ? def.h : 200
              } else if (frame.widgetType === "calendar") {
                let monthPreset = Config.calendarVariants.find(v => v.variant === "month")
                patch.variant = "month"
                patch.w = monthPreset ? monthPreset.w : 320
                patch.h = monthPreset ? monthPreset.h : 340
              } else if (frame.widgetType === "weather") {
                let small = Config.weatherSizePresets.find(p => p.size === "small")
                patch.size = "small"
                patch.w = small ? small.w : 200
                patch.h = small ? small.h : 200
              } else if (frame.widgetType === "musicplayer") {
                let wide = Config.musicVariants.find(v => v.variant === "wide")
                patch.variant = "wide"
                patch.w = wide ? wide.w : 646
                patch.h = wide ? wide.h : 227
              } else if (frame.widgetType === "systemstat") {
                patch.variant = "cpu"
                patch.w = def ? def.w : 220
                patch.h = def ? def.h : 160
              } else {
                patch.w = def ? def.w : 200
                patch.h = def ? def.h : 200
              }
              Config.updateDesktopWidget(frame.widgetId, patch)
            }
          }
        }

        // Rotate
        Rectangle {
          width: 22; height: 22; radius: 6
          anchors.verticalCenter: parent.verticalCenter
          color: rotateMa.containsMouse ? MatugenColors.accentSoft : MatugenColors.bgElevated2

          Text {
            anchors.centerIn: parent
            text: "\uf2f1"
            font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font"
            color: rotateMa.containsMouse ? MatugenColors.accent : MatugenColors.text
          }

          MouseArea {
            id: rotateMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: frame.rotateStep()
          }
        }

        // Remove
        Rectangle {
          width: 22; height: 22; radius: 6
          anchors.verticalCenter: parent.verticalCenter
          color: removeMa.containsMouse ? "#e05555" : MatugenColors.bgElevated2

          Text {
            anchors.centerIn: parent
            text: "\u2715"
            font.pixelSize: 10
            color: removeMa.containsMouse ? "white" : "#e05555"
          }

          MouseArea {
            id: removeMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Config.removeDesktopWidget(frame.widgetId)
          }
        }
      }
    }
  }

  Loader {
    id: imagePickerLoader
    active: false
    parent: frame.Window.window ? frame.Window.window.contentItem : frame
    anchors.fill: parent
    z: 1000
    sourceComponent: FilePickerDialog {
      titleText: "Choose image"
      nameFilters: ["png", "jpg", "jpeg", "webp", "bmp", "gif"]
      places: [
        { name: "Home", icon: "󰋜", path: Quickshell.env("HOME") || "" },
        { name: "Downloads", icon: "󰇚", path: (Quickshell.env("HOME") || "") + "/Downloads" },
        { name: "Pictures", icon: "󰉏", path: (Quickshell.env("HOME") || "") + "/Pictures" },
      ]
      onAccepted: (path) => {
        Config.updateDesktopWidget(frame.widgetId, { imagePath: path })
        imagePickerLoader.active = false
      }
      onCancelled: imagePickerLoader.active = false
    }
  }
}
