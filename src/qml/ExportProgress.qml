import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Shown while a segment export runs, with a way to cancel it.
Rectangle {
    id: progressBox

    required property SegmentExporter exporter

    width: 500
    implicitHeight: content.implicitHeight + 24
    radius: 6
    color: palette.window
    border.color: palette.mid
    visible: exporter.busy

    // Keeps clicks from reaching the video underneath.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    RowLayout {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                Layout.fillWidth: true
                font.bold: true
                elide: Text.ElideRight
                text: qsTr("Exporting the A-B segment... %1%").arg(Math.floor(progressBox.exporter.progress * 100))
            }

            ProgressBar {
                Layout.fillWidth: true
                value: progressBox.exporter.progress
            }
        }

        IconButton {
            label: qsTr("Cancel export")
            text: ""
            onClicked: progressBox.exporter.cancel()
        }
    }
}
