import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."
import "../Singletons"

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

  property int selectedIndex: 0
  property var rankData: ({})
  
  // Ranks top used app
  FileView {
    id: rankFile
    path: Quickshell.env("HOME") + "/.cache/quickshell/app-rank.json"
    watchChanges: false
    onLoaded: {
      try {
        root.rankData = JSON.parse(text())
      } catch (e) {
        root.rankData = {}
      }
      appsModel.reload()
    }
    onLoadFailed: (error) => {
      root.rankData = {}
    }
  }

  function bumpRank(name) {
    const d = root.rankData
    d[name] = (d[name] || 0) + 1
    root.rankData = d
    rankFile.setText(JSON.stringify(d))
  }

  ScriptModel {
    id: appsModel
    function reload() { appsModel.valuesChanged() }
    values: {
      const entries = DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .map(e => ({
          name: e.name,
          description: e.comment || e.genericName || "",
          exec: e.execString ? e.execString.replace(/%[a-zA-Z]/g, "").trim() : "",
          icon: e.icon || "application-x-executable",
          keywords: [e.genericName, e.comment, (e.categories || []).join(" ")].filter(Boolean).join(" "),
          entry: e
        }))
        .filter(e => e.exec.length > 0)
      entries.sort((a, b) => {
        const rb = root.rankData[b.name] || 0
        const ra = root.rankData[a.name] || 0
        if (rb !== ra) return rb - ra
        return a.name.localeCompare(b.name)
      })
      return entries
    }
  }

  ScriptModel {
    id: filteredModel
    values: {
      const q = query.text.toLowerCase().trim()
      const apps = appsModel.values
      return q === "" ? apps : apps.filter(a =>
        a.name.toLowerCase().includes(q) ||
        (a.keywords && a.keywords.toLowerCase().includes(q))
      )
    }
  }

  function toggle() {
    if (root.visible) close()
    else open()
  }

  function open() {
    root.visible = true
    query.text = ""
    selectedIndex = 0
    Qt.callLater(() => query.forceActiveFocus())
  }

  function close() {
    root.visible = false
  }

  function launch(app) {
    if (!app) return
    root.bumpRank(app.name)
    app.entry.execute()
    close()
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.close()
  }

  // Popup
  Rectangle {
    id: panel
    width: 1000
    height: query.text.length || resultsList.count ? Math.min(24 + 64 + (resultsList.count * 58) + (Math.max(resultsList.count - 1, 0) * 6), 24 + 64 + (7 * 58) + (6 * 6)) : 24 + 64
    anchors.centerIn: parent
    radius: 10
    color: MatugenColors.bgBase
    visible: root.visible
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 12
      spacing: 12

      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        spacing: 10

        // Search Box
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 44
          radius: 4
          color: MatugenColors.bgElevated

  TextInput {
    id: query
    anchors.left: parent.left
    anchors.right: clearBtn.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.margins: 12
    font.family: "JetBrains Mono Nerd Font"
    font.pixelSize: 15
    color: MatugenColors.text
    verticalAlignment: TextInput.AlignVCenter
    clip: true

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
        root.selectedIndex = Math.min(root.selectedIndex + 1, filteredModel.values.length - 1); event.accepted = true
      } else if (event.key === Qt.Key_Up) {
        root.selectedIndex = Math.max(root.selectedIndex - 1, 0); event.accepted = true
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        root.launch(filteredModel.values[root.selectedIndex]); event.accepted = true
      }
    }

    onTextChanged: root.selectedIndex = 0
  }

  Text {
    id: clearBtn
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    text: "\uf00d"
    font.family: "JetBrains Mono Nerd Font"
    font.pixelSize: 13
    color: clearMa.containsMouse ? MatugenColors.accent : MatugenColors.text
    opacity: clearMa.containsMouse ? 1.0 : 0.5
    visible: query.text.length > 0

    MouseArea {
      id: clearMa
      anchors.fill: parent
      anchors.margins: -6
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: { query.text = ""; query.forceActiveFocus() }
    }
  }
}
      }

      // App List
      ListView {
        id: resultsList
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: filteredModel
        currentIndex: root.selectedIndex
        spacing: 5
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
          width: resultsList.width
          height: 58
          radius: 6
          border.width: index === root.selectedIndex ? 1 : 0
          border.color: MatugenColors.accent
          color: index === root.selectedIndex ? MatugenColors.accent : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 12

            Image {
              source: Quickshell.iconPath(modelData.icon, true)
              Layout.preferredWidth: 40
              Layout.preferredHeight: 40
              fillMode: Image.PreserveAspectFit
              asynchronous: true
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              Text {
                text: modelData.name
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 13
                color: index === root.selectedIndex ? MatugenColors.accentText : MatugenColors.text
                Layout.fillWidth: true
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
              }

              Text {
                text: modelData.description
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 11
                color: index === root.selectedIndex ? MatugenColors.accentText : MatugenColors.text
                opacity: 0.6
                Layout.fillWidth: true
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                visible: modelData.description.length > 0
              }
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
