import QtQuick
import QtQuick.Layouts
import qs.modules.bar.components
import qs.services

ActiveWindow {
    property var item
    property var host
    property string orientation: "vertical"

    bar: host
    monitor: Brightness.getMonitorForScreen(host.screen)
    // The bar supplies the real max height; hosts that do not get the bar
    // context fall back to the widget's native default (bar height * 0.25).
    maxHeight: host.activeWindowMaxHeight ?? (host.height * 0.25)
    Layout.fillWidth: true
}
