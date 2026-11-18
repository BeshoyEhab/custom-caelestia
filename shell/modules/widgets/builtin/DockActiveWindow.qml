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
    maxHeight: host.activeWindowMaxHeight
    Layout.fillWidth: true
}
