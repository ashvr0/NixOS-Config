pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property color bgBase:      "#101418"
    property color bgElevated:  "#1c2024"
    property color bgElevated2: "#181c20"

    property color border:      "#8c9198"
    property color borderSoft:  "#42474e"

    property color text:        "#e0e2e8"
    property color textMuted:   "#b8c8da"
    property color textDim:     "#c2c7ce"

    property color accent:      "#98ccf9"
    property color accentText:  "#003351"
    property color accentSoft:  "#054b72"

    property color error:       "#ffb4ab"
    property color warning:     "#d1bfe7"

    property string rawJson: ""

    property color mBgBase:      bgBase
    property color mBgElevated:  bgElevated
    property color mBgElevated2: bgElevated2
    property color mBorder:      border
    property color mBorderSoft:  borderSoft
    property color mText:        text
    property color mTextMuted:   textMuted
    property color mTextDim:     textDim
    property color mAccent:      accent
    property color mAccentText:  accentText
    property color mAccentSoft:  accentSoft
    property color mError:       error
    property color mWarning:     warning

    function applyActiveScheme() {
        let preset = Config.themePresets[Config.colorScheme]
        let src = preset || {
            bgBase: root.mBgBase, bgElevated: root.mBgElevated, bgElevated2: root.mBgElevated2,
            border: root.mBorder, borderSoft: root.mBorderSoft,
            text: root.mText, textMuted: root.mTextMuted, textDim: root.mTextDim,
            accent: root.mAccent, accentText: root.mAccentText, accentSoft: root.mAccentSoft,
            error: root.mError, warning: root.mWarning
        }
        root.bgBase = src.bgBase
        root.bgElevated = src.bgElevated
        root.bgElevated2 = src.bgElevated2
        root.border = src.border
        root.borderSoft = src.borderSoft
        root.text = src.text
        root.textMuted = src.textMuted
        root.textDim = src.textDim
        root.accent = src.accent
        root.accentText = src.accentText
        root.accentSoft = src.accentSoft
        root.error = src.error
        root.warning = src.warning
    }

    Connections {
        target: Config
        function onColorSchemeChanged() { root.applyActiveScheme() }
    }

    Component.onCompleted: root.applyActiveScheme()

    // Sets one color property safely. Bad values are logged instead of silently aborting the whole load.
    function setColor(key, value) {
        if (value === undefined || value === null || value === "") return
        try {
            root[key] = value
        } catch (e) {
            console.warn("MatugenColors: bad value for " + key + ": " + value + " (" + e + ")")
        }
    }

    function applyJson(txt) {
        txt = txt.trim()
        if (txt === "" || txt === root.rawJson) return
        let c
        try {
            c = JSON.parse(txt)
        } catch (e) {
            console.warn("MatugenColors: colors.json is not valid JSON: " + e)
            return
        }
        root.rawJson = txt
        root.setColor("mBgBase", c.bg_base)
        root.setColor("mBgElevated", c.bg_elevated)
        root.setColor("mBgElevated2", c.bg_elevated2)
        root.setColor("mBorder", c.border)
        root.setColor("mBorderSoft", c.border_soft)
        root.setColor("mText", c.text)
        root.setColor("mTextMuted", c.text_muted)
        root.setColor("mTextDim", c.text_dim)
        root.setColor("mAccent", c.accent)
        root.setColor("mAccentText", c.accent_text)
        root.setColor("mAccentSoft", c.accent_soft)
        root.setColor("mError", c.error)
        root.setColor("mWarning", c.warning)
        console.log("MatugenColors: loaded colors.json, scheme=" + Config.colorScheme + ", accent=" + root.mAccent)
        if (Config.colorScheme === "matugen") root.applyActiveScheme()
    }

    FileView {
        id: colorsFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell/colors.json"
        watchChanges: true
        printErrors: false   // file may not exist before matugen first runs
        onFileChanged: reload()
        onLoaded: root.applyJson(text())
        onLoadFailed: error => console.warn("MatugenColors: could not read colors.json: " + error)
    }
}