import QtQuick
import qs.modules.bar.components

Power {
    property var item
    property var host
    property string orientation: "vertical"

    visibilities: host.visibilities
}
