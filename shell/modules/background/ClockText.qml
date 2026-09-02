import QtQuick
import qs.components
import qs.services

StyledText {
    font {
        family: Tokens.font.clock.family ?? Tokens.font.regular.family
        pixelSize: 20
        weight: 350
        styleName: ""
    }
    style: Text.Raised
    styleColor: Colours.palette.m3shadow
}
