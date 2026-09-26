import QtQuick
import QtQuick.Controls
import QtMultimedia

Slider {
    id: seekBar

    required property MediaPlayer player
    required property SegmentLoop segmentLoop

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
}
