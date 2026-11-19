import QtQuick
import Caelestia.Config

Item {
    id: root

    property var item
    property var host
    property string orientation: "vertical"

    readonly property int size: item?.options?.size ?? Tokens.spacing.medium

    implicitWidth: size
    implicitHeight: size
}
