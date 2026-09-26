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
    visible: true
    color: "black"
    title: player.source.toString() === "" ? qsTr("ToyFoxx") : qsTr("%1 - ToyFoxx").arg(MediaSource.displayTitle(player.source))

    Component.onCompleted: openSource(initialSource)

    MediaPlayer {
        id: player

        autoPlay: true
        videoOutput: videoOutput
        audioOutput: AudioOutput {
            id: audioOutput
        }

        onErrorOccurred: (error, errorString) => console.warn("Media failed:", error, errorString)
    }

    VideoOutput {
        id: videoOutput

        anchors.fill: parent
    }

    Label {
        anchors.centerIn: parent
        visible: player.mediaStatus === MediaPlayer.NoMedia
        color: "#808080"
        font.pixelSize: 16
        text: qsTr("Drop a media file here")
    }

    MouseArea {
        anchors.fill: parent
        onDoubleClicked: root.toggleFullScreen()
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
        fullScreen: root.visibility === Window.FullScreen
        // Faded rather than hidden outright; visible drops only once the fade-out has finished,
        // so the invisible panel does not keep catching clicks.
        opacity: root.controlsShown ? 1 : 0
        visible: opacity > 0
        onOpenRequested: fileDialog.open()
        onFullScreenRequested: root.toggleFullScreen()

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
        videoOutput: videoOutput
        targetWindow: root
    }

    Shortcut {
        sequence: "F4"
        onActivated: diagnostics.visible = !diagnostics.visible
    }

    FileDialog {
        id: fileDialog

        title: qsTr("Open media")
        nameFilters: [qsTr("Video files (*.mp4 *.mkv *.webm *.mov *.avi *.wmv *.m4v *.ts *.m2ts *.flv)"), qsTr("All files (*)")]
        onAccepted: root.openSource(MediaSource.resolveUrl(selectedFile))
    }
}
