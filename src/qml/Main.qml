import QtQuick
import QtQuick.Controls

ApplicationWindow {
    width: 1280
    height: 720
    minimumWidth: 640
    minimumHeight: 640
    visible: true
    color: "black"
    title: qsTr("ToyFoxx")

    Label {
        anchors.centerIn: parent
        color: "#808080"
        font.pixelSize: 16
        text: qsTr("Drop a media file here")
    }
}
