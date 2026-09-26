import QtQuick
import QtQuick.Controls

// The window caption, drawn over the video instead of by Windows. FramelessWindow registers it
// as the title bar, so Windows still treats it as a real caption: drag to move, double click to
// maximize and the system menu are handled by the OS, not here.
Rectangle {
    id: caption

    required property ApplicationWindow targetWindow
    readonly property alias minimizeButton: minimizeButton
    readonly property alias maximizeButton: maximizeButton
    readonly property alias closeButton: closeButton

    implicitHeight: 32
    color: Qt.alpha(palette.window, 0.8)

    Label {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: systemButtons.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: caption.targetWindow.title
    }

    Row {
        id: systemButtons

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        CaptionButton {
            id: minimizeButton

            text: "\uE921"
            onClicked: caption.targetWindow.showMinimized()
        }

        CaptionButton {
            id: maximizeButton

            readonly property bool maximized: caption.targetWindow.visibility === Window.Maximized

            text: maximized ? "\uE923" : "\uE922"
            onClicked: maximized ? caption.targetWindow.showNormal() : caption.targetWindow.showMaximized()
        }

        CaptionButton {
            id: closeButton

            background: Rectangle {
                color: closeButton.pressed ? "#94c42b1c" : closeButton.hovered ? "#c42b1c" : "transparent"
            }
            contentItem: Label {
                color: closeButton.hovered ? "white" : closeButton.palette.buttonText
                font: closeButton.font
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: closeButton.text
            }
            text: "\uE8BB"
            onClicked: caption.targetWindow.close()
        }
    }

    component CaptionButton: ToolButton {
        implicitWidth: 46
        // Matches the caption's implicitHeight; an inline component cannot see the caption id.
        implicitHeight: 32
        focusPolicy: Qt.NoFocus
        font.family: "Segoe Fluent Icons"
        font.pixelSize: 10
    }
}
