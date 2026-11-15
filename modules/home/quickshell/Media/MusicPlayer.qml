import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../Singletons/Scaler.js" as LayoutMath
import "../Singletons"
import "../Components"

Item {
  id: root
  implicitWidth: pillBg.width
  implicitHeight: pillBg.height
  property bool vertical: Config.barVertical

  Component.onCompleted: {
    Scaler.currentWidth = Screen.width
    Scaler.currentHeight = Screen.height
  }

  function s(val) {
    return Scaler.s(val)
  }

  component MediaIcon: Item {
    id: icon
    property string kind: "play"
    property color tint: "white"
    property real size: 12
    width: size
    height: size

    function pt(x, y) {
      return (x * size).toFixed(2) + " " + (y * size).toFixed(2)
    }
    function rect(x0, y0, x1, y1) {
      return "M " + pt(x0, y0) + " L " + pt(x1, y0) + " L " + pt(x1, y1) + " L " + pt(x0, y1) + " Z "
    }
    function tri(ax, ay, bx, by, cx, cy) {
      return "M " + pt(ax, ay) + " L " + pt(bx, by) + " L " + pt(cx, cy) + " Z "
    }

    readonly property string pathData: {
      if (kind === "prev")
        return rect(0.10, 0.15, 0.22, 0.85) + tri(0.88, 0.15, 0.88, 0.85, 0.30, 0.50)
      if (kind === "next")
        return rect(0.78, 0.15, 0.90, 0.85) + tri(0.12, 0.15, 0.12, 0.85, 0.70, 0.50)
      if (kind === "pause")
        return rect(0.22, 0.15, 0.40, 0.85) + rect(0.60, 0.15, 0.78, 0.85)
      return tri(0.22, 0.12, 0.22, 0.88, 0.82, 0.50)
    }

    Shape {
      anchors.fill: parent
      layer.enabled: true
      layer.samples: 4

      ShapePath {
        fillColor: icon.tint
        strokeColor: "transparent"
        strokeWidth: -1
        PathSvg { path: icon.pathData }
      }
    }
  }

  component CoverArt: Item {
    id: ca
    property string source: ""
    property real radius: 8
    property real glyphSize: 16
    property int front: 0
    property int duration: 400

    readonly property bool hasImage: source !== "" && (imgA.status === Image.Ready || imgB.status === Image.Ready)

    onSourceChanged: {
      if (source === "") {
        imgA.source = ""
        imgB.source = ""
        return
      }
      var backIsA = front !== 0
      var back = backIsA ? imgA : imgB
      back.source = source
      if (back.status === Image.Ready && back.source.toString() === source)
        front = backIsA ? 0 : 1
    }

    Component.onCompleted: {
      if (source !== "") imgA.source = source
    }

    Rectangle {
      id: caMask
      anchors.fill: parent
      radius: ca.radius
      visible: false
      layer.enabled: true
    }

    Item {
      anchors.fill: parent
      layer.enabled: true
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: caMask
      }

      Image {
        id: imgA
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        mipmap: true
        opacity: ca.front === 0 && ca.source !== "" && status === Image.Ready ? 1 : 0
        scale: 0.96 + 0.04 * opacity
        Behavior on opacity { NumberAnimation { duration: ca.duration; easing.type: Easing.InOutQuad } }
        onStatusChanged: if (status === Image.Ready && ca.source !== "") ca.front = 0
      }

      Image {
        id: imgB
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        mipmap: true
        opacity: ca.front === 1 && ca.source !== "" && status === Image.Ready ? 1 : 0
        scale: 0.96 + 0.04 * opacity
        Behavior on opacity { NumberAnimation { duration: ca.duration; easing.type: Easing.InOutQuad } }
        onStatusChanged: if (status === Image.Ready && ca.source !== "") ca.front = 1
      }
    }

    Text {
      anchors.centerIn: parent
      text: "♪"
      font.pixelSize: ca.glyphSize
      color: MatugenColors.borderSoft
      opacity: ca.hasImage ? 0 : 1
      Behavior on opacity { NumberAnimation { duration: ca.duration } }
    }
  }

  property int geometryEpoch: 0
  Timer {
    id: geometrySettleTimer
    interval: 800
    running: true
    repeat: false
    onTriggered: root.geometryEpoch++
  }

  readonly property var musicLayout: LayoutMath.getLayout(
    "music", 0, 0, Screen.width, Screen.height, Config.uiScale
  )

  IpcHandler {
    target: "music"
    function toggle(): void {
      root.playerExpanded = !root.playerExpanded
    }
  }

  // Player selection 
  property var selectedPlayer: null

  function isValidPlayer(p) {
    return p && p.canPlay && p.trackTitle && p.trackTitle.length > 0
  }

  readonly property var validPlayers: {
    var list = Mpris.players.values
    var out = []
    if (!list) return out
    for (var i = 0; i < list.length; i++) {
      if (isValidPlayer(list[i])) out.push(list[i])
    }
    return out
  }

  function selectPlayer(p) {
    root.selectedPlayer = p
  }

  readonly property var player: {
    var list = Mpris.players.values
    if (!list || list.length === 0)
      return null

    if (selectedPlayer && list.indexOf(selectedPlayer) !== -1 && isValidPlayer(selectedPlayer))
      return selectedPlayer

    for (var i = 0; i < list.length; i++) {
      if (isValidPlayer(list[i]) && list[i].isPlaying)
        return list[i]
    }
    for (var j = 0; j < list.length; j++) {
      if (isValidPlayer(list[j]))
        return list[j]
    }
    return null
  }

  onPlayerChanged: progressTrack.displayPosition = player ? player.position : 0

  function normalizeSeconds(val) {
    if (!val || val <= 0) return 0
    if (val > 36000) return val / 1000000
    return val
  }

  function formatTime(sec) {
    var normalized = normalizeSeconds(sec)
    if (!normalized || normalized <= 0)
      return "--:--"

    var total = Math.floor(normalized)
    var hours = Math.floor(total / 3600)
    var minutes = Math.floor((total % 3600) / 60)
    var seconds = total % 60
    var mm = (hours > 0 && minutes < 10) ? "0" + minutes : String(minutes)
    var ss = (seconds < 10 ? "0" : "") + seconds

    return hours > 0 ? (hours + ":" + mm + ":" + ss) : (minutes + ":" + ss)
  }

  function playerLabel(p) {
    if (!p) return "?"
    var name = p.identity || p.desktopEntry || ""
    if (name.length > 0) return name
    return p.trackTitle ? p.trackTitle : "Player"
  }

  readonly property string artist: player && player.trackArtist ? player.trackArtist : ""
  readonly property string album: player && player.trackAlbum ? player.trackAlbum : ""
  readonly property string title: player && player.trackTitle ? player.trackTitle : ""
  readonly property string rawArt: player && player.trackArtUrl ? String(player.trackArtUrl).trim() : ""

  readonly property string pageUrl: {
    if (!player) return ""
    var m = player.metadata
    return m && m["xesam:url"] ? String(m["xesam:url"]) : ""
  }

  function ytThumbs(vid) {
    var b = "https://i.ytimg.com/vi/" + vid + "/"
    return [b + "maxresdefault.jpg", b + "sddefault.jpg", b + "hq720.jpg", b + "hqdefault.jpg"]
  }

  readonly property var coverCandidates: {
    var raw = rawArt
    var out = []

    if (/^https?:/.test(raw)) {
      if (/(googleusercontent\.com|ggpht\.com)/.test(raw)) {
        var base = raw.split("=")[0]
        out = [base + "=w1200-h1200-l90-rj", base + "=s1200", base + "=s0", raw]
      } else {
        var m = raw.match(/\/(?:vi|vi_webp)\/([^\/?&#]+)/)
        if (m) out = ytThumbs(m[1]).concat([raw])
        else if (/ytimg\.com/.test(raw)) {
          var names = ["maxresdefault", "sddefault", "hq720", "hqdefault"]
          for (var i = 0; i < names.length; i++)
            out.push(raw.replace(/(default|hqdefault|mqdefault|sddefault|hq720)\.(jpg|webp)/, names[i] + ".jpg"))
          out.push(raw)
        } else out = [raw]
      }
    } else if (raw.length > 0) {
      out = [raw.indexOf("://") === -1 ? "file://" + raw : raw]
    }

    if (out.length === 0) {
      var y = pageUrl.match(/(?:youtube\.com\/(?:watch\?(?:.*&)?v=|shorts\/|embed\/)|youtu\.be\/)([\w-]{11})/)
      if (y) out = ytThumbs(y[1])
    }
    return out
  }

  property int coverIndex: 0
  onCoverCandidatesChanged: coverIndex = 0

  readonly property string coverPath:
    coverIndex < coverCandidates.length ? coverCandidates[coverIndex] : ""

  Image {
    source: root.coverPath
    visible: false
    asynchronous: true
    onStatusChanged: if (status === Image.Error) root.coverIndex++
  }

  // Cover color sampling
  // sampledColor is the dominant color of the current cover. hasSampled is false
  // when there is no cover, so the UI falls back to the theme border color.
  property color sampledColor: MatugenColors.border
  property bool hasSampled: false

  Canvas {
    id: colorProbe
    width: 16
    height: 16
    opacity: 0
    renderTarget: Canvas.Image

    property string src: root.coverPath

    onSrcChanged: {
      if (src === "") {
        root.hasSampled = false
        return
      }
      // A url the canvas already holds (skip then prev) never fires imageLoaded
      // again, so repaint straight away instead of waiting for it.
      if (isImageLoaded(src)) requestPaint()
      else loadImage(src)
    }

    Component.onCompleted: {
      if (src !== "") {
        if (isImageLoaded(src)) requestPaint()
        else loadImage(src)
      }
    }

    onImageLoaded: requestPaint()

    onPaint: {
      if (src === "" || !isImageLoaded(src)) return

      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.drawImage(src, 0, 0, width, height)

      var data = ctx.getImageData(0, 0, width, height).data
      var rSum = 0, gSum = 0, bSum = 0, wSum = 0

      for (var i = 0; i < data.length; i += 4) {
        var r = data[i] / 255
        var g = data[i + 1] / 255
        var b = data[i + 2] / 255
        var mx = Math.max(r, g, b)
        var mn = Math.min(r, g, b)
        var sat = mx > 0 ? (mx - mn) / mx : 0

        // skip near black and near white pixels, favor saturated ones
        var w = 0.05 + sat * sat
        if (mx < 0.10) w *= 0.05
        if (mn > 0.92) w *= 0.05

        rSum += r * w
        gSum += g * w
        bSum += b * w
        wSum += w
      }

      if (wSum <= 0) return

      var avg = Qt.rgba(rSum / wSum, gSum / wSum, bSum / wSum, 1)
      var h = avg.hsvHue
      var sa = avg.hsvSaturation
      var v = avg.hsvValue

      if (h < 0 || sa < 0.12) {
        // gray cover, keep it neutral
        root.sampledColor = Qt.hsva(0, 0, Math.max(0.55, Math.min(0.85, v)), 1)
      } else {
        sa = Math.min(1.0, Math.max(0.5, sa))
        v = Math.max(0.65, Math.min(0.95, v))
        root.sampledColor = Qt.hsva(h, sa, v, 1)
      }
      root.hasSampled = true
    }
  }

  readonly property real lengthSec: {
    if (!player) return 0
    if (player.lengthSupported) {
      var l = normalizeSeconds(player.length)
      if (l > 0) return l
    }
    var m = player.metadata
    var us = m && m["mpris:length"] ? Number(m["mpris:length"]) : 0
    return us > 0 ? us / 1000000 : 0
  }

  readonly property string positionStr: formatTime(progressTrack.displayPosition)
  readonly property string lengthStr: lengthSec > 0 ? formatTime(lengthSec) : "--:--"
  readonly property bool isPlaying: player && player.isPlaying
  readonly property string status: player
    ? (player.isPlaying ? "Playing" : "Paused")
    : "Stopped"

  Timer {
    interval: 1000
    repeat: true
    running: !root.playerExpanded && root.isPlaying && Config.mediaSecondaryInfo === "duration" && !root.vertical
    onTriggered: {
      if (!root.player) return
      root.player.positionChanged()
      progressTrack.displayPosition = root.player.position
    }
  }

  property bool entered: false
  property int cascadeIndex: 1
  property bool playerExpanded: false
  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }

  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutBack } } }
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

  // Pill
  Rectangle {
    id: pillBg
    height: root.vertical ? barColumn.implicitHeight + s(16) : s(50)
    width: root.vertical ? s(50) : (barRow.implicitWidth + s(24))
    radius: s(Config.uiRadius)
    color: pillHover.containsMouse || root.playerExpanded
      ? Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b)
      : Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: Config.solidBarActive ? 0 : 1
    anchors.verticalCenter: parent.verticalCenter

    scale: pillHover.containsMouse ? 1.03 : 1.0
    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
    Behavior on color { ColorAnimation { duration: 200 } }
    Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

    MouseArea {
      id: pillHover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.playerExpanded = !root.playerExpanded
    }

    Row {
      id: barRow
      visible: !root.vertical
      anchors.centerIn: parent
      spacing: s(8)
      height: s(32)

      Rectangle {
        visible: Config.mediaShowIcon
        width: s(32); height: s(32); radius: s(8)
        color: MatugenColors.bgElevated
        border.color: MatugenColors.borderSoft
        border.width: Config.solidBarActive ? 0 : 1
        anchors.verticalCenter: parent.verticalCenter

        CoverArt {
          anchors.fill: parent
          source: root.coverPath
          radius: s(8)
          glyphSize: s(16)
        }
      }

      Column {
        spacing: 1
        anchors.verticalCenter: parent.verticalCenter
        width: s(Config.mediaWidth)
        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        Item {
          id: pillMarqueeItem
          width: parent.width
          height: s(15)
          clip: true

          property bool shouldScroll: pillTitleText.implicitWidth > pillMarqueeItem.width

          Row {
            id: pillMarqueeRow
            x: 0
            height: parent.height
            spacing: s(40)

            Text {
              id: pillTitleText
              text: player ? player.trackTitle : "Nothing Playing"
              color: MatugenColors.text
              font.pixelSize: s(12)
              font.weight: Font.Bold
              height: parent.height
              verticalAlignment: Text.AlignVCenter
            }

            Text {
              text: player ? player.trackTitle : "Nothing Playing"
              color: MatugenColors.text
              font.pixelSize: s(12)
              font.weight: Font.Bold
              height: parent.height
              verticalAlignment: Text.AlignVCenter
              visible: pillMarqueeItem.shouldScroll
            }
          }

          SequentialAnimation {
            id: pillMarqueeAnim
            loops: Animation.Infinite
            running: pillMarqueeItem.shouldScroll && pillTitleText.implicitWidth > 0
            PauseAnimation { duration: 2000 }
            NumberAnimation {
              target: pillMarqueeRow; property: "x"
              from: 0; to: -(pillTitleText.implicitWidth + s(40))
              duration: pillTitleText.implicitWidth * 15
              easing.type: Easing.Linear
            }
            PauseAnimation { duration: 1000 }
          }

          onShouldScrollChanged: {
            if (!pillMarqueeItem.shouldScroll) { pillMarqueeAnim.stop(); pillMarqueeRow.x = 0 }
            else pillMarqueeAnim.restart()
          }

          Rectangle {
            anchors.left: parent.left
            width: s(12); height: parent.height
            visible: pillMarqueeItem.shouldScroll
            z: 1
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 1) }
              GradientStop { position: 1.0; color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0) }
            }
          }

          Rectangle {
            anchors.right: parent.right
            width: s(12); height: parent.height
            visible: pillMarqueeItem.shouldScroll
            z: 1
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0) }
              GradientStop { position: 1.0; color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 1) }
            }
          }
        }

        Text {
          text: Config.mediaSecondaryInfo === "duration"
            ? (root.positionStr + " / " + root.lengthStr)
            : root.artist
          color: MatugenColors.textMuted; font.pixelSize: s(10)
          font.weight: Font.Bold
          elide: Text.ElideRight; width: parent.width
        }
      }

      Row {
        visible: Config.mediaShowControls
        spacing: s(6)
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
          model: ["⏮", root.isPlaying ? "⏸" : "▶", "⏭"]

          Rectangle {
            width: s(22); height: s(22)
            radius: s(6)
            property bool isHovered: miniMouse.containsMouse
            color: index === 1 && root.isPlaying ? MatugenColors.accent : (isHovered ? MatugenColors.bgElevated : "transparent")
            scale: isHovered ? 1.15 : 1.0
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: 150 } }

            MediaIcon {
              anchors.centerIn: parent
              size: s(12)
              kind: index === 0 ? "prev" : (index === 1 ? (root.isPlaying ? "pause" : "play") : "next")
              tint: index === 1 && root.isPlaying ? MatugenColors.accentText : MatugenColors.text
            }

            MouseArea {
              id: miniMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (index === 0 && player) player.previous()
                else if (index === 1 && player) player.togglePlaying()
                else if (index === 2 && player) player.next()
              }
            }
          }
        }
      }
    }

    // Vertical bar
    Column {
      id: barColumn
      visible: root.vertical
      anchors.centerIn: parent
      spacing: s(8)

      Rectangle {
        visible: Config.mediaShowIcon
        width: s(32); height: s(32); radius: s(8)
        color: MatugenColors.bgElevated
        border.color: MatugenColors.borderSoft
        border.width: Config.solidBarActive ? 0 : 1
        anchors.horizontalCenter: parent.horizontalCenter

        CoverArt {
          anchors.fill: parent
          source: root.coverPath
          radius: s(8)
          glyphSize: s(16)
        }
      }

      Column {
        visible: Config.mediaShowControls
        spacing: s(6)
        anchors.horizontalCenter: parent.horizontalCenter

        Repeater {
          model: ["⏮", root.isPlaying ? "⏸" : "▶", "⏭"]

          Rectangle {
            width: s(22); height: s(22)
            radius: index === 1 ? s(11) : s(6)
            property bool isHovered: miniMouseV.containsMouse
            anchors.horizontalCenter: parent.horizontalCenter
            color: index === 1 && root.isPlaying ? MatugenColors.accent : (isHovered ? MatugenColors.bgElevated : "transparent")
            scale: isHovered ? 1.15 : 1.0
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: 150 } }

            MediaIcon {
              anchors.centerIn: parent
              size: s(12)
              kind: index === 0 ? "prev" : (index === 1 ? (root.isPlaying ? "pause" : "play") : "next")
              tint: index === 1 && root.isPlaying ? MatugenColors.accentText : MatugenColors.text
            }

            MouseArea {
              id: miniMouseV
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (index === 0 && player) player.previous()
                else if (index === 1 && player) player.togglePlaying()
                else if (index === 2 && player) player.next()
              }
            }
          }
        }
      }
    }
  }

  // Popup Menu
  PanelWindow {
    id: popup
    visible: root.playerExpanded || animOpacity > 0.01
    implicitWidth: s(640)
    implicitHeight: s(285)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qs-music-popup"

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"

    property real animOpacity: root.playerExpanded ? 1.0 : 0.0
    Behavior on animOpacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    MouseArea {
      anchors.fill: parent
      onClicked: {
        root.playerExpanded = false
      }
    }

    FocusScope {
      anchors.fill: parent
      focus: root.playerExpanded
      Keys.onEscapePressed: root.playerExpanded = false

      Rectangle {
        id: popupCard
        width: root.musicLayout ? root.musicLayout.w : s(640)
        height: root.musicLayout ? root.musicLayout.h : s(285)
        x: {
          root.geometryEpoch
          var pillGlobal = pillBg.mapToItem(null, pillBg.width / 2, 0)
          var desiredX = pillGlobal.x - width / 2
          return Math.max(s(8), Math.min(Screen.width - width - s(8), desiredX))
        }
        y: {
          root.geometryEpoch
          return Config.barPosition === "bottom"
            ? (Screen.height - height - (root.musicLayout ? root.musicLayout.ry : s(70)))
            : (root.musicLayout ? root.musicLayout.ry : s(70))
        }
        color: MatugenColors.bgBase
        border.color: root.hasSampled ? root.sampledColor : MatugenColors.border
        border.width: 2
        radius: s(Config.uiRadius)
        Behavior on border.color { ColorAnimation { duration: 600; easing.type: Easing.InOutQuad } }

        opacity: popup.animOpacity
        scale: 0.94 + 0.06 * popup.animOpacity
        transform: Translate { y: (1 - popup.animOpacity) * -10 }
        MouseArea { anchors.fill: parent }

        // --- Blurred cover background ---
        Rectangle {
          id: bgMask
          anchors.fill: parent
          anchors.margins: popupCard.border.width
          radius: Math.max(0, popupCard.radius - popupCard.border.width)
          visible: false
          layer.enabled: true
        }

        Item {
          id: bgLayer
          anchors.fill: bgMask
          layer.enabled: true
          layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: bgMask
          }

          property string art: root.coverPath
          property bool showA: true

          // Load into the hidden image only. showA flips when that image is Ready.
          onArtChanged: {
            if (art === "") {
              bgImgA.source = ""
              bgImgB.source = ""
              return
            }
            var backIsA = !showA
            var back = backIsA ? bgImgA : bgImgB
            back.source = art
            // Same url already loaded in the hidden image: flip right away.
            if (back.status === Image.Ready && back.source.toString() === art)
              showA = backIsA
          }

          Component.onCompleted: {
            if (art !== "") bgImgA.source = art
          }

          // Oversized so the blur edge falloff is clipped away by the mask
          Item {
            id: blurHost
            anchors.fill: parent
            anchors.margins: -s(48)
            layer.enabled: true
            layer.effect: MultiEffect {
              blurEnabled: true
              blur: 1.0
              blurMax: 48
              saturation: 0.2
              brightness: -0.2
            }

            Image {
              id: bgImgA
              anchors.fill: parent
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              opacity: bgLayer.showA && status === Image.Ready ? 1.0 : 0.0
              Behavior on opacity { NumberAnimation { duration: 650; easing.type: Easing.InOutQuad } }
              onStatusChanged: if (status === Image.Ready && bgLayer.art !== "") bgLayer.showA = true
            }

            Image {
              id: bgImgB
              anchors.fill: parent
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              opacity: !bgLayer.showA && status === Image.Ready ? 1.0 : 0.0
              Behavior on opacity { NumberAnimation { duration: 650; easing.type: Easing.InOutQuad } }
              onStatusChanged: if (status === Image.Ready && bgLayer.art !== "") bgLayer.showA = false
            }
          }

          // Dark overlay keeps text readable
          Rectangle {
            anchors.fill: parent
            color: Qt.alpha(MatugenColors.bgBase, 0.8)
          }
        }

        // --- Player switcher ---
        Dropdown {
          id: playerDropdown
          visible: root.validPlayers.length > 1
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.topMargin: s(14)
          anchors.rightMargin: s(14)
          z: 40

          s: root.s
          boxWidth: 140
          boxHeight: 26
          rowHeight: 28
          fontSize: 11
          boundsItem: popupCard
          options: root.validPlayers.map(p => root.playerLabel(p))
          currentIndex: root.validPlayers.indexOf(root.player)
          onPicked: (index, value) => root.selectPlayer(root.validPlayers[index])
        }

        Row {
          anchors.fill: parent
          anchors.margins: s(18)
          spacing: s(16)

          Rectangle {
            id: coverRect
            width: s(200); height: s(200)
            anchors.verticalCenter: parent.verticalCenter
            radius: s(13)
            color: MatugenColors.bgElevated
            border.color: MatugenColors.borderSoft; border.width: 1

            CoverArt {
              anchors.fill: parent
              source: root.coverPath
              radius: s(13)
              glyphSize: s(64)
              duration: 550
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - s(216)
            spacing: 0

            Row {
              width: parent.width
              height: s(24)
              spacing: s(6)

              Item {
                id: marqueeItem
                width: parent.width
                height: s(20)
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                property bool shouldScroll: titleText.implicitWidth > marqueeItem.width

                Row {
                  id: marqueeRow
                  x: 0
                  height: parent.height
                  spacing: s(40)

                  Text {
                    id: titleText
                    text: player ? player.trackTitle : "Nothing Playing"
                    color: MatugenColors.text
                    font.pixelSize: s(15)
                    font.weight: Font.Bold
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                  }

                  Text {
                    text: player ? player.trackTitle : "Nothing Playing"
                    color: MatugenColors.text
                    font.pixelSize: s(15)
                    font.weight: Font.Bold
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    visible: marqueeItem.shouldScroll
                  }
                }

                SequentialAnimation {
                  id: marqueeAnim
                  loops: Animation.Infinite
                  running: marqueeItem.shouldScroll && titleText.implicitWidth > 0 && root.playerExpanded
                  PauseAnimation { duration: 2000 }
                  NumberAnimation {
                    target: marqueeRow; property: "x"
                    from: 0; to: -(titleText.implicitWidth + s(40))
                    duration: titleText.implicitWidth * 15
                    easing.type: Easing.Linear
                  }
                  PauseAnimation { duration: 1000 }
                }

                onShouldScrollChanged: {
                  if (!marqueeItem.shouldScroll) { marqueeAnim.stop(); marqueeRow.x = 0 }
                  else marqueeAnim.restart()
                }

                Connections {
                  target: root
                  function onPlayerExpandedChanged() {
                    if (root.playerExpanded && root.player)
                      progressTrack.displayPosition = root.player.position
                  }
                }

                Rectangle {
                  anchors.left: parent.left
                  width: s(24); height: parent.height
                  visible: marqueeItem.shouldScroll
                  z: 1
                  gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 1) }
                    GradientStop { position: 1.0; color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0) }
                  }
                }

                Rectangle {
                  anchors.right: parent.right
                  width: s(24); height: parent.height
                  visible: marqueeItem.shouldScroll
                  z: 1
                  gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0) }
                    GradientStop { position: 1.0; color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 1) }
                  }
                }
              }
            } // end title row

            Text {
              text: root.artist
              color: MatugenColors.textMuted; font.pixelSize: s(13)
              elide: Text.ElideRight; width: parent.width
            }

            Text {
              text: root.album
              color: MatugenColors.textDim; font.pixelSize: s(11)
              elide: Text.ElideRight; width: parent.width
              visible: root.album !== ""
            }

            Item { width: 1; height: s(20) }

            Item {
              id: progressTrack
              width: parent.width
              height: s(16)

              Connections {
                target: root
                function onPlayerExpandedChanged() {
                  if (root.playerExpanded) Cava.registerConsumer()
                  else Cava.unregisterConsumer()
                }
              }
              Component.onCompleted: {
                if (root.playerExpanded) Cava.registerConsumer()
              }
              Component.onDestruction: {
                if (root.playerExpanded) Cava.unregisterConsumer()
              }

              property bool dragging: false
              property real dragPct: 0
              property real displayPosition: player ? player.position : 0

              readonly property real shownPct: dragging
                ? dragPct
                : (root.lengthSec > 0
                  ? Math.min(100, root.normalizeSeconds(displayPosition) / root.lengthSec * 100)
                  : 0)

              Connections {
                target: root.player
                ignoreUnknownSignals: true
                function onPositionChanged() {
                  if (root.player) progressTrack.displayPosition = root.player.position
                }
                function onTrackChanged() {
                  if (root.player) progressTrack.displayPosition = root.player.position
                }
              }

              Timer {
                interval: 500
                running: root.playerExpanded && root.isPlaying && !progressTrack.dragging
                repeat: true
                onTriggered: {
                  if (!root.player) return
                  root.player.positionChanged()
                  progressTrack.displayPosition = root.player.position
                }
              }

              Item {
                id: trackVis
                anchors.bottom: parent.bottom
                anchors.bottomMargin: s(4)
                width: parent.width
                height: s(10)
                clip: false

                property int sampleCount: 48
                property var smoothLevels: []

                Component.onCompleted: {
                  var init = []
                  for (var i = 0; i < sampleCount; i++) init.push(0.0)
                  smoothLevels = init
                }

                property var processedBars: {
                  var source = Cava.barLevels
                  var count = sampleCount
                  var out = []

                  if (!root.isPlaying || !source || source.length === 0) {
                    for (var i = 0; i < count; i++) out.push(0.0)
                    return out
                  }

                  var srcLen = source.length
                  var half = (count - 1) / 2

                  for (var j = 0; j < count; j++) {
                    var distFromCenter = Math.abs(j - half)
                    var norm = half > 0 ? (distFromCenter / half) : 0
                    var pos = Math.pow(norm, 1.25) * (srcLen - 1)
                    var idx0 = Math.floor(pos)
                    var idx1 = Math.min(srcLen - 1, idx0 + 1)
                    var frac = pos - idx0

                    var v0 = source[idx0] || 0.0
                    var v1 = source[idx1] || 0.0
                    var rawVal = v0 + (v1 - v0) * frac

                    var val = rawVal < 0.015 ? 0.0 : Math.pow((rawVal - 0.015) / 0.985, 0.7)
                    val = Math.max(0.0, Math.min(1.0, val))
                    out.push(val)
                  }

                  var smoothed = []
                  for (var k = 0; k < count; k++) {
                    var prev = k > 0 ? out[k - 1] : out[k]
                    var curr = out[k]
                    var next = k < count - 1 ? out[k + 1] : out[k]
                    var sm = prev * 0.25 + curr * 0.5 + next * 0.25

                    var edgeNorm = Math.sin((k / Math.max(1, count - 1)) * Math.PI)
                    var edgeFactor = Math.min(1.0, edgeNorm * 2.0)
                    edgeFactor = edgeFactor * edgeFactor * (3.0 - 2.0 * edgeFactor)
                    smoothed.push(sm * edgeFactor)
                  }

                  return smoothed
                }

                Timer {
                  interval: 16
                  running: root.playerExpanded && Cava.processEnabled
                  repeat: true
                  onTriggered: {
                    var targets = trackVis.processedBars
                    var current = trackVis.smoothLevels
                    var updated = []

                    for (var i = 0; i < trackVis.sampleCount; i++) {
                      var target = (targets && i < targets.length) ? targets[i] : 0.0
                      var cur = (current && i < current.length) ? current[i] : 0.0
                      var factor = target > cur ? 0.45 : 0.22
                      updated.push(cur + (target - cur) * factor)
                    }

                    trackVis.smoothLevels = updated
                    waveCanvas.requestPaint()
                  }
                }

                Rectangle {
                  anchors.fill: parent
                  radius: s(3)
                  color: MatugenColors.bgElevated
                }

                Item {
                  id: waveReveal
                  anchors.bottom: parent.top
                  width: parent.width * (progressTrack.shownPct / 100)
                  height: s(20)
                  clip: true
                  Behavior on width {
                    enabled: !progressTrack.dragging
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                  }

                  Canvas {
                    id: waveCanvas
                    width: trackVis.width
                    height: s(20)
                    opacity: 0.9

                    onPaint: {
                      var ctx = getContext("2d")
                      var w = width
                      var h = height

                      ctx.reset()
                      ctx.clearRect(0, 0, w, h)

                      var levels = trackVis.smoothLevels
                      if (!levels || levels.length === 0) return

                      var count = levels.length
                      var pts = []
                      for (var i = 0; i < count; i++) {
                        var px = (i / (count - 1)) * w
                        var py = h - (levels[i] * h * 0.98)
                        pts.push({ x: px, y: py })
                      }

                      ctx.beginPath()
                      ctx.moveTo(0, h)
                      ctx.lineTo(pts[0].x, pts[0].y)

                      for (var k = 0; k < pts.length - 1; k++) {
                        var p0 = pts[k]
                        var p1 = pts[k + 1]
                        var mx = (p0.x + p1.x) / 2
                        var my = (p0.y + p1.y) / 2
                        ctx.quadraticCurveTo(p0.x, p0.y, mx, my)
                      }

                      var last = pts[pts.length - 1]
                      ctx.lineTo(last.x, last.y)
                      ctx.lineTo(w, h)
                      ctx.closePath()

                      ctx.fillStyle = MatugenColors.accent
                      ctx.fill()
                    }
                  }
                }

                Rectangle {
                  id: progressFillMask
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: parent.width * (progressTrack.shownPct / 100)
                  color: "transparent"
                  clip: true
                  Behavior on width {
                    enabled: !progressTrack.dragging
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                  }

                  Rectangle {
                    width: trackVis.width
                    height: trackVis.height
                    radius: s(3)
                    color: MatugenColors.accent
                  }
                }
              }

              Rectangle {
                width: s(13); height: s(13); radius: s(7)
                color: MatugenColors.text
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(parent.width - width, parent.width * (progressTrack.shownPct / 100) - width / 2))
                scale: progressTrack.dragging ? 1.2 : 1.0
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
              }

              MouseArea {
                id: timelineArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                function pctFromX(mx) {
                  return Math.max(0, Math.min(100, (mx / width) * 100))
                }

                onPressed: (mouse) => {
                  if (!root.player || root.lengthSec <= 0) return
                  progressTrack.dragging = true
                  progressTrack.dragPct = pctFromX(mouse.x)
                }
                onPositionChanged: (mouse) => {
                  if (progressTrack.dragging)
                    progressTrack.dragPct = pctFromX(mouse.x)
                }
                onReleased: (mouse) => {
                  if (!progressTrack.dragging) return
                  if (root.player && root.lengthSec > 0) {
                    var target = (pctFromX(mouse.x) / 100) * root.lengthSec
                    var current = root.normalizeSeconds(progressTrack.displayPosition)
                    root.player.seek(target - current)
                    progressTrack.displayPosition = target
                  }
                  progressTrack.dragging = false
                }
              }
            }

            Item {
              width: parent.width
              height: s(16)

              Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.positionStr
                color: MatugenColors.textMuted
                font.pixelSize: s(12)
                font.weight: Font.Bold
                font.family: "JetBrainsMono Nerd Font"
              }

              Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.lengthStr
                color: MatugenColors.textMuted
                font.pixelSize: s(12)
                font.weight: Font.Bold
                font.family: "JetBrainsMono Nerd Font"
              }
            }

            Item { width: 1; height: s(16) }

            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: s(20)

              Repeater {
                model: ["⏮", root.isPlaying ? "⏸" : "▶", "⏭"]

                Rectangle {
                  width: index === 1 ? s(54) : s(44)
                  height: index === 1 ? s(54) : s(44)
                  radius: s(10)
                  property bool isHovered: popupMouse.containsMouse
                  color: index === 1 && root.isPlaying ? MatugenColors.accent : (isHovered ? MatugenColors.bgElevated : "transparent")
                  scale: isHovered ? (index === 1 ? 1.08 : 1.1) : 1.0
                  Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                  Behavior on color { ColorAnimation { duration: 150 } }

                  MediaIcon {
                    anchors.centerIn: parent
                    size: index === 1 ? s(26) : s(20)
                    kind: index === 0 ? "prev" : (index === 1 ? (root.isPlaying ? "pause" : "play") : "next")
                    tint: index === 1 && root.isPlaying ? MatugenColors.accentText : MatugenColors.text
                  }

                  MouseArea {
                    id: popupMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (index === 0 && player) player.previous()
                      else if (index === 1 && player) player.togglePlaying()
                      else if (index === 2 && player) player.next()
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
