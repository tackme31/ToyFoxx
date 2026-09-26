import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtMultimedia

ApplicationWindow {
    id: root

    property url initialSource
    property int visibilityBeforeFullScreen: Window.Windowed
    property bool controlsShown: true
    // True while auto-hiding would get in the user's way.
    readonly property bool controlsBusy: controllerPanel.busy || captionHover.hovered

    function openSource(source: url) {
        if (source.toString() === "")
            return;
        player.source = source;
    }

    function revealControls() {
        root.controlsShown = true;
        idleTimer.restart();
    }

    function hideControls() {
        if (!root.controlsBusy)
            root.controlsShown = false;
    }

    function toggleFullScreen() {
        if (root.visibility === Window.FullScreen) {
            root.visibility = root.visibilityBeforeFullScreen;
        } else {
            root.visibilityBeforeFullScreen = root.visibility;
            root.visibility = Window.FullScreen;
        }
    }

    width: 1280
    height: 720
    minimumWidth: 640
    minimumHeight: 640
    color: "black"
    title: player.source.toString() === "" ? qsTr("ToyFoxx") : qsTr("%1 - ToyFoxx").arg(MediaSource.displayTitle(player.source))

    // Shown only after the saved geometry is applied, so the window does not jump on startup.
    Component.onCompleted: {
        frameless.attach(root, caption, caption.minimizeButton, caption.maximizeButton, caption.closeButton);
        windowGeometry.restore();
        // Showing the now frameless window hands the native caption to the client area,
        // synchronously with this assignment, which moves the client rect up by the caption
        // height. Put the restored geometry straight back, or it drifts on every launch.
        const restored = Qt.rect(root.x, root.y, root.width, root.height);
        root.visible = true;
        root.x = restored.x;
        root.y = restored.y;
        root.width = restored.width;
        root.height = restored.height;
        openSource(initialSource);
    }
    // The idle timer may have fired, and been declined, while the controls were busy. Re-arm it,
    // or hide at once if the cursor already left the window across the panel or caption (the
    // window hover drops before theirs does).
    onControlsBusyChanged: {
        if (controlsBusy)
            return;
        if (windowHover.hovered)
            idleTimer.restart();
        else
            hideControls();
    }

    FramelessWindow {
        id: frameless
    }

    CaptionHoverTracker {
        id: captionHover

        window: root
        onMoved: root.revealControls()
    }

    MediaPlayer {
        id: player

        autoPlay: true
        // Initial value only; the panel's toggle assigns loops directly afterwards.
        loops: playbackSettings.loop ? MediaPlayer.Infinite : 1
        videoOutput: videoSurface.videoOutput
        audioOutput: AudioOutput {
            id: audioOutput
        }

        onLoopsChanged: playbackSettings.loop = loops === MediaPlayer.Infinite
        onErrorOccurred: (error, errorString) => console.warn("Media failed:", error, errorString)
    }

    // Written on every change rather than on exit, so with several instances running the
    // last change made in any of them wins.
    Settings {
        id: playbackSettings

        property bool loop: false
        property alias volume: audioOutput.volume
        property alias muted: audioOutput.muted

        category: "Playback"
    }

    WindowGeometry {
        id: windowGeometry

        window: root
    }

    SegmentLoop {
        id: segmentLoop

        player: player
    }

    ScreenshotSaver {
        id: screenshotSaver

        onSaved: filePath => toast.show(qsTr("Screenshot saved"), filePath, () => ShellIntegration.revealInExplorer(filePath))
        onFailed: message => toast.show(qsTr("Screenshot failed"), message, null)
    }

    VideoSurface {
        id: videoSurface

        anchors.fill: parent
        onDoubleClicked: root.toggleFullScreen()
    }

    Label {
        anchors.centerIn: parent
        visible: player.mediaStatus === MediaPlayer.NoMedia
        color: "#808080"
        font.pixelSize: 16
        text: qsTr("Drop a media file here")
    }

    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: drop => {
            if (drop.urls.length > 0)
                root.openSource(MediaSource.resolveUrl(drop.urls[0]));
        }
    }

    // Declared on the content item, so it stays hovered over the panel's buttons too.
    HoverHandler {
        id: windowHover

        // Where the cursor was when activity was last counted.
        property point lastActivePosition: Qt.point(-1, -1)

        cursorShape: root.controlsShown ? Qt.ArrowCursor : Qt.BlankCursor
        // Only a real move counts. Qt Quick re-delivers synthetic hover events at the resting
        // cursor position whenever the scene changes, i.e. every frame during playback, and
        // point is also reset when the cursor leaves.
        onPointChanged: {
            const position = point.position;
            if (!hovered || (Math.abs(position.x - lastActivePosition.x) < 1 && Math.abs(position.y - lastActivePosition.y) < 1))
                return;
            lastActivePosition = position;
            root.revealControls();
        }
        onHoveredChanged: {
            if (!hovered)
                root.hideControls();
        }
    }

    Timer {
        id: idleTimer

        interval: 3000
        running: true
        onTriggered: root.hideControls()
    }

    ControllerPanel {
        id: controllerPanel

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        player: player
        audioOutput: audioOutput
        segmentLoop: segmentLoop
        fullScreen: root.visibility === Window.FullScreen
        // Faded rather than hidden outright; visible drops only once the fade-out has finished,
        // so the invisible panel does not keep catching clicks.
        opacity: root.controlsShown ? 1 : 0
        visible: opacity > 0
        onOpenRequested: fileDialog.open()
        onFullScreenRequested: root.toggleFullScreen()

        // Keyed on the Behavior's own target so the duration is settled before the animation
        // starts, whatever order the bindings on controlsShown re-evaluate in.
        Behavior on opacity {
            id: panelFade

            NumberAnimation {
                duration: panelFade.targetValue > 0 ? 100 : 300
            }
        }
    }

    CaptionBar {
        id: caption

        targetWindow: root
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        opacity: root.controlsShown ? 1 : 0
        // Hidden in full screen, where there is no window to move or resize.
        visible: opacity > 0 && root.visibility !== Window.FullScreen

        Behavior on opacity {
            id: captionFade

            NumberAnimation {
                duration: captionFade.targetValue > 0 ? 100 : 300
            }
        }
    }

    PlaybackDiagnostics {
        id: diagnostics

        x: 12
        y: caption.height + 12
        visible: false
        player: player
        videoOutput: videoSurface.videoOutput
        targetWindow: root
    }

    Toast {
        id: toast

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 12
        // Above the panel's area whether or not the panel is showing, so it never jumps.
        anchors.bottomMargin: controllerPanel.height + 12
    }

    KeyboardShortcuts {
        player: player
        controllerPanel: controllerPanel
        videoSurface: videoSurface
        diagnostics: diagnostics
        onScreenshotRequested: screenshotSaver.save(videoSurface.videoOutput.videoSink, MediaSource.displayTitle(player.source))
    }

    FileDialog {
        id: fileDialog

        title: qsTr("Open media")
        nameFilters: [qsTr("Video files (*.mp4 *.mkv *.webm *.mov *.avi *.wmv *.m4v *.ts *.m2ts *.flv)"), qsTr("All files (*)")]
        onAccepted: root.openSource(MediaSource.resolveUrl(selectedFile))
    }
}
