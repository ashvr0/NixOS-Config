import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Components"
import ".."
import "../Singletons"
import "."

PanelWindow {
  id: root

  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "qs-desktop-widgets"
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }

  WlrLayershell.keyboardFocus: Config.desktopEditMode ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

  Component.onCompleted: {
    Scaler.currentWidth = Screen.width
    Scaler.currentHeight = Screen.height
  }
  function s(v) { return Scaler.s(v) }

  property real activeGuideX: -1
  property real activeGuideY: -1

  function calculateSnap(draggedFrame, rawX, rawY) {
    let snapThreshold = 8
    let res = { x: rawX, y: rawY, guideX: -1, guideY: -1 }

    let bestDx = snapThreshold
    let bestDy = snapThreshold

    let dXEdges = [rawX, rawX + draggedFrame.width / 2.0, rawX + draggedFrame.width]
    let dYEdges = [rawY, rawY + draggedFrame.height / 2.0, rawY + draggedFrame.height]

    let screenCenterX = root.width / 2.0
    let screenCenterY = root.height / 2.0

    for (let j = 0; j < dXEdges.length; j++) {
      let diff = Math.abs(dXEdges[j] - screenCenterX)
      if (diff < bestDx) {
        bestDx = diff
        res.x = rawX + (screenCenterX - dXEdges[j])
        res.guideX = screenCenterX
      }
    }

    for (let j = 0; j < dYEdges.length; j++) {
      let diff = Math.abs(dYEdges[j] - screenCenterY)
      if (diff < bestDy) {
        bestDy = diff
        res.y = rawY + (screenCenterY - dYEdges[j])
        res.guideY = screenCenterY
      }
    }

    for (let i = 0; i < widgetRepeater.count; i++) {
      let other = widgetRepeater.itemAt(i)
      if (!other || other === draggedFrame) continue

      let oXEdges = [other.x, other.x + other.width / 2.0, other.x + other.width]
      let oYEdges = [other.y, other.y + other.height / 2.0, other.y + other.height]

      for (let j = 0; j < dXEdges.length; j++) {
        for (let k = 0; k < oXEdges.length; k++) {
          let diff = Math.abs(dXEdges[j] - oXEdges[k])
          if (diff < bestDx) {
            bestDx = diff
            res.x = rawX + (oXEdges[k] - dXEdges[j])
            res.guideX = oXEdges[k]
          }
        }
      }

      for (let j = 0; j < dYEdges.length; j++) {
        for (let k = 0; k < oYEdges.length; k++) {
          let diff = Math.abs(dYEdges[j] - oYEdges[k])
          if (diff < bestDy) {
            bestDy = diff
            res.y = rawY + (oYEdges[k] - dYEdges[j])
            res.guideY = oYEdges[k]
          }
        }
      }
    }

    let mX = Math.max(0, root.width - draggedFrame.width)
    let mY = Math.max(0, root.height - draggedFrame.height)
    res.x = Math.max(0, Math.min(mX, res.x))
    res.y = Math.max(0, Math.min(mY, res.y))

    return res
  }

  property real pendingImageX: 0
  property real pendingImageY: 0

  Loader {
    id: addImagePickerLoader
    active: false
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
        Config.addDesktopWidget("image", root.pendingImageX, root.pendingImageY)
        let added = Config.desktopWidgets[Config.desktopWidgets.length - 1]
        Config.updateDesktopWidget(added.id, { imagePath: path })
        addImagePickerLoader.active = false
      }
      onCancelled: addImagePickerLoader.active = false
    }
  }

  MouseArea {
    anchors.fill: parent
    z: -10
    enabled: Config.desktopEditMode
    onClicked: Config.desktopSelectedWidgetId = ""
  }

  Canvas {
    id: dotGrid
    anchors.fill: parent
    visible: Config.desktopEditMode
    opacity: Config.desktopEditMode ? (Config.desktopSnapToGrid ? 0.55 : 0.35) : 0
    Behavior on opacity { NumberAnimation { duration: 220 } }

    onPaint: {
      let ctx = getContext("2d")
      ctx.reset()
      ctx.fillStyle = MatugenColors.textDim
      let spacing = s(28)
      let dotRadius = Config.desktopSnapToGrid ? 1.8 : 1.5
      for (let px = spacing; px < width; px += spacing) {
        for (let py = spacing; py < height; py += spacing) {
          ctx.beginPath()
          ctx.arc(px, py, dotRadius, 0, Math.PI * 2)
          ctx.fill()
        }
      }
    }
    Component.onCompleted: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    Connections {
      target: Config
      function onDesktopSnapToGridChanged() { dotGrid.requestPaint() }
    }
  }

  Repeater {
    id: widgetRepeater
    model: Config.desktopWidgets
    delegate: DesktopWidgetFrame {
      required property var modelData
      widgetData: modelData
      boundsWidth: root.width
      boundsHeight: root.height
      desktopRoot: root
    }
  }

  Rectangle {
    x: root.activeGuideX
    y: 0
    width: 1
    height: parent.height
    color: MatugenColors.accent
    visible: Config.desktopEditMode && root.activeGuideX >= 0
    z: 500
  }

  Rectangle {
    x: 0
    y: root.activeGuideY
    width: parent.width
    height: 1
    color: MatugenColors.accent
    visible: Config.desktopEditMode && root.activeGuideY >= 0
    z: 500
  }

  Rectangle {
    id: tray
    width: Math.min(root.width * 0.75, s(740))
    height: s(96)
    radius: s(18)
    color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.94)
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1
    anchors.horizontalCenter: parent.horizontalCenter
    y: Config.desktopEditMode ? root.height - height - s(28) : root.height + s(20)
    Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

    Row {
      anchors.fill: parent
      anchors.margins: s(14)
      spacing: s(14)

      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: s(4)

        Row {
          spacing: s(16)
          anchors.horizontalCenter: parent.horizontalCenter

          Repeater {
            model: Config.desktopWidgetTypes
            delegate: Column {
              required property var modelData
              spacing: s(4)

              Rectangle {
                width: s(56); height: s(56); radius: s(14)
                anchors.horizontalCenter: parent.horizontalCenter
                color: trayMa.containsMouse ? MatugenColors.bgElevated2 : MatugenColors.bgElevated
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                  anchors.centerIn: parent
                  text: modelData.icon
                  font.pixelSize: s(20)
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.accent
                }

                MouseArea {
                  id: trayMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (modelData.type === "image") {
                      root.pendingImageX = Math.round(root.width / 2 - modelData.w / 2)
                      root.pendingImageY = Math.round(root.height / 2 - modelData.h / 2)
                      addImagePickerLoader.active = true
                    } else {
                      Config.addDesktopWidget(
                        modelData.type,
                        Math.round(root.width / 2 - modelData.w / 2),
                        Math.round(root.height / 2 - modelData.h / 2)
                      )
                    }
                  }
                }
              }

              Text {
                text: modelData.label
                font.pixelSize: s(9)
                font.family: Config.fontFamily
                color: MatugenColors.textDim
                anchors.horizontalCenter: parent.horizontalCenter
              }
            }
          }
        }
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: s(56)
        color: Qt.rgba(1, 1, 1, 0.1)
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: s(4)

        Rectangle {
          width: s(56); height: s(56); radius: s(14)
          anchors.horizontalCenter: parent.horizontalCenter
          color: Config.desktopSnapToGrid
            ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.28)
            : (snapMa.containsMouse ? MatugenColors.bgElevated2 : MatugenColors.bgElevated)
          border.width: Config.desktopSnapToGrid ? 1 : 0
          border.color: MatugenColors.accent
          Behavior on color { ColorAnimation { duration: 120 } }

          Text {
            anchors.centerIn: parent
            text: "󰕰"
            font.pixelSize: s(20)
            font.family: "JetBrainsMono Nerd Font"
            color: Config.desktopSnapToGrid ? MatugenColors.accent : MatugenColors.textDim
          }

          MouseArea {
            id: snapMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Config.desktopSnapToGrid = !Config.desktopSnapToGrid
          }
        }

        Text {
          text: "Snap"
          font.pixelSize: s(9)
          font.weight: Font.Bold
          font.family: Config.fontFamily
          color: MatugenColors.textDim
          anchors.horizontalCenter: parent.horizontalCenter
        }
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: s(56)
        color: Qt.rgba(1, 1, 1, 0.1)
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: s(80); height: s(40); radius: s(20)
        color: doneMa.containsMouse ? Qt.lighter(MatugenColors.accent, 1.1) : MatugenColors.accent

        Text {
          anchors.centerIn: parent
          text: "Done"
          font.pixelSize: s(12)
          font.weight: Font.Bold
          font.family: Config.fontFamily
          color: MatugenColors.accentText
        }

        MouseArea {
          id: doneMa
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Config.desktopEditMode = false
        }
      }
    }
  }
}
