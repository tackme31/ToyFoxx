pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtMultimedia

Button {
    id: speedButton

    required property MediaPlayer player
    readonly property bool popupOpen: ratePopup.visible
    readonly property list<real> rates: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]

    checkable: true
    checked: ratePopup.visible
    focusPolicy: Qt.NoFocus
    text: qsTr("x %1").arg(player.playbackRate)

    onClicked: ratePopup.open()

    Popup {
        id: ratePopup

        y: -implicitHeight - 4
        width: speedButton.width + leftPadding + rightPadding
        padding: 4

        Column {
            Repeater {
                model: speedButton.rates

                delegate: Button {
                    required property real modelData

                    width: speedButton.width
                    flat: true
                    highlighted: modelData === speedButton.player.playbackRate
                    focusPolicy: Qt.NoFocus
                    text: qsTr("x %1").arg(modelData)
                    onClicked: {
                        speedButton.player.playbackRate = modelData;
                        ratePopup.close();
                    }
                }
            }
        }
    }
}
