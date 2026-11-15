import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../Singletons"

Variants {
  id: wpRoot
  model: Quickshell.screens

  // Fires when a screen has fully finished showing a wallpaper (after the reveal ends)
  signal settled(string path)

  delegate: Component {
    PanelWindow {
      id: bg
      required property var modelData
      screen: modelData

      WlrLayershell.namespace: "wallpaper-bg"
      WlrLayershell.layer: WlrLayer.Background
      focusable: false
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}
      color: "#000000"
      anchors { top: true; bottom: true; left: true; right: true }

      readonly property string stateFile: Quickshell.env("HOME") + "/.cache/wallpaper-picker/current_" + bg.screen.name

      // Committed wallpaper (what is fully on screen at rest)
      property string path: ""

      // Two image layers. The one on top is the newest wallpaper.
      property string pathA: ""
      property string pathB: ""
      property bool topIsA: true

      // Transition state
      property string pending: ""
      property bool animating: false
      property real progress: 1.0
      property string tType: "fade"
      property real tAngle: 0
      property real tOx: 0.5
      property real tOy: 0.5
      property int tDuration: 700

      function persist(newPath) {
        Quickshell.execDetached(["bash", "-c",
          "mkdir -p '" + Quickshell.env("HOME") + "/.cache/wallpaper-picker' && printf '%s' '" + newPath.replace(/'/g, "'\\''") + "' > '" + bg.stateFile + "'"
        ])
      }

      // Commit the result of a transition and release the old layer
      function commit() {
        bg.animating = false
        bg.progress = 1.0
        let done = bg.pending
        if (done !== "") bg.path = done
        bg.pending = ""
        loadGuard.stop()
        if (done !== "") wpRoot.settled(done)
      }

      // Stop a running transition and keep its result
      function finishNow() {
        if (!bg.animating) return
        anim.stop()
        bg.commit()
      }

      // Start the reveal once the incoming layer is fully decoded
      function tryBegin() {
        if (bg.pending === "" || bg.animating) return
        let backIsA = !bg.topIsA
        let backImg = backIsA ? imgA : imgB
        let backPath = backIsA ? bg.pathA : bg.pathB
        if (backPath !== bg.pending || backImg.status !== Image.Ready) return

        loadGuard.stop()
        bg.progress = 0.0
        bg.topIsA = !bg.topIsA
        bg.animating = true
        anim.restart()
      }

      function setWallpaper(newPath, plan) {
        bg.persist(newPath)
        bg.finishNow()
        if (newPath === bg.path) {
          // Drop any half loaded wallpaper from an earlier quick pick
          bg.pending = ""
          loadGuard.stop()
          wpRoot.settled(newPath)
          return
        }

        // Nothing on screen yet (first run): show it directly
        if (bg.path === "") {
          bg.pathA = newPath
          bg.topIsA = true
          bg.path = newPath
          wpRoot.settled(newPath)
          return
        }

        let p = plan || WallpaperTransition.plan(null)
        bg.tType = p.type
        bg.tAngle = p.angle
        bg.tOx = p.ox
        bg.tOy = p.oy
        bg.tDuration = p.duration
        bg.pending = newPath

        // Load the new wallpaper into whichever layer is behind
        if (bg.topIsA) bg.pathB = newPath
        else bg.pathA = newPath

        loadGuard.restart()
        // Covers the case where the layer already holds this image
        bg.tryBegin()
      }

      Component.onCompleted: restoreProc.running = true

      // If the image never becomes Ready (missing file, decode error), snap to it
      Timer {
        id: loadGuard
        interval: 4000
        repeat: false
        onTriggered: {
          if (bg.pending !== "" && !bg.animating) {
            console.log("[wp] load timeout, snapping to", bg.pending)
            if (bg.topIsA) { bg.pathA = bg.pending } else { bg.pathB = bg.pending }
            bg.topIsA = !bg.topIsA
            bg.commit()
          }
        }
      }

      Process {
        id: restoreProc
        running: false
        command: ["bash", "-c", "[ -f '" + bg.stateFile + "' ] && cat '" + bg.stateFile + "' || true"]
        stdout: StdioCollector {
          onStreamFinished: {
            let saved = this.text.trim()
            if (saved !== "" && bg.path === "") {
              bg.pathA = saved
              bg.topIsA = true
              bg.path = saved
            }
          }
        }
      }

      NumberAnimation {
        id: anim
        target: bg
        property: "progress"
        from: 0.0
        to: 1.0
        duration: bg.tDuration
        easing.type: Easing.InOutCubic
        onFinished: if (bg.animating) bg.commit()
      }

      // Each image sits in a wrapper Item that carries the layer order and fade opacity.
      Item {
        id: wrapA
        anchors.fill: parent
        z: bg.topIsA ? 2 : 1
        visible: bg.pathA !== ""
        opacity: (bg.animating && bg.topIsA && bg.tType === "fade") ? bg.progress : 1.0

        Image {
          id: imgA
          anchors.fill: parent
          source: bg.pathA !== "" ? "file://" + bg.pathA : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: false
          sourceSize.width: bg.width
          sourceSize.height: bg.height
          onStatusChanged: {
            if (status === Image.Error) console.log("[wp] image A failed", source)
            bg.tryBegin()
          }
        }
      }

      Item {
        id: wrapB
        anchors.fill: parent
        z: bg.topIsA ? 1 : 2
        visible: bg.pathB !== ""
        opacity: (bg.animating && !bg.topIsA && bg.tType === "fade") ? bg.progress : 1.0

        Image {
          id: imgB
          anchors.fill: parent
          source: bg.pathB !== "" ? "file://" + bg.pathB : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: false
          sourceSize.width: bg.width
          sourceSize.height: bg.height
          onStatusChanged: {
            if (status === Image.Error) console.log("[wp] image B failed", source)
            bg.tryBegin()
          }
        }
      }

      // Wipe, circle and swipe are drawn by a shader that blends the old and new
      // layers. The wrappers are rendered into textures and hidden while it runs.
      readonly property bool shaderActive: bg.animating && bg.tType !== "fade"

      ShaderEffectSource {
        id: srcA
        sourceItem: wrapA
        hideSource: bg.shaderActive
        live: true
        smooth: true
        visible: false
      }

      ShaderEffectSource {
        id: srcB
        sourceItem: wrapB
        hideSource: bg.shaderActive
        live: true
        smooth: true
        visible: false
      }

      ShaderEffect {
        id: reveal
        anchors.fill: parent
        z: 10
        visible: bg.shaderActive

        property var oldTex: bg.topIsA ? srcB : srcA
        property var newTex: bg.topIsA ? srcA : srcB
        property real progress: bg.progress
        property real feather: 2.0
        property real mode: bg.tType === "circle" ? 2.0 : 1.0
        property vector2d size: Qt.vector2d(bg.width, bg.height)
        property vector2d origin: Qt.vector2d(bg.tOx, bg.tOy)

        // Same convention as before: angle 0 starts at the right edge, 90 top, 180 left, 270 bottom
        readonly property real rad: bg.tAngle * Math.PI / 180
        property vector2d dir: Qt.vector2d(-Math.cos(rad), Math.sin(rad))
        property real halfExtent: (Math.abs(dir.x) * bg.width + Math.abs(dir.y) * bg.height) / 2
        property real maxRadius: Math.sqrt(
          Math.pow(Math.max(bg.tOx, 1 - bg.tOx) * bg.width, 2) +
          Math.pow(Math.max(bg.tOy, 1 - bg.tOy) * bg.height, 2))

        fragmentShader: Qt.resolvedUrl("wallpaper_transition.frag.qsb")
        onStatusChanged: if (status === ShaderEffect.Error) console.log("[wp] shader error:", log)
      }
    }
  }
}
