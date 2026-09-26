import QtCore
import QtQuick
import QtQuick.Controls
import QtMultimedia

ApplicationWindow {
    id: root

    property url initialSource
    property int visibilityBeforeFullScreen: Window.Windowed

    function openSource(source: url) {
        if (source.toString() === "")
            return;
        player.source = source;
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
        const caption = chrome.caption;
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

    FramelessWindow {
        id: frameless
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

        onSaved: filePath => chrome.toast.show(qsTr("Screenshot saved"), filePath, () => ShellIntegration.revealInExplorer(filePath))
        onFailed: message => chrome.toast.show(qsTr("Screenshot failed"), message, null)
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

    WindowChrome {
        id: chrome

        anchors.fill: parent
        targetWindow: root
        player: player
        audioOutput: audioOutput
        segmentLoop: segmentLoop
        onFullScreenRequested: root.toggleFullScreen()
    }

    PlaybackDiagnostics {
        id: diagnostics

        x: 12
        y: chrome.caption.height + 12
        visible: false
        player: player
        videoOutput: videoSurface.videoOutput
        targetWindow: root
    }

    KeyboardShortcuts {
        player: player
        controllerPanel: chrome.controllerPanel
        videoSurface: videoSurface
        diagnostics: diagnostics
        onScreenshotRequested: screenshotSaver.save(videoSurface.videoOutput.videoSink, MediaSource.displayTitle(player.source))
    }
}
