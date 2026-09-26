import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
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
    visible: true
    color: "black"
    title: qsTr("ToyFoxx")

    Component.onCompleted: openSource(initialSource)

    MediaPlayer {
        id: player

        autoPlay: true
        videoOutput: videoOutput
        audioOutput: AudioOutput {}

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

    ControllerPanel {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        player: player
        fullScreen: root.visibility === Window.FullScreen
        onOpenRequested: fileDialog.open()
        onFullScreenRequested: root.toggleFullScreen()
    }

    PlaybackDiagnostics {
        id: diagnostics

        x: 12
        y: 12
        player: player
        videoOutput: videoOutput
        targetWindow: root
    }

    Shortcut {
        sequence: "F12"
        onActivated: diagnostics.visible = !diagnostics.visible
    }

    FileDialog {
        id: fileDialog

        title: qsTr("Open media")
        nameFilters: [qsTr("Video files (*.mp4 *.mkv *.webm *.mov *.avi *.wmv *.m4v *.ts *.m2ts *.flv)"), qsTr("All files (*)")]
        onAccepted: root.openSource(MediaSource.resolveUrl(selectedFile))
    }
}
