import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire

Item {
  id: root

  Scaler {
    id: scaler
    currentWidth: Screen.width
  }
  function s(val) { return scaler.s(val) }

  IpcHandler {
    target: "audio"
    function toggle(): void {
      root.volumeMenuOpen = !root.volumeMenuOpen
    }
  }

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var sinkAudio: sink ? sink.audio : null
  readonly property var source: Pipewire.defaultAudioSource
  readonly property var sourceAudio: source ? source.audio : null

  property bool volumeMenuOpen: false
  property bool osdVisible: false
  property bool osdFirstRun: true
  property int  activeTab: 0 // 0 output, 1 input, 2 apps

  property int    volumeLevel: sinkAudio ? Math.round(sinkAudio.volume * 100) : 0
  property bool   muted:       sinkAudio ? sinkAudio.muted : false
  property string sinkName:    sink ? (sink.description || sink.nickname || sink.name || "Audio Output") : "Audio Output"
  property string volumeIcon: {
    if (root.muted || root.volumeLevel === 0) return "\u{f026}"
    if (root.volumeLevel >= 70) return "\u{f028}"
    if (root.volumeLevel >= 30) return "\u{f027}"
    return "\u{f026}"
  }

  readonly property var outputDevices: {
    var out = []
    for (var i = 0; i < Pipewire.nodes.values.length; i++) {
      var n = Pipewire.nodes.values[i]
      if (n.audio && n.isSink && !n.isStream) out.push(n)
    }
    return out
  }

  readonly property var inputDevices: {
    var out = []
    for (var i = 0; i < Pipewire.nodes.values.length; i++) {
      var n = Pipewire.nodes.values[i]
      if (n.audio && !n.isSink && !n.isStream) out.push(n)
    }
    return out
  }

  readonly property var appStreams: {
    var out = []
    for (var i = 0; i < Pipewire.nodes.values.length; i++) {
      var n = Pipewire.nodes.values[i]
      if (n.audio && n.isStream && n.isSink) out.push(n)
    }
    return out
  }

  PwObjectTracker {
    objects: {
      var t = []
      if (root.sink) t.push(root.sink)
      if (root.source) t.push(root.source)
      for (var i = 0; i < root.outputDevices.length; i++) t.push(root.outputDevices[i])
      for (var j = 0; j < root.inputDevices.length; j++) t.push(root.inputDevices[j])
      for (var k = 0; k < root.appStreams.length; k++) t.push(root.appStreams[k])
      return t
    }
  }

  readonly property var heroNode: root.activeTab === 1 ? root.source : root.sink
  readonly property var heroAudio: heroNode ? heroNode.audio : null
  readonly property int  heroLevel: heroAudio ? Math.round(heroAudio.volume * 100) : 0
  readonly property bool heroMuted: heroAudio ? heroAudio.muted : false
  readonly property string heroName: heroNode ? (heroNode.description || heroNode.nickname || heroNode.name || "No Device") : "No Device"

  readonly property color accentColor: MatugenColors.accent
  // Slightly lighter accent so bars/handles read as a gradient instead of a flat fill.
  readonly property color accentColorLight: Qt.lighter(MatugenColors.accent, 1.35)

  // Guess a device-class glyph from the node name so the list isn't a wall of identical rows.
  function deviceGlyph(node, isInput) {
    var name = ((node.description || node.name || "") + "").toLowerCase()
    if (isInput) {
      if (name.indexOf("webcam") !== -1) return "\u{f03d}"
      return "\u{f130}"
    }
    if (name.indexOf("headphone") !== -1 || name.indexOf("headset") !== -1) return "\u{f025}"
    if (name.indexOf("hdmi") !== -1 || name.indexOf("monitor") !== -1 || name.indexOf("tv") !== -1) return "\u{f26c}"
    if (name.indexOf("bluetooth") !== -1) return "\u{f293}"
    return "\u{f028}"
  }

  property int  _lastVol:   volumeLevel
  property bool _lastMuted: muted
  onVolumeLevelChanged: _checkOsd()
  onMutedChanged: _checkOsd()
  function _checkOsd() {
    var changed = volumeLevel !== _lastVol || muted !== _lastMuted
    if (!osdFirstRun && changed && !volumeMenuOpen) {
      osdVisible = true
      osdHideTimer.restart()
    }
    osdFirstRun = false
    _lastVol = volumeLevel
    _lastMuted = muted
  }

  Timer { id: osdHideTimer; interval: 1200; onTriggered: root.osdVisible = false }

  function setVolume(pct) {
    var clamped = Math.max(0, Math.min(150, pct))
    if (root.sinkAudio) root.sinkAudio.volume = clamped / 100
    if (!root.volumeMenuOpen) {
      root.osdVisible = true
      osdHideTimer.restart()
    }
  }

  function setNodeVolume(node, pct) {
    if (node && node.audio) node.audio.volume = Math.max(0, Math.min(150, pct)) / 100
  }

  function toggleNodeMute(node) {
    if (node && node.audio) node.audio.muted = !node.audio.muted
  }

  function toggleMute() {
    if (root.sinkAudio) root.sinkAudio.muted = !root.sinkAudio.muted
    root.osdVisible = true
    osdHideTimer.restart()
  }

  property real introMain: 0

  // ── OSD ──
  PanelWindow {
    id: volOsd
    visible: osdAnim > 0.01
    color: "transparent"
    implicitWidth: s(180)
    implicitHeight: s(180)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "qs-volume-osd"

    anchors.bottom: true
    margins.bottom: s(120)

    property real osdAnim: root.osdVisible ? 1.0 : 0.0
    Behavior on osdAnim { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    // Layered shadow: two soft rects offset behind the card fake elevation
    // without a real blur pass, which avoids an extra compositor effect node.
    Rectangle {
      anchors.centerIn: parent
      anchors.verticalCenterOffset: s(4)
      width: s(150)
      height: s(150)
      radius: s(20)
      color: Qt.rgba(0, 0, 0, 0.35)
      opacity: volOsd.osdAnim * 0.6
      scale: 0.97
    }

    Rectangle {
      anchors.centerIn: parent
      width: s(150)
      height: s(150)
      radius: s(18)
      color: Qt.rgba(0.13, 0.13, 0.14, 0.92)
      border.color: Qt.rgba(1, 1, 1, 0.09)
      border.width: 1
      opacity: volOsd.osdAnim
      scale: 0.95 + 0.05 * volOsd.osdAnim
      Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

      Column {
        anchors.centerIn: parent
        spacing: s(14)

        Text {
          text: root.muted ? "\u{f026}" : root.volumeIcon
          font.pixelSize: s(36)
          font.family: "JetBrainsMono Nerd Font"
          color: root.muted ? MatugenColors.textMuted : "white"
          anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
          text: root.muted ? "Muted" : root.volumeLevel + "%"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: s(11)
          font.weight: Font.DemiBold
          color: Qt.rgba(1, 1, 1, 0.55)
          anchors.horizontalCenter: parent.horizontalCenter
        }

        Rectangle {
          width: s(90); height: s(5); radius: s(2.5)
          color: Qt.rgba(1, 1, 1, 0.12)
          anchors.horizontalCenter: parent.horizontalCenter

          Rectangle {
            width: parent.width * (root.muted ? 0 : Math.min(root.volumeLevel, 100) / 100)
            height: parent.height; radius: s(2.5)
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: root.accentColor }
              GradientStop { position: 1.0; color: root.accentColorLight }
            }
            Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
          }
        }
      }
    }
  }

  // ── MAIN POPUP ──
  PanelWindow {
    id: volPopup
    visible: root.volumeMenuOpen
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qs-volume-popup"

    anchors { top: true; left: true; right: true; bottom: true }

    onVisibleChanged: {
      if (visible) {
        introMain = 0
        introAnim.start()
      }
    }

    NumberAnimation {
      id: introAnim
      target: root; property: "introMain"
      from: 0; to: 1.0; duration: 180; easing.type: Easing.OutCubic
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.volumeMenuOpen = false
    }

    FocusScope {
      anchors.fill: parent
      focus: root.volumeMenuOpen
      Keys.onEscapePressed: root.volumeMenuOpen = false
      Keys.onTabPressed: root.activeTab = (root.activeTab + 1) % 3

      // Soft drop shadow behind the card. Offset + layering rather than a
      // MultiEffect node, since this popup opens/closes often and an extra
      // effect item per open would add avoidable GPU cost.
      Rectangle {
        width: card.width
        height: card.height
        x: card.x
        y: card.y + s(6)
        radius: card.radius
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: introMain * 0.5
        scale: card.scale
        z: -1
      }

      Rectangle {
        id: card
        width: s(680)
        height: Math.min(s(560), Screen.height - s(70) - s(40))
        x: Config.barPosition === "left" ? s(8) : (Screen.width - width - s(8))
        y: Config.barPosition === "bottom" ? (Screen.height - height - s(70)) : s(70)
        radius: s(14)
        color: MatugenColors.bgBase
        border.color: Qt.rgba(1, 1, 1, 0.09)
        border.width: 1
        clip: true

        scale: 0.98 + (0.02 * introMain)
        opacity: introMain

        MouseArea { anchors.fill: parent }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: s(18)
          spacing: s(14)

          // ── Header: title + segmented control sharing a row ──
          RowLayout {
            Layout.fillWidth: true
            spacing: s(12)

            Text {
              text: "Sound"
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: s(14)
              font.weight: Font.DemiBold
              color: MatugenColors.text
            }

            Item { Layout.fillWidth: true }

            Rectangle {
              Layout.preferredWidth: s(220)
              Layout.preferredHeight: s(28)
              radius: s(8)
              color: Qt.rgba(1, 1, 1, 0.05)
              border.color: Qt.rgba(1, 1, 1, 0.08)
              border.width: 1

              Rectangle {
                width: (parent.width - s(4)) / 3
                height: parent.height - s(4)
                y: s(2)
                radius: s(6)
                color: MatugenColors.surface1
                border.color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                x: {
                  if (root.activeTab === 0) return s(2);
                  if (root.activeTab === 1) return width + s(2);
                  return (width * 2) + s(2);
                }
                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
              }

              RowLayout {
                anchors.fill: parent
                spacing: 0
                Repeater {
                  model: ["Output", "Input", "Apps"]
                  Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Text {
                      anchors.centerIn: parent
                      text: modelData
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: s(11)
                      font.weight: root.activeTab === index ? Font.DemiBold : Font.Normal
                      color: root.activeTab === index ? MatugenColors.text : MatugenColors.textDim
                      Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.activeTab = index
                    }
                  }
                }
              }
            }
          }

          // ── Hero row ──
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: s(84)
            radius: s(12)
            color: Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: s(14)
              spacing: s(8)

              RowLayout {
                Layout.fillWidth: true
                spacing: s(10)

                Rectangle {
                  Layout.preferredWidth: s(32)
                  Layout.preferredHeight: s(32)
                  radius: s(8)
                  color: root.heroMuted ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)

                  Text {
                    anchors.centerIn: parent
                    text: root.heroMuted ? "\u{f026}" : root.volumeIcon
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: s(15)
                    color: root.heroMuted ? MatugenColors.textDim : root.accentColor
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (root.activeTab === 1) { if (root.sourceAudio) root.sourceAudio.muted = !root.sourceAudio.muted }
                      else root.toggleMute()
                    }
                  }
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: s(1)

                  Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.heroName
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: s(12)
                    font.weight: Font.DemiBold
                    color: MatugenColors.text
                  }

                  Text {
                    text: root.activeTab === 1 ? "Input device" : "Output device"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: s(10)
                    color: MatugenColors.textDim
                  }
                }

                Text {
                  text: root.heroMuted ? "Muted" : root.heroLevel + "%"
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: s(18)
                  font.weight: Font.DemiBold
                  color: root.heroMuted ? MatugenColors.textMuted : MatugenColors.text
                }
              }

              Item {
                Layout.fillWidth: true
                height: s(18)

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width
                  height: s(5)
                  radius: s(2.5)
                  color: Qt.rgba(1, 1, 1, 0.08)

                  Rectangle {
                    width: parent.width * (Math.min(100, root.heroLevel) / 100)
                    height: parent.height
                    radius: s(2.5)
                    gradient: Gradient {
                      orientation: Gradient.Horizontal
                      GradientStop { position: 0.0; color: root.heroMuted ? MatugenColors.textMuted : root.accentColor }
                      GradientStop { position: 1.0; color: root.heroMuted ? MatugenColors.textMuted : root.accentColorLight }
                    }
                  }
                }

                Rectangle {
                  width: s(15); height: s(15); radius: s(7.5)
                  color: "white"
                  border.color: Qt.rgba(0, 0, 0, 0.15)
                  border.width: 1
                  y: (parent.height - height) / 2
                  x: Math.max(0, Math.min(parent.width - width, (parent.width * (Math.min(100, root.heroLevel) / 100)) - width / 2))
                  scale: sliderMa.pressed ? 1.15 : 1.0
                  Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                  id: sliderMa
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onPressed: (mouse) => updateVol(mouse.x)
                  onPositionChanged: (mouse) => { if (pressed) updateVol(mouse.x) }
                  function updateVol(mx) {
                    var pct = Math.max(0, Math.min(150, Math.round((mx / width) * 150)))
                    root.setNodeVolume(root.heroNode, pct)
                  }
                }
              }
            }
          }

          // ── Device list ──
          ListView {
            id: deviceList
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: s(3)
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            model: root.activeTab === 0 ? root.outputDevices : (root.activeTab === 1 ? root.inputDevices : root.appStreams)

            Item {
              width: deviceList.width; height: deviceList.height
              visible: deviceList.count === 0
              Column {
                anchors.centerIn: parent
                spacing: s(6)
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: s(20)
                  color: MatugenColors.textMuted
                  text: root.activeTab === 2 ? "\u{f028}" : "\u{f290}"
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: s(11)
                  color: MatugenColors.textDim
                  text: root.activeTab === 2 ? "No applications playing audio" : "No devices found"
                }
              }
            }

            delegate: Rectangle {
              id: delegateRoot
              width: deviceList.width
              height: s(50)
              radius: s(10)
              color: rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.045) : "transparent"
              Behavior on color { ColorAnimation { duration: 100 } }

              property bool isDefault: {
                if (root.activeTab === 2) return false
                if (root.activeTab === 1) return root.source === modelData
                return root.sink === modelData
              }

              MouseArea {
                id: rowMa
                anchors.fill: parent
                hoverEnabled: root.activeTab !== 2
                cursorShape: root.activeTab !== 2 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                  if (root.activeTab === 2) return
                  if (root.activeTab === 1) Pipewire.preferredDefaultAudioSource = modelData
                  else Pipewire.preferredDefaultAudioSink = modelData
                }
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: s(10)
                anchors.rightMargin: s(10)
                spacing: s(10)

                Rectangle {
                  Layout.preferredWidth: s(30)
                  Layout.preferredHeight: s(30)
                  radius: s(8)
                  color: delegateRoot.isDefault ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16) : Qt.rgba(1, 1, 1, 0.05)

                  Text {
                    anchors.centerIn: parent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: s(13)
                    color: delegateRoot.isDefault ? root.accentColor : MatugenColors.textDim
                    text: root.activeTab === 2 ? "\u{f028}" : root.deviceGlyph(modelData, root.activeTab === 1)
                  }
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: s(1)

                  Text {
                    Layout.fillWidth: true; elide: Text.ElideRight
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: s(12)
                    font.weight: delegateRoot.isDefault ? Font.DemiBold : Font.Normal
                    color: MatugenColors.text
                    text: {
                      if (root.activeTab === 2) {
                        return modelData.properties && modelData.properties["application.name"]
                          ? modelData.properties["application.name"]
                          : (modelData.description || modelData.name)
                      }
                      return modelData.description || modelData.nickname || modelData.name
                    }
                  }

                  Text {
                    visible: delegateRoot.isDefault
                    text: "Default"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: s(9)
                    color: root.accentColor
                  }
                }

                Text {
                  visible: root.activeTab === 2 || !delegateRoot.isDefault
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: s(10)
                  color: MatugenColors.textDim
                  text: (modelData.audio && modelData.audio.muted) ? "Muted" : (modelData.audio ? Math.round(modelData.audio.volume * 100) + "%" : "")
                }

                Rectangle {
                  Layout.preferredWidth: s(26)
                  Layout.preferredHeight: s(26)
                  radius: s(7)
                  color: muteMa.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"

                  Text {
                    anchors.centerIn: parent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: s(11)
                    color: (modelData.audio && modelData.audio.muted) ? MatugenColors.textMuted : MatugenColors.textDim
                    text: (modelData.audio && modelData.audio.muted) ? "\u{f026}" : "\u{f028}"
                  }

                  MouseArea {
                    id: muteMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleNodeMute(modelData)
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
