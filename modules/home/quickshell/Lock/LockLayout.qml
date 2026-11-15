pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Lock screen layout + lock settings. One JSON file, shared by the settings app
// (editor) and Lock.qml (reader).
//
// Layout space is 1920 x 1080. The lock screen and the editor scale that space to fit
// the real screen, so a saved layout works on any monitor.
// Two layers: "idle" (shown before you touch anything) and "login" (shown after a key
// press or click).
Singleton {
  id: store

  readonly property int refW: 1920
  readonly property int refH: 1080
  readonly property real gridSize: 20
  readonly property string dir: Quickshell.env("HOME") + "/.local/state/quickshell"
  readonly property string path: dir + "/lock-layout.json"

  // ---------- lock settings (persisted) ----------
  property bool blurOnInput: true
  property bool attemptLimits: false
  property int maxAttempts: 5
  property string bgMode: "follow"        // "follow" or "custom"
  property string customBgPath: ""
  readonly property real loginScale: 1.0  // fixed size of the login layer on the lock screen
  onBlurOnInputChanged: store.scheduleSave()
  onAttemptLimitsChanged: store.scheduleSave()
  onMaxAttemptsChanged: store.scheduleSave()
  onBgModeChanged: store.scheduleSave()
  onCustomBgPathChanged: store.scheduleSave()

  // ---------- editor state (not persisted) ----------
  property string selectedId: ""
  property bool snapToGrid: false

  // roles: uid, lyr, kind, ix, iy, iw, ih, iop, variant, showText
  property alias model: listModel
  ListModel { id: listModel }

  property bool loading: false
  property string pending: ""

  readonly property var types: [
    { type: "panel", label: "Card", icon: "\uf2d0", group: "lock", w: 1104, h: 576, minW: 200, minH: 120, maxW: 1920, maxH: 1080 },
    { type: "clock", label: "Clock", icon: "\uf017", group: "lock", w: 360, h: 140, minW: 120, minH: 50, maxW: 1400, maxH: 600,
      variants: [
        { id: "classic", label: "Classic", w: 360, h: 140 },
        { id: "seconds", label: "Seconds", w: 460, h: 140 },
        { id: "stacked", label: "Stacked", w: 220, h: 300 }
      ] },
    { type: "date", label: "Date", icon: "\uf073", group: "lock", w: 360, h: 36, minW: 120, minH: 20, maxW: 1000, maxH: 140 },
    { type: "avatar", label: "Avatar", icon: "\uf2bd", group: "lock", w: 172, h: 172, minW: 48, minH: 48, maxW: 600, maxH: 600 },
    { type: "user", label: "User", icon: "\uf007", group: "lock", w: 160, h: 35, minW: 40, minH: 24, maxW: 500, maxH: 90, hasText: true },
    { type: "status", label: "Status", icon: "\uf023", group: "lock", w: 160, h: 35, minW: 40, minH: 24, maxW: 500, maxH: 90, hasText: true },
    { type: "password", label: "Password", icon: "\uf084", group: "lock", w: 330, h: 53, minW: 200, minH: 36, maxW: 800, maxH: 110, unique: true,
      variants: [
        { id: "pill", label: "Pill", w: 330, h: 53 },
        { id: "minimal", label: "Minimal", w: 330, h: 53 }
      ] },
    { type: "keyboard", label: "Keyboard", icon: "\uf11c", group: "lock", w: 80, h: 35, minW: 40, minH: 24, maxW: 300, maxH: 90, hasText: true },
    { type: "battery", label: "Battery", icon: "\uf240", group: "lock", w: 80, h: 35, minW: 40, minH: 24, maxW: 300, maxH: 90, hasText: true },
    { type: "notifications", label: "Notifs", icon: "\uf0f3", group: "lock", w: 334, h: 557, minW: 220, minH: 160, maxW: 700, maxH: 1000 },

    { type: "weather", label: "Weather", icon: "\uf0c2", group: "widget", w: 290, h: 120, minW: 120, minH: 90, maxW: 700, maxH: 400,
  variants: [
    { id: "full", label: "Full", w: 290, h: 120 },
    { id: "compact", label: "Compact", w: 150, h: 120 }
  ] },
{ type: "music", label: "Music", icon: "\uf001", group: "widget", w: 300, h: 80, minW: 80, minH: 60, maxW: 800, maxH: 300,
  variants: [
    { id: "wide", label: "Wide", w: 300, h: 80 },
    { id: "cover", label: "Cover", w: 110, h: 110 }
  ] },
{ type: "cpu", label: "CPU", icon: "\uf2db", group: "widget", w: 90, h: 120, minW: 70, minH: 70, maxW: 500, maxH: 500, hasText: true },
{ type: "ram", label: "RAM", icon: "\uf538", group: "widget", w: 90, h: 120, minW: 70, minH: 70, maxW: 500, maxH: 500, hasText: true },
{ type: "temp", label: "Temp", icon: "\uf2c9", group: "widget", w: 90, h: 120, minW: 70, minH: 70, maxW: 500, maxH: 500, hasText: true },
{ type: "disk", label: "Disk", icon: "\uf0a0", group: "widget", w: 156, h: 120, minW: 70, minH: 70, maxW: 500, maxH: 500, hasText: true },
{ type: "net", label: "Net", icon: "\uf1eb", group: "widget", w: 120, h: 120, minW: 70, minH: 70, maxW: 500, maxH: 500, hasText: true }
  ]

  function def(type) {
    for (let i = 0; i < types.length; i++) if (types[i].type === type) return types[i]
    return null
  }

  function sizeFor(type, variant) {
    const d = def(type)
    if (!d) return { w: 200, h: 100 }
    if (d.variants) for (const v of d.variants) if (v.id === variant) return { w: v.w, h: v.h }
    return { w: d.w, h: d.h }
  }

  function group(g) { return types.filter(t => t.group === g) }

  function newId() { return Date.now().toString(36) + Math.floor(Math.random() * 46656).toString(36) }

  function indexOf(id) {
    for (let i = 0; i < listModel.count; i++) if (listModel.get(i).uid === id) return i
    return -1
  }

  function has(type) {
    for (let i = 0; i < listModel.count; i++) if (listModel.get(i).kind === type) return true
    return false
  }

  function makeItem(type, layer, x, y) {
    const d = def(type)
    const v = d && d.variants ? d.variants[0].id : ""
    const sz = sizeFor(type, v)
    return { uid: newId(), lyr: layer, kind: type, ix: Math.round(x), iy: Math.round(y), iw: sz.w, ih: sz.h, iop: 1.0, variant: v, showText: true }
  }

  function add(type, layer, cx, cy) {
    const d = def(type)
    if (!d) return ""
    if (d.unique && has(type)) return ""
    const sz = sizeFor(type, d.variants ? d.variants[0].id : "")
    const o = makeItem(type, layer, cx - sz.w / 2, cy - sz.h / 2)
    if (type === "panel") listModel.insert(0, o)
    else listModel.append(o)
    selectedId = o.uid
    scheduleSave()
    return o.uid
  }

  function update(id, patch) {
    const i = indexOf(id)
    if (i < 0) return
    for (const k in patch) listModel.setProperty(i, k, patch[k])
    scheduleSave()
  }

  function remove(id) {
    const i = indexOf(id)
    if (i < 0) return
    listModel.remove(i)
    if (selectedId === id) selectedId = ""
    scheduleSave()
  }

  // Default layout: matches the original single file lock card (1220 x 540, centered).
  // Left column 280 wide (weather, 2x2 stats, music), middle column with avatar, name, status,
  // password and keyboard, right column 380 wide for notifications. Every piece is movable.
  function defaultsFor(layer) {
    const L = (t, x, y, w, h, extra) => {
      const o = makeItem(t, layer, x, y)
      o.iw = w; o.ih = h
      if (extra) for (const k in extra) o[k] = extra[k]
      return o
    }
    if (layer === "idle") {
      return [ L("clock", 780, 420, 360, 140), L("date", 780, 565, 360, 36) ]
    }
    return [
      L("panel", 470, 280, 980, 494),
      L("weather", 490, 300, 300, 110),
      L("cpu", 490, 422, 146, 96),
      L("ram", 644, 422, 146, 96),
      L("disk", 490, 530, 146, 96),
      L("net", 644, 530, 146, 96),
      L("music", 490, 638, 300, 80),
      L("avatar", 877, 339, 151, 153),
      L("user", 884, 519, 144, 30),
      L("status", 861, 564, 191, 32),
      L("password", 821, 612, 270, 44),
      L("keyboard", 922, 668, 76, 32),
      L("notifications", 1152, 294, 279, 466)
    ]
  }

  function resetLayer(layer) {
    for (let i = listModel.count - 1; i >= 0; i--)
      if (listModel.get(i).lyr === layer) listModel.remove(i)
    for (const o of defaultsFor(layer)) listModel.append(o)
    selectedId = ""
    scheduleSave()
  }

  function toJson() {
    const items = []
    for (let i = 0; i < listModel.count; i++) {
      const it = listModel.get(i)
      items.push({ id: it.uid, layer: it.lyr, type: it.kind, x: it.ix, y: it.iy, w: it.iw, h: it.ih,
                   opacity: it.iop, variant: it.variant, showText: it.showText })
    }
    return JSON.stringify({
      settings: { blurOnInput: blurOnInput, attemptLimits: attemptLimits, maxAttempts: maxAttempts,
                  bgMode: bgMode, customBgPath: customBgPath },
      items: items
    }, null, 2)
  }

  function parse(text) {
    let data
    try { data = JSON.parse(text) } catch (e) { return false }
    if (!data || !Array.isArray(data.items)) return false
    loading = true
    const s = data.settings || {}
    if (s.blurOnInput !== undefined) blurOnInput = !!s.blurOnInput
    if (s.attemptLimits !== undefined) attemptLimits = !!s.attemptLimits
    if (isFinite(s.maxAttempts)) maxAttempts = Math.max(1, Math.min(10, Math.round(s.maxAttempts)))
    if (s.bgMode === "follow" || s.bgMode === "custom") bgMode = s.bgMode
    if (typeof s.customBgPath === "string") customBgPath = s.customBgPath
    listModel.clear()
    for (const o of data.items) {
      if (!o || !def(o.type) || (o.layer !== "idle" && o.layer !== "login")) continue
      if (![o.x, o.y, o.w, o.h].every(isFinite)) continue
      listModel.append({
        uid: String(o.id || newId()), lyr: o.layer, kind: o.type,
        ix: o.x, iy: o.y, iw: o.w, ih: o.h,
        iop: isFinite(o.opacity) ? o.opacity : 1.0,
        variant: typeof o.variant === "string" ? o.variant : "",
        showText: o.showText === undefined ? true : !!o.showText
      })
    }
    loading = false
    return true
  }

  function fillDefaults() {
    listModel.clear()
    for (const o of defaultsFor("idle")) listModel.append(o)
    for (const o of defaultsFor("login")) listModel.append(o)
  }

  function scheduleSave() {
    if (loading) return
    saveTimer.restart()
  }

  Timer {
    id: saveTimer
    interval: 300
    onTriggered: {
      store.pending = store.toJson()
      mk.running = true
    }
  }

  Process {
    id: mk
    command: ["mkdir", "-p", store.dir]
    onExited: file.setText(store.pending)
  }

  FileView {
    id: file
    path: store.path
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      if (text() === store.pending) return
      if (!store.parse(text())) store.fillDefaults()
    }
    onLoadFailed: store.fillDefaults()
  }

  Component.onCompleted: fillDefaults()
}
