import QtQuick
import QtQuick.Controls
import QtMultimedia

Slider {
    id: seekBar

    required property MediaPlayer player
    required property SegmentLoop segmentLoop

    // Only where a position means something: live streams have no duration to preview.
    readonly property bool previewAvailable: enabled && player.duration > 0

    // Inverse of markerX: the media position under an x coordinate, clamped to the range.
    function positionAt(x: real): real {
        const fraction = (x - leftPadding - handle.width / 2) / (availableWidth - handle.width);
        return from + Math.max(0, Math.min(1, fraction)) * (to - from);
    }

    // Centre of the handle at a given media position, so markers line up with it.
    function markerX(ms: real): real {
        return leftPadding + handle.width / 2 + (ms - from) / (to - from) * (availableWidth - handle.width) - 1;
    }

    from: 0
    // Live streams report a duration of 0; keep the range non-empty so the slider stays sane.
    to: Math.max(player.duration, 1)
    enabled: player.seekable && player.duration > 0
    focusPolicy: Qt.NoFocus

    // Setting position on every move gives a live seek while dragging; the Binding below stops
    // the playback position from fighting the handle until it is released.
    onMoved: player.position = value

    Binding {
        seekBar.value: seekBar.player.position
        when: !seekBar.pressed
        restoreMode: Binding.RestoreNone
    }

    Rectangle {
        x: seekBar.markerX(seekBar.segmentLoop.startMs)
        width: 2
        height: seekBar.height
        visible: seekBar.segmentLoop.hasStart
        color: "white"
    }

    Rectangle {
        x: seekBar.markerX(seekBar.segmentLoop.endMs)
        width: 2
        height: seekBar.height
        visible: seekBar.segmentLoop.active
        color: "white"
    }

    HoverHandler {
        id: hover

        onPointChanged: {
            if (hovered && seekBar.previewAvailable)
                preview.request(seekBar.positionAt(point.position.x));
        }
    }

    SeekBarPreview {
        id: preview

        x: Math.max(0, Math.min(seekBar.width - width, hover.point.position.x - width / 2))
        y: -height - 8
        visible: hover.hovered && seekBar.previewAvailable
        mainPlayer: seekBar.player
    }
}
