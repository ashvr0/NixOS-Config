import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../.."
import "../../Singletons"

Item {
  id: dialog
  anchors.fill: parent

  signal accepted(string path)
  signal cancelled()

  property string titleText: "Choose file"
  property var nameFilters: []
  property var places: []
  property bool selectFolders: false

  readonly property string homeDir: Quickshell.env("HOME")
  property string currentDir: homeDir
  property string selectedFile: ""
  property var entries: []
  property bool showHidden: false

  readonly property var imageExts: ["png", "jpg", "jpeg", "webp", "bmp", "gif"]
  readonly property bool showPreview: {
    if (selectFolders || nameFilters.length === 0) return false
    for (let f of nameFilters) {
      if (imageExts.includes(f)) return true
    }
    return false
  }

  readonly property var shownEntries: {
    let q = searchInput.text.trim().toLowerCase()
    if (q === "") return entries
    return entries.filter(e => e.name.toLowerCase().includes(q))
  }

  readonly property var crumbs: {
    let parts = currentDir.split("/").filter(p => p !== "")
    let arr = [{ name: "Root", path: "/" }]
    let cp = ""
    for (let p of parts) {
      cp += "/" + p
      arr.push({ name: p, path: cp })
    }
    return arr
  }

  function matchesFilter(name) {
    if (dialog.nameFilters.length === 0) return true
    let ext = name.split(".").pop().toLowerCase()
    return dialog.nameFilters.includes(ext)
  }

  function refresh() {
    listProc.running = false
    listProc.running = true
  }

  function goTo(path) {
    dialog.currentDir = path === "" ? "/" : path
    dialog.selectedFile = ""
    searchInput.text = ""
    dialog.refresh()
  }

  function goUp() {
    if (dialog.currentDir === "/" || dialog.currentDir === "") return
    let parts = dialog.currentDir.split("/")
    parts.pop()
    dialog.goTo(parts.join("/") || "/")
  }

  function pathOf(name) {
    return (dialog.currentDir === "/" ? "" : dialog.currentDir) + "/" + name
  }

  function confirm() {
    if (dialog.selectedFile !== "") dialog.accepted(dialog.selectedFile)
  }

  function openWithOptionalPath(initialPath) {
    if (initialPath && initialPath !== "") {
      let dir = initialPath.substring(0, initialPath.lastIndexOf("/"))
      dialog.currentDir = dir !== "" ? dir : dialog.homeDir
      dialog.selectedFile = initialPath
    } else {
      dialog.currentDir = dialog.homeDir
      dialog.selectedFile = ""
    }
    dialog.refresh()
  }

  onShowHiddenChanged: refresh()
  Component.onCompleted: { refresh(); searchInput.forceActiveFocus() }

  Process {
    id: listProc
    command: ["ls", dialog.showHidden ? "-1pA" : "-1p", dialog.currentDir]
    stdout: StdioCollector {
      onStreamFinished: {
        let lines = this.text.trim().length > 0 ? this.text.trim().split("\n") : []
        let dirs = []
        let files = []
        for (let l of lines) {
          if (l.endsWith("/")) dirs.push({ name: l.slice(0, -1), isDir: true })
          else if (!dialog.selectFolders && dialog.matchesFilter(l)) files.push({ name: l, isDir: false })
        }
        dirs.sort((a, b) => a.name.localeCompare(b.name))
        files.sort((a, b) => a.name.localeCompare(b.name))
        dialog.entries = dirs.concat(files)
      }
    }
  }

  // Dim background
  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.6)
    MouseArea { anchors.fill: parent; onClicked: dialog.cancelled() }
  }

  Rectangle {
    id: card
    anchors.centerIn: parent
    width: Math.min(parent.width * 0.8, 900)
    height: Math.min(parent.height * 0.8, 600)
    radius: 18
    color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 1)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.1)

    MouseArea { anchors.fill: parent }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 16
      spacing: 12

      // Header
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: dialog.titleText
          font.pixelSize: 16
          font.weight: Font.Bold
          font.family: Config.fontFamily
          color: MatugenColors.text
          Layout.fillWidth: true
        }

        Rectangle {
          Layout.preferredWidth: 28
          Layout.preferredHeight: 28
          radius: 8
          color: closeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
          Text { anchors.centerIn: parent; text: "\uf00d"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: MatugenColors.text }
          MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dialog.cancelled() }
        }
      }

      // Body
      RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 14

        // Sidebar, fixed width
        Item {
          visible: dialog.places.length > 0
          Layout.preferredWidth: 150
          Layout.minimumWidth: 150
          Layout.maximumWidth: 150
          Layout.fillHeight: true

          Column {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 2

            Repeater {
              model: dialog.places
              delegate: Rectangle {
                required property var modelData
                readonly property bool active: dialog.currentDir === modelData.path
                width: parent.width
                height: 34
                radius: 8
                color: active ? MatugenColors.accent : (placeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 10
                  spacing: 10

                  Text {
                    text: modelData.icon
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    color: active ? MatugenColors.accentText : MatugenColors.textDim
                    Layout.preferredWidth: 20
                    horizontalAlignment: Text.AlignHCenter
                  }
                  Text {
                    text: modelData.name
                    font.pixelSize: 12
                    font.weight: active ? Font.Bold : Font.Normal
                    font.family: Config.fontFamily
                    color: active ? MatugenColors.accentText : MatugenColors.text
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }
                }

                MouseArea {
                  id: placeMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: dialog.goTo(modelData.path)
                }
              }
            }
          }
        }

        // Main column, takes all remaining width
        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.minimumWidth: 0
          Layout.preferredWidth: 0
          spacing: 10

          // Nav row
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
              Layout.preferredWidth: 32
              Layout.preferredHeight: 32
              radius: 8
              color: upMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
              Text { anchors.centerIn: parent; text: "\uf060"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: MatugenColors.text }
              MouseArea { id: upMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dialog.goUp() }
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              Layout.preferredHeight: 32
              radius: 8
              color: Qt.rgba(1, 1, 1, 0.06)
              clip: true

              Flickable {
                id: crumbFlick
                anchors.fill: parent
                contentWidth: crumbRow.width
                contentHeight: height
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                onContentWidthChanged: contentX = Math.max(0, contentWidth - width)

                Row {
                  id: crumbRow
                  height: parent.height
                  leftPadding: 6
                  rightPadding: 6
                  spacing: 2

                  Repeater {
                    model: dialog.crumbs
                    delegate: Row {
                      required property var modelData
                      required property int index
                      readonly property bool isLast: index === dialog.crumbs.length - 1
                      height: crumbRow.height
                      spacing: 2

                      Text {
                        visible: index > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf054"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        color: MatugenColors.textDim
                      }

                      Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 22
                        width: crumbTxt.implicitWidth + 14
                        radius: 6
                        color: isLast ? Qt.rgba(1, 1, 1, 0.1) : (crumbMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")

                        Text {
                          id: crumbTxt
                          anchors.centerIn: parent
                          text: modelData.name
                          font.pixelSize: 12
                          font.family: Config.fontFamily
                          color: isLast ? MatugenColors.accent : MatugenColors.textMuted
                        }
                        MouseArea {
                          id: crumbMa
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: dialog.goTo(modelData.path)
                        }
                      }
                    }
                  }
                }
              }
            }

            // Hidden files toggle
            Rectangle {
              Layout.preferredWidth: 32
              Layout.preferredHeight: 32
              radius: 8
              color: dialog.showHidden
                ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.25)
                : (hidMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06))
              Text {
                anchors.centerIn: parent
                text: dialog.showHidden ? "\uf06e" : "\uf070"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: dialog.showHidden ? MatugenColors.accent : MatugenColors.text
              }
              MouseArea { id: hidMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dialog.showHidden = !dialog.showHidden }
            }
          }

          // Search
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 8
            color: Qt.rgba(1, 1, 1, 0.06)

            Text {
              id: searchIcon
              anchors.left: parent.left
              anchors.leftMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf002"
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 12
              color: MatugenColors.textDim
            }

            TextInput {
              id: searchInput
              anchors.left: searchIcon.right
              anchors.leftMargin: 8
              anchors.right: parent.right
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              font.pixelSize: 12
              font.family: Config.fontFamily
              color: MatugenColors.text
              selectionColor: MatugenColors.accent
              selectedTextColor: MatugenColors.accentText
              clip: true
              Keys.onEscapePressed: dialog.cancelled()
              Keys.onReturnPressed: dialog.confirm()

              Text {
                visible: searchInput.text.length === 0
                anchors.verticalCenter: parent.verticalCenter
                text: "Search..."
                font: searchInput.font
                color: MatugenColors.textDim
              }
            }
          }

          // List and preview
          RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Rectangle {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.minimumWidth: 0
              Layout.preferredWidth: 0
              radius: 10
              color: Qt.rgba(1, 1, 1, 0.04)
              clip: true

              Text {
                anchors.centerIn: parent
                visible: dialog.shownEntries.length === 0
                text: "Nothing here"
                font.pixelSize: 13
                font.family: Config.fontFamily
                color: MatugenColors.textDim
              }

              ListView {
                id: listView
                anchors.fill: parent
                anchors.margins: 4
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: dialog.shownEntries

                delegate: Rectangle {
                  required property var modelData
                  readonly property string fullPath: dialog.pathOf(modelData.name)
                  width: ListView.view.width
                  height: 32
                  radius: 6
                  color: dialog.selectedFile === fullPath
                    ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.22)
                    : (entryMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                  Behavior on color { ColorAnimation { duration: 100 } }

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                      text: modelData.isDir ? "\uf07b" : "\uf03e"
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 13
                      color: modelData.isDir ? MatugenColors.accent : MatugenColors.textDim
                      Layout.preferredWidth: 18
                    }
                    Text {
                      text: modelData.name
                      font.pixelSize: 12
                      font.family: Config.fontFamily
                      color: MatugenColors.text
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }
                  }

                  MouseArea {
                    id: entryMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (modelData.isDir && !dialog.selectFolders) dialog.goTo(fullPath)
                      else dialog.selectedFile = fullPath
                    }
                    onDoubleClicked: {
                      if (modelData.isDir) dialog.goTo(fullPath)
                      else { dialog.selectedFile = fullPath; dialog.confirm() }
                    }
                  }
                }
              }
            }

            // Preview, only for image filters
            Rectangle {
              visible: dialog.showPreview
              Layout.preferredWidth: Math.round(card.width * 0.34)
              Layout.fillHeight: true
              radius: 10
              color: Qt.rgba(1, 1, 1, 0.04)
              clip: true

              Image {
                id: previewImg
                anchors.fill: parent
                anchors.margins: 10
                visible: dialog.selectedFile !== "" && dialog.imageExts.includes(dialog.selectedFile.split(".").pop().toLowerCase())
                source: visible ? "file://" + dialog.selectedFile : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
              }

              Text {
                anchors.centerIn: parent
                visible: !previewImg.visible
                text: dialog.selectedFile === "" ? "No preview" : dialog.selectedFile.split("/").pop()
                font.pixelSize: 12
                font.family: Config.fontFamily
                color: MatugenColors.textDim
                elide: Text.ElideMiddle
                width: parent.width - 20
                horizontalAlignment: Text.AlignHCenter
              }
            }
          }
        }
      }

      // Footer
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          Layout.fillWidth: true
          text: dialog.selectedFile !== "" ? dialog.selectedFile.split("/").pop()
            : (dialog.selectFolders ? "No folder selected" : "No file selected")
          font.pixelSize: 13
          font.family: Config.fontFamily
          color: dialog.selectedFile !== "" ? MatugenColors.text : MatugenColors.textDim
          elide: Text.ElideMiddle
        }

        Rectangle {
          visible: dialog.selectFolders
          Layout.preferredWidth: 130
          Layout.preferredHeight: 36
          radius: 10
          color: useCurrentMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
          Text { anchors.centerIn: parent; text: "Use current folder"; font.pixelSize: 11; font.family: Config.fontFamily; color: MatugenColors.text }
          MouseArea { id: useCurrentMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dialog.accepted(dialog.currentDir) }
        }

        Rectangle {
          Layout.preferredWidth: 80
          Layout.preferredHeight: 36
          radius: 10
          color: cancelMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
          Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 12; font.family: Config.fontFamily; color: MatugenColors.text }
          MouseArea { id: cancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dialog.cancelled() }
        }

        Rectangle {
          Layout.preferredWidth: 80
          Layout.preferredHeight: 36
          radius: 10
          opacity: dialog.selectedFile !== "" ? 1 : 0.4
          color: doneMa.containsMouse && dialog.selectedFile !== "" ? Qt.lighter(MatugenColors.accent, 1.1) : MatugenColors.accent
          Text { anchors.centerIn: parent; text: "Done"; font.pixelSize: 12; font.weight: Font.Bold; font.family: Config.fontFamily; color: MatugenColors.accentText }
          MouseArea {
            id: doneMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: dialog.selectedFile !== ""
            cursorShape: Qt.PointingHandCursor
            onClicked: dialog.confirm()
          }
        }
      }
    }
  }
}