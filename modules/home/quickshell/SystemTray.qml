import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Item {
  id: root
  implicitWidth: pillBg.width
  implicitHeight: pillBg.height
  property int cascadeIndex: 4
  property bool entered: false
  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }
  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutBack } } }
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
  visible: pillBg.width > 0

  Rectangle {
    id: pillBg
    height: 50
    width: SystemTray.items.values.length > 0 ? trayRow.implicitWidth + 20 : 0
    radius: 14
    color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.75)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    anchors.verticalCenter: parent.verticalCenter
    clip: true

    Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

    Row {
      id: trayRow
      anchors.centerIn: parent
      spacing: 12

      Repeater {
        model: SystemTray.items.values

        Item {
          id: trayIcon
          width: 20; height: 20
          anchors.verticalCenter: parent.verticalCenter

          required property var modelData

          property bool isHovered: trayMouse.containsMouse
          scale: isHovered ? 1.18 : 1.0
          Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

          Image {
            anchors.fill: parent
            source: trayIcon.modelData.icon || ""
            fillMode: Image.PreserveAspectFit
            sourceSize: Qt.size(20, 20)
          }

          QsMenuAnchor {
            id: menuAnchor
            anchor.item: trayIcon
            menu: trayIcon.modelData.menu
          }

          MouseArea {
            id: trayMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: (mouse) => {
              if (mouse.button === Qt.LeftButton) {
                if (trayIcon.modelData.onlyMenu) {
                  menuAnchor.open()
                } else if (typeof trayIcon.modelData.activate === "function") {
                  trayIcon.modelData.activate()
                }
              } else if (mouse.button === Qt.MiddleButton) {
                if (typeof trayIcon.modelData.secondaryActivate === "function") {
                  trayIcon.modelData.secondaryActivate()
                }
              } else if (mouse.button === Qt.RightButton) {
                if (trayIcon.modelData.menu) {
                  menuAnchor.open()
                }
              }
            }
          }
        }
      }
    }
  }
}
