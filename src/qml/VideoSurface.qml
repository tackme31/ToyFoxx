import QtQuick
import QtMultimedia

// Zoom, pan and rotation are scene-graph transforms on the VideoOutput item; the frame itself
// is never rescaled. clip is a scissor, not an offscreen layer.
Item {
    id: surface

    property real zoom: 1
    property real panX: 0
    property real panY: 0
    property int videoRotation: 0
    readonly property alias videoOutput: videoOutput
    // At 90 and 270 degrees the fitted frame lies on its side; this refits it to the item, so
    // zoom 1 always means "fits the window". ToyBoxx let the rotated frame overflow instead.
    readonly property real rotationFit: {
        const shown = videoOutput.contentRect;
        if (videoRotation % 180 === 0 || shown.width <= 0 || shown.height <= 0)
            return 1;
        return Math.min(width / shown.height, height / shown.width);
    }

    signal doubleClicked

    function setZoom(value: real) {
        zoom = Math.max(0.1, value);
        if (zoom < 1) {
            panX = 0;
            panY = 0;
        }
    }

    function rotateClockwise() {
        videoRotation = (videoRotation + 90) % 360;
    }

    // The frame is fitted into the item, so 1:1 is the inverse of that fit, in device pixels.
    function showOriginalSize() {
        const shownWidth = videoOutput.contentRect.width * rotationFit * Screen.devicePixelRatio;
        if (shownWidth > 0 && videoOutput.sourceRect.width > 0)
            setZoom(videoOutput.sourceRect.width / shownWidth);
    }

    function reset() {
        zoom = 1;
        panX = 0;
        panY = 0;
        videoRotation = 0;
    }

    clip: true

    VideoOutput {
        id: videoOutput

        x: surface.panX
        y: surface.panY
        width: surface.width
        height: surface.height
        scale: surface.zoom * surface.rotationFit
        rotation: surface.videoRotation
    }

    TapHandler {
        onDoubleTapped: surface.doubleClicked()
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: surface.reset()
    }

    DragHandler {
        property point startPan

        target: null
        enabled: surface.zoom > 1
        acceptedButtons: Qt.LeftButton
        onActiveChanged: {
            if (active)
                startPan = Qt.point(surface.panX, surface.panY);
        }
        onActiveTranslationChanged: {
            if (!active)
                return;
            surface.panX = startPan.x + activeTranslation.x;
            surface.panY = startPan.y + activeTranslation.y;
        }
    }

    WheelHandler {
        target: null
        acceptedModifiers: Qt.ControlModifier
        // 0.1 per wheel notch; high-resolution wheels and touchpads send fractions of a notch.
        onWheel: event => surface.setZoom(surface.zoom + event.angleDelta.y / 120 * 0.1)
    }
}
