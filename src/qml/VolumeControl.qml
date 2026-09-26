import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

RowLayout {
    id: volumeControl

    required property AudioOutput audioOutput

    spacing: 4

    Button {
        checkable: true
        checked: volumeControl.audioOutput.muted
        focusPolicy: Qt.NoFocus
        text: qsTr("Mute")
        onToggled: volumeControl.audioOutput.muted = checked
    }

    // AudioOutput.volume is linear, as in ToyBoxx.
    Slider {
        Layout.preferredWidth: 100
        from: 0
        to: 1
        value: volumeControl.audioOutput.volume
        enabled: !volumeControl.audioOutput.muted
        focusPolicy: Qt.NoFocus
        onMoved: volumeControl.audioOutput.volume = value
    }
}
