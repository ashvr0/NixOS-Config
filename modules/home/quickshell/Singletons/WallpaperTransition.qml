pragma Singleton
import QtQuick
import Quickshell

Singleton {
  id: root

  readonly property var allTypes: ["fade", "wipe", "circle", "swipe"]
  readonly property var swipeDirections: ["left", "right", "top", "bottom", "top-left", "top-right", "bottom-left", "bottom-right"]

  function pick(list) { return list[Math.floor(Math.random() * list.length)] }
  function fmt(d) { return String(Math.round(Math.max(0.1, Math.min(10, d)) * 10) / 10) }

  function activeTypes() {
    if (Config.wallpaperTransitionMode === "random") return root.allTypes
    let set = Config.wallpaperTransitionSet.split(",").filter(t => root.allTypes.indexOf(t) !== -1)
    return set.length > 0 ? set : root.allTypes
  }

  // Edge and corner swipes. awww angle: 0 starts at the right edge, 90 at the top,
  // 180 at the left, 270 at the bottom. Corners sit between the edges.
  readonly property var swipeAngles: ({
    "right": 0, "top-right": 45, "top": 90, "top-left": 135,
    "left": 180, "bottom-left": 225, "bottom": 270, "bottom-right": 315
  })

  // Builds one transition plan. clickPos is optional: { x, y } as 0..1 fractions from the top left.
  // Pass it when a wallpaper is set from the desktop menu so the circle starts at the click.
  // angle uses the same convention everywhere: 0 starts at the right edge, 90 top, 180 left, 270 bottom.
  function plan(clickPos) {
    let type = root.pick(root.activeTypes())
    let p = { type: type, duration: 700, angle: 0, ox: 0.5, oy: 0.5 }
    let sec = 0.7

    if (type === "fade") {
      sec = Config.wallpaperFadeDuration
    } else if (type === "wipe") {
      sec = Config.wallpaperWipeDuration
      let o = Config.wallpaperWipeOrientation
      if (o === "random") o = root.pick(["horizontal", "vertical"])
      p.angle = o === "vertical" ? root.pick([90, 270]) : root.pick([0, 180])
    } else if (type === "circle") {
      sec = Config.wallpaperCircleDuration
      if (clickPos) {
        p.ox = clickPos.x
        p.oy = clickPos.y
      } else if (Config.wallpaperCircleOrigin !== "center") {
        p.ox = 0.1 + Math.random() * 0.8
        p.oy = 0.1 + Math.random() * 0.8
      }
    } else {
      sec = Config.wallpaperSwipeDuration
      let d = Config.wallpaperSwipeDirection
      if (root.swipeDirections.indexOf(d) === -1) d = root.pick(root.swipeDirections)
      p.angle = root.swipeAngles[d]
    }

    p.duration = Math.round(Math.max(0.1, Math.min(10, sec)) * 1000)
    return p
  }
}
