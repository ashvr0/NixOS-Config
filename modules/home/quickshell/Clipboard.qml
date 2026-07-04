import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
  id: root

  IpcHandler {
    target: "clipboard"
    function toggle(): void { root.toggle() }
  }

  visible: false
  color: "transparent"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  exclusiveZone: 0
  anchors { top: true; left: true; right: true; bottom: true }

  property var entries: []
  property var filtered: []
  property int selectedIndex: 0
  property var delQueue: []

  function toggle() { root.visible ? close() : open() }

  function open() {
    root.visible = true
    refresh()
    query.text = ""
    selectedIndex = 0
    Qt.callLater(() => query.forceActiveFocus())
  }

  function close() { root.visible = false }

  function refresh() {
    if (listProc.running || delProc.running || delQueue.length) return
    listProc.running = true
  }

  function refilter() {
    const q = query.text.toLowerCase().trim()
    filtered = q === "" ? entries : entries.filter(e => e.preview.toLowerCase().includes(q))
    selectedIndex = 0
  }

  function select(entry) {
  if (!entry || !/^\d+$/.test(String(entry.id))) return
  Quickshell.execDetached(["sh", "-c", "echo \"$1\" | cliphist decode | wl-copy -o", "_", String(entry.id)])
  close()
}

  function del(entry) {
    if (!entry || !/^\d+$/.test(String(entry.id))) return
    const id = String(entry.id)
    entries = entries.filter(e => e.id !== id)
    refilter()
    delQueue.push(id)
    pumpDeletes()
  }

  function pumpDeletes() {
    if (delProc.running || !delQueue.length) return
    const id = delQueue.shift()
    delProc.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "_", id]
    delProc.running = true
  }

  Process {
    id: delProc
    onExited: root.delQueue.length ? root.pumpDeletes() : root.refresh()
  }

  Process {
    id: listProc
    command: ["cliphist", "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = this.text.split("\n")
        const out = []
        for (const line of lines) {
          const tab = line.indexOf("\t")
          if (tab < 1) continue
          const id = line.substring(0, tab)
          if (!/^\d+$/.test(id)) continue
          out.push({ id: id, preview: line.substring(tab + 1) })
        }
        root.entries = out
        root.refilter()
      }
    }
  }

  MouseArea { anchors.fill: parent; onClicked: root.close() }

  Rectangle {
    id: panel
    width: 750
    height: Math.min(20 + 56 + (resultsList.count * 43) + (Math.max(resultsList.count - 1, 0) * 5), 20 + 56 + (7 * 43) + (6 * 5))
    anchors.centerIn: parent
    radius: 10
    color: "#101418"
    visible: root.visible
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 10
      spacing: 10

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        radius: 4
        color: "#101418"
        border.width: 1
        border.color: "#9fcafc"

        RowLayout {
          anchors.fill: parent
          anchors.margins: 10
          spacing: 10

          Text { text: "::"; font.family: "JetBrains Mono Nerd Font"; color: "#e1e2e8" }

          TextInput {
            id: query
            Layout.fillWidth: true
            font.family: "JetBrains Mono Nerd Font"
            font.pixelSize: 14
            color: "#e1e2e8"
            clip: true
            onTextChanged: root.refilter()

            Text {
              text: "Search clipboard"
              font: parent.font
              color: "#e1e2e8"
              opacity: 0.5
              visible: parent.text.length === 0
            }

            Keys.onPressed: (event) => {
              if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
              else if (event.key === Qt.Key_Down) { root.selectedIndex = Math.min(root.selectedIndex + 1, root.filtered.length - 1); event.accepted = true }
              else if (event.key === Qt.Key_Up) { root.selectedIndex = Math.max(root.selectedIndex - 1, 0); event.accepted = true }
              else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.select(root.filtered[root.selectedIndex]); event.accepted = true }
              else if (event.key === Qt.Key_Delete) { root.del(root.filtered[root.selectedIndex]); event.accepted = true }
            }
          }
        }
      }

      ListView {
        id: resultsList
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: root.filtered
        currentIndex: root.selectedIndex
        spacing: 5
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
          width: resultsList.width
          height: 38
          radius: 6
          border.width: index === root.selectedIndex ? 1 : 0
          border.color: "#9fcafc"
          color: index === root.selectedIndex ? "#9fcafc" : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 10

            Text {
              text: modelData.preview
              font.family: "JetBrains Mono Nerd Font"
              font.pixelSize: 12
              color: index === root.selectedIndex ? "#003257" : "#e1e2e8"
              Layout.fillWidth: true
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
            }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onEntered: root.selectedIndex = index
            onClicked: (mouse) => mouse.button === Qt.RightButton ? root.del(modelData) : root.select(modelData)
          }
        }
      }
    }
  }
}
