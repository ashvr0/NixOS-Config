import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."
import "../Singletons"
import "../Singletons/SearchProviders.js" as SearchProviders

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
  // Ignore other panels' reserved space (your bar) so the launcher can sit on the real screen edge.
  exclusionMode: ExclusionMode.Ignore

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
        if (Config.launcherSmartSort) {
          const rb = root.rankData[b.name] || 0
          const ra = root.rankData[a.name] || 0
          if (rb !== ra) return rb - ra
        }
        return a.name.localeCompare(b.name)
      })
      return entries
    }
  }

ScriptModel {
  id: filteredModel
  values: {
    const raw = query.text.trim()
    if (raw.startsWith("?")) {
      const term = raw.substring(1).trim()
      const provider = SearchProviders.find(Config.launcherSearchProvider)
      return [{
        name: term.length > 0 ? "? " + term : "? ...",
        description: term.length > 0 ? "Search " + provider.name : "Type something to search " + provider.name,
        icon: "",
        keywords: "",
        isWeb: true,
        url: term.length > 0 ? SearchProviders.urlFor(Config.launcherSearchProvider, term) : ""
      }]
    }

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
  if (app.isWeb) {
    if (app.url) {
      Quickshell.execDetached(["xdg-open", app.url])
      close()
    }
    return
  }
  root.bumpRank(app.name)
  app.entry.execute()
  close()
}

  MouseArea {
    anchors.fill: parent
    onClicked: root.close()
  }

  // Popup
  readonly property string edge: Config.launcherPosition
  readonly property int shownRows: Math.min(resultsList.count, Config.launcherVisibleItems)
  readonly property real listHeight: shownRows * 58 + Math.max(shownRows - 1, 0) * 5

  Item {
    id: panel
    // Frame that hugs the screen edge: rounded free corners, flared
    // (concave) corners where it meets the edge. "center" = rounded card.
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

    width: Config.launcherWidth
    height: 44 + (root.shownRows > 0 ? 12 + root.listHeight : 0) + panel.verticalInset
    visible: root.visible

    // Fixed size, flush to the chosen edge, centered along it.
    clip: true
    x: edge === "left" ? 0 : (edge === "right" ? root.width - width : Math.round((root.width - width) / 2))
    y: edge === "top" ? 0 : (edge === "bottom" ? root.height - height : Math.round((root.height - height) / 2))

    ColumnLayout {
      anchors.fill: contentArea
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
              visible: !modelData.isWeb
              source: modelData.isWeb ? "" : Quickshell.iconPath(modelData.icon, true)
              Layout.preferredWidth: 40
              Layout.preferredHeight: 40
              fillMode: Image.PreserveAspectFit
              asynchronous: true
            }

            Text {
              visible: modelData.isWeb === true
              text: "󰖟"
              Layout.preferredWidth: 40
              Layout.preferredHeight: 40
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              font.family: "JetBrains Mono Nerd Font"
              font.pixelSize: 24
              color: index === root.selectedIndex ? MatugenColors.accentText : MatugenColors.accent
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
