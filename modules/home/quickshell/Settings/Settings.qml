import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."
import "../Singletons"

Item {
  id: root

  function s(val) { return Scaler.s(val) }

  IpcHandler {
    target: "settings"
    function toggle(): void {
      root.menuOpen = !root.menuOpen
    }
  }

  implicitWidth: s(50)
  implicitHeight: s(50)

  property int cascadeIndex: 6
  property bool menuOpen: false
  property bool entered: false
  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }
  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } } }
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

  property string homeDir: Quickshell.env("HOME")
  property string hyprConf: root.homeDir + "/.config/hypr/keybinds.lua"

  property string wallpaperDir: Config.wallpaperDir
  function setWallpaperDir(path) {
    let clean = path.trim()
    if (!clean) return
    Config.wallpaperDir = clean
    root.wallpaperDir = clean
  }

  // ── Current wallpaper preview ──
  // The wallpaper picker (WallpaperPicker.qml) is a separate ShellRoot process.
  // It persists the last-applied filename to its own session.json cache file
  // rather than through the shared Config singleton, so we read that file
  // directly here to know what's currently set.
  property string wallpaperCacheDir: root.homeDir + "/.cache/wallpaper-picker"

  FileView {
    id: wallpaperSessionFile
    path: root.wallpaperCacheDir + "/session.json"
    blockLoading: true
    watchChanges: true
    onFileChanged: reload()

    JsonAdapter {
      id: wallpaperSession
      property string query: ""
      property string colorFilter: ""
      property string lastSelectedName: ""
    }
    printErrors: false
  }

  readonly property string currentWallpaperPath:
    wallpaperSession.lastSelectedName
      ? root.wallpaperDir + "/" + wallpaperSession.lastSelectedName
      : ""

  property var validMods: ["SHIFT", "SHIFT_L", "SHIFT_R", "CAPS", "CTRL", "CONTROL", "ALT", "MOD2", "MOD3", "SUPER", "WIN", "LOGO", "MOD4", "MOD5", "$mainMod"]
  property string mainMod: Config.mainMod || "SUPER"
  function setMainMod(mod) {
    if (!root.validMods.includes(mod)) return
    Config.mainMod = mod
    root.mainMod = mod
    root.runShell(
      "sed -i 's/^\\s*\\$mainMod\\s*=.*/$mainMod = " + mod + "/' '" + root.hyprConf + "' && hyprctl reload"
    )
  }

  property string searchQuery: ""
  function matches(label) {
    return root.searchQuery.trim() === "" || label.toLowerCase().includes(root.searchQuery.toLowerCase())
  }

  property string themeSearchQuery: ""
  function themeMatches(label) {
    return root.themeSearchQuery.trim() === "" || label.toLowerCase().includes(root.themeSearchQuery.toLowerCase())
  }

  property bool useFahrenheit: Config.tempUnitFahrenheit
  function toggleTempUnit() { Config.tempUnitFahrenheit = !Config.tempUnitFahrenheit }

  property string profilePicturePath: Config.profilePicturePath
  function setProfilePicturePath(path) {
    let clean = path.trim()
    if (!clean) return
    Config.profilePicturePath = clean
    root.profilePicturePath = clean
  }

  property string weatherLocation: Config.weatherLocation
  function setWeatherLocation(loc) {
    let clean = loc.trim()
    if (!clean) return
    Config.weatherLocation = clean
    root.weatherLocation = clean
  }

  property var locationSuggestions: []
  property bool locationLookupBusy: false
  property bool locationConfirmedValid: false

  Timer {
    id: locationLookupDebounce
    interval: 400
    repeat: false
    onTriggered: root.lookupLocation(generalTab.weatherLocationInput.text)
  }

  function queueLocationLookup() {
    root.locationConfirmedValid = false
    locationLookupDebounce.restart()
  }

  function lookupLocation(query) {
    let clean = query.trim()
    root.locationSuggestions = []
    if (clean.length < 2) {
      root.locationLookupBusy = false
      return
    }
    root.locationLookupBusy = true
    let xhr = new XMLHttpRequest()
    let url = "https://geocoding-api.open-meteo.com/v1/search?name=" +
      encodeURIComponent(clean) + "&count=5&language=en&format=json"
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      root.locationLookupBusy = false
      if (xhr.status !== 200) {
        root.locationSuggestions = []
        return
      }
      try {
        let data = JSON.parse(xhr.responseText)
        let results = data.results || []
        root.locationSuggestions = results.map(r => {
          let parts = [r.name]
          if (r.admin1 && r.country_code === "US") parts.push(r.admin1)
          if (r.country) parts.push(r.country)
          return { label: parts.join(", "), value: parts.join(", ") }
        })
      } catch (e) {
        root.locationSuggestions = []
      }
    }
    xhr.open("GET", url)
    xhr.send()
  }

  function pickLocationSuggestion(label) {
    generalTab.weatherLocationInput.text = label
    root.locationConfirmedValid = true
    root.locationSuggestions = []
    root.setWeatherLocation(label)
  }

  property bool showClockSeconds: Config.showClockSeconds
  function toggleClockSeconds() { Config.showClockSeconds = !Config.showClockSeconds }

  property bool clock24h: Config.clock24h
  function toggleClock24h() { Config.clock24h = !Config.clock24h }

  property bool autoHideBar: Config.autoHideBar
  function toggleAutoHideBar() { Config.autoHideBar = !Config.autoHideBar }

  property var barPositionChoices: [
    { id: "top", label: "Top" },
    { id: "bottom", label: "Bottom" },
    { id: "left", label: "Left" },
    { id: "right", label: "Right" }
  ]
  function setBarPosition(pos) {
    if (!["top", "bottom", "left", "right"].includes(pos)) return
    Config.barPosition = pos
  }

  property string notifPosition: Config.notifPosition
  function setNotifPosition(pos) {
    if (!["top-left", "top", "top-right", "bottom-left", "bottom", "bottom-right"].includes(pos)) return
    Config.notifPosition = pos
    root.notifPosition = pos
  }

  property bool doNotDisturb: Notifs.silent
  function toggleDoNotDisturb() { Notifs.silent = !Notifs.silent; root.doNotDisturb = Notifs.silent }

  function sendTestNotification() { Notifs.sendTestNotification() }

  property string currentTab: "general"
  onCurrentTabChanged: {
    root.capturingMainMod = false
    generalTab.layoutDropdown.visible = false
    switchDropdown.visible = false
    appearanceTab.fontDropdown.visible = false
    barPosDropdown.visible = false
    if (currentTab === "bar") root.refreshBarLayoutDraft()
    if (currentTab === "about") root.refreshAboutInfo()
  }
  property var tabsList: [
    { id: "general", label: "General", icon: "" },
    { id: "bar", label: "Bar", icon: "󰹑"},
    { id: "notifications", label: "Notifications", icon: "󰵛" },
    { id: "appearance", label: "Appearance", icon: "󰏘" },
    { id: "keybinds", label: "Keybinds", icon: "󰌌" },
    { id: "displays", label: "Displays", icon: "󰍹" },
    { id: "about", label: "About", icon: "󰋽" }
  ]

  property string fontFamily: Config.fontFamily
  property var fontChoices: {
    let all = Qt.fontFamilies()
    let nerd = all.filter(f => /nerd font/i.test(f))
    let list = nerd.length > 0 ? nerd : all
    if (root.fontFamily && !list.includes(root.fontFamily)) list = [root.fontFamily].concat(list)
    return [...new Set(list)].sort()
  }
  function setFontFamily(f) { Config.fontFamily = f; root.fontFamily = f }
  function setUiRadius(r) { r = Math.max(0, Math.min(20, r)); Config.uiRadius = r }
  property string colorScheme: Config.colorScheme
  function setColorScheme(id) { Config.colorScheme = id; root.colorScheme = id }
  property var barLayoutDraft: JSON.parse(JSON.stringify(Config.barLayout))
  property var unplacedDraft: Config.unplacedBarModules()
  function refreshBarLayoutDraft() {
    root.barLayoutDraft = JSON.parse(JSON.stringify(Config.barLayout))
    root.unplacedDraft = Config.unplacedBarModules()
  }
  property string draggingModuleId: ""
  property string draggingFromZone: ""
  property var activeDragPill: null
  property string previewZone: ""
  property int previewIdx: -1

  function moduleZone(id) {
    if (root.barLayoutDraft.left.includes(id)) return "left"
    if (root.barLayoutDraft.center.includes(id)) return "center"
    if (root.barLayoutDraft.right.includes(id)) return "right"
    return "unplaced"
  }

  function removeFromCurrentZone(id) {
    let draft = root.barLayoutDraft
    let next = {
      left: draft.left.filter(m => m !== id),
      center: draft.center.filter(m => m !== id),
      right: draft.right.filter(m => m !== id)
    }
    root.barLayoutDraft = next
    root.unplacedDraft = root.unplacedDraft.filter(m => m !== id)
  }

  function moveModuleToZone(id, zone, insertIdx) {
    let fromZone = root.moduleZone(id)
    let fromIdx = (fromZone !== "unplaced") ? root.barLayoutDraft[fromZone].indexOf(id) : -1

    root.removeFromCurrentZone(id)
    if (zone === "unplaced") {
      let u = root.unplacedDraft.slice()
      u.push(id)
      root.unplacedDraft = u
    } else {
      let draft = root.barLayoutDraft
      let arr = draft[zone].slice()
      let idx = (insertIdx === undefined || insertIdx < 0 || insertIdx > arr.length) ? arr.length : insertIdx
      // computeInsertIdx already skips the dragged module when counting,
      // so the returned index is already relative to the post-removal
      // array — no further adjustment needed here.
      arr.splice(idx, 0, id)
      let next = { left: draft.left, center: draft.center, right: draft.right }
      next[zone] = arr
      root.barLayoutDraft = next
    }
  }

  function commitBarLayout() {
    Config.setBarLayout(root.barLayoutDraft)
    Config.pruneBarGroups()
  }

  function resetBarLayout() {
    Config.barLayout = Config.defaultBarLayout()
    Config.setBarGroups({}, {})
    Config.saveSettings()
    root.refreshBarLayoutDraft()
  }

  // --- Bar module grouping (right-click two pills in the same zone to merge) ---
  property string pendingGroupId: ""
  property string pendingGroupZone: ""
  readonly property var groupPalette: ["#f38ba8", "#a6e3a1", "#89b4fa", "#f9e2af", "#cba6f7", "#94e2d5", "#fab387", "#89dceb"]

  function clearPendingGroup() {
    root.pendingGroupId = ""
    root.pendingGroupZone = ""
  }

  function groupIdFor(moduleId) {
    let groups = Config.barGroups || ({})
    return groups[moduleId] || ""
  }

  function isFirstInGroup(moduleId) {
    let gId = root.groupIdFor(moduleId)
    if (!gId) return true
    let zone = root.moduleZone(moduleId)
    if (zone === "unplaced") return true
    let ids = root.barLayoutDraft[zone]
    let idx = ids.indexOf(moduleId)
    return idx <= 0 || root.groupIdFor(ids[idx - 1]) !== gId
  }

  function isLastInGroup(moduleId) {
    let gId = root.groupIdFor(moduleId)
    if (!gId) return true
    let zone = root.moduleZone(moduleId)
    if (zone === "unplaced") return true
    let ids = root.barLayoutDraft[zone]
    let idx = ids.indexOf(moduleId)
    return idx === -1 || idx === ids.length - 1 || root.groupIdFor(ids[idx + 1]) !== gId
  }

  // Deterministic color per group id — always the same color for the same
  // group, independent of assignment order, so colors don't shuffle around
  // as groups are made and dissolved.
  function groupColorFor(moduleId) {
    let gId = root.groupIdFor(moduleId)
    if (!gId) return ""
    let hash = 0
    for (let i = 0; i < gId.length; i++) {
      hash = ((hash << 5) - hash) + gId.charCodeAt(i)
      hash |= 0
    }
    return root.groupPalette[Math.abs(hash) % root.groupPalette.length]
  }

  function requestGroupClick(moduleId) {
    let zone = root.moduleZone(moduleId)
    if (zone === "unplaced") { root.clearPendingGroup(); return }

    if (root.pendingGroupId === "") {
      root.pendingGroupId = moduleId
      root.pendingGroupZone = zone
      return
    }
    if (root.pendingGroupId === moduleId) {
      root.clearPendingGroup()
      return
    }
    if (root.pendingGroupZone !== zone) {
      // different zone — can't merge, just re-select the new one
      root.pendingGroupId = moduleId
      root.pendingGroupZone = zone
      return
    }
    root.uniteModules(root.pendingGroupId, moduleId)
    root.clearPendingGroup()
  }

  function uniteModules(aId, bId) {
    let groups = Object.assign({}, Config.barGroups || ({}))
    let gId = groups[bId] || groups[aId] || ("grp_" + [aId, bId].sort().join("_"))
    groups[aId] = gId
    groups[bId] = gId
    Config.barGroups = groups
    Config.saveSettings()
  }

  function ungroupModule(moduleId) {
    let groups = Object.assign({}, Config.barGroups || ({}))
    if (!groups[moduleId]) return
    delete groups[moduleId]
    Config.barGroups = groups
    Config.saveSettings()
  }

  property int capturingIdx: -1
  property bool capturingMainMod: false

  function startCaptureMainMod() { root.capturingMainMod = true }
  function cancelCaptureMainMod() { root.capturingMainMod = false }

  function keyEventToModToken(event) {
    let k = event.key
    switch (k) {
      case Qt.Key_Super_L: case Qt.Key_Super_R: case Qt.Key_Meta: return "SUPER"
      case Qt.Key_Shift: return "SHIFT"
      case Qt.Key_Control: return "CTRL"
      case Qt.Key_Alt: return "ALT"
      case Qt.Key_CapsLock: return "CAPS"
      case Qt.Key_AltGr: return "MOD5"
      default: return ""
    }
  }

  function validScalesForResolution(width, height) {
  if (!width || !height) return [1.0]
  let candidates = []
  let seen = {}
  function tryAdd(s) {
    let r = Math.round(s * 1000) / 1000
    let key = r.toFixed(3)
    if (seen[key]) return
    let lw = width / r
    let lh = height / r
    if (Math.abs(lw - Math.round(lw)) >= 0.001 || Math.abs(lh - Math.round(lh)) >= 0.001) return
    seen[key] = true
    candidates.push(r)
  }
  for (let s = 0.50; s <= 3.00; s += 0.05) tryAdd(Math.round(s * 100) / 100)
  ;[0.667, 1.333, 1.667, 2.667].forEach(tryAdd)
  candidates.sort((a, b) => a - b)
  return candidates.length > 0 ? candidates : [1.0]
}

function ratesForRes(availableModes, width, height) {
  if (!availableModes || availableModes.length === 0) return [60]
  let target = width + "x" + height + "@"
  let rates = []
  for (let i = 0; i < availableModes.length; i++) {
    let modeStr = String(availableModes[i] ?? "")
    if (modeStr.indexOf(target) !== 0) continue
    let hz = parseFloat(modeStr.split("@")[1])
    if (!isNaN(hz)) rates.push(Math.round(hz))
  }
  rates = [...new Set(rates)].sort((a, b) => a - b)
  return rates.length > 0 ? rates : [60]
}

function setMonitorRate(idx, rate) {
  monitorsModel.setProperty(idx, "refreshRate", rate)
  root.applyMonitor(idx)
}

  //fonts 
Process {
    id: systemFontLister
    running: true
    command: ["bash", "-c", "fc-list : family | tr ',' '\\n' | sort -u"]
    stdout: StdioCollector {
        onStreamFinished: {
            let fonts = this.text.trim().split("\n").filter(f => f.length > 0)
            root.fontChoices = fonts
        }
    }
}
  ListModel { id: keybindsModel }

  // ── About tab: system info ──
  property string aboutNixosVersion: "--"
  property string aboutKernelVersion: "--"
  property string aboutUptimeStr: "--"
  property string aboutHyprlandVersion: "--"

  Process {
    id: aboutNixosProc
    command: ["sh", "-c", "nixos-version | grep -oE '[0-9]{2}\\.[0-9]{2}(\\.[0-9]+)?'"]
    stdout: SplitParser {
      onRead: data => {
        const v = data.trim()
        root.aboutNixosVersion = v.length > 0 ? v : "Unknown"
      }
    }
  }

  Process {
    id: aboutKernelProc
    command: ["uname", "-r"]
    stdout: SplitParser {
      onRead: data => root.aboutKernelVersion = data.trim()
    }
  }

  Process {
    id: aboutUptimeProc
    command: ["sh", "-c", "uptime -p"]
    stdout: SplitParser {
      onRead: data => root.aboutUptimeStr = data.trim().replace(/^up /, "")
    }
  }

  Process {
    id: aboutHyprlandProc
    command: ["sh", "-c", "hyprctl version | head -n1"]
    stdout: SplitParser {
      onRead: data => root.aboutHyprlandVersion = data.trim()
    }
  }

  function refreshAboutInfo() {
    aboutNixosProc.running = true
    aboutKernelProc.running = true
    aboutUptimeProc.running = true
    aboutHyprlandProc.running = true
  }

  Process {
    id: keybindsReadProc
    command: ["grep", "-noE", "hl\\.bind\\(mainMod \\.\\. \" \\+ [^\"]+\"(, *hl\\.dsp\\.[A-Za-z_.]+\\([^)]*\\))?", root.hyprConf]
    stdout: StdioCollector {
      onStreamFinished: {
        keybindsModel.clear()
        let lines = this.text.trim().split("\n")
        for (let l of lines) {
          if (!l) continue
          let colonIdx = l.indexOf(":")
          let lineNum = l.substring(0, colonIdx)
          let rest = l.substring(colonIdx + 1)
          let keyM = rest.match(/\+ ([^"]+)"/)
          if (!keyM) continue
          let key = keyM[1].trim()
          let dispM = rest.match(/hl\.dsp\.([A-Za-z_.]+)\(([^)]*)\)/)
          let dispatcher = dispM ? dispM[1] : ""
          let args = dispM ? dispM[2].replace(/^["']|["']$/g, "") : ""
          let name = Config.keybindNameOverrides[lineNum] || Config.friendlyKeybindName(dispatcher, args)
          keybindsModel.append({ lineNum: parseInt(lineNum), key: key, name: name, editing: false, error: "" })
        }
      }
    }
  }
  function refreshKeybinds() { keybindsReadProc.running = false; keybindsReadProc.running = true }

  function escapeSedToken(s) { return s.replace(/[\\&/]/g, "\\$&") }

  function checkDuplicateKeybind(idx, newKey, newMods) {
    let currentModsNormalized = (newMods || root.mainMod).toUpperCase()
    let currentKeyNormalized = newKey.toUpperCase()
    for (let i = 0; i < keybindsModel.count; i++) {
      if (i === idx) continue
      let item = keybindsModel.get(i)
      let itemModsNormalized = (item.mods || root.mainMod).toUpperCase()
      let itemKeyNormalized = item.key.toUpperCase()
      if (itemModsNormalized === currentModsNormalized && itemKeyNormalized === currentKeyNormalized) {
        return "Duplicate keybind!\nThis exact combination already exists."
      }
    }
    return ""
  }

  function setKeybindKey(idx, newKey) {
    let clean = newKey.trim()
    if (!/^[A-Za-z_0-9]+$/.test(clean)) return
    let dupError = root.checkDuplicateKeybind(idx, clean)
    if (dupError) {
      keybindsModel.setProperty(idx, "error", dupError)
      return
    }
    let entry = keybindsModel.get(idx)
    let ln = entry.lineNum
    let escNew = root.escapeSedToken(clean)
    root.runShell(
      "sed -i '" + ln + "s/\\+ [^\"]\\+\"/+ " + escNew + "\"/' '" + root.hyprConf + "' && hyprctl reload"
    )
    keybindsModel.setProperty(idx, "key", clean)
    keybindsModel.setProperty(idx, "editing", false)
    keybindsModel.setProperty(idx, "error", "")
  }

  function setKeybindName(idx, newName) {
    let entry = keybindsModel.get(idx)
    Config.setKeybindName(entry.lineNum, newName)
    keybindsModel.setProperty(idx, "name", newName)
  }

  function startCapture(idx) {
    root.capturingIdx = idx
    for (let i = 0; i < keybindsModel.count; i++) keybindsModel.setProperty(i, "editing", i === idx)
  }

  function cancelCapture() {
    if (root.capturingIdx >= 0) {
      keybindsModel.setProperty(root.capturingIdx, "editing", false)
      keybindsModel.setProperty(root.capturingIdx, "error", "")
    }
    root.capturingIdx = -1
  }

  function keyEventToToken(event) {
    let k = event.key
    if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k)
    if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k)
    switch (k) {
      case Qt.Key_Left: return "left"
      case Qt.Key_Right: return "right"
      case Qt.Key_Up: return "up"
      case Qt.Key_Down: return "down"
      case Qt.Key_Space: return "space"
      case Qt.Key_Return: case Qt.Key_Enter: return "return"
      case Qt.Key_Tab: return "tab"
      case Qt.Key_Escape: return "escape"
      case Qt.Key_grave: return "grave"
      case Qt.Key_Comma: return "comma"
      case Qt.Key_Period: return "period"
      case Qt.Key_Minus: return "minus"
      case Qt.Key_Equal: return "equal"
      case Qt.Key_Semicolon: return "semicolon"
      case Qt.Key_Apostrophe: return "apostrophe"
      case Qt.Key_Slash: return "slash"
      case Qt.Key_Backslash: return "backslash"
      case Qt.Key_BracketLeft: return "bracketleft"
      case Qt.Key_BracketRight: return "bracketright"
      default:
        if (k >= Qt.Key_F1 && k <= Qt.Key_F35) return "F" + (k - Qt.Key_F1 + 1)
        return ""
    }
  }

  Process { id: reloadHyprProc; command: ["hyprctl", "reload"] }

  Process { id: applyProc; property string cmd: ""; command: ["sh", "-c", cmd] }
  function runShell(cmd) { applyProc.cmd = cmd; applyProc.running = false; applyProc.running = true }

  function applyWorkspaceCount() {
    root.runShell(
      "sed -i 's/for i = 1, [0-9]*/for i = 1, " + Config.workspaceCount + "/' '" + root.hyprConf + "' && hyprctl reload"
    )
  }

  property var currentLayouts: ["us"]
  property var availableLayoutCodes: [
    "us","gb","de","fr","es","it","ru","ua","pl","cz","se","no","dk","fi",
    "jp","kr","cn","br","tr","gr","il","in","pt","nl","be","ch","at","hu",
    "ro","bg","rs","hr","si","sk","lt","lv","ee","ie","ca","latam","dvorak","colemak",
  ]

  property string layoutSwitchOption: "grp:alt_shift_toggle"
  property var switchOptionChoices: [
    { label: "Alt Shift", value: "grp:alt_shift_toggle" },
    { label: "Ctrl Shift", value: "grp:ctrl_shift_toggle" },
    { label: "Ctrl + Alt", value: "grp:ctrl_alt_toggle" },
    { label: "Win Space", value: "grp:win_space_toggle" },
    { label: "Caps Lock", value: "grp:caps_toggle" },
    { label: "No Toggle", value: "" }
  ]

  function setSwitchOption(val) {
    Quickshell.execDetached(["hyprctl", "keyword", "input:kb_options", val])
    root.runShell("sed -i 's/kb_options\\s*=\\s*\"[^\"]*\"/kb_options = \"" + val + "\"/' '" + root.hyprConf + "'")
    root.layoutSwitchOption = val
  }

  Process {
    id: layoutQueryProc
    command: ["hyprctl", "getoption", "input:kb_layout", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          let data = JSON.parse(this.text)
          root.currentLayouts = (data.str || "us").split(",")
        } catch (e) {}
      }
    }
  }

  Process {
    id: switchOptionQueryProc
    command: ["hyprctl", "getoption", "input:kb_options", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          let data = JSON.parse(this.text)
          root.layoutSwitchOption = data.str || "grp:alt_shift_toggle"
        } catch (e) {}
      }
    }
  }

  Component.onCompleted: {
    Scaler.currentWidth = Screen.width
    Scaler.currentHeight = Screen.height
    layoutQueryProc.running = true
    switchOptionQueryProc.running = true
    monitorQueryProc.running = true
    root.refreshKeybinds()
  }

  function setKbLayout(codes) {
    let joined = codes.join(",")
    Quickshell.execDetached(["hyprctl", "keyword", "input:kb_layout", joined])
    root.runShell("sed -i 's/kb_layout\\s*=\\s*\"[^\"]*\"/kb_layout  = \"" + joined + "\"/' '" + root.hyprConf + "'")
    root.currentLayouts = codes
  }
  function addLayout(code) {
    if (root.currentLayouts.includes(code)) return
    let arr = root.currentLayouts.slice(); arr.push(code)
    root.setKbLayout(arr)
  }
  function removeLayout(code) {
    let arr = root.currentLayouts.filter(c => c !== code)
    if (arr.length === 0) return
    root.setKbLayout(arr)
  }

  ListModel { id: monitorsModel }
  Process {
    id: monitorQueryProc
    command: ["hyprctl", "monitors", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          let mons = JSON.parse(this.text)
          monitorsModel.clear()
          for (let m of mons) {
            monitorsModel.append({
              name: m.name,
              width: m.width,
              height: m.height,
              refreshRate: Math.round(m.refreshRate),
              x: m.x,
              y: m.y,
              scale: m.scale,
              transform: m.transform,
              disabled: m.disabled || false,
              availableModes: m.availableModes || []
            })
          }
        } catch (e) {}
      }
    }
  }
  function refreshMonitors() { monitorQueryProc.running = false; monitorQueryProc.running = true }

function applyMonitor(idx) {
  let m = monitorsModel.get(idx)
  let res = m.disabled ? "disable" : (m.width + "x" + m.height + "@" + m.refreshRate)
  let pos = m.x + "x" + m.y
  let cmd = m.disabled
    ? "hyprctl keyword monitor " + m.name + ",disable"
    : "hyprctl keyword monitor " + m.name + "," + res + "," + pos + "," + m.scale
  root.runShell(cmd)
  root.persistMonitor(idx)
}

property string hyprGeneral: root.homeDir + "/.config/hypr/general.lua"

function persistMonitor(idx) {
  let m = monitorsModel.get(idx)
  let mode = m.disabled ? "disable" : (m.width + "x" + m.height + "@" + m.refreshRate)
  let position = m.x + "x" + m.y
  let scale = String(m.scale)
  let output = m.name

  let script =
    "python3 - '" + root.hyprGeneral + "' '" + output + "' '" + mode + "' '" + position + "' '" + scale + "' <<'PYEOF'\n" +
    "import re, sys\n" +
    "path, output, mode, position, scale = sys.argv[1:6]\n" +
    "with open(path) as f: text = f.read()\n" +
    "pattern = re.compile(r'hl\\.monitor\\(\\{[^}]*output\\s*=\\s*\"' + re.escape(output) + r'\"[^}]*\\}\\)', re.S)\n" +
    "block = 'hl.monitor({\\n    output   = \"' + output + '\",\\n    mode     = \"' + mode + '\",\\n    position = \"' + position + '\",\\n    scale    = \"' + scale + '\",\\n})'\n" +
    "if pattern.search(text):\n" +
    "    text = pattern.sub(block, text, count=1)\n" +
    "else:\n" +
    "    marker = '-- MONITORS'\n" +
    "    idx = text.find(marker)\n" +
    "    if idx == -1:\n" +
    "        text = text + '\\n' + marker + '\\n' + block + '\\n'\n" +
    "    else:\n" +
    "        insert_at = idx + len(marker)\n" +
    "        text = text[:insert_at] + '\\n' + block + text[insert_at:]\n" +
    "with open(path, 'w') as f: f.write(text)\n" +
    "PYEOF"

  root.runShell(script)
}

function setMonitorScale(idx, scale) {
  monitorsModel.setProperty(idx, "scale", scale)
  root.applyMonitor(idx)
}

property var commonResolutions: [
  { w: 7680, h: 4320 }, { w: 5120, h: 2880 }, { w: 5120, h: 1440 },
  { w: 4096, h: 2160 }, { w: 3840, h: 2160 }, { w: 3840, h: 1600 },
  { w: 3440, h: 1440 }, { w: 2560, h: 1440 }, { w: 2560, h: 1080 },
  { w: 1920, h: 1200 }, { w: 1920, h: 1080 }, { w: 1680, h: 1050 },
  { w: 1600, h: 900 },  { w: 1440, h: 900 },  { w: 1366, h: 768 },
  { w: 1280, h: 1024 }, { w: 1280, h: 800 },  { w: 1280, h: 720 },
  { w: 1024, h: 768 },  { w: 800, h: 600 }
]

function resLabel(w, h) {
  if (w === 7680 && h === 4320) return "8K UHD"
  if (w === 5120 && h === 2880) return "5K"
  if (w === 5120 && h === 1440) return "DQHD"
  if (w === 4096 && h === 2160) return "DCI 4K"
  if (w === 3840 && h === 2160) return "4K UHD"
  if (w === 3840 && h === 1600) return "UW4K"
  if (w === 3440 && h === 1440) return "UWQHD"
  if (w === 2560 && h === 1440) return "QHD"
  if (w === 2560 && h === 1080) return "UWFHD"
  if (w === 1920 && h === 1200) return "WUXGA"
  if (w === 1920 && h === 1080) return "FHD"
  if (w === 1680 && h === 1050) return "WSXGA+"
  if (w === 1600 && h === 900)  return "HD+"
  if (w === 1440 && h === 900)  return "WXGA+"
  if (w === 1366 && h === 768)  return "FWXGA"
  if (w === 1280 && h === 1024) return "SXGA"
  if (w === 1280 && h === 800)  return "WXGA"
  if (w === 1280 && h === 720)  return "HD"
  if (w === 1024 && h === 768)  return "XGA"
  if (w === 800  && h === 600)  return "SVGA"
  return w + "x" + h
}

function setMonitorRes(idx, w, h) {
  monitorsModel.setProperty(idx, "width", w)
  monitorsModel.setProperty(idx, "height", h)
  root.applyMonitor(idx)
}

function stepRefreshRate(idx, delta) {
  let m = monitorsModel.get(idx)
  let steps = [24, 30, 48, 50, 60, 75, 90, 120, 144, 165, 180, 240]
  let cur = m.refreshRate
  let closest = steps.reduce((a, b) => Math.abs(b - cur) < Math.abs(a - cur) ? b : a)
  let i = steps.indexOf(closest)
  let ni = Math.max(0, Math.min(steps.length - 1, i + delta))
  monitorsModel.setProperty(idx, "refreshRate", steps[ni])
  root.applyMonitor(idx)
}

property var transformChoices: [
  { id: 0, label: "0°" },
  { id: 1, label: "90°" },
  { id: 2, label: "180°" },
  { id: 3, label: "270°" }
]
function setMonitorTransform(idx, t) {
  monitorsModel.setProperty(idx, "transform", t)
  root.applyMonitor(idx)
}

// ── Night light ──
property string nightLightMode: Config.nightLightMode || "Never"
property string nightLightFrom: Config.nightLightFrom || "20:00"
property string nightLightTo: Config.nightLightTo || "07:00"
property var nightLightModeChoices: ["Never", "On", "Schedule"]

function applyNightLight(on) {
  root.runShell(on ? "hyprctl hyprsunset temperature 4000" : "hyprctl hyprsunset identity")
}

Timer {
  id: nightLightScheduleTimer
  interval: 60000
  repeat: true
  running: root.nightLightMode === "Schedule"
  triggeredOnStart: true
  onTriggered: root.evaluateNightLightSchedule()
}

function evaluateNightLightSchedule() {
  if (root.nightLightMode !== "Schedule") return
  let now = new Date()
  let cur = now.getHours() * 60 + now.getMinutes()
  let [fh, fm] = root.nightLightFrom.split(":").map(Number)
  let [th, tm] = root.nightLightTo.split(":").map(Number)
  let from = fh * 60 + fm
  let to = th * 60 + tm
  let active = from <= to ? (cur >= from && cur < to) : (cur >= from || cur < to)
  root.applyNightLight(active)
}

function setNightLightMode(mode) {
  if (!root.nightLightModeChoices.includes(mode)) return
  Config.nightLightMode = mode
  root.nightLightMode = mode
  if (mode === "Never") root.applyNightLight(false)
  else if (mode === "On") root.applyNightLight(true)
  else root.evaluateNightLightSchedule()
}

function setNightLightFrom(t) {
  Config.nightLightFrom = t
  root.nightLightFrom = t
  root.evaluateNightLightSchedule()
}

function setNightLightTo(t) {
  Config.nightLightTo = t
  root.nightLightTo = t
  root.evaluateNightLightSchedule()
}

// ── Auto-lock ──
property int autoLockSeconds: Config.autoLockSeconds !== undefined ? Config.autoLockSeconds : 300
property var autoLockChoices: [
  { s: 30, label: "30 sec" },
  { s: 60, label: "1 min" },
  { s: 120, label: "2 min" },
  { s: 180, label: "3 min" },
  { s: 240, label: "4 min" },
  { s: 300, label: "5 min" },
  { s: 0, label: "Never" }
]
property string hypridleConf: root.homeDir + "/.config/hypr/hypridle.conf"

function setAutoLockSeconds(sec) {
  Config.autoLockSeconds = sec
  root.autoLockSeconds = sec

  let script =
    "python3 - '" + root.hypridleConf + "' " + sec + " <<'PYEOF'\n" +
    "import re, sys\n" +
    "path, sec = sys.argv[1], int(sys.argv[2])\n" +
    "with open(path) as f: text = f.read()\n" +
    "block_pattern = re.compile(r'listener\\s*\\{[^}]*loginctl lock-session[^}]*\\}', re.S)\n" +
    "if sec == 0:\n" +
    "    text = block_pattern.sub('', text)\n" +
    "else:\n" +
    "    block = 'listener {\\n    timeout = ' + str(sec) + '\\n    on-timeout = loginctl lock-session\\n}'\n" +
    "    if block_pattern.search(text):\n" +
    "        text = block_pattern.sub(block, text, count=1)\n" +
    "    else:\n" +
    "        text = text.rstrip() + '\\n\\n' + block + '\\n'\n" +
    "with open(path, 'w') as f: f.write(text)\n" +
    "PYEOF && systemctl --user restart hypridle 2>/dev/null || (pkill hypridle; setsid -f hypridle)"

  root.runShell(script)
}

property int resDropdownIdx: -1

  Rectangle {
    id: pillBg
    anchors.fill: parent
    radius: s(Config.uiRadius + 4)
    color: "transparent"
    border.color: "transparent"
    border.width: 1
  }

  Text {
    anchors.centerIn: parent
    text: "󰒓"
    font.pixelSize: s(18)
    font.family: "JetBrainsMono Nerd Font"
    color: root.menuOpen ? MatugenColors.accent : MatugenColors.text
    Behavior on color { ColorAnimation { duration: 200 } }
  }

  MouseArea {
    id: pillMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.menuOpen = !root.menuOpen
  }

  PanelWindow {
    id: settingsPopup
    visible: animOpacity > 0.01
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qs-settings-popup"
    anchors { top: true; left: true; right: true; bottom: true }

    property real animOpacity: root.menuOpen ? 1.0 : 0.0
    Behavior on animOpacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    onVisibleChanged: if (!visible) { root.capturingMainMod = false; appearanceTab.fontDropdown.visible = false }

    MouseArea {
      anchors.fill: parent
      onClicked: {
        if (root.draggingModuleId !== "") return
        root.menuOpen = false
        root.cancelCapture()
      }
    }

    FocusScope {
      anchors.fill: parent
      focus: root.menuOpen
      Keys.onEscapePressed: {
        if (root.capturingIdx >= 0) root.cancelCapture()
        else if (root.capturingMainMod) root.cancelCaptureMainMod()
        else root.menuOpen = false
      }

      Rectangle {
        id: settingsCard
        width: Math.max(s(1900), Math.min(s(1000), Screen.width - s(80)))
        height: Math.max(s(500), Math.min(s(1100), Screen.height - s(80)))
        x: Math.floor((Screen.width - width) / 2)
        y: Math.floor((Screen.height - height) / 2)
        radius: s(Config.uiRadius + 6)
        color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 1)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)
        clip: true

        opacity: settingsPopup.animOpacity
        scale: 0.9 + 0.1 * settingsPopup.animOpacity
        transform: Translate { y: (1 - settingsPopup.animOpacity) * -10 }

        MouseArea { anchors.fill: parent }



        RowLayout {
          id: settingsBody
          anchors.fill: parent
          anchors.margins: s(16)
          spacing: s(16)

          // ── Sidebar ──
          ColumnLayout {
            id: sidebar
            Layout.preferredWidth: s(200)
            Layout.minimumWidth: s(200)
            Layout.maximumWidth: s(200)
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: s(14)

            Text {
              text: "Settings"
              font.pixelSize: s(16)
              font.weight: Font.Bold
              font.family: "JetBrainsMono Nerd Font"
              color: MatugenColors.text
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: s(36)
              radius: s(Config.uiRadius)
              color: Qt.rgba(1, 1, 1, 0.06)
              border.color: searchInput.activeFocus ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.08)
              border.width: 1
              Behavior on border.color { ColorAnimation { duration: 150 } }

              RowLayout {
                anchors.fill: parent
                anchors.margins: s(8)
                spacing: s(8)
                Text { text: "󰍉"; font.pixelSize: s(13); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textDim }
                TextInput {
                  id: searchInput
                  Layout.fillWidth: true
                  verticalAlignment: TextInput.AlignVCenter
                  font.pixelSize: s(12)
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.text
                  clip: true
                  onTextChanged: root.searchQuery = text
                  Text { text: "Search"; color: MatugenColors.textDim; visible: !parent.text; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
                }
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: s(4)

              Repeater {
                model: root.tabsList
                delegate: Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: s(38)
                  radius: s(Config.uiRadius)
                  color: root.currentTab === modelData.id
                    ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.85)
                    : (tabMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                  Behavior on color { ColorAnimation { duration: 150 } }

                  RowLayout {
                    anchors.fill: parent
                    anchors.margins: s(10)
                    spacing: s(8)
                    Text {
                      text: modelData.icon
                      font.pixelSize: s(13)
                      font.family: "JetBrainsMono Nerd Font"
                      color: root.currentTab === modelData.id ? MatugenColors.accentText : MatugenColors.textDim
                      Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                      text: modelData.label
                      font.pixelSize: s(12)
                      font.weight: root.currentTab === modelData.id ? Font.Bold : Font.Normal
                      font.family: "JetBrainsMono Nerd Font"
                      color: root.currentTab === modelData.id ? MatugenColors.accentText : MatugenColors.text
                      Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Item { Layout.fillWidth: true }
                  }

                  MouseArea {
                    id: tabMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.currentTab = modelData.id; root.cancelCapture() }
                  }
                }
              }
            }

            Item { Layout.fillHeight: true }
          }

          Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Qt.rgba(1, 1, 1, 0.08) }

          // ── Content pane ──
          Flickable {
          id: mainFlick
          Layout.fillWidth: true
          Layout.fillHeight: true
          contentWidth: width
          onContentYChanged: { root.capturingMainMod = false; appearanceTab.fontDropdown.visible = false }
          contentHeight: mainColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          ColumnLayout {
            id: mainColumn
            width: mainFlick.width
            spacing: s(14)

            GeneralTab {
      id: generalTab
              visible: root.currentTab === "general"
              Layout.fillWidth: true
              s: root.s
              matches: root.matches
              useFahrenheit: root.useFahrenheit
              toggleTempUnit: root.toggleTempUnit
              weatherLocation: root.weatherLocation
              setWeatherLocation: root.setWeatherLocation
              queueLocationLookup: root.queueLocationLookup
              pickLocationSuggestion: root.pickLocationSuggestion
              locationSuggestions: root.locationSuggestions
              locationLookupBusy: root.locationLookupBusy
              locationConfirmedValid: root.locationConfirmedValid
              currentLayouts: root.currentLayouts
              removeLayout: root.removeLayout
              availableLayoutCodes: root.availableLayoutCodes
              addLayout: root.addLayout
              switchOptionChoices: root.switchOptionChoices
              layoutSwitchOption: root.layoutSwitchOption
              setSwitchOption: root.setSwitchOption
              profilePicturePath: root.profilePicturePath
              setProfilePicturePath: root.setProfilePicturePath
            }

            BarTab {
              visible: root.currentTab === "bar"
              Layout.fillWidth: true
              s: root.s
              matches: root.matches
              fontFamily: root.fontFamily
              barPositionChoices: root.barPositionChoices
              setBarPosition: root.setBarPosition
              autoHideBar: root.autoHideBar
              toggleAutoHideBar: root.toggleAutoHideBar
              barLayoutDraft: root.barLayoutDraft
              unplacedDraft: root.unplacedDraft
              moveModuleToZone: root.moveModuleToZone
              commitBarLayout: root.commitBarLayout
              resetBarLayout: root.resetBarLayout
              draggingModuleId: root.draggingModuleId
              previewZone: root.previewZone
              previewIdx: root.previewIdx
              activeDragPill: root.activeDragPill
              controller: root
              dragSurfaceItem: mainFlick.contentItem
              showClockSeconds: root.showClockSeconds
              toggleClockSeconds: root.toggleClockSeconds
              clock24h: root.clock24h
              toggleClock24h: root.toggleClock24h
            }

            NotifactionTab {
              visible: root.currentTab === "notifications"
              Layout.fillWidth: true
              s: root.s
              matches: root.matches
              notifPosition: root.notifPosition
              setNotifPosition: root.setNotifPosition
              doNotDisturb: root.doNotDisturb
              toggleDoNotDisturb: root.toggleDoNotDisturb
              sendTestNotification: root.sendTestNotification
            }

            AppearanceTab {
      id: appearanceTab
              visible: root.currentTab === "appearance"
              Layout.fillWidth: true
              s: root.s
              matches: root.matches
              fontFamily: root.fontFamily
              fontChoices: root.fontChoices
              setFontFamily: root.setFontFamily
              currentWallpaperPath: root.currentWallpaperPath
              wallpaperDir: root.wallpaperDir
              setWallpaperDir: root.setWallpaperDir
              colorScheme: root.colorScheme
              setColorScheme: root.setColorScheme
              themeSearchQuery: root.themeSearchQuery
              themeMatches: root.themeMatches
            }

            KeybindsTab {
              visible: root.currentTab === "keybinds"
              Layout.fillWidth: true
              s: root.s
              matches: root.matches
              capturingMainMod: root.capturingMainMod
              cancelCaptureMainMod: root.cancelCaptureMainMod
              startCaptureMainMod: root.startCaptureMainMod
              keyEventToModToken: root.keyEventToModToken
              setMainMod: root.setMainMod
              mainMod: root.mainMod
              refreshKeybinds: root.refreshKeybinds
              keybindsModel: keybindsModel
              setKeybindName: root.setKeybindName
              cancelCapture: root.cancelCapture
              startCapture: root.startCapture
              keyEventToToken: root.keyEventToToken
              setKeybindKey: root.setKeybindKey
            }

            DisplayTab {
              visible: root.currentTab === "displays"
              Layout.fillWidth: true
              s: root.s
              matches: root.matches
              fontFamily: root.fontFamily
              menuOpenSetter: function(v) { root.menuOpen = v }
              monitorsModel: monitorsModel
              resDropdownIdx: root.resDropdownIdx
              setResDropdownIdx: function(v) { root.resDropdownIdx = v }
              resLabel: root.resLabel
              commonResolutions: root.commonResolutions
              validScalesForResolution: root.validScalesForResolution
              setMonitorRes: root.setMonitorRes
              stepRefreshRate: root.stepRefreshRate
              ratesForRes: root.ratesForRes
              setMonitorRate: root.setMonitorRate
              setMonitorScale: root.setMonitorScale
              transformChoices: root.transformChoices
              setMonitorTransform: root.setMonitorTransform
              nightLightMode: root.nightLightMode
              nightLightFrom: root.nightLightFrom
              nightLightTo: root.nightLightTo
              nightLightModeChoices: root.nightLightModeChoices
              setNightLightMode: root.setNightLightMode
              setNightLightFrom: root.setNightLightFrom
              setNightLightTo: root.setNightLightTo
              autoLockSeconds: root.autoLockSeconds
              autoLockChoices: root.autoLockChoices
              setAutoLockSeconds: root.setAutoLockSeconds
            }

            AboutTab {
              visible: root.currentTab === "about"
              Layout.fillWidth: true
              s: root.s
              aboutNixosVersion: root.aboutNixosVersion
              aboutKernelVersion: root.aboutKernelVersion
              aboutHyprlandVersion: root.aboutHyprlandVersion
              aboutUptimeStr: root.aboutUptimeStr
            }
          }

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 36
            visible: mainFlick.contentHeight > mainFlick.height &&
                     mainFlick.contentY < mainFlick.contentHeight - mainFlick.height - 1
            gradient: Gradient {
              orientation: Gradient.Vertical
              GradientStop { position: 0.0; color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.0) }
              GradientStop { position: 1.0; color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.94) }
            }
          }
          }
        }
      }
    }
  }
}
