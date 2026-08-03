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
  property var pinnedIds: []

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
    let out = q === "" ? entries : entries.filter(e => e.preview.toLowerCase().includes(q))
    out = out.slice().sort((a, b) => {
      const ap = root.pinnedIds.includes(a.id) ? 1 : 0
      const bp = root.pinnedIds.includes(b.id) ? 1 : 0
      return bp - ap
    })
    filtered = out
    selectedIndex = 0
  }

  function togglePin(entry) {
    if (!entry) return
    const id = entry.id
    root.pinnedIds = root.pinnedIds.includes(id)
      ? root.pinnedIds.filter(p => p !== id)
      : root.pinnedIds.concat([id])
    refilter()
  }

  function clearAll() {
    for (const e of entries) delQueue.push(e.id)
    entries = []
    pinnedIds = []
    refilter()
    pumpDeletes()
  }

  function select(entry) {
    if (!entry || !/^\d+$/.test(String(entry.id))) return
    Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "_", String(entry.id)])
    close()
  }

  function del(entry) {
    if (!entry || !/^\d+$/.test(String(entry.id))) return
    const id = String(entry.id)
    entries = entries.filter(e => e.id !== id)
    pinnedIds = pinnedIds.filter(p => p !== id)
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
    width: 980
    height: 20 + 56 + (3 * 140) + (2 * 8)
    anchors.centerIn: parent
    radius: 10
    color: "#101418"
    visible: root.visible
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 10
      spacing: 10

      RowLayout {
        Layout.fillWidth: true
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

            Text { text: "󰅌"; font.family: "JetBrains Mono Nerd Font"; color: "#e1e2e8" }

            TextInput {
              id: query
              Layout.fillWidth: true
              font.family: "JetBrains Mono Nerd Font"
              font.pixelSize: 14
              color: "#e1e2e8"
              clip: true
              onTextChanged: root.refilter()

              Text {
                text: "Clipboard"
                font: parent.font
                color: "#e1e2e8"
                opacity: 0.5
                visible: parent.text.length === 0
              }

              Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
                else if (event.key === Qt.Key_Down) { root.selectedIndex = Math.min(root.selectedIndex + 3, root.filtered.length - 1); event.accepted = true }
                else if (event.key === Qt.Key_Up) { root.selectedIndex = Math.max(root.selectedIndex - 3, 0); event.accepted = true }
                else if (event.key === Qt.Key_Left) { root.selectedIndex = Math.max(root.selectedIndex - 1, 0); event.accepted = true }
                else if (event.key === Qt.Key_Right) { root.selectedIndex = Math.min(root.selectedIndex + 1, root.filtered.length - 1); event.accepted = true }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.select(root.filtered[root.selectedIndex]); event.accepted = true }
                else if (event.key === Qt.Key_Delete) { root.del(root.filtered[root.selectedIndex]); event.accepted = true }
              }
            }
          }
        }

        Rectangle {
          Layout.preferredWidth: 100
          Layout.preferredHeight: 36
          radius: 4
          color: clearArea.containsMouse ? "#9fcafc" : "#101418"
          border.width: 1
          border.color: "#9fcafc"

          RowLayout {
            anchors.centerIn: parent
            spacing: 6

            Text {
              text: ""
              font.family: "JetBrains Mono Nerd Font"
              font.pixelSize: 15
              color: clearArea.containsMouse ? "#003257" : "#e1e2e8"
            }

            Text {
              text: "Clear"
              font.family: "JetBrains Mono Nerd Font"
              font.pixelSize: 13
              color: clearArea.containsMouse ? "#003257" : "#e1e2e8"
            }
          }

          MouseArea {
            id: clearArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.clearAll()
          }
        }
      }

      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        GridView {
          id: resultsList
          width: Math.floor(parent.width / 3) * 3
          height: parent.height
          anchors.horizontalCenter: parent.horizontalCenter
          clip: true
          model: root.filtered
          currentIndex: root.selectedIndex
          cellWidth: width / 3
          cellHeight: 140
          boundsBehavior: Flickable.StopAtBounds

          delegate: Item {
            width: resultsList.cellWidth
            height: resultsList.cellHeight

            Rectangle {
              anchors.centerIn: parent
              width: parent.width - 8
              height: parent.height - 8
              radius: 6
              border.width: 1
              border.color: index === root.selectedIndex ? "#9fcafc" : "#2a2f36"
              color: index === root.selectedIndex ? "#9fcafc" : "#171b20"

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                enabled: !pinArea.containsMouse && !delArea.containsMouse
                onEntered: root.selectedIndex = index
                onClicked: root.select(modelData)
              }

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                Text {
                  text: modelData.preview
                  font.family: "JetBrains Mono Nerd Font"
                  font.pixelSize: 12
                  color: index === root.selectedIndex ? "#003257" : "#e1e2e8"
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  wrapMode: Text.Wrap
                  elide: Text.ElideRight
                  verticalAlignment: Text.AlignTop
                  maximumLineCount: 5
                }

                Text {
                  text: root.pinnedIds.includes(modelData.id) ? "Pinned" : ""
                  visible: root.pinnedIds.includes(modelData.id)
                  font.family: "JetBrains Mono Nerd Font"
                  font.pixelSize: 10
                  color: index === root.selectedIndex ? "#003257" : "#9fcafc"
                  opacity: 0.8
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 8

                  Item { Layout.fillWidth: true }

                  Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 20
                    radius: 4
                    color: pinArea.containsMouse ? "#9fcafc" : "transparent"
                    border.width: 1
                    border.color: index === root.selectedIndex ? "#003257" : "#9fcafc"

                    Text {
                      anchors.centerIn: parent
                      text: root.pinnedIds.includes(modelData.id) ? "󰐄" : "󰐃"
                      font.family: "JetBrains Mono Nerd Font"
                      font.pixelSize: 12
                      color: pinArea.containsMouse ? "#003257" : (index === root.selectedIndex ? "#003257" : "#9fcafc")
                    }

                    MouseArea {
                      id: pinArea
                      anchors.fill: parent
                      hoverEnabled: true
                      propagateComposedEvents: false
                      onClicked: (mouse) => { mouse.accepted = true; root.togglePin(modelData) }
                    }
                  }

                  Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 20
                    radius: 4
                    color: delArea.containsMouse ? "#9fcafc" : "transparent"
                    border.width: 1
                    border.color: index === root.selectedIndex ? "#003257" : "#9fcafc"

                    Text {
                      anchors.centerIn: parent
                      text: ""
                      font.family: "JetBrains Mono Nerd Font"
                      font.pixelSize: 12
                      color: delArea.containsMouse ? "#003257" : (index === root.selectedIndex ? "#003257" : "#9fcafc")
                    }

                    MouseArea {
                      id: delArea
                      anchors.fill: parent
                      hoverEnabled: true
                      propagateComposedEvents: false
                      onClicked: (mouse) => { mouse.accepted = true; root.del(modelData) }
                    }
                  }
                }
              }
            }
          }
        }

        Rectangle {
          width: resultsList.width
          height: 32
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          gradient: Gradient {
            GradientStop { position: 0.0; color: "#00101418" }
            GradientStop { position: 1.0; color: "#101418" }
          }
        }
      }
    }
  }
}
