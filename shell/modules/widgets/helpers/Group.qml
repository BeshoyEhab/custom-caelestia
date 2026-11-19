import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import ".." as Widgets

StyledRect {
    id: root

    property var item
    property var host
    property string orientation: "vertical"

    readonly property int padding: Tokens.padding.small

    implicitWidth: content.implicitWidth + padding * 2
    implicitHeight: content.implicitHeight + padding * 2

    color: root.item?.options?.background === false ? "transparent" : Colours.tPalette.m3surfaceContainer

    Widgets.WidgetHost {
        id: content

        anchors.centerIn: parent

        items: root.item?.children ?? []
        hostContext: root.host
    }
}
