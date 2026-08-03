import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: root

  Scaler {
    id: scaler
    currentWidth: Screen.width
    currentHeight: Screen.height
  }
  function s(val) { return scaler.s(val) }

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

  property bool showClockSeconds: Config.showClockSeconds
  function toggleClockSeconds() { Config.showClockSeconds = !Config.showClockSeconds }

  property bool clock24h: Config.clock24h
  function toggleClock24h() { Config.clock24h = !Config.clock24h }

  property bool autoHideBar: Config.autoHideBar
  function toggleAutoHideBar() { Config.autoHideBar = !Config.autoHideBar }

  property string barPosition: Config.barPosition || "top"
  property var barPositionChoices: [
    { id: "top", label: "Top" },
    { id: "bottom", label: "Bottom" },
    { id: "left", label: "Left" },
    { id: "right", label: "Right" }
  ]
  function setBarPosition(pos) {
    if (!["top", "bottom", "left", "right"].includes(pos)) return
    Config.barPosition = pos
    root.barPosition = pos
  }

  property string currentTab: "general"
  onCurrentTabChanged: {
    mainModDropdown.visible = false
    layoutDropdown.visible = false
    switchDropdown.visible = false
    fontDropdown.visible = false
    if (currentTab === "appearance") root.refreshBarLayoutDraft()
  }
  property var tabsList: [
    { id: "general", label: "General", icon: "󰹑" },
    { id: "appearance", label: "Appearance", icon: "󰏘" },
    { id: "keybinds", label: "Keybinds", icon: "󰌌" },
    { id: "monitors", label: "Monitors", icon: "󰍹" }
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

  // ── Bar layout editor state ──
  // Working copy of Config.barLayout so drags can be previewed live and
  // only committed (and persisted) once, rather than writing to Config on
  // every intermediate drag frame.
  property var barLayoutDraft: JSON.parse(JSON.stringify(Config.barLayout))
  property var unplacedDraft: Config.unplacedBarModules()
  function refreshBarLayoutDraft() {
    root.barLayoutDraft = JSON.parse(JSON.stringify(Config.barLayout))
    root.unplacedDraft = Config.unplacedBarModules()
  }
  property string draggingModuleId: ""
  property string draggingFromZone: ""
  property var activeDragPill: null
  // Live preview of where a dragged pill would land if dropped right now.
  // Updated continuously from DropArea.onPositionChanged so the target zone
  // can open a gap and give visual feedback while still dragging, instead
  // of the layout only updating after release.
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
    root.removeFromCurrentZone(id)
    if (zone === "unplaced") {
      let u = root.unplacedDraft.slice()
      u.push(id)
      root.unplacedDraft = u
    } else {
      let draft = root.barLayoutDraft
      let arr = draft[zone].slice()
      let idx = (insertIdx === undefined || insertIdx < 0 || insertIdx > arr.length) ? arr.length : insertIdx
      arr.splice(idx, 0, id)
      let next = { left: draft.left, center: draft.center, right: draft.right }
      next[zone] = arr
      root.barLayoutDraft = next
    }
  }

  function commitBarLayout() {
    Config.setBarLayout(root.barLayoutDraft)
  }

  function resetBarLayout() {
    Config.barLayout = Config.defaultBarLayout()
    Config.saveSettings()
    root.refreshBarLayoutDraft()
  }

  property int capturingIdx: -1

  ListModel { id: keybindsModel }

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
              disabled: m.disabled || false
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
    onVisibleChanged: if (!visible) { mainModDropdown.visible = false; fontDropdown.visible = false }

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
        else root.menuOpen = false
      }

      Rectangle {
        id: settingsCard
        width: Math.max(s(2000), Math.min(s(1100), Screen.width - s(80)))
        height: Math.max(s(500), Math.min(s(1300), Screen.height - s(80)))
        x: Math.floor((Screen.width - width) / 2)
        y: Math.floor((Screen.height - height) / 2)
        radius: s(Config.uiRadius + 6)
        color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.94)
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
                  font.pixelSize: s(11)
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.text
                  clip: true
                  onTextChanged: root.searchQuery = text
                  Text { text: "Search settings..."; color: MatugenColors.textDim; visible: !parent.text; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
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
                      font.pixelSize: s(11)
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
          onContentYChanged: { mainModDropdown.visible = false; fontDropdown.visible = false }
          contentHeight: mainColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          ColumnLayout {
            id: mainColumn
            width: mainFlick.width
            spacing: s(14)

            Text { visible: root.currentTab === "appearance" && root.matches("Bar position"); text: "BAR POSITION"; font.pixelSize: s(9); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.border }

            Rectangle {
              visible: root.currentTab === "appearance" && root.matches("Bar position")
              Layout.fillWidth: true
              Layout.preferredHeight: s(44)
              radius: s(Config.uiRadius)
              color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

              RowLayout {
                anchors.fill: parent
                anchors.margins: s(10)
                spacing: s(8)

                Text { text: "󰝚"; font.pixelSize: s(14); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent }
                Text { text: "Bar position"; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text; Layout.fillWidth: true }

                RowLayout {
                  spacing: s(4)
                  Repeater {
                    model: root.barPositionChoices
                    delegate: Rectangle {
                      width: s(50); height: s(26); radius: s(6)
                      color: root.barPosition === modelData.id
                        ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.22)
                        : (barPosMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.08))
                      border.width: root.barPosition === modelData.id ? 1 : 0
                      border.color: MatugenColors.accent
                      Behavior on color { ColorAnimation { duration: 150 } }

                      Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: s(9)
                        font.weight: Font.Bold
                        font.family: "JetBrainsMono Nerd Font"
                        color: root.barPosition === modelData.id ? MatugenColors.accent : MatugenColors.text
                      }

                      MouseArea {
                        id: barPosMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setBarPosition(modelData.id)
                      }
                    }
                  }
                }
              }
            }

            Text { visible: root.currentTab === "general" && root.matches("Wallpaper directory"); text: "WALLPAPER DIRECTORY"; font.pixelSize: s(9); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.border }

            Rectangle {
              visible: root.currentTab === "general" && root.matches("Wallpaper directory")
              Layout.fillWidth: true
              Layout.preferredHeight: s(44)
              radius: s(Config.uiRadius)
              color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

              RowLayout {
                anchors.fill: parent
                anchors.margins: s(10)
                spacing: s(8)

                Text { text: "󰉏"; font.pixelSize: s(14); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent }

                TextInput {
                  id: wallpaperDirInput
                  Layout.fillWidth: true
                  text: root.wallpaperDir
                  verticalAlignment: TextInput.AlignVCenter
                  font.pixelSize: s(11)
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.text
                  clip: true
                  onAccepted: root.setWallpaperDir(text)
                  onActiveFocusChanged: if (!activeFocus) root.setWallpaperDir(text)
                }
              }
            }

            Text { visible: root.currentTab === "general" && root.matches("UI scale"); text: "UI SCALE"; font.pixelSize: s(9); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.border }

            Rectangle {
              visible: root.currentTab === "general" && root.matches("UI scale")
              Layout.fillWidth: true
              Layout.preferredHeight: s(44)
              radius: s(Config.uiRadius)
              color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

              RowLayout {
                anchors.fill: parent
                anchors.margins: s(10)
                spacing: s(8)

                Text { text: "󰍉"; font.pixelSize: s(14); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent }
                Text { text: "UI scale"; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text }

                Item { Layout.fillWidth: true }

                Item { Layout.preferredWidth: 110; Layout.preferredHeight: 24

                  // Dragging previews locally in uiScaleDraft; Config.uiScale
                  // (and therefore this whole panel's own s()-driven sizing)
                  // only updates on release. Committing on every drag frame
                  // made the panel resize itself mid-drag, which moved the
                  // slider out from under the cursor.
                  property real uiScaleDraft: Config.uiScale

                  Rectangle {
                    id: uiScaleTrack
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.1)

                    // 0.75-1.5x range: below 0.75 bar text/icons get too
                    // small to read; above 1.5 modules start overflowing.
                    readonly property real ratio: (parent.uiScaleDraft - 0.75) / 0.75

                    Rectangle {
                      width: uiScaleTrack.width * uiScaleTrack.ratio
                      height: parent.height
                      radius: parent.radius
                      color: MatugenColors.accent
                    }

                    Rectangle {
                      id: uiScaleHandle
                      width: 16; height: 16; radius: 8
                      color: MatugenColors.accent
                      anchors.verticalCenter: parent.verticalCenter
                      x: uiScaleTrack.width * uiScaleTrack.ratio - width / 2
                    }

                    MouseArea {
                      id: uiScaleMa
                      anchors.fill: parent
                      anchors.margins: -8
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      preventStealing: true

                      function draftFromX(mx) {
                        let trackX = mx - 8
                        let ratio = Math.max(0, Math.min(1, trackX / uiScaleTrack.width))
                        uiScaleTrack.parent.uiScaleDraft = Math.round((0.75 + ratio * 0.75) * 20) / 20
                      }
                      onPressed: (mouse) => draftFromX(mouse.x)
                      onPositionChanged: (mouse) => { if (pressed) draftFromX(mouse.x) }
                      onReleased: Config.uiScale = uiScaleTrack.parent.uiScaleDraft
                    }
                  }
                }

                Text { text: uiScaleMa.pressed ? uiScaleTrack.parent.uiScaleDraft.toFixed(2) + "x" : Config.uiScale.toFixed(2) + "x"; font.pixelSize: s(12); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent; Layout.preferredWidth: s(48); horizontalAlignment: Text.AlignHCenter }
              }
            }

            Text { visible: root.currentTab === "general" && root.matches("Workspaces"); text: "WORKSPACES"; font.pixelSize: s(9); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.border }

            Rectangle {
              visible: root.currentTab === "general" && root.matches("Workspaces")
              Layout.fillWidth: true
              Layout.preferredHeight: s(44)
              radius: s(Config.uiRadius)
              color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

              RowLayout {
                anchors.fill: parent
                anchors.margins: s(10)
                spacing: s(8)

                Text { text: "󰽿"; font.pixelSize: s(14); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent }
                Text { text: "Workspace count"; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text; Layout.fillWidth: true }

                Rectangle {
                  Layout.preferredWidth: s(56)
                  Layout.preferredHeight: s(28)
                  radius: s(6)
                  color: Qt.rgba(1, 1, 1, wsCountInput.activeFocus ? 0.12 : 0.08)
                  border.width: wsCountInput.activeFocus ? 1 : 0
                  border.color: MatugenColors.accent
                  Behavior on color { ColorAnimation { duration: 120 } }

                  TextInput {
                    id: wsCountInput
                    anchors.fill: parent
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    font.pixelSize: s(13)
                    font.weight: Font.Bold
                    font.family: "JetBrainsMono Nerd Font"
                    color: MatugenColors.accent
                    selectionColor: MatugenColors.accent
                    text: Config.workspaceCount
                    maximumLength: 2
                    inputMethodHints: Qt.ImhDigitsOnly

                    onActiveFocusChanged: {
                      if (activeFocus) {
                        selectAll()
                      } else {
                        let n = parseInt(text)
                        if (isNaN(n)) n = Config.workspaceCount
                        n = Math.max(1, Math.min(20, n))
                        Config.workspaceCount = n
                        root.applyWorkspaceCount()
                        text = Config.workspaceCount
                      }
                    }
                    onTextChanged: {
                      if (!activeFocus) return
                      // Strip anything that isn't a digit as it's typed, so
                      // letters/symbols/minus signs can never land in the
                      // field in the first place.
                      let digits = text.replace(/[^0-9]/g, "")
                      if (digits !== text) { text = digits; return }
                      if (digits === "") return
                      let n = parseInt(digits)
                      if (n > 20) { text = "20"; return }
                      if (n >= 1) {
                        Config.workspaceCount = n
                        root.applyWorkspaceCount()
                      }
                    }
                    Keys.onReturnPressed: wsCountInput.focus = false
                    Keys.onEnterPressed: wsCountInput.focus = false
                    Keys.onEscapePressed: { text = Config.workspaceCount; wsCountInput.focus = false }
                  }
                }
              }
            }

            Rectangle { visible: root.currentTab === "general" || root.currentTab === "keybinds"; Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

            Text { visible: root.currentTab === "appearance" && root.matches("Bar style"); text: "BAR STYLE"; font.pixelSize: s(9); font.weight: Font.Bold; font.family: root.fontFamily; color: MatugenColors.border }

            Rectangle {
              visible: root.currentTab === "appearance" && root.matches("Bar style")
              Layout.fillWidth: true
              Layout.preferredHeight: s(44)
              radius: s(Config.uiRadius)
              color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

              RowLayout {
                anchors.fill: parent
                anchors.margins: s(10)
                spacing: s(8)

                Text { text: "󰕮"; font.pixelSize: s(14); font.family: root.fontFamily; color: MatugenColors.accent }
                Text { text: "Bar style"; font.pixelSize: s(12); font.family: root.fontFamily; color: MatugenColors.text; Layout.fillWidth: true }

                RowLayout {
                  spacing: s(4)
                  Repeater {
                    model: [ { id: "modular", label: "Separated" }, { id: "solid", label: "Connected" } ]
                    delegate: Rectangle {
                      width: s(78); height: s(26); radius: s(6)
                      color: Config.barStyle === modelData.id
                        ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.22)
                        : (barStyleMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.08))
                      border.width: Config.barStyle === modelData.id ? 1 : 0
                      border.color: MatugenColors.accent
                      Behavior on color { ColorAnimation { duration: 150 } }

                      Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: s(9)
                        font.weight: Font.Bold
                        font.family: root.fontFamily
                        color: Config.barStyle === modelData.id ? MatugenColors.accent : MatugenColors.text
                      }

                      MouseArea {
                        id: barStyleMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.barStyle = modelData.id
                      }
                    }
                  }
                }
              }
            }

            Text { visible: root.currentTab === "appearance" && root.matches("Font") && root.fontChoices.length > 1; text: "FONT"; font.pixelSize: s(9); font.weight: Font.Bold; font.family: root.fontFamily; color: MatugenColors.border }

            Rectangle {
              id: fontRow
              visible: root.currentTab === "appearance" && root.matches("Font") && root.fontChoices.length > 1
              Layout.fillWidth: true
              Layout.preferredHeight: s(44)
              radius: s(Config.uiRadius)
              color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

              RowLayout {
                anchors.fill: parent
                anchors.margins: s(10)
                spacing: s(8)

                Text { text: "󰛖"; font.pixelSize: s(14); font.family: root.fontFamily; color: MatugenColors.accent }
                Text { text: "UI Font"; font.pixelSize: s(12); font.family: root.fontFamily; color: MatugenColors.text; Layout.fillWidth: true }

                Text {
                  text: root.fontFamily
                  font.pixelSize: s(11)
                  font.weight: Font.Bold
                  font.family: root.fontFamily
                  color: MatugenColors.accent
                  elide: Text.ElideRight
                  Layout.maximumWidth: s(140)
                }

                Text {
                  text: fontDropdown.visible ? "󰅃" : "󰅀"
                  font.pixelSize: s(12)
                  font.family: root.fontFamily
                  color: fontChevronMa.containsMouse ? MatugenColors.accent : MatugenColors.textDim
                  Behavior on color { ColorAnimation { duration: 150 } }
                  MouseArea {
                    id: fontChevronMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: fontDropdown.visible = !fontDropdown.visible
                  }
                }
              }
            }

            // Inline expanding panel, matching the keyboard-layout dropdown
            // pattern: lives in the normal ColumnLayout flow right below its
            // trigger row instead of floating as an absolutely-positioned
            // overlay on top of the settings card.
            Rectangle {
              id: fontDropdown
              visible: false
              Layout.fillWidth: true
              Layout.preferredHeight: visible ? Math.min(s(220), root.fontChoices.length * s(28) + s(12)) : 0
              radius: s(Config.uiRadius)
              clip: true
              color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.6)
              border.color: Qt.rgba(1, 1, 1, 0.08)
              border.width: 1
              Behavior on Layout.preferredHeight { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

              ListView {
                anchors.fill: parent
                anchors.margins: s(6)
                clip: true
                model: root.fontChoices
                delegate: Rectangle {
                  width: ListView.view.width
                  height: s(26)
                  radius: s(6)
                  property bool selected: root.fontFamily === modelData
                  color: selected
                    ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16)
                    : (fontItemMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                  Behavior on color { ColorAnimation { duration: 120 } }

                  Text {
                    anchors.left: parent.left
                    anchors.leftMargin: s(8)
                    anchors.right: parent.right
                    anchors.rightMargin: s(8)
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    elide: Text.ElideRight
                    font.pixelSize: s(11)
                    font.family: modelData
                    color: selected ? MatugenColors.accent : MatugenColors.text
                  }

                  MouseArea {
                    id: fontItemMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.setFontFamily(modelData); fontDropdown.visible = false }
                  }
                }
              }
            }

            Text { visible: root.currentTab === "appearance" && root.matches("Border radius"); text: "BORDER RADIUS"; font.pixelSize: s(9); font.weight: Font.Bold; font.family: root.fontFamily; color: MatugenColors.border }

            Rectangle {
              visible: root.currentTab === "appearance" && root.matches("Border radius")
              Layout.fillWidth: true
              Layout.preferredHeight: s(44)
              radius: s(Config.uiRadius)
              color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

              RowLayout {
                anchors.fill: parent
                anchors.margins: s(10)
                spacing: s(8)

                Text { text: "󰛐"; font.pixelSize: s(14); font.family: root.fontFamily; color: MatugenColors.accent }
                Text { text: "Border radius"; font.pixelSize: s(12); font.family: root.fontFamily; color: MatugenColors.text; Layout.fillWidth: true }

                Rectangle {
                  Layout.preferredWidth: s(56)
                  Layout.preferredHeight: s(28)
                  radius: s(6)
                  color: Qt.rgba(1, 1, 1, radiusInput.activeFocus ? 0.12 : 0.08)
                  border.width: radiusInput.activeFocus ? 1 : 0
                  border.color: MatugenColors.accent
                  Behavior on color { ColorAnimation { duration: 120 } }

                  TextInput {
                    id: radiusInput
                    anchors.fill: parent
                    anchors.leftMargin: s(8)
                    anchors.rightMargin: s(4)
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    font.pixelSize: s(13)
                    font.weight: Font.Bold
                    font.family: root.fontFamily
                    color: MatugenColors.accent
                    selectionColor: MatugenColors.accent
                    text: Config.uiRadius + "px"
                    validator: IntValidator { bottom: 0; top: 20 }
                    inputMethodHints: Qt.ImhDigitsOnly

                    // Strip the "px" suffix for editing so keystrokes don't
                    // fight the displayed text against the cursor position.
                    // Applies live on every valid keystroke instead of
                    // waiting for the field to lose focus.
                    onActiveFocusChanged: {
                      if (activeFocus) {
                        text = String(Config.uiRadius)
                        selectAll()
                      } else {
                        text = Config.uiRadius + "px"
                      }
                    }
                    onTextChanged: {
                      if (!activeFocus) return
                      let n = parseInt(text)
                      if (!isNaN(n)) root.setUiRadius(n)
                    }
                    Keys.onReturnPressed: radiusInput.focus = false
                    Keys.onEnterPressed: radiusInput.focus = false
                    Keys.onEscapePressed: { text = Config.uiRadius + "px"; radiusInput.focus = false }
                  }
                }
              }
            }

            Text { visible: root.currentTab === "appearance" && root.matches("Bar width"); text: "BAR WIDTH"; font.pixelSize: s(9); font.weight: Font.Bold; font.family: root.fontFamily; color: MatugenColors.border }

            Rectangle {
              visible: root.currentTab === "appearance" && root.matches("Bar width")
              Layout.fillWidth: true
              Layout.preferredHeight: s(44)
              radius: s(Config.uiRadius)
              color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

              RowLayout {
                anchors.fill: parent
                anchors.margins: s(10)
                spacing: s(8)

                Text { text: "󰡍"; font.pixelSize: s(14); font.family: root.fontFamily; color: MatugenColors.accent }
                Text { text: "Bar width"; font.pixelSize: s(12); font.family: root.fontFamily; color: MatugenColors.text }

                Item { Layout.fillWidth: true }

                Item { Layout.preferredWidth: s(110); Layout.preferredHeight: s(24)

                  Rectangle {
                    id: barWidthTrack
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: s(4)
                    radius: s(2)
                    color: Qt.rgba(1, 1, 1, 0.1)

                    // 40-100% range: below 40 the zones would overlap.
                    readonly property real ratio: Config.barWidthPercent / 100

                    Rectangle {
                      width: barWidthTrack.width * barWidthTrack.ratio
                      height: parent.height
                      radius: parent.radius
                      color: MatugenColors.accent
                    }

                    Rectangle {
                      id: barWidthHandle
                      width: s(16); height: s(16); radius: s(8)
                      color: MatugenColors.accent
                      anchors.verticalCenter: parent.verticalCenter
                      x: barWidthTrack.width * barWidthTrack.ratio - width / 2
                    }

                    MouseArea {
                      id: barWidthMa
                      anchors.fill: parent
                      anchors.margins: s(-8)
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      preventStealing: true

                      function updateFromX(mx) {
                        let trackX = mx - s(8)
                        let ratio = Math.max(0, Math.min(1, trackX / barWidthTrack.width))
                        Config.barWidthPercent = Math.round(ratio * 100)
                      }
                      onPressed: (mouse) => updateFromX(mouse.x)
                      onPositionChanged: (mouse) => { if (pressed) updateFromX(mouse.x) }
                    }
                  }
                }

                Text { text: Config.barWidthPercent + "%"; font.pixelSize: s(12); font.weight: Font.Bold; font.family: root.fontFamily; color: MatugenColors.accent; Layout.preferredWidth: s(40); horizontalAlignment: Text.AlignHCenter }
              }
            }

            Text { visible: root.currentTab === "appearance" && root.matches("Auto hide bar"); text: "AUTO HIDE"; font.pixelSize: s(9); font.weight: Font.Bold; font.family: root.fontFamily; color: MatugenColors.border }

            Rectangle {
              visible: root.currentTab === "appearance" && root.matches("Auto hide bar")
              Layout.fillWidth: true
              Layout.preferredHeight: s(44)
              radius: s(Config.uiRadius)
              color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

              RowLayout {
                anchors.fill: parent
                anchors.margins: s(10)
                spacing: s(8)

                Text { text: "󰈈"; font.pixelSize: s(14); font.family: root.fontFamily; color: MatugenColors.accent }
                Text { text: "Auto hide bar"; font.pixelSize: s(12); font.family: root.fontFamily; color: MatugenColors.text; Layout.fillWidth: true }

                Rectangle {
                  width: s(48); height: s(26); radius: s(13); Layout.preferredWidth: s(48); Layout.preferredHeight: s(26)
                  color: root.autoHideBar ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.08)
                  Behavior on color { ColorAnimation { duration: 250 } }
                  Rectangle {
                    width: s(20); height: s(20); radius: s(10); color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.autoHideBar ? parent.width - width - s(3) : s(3)
                    Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleAutoHideBar() }
                }
              }
            }

            Rectangle { visible: root.currentTab === "appearance" && root.matches("Color theme"); Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

            Text { visible: root.currentTab === "appearance" && root.matches("Color theme"); text: "COLOR THEME"; font.pixelSize: s(9); font.weight: Font.Bold; font.family: root.fontFamily; color: MatugenColors.border }

            Rectangle {
              visible: root.currentTab === "appearance" && root.matches("Color theme")
              Layout.fillWidth: true
              Layout.preferredHeight: s(36)
              radius: s(Config.uiRadius)
              color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

              RowLayout {
                anchors.fill: parent
                anchors.margins: s(8)
                spacing: s(6)

                Text { text: "󰍉"; font.pixelSize: s(12); font.family: root.fontFamily; color: MatugenColors.textDim }

                TextInput {
                  id: themeSearchInput
                  Layout.fillWidth: true
                  text: root.themeSearchQuery
                  verticalAlignment: TextInput.AlignVCenter
                  font.pixelSize: s(11)
                  font.family: root.fontFamily
                  color: MatugenColors.text
                  clip: true
                  onTextChanged: root.themeSearchQuery = text
                  Text { text: "Search themes..."; color: MatugenColors.textDim; visible: !parent.text; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
                  Keys.onEscapePressed: { text = ""; themeSearchInput.focus = false }
                }
              }
            }

            GridLayout {
              visible: root.currentTab === "appearance" && root.matches("Color theme")
              Layout.fillWidth: true
              columns: 3
              columnSpacing: s(8)
              rowSpacing: s(8)

              Repeater {
                model: Config.themeChoices.filter(t => root.themeMatches(t.label))
                delegate: Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: s(56)
                  radius: s(Config.uiRadius)
                  property bool selected: root.colorScheme === modelData.id
                  color: selected
                    ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16)
                    : Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)
                  border.width: 1
                  border.color: selected ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.08)
                  Behavior on color { ColorAnimation { duration: 150 } }

                  property var preset: Config.themePresets[modelData.id]

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: s(8)
                    spacing: s(4)

                    RowLayout {
                      spacing: s(4)
                      Rectangle { width: s(12); height: s(12); radius: s(3); color: preset ? preset.bgBase : MatugenColors.bgBase }
                      Rectangle { width: s(12); height: s(12); radius: s(3); color: preset ? preset.accent : MatugenColors.accent }
                      Rectangle { width: s(12); height: s(12); radius: s(3); color: preset ? preset.text : MatugenColors.text }
                    }

                    Text {
                      text: modelData.label
                      font.pixelSize: s(10)
                      font.family: root.fontFamily
                      color: selected ? MatugenColors.accent : MatugenColors.text
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setColorScheme(modelData.id)
                  }
                }
              }

              Text {
                visible: root.currentTab === "appearance" && root.matches("Color theme") && Config.themeChoices.filter(t => root.themeMatches(t.label)).length === 0
                Layout.columnSpan: 3
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "No themes match \u201c" + root.themeSearchQuery + "\u201d"
                font.pixelSize: s(10)
                font.family: root.fontFamily
                color: MatugenColors.textDim
              }
            }

            Rectangle { visible: root.currentTab === "appearance"; Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

            RowLayout {
              visible: root.currentTab === "appearance" && root.matches("Bar layout")
              Layout.fillWidth: true
              Text { text: "BAR LAYOUT"; font.pixelSize: s(9); font.weight: Font.Bold; font.family: root.fontFamily; color: MatugenColors.border; Layout.fillWidth: true }
              Text {
                text: "Reset"
                font.pixelSize: s(9)
                font.family: root.fontFamily
                color: resetBarMa.containsMouse ? MatugenColors.accent : MatugenColors.textDim
                MouseArea { id: resetBarMa; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.resetBarLayout() }
              }
            }

            // ── Bar layout drag-and-drop editor ──
            // Modules are dragged as pills between an "Available" pool and
            // three ordered drop zones (Left/Center/Right) mirroring the
            // actual bar. Drops are staged in root.barLayoutDraft /
            // root.unplacedDraft and only written to Config (and disk) via
            // commitBarLayout(), so a half-finished drag never corrupts the
            // live bar mid-edit.
            ColumnLayout {
              visible: root.currentTab === "appearance" && root.matches("Bar layout")
              Layout.fillWidth: true
              spacing: s(10)

              Text { text: "Drag modules between zones. Changes apply immediately to the bar."; font.pixelSize: s(9); font.family: root.fontFamily; color: MatugenColors.textDim; wrapMode: Text.WordWrap; Layout.fillWidth: true }

              // Available (unplaced) pool
              Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.max(s(72), availableFlow.implicitHeight + s(20))
                radius: s(Config.uiRadius)
                color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.4)
                border.width: 1
                border.color: availableDrop.containsDrag ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.06)
                Behavior on border.color { ColorAnimation { duration: 120 } }

                DropArea {
                  id: availableDrop
                  anchors.fill: parent
                  onEntered: (drag) => { drag.accepted = root.draggingModuleId !== "" }
                  onDropped: {
                    root.moveModuleToZone(root.draggingModuleId, "unplaced")
                    root.commitBarLayout()
                    root.previewZone = ""
                    root.previewIdx = -1
                    if (root.activeDragPill) root.activeDragPill.dropHandled = true
                  }
                }

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: s(10)
                  spacing: s(6)

                  Text { text: "AVAILABLE"; font.pixelSize: s(8); font.weight: Font.Bold; font.family: root.fontFamily; color: MatugenColors.textDim }

                  Flow {
                    id: availableFlow
                    Layout.fillWidth: true
                    spacing: s(6)

                    move: Transition {
                      NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutCubic }
                    }
                    add: Transition {
                      NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutCubic }
                    }

                    Text {
                      visible: root.unplacedDraft.length === 0
                      text: "All modules placed"
                      font.pixelSize: s(10)
                      font.family: root.fontFamily
                      color: MatugenColors.textDim
                    }

                    Repeater {
                      model: root.unplacedDraft
                      delegate: BarModulePill {
                        required property string modelData
                        moduleId: modelData
                        zone: "unplaced"
                        controller: root
                        dragSurface: mainFlick.contentItem
                        onRemoveRequested: (id) => { root.moveModuleToZone(id, "unplaced"); root.commitBarLayout() }
                      }
                    }
                  }
                }
              }

              // Left / Center / Right zones, side by side
              RowLayout {
                Layout.fillWidth: true
                spacing: s(10)

                Repeater {
                  model: [
                    { zone: "left", label: "LEFT" },
                    { zone: "center", label: "CENTER" },
                    { zone: "right", label: "RIGHT" }
                  ]
                  delegate: Rectangle {
                    id: outerZone
                    required property var modelData
                    property string zone: modelData.zone
                    property string label: modelData.label
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(s(120), zoneCol.implicitHeight + s(20))
                    Layout.alignment: Qt.AlignTop
                    radius: s(Config.uiRadius)
                    color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)
                    border.width: 1
                    border.color: zoneDrop.containsDrag ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.06)
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    DropArea {
                      id: zoneDrop
                      anchors.fill: parent
                      onEntered: (drag) => { drag.accepted = root.draggingModuleId !== "" }
                      onPositionChanged: (drag) => {
                        if (root.draggingModuleId === "") return
                        root.previewZone = outerZone.zone
                        root.previewIdx = zoneDrop.computeInsertIdx(drag.x, drag.y)
                      }
                      onExited: {
                        if (root.previewZone === outerZone.zone) {
                          root.previewZone = ""
                          root.previewIdx = -1
                        }
                      }
                      onDropped: (drag) => {
                        let insertIdx = zoneDrop.computeInsertIdx(drag.x, drag.y)
                        root.moveModuleToZone(root.draggingModuleId, outerZone.zone, insertIdx)
                        root.commitBarLayout()
                        root.previewZone = ""
                        root.previewIdx = -1
                        if (root.activeDragPill) root.activeDragPill.dropHandled = true
                      }

                      // drag.x/drag.y arrive in zoneDrop's own coordinate
                      // space (it fills the whole outerZone Rectangle), but
                      // the pills live inside pillFlow, which is inset from
                      // outerZone by margins plus the header/hint text
                      // above it. Comparing drag.x/y directly against a
                      // pill's position (as before) compared two different
                      // coordinate spaces and silently produced the wrong
                      // index. Pills now lay out left-to-right (wrapping to
                      // a new row via Flow), so insertion order is
                      // determined by reading order: row-by-row (y), then
                      // left-to-right within a row (x), rather than purely
                      // by vertical position as when pills were stacked.
                      function computeInsertIdx(dragX, dragY) {
                        let local = zoneDrop.mapToItem(pillFlow, dragX, dragY)
                        let count = 0
                        for (let i = 0; i < pillFlow.children.length; i++) {
                          let child = pillFlow.children[i]
                          if (!child || child.modelData === undefined) continue
                          if (child.modelData === root.draggingModuleId) continue
                          // Treat two items as being on the "same row" if
                          // their vertical centers are within one pill's
                          // height of each other, since Flow rows aren't
                          // pixel-aligned to a fixed grid.
                          let sameRow = Math.abs((child.y + child.height / 2) - local.y) < child.height
                          let childCenterX = child.x + child.width / 2
                          let before = sameRow
                            ? (local.x >= childCenterX)
                            : (local.y >= child.y + child.height / 2)
                          if (before) count++
                        }
                        return count
                      }
                    }

                    ColumnLayout {
                      id: zoneCol
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.top: parent.top
                      anchors.margins: s(10)
                      spacing: s(6)

                      Text { text: outerZone.label; font.pixelSize: s(8); font.weight: Font.Bold; font.family: root.fontFamily; color: MatugenColors.textDim }

                      Text {
                        visible: root.barLayoutDraft[outerZone.zone].length === 0
                        text: "Drop here"
                        font.pixelSize: s(10)
                        font.family: root.fontFamily
                        color: MatugenColors.textDim
                      }

                      // Pills flow left-to-right (wrapping to a new row if
                      // the zone is too narrow) instead of stacking
                      // top-to-bottom, matching how modules actually lay
                      // out on the real bar.
                      Flow {
                        id: pillFlow
                        Layout.fillWidth: true
                        spacing: s(6)

                        Repeater {
                          model: root.barLayoutDraft[outerZone.zone]
                          delegate: RowLayout {
                            id: pillSlot
                            required property string modelData
                            required property int index
                            spacing: 0

                            // Opens a gap to the LEFT of this pill when the
                            // live drag preview says an item would be
                            // inserted at this index, so the row visibly
                            // shifts to make room while dragging instead of
                            // only settling after release. A RowLayout
                            // (rather than anchoring realPill next to
                            // gapBefore directly) is used here because
                            // BarModulePill has its own Behavior on x/y for
                            // settling into place; an anchor binding would
                            // win against that Behavior every frame and
                            // cause the pill to jitter instead of sliding.
                            readonly property bool gapActive: root.previewZone === outerZone.zone
                              && root.previewIdx === index
                              && root.draggingModuleId !== pillSlot.modelData

                            Rectangle {
                              id: gapBefore
                              Layout.preferredWidth: pillSlot.gapActive ? realPill.implicitWidth + s(6) : 0
                              Layout.preferredHeight: realPill.implicitHeight
                              color: "transparent"
                              Behavior on Layout.preferredWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            }

                            BarModulePill {
                              id: realPill
                              moduleId: pillSlot.modelData
                              zone: outerZone.zone
                              controller: root
                              dragSurface: mainFlick.contentItem
                              onRemoveRequested: (id) => { root.moveModuleToZone(id, "unplaced"); root.commitBarLayout() }
                            }
                          }
                        }

                        // Trailing gap: lets a pill be previewed as landing
                        // after the last item in the zone.
                        Rectangle {
                          Layout.preferredWidth: (root.previewZone === outerZone.zone
                            && root.previewIdx === root.barLayoutDraft[outerZone.zone].length)
                            ? s(34) : 0
                          Layout.preferredHeight: s(28)
                          color: "transparent"
                          Behavior on Layout.preferredWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }
                      }
                    }
                  }
                }
              }
            }

            Rectangle { visible: root.currentTab === "appearance" && root.matches("Bar layout"); Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

            Text { visible: root.currentTab === "general" && root.matches("Temperature unit"); text: "TEMPERATURE"; font.pixelSize: s(9); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.border }

            Rectangle {
              visible: root.currentTab === "general" && root.matches("Temperature unit")
              Layout.fillWidth: true
              Layout.preferredHeight: s(44)
              radius: s(Config.uiRadius)
              color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

              RowLayout {
                anchors.fill: parent
                anchors.margins: s(10)
                spacing: s(8)

                Text { text: "󰔏"; font.pixelSize: s(14); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent }
                Text { text: "Temperature unit"; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text; Layout.fillWidth: true }

                Rectangle {
                  width: s(70); height: s(26); radius: s(13); Layout.preferredWidth: s(70); Layout.preferredHeight: s(26)
                  color: Qt.rgba(1, 1, 1, 0.08)
                  Rectangle {
                    width: s(33); height: s(22); radius: s(11)
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.useFahrenheit ? parent.width - width - s(2) : s(2)
                    color: MatugenColors.accent
                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Text { anchors.centerIn: parent; text: root.useFahrenheit ? "°F" : "°C"; font.pixelSize: s(10); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.bgBase }
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleTempUnit() }
                }
              }
            }

            Text { visible: root.currentTab === "general" && root.matches("Clock"); text: "CLOCK"; font.pixelSize: s(9); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.border }

            Rectangle {
              visible: root.currentTab === "general" && root.matches("Clock seconds")
              Layout.fillWidth: true
              Layout.preferredHeight: s(44)
              radius: s(Config.uiRadius)
              color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

              RowLayout {
                anchors.fill: parent
                anchors.margins: s(10)
                spacing: s(8)

                Text { text: "󰥔"; font.pixelSize: s(14); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent }
                Text { text: "Show seconds in clock"; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text; Layout.fillWidth: true }

                Rectangle {
                  width: s(48); height: s(26); radius: s(13); Layout.preferredWidth: s(48); Layout.preferredHeight: s(26)
                  color: root.showClockSeconds ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.08)
                  Behavior on color { ColorAnimation { duration: 250 } }
                  Rectangle {
                    width: s(20); height: s(20); radius: s(10); color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.showClockSeconds ? parent.width - width - s(3) : s(3)
                    Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleClockSeconds() }
                }
              }
            }

            Rectangle {
              visible: root.currentTab === "general" && root.matches("Clock time format")
              Layout.fillWidth: true
              Layout.preferredHeight: s(44)
              radius: s(Config.uiRadius)
              color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

              RowLayout {
                anchors.fill: parent
                anchors.margins: s(10)
                spacing: s(8)

                Text { text: "󰅐"; font.pixelSize: s(14); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent }
                Text { text: "Time format"; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text; Layout.fillWidth: true }

                Rectangle {
                  width: s(70); height: s(26); radius: s(13); Layout.preferredWidth: s(70); Layout.preferredHeight: s(26)
                  color: Qt.rgba(1, 1, 1, 0.08)
                  Rectangle {
                    width: s(33); height: s(22); radius: s(11)
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.clock24h ? parent.width - width - s(2) : s(2)
                    color: MatugenColors.accent
                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Text { anchors.centerIn: parent; text: root.clock24h ? "24h" : "12h"; font.pixelSize: s(9); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.bgBase }
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleClock24h() }
                }
              }
            }

            Text { visible: root.currentTab === "keybinds" && root.matches("Main mod"); text: "MAIN MOD"; font.pixelSize: s(9); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.border }

            Rectangle {
              id: mainModRow
              visible: root.currentTab === "keybinds" && root.matches("Main mod")
              Layout.fillWidth: true
              Layout.preferredHeight: s(44)
              radius: s(Config.uiRadius)
              color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

              RowLayout {
                anchors.fill: parent
                anchors.margins: s(10)
                spacing: s(8)

                Text { text: "󰌌"; font.pixelSize: s(14); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent }
                Text { text: "Main modifier"; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text; Layout.fillWidth: true }

                Text { text: root.mainMod; font.pixelSize: s(11); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent }

                Text {
                  text: mainModDropdown.visible ? "󰅃" : "󰅀"
                  font.pixelSize: s(12)
                  font.family: "JetBrainsMono Nerd Font"
                  color: mainModMa.containsMouse ? MatugenColors.accent : MatugenColors.textDim
                  Behavior on color { ColorAnimation { duration: 150 } }
                  MouseArea {
                    id: mainModMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mainModDropdown.visible = !mainModDropdown.visible
                  }
                }
              }
            }

            // Inline expanding panel, matching the keyboard-layout dropdown
            // pattern: lives in the normal ColumnLayout flow right below its
            // trigger row instead of floating as an absolutely-positioned
            // overlay on top of the settings card.
            Rectangle {
              id: mainModDropdown
              visible: false
              Layout.fillWidth: true
              Layout.preferredHeight: visible ? (root.validMods.length * s(26) + s(12)) : 0
              radius: s(Config.uiRadius)
              clip: true
              color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.6)
              border.color: Qt.rgba(1, 1, 1, 0.08)
              border.width: 1
              Behavior on Layout.preferredHeight { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: s(6)
                spacing: s(2)

                Repeater {
                  model: root.validMods
                  delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: s(24)
                    radius: s(6)
                    color: mainModItemMa.containsMouse ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                      anchors.left: parent.left
                      anchors.leftMargin: s(8)
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData
                      font.pixelSize: s(11)
                      font.family: "JetBrainsMono Nerd Font"
                      color: root.mainMod === modelData ? MatugenColors.accent : MatugenColors.text
                    }

                    MouseArea {
                      id: mainModItemMa
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: { root.setMainMod(modelData); mainModDropdown.visible = false }
                    }
                  }
                }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              visible: root.currentTab === "keybinds" && root.matches("Keybinds")
              Text { text: "KEYBINDS"; font.pixelSize: s(9); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.border; Layout.fillWidth: true }
              Text {
                text: "󰑐"
                font.pixelSize: s(12)
                font.family: "JetBrainsMono Nerd Font"
                color: kbRefreshMa.containsMouse ? MatugenColors.accent : MatugenColors.textDim
                Behavior on color { ColorAnimation { duration: 150 } }
                MouseArea { id: kbRefreshMa; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.refreshKeybinds() }
              }
            }

            Repeater {
              model: keybindsModel
              delegate: Rectangle {
                visible: root.currentTab === "keybinds" && (root.matches("Keybinds") || root.matches(model.key) || root.matches(model.name))
                Layout.fillWidth: true
                Layout.preferredHeight: s(40)
                radius: s(8)
                color: model.editing ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.14) : Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)
                border.width: model.editing ? 1 : 0
                border.color: MatugenColors.accent
                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: s(10)
                  spacing: s(8)

                  Text { text: root.mainMod; font.pixelSize: s(11); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textDim }
                  Text { text: "+"; font.pixelSize: s(11); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textDim }

                  Item {
                    id: renameEdit
                    Layout.fillWidth: true
                    Layout.preferredHeight: s(20)
                    property bool renaming: false
                    function startEdit() { renaming = true; nameInput.text = model.name; nameInput.forceActiveFocus(); nameInput.selectAll() }
                    function commit() { renaming = false; if (nameInput.text.trim()) root.setKeybindName(index, nameInput.text.trim()) }

                    Text {
                      anchors.fill: parent
                      visible: !renameEdit.renaming
                      verticalAlignment: Text.AlignVCenter
                      text: model.name
                      font.pixelSize: s(11)
                      font.family: "JetBrainsMono Nerd Font"
                      color: MatugenColors.text
                      elide: Text.ElideRight
                      MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onDoubleClicked: renameEdit.startEdit() }
                    }

                    TextInput {
                      id: nameInput
                      anchors.fill: parent
                      visible: renameEdit.renaming
                      verticalAlignment: TextInput.AlignVCenter
                      font.pixelSize: s(11)
                      font.family: "JetBrainsMono Nerd Font"
                      color: MatugenColors.accent
                      clip: true
                      onAccepted: renameEdit.commit()
                      Keys.onEscapePressed: renameEdit.renaming = false
                      onActiveFocusChanged: if (!activeFocus && renameEdit.renaming) renameEdit.commit()
                    }
                  }

                  Rectangle {
                    width: s(72); height: s(26); radius: s(6); Layout.preferredWidth: s(72); Layout.preferredHeight: s(26)
                    color: model.error ? Qt.rgba(1, 0.3, 0.3, 0.22) : (model.editing ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.22) : Qt.rgba(1, 1, 1, 0.08))
                    border.width: model.editing || model.error ? 1 : 0
                    border.color: model.error ? "#ff4d4d" : MatugenColors.accent

                    Text {
                      anchors.centerIn: parent
                      text: model.editing ? "press key" : model.key
                      font.pixelSize: model.editing ? 9 : 11
                      font.weight: Font.Bold
                      font.family: "JetBrainsMono Nerd Font"
                      color: model.editing ? MatugenColors.accent : MatugenColors.text
                    }

                    MouseArea {
                      id: keyEditMa
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (model.editing) root.cancelCapture()
                        else root.startCapture(index)
                      }
                    }

                    Keys.onPressed: {
                      if (!model.editing) return
                      let token = root.keyEventToToken(event)
                      if (token) root.setKeybindKey(index, token)
                      event.accepted = true
                    }
                    focus: model.editing

                    Text {
                      visible: !!model.error
                      anchors.top: parent.bottom
                      anchors.topMargin: s(4)
                      anchors.right: parent.right
                      width: s(160)
                      wrapMode: Text.WordWrap
                      horizontalAlignment: Text.AlignRight
                      text: model.error
                      font.pixelSize: s(9)
                      font.family: "JetBrainsMono Nerd Font"
                      color: "#ff4d4d"
                      z: 10
                    }
                  }
                }
              }
            }

            Rectangle { visible: root.currentTab === "general"; Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

            Text { visible: root.currentTab === "general"; text: "KEYBOARD LAYOUTS"; font.pixelSize: s(9); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.border }

            Flow {
              visible: root.currentTab === "general"
              Layout.fillWidth: true
              spacing: s(6)

              Repeater {
                model: root.currentLayouts
                Rectangle {
                  width: layoutChipRow.implicitWidth + s(20)
                  height: s(28)
                  radius: s(14)
                  color: Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.18)
                  border.color: Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.4)
                  border.width: 1

                  RowLayout {
                    id: layoutChipRow
                    anchors.centerIn: parent
                    spacing: s(6)
                    Text { text: modelData; font.pixelSize: s(11); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text }
                    Text {
                      text: "✖"
                      font.pixelSize: s(10)
                      font.family: "JetBrainsMono Nerd Font"
                      color: chipRemMa.containsMouse ? MatugenColors.accent : MatugenColors.textDim
                      Behavior on color { ColorAnimation { duration: 150 } }
                      MouseArea { id: chipRemMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.removeLayout(modelData) }
                    }
                  }
                }
              }
            }

            Rectangle {
              id: addLayoutBtn
              visible: root.currentTab === "general"
              Layout.fillWidth: true
              Layout.preferredHeight: s(36)
              radius: s(Config.uiRadius)
              color: addLayoutMa.containsMouse || layoutDropdown.visible ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16) : Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)
              Behavior on color { ColorAnimation { duration: 150 } }

              RowLayout {
                anchors.centerIn: parent
                spacing: s(6)
                Text { text: "+"; font.pixelSize: s(13); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text }
                Text { text: "Add layout"; font.pixelSize: s(11); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text }
              }

              MouseArea { id: addLayoutMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: layoutDropdown.visible = !layoutDropdown.visible }
            }

            Rectangle {
              id: layoutDropdown
              Layout.fillWidth: true
              visible: false
              Layout.preferredHeight: visible ? s(220) : 0
              radius: s(Config.uiRadius)
              clip: true
              color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.6)
              border.color: Qt.rgba(1, 1, 1, 0.08)
              border.width: 1

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: s(8)
                spacing: s(6)

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: s(30)
                  radius: s(6)
                  color: Qt.rgba(1, 1, 1, 0.06)
                  TextInput {
                    id: layoutSearchInput
                    anchors.fill: parent
                    anchors.margins: s(8)
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: s(11)
                    font.family: "JetBrainsMono Nerd Font"
                    color: MatugenColors.text
                    clip: true
                    Text {
                      text: "Search layout code..."
                      color: MatugenColors.textDim
                      visible: !parent.text
                      font: parent.font
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }
                }

                ListView {
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  clip: true
                  model: root.availableLayoutCodes.filter(c => c.toLowerCase().includes(layoutSearchInput.text.toLowerCase()))
                  delegate: Rectangle {
                    width: ListView.view.width
                    height: s(28)
                    radius: s(6)
                    color: layoutItemMa.containsMouse ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                      anchors.left: parent.left
                      anchors.leftMargin: s(8)
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData
                      font.pixelSize: s(11)
                      font.family: "JetBrainsMono Nerd Font"
                      color: root.currentLayouts.includes(modelData) ? MatugenColors.accent : MatugenColors.text
                    }
                    MouseArea {
                      id: layoutItemMa
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: { root.addLayout(modelData); layoutDropdown.visible = false; layoutSearchInput.text = "" }
                    }
                  }
                }
              }
            }

            Text { visible: root.currentTab === "general"; text: "SWITCH KEY"; font.pixelSize: s(9); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.border }

            Rectangle {
              visible: root.currentTab === "general"
              Layout.fillWidth: true
              Layout.preferredHeight: s(44)
              radius: s(Config.uiRadius)
              color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

              RowLayout {
                anchors.fill: parent
                anchors.margins: s(10)
                spacing: s(8)

                Text { text: "󰌌"; font.pixelSize: s(14); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent }
                Text { text: "Layout switch key"; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text; Layout.fillWidth: true }

                Text {
                  text: {
                    let found = root.switchOptionChoices.find(function(c) { return c.value === root.layoutSwitchOption })
                    return found ? found.label : "Custom"
                  }
                  font.pixelSize: s(11)
                  font.weight: Font.Bold
                  font.family: "JetBrainsMono Nerd Font"
                  color: MatugenColors.accent
                }

                Text {
                  text: switchDropdown.visible ? "󰅃" : "󰅀"
                  font.pixelSize: s(12)
                  font.family: "JetBrainsMono Nerd Font"
                  color: switchOptMa.containsMouse ? MatugenColors.accent : MatugenColors.textDim
                  Behavior on color { ColorAnimation { duration: 150 } }
                  MouseArea { id: switchOptMa; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: switchDropdown.visible = !switchDropdown.visible }
                }
              }
            }

            Rectangle {
              id: switchDropdown
              visible: false
              Layout.fillWidth: true
              height: visible ? (root.switchOptionChoices.length * 30 + 12) : 0
              radius: s(Config.uiRadius)
              clip: true
              color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.6)
              border.color: Qt.rgba(1, 1, 1, 0.08)
              border.width: 1
              Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: s(6)
                spacing: s(2)

                Repeater {
                  model: root.switchOptionChoices
                  delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: s(28)
                    radius: s(6)
                    color: switchItemMa.containsMouse ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                      anchors.left: parent.left
                      anchors.leftMargin: s(8)
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.label
                      font.pixelSize: s(11)
                      font.family: "JetBrainsMono Nerd Font"
                      color: root.layoutSwitchOption === modelData.value ? MatugenColors.accent : MatugenColors.text
                    }

                    MouseArea {
                      id: switchItemMa
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: { root.setSwitchOption(modelData.value); switchDropdown.visible = false }
                    }
                  }
                }
              }
            }

            Rectangle { visible: root.currentTab === "general" || root.currentTab === "monitors"; Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

            RowLayout {
              Layout.fillWidth: true
              visible: root.currentTab === "monitors"
              Text { text: "MONITORS"; font.pixelSize: s(9); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.border; Layout.fillWidth: true }
            }

            Repeater {
              model: monitorsModel
              delegate: Rectangle {
                visible: root.currentTab === "monitors"
                Layout.fillWidth: true
                implicitHeight: monCol.implicitHeight + s(20)
                radius: s(Config.uiRadius)
                color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

                ColumnLayout {
                  id: monCol
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: s(10)
                  spacing: s(8)

                  RowLayout {
                    Layout.fillWidth: true
                    Text { text: "󰍹"; font.pixelSize: s(14); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent }
                    Text { text: model.name; font.pixelSize: s(12); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text; Layout.fillWidth: true }
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: s(8)

                    Text { text: "resolution"; font.pixelSize: s(10); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textDim }

                    Rectangle {
                      Layout.fillWidth: true
                      Layout.preferredHeight: s(26)
                      radius: s(6)
                      color: resBtnMa.containsMouse || root.resDropdownIdx === index ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                      Behavior on color { ColorAnimation { duration: 150 } }

                      Text {
                        anchors.centerIn: parent
                        text: root.resLabel(model.width, model.height) + "  (" + model.width + "x" + model.height + ")"
                        font.pixelSize: s(10)
                        font.weight: Font.Bold
                        font.family: "JetBrainsMono Nerd Font"
                        color: MatugenColors.text
                      }

                      MouseArea {
                        id: resBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resDropdownIdx = (root.resDropdownIdx === index ? -1 : index)
                      }
                    }
                  }

                  Rectangle {
                    Layout.fillWidth: true
                    visible: root.resDropdownIdx === index
                    height: visible ? s(160) : 0
                    radius: s(8)
                    clip: true
                    color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.6)
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1

                    ListView {
                      anchors.fill: parent
                      anchors.margins: s(4)
                      clip: true
                      model: root.commonResolutions
                      delegate: Rectangle {
                        width: ListView.view.width
                        height: s(26)
                        radius: s(5)
                        color: resItemMa.containsMouse ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.16) : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                          anchors.left: parent.left
                          anchors.leftMargin: s(8)
                          anchors.verticalCenter: parent.verticalCenter
                          text: root.resLabel(modelData.w, modelData.h) + "  " + modelData.w + "x" + modelData.h
                          font.pixelSize: s(10)
                          font.family: "JetBrainsMono Nerd Font"
                          color: (model.width === modelData.w && model.height === modelData.h) ? MatugenColors.accent : MatugenColors.text
                        }
                        MouseArea {
                          id: resItemMa
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: { root.setMonitorRes(index, modelData.w, modelData.h); root.resDropdownIdx = -1 }
                        }
                      }
                    }
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: s(8)
                    Text { text: "refresh"; font.pixelSize: s(10); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textDim; Layout.fillWidth: true }

                    Rectangle {
                      width: s(24); height: s(22); radius: s(5); Layout.preferredWidth: s(24); Layout.preferredHeight: s(22)
                      color: refMinusMa.containsMouse ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.2) : Qt.rgba(1, 1, 1, 0.08)
                      Text { anchors.centerIn: parent; text: "-"; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text }
                      MouseArea { id: refMinusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.stepRefreshRate(index, -1) }
                    }

                    Text { text: model.refreshRate + "Hz"; font.pixelSize: s(11); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent; Layout.preferredWidth: s(44); horizontalAlignment: Text.AlignHCenter }

                    Rectangle {
                      width: s(24); height: s(22); radius: s(5); Layout.preferredWidth: s(24); Layout.preferredHeight: s(22)
                      color: refPlusMa.containsMouse ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.2) : Qt.rgba(1, 1, 1, 0.08)
                      Text { anchors.centerIn: parent; text: "+"; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text }
                      MouseArea { id: refPlusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.stepRefreshRate(index, 1) }
                    }
                  }
                }
              }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
          }

          // Bottom scroll-fade overlay. Lives inside mainFlick (anchored
          // to parent) rather than as a RowLayout sibling positioned via
          // mainFlick.left/right/bottom — that used to fight the outer
          // RowLayout's own Layout-managed positioning of this item.
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
