import QtQuick
import Caelestia.Config
import qs.components
import qs.services

StyledText {
    id: root

    // Optional desktop-clock font override. When set, it is expected to expose
    // the DesktopClockFont properties: size, family, width and roundness.
    property var fontSettings: null
    property real pointSize: 20
    property real scale: 1
    property int weight: -1
    property real letterSpacing: 0
    property string dateFormat: ""
    property bool uppercaseDate: false
    property bool raised: true

    readonly property real effectivePointSize: Math.max(1, Math.round(root.pointSize * root.scale
        * (root.fontSettings ? root.fontSettings.size : 1)))
    readonly property string clockFamily: Tokens.font.clock.build().family

    text: root.dateFormat.length > 0
        ? (root.uppercaseDate ? Time.format(root.dateFormat).toUpperCase() : Time.format(root.dateFormat))
        : ""

    font: {
        let b = Tokens.font.clock.size(root.effectivePointSize);
        if (root.weight > 0)
            b = b.weight(root.weight);
        if (root.clockFamily.length > 0)
            b = b.family(root.clockFamily);
        if (root.fontSettings) {
            b = b.vaxes({
                "wdth": root.fontSettings.width,
                "ROND": root.fontSettings.roundness
            });
        }
        if (root.letterSpacing !== 0)
            b = b.letterSpacing(root.letterSpacing);
        return b.build();
    }
    style: root.raised ? Text.Raised : Text.Normal
    styleColor: Colours.palette.m3shadow
}
