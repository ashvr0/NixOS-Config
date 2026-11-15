import QtQuick
import QtQuick.Layouts
import ".."
import "../Singletons"
import "../Singletons/SearchProviders.js" as SearchProviders
import "../Components"

ColumnLayout {
  id: root

  required property var s
  required property var matches
  required property string fontFamily
  // Called by the "Open launcher" button
  required property var openLauncher

  readonly property var positionChoices: [
    { id: "top",    label: "Top" },
    { id: "bottom", label: "Bottom" },
    { id: "left",   label: "Left" },
    { id: "right",  label: "Right" },
    { id: "center", label: "Center" }
  ]

  Layout.fillWidth: true
  spacing: s(14)
  focus: true

  TapHandler { onTapped: root.forceActiveFocus() }

  // ---------- building blocks ----------

  // ---------- settings ----------

  ColumnLayout {
    Layout.fillWidth: true
    spacing: root.s(2)

    SettingRow {
      visible: root.matches("Screen position")
      icon: "󰍹"
      title: "Screen position"
      description: "Where the launcher popup appears on screen"

      control: Component {
        Dropdown {
          s: root.s
          boxWidth: 130
          options: root.positionChoices
          labelKey: "label"
          currentIndex: {
            const i = root.positionChoices.findIndex(c => c.id === (Config.launcherPosition || "center"))
            return i >= 0 ? i : 4
          }
          onPicked: (i) => Config.launcherPosition = root.positionChoices[i].id
        }
      }
    }

    SettingRow {
      visible: root.matches("Launcher width")
      icon: "󰩨"
      title: "Launcher width"
      description: "Total width of the launcher window in pixels"

      control: Component {
        Stepper {
          s: root.s
          value: Config.launcherWidth
          from: 300
          to: 1200
          step: 50
          suffix: "px"
          onMoved: (n) => Config.launcherWidth = n
        }
      }
    }

    SettingRow {
      visible: root.matches("Visible items")
      icon: "󰕰"
      title: "Visible items"
      description: "Number of search results displayed simultaneously"

      control: Component {
        Stepper {
          s: root.s
          value: Config.launcherVisibleItems
          from: 3
          to: 12
          onMoved: (n) => Config.launcherVisibleItems = n
        }
      }
    }

    SettingRow {
      visible: root.matches("Smart sorting")
      icon: "󰒺"
      title: "Smart sorting"
      description: "Sort apps by how often and how long you use them"

      control: Component {
        Rectangle {
          width: root.s(48); height: root.s(26); radius: root.s(13)
          color: Config.launcherSmartSort ? MatugenColors.accent : Qt.rgba(1, 1, 1, 0.08)
          Behavior on color { ColorAnimation { duration: 250 } }
          Rectangle {
            width: root.s(20); height: root.s(20); radius: root.s(10); color: "white"
            anchors.verticalCenter: parent.verticalCenter
            x: Config.launcherSmartSort ? parent.width - width - root.s(3) : root.s(3)
            Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Config.launcherSmartSort = !Config.launcherSmartSort
          }
        }
      }
    }

    SettingRow {
      visible: root.matches("Web search provider")
      icon: "󰖟"
      title: "Web search provider"
      description: "Type ? followed by a query in the launcher to search in your browser"

      control: Component {
        Dropdown {
          s: root.s
          boxWidth: 150
          searchable: true
          options: SearchProviders.PROVIDERS
          labelKey: "name"
          currentIndex: SearchProviders.PROVIDERS.findIndex(p => p.id === Config.launcherSearchProvider)
          onPicked: (i) => Config.launcherSearchProvider = SearchProviders.PROVIDERS[i].id
        }
      }
    }
  }

  // ---------- open launcher ----------

  Rectangle {
    id: openBtn
    Layout.alignment: Qt.AlignRight
    Layout.preferredWidth: openRow.implicitWidth + root.s(28)
    Layout.preferredHeight: root.s(36)
    radius: root.s(Config.uiRadius)
    color: openMa.pressed
      ? Qt.darker(MatugenColors.accent, 1.15)
      : (openMa.containsMouse ? Qt.lighter(MatugenColors.accent, 1.08) : MatugenColors.accent)
    Behavior on color { ColorAnimation { duration: 120 } }
    scale: openMa.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

    RowLayout {
      id: openRow
      anchors.centerIn: parent
      spacing: root.s(8)
      Text { text: "󰕰"; font.pixelSize: root.s(15); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.bgBase }
      Text { text: "Open launcher"; font.pixelSize: root.s(12); font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.bgBase }
    }

    MouseArea {
      id: openMa
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.openLauncher()
    }
  }
}
