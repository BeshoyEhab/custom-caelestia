pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.modules.launcher.services

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property var panels

    // Opening during the startup load used to show a partial list that then
    // re-sorted under the cursor. Once the cached first rows exist the launcher
    // opens immediately on them; otherwise (first run after install) it waits
    // for the DB. See Apps.previewReady.
    readonly property bool shouldBeActive: visibilities.launcher && Config.launcher.enabled && (Apps.settled || Apps.previewReady)

    readonly property real maxHeight: {
        let max = screen.height - Config.border.thickness * 2 + Tokens.padding.extraLarge;
        if (visibilities.dashboard)
            max -= panels.dashboard.nonAnimHeight;
        return max;
    }

    property real offsetScale: shouldBeActive ? 0 : 1

    onShouldBeActiveChanged: {
        if (shouldBeActive)
            implicitHeight = Qt.binding(() => content.implicitHeight);
        else
            implicitHeight = implicitHeight;
    }

    visible: offsetScale < 1
    anchors.bottomMargin: (-implicitHeight - 5) * offsetScale
    anchors.topMargin: (-implicitHeight - 5) * offsetScale
    implicitHeight: content.implicitHeight
    implicitWidth: content.implicitWidth || 630
    opacity: 1 - offsetScale

    Component.onCompleted: Qt.callLater(() => Apps)

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            visibilities: root.visibilities
            panels: root.panels
            maxHeight: root.maxHeight
        }
    }
}
