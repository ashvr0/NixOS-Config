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

    // Matugen-derived colors, kept separate from the active (possibly
    // preset-overridden) colors above so switching back to "matugen"
    // doesn't require re-reading the file.
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

    Process {
        id: themeReader
        command: ["cat", Quickshell.env("HOME") + "/.config/quickshell/colors.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "" && txt !== root.rawJson) {
                    root.rawJson = txt;
                    try {
                        let c = JSON.parse(txt);
                        if (c.bg_base) root.mBgBase = c.bg_base;
                        if (c.bg_elevated) root.mBgElevated = c.bg_elevated;
                        if (c.bg_elevated2) root.mBgElevated2 = c.bg_elevated2;
                        if (c.border) root.mBorder = c.border;
                        if (c.border_soft) root.mBorderSoft = c.border_soft;
                        if (c.text) root.mText = c.text;
                        if (c.text_muted) root.mTextMuted = c.text_muted;
                        if (c.text_dim) root.mTextDim = c.text_dim;
                        if (c.accent) root.mAccent = c.accent;
                        if (c.accent_text) root.mAccentText = c.accent_text;
                        if (c.accent_soft) root.mAccentSoft = c.accent_soft;
                        if (c.error) root.mError = c.error;
                        if (c.warning) root.mWarning = c.warning;
                        if (Config.colorScheme === "matugen") root.applyActiveScheme();
                    } catch(e) {}
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: themeReader.running = true
    }
}
