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
        if (!controllerPanel.busy)
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
        windowGeometry.restore();
        root.visible = true;
        openSource(initialSource);
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

        cursorShape: root.controlsShown ? Qt.ArrowCursor : Qt.BlankCursor
        // point is also reset when the cursor leaves; that must not count as activity.
        onPointChanged: {
            if (hovered)
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
        // The idle timer may have fired, and been declined, while the panel was busy. Re-arm it,
        // or hide at once if the cursor already left the window across the panel (the window
        // hover drops before the panel's does).
        onBusyChanged: {
            if (busy)
                return;
            if (windowHover.hovered)
                idleTimer.restart();
            else
                root.hideControls();
        }

        Behavior on opacity {
            NumberAnimation {
                duration: root.controlsShown ? 100 : 300
            }
        }
    }

    PlaybackDiagnostics {
        id: diagnostics

        x: 12
        y: 12
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
