import QtQuick
import QtQuick.Layouts
import Quickshell
import "../Singletons"
import ".."

ColumnLayout {
  id: root

  required property var s
  required property string aboutNixosVersion
  required property string aboutKernelVersion
  required property string aboutHyprlandVersion
  required property string aboutUptimeStr

  Layout.fillWidth: true
  spacing: s(14)

  Text { 
    text: "SYSTEM"
    font.pixelSize: s(10)
    font.weight: Font.Bold
    font.family: "JetBrainsMono Nerd Font"
    color: MatugenColors.border 
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: s(14)

    // Left box: system info
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: sysInfoCol.implicitHeight + s(20)
      radius: s(Config.uiRadius)
      color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

      ColumnLayout {
        id: sysInfoCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: s(14)
        spacing: s(10)

        Repeater {
          model: [
            { icon: "󰌢", label: "Device Name", value: (typeof SystemStats !== "undefined" && SystemStats.hostname !== "") ? SystemStats.hostname : "Unknown" },
            { icon: "󰻠", label: "Processor", value: (typeof SystemStats !== "undefined" && SystemStats.cpuModel !== "") ? SystemStats.cpuModel + (SystemStats.cpuCores > 0 ? " (" + SystemStats.cpuCores + ")" : "") : "Unknown" },
            { icon: "󰢮", label: "Graphics", value: (typeof SystemStats !== "undefined" && SystemStats.gpuModel !== "") ? SystemStats.gpuModel : "Unknown" },
            { icon: "󰍛", label: "Memory", value: (typeof SystemStats !== "undefined" && SystemStats.totalRamGb > 0) ? SystemStats.totalRamGb + " GB" : "Unknown" },
            { icon: "󰋊", label: "Disk Capacity", value: (typeof SystemStats !== "undefined" && SystemStats.diskTotalGb > 0) ? SystemStats.diskUsedStr + " / " + SystemStats.diskTotalGb + " GB" : "Unknown" }
          ]
          RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: s(8)
            Text { text: modelData.icon; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent }
            Text { text: modelData.label; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textDim }
            Item { Layout.fillWidth: true }
            Text { text: modelData.value; font.pixelSize: s(12); font.weight: Font.DemiBold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text; elide: Text.ElideRight; Layout.maximumWidth: s(220) }
          }
        }
      }
    }

    // Right box: OS/about info
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: aboutSystemCol.implicitHeight + s(20)
      radius: s(Config.uiRadius)
      color: Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)

      ColumnLayout {
        id: aboutSystemCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: s(14)
        spacing: s(10)

        Repeater {
          model: [
            { icon: "\uf17c", label: "OS", value: (typeof SystemStats !== "undefined" && SystemStats.osName !== "") ? SystemStats.osName : "NixOS " + root.aboutNixosVersion },
            { icon: "\uf013", label: "Kernel Version", value: (typeof SystemStats !== "undefined" && SystemStats.kernelVersion !== "") ? SystemStats.kernelVersion : root.aboutKernelVersion },
            { icon: "\uf108", label: "Desktop", value: root.aboutHyprlandVersion !== "--" ? root.aboutHyprlandVersion : "Hyprland" },
            { icon: "\uf120", label: "Shell", value: (typeof SystemStats !== "undefined" && SystemStats.shellName !== "") ? SystemStats.shellName : "Unknown" },
            { icon: "\uf017", label: "Uptime", value: (typeof SystemStats !== "undefined" && SystemStats.uptime !== "") ? SystemStats.uptime : root.aboutUptimeStr }
          ]
          RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: s(8)
            Text { text: modelData.icon; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.accent }
            Text { text: modelData.label; font.pixelSize: s(12); font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.textDim }
            Item { Layout.fillWidth: true }
            Text { text: modelData.value; font.pixelSize: s(12); font.weight: Font.DemiBold; font.family: "JetBrainsMono Nerd Font"; color: MatugenColors.text; elide: Text.ElideRight; Layout.maximumWidth: s(220) }
          }
        }
      }
    }
  }
  // Credits
Rectangle {
  id: creditsBtn
  Layout.alignment: Qt.AlignHCenter
  Layout.preferredWidth: creditsRow.implicitWidth + s(32)
  Layout.preferredHeight: s(44)
  radius: s(Config.uiRadius)
  color: creditsMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(MatugenColors.bgElevated.r, MatugenColors.bgElevated.g, MatugenColors.bgElevated.b, 0.5)
  Behavior on color { ColorAnimation { duration: 150 } }

  RowLayout {
    id: creditsRow
    anchors.centerIn: parent
    spacing: s(8)

    Text {
      text: "\uf09b"
      font.pixelSize: s(16)
      font.family: "JetBrainsMono Nerd Font"
      color: MatugenColors.text
    }

    Text {
      text: "Ashvr0/NixOS-Config"
      font.pixelSize: s(13)
      font.weight: Font.DemiBold
      font.family: "JetBrainsMono Nerd Font"
      color: MatugenColors.text
    }
  }

  MouseArea {
    id: creditsMa
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/ashyrv0/NixOS-Config"])
  }
}
}
