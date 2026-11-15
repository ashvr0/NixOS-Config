pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: sounds

    function play(filePath) {
        if (!filePath || filePath.trim() === "") return
        playProc.command = ["pw-play", filePath]
        playProc.running = false
        playProc.running = true
    }

    Process {
        id: playProc
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim()) console.log("[Sounds] pw-play stderr:", this.text)
        }
    }
}
