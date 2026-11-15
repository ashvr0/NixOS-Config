.pragma library

function place(side, w, h, anchorY, screenW, screenH, s) {
  var x
  if (side === "left") x = s(80)
  else if (side === "right") x = screenW - w - s(80)
  else x = screenW - w - s(8)

  var y
  if (side === "bottom") y = screenH - h - s(70)
  else if (side === "left" || side === "right") y = Math.max(s(10), Math.min(screenH - h - s(10), anchorY - h / 2))
  else y = s(70)

  return { x: x, y: y }
}