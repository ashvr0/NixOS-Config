import QtQuick
import ".."
import "../Singletons"

Item {
  id: root
  anchors.fill: parent

  property string imagePath: ""

  Rectangle {
    anchors.fill: parent
    radius: 18
    color: Qt.rgba(MatugenColors.bgBase.r, MatugenColors.bgBase.g, MatugenColors.bgBase.b, 0.6)
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1
    clip: true

    Image {
      anchors.fill: parent
      visible: root.imagePath !== ""
      source: root.imagePath !== "" ? "file://" + root.imagePath : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
    }

    Column {
      anchors.centerIn: parent
      spacing: 8
      visible: root.imagePath === ""

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "\uf03e"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: Math.min(root.width, root.height) * 0.22
        color: MatugenColors.textDim
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "No image selected"
        font.family: Config.fontFamily
        font.pixelSize: Math.min(root.width, root.height) * 0.06
        color: MatugenColors.textDim
      }
    }
  }
}
