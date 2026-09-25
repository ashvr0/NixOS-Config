import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "Singletons"

Item {
  id: dialog
  anchors.fill: parent

  signal accepted(string path)
  signal cancelled()

  property string titleText: "Choose file"
  property var nameFilters: []   // e.g. ["png","jpg","jpeg","webp","bmp","gif"] or ["ttf","otf","ttc","woff","woff2"]
  property var places: []        // [{ name, icon, path }] — path is a plain dir path, not file://
  property bool selectFolders: false // when true, dialog picks directories instead of files

  readonly property string homeDir: Quickshell.env("HOME")
  property string currentDir: homeDir
  property string selectedFile: ""
  property var entries: []

  function matchesFilter(name) {
    if (dialog.nameFilters.length === 0) return true
    let ext = name.split(".").pop().toLowerCase()
    return dialog.nameFilters.includes(ext)
  }

  function refresh() {
    listProc.running = false
    listProc.running = true
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

  Component.onCompleted: refresh()

  Process {
    id: listProc
    command: ["ls", "-1p", dialog.currentDir]
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
    width: Math.min(parent.width * 0.75, 820)
    height: Math.min(parent.height * 0.78, 560)
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
          width: 26; height: 26; radius: 8
          color: closeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
          Text { anchors.centerIn: parent; text: "\uf00d"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: MatugenColors.textDim }
          MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dialog.cancelled() }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 12

        // Sidebar
        ColumnLayout {
          Layout.preferredWidth: 140
          Layout.fillHeight: true
          spacing: 2
          visible: dialog.places.length > 0

          Repeater {
            model: dialog.places
            delegate: Rectangle {
              required property var modelData
              Layout.fillWidth: true
              Layout.preferredHeight: 32
              radius: 8
              color: dialog.currentDir === modelData.path ? Qt.rgba(1,1,1,0.1) : (placeMa.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent")
              Behavior on color { ColorAnimation { duration: 120 } }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                spacing: 8
                Text { text: modelData.icon; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: MatugenColors.textDim }
                Text { text: modelData.name; font.pixelSize: 12; font.family: Config.fontFamily; color: MatugenColors.text; elide: Text.ElideRight; Layout.fillWidth: true }
              }

              MouseArea {
                id: placeMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { dialog.currentDir = modelData.path; dialog.selectedFile = ""; dialog.refresh() }
              }
            }
          }

          Item { Layout.fillHeight: true }
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: 10

          // Breadcrumb / nav row
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
              width: 28; height: 28; radius: 8
              color: upMa.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.06)
              Text { anchors.centerIn: parent; text: "\uf060"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: MatugenColors.textDim }
              MouseArea {
                id: upMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (dialog.currentDir === "/" || dialog.currentDir === "") return
                  let parts = dialog.currentDir.split("/")
                  parts.pop()
                  dialog.currentDir = parts.join("/") || "/"
                  dialog.selectedFile = ""
                  dialog.refresh()
                }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 28
              radius: 8
              color: Qt.rgba(1,1,1,0.06)
              Text {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: Text.AlignVCenter
                text: dialog.currentDir
                font.pixelSize: 12
                font.family: Config.fontFamily
                color: MatugenColors.textMuted
                elide: Text.ElideMiddle
              }
            }

            Rectangle {
              width: 28; height: 28; radius: 8
              color: homeMa.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.06)
              Text { anchors.centerIn: parent; text: "\uf015"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: MatugenColors.textDim }
              MouseArea {
                id: homeMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { dialog.currentDir = dialog.homeDir; dialog.selectedFile = ""; dialog.refresh() }
              }
            }
          }

          // Body: list + preview
          RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Rectangle {
              Layout.preferredWidth: parent.width * 0.42
              Layout.fillHeight: true
              radius: 10
              color: Qt.rgba(1, 1, 1, 0.04)
              clip: true

              ListView {
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                model: dialog.entries
                delegate: Rectangle {
                  required property var modelData
                  width: ListView.view.width
                  height: 30
                  radius: 6
                  color: (dialog.selectedFile === dialog.currentDir + "/" + modelData.name)
                    ? Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.22)
                    : (entryMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                  Behavior on color { ColorAnimation { duration: 100 } }

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    spacing: 8

                    Text {
                      text: modelData.isDir ? "\uf07b" : "\uf03e"
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 12
                      color: modelData.isDir ? MatugenColors.accent : MatugenColors.textDim
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                      text: modelData.name
                      font.pixelSize: 12
                      font.family: Config.fontFamily
                      color: MatugenColors.text
                      elide: Text.ElideRight
                      width: parent.width - 30
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  MouseArea {
                    id: entryMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (modelData.isDir) {
                        if (dialog.selectFolders) {
                          dialog.selectedFile = dialog.currentDir + "/" + modelData.name
                        } else {
                          dialog.currentDir = dialog.currentDir + "/" + modelData.name
                          dialog.selectedFile = ""
                          dialog.refresh()
                        }
                      } else {
                        dialog.selectedFile = dialog.currentDir + "/" + modelData.name
                      }
                    }
                    onDoubleClicked: {
                      if (modelData.isDir) {
                        dialog.currentDir = dialog.currentDir + "/" + modelData.name
                        dialog.selectedFile = ""
                        dialog.refresh()
                      }
                    }
                  }
                }
              }
            }

            // Preview (only shown if there are image-type filters; harmless for fonts, just shows placeholder)
            Rectangle {
              Layout.fillWidth: true
              Layout.fillHeight: true
              radius: 10
              color: Qt.rgba(1, 1, 1, 0.04)
              clip: true

              Image {
                anchors.fill: parent
                anchors.margins: 10
                visible: dialog.selectedFile !== "" && ["png","jpg","jpeg","webp","bmp","gif"].includes(dialog.selectedFile.split(".").pop().toLowerCase())
                source: visible ? "file://" + dialog.selectedFile : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
              }

              Text {
                anchors.centerIn: parent
                visible: !parent.children[0].visible
                text: dialog.selectedFile === "" ? (dialog.selectFolders ? "Select a folder" : "Select a file") : dialog.selectedFile.split("/").pop()
                font.pixelSize: 12
                font.family: Config.fontFamily
                color: MatugenColors.textDim
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
          font.pixelSize: 12
          font.family: Config.fontFamily
          color: MatugenColors.textDim
          elide: Text.ElideMiddle
        }

        Rectangle {
          visible: dialog.selectFolders
          width: 130; height: 32; radius: 8
          color: useCurrentMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.06)
          Text { anchors.centerIn: parent; text: "Use current folder"; font.pixelSize: 11; font.family: Config.fontFamily; color: MatugenColors.text }
          MouseArea { id: useCurrentMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dialog.accepted(dialog.currentDir) }
        }

        Rectangle {
          width: 80; height: 32; radius: 8
          color: cancelMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.06)
          Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 12; font.family: Config.fontFamily; color: MatugenColors.text }
          MouseArea { id: cancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dialog.cancelled() }
        }

        Rectangle {
          width: 80; height: 32; radius: 8
          enabled: dialog.selectedFile !== ""
          opacity: enabled ? 1 : 0.4
          color: selectMa.containsMouse ? Qt.lighter(MatugenColors.accent, 1.1) : MatugenColors.accent
          Text { anchors.centerIn: parent; text: "Select"; font.pixelSize: 12; font.weight: Font.Bold; font.family: Config.fontFamily; color: MatugenColors.accentText }
          MouseArea {
            id: selectMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: dialog.selectedFile !== ""
            onClicked: dialog.accepted(dialog.selectedFile)
          }
        }
      }
    }
  }
}