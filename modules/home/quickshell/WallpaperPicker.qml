import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "."

ShellRoot {
  id: root

  property string lockFile: Quickshell.env("HOME") + "/.cache/wallpaper-picker.lock"
  property string cacheDir: Quickshell.env("HOME") + "/.cache/wallpaper-picker"
  property string colorMarkerDir: root.cacheDir + "/colors"
  property string posterDir: root.cacheDir + "/posters"

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
    Quickshell.execDetached(["bash", "-c", "mkdir -p '" + root.colorMarkerDir + "' '" + root.posterDir + "'"])
    root.loadMonitors()
    root.restoreSession()
    colorExtractProc.running = true
    root.loadPosters()
  }
  Component.onDestruction: {
    root.saveSession()
    Quickshell.execDetached(["bash", "-c", "rm -f '" + root.lockFile + "'"])
  }

  property string wallpaperDir: Config.wallpaperDir
  property var wallpapers: []
  property string currentWallpaper: ""
  property string filterText: ""
  property string colorFilter: "" // "" = no color filter active
  property int selectedIndex: -1

  readonly property var colorSwatches: [
    { name: "Red", hex: "#FF4500" },
    { name: "Orange", hex: "#FFA500" },
    { name: "Yellow", hex: "#FFD700" },
    { name: "Green", hex: "#32CD32" },
    { name: "Blue", hex: "#1E90FF" },
    { name: "Purple", hex: "#8A2BE2" },
    { name: "Pink", hex: "#FF69B4" }
  ]

  // fileName -> hex string, populated from marker files dropped by
  // colorExtractProc. Kept as a plain object so filtering is a cheap
  // synchronous lookup instead of a query per frame.
  property var colorMap: ({})

  function isVideoFile(name) {
    const n = name.toLowerCase()
    // .gif is included here (not just video containers) because swww/awww
    // only renders a gif's first frame — mpvpaper is what actually animates it.
    return n.endsWith(".mp4") || n.endsWith(".mkv") || n.endsWith(".webm") || n.endsWith(".mov") || n.endsWith(".gif")
  }

  // Distinguishes true video containers from gifs: gifs get a native Image
  // thumbnail (Qt decodes frame 0 directly), containers need an ffmpeg-
  // extracted poster frame since there's no in-process video decoder.
  function isVideoContainerFile(name) {
    const n = name.toLowerCase()
    return n.endsWith(".mp4") || n.endsWith(".mkv") || n.endsWith(".webm") || n.endsWith(".mov")
  }

  // Reads the directory in-process, no bash/ls/grep spawn, so the list
  // is ready as soon as the folder is stat'd instead of waiting on a
  // subprocess round trip.
  FolderListModel {
    id: folderModel
    folder: "file://" + root.wallpaperDir
    nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.tga", "*.tiff", "*.bmp", "*.farbfeld", "*.mp4", "*.mkv", "*.webm", "*.mov"]
    showDirs: false
    sortField: FolderListModel.Name

    onStatusChanged: {
      if (status === FolderListModel.Ready) {
        const names = []
        for (let i = 0; i < count; i++) {
          names.push(get(i, "fileName"))
        }
        root.wallpapers = names
        root.clampSelection()
        colorExtractProc.running = true
        root.loadPosters()
      }
    }
  }

  // Marker files are named "<wallpaperFileName>.hex" containing a single
  // hex color line. A background script owns writing these; we only read.
  FolderListModel {
    id: colorMarkerModel
    folder: "file://" + root.colorMarkerDir
    nameFilters: ["*.hex"]
    showDirs: false

    onStatusChanged: {
      if (status === FolderListModel.Ready) root.reloadColorMap()
    }
    onCountChanged: root.reloadColorMap()
  }

  function reloadColorMap() {
    const map = {}
    for (let i = 0; i < colorMarkerModel.count; i++) {
      const markerName = colorMarkerModel.get(i, "fileName")
      const wallpaperName = markerName.slice(0, -4) // strip ".hex"
      map[wallpaperName] = colorMarkerFileContents[markerName] || ""
    }
    // Contents are filled in asynchronously by the FileView Repeater
    // below; this pass just tracks which marker files currently exist
    // and queues any we haven't read yet.
    root.colorMap = Object.assign({}, root.colorMap, map)
    root.readColorMarkerContents()
  }

  property var colorMarkerFileContents: ({})

  // One-shot background pipeline: for every wallpaper missing a marker
  // file, sample a resized 1x1 pixel and write its hex. Runs after any
  // folder change so new wallpapers eventually get filterable.
  Process {
    id: colorExtractProc
    command: ["bash", "-c", `
      set -f
      SRC="${root.wallpaperDir}"
      OUT="${root.colorMarkerDir}"
      mkdir -p "$OUT"
      command -v magick >/dev/null 2>&1 && CMD=magick || CMD=convert
      for f in "$SRC"/*; do
        [ -f "$f" ] || continue
        base=$(basename "$f")
        case "$base" in *.mp4|*.mkv|*.webm|*.mov) continue ;; esac
        marker="$OUT/$base.hex"
        [ -f "$marker" ] && continue
        hex=$($CMD "$f" -resize 1x1^ -gravity center -extent 1x1 -depth 8 -format "%[hex:p{0,0}]" info:- 2>/dev/null)
        [ -n "$hex" ] && echo "#$hex" > "$marker"
      done
    `]
  }

  // One-shot background pipeline: extracts a single poster frame per video
  // container into posterDir so the picker can show a real thumbnail
  // without QtMultimedia. Skips files that already have a poster so repeat
  // runs (e.g. after adding one new video) stay cheap.
  Process {
    id: posterExtractProc
    command: ["bash", "-c", `
      set -f
      SRC="${root.wallpaperDir}"
      OUT="${root.posterDir}"
      mkdir -p "$OUT"
      command -v ffmpeg >/dev/null 2>&1 || exit 0
      for f in "$SRC"/*; do
        [ -f "$f" ] || continue
        base=$(basename "$f")
        case "$base" in
          *.mp4|*.mkv|*.webm|*.mov) ;;
          *) continue ;;
        esac
        poster="$OUT/$base.jpg"
        [ -f "$poster" ] && continue
        ffmpeg -y -loglevel error -ss 00:00:01 -i "$f" -frames:v 1 -vf "scale=480:-1" "$poster" 2>/dev/null
      done
    `]
    onRunningChanged: if (!running) root.posterCacheVersion++
  }

  // Bumped after each poster-extraction pass; referenced (but not used
  // directly) by delegate Image.source bindings so QML re-evaluates
  // whether a poster file now exists instead of caching a failed load.
  property int posterCacheVersion: 0

  function loadPosters() { posterExtractProc.running = true }

  function readColorMarkerContents() {
    // Rebuild the list of markers pending a read; the actual reading is
    // done by the colorMarkerReader Repeater below using FileView, which
    // is a documented, synchronous-enough API — not a dynamically
    // constructed Process per file (that path was unreliable in practice).
    const pending = []
    for (let i = 0; i < colorMarkerModel.count; i++) {
      const markerName = colorMarkerModel.get(i, "fileName")
      if (!root.colorMarkerFileContents[markerName]) pending.push(markerName)
    }
    root.pendingColorMarkers = pending
  }

  property var pendingColorMarkers: []

  // One FileView per pending marker file, each reading its single hex
  // line. Repeater instances are cheap and short-lived: once a marker's
  // content is captured into colorMap, it drops out of pendingColorMarkers
  // and this delegate is destroyed.
  Repeater {
    model: root.pendingColorMarkers
    delegate: FileView {
      required property string modelData
      path: root.colorMarkerDir + "/" + modelData
      blockLoading: true
      printErrors: false

      Component.onCompleted: {
        const hex = text().trim()
        if (hex) {
          const wallpaperName = modelData.slice(0, -4) // strip ".hex"
          root.colorMap = Object.assign({}, root.colorMap, { [wallpaperName]: hex })
          root.colorMarkerFileContents = Object.assign({}, root.colorMarkerFileContents, { [modelData]: hex })
        }
      }
    }
  }

  function hexToColorName(hex) {
    if (!hex) return ""
    let h = hex.replace("#", "")
    if (h.length !== 6) return ""
    const r = parseInt(h.substring(0, 2), 16) / 255
    const g = parseInt(h.substring(2, 4), 16) / 255
    const b = parseInt(h.substring(4, 6), 16) / 255
    const max = Math.max(r, g, b), min = Math.min(r, g, b)
    const d = max - min
    const v = max, s = max === 0 ? 0 : d / max
    if (s < 0.12 || v < 0.1) return ""
    let hue = 0
    if (d !== 0) {
      if (max === r) hue = ((g - b) / d) % 6
      else if (max === g) hue = (b - r) / d + 2
      else hue = (r - g) / d + 4
      hue *= 60
      if (hue < 0) hue += 360
    }
    if (hue >= 345 || hue < 15) return "Red"
    if (hue < 45) return "Orange"
    if (hue < 75) return "Yellow"
    if (hue < 165) return "Green"
    if (hue < 260) return "Blue"
    if (hue < 315) return "Purple"
    return "Pink"
  }

  // Rebuilds only added/removed entries instead of recreating the whole
  // list, which is what was causing thumbnails to unload while scrolling.
  ScriptModel {
    id: filteredModel
    values: {
      const f = root.filterText.toLowerCase()
      let list = root.wallpapers
      if (f !== "") list = list.filter(w => w.toLowerCase().indexOf(f) !== -1)
      if (root.colorFilter !== "") {
        list = list.filter(w => root.hexToColorName(root.colorMap[w]) === root.colorFilter)
      }
      return list
    }
  }

  Connections {
    target: Config
    function onWallpaperDirChanged() {
      root.wallpaperDir = Config.wallpaperDir
      folderModel.folder = "file://" + root.wallpaperDir
    }
  }

  function clampSelection() {
    const count = filteredModel.values.length
    if (count > 0) {
      if (root.selectedIndex < 0 || root.selectedIndex >= count) {
        root.selectedIndex = 0
      }
    } else {
      root.selectedIndex = -1
    }
  }

  // ---- Session restore ----
  // Each launch is a fresh process (spawned by a keybind), so nothing in
  // QML property state survives between opens — we persist to a real
  // JSON file on disk and reload it at startup.
  FileView {
    id: sessionFile
    path: root.cacheDir + "/session.json"
    blockLoading: true
    watchChanges: false

    JsonAdapter {
      id: session
      property string query: ""
      property string colorFilter: ""
      property string lastSelectedName: ""
    }

    // Missing file on first run is expected; FileView already skips
    // logging known errors when printErrors is false, so just disable
    // the automatic warning rather than filtering error types ourselves.
    printErrors: false
  }

  function restoreSession() {
    root.filterText = session.query
    root.colorFilter = session.colorFilter
    root._pendingRestoreName = session.lastSelectedName
  }

  property string _pendingRestoreName: ""

  function saveSession() {
    session.query = root.filterText
    session.colorFilter = root.colorFilter
    if (root.selectedIndex >= 0 && root.selectedIndex < filteredModel.values.length) {
      session.lastSelectedName = filteredModel.values[root.selectedIndex]
    }
    sessionFile.writeAdapter()
  }

  onWallpapersChanged: {
    if (root._pendingRestoreName !== "") {
      const idx = filteredModel.values.indexOf(root._pendingRestoreName)
      if (idx !== -1) root.selectedIndex = idx
      root._pendingRestoreName = ""
    }
  }

  // ---- Multi-monitor ----
  ListModel { id: monitorModel }

  Process {
    id: monitorProc
    command: ["bash", "-c", "hyprctl monitors -j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const monitors = JSON.parse(this.text)
          monitorModel.clear()
          for (const m of monitors) monitorModel.append({ name: m.name, selected: true })
        } catch (e) {
          console.log("[WallpaperPicker] failed to parse hyprctl monitors output:", e)
        }
      }
    }
  }

  function loadMonitors() { monitorProc.running = true }

  function selectedMonitorOutputs() {
    if (monitorModel.count <= 1) return "all"
    const selected = []
    for (let i = 0; i < monitorModel.count; i++) {
      if (monitorModel.get(i).selected) selected.push(monitorModel.get(i).name)
    }
    if (selected.length === 0) return "none"
    if (selected.length === monitorModel.count) return "all"
    return selected.join(",")
  }

  function toggleMonitor(index) {
    const item = monitorModel.get(index)
    if (item.selected) {
      let activeCount = 0
      for (let i = 0; i < monitorModel.count; i++) if (monitorModel.get(i).selected) activeCount++
      if (activeCount > 1) monitorModel.setProperty(index, "selected", false)
    } else {
      monitorModel.setProperty(index, "selected", true)
    }
  }

  // ---- Apply wallpaper (image or video) ----
  function applyWallpaper(filename) {
    const outputs = root.selectedMonitorOutputs()
    if (outputs === "none") return

    const fullPath = root.wallpaperDir + "/" + filename
    root.currentWallpaper = filename
    const escapeBash = (str) => String(str).replace(/(["\\$`])/g, '\\$1')
    const escPath = escapeBash(fullPath)
    const escOutputs = escapeBash(outputs)

    let wallpaperCmd
    if (root.isVideoFile(filename)) {
      // mpvpaper never returns on its own while it's painting the
      // wallpaper, so it must always be backgrounded with `&` or the
      // script blocks on it forever and matugen below never runs.
      if (outputs === "all") {
        wallpaperCmd = `mpvpaper -o 'loop --no-audio --hwdec=auto' '*' "${escPath}" &`
      } else {
        wallpaperCmd =
          `IFS=',' read -ra MONS <<< "${escOutputs}"\n` +
          `for m in "\${MONS[@]}"; do mpvpaper -o 'loop --no-audio --hwdec=auto' "$m" "${escPath}" & done`
      }
    } else {
      const outputFlag = outputs === "all" ? "" : `-o "${escOutputs}"`
      wallpaperCmd = `awww img ${outputFlag} "${escPath}" --transition-type wave --transition-angle 30 --transition-wave "60,30" --transition-step 90 --transition-fps 60`
    }

    // matugen can't decode video containers (mp4/mkv/webm/mov) directly —
    // it needs a still image. Rather than depend on posterExtractProc
    // having already produced a poster for this exact file (it's a
    // background pass over the whole folder and may not have run yet),
    // grab a fresh frame with ffmpeg right here at apply-time. Gifs are
    // still images to ImageMagick/matugen, so they're passed through as-is.
    const isVideoContainer = root.isVideoContainerFile(filename)

    // Run the color-extraction step in the script's own foreground
    // (after backgrounding the wallpaper-setting command above it) rather
    // than in a nested `(...) &` subshell. The setsid-detached wrapper
    // that runs this whole script appears to tear down before a freshly
    // spawned nested subshell gets scheduled, so ffmpeg/matugen never
    // actually started when they lived in a subshell. Running them as
    // the script's last foreground steps keeps the script's own process
    // alive until they finish, without blocking wallpaper application
    // (mpvpaper/awww are already backgrounded above).
    const matugenBlock = isVideoContainer
      ? `FRAME_PATH="/tmp/matugen_frame_$$.png"\n` +
        `ffmpeg -y -loglevel error -ss 00:00:01 -i "${escPath}" -frames:v 1 "$FRAME_PATH" >> /tmp/matugen.log 2>&1\n` +
        `if [ -s "$FRAME_PATH" ]; then\n` +
        `  matugen image "$FRAME_PATH" -m dark --source-color-index 0 >> /tmp/matugen.log 2>&1\n` +
        `  rm -f "$FRAME_PATH"\n` +
        `else\n` +
        `  echo "[$(date +'%H:%M:%S')] frame extraction failed for ${escPath}" >> /tmp/matugen.log\n` +
        `fi\n`
      : `matugen image "${escPath}" -m dark --source-color-index 0 >> /tmp/matugen.log 2>&1\n`

    const script = "#!/usr/bin/env bash\n" +
      "pkill mpvpaper 2>/dev/null || true\n" +
      wallpaperCmd + "\n" +
      matugenBlock

    Quickshell.execDetached(["bash", "-c",
      `SCRIPT=$(mktemp /tmp/apply-wallpaper.XXXXXX.sh); cat > "$SCRIPT" << 'WPEOF'\n${script}\nWPEOF\nchmod +x "$SCRIPT"; setsid "$SCRIPT" < /dev/null &> /dev/null & disown; sleep 15; rm -f "$SCRIPT"`
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

    Scaler {
      id: scaler
      currentWidth: Screen.width
      currentHeight: Screen.height
    }
    function s(val) { return scaler.s(val) }

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
        height: parent.height * 0.30
        radius: overlay.s(14)
        clip: true
        focus: true
        color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.85)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)

        // Fade the card in only once the wallpaper list has actually
        // loaded, instead of showing an empty list for a moment first.
        opacity: root.wallpapers.length > 0 ? 1 : 0
        scale: root.wallpapers.length > 0 ? 1 : 0.95
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

        Keys.onEscapePressed: Qt.quit()
        MouseArea { anchors.fill: parent }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: overlay.s(20)
          spacing: overlay.s(14)

          // inputbar
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: overlay.s(46)
            radius: overlay.s(10)
            color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.85)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.06)

            Row {
              anchors.fill: parent
              anchors.leftMargin: overlay.s(14)
              anchors.rightMargin: overlay.s(14)
              spacing: overlay.s(8)

              Text {
                text: "󰸉"
                font.pixelSize: overlay.s(13)
                font.weight: Font.Bold
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.accent
                anchors.verticalCenter: parent.verticalCenter
              }

              TextInput {
                id: searchInput
                width: parent.width - overlay.s(24)
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: overlay.s(14)
                font.family: "JetBrainsMono Nerd Font"
                color: MatugenColors.text
                text: root.filterText
                focus: true
                clip: true

                onTextChanged: {
                  root.filterText = text
                  root.clampSelection()
                }

                Keys.onEscapePressed: Qt.quit()
                Keys.onReturnPressed: {
                  if (root.selectedIndex >= 0 && root.selectedIndex < filteredModel.values.length) {
                    root.applyWallpaper(filteredModel.values[root.selectedIndex])
                  } else if (filteredModel.values.length > 0) {
                    root.applyWallpaper(filteredModel.values[0])
                  }
                }
                Keys.onLeftPressed: if (root.selectedIndex > 0) root.selectedIndex--
                Keys.onRightPressed: if (root.selectedIndex < filteredModel.values.length - 1) root.selectedIndex++

                Text {
                  text: "Search wallpapers..."
                  font: parent.font
                  color: Qt.rgba(MatugenColors.text.r, MatugenColors.text.g, MatugenColors.text.b, 0.4)
                  visible: searchInput.text.length === 0
                }
              }
            }
          }

          // color filter + monitor row
          RowLayout {
            Layout.fillWidth: true
            spacing: overlay.s(8)

            Rectangle {
              width: overlay.s(28); height: overlay.s(28); radius: overlay.s(8)
              color: root.colorFilter === "" ? MatugenColors.accent : "transparent"
              border.width: 1
              border.color: Qt.rgba(1, 1, 1, 0.15)
              Text {
                anchors.centerIn: parent
                text: "All"
                font.pixelSize: overlay.s(9)
                font.family: "JetBrainsMono Nerd Font"
                color: root.colorFilter === "" ? MatugenColors.bgBase : MatugenColors.text
              }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.colorFilter = ""; root.clampSelection() } }
            }

            Repeater {
              model: root.colorSwatches
              delegate: Rectangle {
                width: overlay.s(24); height: overlay.s(24); radius: overlay.s(12)
                color: modelData.hex
                border.width: root.colorFilter === modelData.name ? overlay.s(2) : 1
                border.color: root.colorFilter === modelData.name ? MatugenColors.text : Qt.rgba(1, 1, 1, 0.15)
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.colorFilter = root.colorFilter === modelData.name ? "" : modelData.name
                    root.clampSelection()
                  }
                }
              }
            }

            Item { Layout.fillWidth: true }

            // Monitor selector — only shown when more than one output exists
            Row {
              visible: monitorModel.count > 1
              spacing: overlay.s(6)
              Repeater {
                model: monitorModel
                delegate: Rectangle {
                  width: monLabel.implicitWidth + overlay.s(12)
                  height: overlay.s(24)
                  radius: overlay.s(6)
                  color: model.selected ? MatugenColors.accent : "transparent"
                  border.width: 1
                  border.color: Qt.rgba(1, 1, 1, 0.15)
                  Text {
                    id: monLabel
                    anchors.centerIn: parent
                    text: model.name
                    font.pixelSize: overlay.s(9)
                    font.family: "JetBrainsMono Nerd Font"
                    color: model.selected ? MatugenColors.bgBase : MatugenColors.text
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleMonitor(index) }
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
              anchors.bottomMargin: overlay.s(10)
              orientation: ListView.Horizontal
              spacing: overlay.s(14)
              clip: true
              model: filteredModel
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

                readonly property bool isVideo: root.isVideoFile(thumbCard.modelData)
                readonly property bool isVideoContainer: root.isVideoContainerFile(thumbCard.modelData)
                readonly property bool isGif: thumbCard.modelData.toLowerCase().endsWith(".gif")

                Rectangle {
                  anchors.fill: parent
                  radius: overlay.s(12)
                  clip: true
                  color: "transparent"

                  Image {
                    anchors.fill: parent
                    // Qt's image plugins decode a gif's first frame like any
                    // other still image, so gifs get a real thumbnail here.
                    // True video containers use the pre-extracted poster below.
                    visible: !thumbCard.isVideoContainer
                    source: thumbCard.isVideoContainer ? "" : "file://" + root.wallpaperDir + "/" + thumbCard.modelData
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    // Decode at thumbnail size instead of full wallpaper
                    // resolution, this is what actually made loading feel
                    // slow once the file list itself became instant.
                    sourceSize.width: thumbCard.width
                    sourceSize.height: thumbCard.height
                  }

                  // Video containers (mp4/mkv/webm/mov) get a poster frame
                  // extracted by ffmpeg during the background color-extract
                  // pass (see posterExtractProc) since there's no in-process
                  // decoder available without QtMultimedia. Falls back to a
                  // plain tile until the poster file shows up on disk.
                  Image {
                    anchors.fill: parent
                    visible: thumbCard.isVideoContainer
                    source: thumbCard.isVideoContainer
                            ? "file://" + root.posterDir + "/" + thumbCard.modelData + ".jpg" : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    sourceSize.width: thumbCard.width
                    sourceSize.height: thumbCard.height
                    cache: false

                    Rectangle {
                      anchors.fill: parent
                      visible: parent.status !== Image.Ready
                      color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 1.0)
                    }
                  }
                }

                Rectangle {
                  anchors.fill: parent
                  radius: overlay.s(12)
                  color: "transparent"
                  border.width: overlay.s(2)
                  border.color: MatugenColors.accent
                  visible: root.selectedIndex === thumbCard.index
                }

                Rectangle {
                  id: gifBadge
                  visible: thumbCard.isVideo
                  width: overlay.s(22)
                  height: overlay.s(22)
                  radius: overlay.s(6)
                  anchors.top: parent.top
                  anchors.right: parent.right
                  anchors.margins: overlay.s(6)
                  color: Qt.rgba(0.1, 0.1, 0.12, 0.6)

                  Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: 1
                    text: ""
                    font.pixelSize: overlay.s(20)
                    color: "white"
                  }
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
                height: overlay.s(4)

                contentItem: Rectangle {
                  radius: overlay.s(8)
                  color: Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.5)
                }
                background: Rectangle {
                  radius: overlay.s(8)
                  color: Qt.rgba(1, 1, 1, 0.05)
                }
              }
            }

            MouseArea {
              anchors.fill: listview
              acceptedButtons: Qt.NoButton
              onWheel: (event) => {
                let delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                if (delta < 0 && root.selectedIndex < filteredModel.values.length - 1) {
                  root.selectedIndex++
                } else if (delta > 0 && root.selectedIndex > 0) {
                  root.selectedIndex--
                }
                event.accepted = true
              }
            }

            Text {
              visible: filteredModel.values.length === 0
              anchors.centerIn: parent
              text: root.wallpapers.length === 0
                    ? "No wallpapers found in\n" + root.wallpaperDir
                    : "No matches"
              horizontalAlignment: Text.AlignHCenter
              font.pixelSize: overlay.s(12)
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
