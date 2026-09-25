import "Singletons"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire

Item {
  id: root

  Component.onCompleted: {
    Scaler.currentWidth = Screen.width
  }

  function s(val) { return Scaler.s(val) }

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
  property int  activeTab: 0
  property int    volumeLevel: sinkAudio ? Math.round(sinkAudio.volume * 100) : 0
  property bool   muted:       sinkAudio ? sinkAudio.muted : false
  property string sinkName:    sink ? (sink.description || sink.nickname || sink.name || "Audio Output") : "Audio Output"
  property string volumeIcon: {
    if (root.muted || root.volumeLevel === 0) return "󰖁"
    if (root.volumeLevel >= 70) return ""
    if (root.volumeLevel >= 30) return ""
    return ""
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
  readonly property color accentColorLight: Qt.lighter(MatugenColors.accent, 1.35)
  function deviceGlyph(node, isInput) {
    var name = ((node.description || node.name || "") + "").toLowerCase()
    if (isInput) {
      if (name.indexOf("webcam") !== -1) return ""
      return ""
    }
    if (name.indexOf("headphone") !== -1 || name.indexOf("headset") !== -1) return ""
    if (name.indexOf("hdmi") !== -1 || name.indexOf("monitor") !== -1 || name.indexOf("tv") !== -1) return ""
    if (name.indexOf("bluetooth") !== -1) return ""
    return ""
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
    implicitWidth: s(360)
    implicitHeight: s(56)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "qs-volume-osd"

    anchors.bottom: true
    margins.bottom: s(120)

    property real osdAnim: root.osdVisible ? 1.0 : 0.0
    Behavior on osdAnim { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    Rectangle {
      anchors.centerIn: parent
      width: s(300)
      height: s(50)
      radius: s(10)
      color: Qt.rgba(0.13, 0.13, 0.14, 0.92)
      border.color: Qt.rgba(1, 1, 1, 0.09)
      border.width: 1
      opacity: volOsd.osdAnim
      scale: 0.95 + 0.05 * volOsd.osdAnim
      Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
          var delta = wheel.angleDelta.y > 0 ? 5 : -5
          var pct = Math.max(0, Math.min(100, root.volumeLevel + delta))
          root.setVolume(pct)
        }
      }

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: s(10)
        anchors.rightMargin: s(8)
        spacing: s(6)

        Text {
          text: root.muted ? "󰖁" : root.volumeIcon
          font.pixelSize: s(18)
          font.family: "JetBrainsMono Nerd Font"
          color: root.muted ? "white" : MatugenColors.accent

          MouseArea {
            anchors.fill: parent
            anchors.margins: s(-6)
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleMute()
          }
        }

        Item {
          id: osdSliderRoot
          Layout.fillWidth: true
          Layout.preferredHeight: s(16)

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: s(10)
            radius: s(5)
            color: Qt.rgba(1, 1, 1, 0.12)

            Rectangle {
              width: parent.width * (Math.min(root.volumeLevel, 100) / 100)
              height: parent.height
              radius: s(5)
              color: root.heroMuted ? MatugenColors.textMuted : root.accentColor
              Behavior on width { enabled: !osdSliderMa.pressed; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
          }

          MouseArea {
            id: osdSliderMa
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: (mouse) => updateVol(mouse.x)
            onPositionChanged: (mouse) => { if (pressed) updateVol(mouse.x) }
            function updateVol(mx) {
              var pct = Math.max(0, Math.min(100, Math.round((mx / width) * 100)))
              if (root.muted) root.toggleMute()
              root.setVolume(pct)
            }

            onWheel: (wheel) => {
              var delta = wheel.angleDelta.y > 0 ? 5 : -5
              var pct = Math.max(0, Math.min(100, root.volumeLevel + delta))
              root.setVolume(pct)
            }
          }
        }

        Text {
          text: root.volumeLevel + "%"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: s(11)
          font.weight: Font.DemiBold
          color: Qt.rgba(1, 1, 1, 0.55)
          Layout.preferredWidth: s(28)
          horizontalAlignment: Text.AlignRight
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
        width: s(720)
        height: Math.min(s(560), Screen.height - s(70) - s(40))
        x: Config.barPosition === "left" ? s(80) : (Config.barPosition === "right" ? (Screen.width - width - s(80)) : (Screen.width - width - s(8)))
        y: Config.barPosition === "bottom" ? (Screen.height - height - s(70)) : (Config.barPosition === "left" || Config.barPosition === "right" ? (Screen.height - height - s(85)) : s(70))
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
                    text: root.heroMuted ? "󰖁" : root.volumeIcon
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
                id: heroSliderRoot
                Layout.fillWidth: true
                height: s(18)

                readonly property real frac: Math.min(150, root.heroLevel) / 150

                Rectangle {
                  id: heroTrack
                  anchors.fill: parent
                  radius: height / 2
                  color: Qt.rgba(1, 1, 1, 0.08)
                  clip: true

                  Rectangle {
                   width: Math.max(parent.radius * 2, parent.width * heroSliderRoot.frac)
                   height: parent.height
                   radius: parent.radius
                   color: root.heroMuted ? MatugenColors.textMuted : root.accentColor
                   Behavior on width { enabled: !sliderMa.pressed; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                   }

                  Rectangle {
                    width: s(2)
                    height: parent.height
                    x: Math.max(0, Math.min(parent.width - width, parent.width * heroSliderRoot.frac - width / 2))
                    color: MatugenColors.bgBase
                    opacity: 0.55
                    Behavior on x { enabled: !sliderMa.pressed; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                  }
                }

                MouseArea {
                  id: sliderMa
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onPressed: (mouse) => updateVol(mouse.x)
                  onPositionChanged: (mouse) => { if (pressed) updateVol(mouse.x) }
                  function updateVol(mx) {
                    var pct = Math.max(0, Math.min(150, Math.round((mx / width) * 150)))
                    root.setNodeVolume(root.heroNode, pct)}

                  onWheel: (wheel) => {
                    var delta = wheel.angleDelta.y > 0 ? 5 : -5
                    var pct = Math.max(0, Math.min(150, root.heroLevel + delta))
                    root.setNodeVolume(root.heroNode, pct)
                    }
                }
              }
            }
          }

// ── Tab switcher (stretched, below hero) ──
Rectangle {
  Layout.fillWidth: true
  Layout.preferredHeight: s(32)
  radius: s(8)
  color: Qt.rgba(1, 1, 1, 0.05)
  border.color: Qt.rgba(1, 1, 1, 0.08)
  border.width: 1

  Rectangle {
    width: (parent.width - s(4)) / 3
    height: parent.height - s(4)
    y: s(2)
    radius: s(6)
    color: MatugenColors.bgElevated2
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
                  font.pixelSize: s(25)
                  color: MatugenColors.textMuted
                  text: root.activeTab === 2 ? "" : "󰓃"
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: s(15)
                  color: MatugenColors.textDim
                  text: root.activeTab === 2 ? "No applications playing audio" : "No devices found"
                }
              }
            }

            delegate: Rectangle {
              id: delegateRoot
              width: deviceList.width
              height: root.activeTab === 2 ? s(64) : s(50)
              radius: s(10)

              property bool isDefault: {
                if (root.activeTab === 2) return false
                if (root.activeTab === 1) return root.source === modelData
                return root.sink === modelData
              }
            
              color: rowMa.containsMouse ? MatugenColors.bgElevated2 : MatugenColors.bgElevated
              
              readonly property int nodeLevel: modelData.audio ? Math.round(modelData.audio.volume * 100) : 0
              readonly property bool nodeMuted: modelData.audio ? modelData.audio.muted : false

              MouseArea {
                id: rowMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.activeTab !== 2 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                  if (root.activeTab === 2) return
                  if (root.activeTab === 1) Pipewire.preferredDefaultAudioSource = modelData
                  else Pipewire.preferredDefaultAudioSink = modelData
                }
              }

              // ── Output / Input row layout (unchanged) ──
              RowLayout {
                visible: root.activeTab !== 2
                anchors.fill: parent
                anchors.leftMargin: s(10)
                anchors.rightMargin: s(10)
                spacing: s(10)

                Rectangle {
                  Layout.preferredWidth: s(30)
                  Layout.preferredHeight: s(30)
                  radius: s(8)
                  color: delegateRoot.isDefault ? root.accentColor : MatugenColors.textDim

                  Text {
                    anchors.centerIn: parent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: s(13)
                     color: MatugenColors.text
                    text: root.deviceGlyph(modelData, root.activeTab === 1)
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
                      text: modelData.description || modelData.nickname || modelData.name
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
                  visible: !delegateRoot.isDefault
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: s(10)
                  color: MatugenColors.text
                  text: delegateRoot.nodeMuted ? "Muted" : (modelData.audio ? delegateRoot.nodeLevel + "%" : "")
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
                    color: delegateRoot.nodeMuted ? MatugenColors.textMuted : MatugenColors.textDim
                    text: delegateRoot.nodeMuted ? "󰖁" : ""
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

              // ── Apps row layout ──
              ColumnLayout {
                visible: root.activeTab === 2
                anchors.fill: parent
                anchors.leftMargin: s(10)
                anchors.rightMargin: s(10)
                anchors.topMargin: s(7)
                anchors.bottomMargin: s(7)
                spacing: s(4)

                RowLayout {
                  Layout.fillWidth: true
                  spacing: s(7)

                  Text {
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: s(11)
                    color: MatugenColors.textDim
                    text: ""
                  }

                  Text {
                    Layout.fillWidth: true; elide: Text.ElideRight
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: s(12)
                    font.weight: Font.DemiBold
                    color: MatugenColors.text
                    text: {
                      var appName = modelData.properties && modelData.properties["application.name"]
                        ? modelData.properties["application.name"]
                        : (modelData.description || modelData.name || "Unknown App")
                      var media = modelData.properties
                        ? (modelData.properties["media.name"] || modelData.properties["media.title"] || "")
                        : ""
                      return media ? (appName + " \u2013 " + media) : appName
                    }
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: s(7)

                  Text {
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: s(10)
                    color: delegateRoot.nodeMuted ? MatugenColors.textMuted : MatugenColors.textDim
                    text: delegateRoot.nodeMuted ? "󰖁" : ""

                    MouseArea {
                      anchors.fill: parent
                      anchors.margins: s(-4)
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.toggleNodeMute(modelData)
                    }
                  }

                  Item {
                    id: appSliderRoot
                    Layout.fillWidth: true
                    Layout.preferredHeight: s(12)

                    readonly property real frac: Math.min(150, delegateRoot.nodeLevel) / 150

                    Rectangle {
                      id: appTrack
                      anchors.fill: parent
                      radius: height / 2
                      color: Qt.rgba(1, 1, 1, 0.08)
                      clip: true

                      Rectangle {
                        width: Math.max(parent.radius * 2, parent.width * appSliderRoot.frac)
                        height: parent.height
                        radius: parent.radius
                        color: delegateRoot.nodeMuted ? MatugenColors.textMuted : root.accentColor
                        Behavior on width { enabled: !appSliderMa.pressed; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                      }
                    }

                    MouseArea {
                      id: appSliderMa
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onPressed: (mouse) => updateVol(mouse.x)
                      onPositionChanged: (mouse) => { if (pressed) updateVol(mouse.x) }
                      function updateVol(mx) {
                        var pct = Math.max(0, Math.min(150, Math.round((mx / width) * 150)))
                        root.setNodeVolume(modelData, pct)
                      }

                      onWheel: (wheel) => {
                        var delta = wheel.angleDelta.y > 0 ? 5 : -5
                        var pct = Math.max(0, Math.min(150, delegateRoot.nodeLevel + delta))
                        root.setNodeVolume(modelData, pct)
                      }
                    }
                  }

                  Text {
                    Layout.preferredWidth: s(30)
                    horizontalAlignment: Text.AlignRight
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: s(10)
                    color: delegateRoot.nodeMuted ? MatugenColors.textMuted : MatugenColors.textDim
                    text: delegateRoot.nodeMuted ? "\u2014" : delegateRoot.nodeLevel + "%"
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
