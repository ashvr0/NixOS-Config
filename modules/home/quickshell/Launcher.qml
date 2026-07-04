import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
  id: root

  IpcHandler {
    target: "launcher"
    function toggle(): void {
      root.toggle()
    }
  }

  visible: false
  color: "transparent"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  exclusiveZone: 0

  anchors { top: true; left: true; right: true; bottom: true }

  property var apps: []
  property var filtered: []
  property int selectedIndex: 0

  function toggle() {
    if (root.visible) close()
    else open()
  }

  function open() {
    root.visible = true
    loadApps()
    query.text = ""
    selectedIndex = 0
    Qt.callLater(() => query.forceActiveFocus())
  }

  function close() {
    root.visible = false
  }

  function loadApps() {
    const entries = DesktopEntries.applications.values
      .filter(e => !e.noDisplay)
      .map(e => ({
        name: e.name,
        exec: e.execString ? e.execString.replace(/%[a-zA-Z]/g, "").trim() : "",
        icon: e.icon || "application-x-executable",
        keywords: [e.genericName, e.comment, (e.categories || []).join(" ")].filter(Boolean).join(" "),
        entry: e
      }))
      .filter(e => e.exec.length > 0)
    entries.sort((a, b) => a.name.localeCompare(b.name))
    root.apps = entries
    refilter()
  }

  function refilter() {
    const q = query.text.toLowerCase().trim()
    filtered = q === "" ? apps : apps.filter(a =>
      a.name.toLowerCase().includes(q) ||
      (a.keywords && a.keywords.toLowerCase().includes(q))
    )
    selectedIndex = 0
  }

  function launch(app) {
    if (!app) return
    app.entry.execute()
    close()
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.close()
  }

  Rectangle {
    id: panel
    width: 750
    height: query.text.length || resultsList.count ? Math.min(20 + 56 + (resultsList.count * 43) + (Math.max(resultsList.count - 1, 0) * 5), 20 + 56 + (7 * 43) + (6 * 5)) : 20 + 56
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

          Text {
            text: "::"
            font.family: "JetBrains Mono Nerd Font"
            color: "#e1e2e8"
          }

          TextInput {
            id: query
            Layout.fillWidth: true
            font.family: "JetBrains Mono Nerd Font"
            font.pixelSize: 14
            color: "#e1e2e8"
            clip: true
            onTextChanged: root.refilter()

            Text {
              text: "Search"
              font: parent.font
              color: "#e1e2e8"
              opacity: 0.5
              visible: parent.text.length === 0
            }

            Keys.onPressed: (event) => {
              if (event.key === Qt.Key_Escape) {
                root.close(); event.accepted = true
              } else if (event.key === Qt.Key_Down) {
                root.selectedIndex = Math.min(root.selectedIndex + 1, root.filtered.length - 1); event.accepted = true
              } else if (event.key === Qt.Key_Up) {
                root.selectedIndex = Math.max(root.selectedIndex - 1, 0); event.accepted = true
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.launch(root.filtered[root.selectedIndex]); event.accepted = true
              }
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
            anchors.margins: 5
            spacing: 10

            Image {
              source: Quickshell.iconPath(modelData.icon, true)
              Layout.preferredWidth: 32
              Layout.preferredHeight: 32
              fillMode: Image.PreserveAspectFit
              asynchronous: true
            }

            Text {
              text: modelData.name
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
            onEntered: root.selectedIndex = index
            onClicked: root.launch(modelData)
          }
        }
      }
    }
  }
}
