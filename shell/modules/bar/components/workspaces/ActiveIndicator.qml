pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

Rectangle {
    id: root

    required property int activeWsId
    required property Repeater workspaces
    required property Item mask
    required property bool fullscreen

    readonly property int currentWsIdx: {
        let i = activeWsId - 1;
        while (i < 0)
            i += Config.bar.workspaces.shown;
        return i % Config.bar.workspaces.shown;
    }

    readonly property var activeItem: workspaces.count > 0 ? workspaces.itemAt(currentWsIdx) : null

    property real targetX: (mask.parent.width - width) / 2
    property real targetY: activeItem ? mask.y + activeItem.y + (activeItem.size - height) / 2 : 0

    x: targetX
    y: targetY
    width: Tokens.sizes.bar.innerWidth - Tokens.padding.extraSmall * 2
    height: width
    radius: width / 2
    color: Colours.palette.m3primary
    z: 0

    property bool animationsReady: false

    Timer {
        interval: 350
        running: true
        repeat: false
        onTriggered: root.animationsReady = true
    }

    Behavior on y {
        enabled: root.animationsReady
        Anim {
            type: Anim.Emphasized
        }
    }
}
