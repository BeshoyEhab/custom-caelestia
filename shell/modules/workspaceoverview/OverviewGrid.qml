import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.components.misc
import qs.services
import qs.utils

Item {
    id: root

    required property int activeWsId
    required property bool overviewOpen
    required property int rows
    required property int columns
    required property real wsWidth
    required property real wsHeight
    required property real cardSpacing
    required property real overviewScale
    signal close

    readonly property int workspacesShown: rows * columns
    readonly property int groupOffset: Math.floor((root.activeWsId - 1) / root.workspacesShown) * root.workspacesShown

    property var windowDataList: []
    property var dragWindow: null

    implicitWidth: columns * root.wsWidth + (columns - 1) * root.cardSpacing
    implicitHeight: rows * root.wsHeight + (rows - 1) * root.cardSpacing

    function cellAtPos(px: real, py: real): int {
        for (let c = 0; c < root.columns; c++) {
            for (let r = 0; r < root.rows; r++) {
                const cellX = c * (root.wsWidth + root.cardSpacing);
                const cellY = r * (root.wsHeight + root.cardSpacing);
                if (px >= cellX && px < cellX + root.wsWidth && py >= cellY && py < cellY + root.wsHeight)
                    return root.groupOffset + r * root.columns + c + 1;
            }
        }
        return -1;
    }

    function refreshWindows() {
        const newList = [];
        if (!root.overviewOpen) {
            windowDataList = newList;
            return;
        }

        const hyprVals = Hypr.toplevels?.values;
        if (!hyprVals) {
            windowDataList = newList;
            return;
        }

        for (let i = 0; i < hyprVals.length; i++) {
            const h = hyprVals[i];
            const wsId = h.workspace?.id ?? 0;
            const ipc = h.lastIpcObject;
            if (wsId <= root.groupOffset || wsId > root.groupOffset + root.workspacesShown) continue;
            if (!ipc) continue;

            newList.push({
                toplevel: h,
                address: h.address,
                wsId: wsId,
                winClass: ipc.class ?? "",
                sizeX: ipc.size?.[0] ?? 100,
                sizeY: ipc.size?.[1] ?? 100,
                posX: ipc.at?.[0] ?? 0,
                posY: ipc.at?.[1] ?? 0
            });
        }
        windowDataList = newList;
    }

    onOverviewOpenChanged: refreshWindows()
    onActiveWsIdChanged: { if (overviewOpen) refreshWindows(); }
    onGroupOffsetChanged: { if (overviewOpen) refreshWindows(); }
    Component.onCompleted: { if (overviewOpen) refreshWindows(); }

    Connections {
        target: Hypr.toplevels
        function onValuesChanged() { root.refreshWindows(); }
    }

    Item {
        id: previewContainer
        anchors.fill: parent
        z: 1
    }

    onWindowDataListChanged: {
        const existing = {};
        for (let i = 0; i < previewContainer.children.length; i++) {
            const child = previewContainer.children[i];
            existing[child.addr] = child;
        }

        const usedAddrs = {};

        for (let i = 0; i < windowDataList.length; i++) {
            const d = windowDataList[i];
            usedAddrs[d.address] = true;

            const wsId = d.wsId;
            const wsCol = (wsId - 1 - root.groupOffset) % root.columns;
            const wsRow = Math.floor((wsId - 1 - root.groupOffset) / root.columns);
            const winW = Math.max(d.sizeX, 50);
            const winH = Math.max(d.sizeY, 50);
            const sc = root.overviewScale;
            const scaledW = winW * sc;
            const scaledH = winH * sc;
            const wsX = wsCol * (root.wsWidth + root.cardSpacing);
            const wsY = wsRow * (root.wsHeight + root.cardSpacing);
            const baseX = d.posX * sc;
            const baseY = d.posY * sc;

            const newX = wsX + baseX;
            const newY = wsY + baseY;

            if (existing[d.address]) {
                const item = existing[d.address];
                item.toplevel = d.toplevel;
                item.x = newX;
                item.y = newY;
                item.width = scaledW;
                item.height = scaledH;
                item.wsId = d.wsId;
                item.winClass = d.winClass;
                item.visible = true;
                delete existing[d.address];
            } else {
                previewComponent.createObject(previewContainer, {
                    "x": newX,
                    "y": newY,
                    "width": scaledW,
                    "height": scaledH,
                    "winClass": d.winClass,
                    "toplevel": d.toplevel,
                    "addr": d.address,
                    "wsId": d.wsId
                });
            }
        }

        for (const addr in existing) {
            existing[addr].destroy();
        }
    }

    Component {
        id: previewComponent

        Rectangle {
            id: prevItem
            radius: Tokens.rounding.medium
            color: "#1a1a2e"
            clip: true

            property string winClass: ""
            property var toplevel: null
            property string addr: ""
            property int wsId: 0
            property bool hovered: false
            property bool dragging: false

            ScreencopyView {
                id: screencopy
                anchors.fill: parent
                captureSource: root.overviewOpen ? (prevItem.toplevel?.wayland ?? null) : null
                live: true
            }

            IconImage {
                z: 1
                anchors {
                    top: parent.top
                    right: parent.right
                    margins: 4
                }
                visible: true
                implicitSize: Math.min(parent.width, parent.height) * 0.2
                source: Icons.getAppIcon(prevItem.winClass, "image-missing")
            }

            Rectangle {
                z: 1
                anchors.fill: parent
                radius: Tokens.rounding.medium
                color: "transparent"
                border.width: prevItem.hovered || prevItem.dragging ? 2 : 0
                border.color: Colours.palette.m3primary
            }

            MouseArea {
                id: prevMouse
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: prevItem.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                property real pressX: 0
                property real pressY: 0
                property bool wasDrag: false
                property bool wasDragSession: false
                property bool wasMouseDrag: false
                property real startX: 0
                property real startY: 0

                Timer {
                    id: longPressTimer
                    interval: 400
                    onTriggered: {
                        if (prevMouse.pressed) {
                            wasDragSession = true;
                            prevItem.dragging = true;
                            root.dragWindow = { addr: prevItem.addr, wsId: prevItem.wsId };
                            prevItem.z = 999;
                        }
                    }
                }

                onEntered: prevItem.hovered = true
                onExited: prevItem.hovered = false

                onPressed: mouse => {
                    const gp = mapToItem(previewContainer, mouse.x, mouse.y);
                    pressX = gp.x;
                    pressY = gp.y;
                    startX = prevItem.x;
                    startY = prevItem.y;
                    wasDrag = false;
                    wasDragSession = false;
                    wasMouseDrag = false;
                    prevItem.dragging = false;
                    mouse.accepted = true;
                    longPressTimer.start();
                }
                onPositionChanged: mouse => {
                    if (!prevMouse.pressed) return;
                    const gp = mapToItem(previewContainer, mouse.x, mouse.y);
                    const dx = gp.x - pressX;
                    const dy = gp.y - pressY;
                    if (!wasDrag && !prevItem.dragging && (Math.abs(dx) > 1 || Math.abs(dy) > 1)) {
                        wasDrag = true;
                        wasDragSession = true;
                        wasMouseDrag = true;
                        longPressTimer.stop();
                        prevItem.dragging = true;
                        root.dragWindow = { addr: prevItem.addr, wsId: prevItem.wsId };
                        prevItem.z = 999;
                    }
                    if (prevItem.dragging) {
                        prevItem.x = startX + dx;
                        prevItem.y = startY + dy;
                    }
                }
                onReleased: mouse => {
                    longPressTimer.stop();
                    const a = prevItem.addr;
                    if (wasMouseDrag && prevItem.dragging) {
                        const cx = prevItem.x + prevItem.width / 2;
                        const cy = prevItem.y + prevItem.height / 2;
                        const targetWs = root.cellAtPos(cx, cy);
                        if (targetWs !== -1 && targetWs !== prevItem.wsId)
                            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ address = "0x${a}", workspace = ${targetWs} })` : `movetoworkspace ${targetWs},address:0x${a}`);
                        prevItem.dragging = false;
                        prevItem.z = 1;
                        prevItem.x = startX;
                        prevItem.y = startY;
                        root.dragWindow = null;
                        return;
                    }
                    if (!wasDragSession) {
                        if (root.dragWindow) {
                            if (root.dragWindow.addr !== a) {
                                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ address = "0x${root.dragWindow.addr}", workspace = ${prevItem.wsId} })` : `movetoworkspace ${prevItem.wsId},address:0x${root.dragWindow.addr}`);
                            }
                            root.dragWindow = null;
                            root.close();
                            return;
                        }
                        if (prevMouse.pressedButtons === Qt.MiddleButton) {
                            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ address = "0x${a}" })` : `closewindow address:0x${a}`);
                            return;
                        }
                        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ address = "0x${a}" })` : `focuswindow address:0x${a}`);
                        if (prevItem.wsId !== Hypr.activeWsId)
                            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = ${prevItem.wsId} })` : `workspace ${prevItem.wsId}`);
                        if (Hypr.usingLua) {
                            const ipc = prevItem.toplevel?.lastIpcObject;
                            if (ipc) {
                                const mon = Hypr.focusedMonitor?.lastIpcObject;
                                const mx = mon?.x ?? 0;
                                const my = mon?.y ?? 0;
                                const cx = mx + (ipc.at?.[0] ?? 0) + (ipc.size?.[0] ?? 0) / 2;
                                const cy = my + (ipc.at?.[1] ?? 0) + (ipc.size?.[1] ?? 0) / 2;
                                Hypr.dispatch(`hl.dsp.cursor.move({x=${Math.round(cx)},y=${Math.round(cy)}})`);
                            }
                        }
                        root.close();
                    }
                }
            }
        }
    }

    Grid {
        columns: root.columns
        spacing: root.cardSpacing
        z: 0

        Repeater {
            model: root.workspacesShown

            Rectangle {
                required property int index

                property int wsId: root.groupOffset + index + 1
                property bool isCellActive: Number(wsId) === Number(root.activeWsId)
                property bool isDropTarget: false

                width: root.wsWidth
                height: root.wsHeight
                radius: Tokens.rounding.large
                color: "#2a2a2a"
                border.width: isCellActive ? 3 : 2
                border.color: isCellActive ? Colours.palette.m3primary : (isDropTarget ? Colours.palette.m3primary : "#444")

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: false

                    onClicked: {
                        if (root.dragWindow) {
                            const addr = root.dragWindow.addr;
                            const targetWs = parent.wsId;
                            if (targetWs !== root.dragWindow.wsId)
                                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ address = "0x${addr}", workspace = ${targetWs} })` : `movetoworkspace ${targetWs},address:0x${addr}`);
                            root.dragWindow = null;
                            root.close();
                            return;
                        }
                        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = ${parent.wsId} })` : `workspace ${parent.wsId}`);
                        root.close();
                    }
                }

                DropArea {
                    anchors.fill: parent
                    keys: ["text/plain"]
                    onEntered: parent.isDropTarget = true
                    onExited: parent.isDropTarget = false
                    onDropped: drop => {
                        parent.isDropTarget = false;
                        const addr = drop.text;
                        if (addr)
                            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ address = "${addr}", workspace = ${parent.wsId} })` : `movetoworkspace ${parent.wsId},address:${addr}`);
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: parent.wsId.toString()
                    color: parent.isCellActive ? Colours.palette.m3onPrimary : "#ffffff"
                    font.pixelSize: Math.min(parent.width, parent.height) * 0.3
                    font.weight: Font.Bold
                    opacity: 0.15
                }
            }
        }
    }
}
