import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import "../../Singletons"

Item {
  id: root

  property var s: function(v) { return v }
  property var options: []
  property string labelKey: ""
  property int currentIndex: -1
  property string text: ""
  property string placeholderText: "Select"
  property bool searchable: false
  property bool useOptionAsFont: false
  property int boxWidth: 160
  property int boxHeight: 30
  property int rowHeight: 32
  property int maxVisible: 6
  property int fontSize: 11
  property string fontFamily: "JetBrainsMono Nerd Font"
  property Item boundsItem: null

  readonly property bool isOpen: popup.visible
  readonly property bool hovered: btnMa.containsMouse && enabled
  readonly property string currentLabel: {
    if (text.length > 0) return text
    if (currentIndex >= 0 && currentIndex < options.length) return labelOf(options[currentIndex])
    return ""
  }

  signal picked(int index, var value)
  signal opened()
  signal closed()

  // internal
  property string query: ""
  property var entries: []
  property bool openUpward: false
  property real popupMaxHeight: 250

  implicitWidth: s(boxWidth)
  implicitHeight: s(boxHeight)
  Layout.preferredWidth: implicitWidth
  Layout.preferredHeight: implicitHeight
  opacity: enabled ? 1 : 0.4
  activeFocusOnTab: enabled

  readonly property color idleColor: Qt.tint(MatugenColors.bgElevated2, Qt.rgba(MatugenColors.text.r, MatugenColors.text.g, MatugenColors.text.b, 0.14))
  readonly property color accentTint: Qt.rgba(MatugenColors.accent.r, MatugenColors.accent.g, MatugenColors.accent.b, 0.18)

  function labelOf(o) {
    if (labelKey.length > 0 && o !== null && typeof o === "object") return String(o[labelKey])
    return String(o)
  }

  function fuzzyScore(q, t) {
    q = q.toLowerCase(); t = t.toLowerCase()
    if (q.length === 0) return 1
    let qi = 0, score = 0, run = 0, prev = -2
    for (let ti = 0; ti < t.length && qi < q.length; ti++) {
      if (t[ti] !== q[qi]) continue
      score += 10
      if (prev === ti - 1) { run++; score += run * 5 } else run = 0
      if (ti === 0 || " /_-.".indexOf(t[ti - 1]) >= 0) score += 15
      prev = ti
      qi++
    }
    return qi === q.length ? score : -1
  }

  function rebuild() {
    let out = []
    for (let i = 0; i < options.length; i++) {
      let label = labelOf(options[i])
      if (query.length === 0) { out.push({ label: label, index: i, score: 0 }); continue }
      let sc = fuzzyScore(query, label)
      if (sc >= 0) out.push({ label: label, index: i, score: sc })
    }
    if (query.length > 0) out.sort((a, b) => b.score - a.score || a.index - b.index)
    entries = out
  }

  function updateDirection() {
    let rows = Math.min(entries.length, maxVisible)
    let searchH = searchable ? s(34) : 0
    let want = rows * (s(rowHeight) + s(2)) + searchH + s(8)
    let vh = boundsItem ? boundsItem.height : (Window.window ? Window.window.height : 100000)
    let top = boundsItem ? root.mapToItem(boundsItem, 0, 0).y : root.mapToItem(null, 0, 0).y
    let below = vh - (top + root.height) - s(12)
    let above = top - s(12)
    openUpward = want > below && above > below
    let avail = openUpward ? above : below
    popupMaxHeight = Math.max(s(rowHeight), Math.min(want, avail) - searchH - s(8))
  }

  function pick(i) {
    root.picked(i, root.options[i])
    popup.close()
  }

  function toggle() {
    if (!enabled) return
    if (popup.visible) popup.close()
    else if (options.length > 0) popup.open()
  }

  onOptionsChanged: rebuild()
  Component.onCompleted: rebuild()

  Keys.onPressed: (event) => {
    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.toggle()
      event.accepted = true
    }
  }

  // ---------- button ----------

  Rectangle {
    id: btn
    anchors.fill: parent
    radius: root.s(8)
    color: (root.isOpen || root.hovered)
      ? Qt.tint(root.idleColor, root.accentTint)
      : root.idleColor
    Behavior on color { ColorAnimation { duration: 150 } }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: root.s(12)
      anchors.rightMargin: root.s(12)
      spacing: root.s(8)

      Text {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: root.currentLabel.length > 0 ? root.currentLabel : root.placeholderText
        elide: Text.ElideRight
        font.pixelSize: root.s(root.fontSize)
        font.weight: Font.Bold
        font.family: (root.useOptionAsFont && root.currentLabel.length > 0) ? root.currentLabel : root.fontFamily
        color: root.currentLabel.length > 0 ? MatugenColors.text : MatugenColors.textDim
      }

      // drawn chevron, points down and flips up when open
      Item {
        id: chevron
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: root.s(14)
        Layout.preferredHeight: root.s(14)
        rotation: root.isOpen ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        readonly property real arm: root.s(6)
        readonly property real thick: Math.max(1.5, root.s(1.6))
        readonly property real apexX: width / 2
        readonly property real apexY: height / 2 + arm * 0.32

        Rectangle {
          x: chevron.apexX - chevron.arm
          y: chevron.apexY - chevron.thick / 2
          width: chevron.arm
          height: chevron.thick
          radius: height / 2
          antialiasing: true
          transformOrigin: Item.Right
          rotation: 40
          color: MatugenColors.textDim
        }
        Rectangle {
          x: chevron.apexX
          y: chevron.apexY - chevron.thick / 2
          width: chevron.arm
          height: chevron.thick
          radius: height / 2
          antialiasing: true
          transformOrigin: Item.Left
          rotation: -40
          color: MatugenColors.textDim
        }
      }
    }

    MouseArea {
      id: btnMa
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: root.toggle()
    }
  }

  // ---------- popup ----------

  Popup {
    id: popup
    y: root.openUpward ? -(height + root.s(6)) : root.height + root.s(6)
    width: root.width
    padding: root.s(4)
    margins: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    background: Rectangle {
      radius: root.s(10)
      color: MatugenColors.bgBase
    }

    onAboutToShow: {
      root.query = ""
      root.rebuild()
      root.updateDirection()
    }
    onOpened: {
      if (root.searchable) searchInput.forceActiveFocus()
      root.opened()
    }
    onClosed: root.closed()

    enter: Transition {
      NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140; easing.type: Easing.OutCubic }
    }
    exit: Transition {
      NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100; easing.type: Easing.InCubic }
    }

    contentItem: ColumnLayout {
      spacing: root.s(4)

      Rectangle {
        visible: root.searchable
        Layout.fillWidth: true
        Layout.preferredHeight: root.searchable ? root.s(30) : 0
        radius: root.s(8)
        color: MatugenColors.bgElevated

        Text {
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: root.s(10)
          visible: searchInput.text.length === 0
          text: "Search"
          font.pixelSize: root.s(root.fontSize)
          font.family: root.fontFamily
          color: MatugenColors.textDim
        }

        TextInput {
          id: searchInput
          anchors.fill: parent
          anchors.leftMargin: root.s(10)
          anchors.rightMargin: root.s(10)
          verticalAlignment: TextInput.AlignVCenter
          clip: true
          font.pixelSize: root.s(root.fontSize)
          font.family: root.fontFamily
          color: MatugenColors.text
          selectionColor: MatugenColors.accent
          selectedTextColor: MatugenColors.accentText
          onTextEdited: { root.query = text; root.rebuild() }
          onAccepted: if (root.entries.length > 0) root.pick(root.entries[0].index)
        }
      }

      ListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, root.popupMaxHeight)
        model: root.entries
        clip: true
        spacing: root.s(2)
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
          policy: list.contentHeight > list.height + 1 ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
          width: root.s(6)
          contentItem: Rectangle {
            implicitWidth: root.s(3)
            radius: width / 2
            color: MatugenColors.textDim
            opacity: 0.6
          }
          background: Item {}
        }

        delegate: Rectangle {
          id: row
          required property var modelData
          required property int index

          readonly property bool isSel: modelData.index === root.currentIndex
          property bool shown: root.query.length > 0

          width: ListView.view.width
          height: root.s(root.rowHeight)
          radius: root.s(8)
          opacity: shown ? 1 : 0
          transform: Translate {
            y: row.shown ? 0 : (root.openUpward ? -root.s(6) : root.s(6))
            Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
          }
          Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

          color: isSel
            ? MatugenColors.accent
            : (ma.containsMouse
                ? MatugenColors.bgElevated2
                : "transparent")
          Behavior on color { ColorAnimation { duration: 120 } }

          Timer {
            running: popup.visible && !row.shown
            interval: Math.min(row.index, 10) * 25 + 10
            onTriggered: row.shown = true
          }
          Connections {
            target: popup
            function onClosed() { row.shown = false }
          }

          Text {
            anchors.fill: parent
            anchors.leftMargin: root.s(10)
            anchors.rightMargin: root.s(10)
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: row.modelData.label
            font.pixelSize: root.s(root.fontSize)
            font.weight: row.isSel ? Font.Bold : Font.Normal
            font.family: root.useOptionAsFont ? row.modelData.label : root.fontFamily
            color: row.isSel ? MatugenColors.accentText : MatugenColors.text
          }

          MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.pick(row.modelData.index)
          }
        }
      }
    }
  }
}
