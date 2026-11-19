import "popouts" as BarPopouts
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.widgets
import "../widgets/WidgetRegistry.js" as Registry

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen

    readonly property bool isVertical: GlobalConfig.bar.positioningEdge === 0 || GlobalConfig.bar.positioningEdge === 1
    readonly property int vPadding: Tokens.padding.large

    // The dock's widget lists come from Config.bar.entries through the
    // registry: each region keeps only its own ids, drops spacers and unknown
    // ids, and merges each widget's default options.
    readonly property var startItems: Registry.fromBarEntries(Config.bar.entries, "start")
    readonly property var centerItems: Registry.fromBarEntries(Config.bar.entries, "center")
    readonly property var endItems: Registry.fromBarEntries(Config.bar.entries, "end")

    readonly property int activeWindowMaxHeight: Math.max(0, centerWrapper.height - root.vPadding * 2)

    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;

        const hosts = [startHost, endHost];
        for (let h = 0; h < hosts.length; h++) {
            const frames = hosts[h].frames;
            for (let i = 0; i < frames.length; i++) {
                const frame = frames[i];
                if (frame?.entryId !== "tray")
                    continue;
                const tray = frame.widgetItem;
                if (tray)
                    tray.expanded = false;
            }
        }
    }

    function findEntry(pos: real): var {
        // The active window region first, matching the old ordering.
        const hosts = [centerHost, startHost, endHost];
        for (let i = 0; i < hosts.length; i++) {
            const host = hosts[i];
            const p = host.mapFromItem(root, 0, pos);
            const frame = host.hitTest(host.width / 2, p.y);
            if (frame)
                return frame;
        }
        return null;
    }

    // Hovering an entry waits popouts.hoverDelay before its popout opens, so
    // sweeping the cursor across the bar neither opens every menu it crosses
    // nor replaces the open one on the way.
    property string pendingPopoutName
    property var pendingPopoutCenter

    function requestPopout(name: string, centerFn: var): void {
        if (popouts.hasCurrent && popouts.currentName === name) {
            cancelPendingPopout();
            popouts.cancelClose();
            return;
        }
        if (pendingPopoutName === name)
            return;
        pendingPopoutName = name;
        pendingPopoutCenter = centerFn;
        popoutOpenTimer.restart();
    }

    function cancelPendingPopout(): void {
        pendingPopoutName = "";
        pendingPopoutCenter = null;
        popoutOpenTimer.stop();
    }

    function commitPendingPopout(): void {
        if (pendingPopoutName === "")
            return;
        const name = pendingPopoutName;
        const centerFn = pendingPopoutCenter;
        cancelPendingPopout();
        popouts.cancelClose();
        popouts.currentName = name;
        popouts.currentCenter = Qt.binding(centerFn);
        popouts.hasCurrent = true;
    }

    Timer {
        id: popoutOpenTimer

        interval: popouts.hoverDelay
        onTriggered: root.commitPendingPopout()
    }

    function checkPopout(pos: real): void {
        const ch = findEntry(pos);

        if (ch?.entryId !== "tray")
            closeTray();

        if (!ch) {
            cancelPendingPopout();
            popouts.closeSoon();
            return;
        }

        const id = ch.entryId;

        if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
            const items = ch.widgetItem?.items;
            const icon = items ? items.childAt(items.width / 2, mapToItem(items, 0, pos).y) : null;
            if (icon) {
                requestPopout(icon.name, () => icon.mapToItem(root, 0, icon.implicitHeight / 2).y);
            } else {
                cancelPendingPopout();
                popouts.closeSoon();
            }
        } else if (id === "tray" && Config.bar.popouts.tray) {
            const tray = ch.widgetItem;
            const trayPos = mapToItem(ch, 0, pos).y;
            if (!tray) {
                cancelPendingPopout();
                popouts.closeSoon();
            } else if (!Config.bar.tray.compact || (tray.expanded && !tray.expandIcon.contains(mapToItem(tray.expandIcon, tray.implicitWidth / 2, trayPos)))) {
                const index = Math.floor(((trayPos - tray.padding * 2 + tray.spacing) / tray.layout.implicitHeight) * tray.items.count);
                const trayItem = tray.items.itemAt(index);
                if (trayItem) {
                    requestPopout(`traymenu${index}`, () => trayItem.mapToItem(root, 0, trayItem.implicitHeight / 2).y);
                } else {
                    cancelPendingPopout();
                    popouts.closeSoon();
                }
            } else {
                cancelPendingPopout();
                popouts.closeSoon();
                tray.expanded = true;
            }
        } else if (id === "activeWindow" && Config.bar.popouts.activeWindow && Config.bar.activeWindow.showOnHover) {
            requestPopout(id.toLowerCase(), () => {
                const aw = ch.widgetItem;
                if (!aw)
                    return 0;
                return aw.mapToItem(root, 0, aw.implicitHeight / 2).y ?? 0;
            });
        } else {
            cancelPendingPopout();
        }
    }

    function handleWheel(pos: real, angleDelta: point): void {
        const ch = findEntry(pos);
        if (ch?.entryId === "workspaces" && Config.bar.scrollActions.workspaces) {
            const mon = Hypr.monitorFor(screen);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.workspace.toggle_special("${specialWs.slice(8)}")` : `togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || mon.activeWorkspace?.id > 1)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "r${angleDelta.y > 0 ? "-" : "+"}1" })` : `workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
        } else if (pos < screen.height / 2 && Config.bar.scrollActions.volume) {
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            const monitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
        }
    }

    WidgetHost {
        id: startHost

        anchors.top: parent.top
        anchors.topMargin: root.vPadding
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.width

        spacing: Tokens.spacing.medium

        items: root.startItems
        hostContext: root
    }

    Item {
        id: centerWrapper

        anchors.top: startHost.bottom
        anchors.bottom: endHost.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.width

        clip: true

        WidgetHost {
            id: centerHost

            anchors.verticalCenter: parent.verticalCenter
            width: root.width

            spacing: Tokens.spacing.medium

            items: root.centerItems
            hostContext: root
        }
    }

    WidgetHost {
        id: endHost

        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.vPadding
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.width

        spacing: Tokens.spacing.medium

        items: root.endItems
        hostContext: root
    }
}
