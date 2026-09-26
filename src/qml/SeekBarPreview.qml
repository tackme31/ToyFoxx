import QtQuick
import QtQuick.Controls
import QtMultimedia
import "TimeFormat.js" as TimeFormat

// Seek-bar thumbnail. A second, silent MediaPlayer stays paused and renders straight into a
// small VideoOutput, so the frame never leaves the GPU and is scaled down by the scene graph.
// It opens lazily on the first request, so a stream is not fetched twice unless the preview
// is actually used, and it seeks only after the pointer rests for 250 ms.
Rectangle {
    id: preview

    required property MediaPlayer mainPlayer
    property real positionMs: 0
    property real pendingMs: -1

    function request(ms: real) {
        positionMs = ms;
        debounce.restart();
    }

    function seekToRequested() {
        const source = mainPlayer.source.toString();
        if (source === "")
            return;
        if (previewPlayer.source.toString() !== source)
            previewPlayer.source = source;
        pendingMs = positionMs;
        applyPending();
    }

    function applyPending() {
        const status = previewPlayer.mediaStatus;
        if (pendingMs < 0 || status === MediaPlayer.NoMedia || status === MediaPlayer.LoadingMedia
                || status === MediaPlayer.InvalidMedia)
            return;
        // Paused rather than stopped: a paused player renders the frame at each new position.
        if (previewPlayer.playbackState !== MediaPlayer.PausedState)
            previewPlayer.pause();
        previewPlayer.position = pendingMs;
        pendingMs = -1;
    }

    width: 160
    height: 130
    radius: 5
    color: palette.window
    border.color: palette.mid
    border.width: 1

    MediaPlayer {
        id: previewPlayer

        videoOutput: previewOutput
        activeAudioTrack: -1
        activeSubtitleTrack: -1

        onMediaStatusChanged: preview.applyPending()
        // Preview failures are ignored, as in ToyBoxx; the main player reports its own errors.
    }

    Connections {
        target: preview.mainPlayer

        function onSourceChanged() {
            previewPlayer.source = "";
            preview.pendingMs = -1;
        }
    }

    Timer {
        id: debounce

        interval: 250
        onTriggered: preview.seekToRequested()
    }

    VideoOutput {
        id: previewOutput

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: timeLabel.top
        anchors.margins: 4
    }

    Label {
        id: timeLabel

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        text: TimeFormat.hms(Math.floor(preview.positionMs / 1000))
    }
}
