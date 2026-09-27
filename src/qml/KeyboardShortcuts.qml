import QtQuick
import QtMultimedia

// Window-wide shortcuts, so they work wherever keyboard focus happens to be.
Item {
    id: shortcuts

    required property MediaPlayer player
    required property ControllerPanel controllerPanel
    required property VideoSurface videoSurface
    required property Item diagnostics

    signal screenshotRequested
    signal segmentExportRequested

    function seekBy(deltaMs: int) {
        if (controllerPanel.isOpen && player.seekable)
            player.position = Math.max(0, Math.min(player.duration, player.position + deltaMs));
    }

    Shortcut {
        sequence: "Space"
        enabled: shortcuts.controllerPanel.isOpen
        onActivated: shortcuts.player.playing ? shortcuts.player.pause() : shortcuts.controllerPanel.play()
    }

    Shortcut {
        sequence: "Left"
        onActivated: shortcuts.seekBy(-5000)
    }

    Shortcut {
        sequence: "Right"
        onActivated: shortcuts.seekBy(5000)
    }

    Shortcut {
        sequence: "R"
        enabled: shortcuts.controllerPanel.isOpen
        onActivated: shortcuts.videoSurface.rotateClockwise()
    }

    Shortcut {
        sequence: "F"
        enabled: shortcuts.controllerPanel.isOpen && shortcuts.player.hasVideo
        onActivated: shortcuts.videoSurface.showOriginalSize()
    }

    Shortcut {
        sequence: "S"
        enabled: shortcuts.controllerPanel.isOpen && shortcuts.player.hasVideo
        onActivated: shortcuts.screenshotRequested()
    }

    Shortcut {
        sequence: "T"
        enabled: shortcuts.controllerPanel.isOpen && shortcuts.player.hasVideo
        onActivated: shortcuts.segmentExportRequested()
    }

    Shortcut {
        sequence: "F4"
        onActivated: shortcuts.diagnostics.visible = !shortcuts.diagnostics.visible
    }
}
