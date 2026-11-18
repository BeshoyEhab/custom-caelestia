import QtQuick
import qs.modules.bar.components.workspaces

Workspaces {
    property var item
    property var host
    property string orientation: "vertical"

    screen: host.screen
    fullscreen: host.fullscreen
    bar: host
}
