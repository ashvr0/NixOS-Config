import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../.."
import "../../Singletons"

Rectangle {
  id: tile

  required property string tid
  required property string label
  property string wallpaperPath: ""
  property bool selected: true
  property bool interactive: true

  signal picked()

  // Saved settings for this transition
  readonly property real durationSec: tid === "fade" ? Config.wallpaperFadeDuration
    : tid === "wipe" ? Config.wallpaperWipeDuration
    : tid === "circle" ? Config.wallpaperCircleDuration
    : Config.wallpaperSwipeDuration
  readonly property string orientationSetting: Config.wallpaperWipeOrientation
  readonly property string directionSetting: Config.wallpaperSwipeDirection
  readonly property string originSetting: Config.wallpaperCircleOrigin

  readonly property bool hovered: hover.hovered
  readonly property real restProgress: tid === "fade" ? 1.0 : 0.55

  // Animation state
  property real progress: restProgress
  property bool flipped: false
  property real angle: 0          // awww wipe angle: 0 starts right, 90 top, 180 left, 270 bottom
  property real originX: 0.5
  property real originY: 0.5

  function applyAngle() {
    if (tid === "wipe") {
      let o = orientationSetting
      if (o === "random") o = Math.random() < 0.5 ? "horizontal" : "vertical"
      let list = o === "vertical" ? [90, 270] : [0, 180]
      angle = list[Math.floor(Math.random() * 2)]
    } else if (tid === "swipe") {
      let keys = WallpaperTransition.swipeDirections
      let d = directionSetting
      if (keys.indexOf(d) === -1) d = keys[Math.floor(Math.random() * keys.length)]
      angle = WallpaperTransition.swipeAngles[d]
    }
  }
  function applyOrigin() {
    let c = originSetting === "center"
    originX = c ? 0.5 : 0.2 + Math.random() * 0.6
    originY = c ? 0.5 : 0.2 + Math.random() * 0.6
  }
  function randomize() { applyAngle(); applyOrigin() }

  Component.onCompleted: randomize()
  onOrientationSettingChanged: applyAngle()
  onDirectionSettingChanged: applyAngle()
  onOriginSettingChanged: applyOrigin()
  onRestProgressChanged: if (!loopAnim.running) progress = restProgress

  onHoveredChanged: {
    if (hovered) {
      restAnim.stop()
      loopAnim.restart()
    } else {
      loopAnim.stop()
      flipped = false
      restAnim.restart()
    }
  }

  SequentialAnimation {
    id: loopAnim
    loops: Animation.Infinite
    ScriptAction { script: tile.randomize() }
    NumberAnimation {
      target: tile
      property: "progress"
      from: 0.0
      to: 1.0
      duration: Math.max(100, Math.round(tile.durationSec * 1000))
      easing.type: Easing.InOutCubic
    }
    PauseAnimation { duration: 450 }
    ScriptAction { script: { tile.flipped = !tile.flipped; tile.progress = 0.0 } }
  }

  NumberAnimation {
    id: restAnim
    target: tile
    property: "progress"
    to: tile.restProgress
    duration: 250
    easing.type: Easing.OutCubic
  }

  Layout.fillWidth: true
  Layout.preferredWidth: 1
  implicitHeight: Scaler.s(132)
  radius: Scaler.s(Config.uiRadius)
  color: hovered && interactive ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.04)
  Behavior on color { ColorAnimation { duration: 120 } }
  border.width: 1
  border.color: selected ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.45) : Qt.rgba(1, 1, 1, 0.06)
  clip: true

  HoverHandler { id: hover }

  ColumnLayout {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Scaler.s(8)
    spacing: Scaler.s(8)
    opacity: (tile.interactive && !tile.selected) ? (tile.hovered ? 0.7 : 0.4) : 1.0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    Item {
      id: box
      Layout.fillWidth: true
      Layout.preferredHeight: Scaler.s(90)

      Rectangle {
        id: tileMask
        anchors.fill: parent
        radius: Scaler.s(8)
        color: "black"
        visible: false
        layer.enabled: true
      }

      Item {
        id: content
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: tileMask
        }

        // Reveal mask for the incoming layer. Black means visible.
        Item {
          id: revealMask
          anchors.fill: parent
          visible: false
          layer.enabled: tile.tid !== "fade"

          readonly property real bw: width
          readonly property real bh: height

          // Wipe and swipe: a half plane that sweeps across at the awww angle
          Rectangle {
            id: sweep
            visible: tile.tid === "wipe" || tile.tid === "swipe"
            readonly property real rad: tile.angle * Math.PI / 180
            readonly property real mx: -Math.cos(rad)
            readonly property real my: Math.sin(rad)
            readonly property real half: (Math.abs(mx) * revealMask.bw + Math.abs(my) * revealMask.bh) / 2
            readonly property real tt: -half + tile.progress * 2 * half
            readonly property real len: Math.sqrt(revealMask.bw * revealMask.bw + revealMask.bh * revealMask.bh) * 2
            width: len
            height: len
            x: revealMask.bw / 2 + mx * (tt - len / 2) - len / 2
            y: revealMask.bh / 2 + my * (tt - len / 2) - len / 2
            rotation: Math.atan2(my, mx) * 180 / Math.PI
            color: "black"
          }

          // Circle: grows from the origin until it covers everything
          Rectangle {
            id: disc
            visible: tile.tid === "circle"
            readonly property real maxR: Math.sqrt(
              Math.pow(Math.max(tile.originX, 1 - tile.originX) * revealMask.bw, 2) +
              Math.pow(Math.max(tile.originY, 1 - tile.originY) * revealMask.bh, 2))
            readonly property real d: 2 * maxR * tile.progress
            x: tile.originX * revealMask.bw - d / 2
            y: tile.originY * revealMask.bh - d / 2
            width: d
            height: d
            radius: d / 2
            color: "black"
          }
        }

        // Wallpaper layer
        Item {
          id: wallLayer
          anchors.fill: parent
          readonly property bool incoming: !tile.flipped
          z: incoming ? 2 : 1
          opacity: (tile.tid === "fade" && incoming) ? tile.progress : 1.0
          layer.enabled: tile.tid !== "fade" && incoming
          layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: revealMask
          }

          Rectangle { anchors.fill: parent; color: MatugenColors.bgElevated }
          Image {
            anchors.fill: parent
            source: tile.wallpaperPath ? "file://" + tile.wallpaperPath : ""
            sourceSize.width: 360
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
          }
        }

        // Plain layer, stands in for the old wallpaper
        Item {
          id: plainLayer
          anchors.fill: parent
          readonly property bool incoming: tile.flipped
          z: incoming ? 2 : 1
          opacity: (tile.tid === "fade" && incoming) ? tile.progress : 1.0
          layer.enabled: tile.tid !== "fade" && incoming
          layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: revealMask
          }

          Rectangle { anchors.fill: parent; color: MatugenColors.bgBase }
          Text {
            anchors.centerIn: parent
            text: "\udb80\ude79"
            font.pixelSize: Scaler.s(24)
            font.family: "JetBrainsMono Nerd Font"
            color: Qt.rgba(1, 1, 1, 0.25)
          }
        }
      }

      Rectangle {
        anchors.fill: parent
        radius: Scaler.s(8)
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)
      }
    }

    Text {
      Layout.fillWidth: true
      Layout.leftMargin: Scaler.s(2)
      text: tile.label
      font.pixelSize: Scaler.s(12)
      font.weight: Font.Bold
      font.family: "JetBrainsMono Nerd Font"
      color: MatugenColors.text
      elide: Text.ElideRight
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: tile.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: if (tile.interactive) tile.picked()
  }
}
