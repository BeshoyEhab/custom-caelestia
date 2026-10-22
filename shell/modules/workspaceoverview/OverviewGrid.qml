import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.components.misc
import qs.services
import qs.utils
import "OverviewMath.js" as OMath

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

    // Which page of workspaces is shown. Starts on the page holding the active
    // workspace, then follows the wheel or the pager.
    property int groupOffset: 0
    property var windowDataList: []
    property string query: ""
    property string selectedAddr: ""
    property string hoveredAddr: ""
    property int dragTargetWorkspace: -1
    property int dragSourceWorkspace: -1

    // Page count follows every workspace Hyprland knows about, so the pager can
    // reach workspaces that are not part of the current page.
    readonly property int maxWorkspaceId: {
        let max = Math.max(root.activeWsId, 1);
        const all = Hypr.workspaces?.values ?? [];
        for (let i = 0; i < all.length; i++)
            max = Math.max(max, all[i].id ?? 1);
        for (let i = 0; i < root.windowDataList.length; i++)
            max = Math.max(max, root.windowDataList[i].wsId);
        return max;
    }
    readonly property int pages: OMath.pageCount(root.maxWorkspaceId, root.workspacesShown)
    readonly property int pageIndex: Math.floor(root.groupOffset / root.workspacesShown)
    readonly property var matchAddresses: OMath.orderedMatches(root.windowDataList, root.query)
    // What the footer describes: the hovered window, else the selected one.
    readonly property var detail: {
        const addr = root.hoveredAddr || root.selectedAddr;
        return addr ? root.windowDataList.find(w => w.address === addr) ?? null : null;
    }

    implicitWidth: columns * root.wsWidth + (columns - 1) * root.cardSpacing
    implicitHeight: rows * root.wsHeight + (rows - 1) * root.cardSpacing

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
            // Special workspaces (negative ids) have no cell; keep every
            // numbered workspace so search can find windows on other pages.
            if (wsId <= 0) continue;
            if (!ipc) continue;

            newList.push({
                toplevel: h,
                address: h.address,
                wsId: wsId,
                title: ipc.title ?? "",
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
        if (overviewOpen) {
            root.query = "";
            root.hoveredAddr = "";
            root.selectedAddr = "";
            root.groupOffset = OMath.pageOffsetFor(root.activeWsId, root.workspacesShown);
        } else {
            verifyTimer.stop();
        }
        refreshWindows();
    }
    onActiveWsIdChanged: {
        if (!root.overviewOpen)
            return;
        if (root.query === "" && root.dragSourceWorkspace === -1)
            root.groupOffset = OMath.pageOffsetFor(root.activeWsId, root.workspacesShown);
        refreshWindows();
    }
    onGroupOffsetChanged: { if (overviewOpen) refreshWindows(); }
    onQueryChanged: root.applyQuery();
    Component.onCompleted: { if (overviewOpen) refreshWindows(); }

    // ── search, selection and paging ──────────────────────────────────────
    function syncMatchState(): void {
        const q = root.query.trim();
        // A selected/hovered window can close or be moved while the overview
        // is open; drop stale addresses so Enter cannot target a ghost.
        if (root.selectedAddr !== "" && !root.windowDataList.some(w => w.address === root.selectedAddr))
            root.selectedAddr = "";
        if (root.hoveredAddr !== "" && !root.windowDataList.some(w => w.address === root.hoveredAddr))
            root.hoveredAddr = "";
        const matches = {};
        for (let i = 0; i < root.matchAddresses.length; i++)
            matches[root.matchAddresses[i]] = true;
        for (let i = 0; i < previewContainer.children.length; i++) {
            const item = previewContainer.children[i];
            if (item.addr === undefined)
                continue;
            item.matched = q === "" || matches[item.addr] === true;
            item.selected = item.addr === root.selectedAddr;
            if (!item.matched)
                item.hovered = false;
        }
    }

    function selectAddress(addr: string): void {
        root.selectedAddr = addr ?? "";
        const d = addr ? root.windowDataList.find(w => w.address === addr) : null;
        if (d) {
            const offset = OMath.pageOffsetFor(d.wsId, root.workspacesShown);
            if (offset !== root.groupOffset)
                root.groupOffset = offset;
        }
        root.syncMatchState();
    }

    // Up/Down walk the matches in reading order; the page follows the match.
    function selectNext(delta: int): void {
        if (root.matchAddresses.length === 0)
            return;
        root.selectAddress(OMath.stepAddress(root.matchAddresses, root.selectedAddr, delta));
    }

    // Typing filters windows by title and app class. The first hit is selected
    // so Enter works without touching the mouse; clearing the query keeps the
    // page where the user left it.
    function applyQuery(): void {
        root.hoveredAddr = "";
        if (root.query.trim() === "") {
            root.selectAddress("");
            return;
        }
        root.selectAddress(root.matchAddresses[0] ?? "");
    }

    function setPage(index: int): void {
        const offset = OMath.clampPageOffset(index * root.workspacesShown, root.workspacesShown, root.maxWorkspaceId);
        if (offset === root.groupOffset)
            return;
        root.groupOffset = offset;
        root.hoveredAddr = "";
        root.selectedAddr = "";
        root.syncMatchState();
    }

    function changePage(delta: int): void {
        if (root.dragSourceWorkspace !== -1)
            return;
        root.setPage(root.pageIndex + delta);
    }

    function focusSelected(): void {
        if (root.selectedAddr !== "")
            root.focusWindow(root.selectedAddr);
    }

    function focusWindow(addr: string): void {
        const d = root.windowDataList.find(w => w.address === addr);
        if (!d || !d.toplevel)
            return;
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "address:0x${addr}" })` : `focuswindow address:0x${addr}`);
        if (d.wsId !== Hypr.activeWsId)
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = ${d.wsId} })` : `workspace ${d.wsId}`);
        if (Hypr.usingLua) {
            const ipc = d.toplevel?.lastIpcObject;
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

    // Wheel pages through workspaces; the search field keeps the keyboard.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (Math.abs(event.angleDelta.y) < 1)
                return;
            root.changePage(event.angleDelta.y > 0 ? -1 : 1);
            event.accepted = true;
        }
    }

    // Same-workspace moves change geometry without changing the toplevel set,
    // so onValuesChanged may never fire for them, and a single delayed read
    // can still race the compositor. Verify-then-stop: snapshot the moved
    // window pre-drop, rebuild until its data changes (and reaches the
    // target workspace on cross-ws moves), max 5 passes. Usually stops on
    // the first pass; never polls forever.
    property string verifyAddr: ""
    property int verifyTargetWs: -1
    property string verifySnapshot: ""
    property int verifyTries: 0

    // Drop debounce: some touchpads deliver release twice for one gesture,
    // and re-dropping the same window while its slide animation still runs
    // races the layout (frozen half-painted windows). Swallow same-window
    // drops inside the window; windowsMove runs ~300ms so 500ms is safe.
    property string lastDropAddr: ""
    property real lastDropTime: 0

    function dropAllowed(addr: string): bool {
        const now = Date.now();
        if (addr === lastDropAddr && now - lastDropTime < 500)
            return false;
        lastDropAddr = addr;
        lastDropTime = now;
        return true;
    }

    Timer {
        id: verifyTimer
        interval: 150
        repeat: true
        onTriggered: {
            if (root.dragSourceWorkspace !== -1 || root.verifyAddr === "") {
                stop();
                return;
            }
            root.refreshWindows();
            root.verifyTries++;
            const d = windowDataList.find(w => w.address === root.verifyAddr);
            const cur = d ? JSON.stringify([d.wsId, d.posX, d.posY, d.sizeX, d.sizeY]) : "";
            const changed = cur !== root.verifySnapshot;
            const placed = root.verifyTargetWs === -1 || (d && d.wsId === root.verifyTargetWs);
            if ((changed && placed) || root.verifyTries >= 5) {
                stop();
                root.verifyAddr = "";
            }
        }
    }

    function armVerify(addr: string, targetWs: int): void {
        const d = windowDataList.find(w => w.address === addr);
        root.verifyAddr = addr;
        root.verifyTargetWs = targetWs;
        root.verifySnapshot = d ? JSON.stringify([d.wsId, d.posX, d.posY, d.sizeX, d.sizeY]) : "";
        root.verifyTries = 0;
        verifyTimer.restart();
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

    // Border overlay: cell borders must paint above window previews
    // (previews live at z:1 and would otherwise swallow them, leaving
    // sharp preview corners sticking over the rounded frame).
    // Plain Rectangles take no mouse events, so cells stay interactive.
    Item {
        anchors.fill: parent
        z: 2

        Repeater {
            model: root.workspacesShown

            Rectangle {
                required property int index

                property int wsId: root.groupOffset + index + 1
                property bool isCellActive: Number(wsId) === Number(root.activeWsId)
                property bool isDropTarget: root.dragTargetWorkspace === wsId

                x: (index % root.columns) * (root.wsWidth + root.cardSpacing)
                y: Math.floor(index / root.columns) * (root.wsHeight + root.cardSpacing)
                width: root.wsWidth
                height: root.wsHeight
                radius: Tokens.rounding.large
                color: isDropTarget ? Qt.alpha(Colours.palette.m3tertiary, 0.22) : "transparent"
                border.width: isDropTarget ? 3 : 2
                border.color: isDropTarget ? Colours.palette.m3tertiary : isCellActive ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
            }
        }
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
            // Only the current page gets previews; matching still runs over
            // every window, so search can reach other pages.
            if (d.wsId <= root.groupOffset || d.wsId > root.groupOffset + root.workspacesShown)
                continue;
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
                item.title = d.title;
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
                    "title": d.title,
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
        root.syncMatchState();
    }

    Component {
        id: previewComponent

        Rectangle {
            id: prevItem
            radius: Tokens.rounding.large
            color: Colours.palette.m3surfaceContainerHigh
            clip: true

            property string title: ""
            property string winClass: ""
            property var toplevel: null
            property string addr: ""
            property int wsId: 0
            property bool hovered: false
            property bool pressed: false
            property bool matched: true
            property bool selected: false
            property real expectedX: 0
            property real expectedY: 0
            property bool wasDragged: false

            z: Drag.active ? 9999 : 1
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2
            scale: pressed ? 1.05 : 1
            enabled: matched
            opacity: matched ? 1 : 0.18

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

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

            Item {
                z: 1
                anchors {
                    top: parent.top
                    right: parent.right
                    margins: Tokens.spacing.extraSmall
                }
                width: 26
                height: 26

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.rounding.full
                    color: Qt.alpha(Colours.palette.m3surfaceContainer, 0.85)
                    border.width: 1
                    border.color: Qt.alpha(Colours.palette.m3outline, 0.25)
                }

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 18
                    source: Icons.getAppIcon(prevItem.winClass, "image-missing")
                }
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
                width: 28
                height: 28
                radius: Tokens.rounding.full
                color: Colours.palette.m3error
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3onError, 0.3)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "close"
                    color: Colours.palette.m3onError
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
                        root.armVerify(prevItem.addr, -1);
                    }
                }
            }

            // Keyboard selection ring, drawn above the hover tint and the
            // preview so the window Enter will open is always visible.
            Rectangle {
                z: 6
                anchors.fill: parent
                radius: Tokens.rounding.large
                color: "transparent"
                border.width: 3
                border.color: Colours.palette.m3primary
                visible: prevItem.selected
            }

            Rectangle {
                z: 1
                anchors.fill: parent
                radius: Tokens.rounding.large
                color: prevItem.pressed ? Qt.alpha(Colours.palette.m3primary, 0.3) :
                    prevItem.hovered ? Qt.alpha(Colours.palette.m3primary, 0.15) :
                    Qt.alpha(Colours.palette.m3primary, 0.05)
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3outline, 0.12)
            }

            MouseArea {
                id: prevMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
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
                        if (!root.dropAllowed(prevItem.addr)) {
                            prevItem.x = prevItem.expectedX;
                            prevItem.y = prevItem.expectedY;
                            return;
                        }
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
                                // Single nudge along the dominant axis. A second
                                // chained dispatch raced the layout reflow and
                                // left windows stuck half-sized until resized.
                                let dir = "";
                                if (Math.abs(dx) > 20 || Math.abs(dy) > 20)
                                    dir = Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? "r" : "l") : (dy > 0 ? "d" : "u");
                                if (dir !== "") {
                                    Hypr.dispatch(`hl.dsp.window.move({ window = "address:0x${prevItem.addr}", direction = "${dir}" })`);
                                }
                            }
                        }
                        // Optimistic: show the window where it was dropped
                        // instantly; verify-retry reconciles with Hypr truth.
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
                        root.armVerify(prevItem.addr, targetWs);
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
                        if (!root.dropAllowed(srcAddr)) {
                            prevItem.x = prevItem.expectedX;
                            prevItem.y = prevItem.expectedY;
                            return;
                        }
                        Hypr.dispatch(`hl.dsp.window.move({ x = "${moveX}", y = "${moveY}", window = "address:0x${srcAddr}" })`);
                        prevItem.expectedX = prevItem.x;
                        prevItem.expectedY = prevItem.y;
                        prevItem.wasDragged = true;
                        Hyprland.refreshToplevels();
                        root.armVerify(srcAddr, -1);
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
                            if (!root.dropAllowed(srcAddr)) {
                                prevItem.x = prevItem.expectedX;
                                prevItem.y = prevItem.expectedY;
                                return;
                            }
                            Hypr.dispatch(`hl.dsp.window.move({ window = "address:0x${srcAddr}", direction = "${dir}" })`);
                            prevItem.expectedX = prevItem.x;
                            prevItem.expectedY = prevItem.y;
                            prevItem.wasDragged = true;
                            Hyprland.refreshToplevels();
                            root.armVerify(srcAddr, -1);
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
                        root.armVerify(prevItem.addr, -1);
                        return;
                    }
                    root.focusWindow(prevItem.addr);
                }
                onEntered: {
                    prevItem.hovered = true;
                    root.hoveredAddr = prevItem.addr;
                }
                onExited: {
                    prevItem.hovered = false;
                    if (root.hoveredAddr === prevItem.addr)
                        root.hoveredAddr = "";
                }
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
                color: isDropTarget ? Colours.palette.m3surfaceContainerHigh : isCellActive ? Qt.alpha(Colours.palette.m3primary, 0.14) : isEmpty ? Colours.palette.m3surfaceContainerLow : (root.dragSourceWorkspace === wsId ? Qt.alpha(Colours.palette.m3primary, 0.08) : (root.dragSourceWorkspace !== -1 ? Colours.palette.m3surfaceContainerLow : Colours.palette.m3surfaceContainer))

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
                    // Same token as the bar indicator's empty-workspace number
                    color: Colours.palette.m3onSurfaceVariant
                    font.pixelSize: Math.min(parent.width, parent.height) * 0.35
                    font.weight: Font.Bold
                }
            }
        }
    }
}
