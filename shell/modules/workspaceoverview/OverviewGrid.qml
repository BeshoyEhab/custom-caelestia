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
    property int dragTargetWorkspace: -1
    property int dragSourceWorkspace: -1

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

    onOverviewOpenChanged: {
        if (!overviewOpen)
            releaseTimer.stop();
        refreshWindows();
    }
    onActiveWsIdChanged: { if (overviewOpen) refreshWindows(); }
    onGroupOffsetChanged: { if (overviewOpen) refreshWindows(); }
    Component.onCompleted: { if (overviewOpen) refreshWindows(); }

    // Same-workspace moves change geometry without changing the toplevel set,
    // so onValuesChanged may never fire for them. One backstop rebuild after
    // release, past the window animation so mid-flight geometry isn't
    // captured (alongside the explicit Hyprland.refreshToplevels() at each
    // drop site). Skipped if a new drag already started, so it can't yank
    // the item mid-gesture.
    Timer {
        id: releaseTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (root.dragSourceWorkspace === -1)
                root.refreshWindows();
        }
    }

    function scheduleReleaseRefresh(): void {
        releaseTimer.restart();
    }

    Connections {
        target: Hypr.toplevels
        function onValuesChanged() {
            if (root.dragSourceWorkspace === -1)
                root.refreshWindows();
        }
    }

    Connections {
        target: Hypr
        // Toplevel state (float/fullscreen/pin/group) changed without
        // changing the set: rebuild so live external changes show.
        function onToplevelDataChanged() {
            if (root.overviewOpen && root.dragSourceWorkspace === -1)
                root.refreshWindows();
        }
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
                item.expectedX = newX;
                item.expectedY = newY;
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
                    "expectedX": newX,
                    "expectedY": newY,
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
            property bool pressed: false
            property real expectedX: 0
            property real expectedY: 0
            property bool wasDragged: false

            z: Drag.active ? 9999 : 1
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2
            scale: pressed ? 1.05 : 1

            Behavior on scale {
                Anim {
                    type: Anim.FastSpatial
                }
            }

            onXChanged: {
                if (pressed && Math.abs(x - expectedX) > 5)
                    wasDragged = true;
            }
            onYChanged: {
                if (pressed && Math.abs(y - expectedY) > 5)
                    wasDragged = true;
            }

            ScreencopyView {
                id: screencopy
                anchors.fill: parent
                captureSource: root.overviewOpen ? (prevItem.toplevel?.wayland ?? null) : null
                // Freeze captures while dragging: less GPU churn exactly when
                // the compositor animates the move, and a stable drag image.
                live: root.dragSourceWorkspace === -1
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

            // Hover close badge (touchpad-friendly; right-click also closes).
            // Visibility also keys off the badge's own hover: otherwise the
            // badge steals hover from the window, hides itself, hover
            // returns, and it flickers in a loop.
            Rectangle {
                z: 5
                visible: (prevItem.hovered || closeMouse.containsMouse) && !prevItem.pressed
                anchors {
                    top: parent.top
                    left: parent.left
                    margins: 4
                }
                width: 22
                height: 22
                radius: 11
                color: Colours.palette.m3error

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: Colours.palette.m3onError
                    font.pixelSize: 14
                    font.bold: true
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: {
                        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "address:0x${prevItem.addr}" })` : `closewindow address:0x${prevItem.addr}`);
                        Hyprland.refreshToplevels();
                        root.scheduleReleaseRefresh();
                    }
                }
            }

            Rectangle {
                z: 1
                anchors.fill: parent
                radius: Tokens.rounding.medium
                color: prevItem.pressed ? Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.3) :
                    prevItem.hovered ? Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.15) :
                    Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.05)
                border.width: 1
                border.color: Qt.rgba(Colours.palette.m3outline.r, Colours.palette.m3outline.g, Colours.palette.m3outline.b, 0.12)
            }

            MouseArea {
                id: prevMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                // RightButton = two-finger tap on touchpads → close (same as middle-click)
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                drag.target: prevItem

                onPressed: mouse => {
                    root.dragSourceWorkspace = prevItem.wsId;
                    root.dragTargetWorkspace = -1;
                    prevItem.pressed = true;
                    prevItem.wasDragged = false;
                    prevItem.Drag.active = true;
                    prevItem.Drag.source = prevItem;
                    prevItem.Drag.hotSpot.x = mouse.x;
                    prevItem.Drag.hotSpot.y = mouse.y;
                }
                onReleased: mouse => {
                    const targetWs = root.dragTargetWorkspace;
                    const didDrop = targetWs !== -1 && targetWs !== prevItem.wsId;
                    prevItem.pressed = false;
                    prevItem.Drag.active = false;
                    root.dragSourceWorkspace = -1;
                    root.dragTargetWorkspace = -1;

                    if (didDrop) {
                        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ window = "address:0x${prevItem.addr}", workspace = ${targetWs}, follow = false })` : `movetowsilent ${targetWs},address:0x${prevItem.addr}`);
                        if (Hypr.usingLua) {
                            // Place within the target workspace relative to the
                            // drop point: floating windows go to the exact
                            // drop coordinates; tiled windows nudge one layout
                            // slot toward it (stays tiled, no focus change).
                            const isFloating = prevItem.toplevel?.lastIpcObject?.floating ?? false;
                            const isFullscreen = (prevItem.toplevel?.lastIpcObject?.fullscreen ?? 0) !== 0;
                            const tCol = (targetWs - 1 - root.groupOffset) % root.columns;
                            const tRow = Math.floor((targetWs - 1 - root.groupOffset) / root.columns);
                            const tX = tCol * (root.wsWidth + root.cardSpacing);
                            const tY = tRow * (root.wsHeight + root.cardSpacing);
                            if (isFloating && !isFullscreen) {
                                const scrW = QsWindow.window?.screen?.width ?? 1920;
                                const scrH = QsWindow.window?.screen?.height ?? 1080;
                                const moveX = Math.round(Math.min(1, Math.max(0, (prevItem.x - tX) / root.wsWidth)) * scrW);
                                const moveY = Math.round(Math.min(1, Math.max(0, (prevItem.y - tY) / root.wsHeight)) * scrH);
                                Hypr.dispatch(`hl.dsp.window.move({ x = "${moveX}", y = "${moveY}", window = "address:0x${prevItem.addr}" })`);
                            } else if (!isFullscreen) {
                                const dx = (prevItem.x + prevItem.width / 2) - (tX + root.wsWidth / 2);
                                const dy = (prevItem.y + prevItem.height / 2) - (tY + root.wsHeight / 2);
                                // Corner drops need two layout steps (e.g. right
                                // then down for bottom-right); edge drops need one.
                                const dirs = [];
                                if (Math.abs(dx) > 20 || Math.abs(dy) > 20) {
                                    if (Math.abs(dx) > Math.abs(dy)) {
                                        dirs.push(dx > 0 ? "r" : "l");
                                        if (Math.abs(dy) > 20)
                                            dirs.push(dy > 0 ? "d" : "u");
                                    } else {
                                        dirs.push(dy > 0 ? "d" : "u");
                                        if (Math.abs(dx) > 20)
                                            dirs.push(dx > 0 ? "r" : "l");
                                    }
                                }
                                for (const dir of dirs)
                                    Hypr.dispatch(`hl.dsp.window.move({ window = "address:0x${prevItem.addr}", direction = "${dir}" })`);
                            }
                        }
                        // Optimistic: show the window where it was dropped
                        // instantly; the resync reconciles with Hypr truth.
                        prevItem.wsId = targetWs;
                        prevItem.expectedX = prevItem.x;
                        prevItem.expectedY = prevItem.y;
                        // A drop is not a click, even a short one: suppress onClicked,
                        // which would otherwise focus/navigate/close the overview.
                        prevItem.wasDragged = true;
                        // Force fresh IPC state; the reply updates
                        // Hypr.toplevels/workspaces, whose onValuesChanged
                        // triggers our rebuild. No timers, no guessing.
                        Hyprland.refreshToplevels();
                        Hyprland.refreshWorkspaces();
                        root.scheduleReleaseRefresh();
                        return;
                    }

                    if (!Hypr.usingLua) {
                        prevItem.x = prevItem.expectedX;
                        prevItem.y = prevItem.expectedY;
                        return;
                    }

                    const srcAddr = prevItem.addr;
                    const srcWs = prevItem.wsId;
                    const isFloating = prevItem.toplevel?.lastIpcObject?.floating ?? false;
                    const isFullscreen = (prevItem.toplevel?.lastIpcObject?.fullscreen ?? 0) !== 0;

                    const wsCol = (srcWs - 1 - root.groupOffset) % root.columns;
                    const wsRow = Math.floor((srcWs - 1 - root.groupOffset) / root.columns);
                    const xOffset = wsCol * (root.wsWidth + root.cardSpacing);
                    const yOffset = wsRow * (root.wsHeight + root.cardSpacing);
                    const scrW = QsWindow.window?.screen?.width ?? 1920;
                    const scrH = QsWindow.window?.screen?.height ?? 1080;

                    if (isFloating && !isFullscreen) {
                        const percentageX = Math.min(1, Math.max(0, (prevItem.x - xOffset) / root.wsWidth));
                        const percentageY = Math.min(1, Math.max(0, (prevItem.y - yOffset) / root.wsHeight));
                        const moveX = Math.round(percentageX * scrW);
                        const moveY = Math.round(percentageY * scrH);
                        Hypr.dispatch(`hl.dsp.window.move({ x = "${moveX}", y = "${moveY}", window = "address:0x${srcAddr}" })`);
                        prevItem.expectedX = prevItem.x;
                        prevItem.expectedY = prevItem.y;
                        prevItem.wasDragged = true;
                        Hyprland.refreshToplevels();
                        root.scheduleReleaseRefresh();
                        return;
                    }

                    // Tiled window dropped in the same workspace: nudge it one
                    // slot through the layout toward the drop point. Single
                    // window-targeted dispatch: no focus change, no cursor
                    // warp, stays tiled. Exact positional insert is not
                    // something Hyprland exposes (no such dispatcher).
                    if (!isFloating && !isFullscreen) {
                        const dx = prevItem.x - prevItem.expectedX;
                        const dy = prevItem.y - prevItem.expectedY;
                        let dir = "";
                        if (Math.abs(dx) > 20 || Math.abs(dy) > 20)
                            dir = Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? "r" : "l") : (dy > 0 ? "d" : "u");
                        if (dir !== "") {
                            Hypr.dispatch(`hl.dsp.window.move({ window = "address:0x${srcAddr}", direction = "${dir}" })`);
                            prevItem.expectedX = prevItem.x;
                            prevItem.expectedY = prevItem.y;
                            prevItem.wasDragged = true;
                            Hyprland.refreshToplevels();
                            root.scheduleReleaseRefresh();
                            return;
                        }
                    }

                    prevItem.x = prevItem.expectedX;
                    prevItem.y = prevItem.expectedY;
                }
                onClicked: mouse => {
                    if (prevItem.wasDragged) return;
                    if (!prevItem.toplevel) return;
                    if (mouse.button === Qt.MiddleButton || mouse.button === Qt.RightButton) {
                        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "address:0x${prevItem.addr}" })` : `closewindow address:0x${prevItem.addr}`);
                        Hyprland.refreshToplevels();
                        root.scheduleReleaseRefresh();
                        return;
                    }
                    Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "address:0x${prevItem.addr}" })` : `focuswindow address:0x${prevItem.addr}`);
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
                onEntered: prevItem.hovered = true
                onExited: prevItem.hovered = false
            }

            Behavior on x { Anim { type: Anim.FastSpatial } }
            Behavior on y { Anim { type: Anim.FastSpatial } }
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
                property bool isEmpty: !root.windowDataList.some(d => d.wsId === wsId)

                width: root.wsWidth
                height: root.wsHeight
                radius: Tokens.rounding.large
                color: isDropTarget ? "#3d3d3d" : isCellActive ? Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.14) : (root.dragSourceWorkspace !== -1 ? "#202020" : "#2a2a2a")
                border.width: (isCellActive || isDropTarget) ? 3 : 2
                border.color: (isCellActive || isDropTarget) ? Colours.palette.m3primary : "#444"

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: false

                    onClicked: {
                        if (root.dragTargetWorkspace !== -1) {
                            root.dragTargetWorkspace = -1;
                            root.close();
                            return;
                        }
                        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = ${parent.wsId} })` : `workspace ${parent.wsId}`);
                        root.close();
                    }
                }

                DropArea {
                    anchors.fill: parent
                    onEntered: {
                        root.dragTargetWorkspace = parent.wsId;
                        parent.isDropTarget = true;
                    }
                    onExited: {
                        parent.isDropTarget = false;
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: parent.wsId.toString()
                    color: "#999999"
                    font.pixelSize: Math.min(parent.width, parent.height) * 0.35
                    font.weight: Font.Bold
                }
            }
        }
    }
}
