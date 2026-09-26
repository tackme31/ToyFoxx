import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Rectangle {
    id: panel

    required property MediaPlayer player
    required property AudioOutput audioOutput
    property bool fullScreen: false

    readonly property bool isOpen: player.mediaStatus >= MediaPlayer.LoadedMedia
                                   && player.mediaStatus !== MediaPlayer.InvalidMedia
    // Whole seconds, so the label re-formats once per second rather than on every position notify.
    readonly property int positionSeconds: Math.floor(player.position / 1000)
    readonly property int durationSeconds: Math.floor(player.duration / 1000)

    signal openRequested
    signal fullScreenRequested

    function formatTime(totalSeconds: int): string {
        const pad = n => n.toString().padStart(2, "0");
        return pad(Math.floor(totalSeconds / 3600)) + ":" + pad(Math.floor(totalSeconds / 60) % 60) + ":" + pad(totalSeconds % 60);
    }

    function play() {
        if (player.mediaStatus === MediaPlayer.EndOfMedia)
            player.position = 0;
        player.play();
    }

    implicitHeight: 120
    color: Qt.alpha(palette.window, 0.8)

    // Swallows clicks on the panel background so a double click here does not toggle full screen.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 0

        SeekBar {
            Layout.fillWidth: true
            Layout.topMargin: 10
            Layout.preferredHeight: 20
            player: panel.player
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 70

            Button {
                focusPolicy: Qt.NoFocus
                text: qsTr("Open")
                onClicked: panel.openRequested()
            }

            Button {
                visible: !panel.player.playing
                enabled: panel.isOpen
                focusPolicy: Qt.NoFocus
                text: qsTr("Play")
                onClicked: panel.play()
            }

            Button {
                visible: panel.player.playing
                enabled: panel.isOpen
                focusPolicy: Qt.NoFocus
                text: qsTr("Pause")
                onClicked: panel.player.pause()
            }

            Button {
                enabled: panel.isOpen
                focusPolicy: Qt.NoFocus
                text: qsTr("Stop")
                onClicked: panel.player.stop()
            }

            SpeedButton {
                enabled: panel.isOpen
                player: panel.player
            }

            VolumeControl {
                audioOutput: panel.audioOutput
            }

            Item {
                Layout.fillWidth: true
            }

            Label {
                text: panel.formatTime(panel.positionSeconds) + " / " + panel.formatTime(panel.durationSeconds)
            }

            Button {
                focusPolicy: Qt.NoFocus
                text: panel.fullScreen ? qsTr("Exit full screen") : qsTr("Full screen")
                onClicked: panel.fullScreenRequested()
            }
        }
    }
}
