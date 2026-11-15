import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."
import "../Singletons"

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
  // Ignore the bar's reserved space so the panel can sit on the real screen edge.
  exclusionMode: ExclusionMode.Ignore
  anchors { top: true; left: true; right: true; bottom: true }

  // Sizing comes from the launcher settings (Config.launcherWidth, Config.launcherVisibleItems).
  readonly property real clipWidth: Config.launcherWidth
  readonly property real rowHeight: 58
  readonly property real expandedRowHeight: 172
  readonly property real rowSpacing: 5
  readonly property real headerHeight: 22
  readonly property real emptyHeight: 96

  // Same position setting as the launcher (top, bottom, left, right, center).
  readonly property string edge: Config.launcherPosition

  property var entries: []
  property var filtered: []
  property int selectedIndex: 0
  property var delQueue: []
  property var pinnedIds: []

  // Expand state. Only one row is expanded at a time.
  property string expandedId: ""
  property string fullId: ""
  property string fullText: ""

  // Fixed by the collapsed rows only, so expanding a row never resizes the panel.
  // The list scrolls instead. Never smaller than one expanded row.
  function visibleListHeight() {
    const n = Math.min(filtered.length, Config.launcherVisibleItems)
    if (n === 0) return emptyHeight
    let h = n * rowHeight + (n - 1) * rowSpacing + headerHeight
    for (let i = 1; i < n; i++) {
      if (filtered[i].pinned !== filtered[i - 1].pinned) h += headerHeight
    }
    return Math.max(h, expandedRowHeight + headerHeight)
  }
  readonly property real listHeight: visibleListHeight()

  function toggle() { root.visible ? close() : open() }

  function open() {
    root.visible = true
    expandedId = ""
    fullId = ""
    fullText = ""
    refresh()
    query.text = ""
    selectedIndex = 0
    Qt.callLater(() => query.forceActiveFocus())
  }

  function close() {
    root.visible = false
    expandedId = ""
  }

  function refresh() {
    if (listProc.running || delProc.running || delQueue.length) return
    listProc.running = true
  }

  function refilter() {
    const q = query.text.toLowerCase().trim()
    const base = q === "" ? entries : entries.filter(e => e.preview.toLowerCase().includes(q))
    const out = base.map(e => ({
      id: e.id,
      preview: e.preview,
      pinned: root.pinnedIds.includes(e.id)
    }))
    out.sort((a, b) => (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0))
    filtered = out
    selectedIndex = 0
  }

  function isBinary(entry) {
    return entry && entry.preview.indexOf("[[ binary data") === 0
  }

  // The cliphist preview is a single truncated line, so long entries get a chevron.
  function canExpand(entry) {
    if (!entry || isBinary(entry)) return false
    return entry.preview.length > 60 || entry.preview.endsWith("\u2026")
  }

  function loadFull(id) {
    if (fullProc.running) return
    fullProc.reqId = id
    fullProc.command = ["cliphist", "decode", id]
    fullProc.running = true
  }

  function toggleExpand(entry) {
    if (!canExpand(entry)) return
    if (expandedId === entry.id) {
      expandedId = ""
      return
    }
    expandedId = entry.id
    fullText = ""
    fullId = ""
    loadFull(entry.id)
    revealTimer.restart()
  }

  // Scroll the expanded row fully into view once its height animation is done.
  Timer {
    id: revealTimer
    interval: 200
    onTriggered: resultsList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
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
    expandedId = ""
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
    if (expandedId === id) expandedId = ""
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

  function moveSelection(delta) {
    if (filtered.length === 0) return
    selectedIndex = Math.max(0, Math.min(selectedIndex + delta, filtered.length - 1))
    resultsList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  readonly property var emptyMessages: [
    "Nothing copied yet. Ctrl+C something.",
    "Copy something, ya goblin.",
    "Empty as my coffee cup."
  ]
  property string emptyMessage: emptyMessages[Math.floor(Math.random() * emptyMessages.length)]

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

  // Full text of the expanded entry.
  Process {
    id: fullProc
    property string reqId: ""
    stdout: StdioCollector {
      onStreamFinished: {
        if (fullProc.reqId === root.expandedId) {
          root.fullId = fullProc.reqId
          root.fullText = this.text.length > 20000 ? this.text.slice(0, 20000) : this.text
        }
      }
    }
    onExited: {
      // The user expanded a different row while this one was still running.
      if (root.expandedId !== "" && root.expandedId !== reqId) root.loadFull(root.expandedId)
    }
  }

  MouseArea { anchors.fill: parent; onClicked: root.close() }

  // Popup. Same flared edge shape as the launcher, own width.
  Item {
    id: panel
    property string edge: root.edge
    property real radius: Config.uiRadius + 8
    property color color: MatugenColors.bgBase
    property real padding: 12

    readonly property bool alongX: edge === "top" || edge === "bottom"
    readonly property bool alongY: edge === "left" || edge === "right"
    readonly property bool docked: alongX || alongY
    readonly property real verticalInset: padding * 2 + (alongY ? radius * 2 : 0)

    function pt(D, L) {
      let x, y
      if (edge === "left")       { x = D;         y = L }
      else if (edge === "right") { x = width - D; y = L }
      else if (edge === "top")   { x = L;         y = D }
      else                       { x = L;         y = height - D }
      return x + " " + y
    }

    readonly property string shapePath: {
      let r = Math.max(0, Math.min(radius, Math.min(width, height) / 4))
      if (!docked) {
        let rr = Math.min(radius, Math.min(width, height) / 2)
        return "M " + rr + " 0 L " + (width - rr) + " 0 A " + rr + " " + rr + " 0 0 1 " + width + " " + rr
          + " L " + width + " " + (height - rr) + " A " + rr + " " + rr + " 0 0 1 " + (width - rr) + " " + height
          + " L " + rr + " " + height + " A " + rr + " " + rr + " 0 0 1 0 " + (height - rr)
          + " L 0 " + rr + " A " + rr + " " + rr + " 0 0 1 " + rr + " 0 Z"
      }
      let Dt = alongY ? width : height
      let Lt = alongY ? height : width
      let flip = (edge === "right" || edge === "top")
      let concave = flip ? 1 : 0
      let convex = flip ? 0 : 1
      let a = function (sweep) { return "A " + r + " " + r + " 0 0 " + sweep + " " }
      return "M " + pt(0, 0)
        + " " + a(concave) + pt(r, r)
        + " L " + pt(Dt - r, r)
        + " " + a(convex) + pt(Dt, 2 * r)
        + " L " + pt(Dt, Lt - 2 * r)
        + " " + a(convex) + pt(Dt - r, Lt - r)
        + " L " + pt(r, Lt - r)
        + " " + a(concave) + pt(0, Lt)
        + " Z"
    }

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeWidth: 0
        fillColor: panel.color
        PathSvg { path: panel.shapePath }
      }
    }

    Item {
      id: contentArea
      anchors.fill: parent
      anchors.leftMargin: panel.padding + (panel.alongX ? panel.radius : 0)
      anchors.rightMargin: panel.padding + (panel.alongX ? panel.radius : 0)
      anchors.topMargin: panel.padding + (panel.alongY ? panel.radius : 0)
      anchors.bottomMargin: panel.padding + (panel.alongY ? panel.radius : 0)
    }

    width: root.clipWidth
    height: 44 + 12 + root.listHeight + panel.verticalInset
    visible: root.visible
    clip: true

    x: edge === "left" ? 0 : (edge === "right" ? root.width - width : Math.round((root.width - width) / 2))
    y: edge === "top" ? 0 : (edge === "bottom" ? root.height - height : Math.round((root.height - height) / 2))

    ColumnLayout {
      anchors.fill: contentArea
      spacing: 12

      // Search stays at the top.
      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        spacing: 10

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 44
          radius: 4
          color: MatugenColors.bgElevated

          TextInput {
            id: query
            anchors.fill: parent
            anchors.margins: 12
            font.family: "JetBrains Mono Nerd Font"
            font.pixelSize: 15
            color: MatugenColors.text
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            onTextChanged: root.refilter()

            Text {
              text: "Search"
              font: parent.font
              color: MatugenColors.text
              opacity: 0.5
              visible: parent.text.length === 0
            }

            Keys.onPressed: (event) => {
              if (event.key === Qt.Key_Escape) {
                if (query.text.length > 0) { query.text = ""; event.accepted = true; return }
                root.close(); event.accepted = true
              } else if (event.key === Qt.Key_Down) {
                root.moveSelection(1); event.accepted = true
              } else if (event.key === Qt.Key_Up) {
                root.moveSelection(-1); event.accepted = true
              } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                root.toggleExpand(root.filtered[root.selectedIndex]); event.accepted = true
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.select(root.filtered[root.selectedIndex]); event.accepted = true
              } else if (event.key === Qt.Key_Delete) {
                root.del(root.filtered[root.selectedIndex]); event.accepted = true
              }
            }
          }
        }

        Rectangle {
          Layout.preferredWidth: 100
          Layout.preferredHeight: 44
          radius: 4
          color: clearArea.containsMouse ? MatugenColors.accent : MatugenColors.bgElevated

          RowLayout {
            anchors.centerIn: parent
            spacing: 6

            Text {
              text: "\uf1f8"
              font.family: "JetBrains Mono Nerd Font"
              font.pixelSize: 15
              color: clearArea.containsMouse ? MatugenColors.accentText : MatugenColors.text
            }

            Text {
              text: "Clear"
              font.family: "JetBrains Mono Nerd Font"
              font.pixelSize: 13
              color: clearArea.containsMouse ? MatugenColors.accentText : MatugenColors.text
            }
          }

          MouseArea {
            id: clearArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clearAll()
          }
        }
      }

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: root.listHeight

        ColumnLayout {
          anchors.centerIn: parent
          visible: root.filtered.length === 0
          spacing: 6

          Text {
            text: "\uf0ea"
            font.family: "JetBrains Mono Nerd Font"
            font.pixelSize: 28
            color: MatugenColors.accent
            opacity: 0.6
            Layout.alignment: Qt.AlignHCenter
          }

          Text {
            text: root.emptyMessage
            font.family: "JetBrains Mono Nerd Font"
            font.pixelSize: 14
            color: MatugenColors.text
            opacity: 0.6
            Layout.alignment: Qt.AlignHCenter
          }
        }

        ListView {
          id: resultsList
          anchors.fill: parent
          clip: true
          visible: root.filtered.length > 0
          model: root.filtered
          spacing: root.rowSpacing
          boundsBehavior: Flickable.StopAtBounds

          delegate: Item {
            id: del
            required property int index
            required property var modelData

            readonly property bool selected: index === root.selectedIndex
            readonly property bool expanded: root.expandedId === modelData.id
            readonly property bool binary: root.isBinary(modelData)
            readonly property bool expandable: root.canExpand(modelData)
            readonly property bool hasHeader: index === 0 || root.filtered[index - 1].pinned !== modelData.pinned
            readonly property color fg: selected ? MatugenColors.accentText : MatugenColors.text
            readonly property color overlay: selected ? Qt.rgba(0, 0, 0, 0.15) : Qt.rgba(1, 1, 1, 0.08)

            width: resultsList.width
            height: (hasHeader ? root.headerHeight : 0) + card.height

            Text {
              visible: del.hasHeader
              x: 4
              height: root.headerHeight
              verticalAlignment: Text.AlignVCenter
              text: del.modelData.pinned ? "Pinned" : "Recent"
              font.family: "JetBrains Mono Nerd Font"
              font.pixelSize: 11
              font.bold: true
              color: MatugenColors.text
              opacity: 0.7
            }

            Rectangle {
              id: card
              y: del.hasHeader ? root.headerHeight : 0
              width: parent.width
              height: del.expanded ? root.expandedRowHeight : root.rowHeight
              radius: 6
              color: del.selected ? MatugenColors.accent : MatugenColors.bgElevated2
              clip: true

              Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

              // Row click. Left copies, right pins.
              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onEntered: root.selectedIndex = del.index
                onClicked: (mouse) => {
                  if (mouse.button === Qt.RightButton) root.togglePin(del.modelData)
                  else root.select(del.modelData)
                }
              }

              // Type icon
              Rectangle {
                x: 10
                y: 13
                width: 32
                height: 32
                radius: 6
                color: del.overlay
                visible: !del.expanded

                Text {
                  anchors.centerIn: parent
                  text: del.binary ? "\uf03e" : "\uf15c"
                  font.family: "JetBrains Mono Nerd Font"
                  font.pixelSize: 14
                  color: del.fg
                  opacity: 0.85
                }
              }

              // Collapsed preview
              Text {
                x: 52
                y: 11
                width: parent.width - 52 - (del.expandable ? 76 : 46)
                height: 36
                visible: !del.expanded
                text: del.modelData.preview
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 12
                font.bold: del.selected
                color: del.fg
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
                textFormat: Text.PlainText
                verticalAlignment: Text.AlignVCenter
              }

              // Expanded full text
              Flickable {
                id: fullFlick
                visible: del.expanded
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 76
                anchors.topMargin: 12
                anchors.bottomMargin: 12
                contentWidth: width
                contentHeight: fullLabel.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height
                clip: true

                Text {
                  id: fullLabel
                  width: fullFlick.width
                  text: (root.fullId === del.modelData.id && root.fullText !== "") ? root.fullText : del.modelData.preview
                  font.family: "JetBrains Mono Nerd Font"
                  font.pixelSize: 12
                  color: del.fg
                  wrapMode: Text.Wrap
                  textFormat: Text.PlainText

                  TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onTapped: root.select(del.modelData)
                  }
                  TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: root.togglePin(del.modelData)
                  }
                }
              }

              // Action buttons (delete, chevron)
              Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                y: 16
                spacing: 6

                Rectangle {
                  width: 26
                  height: 26
                  radius: 6
                  visible: del.selected
                  color: delArea.containsMouse ? Qt.rgba(0, 0, 0, 0.3) : del.overlay

                  Text {
                    anchors.centerIn: parent
                    text: "\uf1f8"
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 12
                    color: del.fg
                  }

                  MouseArea {
                    id: delArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.del(del.modelData)
                  }
                }

                Rectangle {
                  width: 26
                  height: 26
                  radius: 6
                  visible: del.expandable
                  color: chevArea.containsMouse ? Qt.rgba(0, 0, 0, 0.3) : del.overlay

                  Text {
                    anchors.centerIn: parent
                    text: del.expanded ? "\uf077" : "\uf078"
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: 11
                    color: del.fg
                  }

                  MouseArea {
                    id: chevArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.selectedIndex = del.index
                      root.toggleExpand(del.modelData)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
