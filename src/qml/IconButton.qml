import QtQuick
import QtQuick.Controls

// A flat button showing one Segoe Fluent Icons glyph. The label, which the glyph replaces, is
// kept as the tooltip and the accessible name.
ToolButton {
    id: iconButton

    required property string label

    implicitWidth: 40
    implicitHeight: 40
    focusPolicy: Qt.NoFocus
    font.family: "Segoe Fluent Icons"
    font.pixelSize: 16
    Accessible.name: label
    ToolTip.visible: hovered
    ToolTip.delay: 600
    ToolTip.text: label
}
