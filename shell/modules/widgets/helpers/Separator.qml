import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Perpendicular to the dock: a vertical dock gets a horizontal hairline.
StyledRect {
    id: root

    property var item
    property var host
    property string orientation: "vertical"

    readonly property bool vertical: orientation === "vertical"
    readonly property int length: Math.round(Tokens.sizes.bar.innerWidth / 2)

    implicitWidth: vertical ? length : 1
    implicitHeight: vertical ? 1 : length

    color: Colours.palette.m3outlineVariant
}
