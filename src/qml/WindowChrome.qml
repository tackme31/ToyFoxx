import QtQuick
import QtQuick.Controls
import QtMultimedia

// Everything drawn over the video: caption bar, controller panel and toast, plus the logic that
// fades the caption and panel out (and hides the cursor) after 3 s without mouse activity.
// It fills the window so its HoverHandler is an ancestor of every control it has to keep track of.
Item {
    id: chrome

    required property ApplicationWindow targetWindow
    required property MediaPlayer player
    required property AudioOutput audioOutput
    required property SegmentLoop segmentLoop
    required property SegmentExporter segmentExporter
    property bool shown: true
    // True while auto-hiding would get in the user's way.
    readonly property bool busy: controllerPanel.busy || captionHover.hovered
    readonly property alias caption: caption
    readonly property alias controllerPanel: controllerPanel
    readonly property alias toast: toast

    signal fullScreenRequested

    function reveal() {
        shown = true;
        idleTimer.restart();
    }

    function hide() {
        if (!busy)
            shown = false;
    }

    // The idle timer may have fired, and been declined, while the controls were busy. Re-arm it,
    // or hide at once if the cursor already left the window across the panel or caption (the
    // window hover drops before theirs does).
    onBusyChanged: {
        if (busy)
            return;
        if (windowHover.hovered)
            idleTimer.restart();
        else
            hide();
    }

    // Qt Quick sees no hover over the caption, which Windows treats as non-client area.
    CaptionHoverTracker {
        id: captionHover

        window: chrome.targetWindow
        onMoved: chrome.reveal()
    }

    HoverHandler {
        id: windowHover

        // Where the cursor was when activity was last counted.
        property point lastActivePosition: Qt.point(-1, -1)

        cursorShape: chrome.shown ? Qt.ArrowCursor : Qt.BlankCursor
        // Only a real move counts. Qt Quick re-delivers synthetic hover events at the resting
        // cursor position whenever the scene changes, i.e. every frame during playback, and
        // point is also reset when the cursor leaves.
        onPointChanged: {
            const position = point.position;
            if (!hovered || (Math.abs(position.x - lastActivePosition.x) < 1 && Math.abs(position.y - lastActivePosition.y) < 1))
                return;
            lastActivePosition = position;
            chrome.reveal();
        }
        onHoveredChanged: {
            if (!hovered)
                chrome.hide();
        }
    }

    Timer {
        id: idleTimer

        interval: 3000
        running: true
        onTriggered: chrome.hide()
    }

    ControllerPanel {
        id: controllerPanel

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        player: chrome.player
        audioOutput: chrome.audioOutput
        segmentLoop: chrome.segmentLoop
        fullScreen: chrome.targetWindow.visibility === Window.FullScreen
        // Faded rather than hidden outright; visible drops only once the fade-out has finished,
        // so the invisible panel does not keep catching clicks.
        opacity: chrome.shown ? 1 : 0
        visible: opacity > 0
        onFullScreenRequested: chrome.fullScreenRequested()

        // Keyed on the Behavior's own target so the duration is settled before the animation
        // starts, whatever order the bindings on shown re-evaluate in.
        Behavior on opacity {
            id: panelFade

            NumberAnimation {
                duration: panelFade.targetValue > 0 ? 100 : 300
            }
        }
    }

    CaptionBar {
        id: caption

        targetWindow: chrome.targetWindow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        opacity: chrome.shown ? 1 : 0
        // Hidden in full screen, where there is no window to move or resize.
        visible: opacity > 0 && chrome.targetWindow.visibility !== Window.FullScreen

        Behavior on opacity {
            id: captionFade

            NumberAnimation {
                duration: captionFade.targetValue > 0 ? 100 : 300
            }
        }
    }

    Toast {
        id: toast

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 12
        // Above the panel's area whether or not the panel is showing, so it never jumps.
        anchors.bottomMargin: controllerPanel.height + 12 + (exportProgress.visible ? exportProgress.height + 8 : 0)
    }

    ExportProgress {
        id: exportProgress

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 12
        anchors.bottomMargin: controllerPanel.height + 12
        exporter: chrome.segmentExporter
    }
}
