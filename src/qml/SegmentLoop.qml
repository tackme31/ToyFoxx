import QtQuick
import QtMultimedia

// A-B segment loop state. advance() walks it through unset -> start set -> active -> unset.
QtObject {
    id: segmentLoop

    required property MediaPlayer player
    property real startMs: -1
    property real endMs: -1
    readonly property bool hasStart: startMs >= 0
    readonly property bool active: endMs >= 0

    // Resolution is bounded by the position notify rate; do not poll to tighten it.
    property Connections positionWatcher: Connections {
        target: segmentLoop.player
        enabled: segmentLoop.active

        function onPositionChanged() {
            const position = segmentLoop.player.position;
            if (position < segmentLoop.startMs || position > segmentLoop.endMs)
                segmentLoop.player.position = segmentLoop.startMs;
        }
    }

    property Connections sourceWatcher: Connections {
        target: segmentLoop.player

        function onSourceChanged() {
            segmentLoop.clear();
        }

        function onMediaStatusChanged() {
            // An end point at the very end of the media can be passed without a position notify.
            if (segmentLoop.active && segmentLoop.player.mediaStatus === MediaPlayer.EndOfMedia) {
                segmentLoop.player.position = segmentLoop.startMs;
                segmentLoop.player.play();
            }
        }
    }

    function advance() {
        const position = player.position;
        if (active)
            clear();
        else if (!hasStart)
            startMs = position;
        else if (startMs < position)
            endMs = position;
    }

    function clear() {
        startMs = -1;
        endMs = -1;
    }
}
