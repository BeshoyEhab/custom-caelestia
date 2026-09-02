pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.misc
import qs.services
import qs.utils

Item {
    id: root

    required property var toplevel
    required property bool overviewOpen
    required property real containerWidth
    required property real containerHeight
    required property int groupOffset
    required property int columns
    required property real cardSpacing
    required property int totalWindows
    required property int windowIndex

    readonly property var ipcObj: toplevel?.lastIpcObject
    readonly property int wsId: toplevel?.workspace?.id ?? 0
    readonly property int wsCol: (wsId - 1 - groupOffset) % columns
    readonly property int wsRow: Math.floor((wsId - 1 - groupOffset) / columns)
    readonly property real winW: Math.max(ipcObj?.size[0] ?? 100, 50)
    readonly property real winH: Math.max(ipcObj?.size[1] ?? 100, 50)
    readonly property real fitScale: Math.min(containerWidth / winW, containerHeight / winH, 0.8)
    readonly property real scaledW: winW * fitScale
    readonly property real scaledH: winH * fitScale

    // Position: window position within its workspace cell, offset by cell position
    readonly property real cellX: wsCol * (containerWidth + cardSpacing)
    readonly property real cellY: wsRow * (containerHeight + cardSpacing)
    readonly property real winOffsetX: Math.min(ipcObj?.at[0] ?? 0, containerWidth - scaledW) * 0.3
    readonly property real winOffsetY: Math.min(ipcObj?.at[1] ?? 0, containerHeight - scaledH) * 0.3

    x: cellX + winOffsetX
    y: cellY + winOffsetY
    width: scaledW
    height: scaledH
    z: dragArea.drag.active ? 999 : 1

    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2

    // Window preview
    StyledClippingRect {
        anchors.fill: parent
        radius: Tokens.rounding.medium
        color: Colours.layer(Colours.palette.m3surfaceContainer, 1)

        ScreencopyView {
            id: screencopy
            anchors.fill: parent
            captureSource: root.overviewOpen ? root.toplevel : null
            live: true
        }

        // App icon fallback — always show
        MaterialIcon {
            anchors.centerIn: parent
            grade: 0
            text: Icons.getAppCategoryIcon(root.toplevel?.lastIpcObject?.class ?? "", "terminal")
            color: Colours.palette.m3onSurfaceVariant
            font.pixelSize: Math.min(root.scaledW, root.scaledH) * 0.35
        }
    }

    // Drag + click handling
    MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        drag.target: root
        drag.axis: Drag.XAndY

        property real pressX: 0
        property real pressY: 0
        property bool wasDrag: false

        onPressed: mouse => {
            pressX = mapToItem(root.parent, mouse.x, mouse.y).x;
            pressY = mapToItem(root.parent, mouse.x, mouse.y).y;
            wasDrag = false;
        }

        onPositionChanged: mouse => {
            if (!pressed) return;
            const curX = mapToItem(root.parent, mouse.x, mouse.y).x;
            const curY = mapToItem(root.parent, mouse.x, mouse.y).y;
            if (Math.abs(curX - pressX) > 1 || Math.abs(curY - pressY) > 1)
                wasDrag = true;
        }

        onReleased: mouse => {
            if (wasDrag) {
                const targetWs = root.getWorkspaceAtPosition(root.x + root.width / 2, root.y + root.height / 2);
                if (targetWs > 0 && targetWs !== root.wsId) {
                    Hypr.dispatch(Hypr.usingLua
                        ? `hl.dsp.window.move({ address = "0x${root.toplevel?.lastIpcObject?.address?.toString(16) ?? '0'}", workspace = ${targetWs} })`
                        : `movetoworkspace ${targetWs},address:0x${root.toplevel?.lastIpcObject?.address?.toString(16) ?? '0'}`);
                }
                root.x = Qt.binding(() => root.cellX + root.winOffsetX);
                root.y = Qt.binding(() => root.cellY + root.winOffsetY);
            } else {
                Hypr.dispatch(Hypr.usingLua
                    ? `hl.dsp.focus({ address = "0x${root.toplevel?.lastIpcObject?.address?.toString(16) ?? '0'}" })`
                    : `focuswindow address:0x${root.toplevel?.lastIpcObject?.address?.toString(16) ?? '0'}`);
                if (root.toplevel?.workspace?.id !== Hypr.activeWsId)
                    Hypr.dispatch(Hypr.usingLua
                        ? `hl.dsp.focus({ workspace = "${root.toplevel?.workspace?.id}" })`
                        : `workspace ${root.toplevel?.workspace?.id}`);
                root.parent?.parent?.close?.();
            }
        }
    }

    function getWorkspaceAtPosition(x: real, y: real): int {
        const cols = root.columns;
        const cellW = root.containerWidth + root.cardSpacing;
        const cellH = root.containerHeight + root.cardSpacing;
        const col = Math.floor(x / cellW);
        const row = Math.floor(y / cellH);
        if (col < 0 || col >= cols || row < 0) return -1;
        return root.groupOffset + row * cols + col + 1;
    }

    Behavior on x { Anim { type: Anim.FastSpatial } }
    Behavior on y { Anim { type: Anim.FastSpatial } }
}
