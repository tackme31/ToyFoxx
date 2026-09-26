import QtQuick
import QtQuick.Controls
import QtMultimedia

// Developer overlay (F4) for judging playback smoothness. Measurement stops while it is hidden.
Rectangle {
    id: diagnostics

    required property MediaPlayer player
    required property VideoOutput videoOutput
    required property Window targetWindow

    readonly property var statusNames: ["NoMedia", "Loading", "Loaded", "Stalled", "Buffering", "Buffered", "EndOfMedia", "Invalid"]
    readonly property var stateNames: ["Stopped", "Playing", "Paused"]
    // The initial buffering after opening is expected; only count stalls once playback has settled.
    property bool settled: false
    readonly property bool stalling: settled && player.playing && (player.mediaStatus === MediaPlayer.StalledMedia || player.mediaStatus === MediaPlayer.BufferingMedia)
    property int stallEvents: 0
    property int playingToggles: 0
    readonly property real frameRate: player.metaData.value(MediaMetaData.VideoFrameRate) ?? 0

    function resetCounters() {
        diagnostics.stallEvents = 0;
        diagnostics.playingToggles = 0;
        monitor.reset();
    }

    implicitWidth: column.implicitWidth + 20
    implicitHeight: column.implicitHeight + 16
    radius: 6
    color: Qt.rgba(0, 0, 0, 0.6)

    onStallingChanged: {
        if (diagnostics.stalling) {
            ++diagnostics.stallEvents;
            stallFlash.restart();
        }
    }

    PlaybackMonitor {
        id: monitor

        active: diagnostics.visible
        videoSink: diagnostics.videoOutput.videoSink
        window: diagnostics.targetWindow
        playing: diagnostics.player.playing
        // Frames reach the sink at the stream rate times the playback rate.
        expectedFps: diagnostics.frameRate * diagnostics.player.playbackRate

        onStatsChanged: {
            if (monitor.recentLateFrames > 0)
                lateFlash.restart();
        }
    }

    Connections {
        function onMediaStatusChanged() {
            if (diagnostics.player.mediaStatus === MediaPlayer.BufferedMedia)
                diagnostics.settled = true;
        }

        function onPlayingChanged() {
            ++diagnostics.playingToggles;
        }

        // Per-rate numbers are what matter, so start over whenever the rate changes.
        function onPlaybackRateChanged() {
            diagnostics.resetCounters();
        }

        function onSourceChanged() {
            diagnostics.settled = false;
            diagnostics.resetCounters();
        }

        target: diagnostics.player
    }

    // Stalls and late frames can be shorter than one overlay refresh, so latch them long enough to see.
    Timer {
        id: stallFlash

        interval: 1000
    }

    Timer {
        id: lateFlash

        interval: 1000
    }

    Column {
        id: column

        x: 10
        y: 8
        spacing: 2

        Row {
            spacing: 8

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: 7
                color: stallFlash.running ? "orange" : lateFlash.running ? "red" : diagnostics.player.playing ? "limegreen" : "gray"
            }

            Label {
                color: "white"
                text: diagnostics.stateNames[diagnostics.player.playbackState] + " / " + diagnostics.statusNames[diagnostics.player.mediaStatus]
            }
        }

        Label {
            color: "white"
            font.family: "Consolas"
            text: "Video: %1  %2x%3  %4 fps".arg(diagnostics.player.metaData.stringValue(MediaMetaData.VideoCodec)).arg(diagnostics.videoOutput.sourceRect.width).arg(diagnostics.videoOutput.sourceRect.height).arg(diagnostics.frameRate.toFixed(3))
        }

        Label {
            color: "white"
            font.family: "Consolas"
            text: "Rate: x%1  expected sink fps: %2".arg(diagnostics.player.playbackRate).arg(monitor.expectedFps.toFixed(1))
        }

        Label {
            color: "white"
            font.family: "Consolas"
            text: "Sink fps: %1   Present fps: %2".arg(monitor.sinkFps.toFixed(1)).arg(monitor.swapFps.toFixed(1))
        }

        Label {
            color: "white"
            font.family: "Consolas"
            text: "Max gap: %1 ms (worst %2 ms)".arg(monitor.maxSinkGapMs.toFixed(1)).arg(monitor.worstSinkGapMs.toFixed(1))
        }

        Label {
            color: monitor.totalLateFrames > 0 ? "#ff8080" : "white"
            font.family: "Consolas"
            text: "Late frames: %1 recent / %2 total".arg(monitor.recentLateFrames).arg(monitor.totalLateFrames)
        }

        Label {
            color: diagnostics.stallEvents > 0 ? "orange" : "white"
            font.family: "Consolas"
            text: "Stall events: %1   playing toggles: %2".arg(diagnostics.stallEvents).arg(diagnostics.playingToggles)
        }
    }
}
