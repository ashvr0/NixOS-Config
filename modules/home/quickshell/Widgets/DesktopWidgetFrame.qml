import QtQuick
import QtQuick.Window
import ".."
import "../Singletons"

Item {
  id: frame

  required property var widgetData
  property real boundsWidth: 1920
  property real boundsHeight: 1080
  property var desktopRoot: null
  readonly property bool selected: Config.desktopSelectedWidgetId === widgetId

  // Cache the id/type up front. These never change for a given widget
  // instance, so reading them once avoids re-deriving anything from
  // widgetData (a fresh object every update) inside bindings that
  // shouldn't care about unrelated field changes.
  readonly property string widgetId: widgetData ? widgetData.id : ""
  readonly property string widgetType: widgetData ? widgetData.type : ""
  readonly property var defaults: Config.desktopWidgetTypes.find(t => t.type === frame.widgetType)

  x: widgetData ? widgetData.x : 0
  y: widgetData ? widgetData.y : 0
  width: widgetData ? widgetData.w : 200
  height: widgetData ? widgetData.h : 140

  readonly property real widgetOpacity: (widgetData && widgetData.opacity !== undefined) ? widgetData.opacity : 1.0
  readonly property string clockVariant: (widgetData && widgetData.variant !== undefined) ? widgetData.variant : "digital"
  readonly property string calendarVariant: (widgetData && widgetData.variant !== undefined) ? widgetData.variant : "month"
  readonly property string musicVariant: (widgetData && widgetData.variant !== undefined) ? widgetData.variant : "wide"
  readonly property string weatherSize: (widgetData && widgetData.size !== undefined) ? widgetData.size : "small"
  readonly property string systemStatVariant: (widgetData && widgetData.variant !== undefined) ? widgetData.variant : "cpu"
  readonly property real gridSize: 20

  Behavior on x { enabled: !dragMa.drag.active; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
  Behavior on y { enabled: !dragMa.drag.active; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

  // Selected widget (panel open) must draw above every sibling frame,
  // or a neighbour's opaque content sits over this widget's own panel.
  // Panel content itself also carries z: 50, but that only wins within
  // this frame - siblings still need their own root z raised.
  z: frame.selected ? 100 : 0

  Item {
    id: contentWrap
    anchors.fill: parent
    opacity: frame.widgetOpacity
    rotation: (widgetData && widgetData.rotation !== undefined) ? widgetData.rotation : 0
    Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    // sourceComponent is keyed only off widgetType, which is a readonly
    // property that never changes after creation - so dragging, resizing,
    // or changing opacity/variant never touches this Loader or reloads
    // the widget's content.
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

    // These only push updates into the already-loaded item's properties -
    // they never touch sourceComponent, so no reload happens.
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

  // Click to select while in edit mode (opens the control panel below).
  MouseArea {
    anchors.fill: parent
    visible: Config.desktopEditMode
    enabled: Config.desktopEditMode
    z: -1
    onClicked: Config.desktopSelectedWidgetId = frame.selected ? "" : frame.widgetId
  }

  // Edit chrome: move handle, resize handle, remove button. Only
  // interactive while Config.desktopEditMode is on.
  Rectangle {
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

      // Snap live while dragging. Only one write per move now (raw
      // position gets immediately overwritten with the rounded value
      // in this same handler), instead of drag.target writing raw
      // then this correcting after, which was causing jitter.
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

    Rectangle {
      id: resizeHandle
      width: 22; height: 22; radius: 7
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: -2
      color: MatugenColors.accent

      property real startW: 0
      property real startH: 0

      // Falls back to the old flat bounds if a widget type has no
      // min/max defined, so this never breaks for an unlisted type.
      readonly property real minW: frame.defaults && frame.defaults.minW !== undefined ? frame.defaults.minW : 180
      readonly property real minH: frame.defaults && frame.defaults.minH !== undefined ? frame.defaults.minH : 140
      readonly property real maxW: frame.defaults && frame.defaults.maxW !== undefined ? frame.defaults.maxW : 1200
      readonly property real maxH: frame.defaults && frame.defaults.maxH !== undefined ? frame.defaults.maxH : 1200

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.SizeFDiagCursor
        onPressed: {
          resizeHandle.startW = frame.width
          resizeHandle.startH = frame.height
        }
        onPositionChanged: (mouse) => {
          if (!pressed) return
          frame.width = Math.min(resizeHandle.maxW, Math.max(resizeHandle.minW, resizeHandle.startW + mouse.x))
          frame.height = Math.min(resizeHandle.maxH, Math.max(resizeHandle.minH, resizeHandle.startH + mouse.y))
        }
        onReleased: {
          let gw = Config.desktopSnapToGrid ? Math.round(frame.width / frame.gridSize) * frame.gridSize : frame.width
          let gh = Config.desktopSnapToGrid ? Math.round(frame.height / frame.gridSize) * frame.gridSize : frame.height
          frame.width = Math.min(resizeHandle.maxW, Math.max(resizeHandle.minW, gw))
          frame.height = Math.min(resizeHandle.maxH, Math.max(resizeHandle.minH, gh))
          Config.updateDesktopWidget(frame.widgetId, { w: Math.round(frame.width), h: Math.round(frame.height) })
        }
      }
    }

    Rectangle {
      width: 22; height: 22; radius: 11
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: -8
      color: "#e05555"

      Text {
        anchors.centerIn: parent
        text: "\u2715"
        color: "white"
        font.pixelSize: 10
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Config.removeDesktopWidget(frame.widgetId)
      }
    }

    Rectangle {
      id: rotateHandle
      width: 22; height: 22; radius: 11
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.margins: -8
      color: rotateMa.containsMouse ? Qt.lighter(MatugenColors.accent, 1.1) : MatugenColors.accent

      readonly property int currentRotation: (frame.widgetData && frame.widgetData.rotation !== undefined) ? frame.widgetData.rotation : 0

      Text {
        anchors.centerIn: parent
        text: "\uf2f1"
        color: MatugenColors.accentText
        font.pixelSize: 11
        font.family: "JetBrainsMono Nerd Font"
      }

      MouseArea {
        id: rotateMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // Rotates in fixed 90° steps, wrapping back to 0 after 270°, so
        // repeated clicks cycle cleanly instead of accumulating forever.
        onClicked: {
          let next = (rotateHandle.currentRotation + 90) % 360
          Config.updateDesktopWidget(frame.widgetId, { rotation: next })
        }
      }
    }

  }

  // ── Control panel: appears below the widget, always visible in edit mode ──
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

    MouseArea { anchors.fill: parent } // eat clicks, don't drag the widget

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
              // Digital and analog are different natural shapes (wide vs.
              // roughly square), so switching variant also resizes the
              // widget instead of leaving the old layout's box behind.
              onClicked: Config.updateDesktopWidget(frame.widgetId, {
                variant: modelData.size,
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
              // Each variant is its own layout with its own natural size,
              // same as weather's size presets - so switching variant also
              // resizes the widget instead of leaving stale content cramped.
              onClicked: Config.updateDesktopWidget(frame.widgetId, {
                variant: modelData.variant,
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
              // Large is a tall layout, wide is a short strip - each needs
              // its own natural size, so switching variant resizes too.
              onClicked: Config.updateDesktopWidget(frame.widgetId, {
                variant: modelData.variant,
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
              // Each size has its own natural layout (icon-only vs. hourly
              // strip vs. full week), so switching size also resizes the
              // widget to that preset's dimensions rather than leaving
              // stale content cramped into the old box.
              onClicked: Config.updateDesktopWidget(frame.widgetId, {
                size: modelData.size,
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

      // Size readout + reset
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
      }
    }
  }

  Loader {
    id: imagePickerLoader
    active: false
    // Reparent to the top-level window's content item so the dialog
    // fills the whole screen instead of being clipped/squashed to
    // this widget's own small frame bounds (frame is the picker's
    // natural parent, which is wrong here).
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
