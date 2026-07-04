import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
  id: root

  property string lockFile: Quickshell.env("HOME") + "/.cache/wallpaper-picker.lock"

  Process {
    id: singleInstanceGuard
    command: ["bash", "-c",
      "LOCK='" + root.lockFile + "'; " +
      "if [ -f \"$LOCK\" ]; then OLDPID=$(cat \"$LOCK\" 2>/dev/null); " +
      "if [ -n \"$OLDPID\" ] && kill -0 \"$OLDPID\" 2>/dev/null; then kill -9 \"$OLDPID\" 2>/dev/null; fi; fi; " +
      "echo $PPID > \"$LOCK\""
    ]
  }
  Component.onCompleted: {
    singleInstanceGuard.running = true
    listProc.running = true
  }
  Component.onDestruction: Quickshell.execDetached(["bash", "-c", "rm -f '" + root.lockFile + "'"])

  property string wallpaperDir: Quickshell.env("HOME") + "/.config/hypr/wallpapers"
  property var wallpapers: []
  property var filteredWallpapers: []
  property string currentWallpaper: ""
  property string filterText: ""
  property int selectedIndex: -1

  function applyFilter() {
    if (root.filterText === "") {
      root.filteredWallpapers = root.wallpapers
    } else {
      const f = root.filterText.toLowerCase()
      root.filteredWallpapers = root.wallpapers.filter(w => w.toLowerCase().indexOf(f) !== -1)
    }
    if (root.filteredWallpapers.length > 0) {
      if (root.selectedIndex < 0 || root.selectedIndex >= root.filteredWallpapers.length) {
        root.selectedIndex = 0
      }
    } else {
      root.selectedIndex = -1
    }
  }

  // list wallpaper files
  Process {
    id: listProc
    command: ["bash", "-c", "ls -1 '" + root.wallpaperDir + "' | grep -Ei '\\.(jpg|jpeg|png|webp)$'"]
    stdout: StdioCollector {
      onStreamFinished: {
        let txt = this.text.trim();
        root.wallpapers = txt === "" ? [] : txt.split("\n");
        root.applyFilter()
      }
    }
  }

function applyWallpaper(filename) {
  let fullPath = root.wallpaperDir + "/" + filename
  root.currentWallpaper = filename
  const escapeBash = (str) => String(str).replace(/(["\\$`])/g, '\\$1')
  const escPath = escapeBash(fullPath)
  const script = "#!/usr/bin/env bash\n" +
    `awww img "${escPath}" --transition-type wave --transition-angle 30 --transition-wave "60,30" --transition-step 90 --transition-fps 60\n` +
    `matugen image "${escPath}" -m dark --source-color-index 0 >> /tmp/matugen.log 2>&1\n`
  const scriptPath = "/tmp/apply-wallpaper.sh"
  Quickshell.execDetached(["bash", "-c",
    `cat > ${scriptPath} << 'WPEOF'\n${script}\nWPEOF\nchmod +x ${scriptPath}\nsetsid ${scriptPath} < /dev/null &> /dev/null &`
  ])
  closeTimer.start()
}

  Timer {
    id: closeTimer
    interval: 120
    onTriggered: Qt.quit()
  }

  PanelWindow {
    id: overlay
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qs-wallpaper-picker"
    anchors { top: true; left: true; right: true; bottom: true }

    // click-outside-to-close catcher (no dim/fade)
    MouseArea {
      anchors.fill: parent
      onClicked: Qt.quit()
    }

    FocusScope {
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: Qt.quit()

      Rectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width * 0.55
        height: parent.height * 0.24
        radius: 14
        clip: true
        focus: true
        color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.85)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)

        opacity: 0
        scale: 0.95
        Component.onCompleted: { opacity = 1; scale = 1 }
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }

        Keys.onEscapePressed: Qt.quit()
        MouseArea { anchors.fill: parent }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 20
          spacing: 14

          // inputbar
          Rectangle {
            Layout.fillWidth: true
            height: 46
            radius: 10
            color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.85)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.06)

            Row {
              anchors.fill: parent
              anchors.leftMargin: 14
              anchors.rightMargin: 14
              spacing: 8

              Text {
                text: "󰸉"
                font.pixelSize: 13
                font.weight: Font.Bold
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.accent
                anchors.verticalCenter: parent.verticalCenter
              }

              TextInput {
                id: searchInput
                width: parent.width - 24
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 14
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.text
                focus: true
                clip: true

                onTextChanged: {
                  root.filterText = text
                  root.applyFilter()
                }

                Keys.onEscapePressed: Qt.quit()
                Keys.onReturnPressed: {
                  if (root.selectedIndex >= 0 && root.selectedIndex < root.filteredWallpapers.length) {
                    root.applyWallpaper(root.filteredWallpapers[root.selectedIndex])
                  } else if (root.filteredWallpapers.length > 0) {
                    root.applyWallpaper(root.filteredWallpapers[0])
                  }
                }
                Keys.onLeftPressed: if (root.selectedIndex > 0) root.selectedIndex--
                Keys.onRightPressed: if (root.selectedIndex < root.filteredWallpapers.length - 1) root.selectedIndex++

                Text {
                  text: "Search wallpapers..."
                  font: parent.font
                  color: Qt.rgba(MatugenColors.text.r, MatugenColors.text.g, MatugenColors.text.b, 0.4)
                  visible: searchInput.text.length === 0
                }
              }
            }
          }

          // listview
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
              id: listview
              anchors.fill: parent
              anchors.bottomMargin: 10
              orientation: ListView.Horizontal
              spacing: 14
              clip: true
              model: root.filteredWallpapers
              cacheBuffer: 2000
              boundsBehavior: ListView.StopAtBounds
              interactive: false
              flickableDirection: Flickable.HorizontalFlick

              currentIndex: root.selectedIndex
              highlightFollowsCurrentItem: true
              onCurrentIndexChanged: listview.positionViewAtIndex(currentIndex, ListView.Contain)

              delegate: Item {
                id: thumbCard
                required property string modelData
                required property int index
                width: listview.height
                height: listview.height

                Rectangle {
                  anchors.fill: parent
                  radius: 12
                  clip: true
                  color: "transparent"

                  Image {
                    anchors.fill: parent
                    source: "file://" + root.wallpaperDir + "/" + thumbCard.modelData
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                  }
                }

                Rectangle {
                  anchors.fill: parent
                  radius: 12
                  color: "transparent"
                  border.width: 2
                  border.color: MatugenColors.accent
                  visible: root.selectedIndex === thumbCard.index
                }

                MouseArea {
                  id: thumbArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.selectedIndex = thumbCard.index
                    root.applyWallpaper(thumbCard.modelData)
                  }
                }
              }

              ScrollBar.horizontal: ScrollBar {
                id: hbar
                policy: ScrollBar.AsNeeded
                height: 4

                contentItem: Rectangle {
                  radius: 8
                  color: Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.5)
                }
                background: Rectangle {
                  radius: 8
                  color: Qt.rgba(1, 1, 1, 0.05)
                }
              }
            }

            MouseArea {
              anchors.fill: listview
              acceptedButtons: Qt.NoButton
              onWheel: (event) => {
                let delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                if (delta < 0 && root.selectedIndex < root.filteredWallpapers.length - 1) {
                  root.selectedIndex++
                } else if (delta > 0 && root.selectedIndex > 0) {
                  root.selectedIndex--
                }
                event.accepted = true
              }
            }

            Text {
              visible: root.filteredWallpapers.length === 0
              anchors.centerIn: parent
              text: root.wallpapers.length === 0
                    ? "No wallpapers found in\n" + root.wallpaperDir
                    : "No matches"
              horizontalAlignment: Text.AlignHCenter
              font.pixelSize: 12
              font.family: "JetBrainsMono Nerd Font"
              color: MatugenColors.textDim
              wrapMode: Text.WordWrap
            }
          }
        }
      }
    }
  }
}
