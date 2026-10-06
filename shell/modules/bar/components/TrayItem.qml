pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components.effects
import qs.services
import qs.utils

MouseArea {
    id: root

    required property SystemTrayItem modelData

    // Debounce icon churn: a flapping app (badge updates, D-Bus IconName
    // error storms) must not drive pixmap reloads at event rate. The
    // displayed icon follows at most every 500ms.
    property string shownIcon: ""

    function requestIcon(): void {
        iconDebounce.restart();
    }

    Component.onCompleted: root.shownIcon = Icons.getTrayIcon(root.modelData.id, root.modelData.icon)

    Connections {
        function onIconChanged(): void {
            root.requestIcon();
        }

        target: root.modelData
    }

    Timer {
        id: iconDebounce

        interval: 500
        onTriggered: root.shownIcon = Icons.getTrayIcon(root.modelData.id, root.modelData.icon)
    }

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    implicitWidth: Tokens.font.body.small.pointSize * 2
    implicitHeight: Tokens.font.body.small.pointSize * 2

    onClicked: event => {
        if (event.button === Qt.LeftButton)
            modelData.activate();
        else
            modelData.secondaryActivate();
    }

    ColouredIcon {
        id: icon

        anchors.fill: parent
        source: root.shownIcon
        colour: Colours.palette.m3secondary
        layer.enabled: Config.bar.tray.recolour
    }
}
