import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import "TimeFormat.js" as TimeFormat

Rectangle {
    id: panel

    required property MediaPlayer player
    required property AudioOutput audioOutput
    required property SegmentLoop segmentLoop
    property bool fullScreen: false

    // True while auto-hiding the panel would get in the user's way.
    readonly property bool busy: panelHover.hovered || speedButton.popupOpen || volumeControl.popupOpen
    readonly property bool isOpen: player.mediaStatus >= MediaPlayer.LoadedMedia
                                   && player.mediaStatus !== MediaPlayer.InvalidMedia
    // Whole seconds, so the label re-formats once per second rather than on every position notify.
    readonly property int positionSeconds: Math.floor(player.position / 1000)
    readonly property int durationSeconds: Math.floor(player.duration / 1000)
    readonly property real frameRate: player.metaData.value(MediaMetaData.VideoFrameRate) || 30

    signal fullScreenRequested

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

            IconButton {
                visible: !panel.player.playing
                enabled: panel.isOpen
                label: qsTr("Play")
                text: "\uE768"
                onClicked: panel.play()
            }

            IconButton {
                visible: panel.player.playing
                enabled: panel.isOpen
                label: qsTr("Pause")
                text: "\uE769"
                onClicked: panel.player.pause()
            }

            IconButton {
                enabled: panel.isOpen
                label: qsTr("Stop")
                text: "\uE71A"
                onClicked: panel.player.stop()
            }

            IconButton {
                enabled: panel.isOpen && panel.player.seekable
                         && panel.player.mediaStatus !== MediaPlayer.EndOfMedia
                autoRepeat: true
                label: qsTr("Next frame")
                text: "\uEBE7"
                onClicked: panel.stepFrame()
            }

            SpeedButton {
                id: speedButton

                enabled: panel.isOpen
                player: panel.player
            }

            VolumeControl {
                id: volumeControl

                audioOutput: panel.audioOutput
            }

            Item {
                Layout.fillWidth: true
            }

            Label {
                text: TimeFormat.hms(panel.positionSeconds) + " / " + TimeFormat.hms(panel.durationSeconds)
            }

            IconButton {
                checkable: true
                checked: panel.player.loops === MediaPlayer.Infinite
                label: qsTr("Loop")
                text: "\uE8EE"
                onToggled: panel.player.loops = checked ? MediaPlayer.Infinite : 1
            }

            // No glyph says "A-B", so this one stays text; "A-" shows the start is set.
            Button {
                flat: true
                enabled: panel.isOpen
                checked: panel.segmentLoop.active
                focusPolicy: Qt.NoFocus
                text: panel.segmentLoop.hasStart && !panel.segmentLoop.active ? "A-" : "A-B"
                Accessible.name: qsTr("A-B loop")
                ToolTip.visible: hovered
                ToolTip.delay: 600
                ToolTip.text: qsTr("A-B loop")
                onClicked: panel.segmentLoop.advance()
            }

            IconButton {
                label: panel.fullScreen ? qsTr("Exit full screen") : qsTr("Full screen")
                text: panel.fullScreen ? "\uE73F" : "\uE740"
                onClicked: panel.fullScreenRequested()
            }
        }
    }
}
