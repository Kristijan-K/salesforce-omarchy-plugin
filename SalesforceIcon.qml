import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property bool warning: false

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    width: root.iconSize * 0.82
    height: root.iconSize * 0.48
    radius: height / 2
    color: root.color
  }

  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.iconSize * 0.18
    width: root.iconSize * 0.58
    height: root.iconSize * 0.58
    radius: width / 2
    color: root.color
  }

  Rectangle {
    anchors.left: parent.left
    anchors.leftMargin: root.iconSize * 0.08
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.iconSize * 0.08
    width: root.iconSize * 0.42
    height: root.iconSize * 0.42
    radius: width / 2
    color: root.color
  }

  Rectangle {
    anchors.right: parent.right
    anchors.rightMargin: root.iconSize * 0.08
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.iconSize * 0.08
    width: root.iconSize * 0.42
    height: root.iconSize * 0.42
    radius: width / 2
    color: root.color
  }

  Text {
    anchors.centerIn: parent
    text: "S"
    color: Color.background
    font.family: Style.font.family
    font.pixelSize: Math.max(6, root.iconSize * 0.42)
    font.bold: true
  }

  BorderSurface {
    visible: root.warning
    width: Math.max(7, root.iconSize * 0.42)
    height: width
    radius: width / 2
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    color: Color.urgent
    borderSpec: Border.flat(Color.popups.background, 1)

    Text {
      anchors.centerIn: parent
      text: "!"
      color: Color.background
      font.family: Style.font.family
      font.pixelSize: Math.max(6, parent.height * 0.72)
      font.bold: true
    }
  }
}
