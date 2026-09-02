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
    property int dragTargetWorkspace: -1

    readonly property var ipcObj: toplevel?.lastIpcObject
    readonly property int wsId: toplevel?.workspace?.id ?? 0
    readonly property int wsCol: (wsId - 1 - groupOffset) % columns
    readonly property int wsRow: Math.floor((wsId - 1 - groupOffset) / columns)
    readonly property real winW: Math.max(ipcObj?.size[0] ?? 100, 50)
    readonly property real winH: Math.max(ipcObj?.size[1] ?? 100, 50)
    readonly property real fitScale: Math.min(containerWidth / winW, containerHeight / winH, 0.8)
    readonly property real scaledW: winW * fitScale
    readonly property real scaledH: winH * fitScale

    readonly property real cellX: wsCol * (containerWidth + cardSpacing)
    readonly property real cellY: wsRow * (containerHeight + cardSpacing)
    readonly property real winOffsetX: Math.min(ipcObj?.at[0] ?? 0, containerWidth - scaledW) * 0.3
    readonly property real winOffsetY: Math.min(ipcObj?.at[1] ?? 0, containerHeight - scaledH) * 0.3

    x: cellX + winOffsetX
    y: cellY + winOffsetY
    width: scaledW
    height: scaledH

    property bool hovered: false
    property bool pressed: false

    z: Drag.active ? 9999 : 1
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2

    StyledClippingRect {
        anchors.fill: parent
        radius: Tokens.rounding.medium
        color: root.pressed ? Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.3) :
            root.hovered ? Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.15) :
            Colours.layer(Colours.palette.m3surfaceContainer, 1)

        ScreencopyView {
            anchors.fill: parent
            captureSource: root.overviewOpen ? root.toplevel : null
            live: true
        }

        MaterialIcon {
            anchors.centerIn: parent
            grade: 0
            text: Icons.getAppCategoryIcon(root.toplevel?.lastIpcObject?.class ?? "", "terminal")
            color: Colours.palette.m3onSurfaceVariant
            font.pixelSize: Math.min(root.scaledW, root.scaledH) * 0.35
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        drag.target: root

        onPressed: mouse => {
            root.pressed = true;
            root.Drag.active = true;
            root.Drag.source = root;
            root.Drag.hotSpot.x = mouse.x;
            root.Drag.hotSpot.y = mouse.y;
        }
        onReleased: {
            const targetWs = root.dragTargetWorkspace;
            root.pressed = false;
            root.Drag.active = false;
            root.dragTargetWorkspace = -1;

            if (targetWs !== -1 && targetWs !== root.wsId) {
                Hypr.dispatch(Hypr.usingLua
                    ? `hl.dsp.window.move({ address = "0x${root.toplevel?.lastIpcObject?.address?.toString(16) ?? '0'}", workspace = ${targetWs} })`
                    : `movetoworkspace ${targetWs},address:0x${root.toplevel?.lastIpcObject?.address?.toString(16) ?? '0'}`);
            }
            root.x = Qt.binding(() => root.cellX + root.winOffsetX);
            root.y = Qt.binding(() => root.cellY + root.winOffsetY);
        }
        onClicked: mouse => {
            if (!root.toplevel) return;
            if (mouse.button === Qt.MiddleButton) {
                Hypr.dispatch(Hypr.usingLua
                    ? `hl.dsp.window.close({ address = "0x${root.toplevel?.lastIpcObject?.address?.toString(16) ?? '0'}" })`
                    : `closewindow address:0x${root.toplevel?.lastIpcObject?.address?.toString(16) ?? '0'}`);
                return;
            }
            Hypr.dispatch(Hypr.usingLua
                ? `hl.dsp.focus({ address = "0x${root.toplevel?.lastIpcObject?.address?.toString(16) ?? '0'}" })`
                : `focuswindow address:0x${root.toplevel?.lastIpcObject?.address?.toString(16) ?? '0'}`);
            if (root.toplevel?.workspace?.id !== Hypr.activeWsId)
                Hypr.dispatch(Hypr.usingLua
                    ? `hl.dsp.focus({ workspace = "${root.toplevel?.workspace?.id}" })`
                    : `workspace ${root.toplevel?.workspace?.id}`);
            root.parent?.parent?.close?.();
        }
        onEntered: root.hovered = true
        onExited: root.hovered = false
    }

    Behavior on x { Anim { type: Anim.FastSpatial } }
    Behavior on y { Anim { type: Anim.FastSpatial } }
}
