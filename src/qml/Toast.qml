import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A transient notification in the video window, the counterpart of ToyBoxx's Snackbar.
Rectangle {
    id: toast

    property string title
    property string message
    property var clickAction: null
    property bool shown: false

    function show(title: string, message: string, clickAction: var) {
        toast.title = title;
        toast.message = message;
        toast.clickAction = clickAction ?? null;
        toast.shown = true;
        hideTimer.restart();
    }

    width: 500
    implicitHeight: content.implicitHeight + 24
    radius: 6
    color: palette.window
    border.color: palette.mid
    opacity: shown ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: 150
        }
    }

    Timer {
        id: hideTimer

        interval: 3000
        onTriggered: toast.shown = false
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        cursorShape: toast.clickAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton && toast.clickAction)
                toast.clickAction();
            toast.shown = false;
        }
    }

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: 4

        Label {
            Layout.fillWidth: true
            font.bold: true
            elide: Text.ElideRight
            text: toast.title
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 3
            elide: Text.ElideRight
            text: toast.message
        }
    }
}
