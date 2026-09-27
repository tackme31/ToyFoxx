import QtQuick
import QtQuick.Controls
import QtMultimedia

// Mute toggle whose hover pops a vertical volume slider above it, as on YouTube. The slider
// closes 300 ms after the cursor has left both the button and the popup, which also bridges the
// gap between them.
IconButton {
    id: volumeButton

    required property AudioOutput audioOutput
    readonly property bool popupOpen: volumePopup.visible

    checkable: true
    checked: audioOutput.muted
    label: qsTr("Mute")
    text: checked ? "" : ""

    onToggled: audioOutput.muted = checked
    onHoveredChanged: {
        if (hovered) {
            closeTimer.stop();
            volumePopup.open();
        } else {
            closeTimer.restart();
        }
    }

    Timer {
        id: closeTimer

        interval: 300
        onTriggered: {
            if (!volumeButton.hovered && !popupHover.hovered)
                volumePopup.close();
        }
    }

    Popup {
        id: volumePopup

        x: (volumeButton.width - width) / 2
        y: -height - 4
        width: implicitContentWidth + leftPadding + rightPadding
        height: implicitContentHeight + topPadding + bottomPadding
        // Each side separately: the FluentWinUI3 Popup sets the per-side paddings from its style
        // config, and those take precedence over the plain padding property.
        leftPadding: 4
        rightPadding: 4
        topPadding: 4
        bottomPadding: 4
        // The FluentWinUI3 background is a 320x72 nine-patch image with shadow margins, drawn past
        // the popup through negative insets; it cannot shrink to a popup this narrow.
        topInset: 0
        bottomInset: 0
        leftInset: 0
        rightInset: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        background: Rectangle {
            radius: 4
            color: volumePopup.palette.window
            border.color: volumePopup.palette.mid
        }

        Item {
            implicitWidth: 26
            implicitHeight: 96

            HoverHandler {
                id: popupHover

                onHoveredChanged: {
                    if (hovered)
                        closeTimer.stop();
                    else
                        closeTimer.restart();
                }
            }

            // AudioOutput.volume is a linear gain, which crowds the audible change into the
            // bottom of a linear slider. The slider moves the cube root instead (about -18 dB at
            // half travel), the curve PulseAudio and mpv use; the stored volume stays linear.
            Slider {
                id: volumeSlider

                anchors.fill: parent
                orientation: Qt.Vertical
                from: 0
                to: 1
                value: Math.cbrt(volumeButton.audioOutput.volume)
                enabled: !volumeButton.audioOutput.muted
                focusPolicy: Qt.NoFocus
                onMoved: volumeButton.audioOutput.volume = value * value * value
            }
        }
    }
}
