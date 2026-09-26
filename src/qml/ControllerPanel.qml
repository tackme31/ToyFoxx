import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Rectangle {
    id: panel

    required property MediaPlayer player
    required property AudioOutput audioOutput
    required property SegmentLoop segmentLoop
    property bool fullScreen: false

    // True while auto-hiding the panel would get in the user's way.
    readonly property bool busy: panelHover.hovered || speedButton.popupOpen
    readonly property bool isOpen: player.mediaStatus >= MediaPlayer.LoadedMedia
                                   && player.mediaStatus !== MediaPlayer.InvalidMedia
    // Whole seconds, so the label re-formats once per second rather than on every position notify.
    readonly property int positionSeconds: Math.floor(player.position / 1000)
    readonly property int durationSeconds: Math.floor(player.duration / 1000)
    readonly property real frameRate: player.metaData.value(MediaMetaData.VideoFrameRate) || 30

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

    // Qt Multimedia has no frame-step API. This seeks by one nominal frame interval, so the
    // result is bounded by seek granularity and may land on the same or the next-but-one frame.
    function stepFrame() {
        player.pause();
        player.position = Math.min(player.duration, player.position + 1000 / frameRate);
    }

    implicitHeight: 120
    color: Qt.alpha(palette.window, 0.8)

    // Swallows clicks on the panel background so a double click here does not toggle full screen.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    HoverHandler {
        id: panelHover
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
            segmentLoop: panel.segmentLoop
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

            Button {
                enabled: panel.isOpen && panel.player.seekable
                         && panel.player.mediaStatus !== MediaPlayer.EndOfMedia
                autoRepeat: true
                focusPolicy: Qt.NoFocus
                text: qsTr("Next frame")
                onClicked: panel.stepFrame()
            }

            SpeedButton {
                id: speedButton

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
                checkable: true
                checked: panel.player.loops === MediaPlayer.Infinite
                focusPolicy: Qt.NoFocus
                text: qsTr("Loop")
                onToggled: panel.player.loops = checked ? MediaPlayer.Infinite : 1
            }

            Button {
                enabled: panel.isOpen
                checked: panel.segmentLoop.active
                focusPolicy: Qt.NoFocus
                text: panel.segmentLoop.hasStart && !panel.segmentLoop.active ? qsTr("A-B (A set)") : qsTr("A-B")
                onClicked: panel.segmentLoop.advance()
            }

            Button {
                focusPolicy: Qt.NoFocus
                text: panel.fullScreen ? qsTr("Exit full screen") : qsTr("Full screen")
                onClicked: panel.fullScreenRequested()
            }
        }
    }
}
