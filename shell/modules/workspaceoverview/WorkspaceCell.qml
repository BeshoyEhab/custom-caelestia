pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Rectangle {
    id: root

    required property int wsId
    required property bool isActive
    required property bool overviewOpen
    required property real cellWidth
    required property real cellHeight
    signal close

    readonly property var ws: Hypr.workspaces.values.find(w => w.id === root.wsId)
    readonly property var windows: Hypr.toplevels.values.filter(c => c.workspace?.id === root.wsId)
    readonly property bool hasWindows: windows.length > 0

    width: cellWidth
    height: cellHeight

    property bool isDropTarget: false
    color: root.isActive ? Colours.palette.m3primary : "#2a2a2a"
    radius: Tokens.rounding.large
    border.width: root.isActive ? 2 : (root.isDropTarget ? 3 : 2)
    border.color: root.isActive ? Colours.palette.m3primary : (root.isDropTarget ? Colours.palette.m3primary : "#444444")

    Behavior on border.color {
        Anim { type: Anim.DefaultEffects }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        property real pressX: 0
        property real pressY: 0
        property bool clicked: false

        onPressed: mouse => {
            pressX = mouse.x;
            pressY = mouse.y;
            clicked = true;
        }

        onReleased: mouse => {
            if (!clicked) return;
            const dx = Math.abs(mouse.x - pressX);
            const dy = Math.abs(mouse.y - pressY);
            if (dx < 8 && dy < 8) {
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "${root.wsId}" })` : `workspace ${root.wsId}`);
                root.close();
            }
            clicked = false;
        }

        onPositionChanged: mouse => {
            if (!pressed) return;
            const dx = Math.abs(mouse.x - pressX);
            const dy = Math.abs(mouse.y - pressY);
            if (dx > 8 || dy > 8) {
                clicked = false;
            }
        }
    }

    // Drop area for window dragging
    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list", "application/x-hyprland-toplevel"]

        onEntered: {
            root.isDropTarget = true
        }

        onExited: {
            root.isDropTarget = false
        }

        onDropped: drop => {
            const address = drop.text;
            if (address) {
                Hypr.dispatch(Hypr.usingLua
                    ? `hl.dsp.window.move({ address = "${address}", workspace = ${root.wsId} })`
                    : `movetoworkspace ${root.wsId},address:${address}`);
            }
            root.isDropTarget = false
        }
    }

    // Workspace number — always visible
    StyledText {
        anchors.centerIn: parent
        text: root.wsId.toString()
        color: "#ffffff"
        font: Tokens.font.headline.builders.large
    }

    Behavior on color {
        Anim { type: Anim.DefaultEffects }
    }
}
