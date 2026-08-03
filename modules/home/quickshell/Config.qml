pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: config

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string hyprConf: homeDir + "/.config/hypr/keybinds.lua"
    readonly property string keybindNamesPath: homeDir + "/.config/quickshell/keybind_names.json"
    readonly property string settingsPath: homeDir + "/.local/state/quickshell/settings.json"

    property string wallpaperDir: homeDir + "/.config/hypr/wallpapers"
    property string mainMod: "SUPER"
    property int workspaceCount: 6
    property real uiScale: 1.0
    property bool tempUnitFahrenheit: false
    property bool showClockSeconds: false
    property bool clock24h: false
    property string barPosition: "top"
    property bool autoHideBar: false
    // 40-100: how far the center/right zones sit from the bar's edges.
    // Higher pushes zones further apart (bigger gap around the center
    // module); Settings.qml's slider is clamped to this same range.
    property int barWidthPercent: 100
    // "modular": each module renders as its own separate pill/card.
    // "solid": all modules in a zone render inside one continuous bar
    // surface with no gaps between them. Bar.qml reads this to decide
    // whether zones draw individual module backgrounds or one shared one.
    property string barStyle: "solid"
    // Every module's own pill background binds its visibility to this so
    // "solid" actually merges modules into one surface instead of each
    // module still painting its own background on top of/inside the
    // shared zone surface Bar.qml draws.
    readonly property bool solidBarActive: barStyle === "solid"
    // Whether the guide/help trigger button shows in the top bar.
    property bool showGuideButton: false
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int uiRadius: 10
    property string colorScheme: "matugen"

    readonly property var themePresets: ({
        "matugen": null,
        "mocha": {
            bgBase: "#1e1e2e", bgElevated: "#181825", bgElevated2: "#11111b",
            border: "#6c7086", borderSoft: "#45475a",
            text: "#cdd6f4", textMuted: "#a6adc8", textDim: "#9399b2",
            accent: "#89b4fa", accentText: "#1e1e2e", accentSoft: "#1e3a5f",
            error: "#f38ba8", warning: "#f9e2af"
        },
        "latte": {
            bgBase: "#eff1f5", bgElevated: "#e6e9ef", bgElevated2: "#dce0e8",
            border: "#9ca0b0", borderSoft: "#acb0be",
            text: "#4c4f69", textMuted: "#5c5f77", textDim: "#6c6f85",
            accent: "#1e66f5", accentText: "#eff1f5", accentSoft: "#c4d9fb",
            error: "#d20f39", warning: "#df8e1d"
        },
        "tokyonight": {
            bgBase: "#1a1b26", bgElevated: "#16161e", bgElevated2: "#13131a",
            border: "#565f89", borderSoft: "#3b3f57",
            text: "#c0caf5", textMuted: "#9aa5ce", textDim: "#787c99",
            accent: "#7aa2f7", accentText: "#1a1b26", accentSoft: "#2a3457",
            error: "#f7768e", warning: "#e0af68"
        },
        "gruvbox": {
            bgBase: "#282828", bgElevated: "#1d2021", bgElevated2: "#32302f",
            border: "#a89984", borderSoft: "#504945",
            text: "#ebdbb2", textMuted: "#d5c4a1", textDim: "#bdae93",
            accent: "#fe8019", accentText: "#282828", accentSoft: "#4a3728",
            error: "#fb4934", warning: "#fabd2f"
        },
        "obsidian": {
            bgBase: "#22272e", bgElevated: "#1c2128", bgElevated2: "#161b22",
            border: "#768390", borderSoft: "#444c56",
            text: "#adbac7", textMuted: "#909dab", textDim: "#768390",
            accent: "#539bf5", accentText: "#22272e", accentSoft: "#264b6d",
            error: "#e5534b", warning: "#daaa3f"
        },
        "flexokidark": {
            bgBase: "#100f0f", bgElevated: "#1c1b1a", bgElevated2: "#282726",
            border: "#878580", borderSoft: "#575653",
            text: "#cecdc3", textMuted: "#b7b5ac", textDim: "#878580",
            accent: "#4385be", accentText: "#100f0f", accentSoft: "#20342f",
            error: "#d14d41", warning: "#d0a215"
        },
        "vesper": {
            bgBase: "#101010", bgElevated: "#161616", bgElevated2: "#1c1c1c",
            border: "#8f8f8f", borderSoft: "#3a3a3a",
            text: "#ffffff", textMuted: "#a0a0a0", textDim: "#7e7e7e",
            accent: "#ffc799", accentText: "#101010", accentSoft: "#4a3d2f",
            error: "#f5a191", warning: "#ffc799"
        },
        "cyberpunk": {
            bgBase: "#0d0221", bgElevated: "#170a33", bgElevated2: "#1f0f42",
            border: "#ff2a6d", borderSoft: "#5a1f6b",
            text: "#f2e9ff", textMuted: "#c9b8e8", textDim: "#9d84c4",
            accent: "#05d9e8", accentText: "#0d0221", accentSoft: "#0a3a42",
            error: "#ff2a6d", warning: "#f9c80e"
        },
        "githubdark": {
            bgBase: "#0d1117", bgElevated: "#161b22", bgElevated2: "#010409",
            border: "#8b949e", borderSoft: "#30363d",
            text: "#c9d1d9", textMuted: "#b1bac4", textDim: "#8b949e",
            accent: "#58a6ff", accentText: "#0d1117", accentSoft: "#1f3b57",
            error: "#f85149", warning: "#d29922"
        },
        "ayudark": {
            bgBase: "#0a0e14", bgElevated: "#0d1017", bgElevated2: "#131721",
            border: "#8a9199", borderSoft: "#33415e",
            text: "#b3b1ad", textMuted: "#9ca3af", textDim: "#6b7280",
            accent: "#39bae6", accentText: "#0a0e14", accentSoft: "#1b3a4a",
            error: "#f26d78", warning: "#ffb454"
        },
        "nightowl": {
            bgBase: "#011627", bgElevated: "#0b2942", bgElevated2: "#01111d",
            border: "#5f7e97", borderSoft: "#1d3b53",
            text: "#d6deeb", textMuted: "#a7bed3", textDim: "#637777",
            accent: "#82aaff", accentText: "#011627", accentSoft: "#1d3b6b",
            error: "#ef5350", warning: "#addb67"
        },
        "materialocean": {
            bgBase: "#0f111a", bgElevated: "#181a24", bgElevated2: "#1f222d",
            border: "#717cb4", borderSoft: "#3b3f51",
            text: "#a6accd", textMuted: "#8f94ab", textDim: "#676e95",
            accent: "#82aaff", accentText: "#0f111a", accentSoft: "#1e3a5f",
            error: "#ff5370", warning: "#ffcb6b"
        },
        "horizon": {
            bgBase: "#1c1e26", bgElevated: "#232530", bgElevated2: "#16161c",
            border: "#6c6f93", borderSoft: "#2e303e",
            text: "#e0e0e0", textMuted: "#cbc9e2", textDim: "#6c6f93",
            accent: "#e95678", accentText: "#1c1e26", accentSoft: "#4a2536",
            error: "#e95678", warning: "#fab795"
        },
        "monokai": {
            bgBase: "#272822", bgElevated: "#1e1f1c", bgElevated2: "#2d2e27",
            border: "#948d70", borderSoft: "#49483e",
            text: "#f8f8f2", textMuted: "#cfcfc2", textDim: "#75715e",
            accent: "#66d9ef", accentText: "#272822", accentSoft: "#1f4d54",
            error: "#f92672", warning: "#e6db74"
        },
        "kanagawa": {
            bgBase: "#1f1f28", bgElevated: "#16161d", bgElevated2: "#2a2a37",
            border: "#727169", borderSoft: "#54546d",
            text: "#dcd7ba", textMuted: "#c8c093", textDim: "#727169",
            accent: "#7e9cd8", accentText: "#1f1f28", accentSoft: "#2d3b53",
            error: "#e82424", warning: "#dca561"
        }
    })
    property var themeChoices: [
        { id: "matugen", label: "Matugen (wallpaper)" },
        { id: "mocha", label: "Catppuccin Mocha" },
        { id: "latte", label: "Catppuccin Latte" },
        { id: "tokyonight", label: "Tokyo Night" },
        { id: "gruvbox", label: "Gruvbox" },
        { id: "obsidian", label: "Obsidian" },
        { id: "flexokidark", label: "Flexoki Dark" },
        { id: "vesper", label: "Vesper" },
        { id: "cyberpunk", label: "Cyberpunk" },
        { id: "githubdark", label: "GitHub Dark" },
        { id: "ayudark", label: "Ayu Dark" },
        { id: "nightowl", label: "Night Owl" },
        { id: "materialocean", label: "Material Ocean" },
        { id: "horizon", label: "Horizon" },
        { id: "monokai", label: "Monokai" },
        { id: "kanagawa", label: "Kanagawa" }
    ]

    // Bar module layout: which modules appear in each zone of the bar, and
    // in what order. Zones are read left-to-right (or top-to-bottom for a
    // vertical bar) by Bar.qml. Stored as module id strings so this stays
    // Single source of truth for the default layout. barLayout's own
    // initializer and resetBarLayout() (Settings.qml) both call this
    // instead of each hardcoding the list — a prior drift between two
    // separate literals (one missing "settings") caused two live
    // Settings module instances to exist at once, each registering an
    // IpcHandler for the same "settings" target, which crashed the shell.
    function defaultBarLayout() {
        return { left: ["launcher", "workspaces"], center: ["musicplayer"], right: ["systemtray", "keyboard", "volume", "network", "bluetooth", "systemstats", "settings", "power"] }
    }
    // trivially JSON-serializable for settings.json.
    property var barLayout: config.defaultBarLayout()
    readonly property var allBarModules: [
        { id: "launcher", label: "Launcher" },
        { id: "workspaces", label: "Workspaces" },
        { id: "musicplayer", label: "Music Player" },
        { id: "keyboard", label: "Keyboard" },
        { id: "systemtray", label: "Tray" },
        { id: "bluetooth", label: "Bluetooth" },
        { id: "network", label: "Network" },
        { id: "systemstats", label: "System Stats" },
        { id: "volume", label: "Volume" },
        { id: "settings", label: "Settings" },
        { id: "power", label: "Power" },
        { id: "guidebutton", label: "Guide Button" }
    ]
    function barModuleLabel(id) {
        let m = config.allBarModules.find(m => m.id === id)
        return m ? m.label : id
    }
    // Every known module id that isn't currently placed in any zone,
    // excluding guidebutton: it's controlled by its own "Show guide
    // button" switch in Appearance rather than by drag placement.
    function unplacedBarModules() {
        let placed = [].concat(config.barLayout.left, config.barLayout.center, config.barLayout.right)
        return config.allBarModules.map(m => m.id).filter(id => id !== "guidebutton" && !placed.includes(id))
    }
    function setBarLayout(layout) {
        config.barLayout = layout
        config.saveSettings()
    }

    // Helper for popup cards: which screen edge they should hug, given
    // where the bar currently lives. Popups open on the same side as the
    // bar so they feel anchored to it rather than always defaulting to the
    // top-right corner regardless of bar position.
    readonly property bool barVertical: barPosition === "left" || barPosition === "right"

    property var keybindNameOverrides: ({})

    function friendlyKeybindName(dispatcher, args) {
        let d = (dispatcher || "").trim()
        let a = (args || "").trim().replace(/^["']|["']$/g, "")
        if (d === "exec_cmd" || d === "exec") return a.split(" ")[0].split("/").pop()
        if (d.includes("close")) return "Close window"
        if (d.includes("float")) return "Toggle floating"
        if (d.includes("fullscreen")) return "Fullscreen"
        if (d.includes("focus")) return "Focus " + a
        if (d.includes("move")) return "Move " + a
        if (d.includes("resize")) return "Resize " + a
        if (a) return d + " " + a
        return d || "Keybind"
    }

    Process {
        id: keybindNamesLoadProc
        command: ["cat", config.keybindNamesPath]
        stdout: StdioCollector {
            onStreamFinished: {
                try { config.keybindNameOverrides = JSON.parse(this.text) } catch (e) { config.keybindNameOverrides = {} }
            }
        }
    }
    function loadKeybindNames() { keybindNamesLoadProc.running = false; keybindNamesLoadProc.running = true }

    function setKeybindName(lineNum, name) {
        let overrides = Object.assign({}, config.keybindNameOverrides)
        overrides[String(lineNum)] = name
        config.keybindNameOverrides = overrides
        let json = JSON.stringify(overrides)
        Quickshell.execDetached(["bash", "-c",
            "mkdir -p '" + config.homeDir + "/.config/quickshell' && cat > '" + config.keybindNamesPath + "' << 'KBEOF'\n" + json + "\nKBEOF"])
    }

    Component.onCompleted: {
        config.loadKeybindNames()
        config.loadSettings()
    }

    property bool _loadingSettings: false

    Process {
        id: settingsLoadProc
        command: ["cat", config.settingsPath]
        stdout: StdioCollector {
            onStreamFinished: {
                config._loadingSettings = true
                try {
                    let data = JSON.parse(this.text)
                    if (data.wallpaperDir !== undefined)
    config.wallpaperDir = data.wallpaperDir

if (data.mainMod !== undefined)
    config.mainMod = data.mainMod

if (data.uiScale !== undefined)
    config.uiScale = data.uiScale

if (data.workspaceCount !== undefined)
    config.workspaceCount = data.workspaceCount

if (data.barPosition !== undefined)
    config.barPosition = data.barPosition

if (data.autoHideBar !== undefined)
    config.autoHideBar = data.autoHideBar

if (data.barWidthPercent !== undefined)
    config.barWidthPercent = data.barWidthPercent

if (data.barStyle !== undefined)
    config.barStyle = data.barStyle

if (data.showGuideButton !== undefined)
    config.showGuideButton = data.showGuideButton

if (data.showClockSeconds !== undefined)
    config.showClockSeconds = data.showClockSeconds

if (data.clock24h !== undefined)
    config.clock24h = data.clock24h

if (data.fontFamily !== undefined)
    config.fontFamily = data.fontFamily

if (data.uiRadius !== undefined)
    config.uiRadius = data.uiRadius

if (data.colorScheme !== undefined)
    config.colorScheme = data.colorScheme

if (data.barLayout !== undefined) {
    let loaded = data.barLayout
    // Dedup: a module id should only ever occupy one zone. Any duplicate
    // (e.g. from a stale save) is dropped from every zone after its first
    // occurrence, so it can never render twice.
    let seen = {}
    function dedupZone(zone) {
        return (zone || []).filter(id => {
            if (seen[id]) return false
            seen[id] = true
            return true
        })
    }
    loaded = { left: dedupZone(loaded.left), center: dedupZone(loaded.center), right: dedupZone(loaded.right) }
    // Any module id introduced after this layout was saved (e.g. a newer
    // build adding "settings"/"power" as standalone modules) won't appear
    // in an old save at all. Append those to the right zone instead of
    // leaving them stuck in "unplaced" forever on every load.
    let known = config.allBarModules.map(m => m.id).filter(id => id !== "guidebutton")
    for (const id of known) {
        if (!seen[id]) {
            loaded.right.push(id)
            seen[id] = true
        }
    }
    config.barLayout = loaded
}
                } catch (e) {}
                config._loadingSettings = false
            }
        }
    }
    function loadSettings() { settingsLoadProc.running = false; settingsLoadProc.running = true }

    Timer {
        id: saveDebounce
        interval: 150
        onTriggered: config._writeSettingsNow()
    }
    function saveSettings() {
        // Guard against saving while values are still being populated from
        // disk on startup: each property assignment during load fires its
        // own onChanged handler, and without this guard the first property
        // to load (e.g. wallpaperDir) would immediately re-save the file
        // with the other properties still at their pre-load defaults,
        // overwriting a real saved uiScale with 1.0 before it's even read.
        if (config._loadingSettings) return
        // Debounced: several properties can change in the same tick (e.g.
        // toggling a switch that also updates a dependent property), each
        // triggering its own onChanged -> saveSettings() call. Restarting a
        // stateful Process on every call let a later call's command
        // assignment silently replace an earlier call's still-in-flight
        // write, so some toggles never made it to disk. Collapsing bursts
        // into a single write after a short quiet period, fired via
        // execDetached (fire-and-forget, no shared process state to race),
        // fixes that.
        saveDebounce.restart()
    }
    function _writeSettingsNow() {
        let json = JSON.stringify({
    wallpaperDir: config.wallpaperDir,
    mainMod: config.mainMod,
    uiScale: config.uiScale,
    workspaceCount: config.workspaceCount,
    barPosition: config.barPosition,
    autoHideBar: config.autoHideBar,
    barWidthPercent: config.barWidthPercent,
    barStyle: config.barStyle,
    showGuideButton: config.showGuideButton,
    showClockSeconds: config.showClockSeconds,
    clock24h: config.clock24h,
    fontFamily: config.fontFamily,
    uiRadius: config.uiRadius,
    colorScheme: config.colorScheme,
    barLayout: config.barLayout
}, null, 2)
        Quickshell.execDetached(["bash", "-c",
            "mkdir -p \"$(dirname '" + config.settingsPath + "')\" && cat > '" + config.settingsPath + ".tmp' << 'STEOF'\n" + json + "\nSTEOF\nmv '" + config.settingsPath + ".tmp' '" + config.settingsPath + "'"])
    }

    onWallpaperDirChanged: config.saveSettings()
    onMainModChanged: config.saveSettings()
    onUiScaleChanged: config.saveSettings()
    onWorkspaceCountChanged: config.saveSettings()
    onBarPositionChanged: config.saveSettings()
    onAutoHideBarChanged: config.saveSettings()
    onBarWidthPercentChanged: config.saveSettings()
    onBarStyleChanged: config.saveSettings()
    onShowGuideButtonChanged: config.saveSettings()
    onShowClockSecondsChanged: config.saveSettings()
    onClock24hChanged: config.saveSettings()
    onFontFamilyChanged: config.saveSettings()
    onUiRadiusChanged: config.saveSettings()
    onColorSchemeChanged: config.saveSettings()
    onBarLayoutChanged: config.saveSettings()
}
