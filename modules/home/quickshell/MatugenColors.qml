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
                        if (c.bg_base) root.bgBase = c.bg_base;
                        if (c.bg_elevated) root.bgElevated = c.bg_elevated;
                        if (c.bg_elevated2) root.bgElevated2 = c.bg_elevated2;
                        if (c.border) root.border = c.border;
                        if (c.border_soft) root.borderSoft = c.border_soft;
                        if (c.text) root.text = c.text;
                        if (c.text_muted) root.textMuted = c.text_muted;
                        if (c.text_dim) root.textDim = c.text_dim;
                        if (c.accent) root.accent = c.accent;
                        if (c.accent_text) root.accentText = c.accent_text;
                        if (c.accent_soft) root.accentSoft = c.accent_soft;
                        if (c.error) root.error = c.error;
                        if (c.warning) root.warning = c.warning;
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
