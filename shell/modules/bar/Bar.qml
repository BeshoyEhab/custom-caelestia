import "popouts" as BarPopouts
import "components"
import "components/workspaces"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen

    readonly property bool isVertical: Config.bar.positioningEdge === 0 || Config.bar.positioningEdge === 1
    readonly property int vPadding: Tokens.padding.large

    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;

        for (let i = 0; i < topRepeater.count; i++) {
            const loader = topRepeater.itemAt(i);
            const tray = loader?.trayItem;
            if (tray)
                tray.expanded = false;
        }
        for (let i = 0; i < bottomRepeater.count; i++) {
            const loader = bottomRepeater.itemAt(i);
            const tray = loader?.trayItem;
            if (tray)
                tray.expanded = false;
        }
    }

    function findEntry(pos: real): var {
        const topEntry = topLayout.childAt(topLayout.width / 2, topLayout.mapFromItem(root, 0, pos).y);
        if (topEntry?.entryId)
            return topEntry;
        const bottomEntry = bottomLayout.childAt(bottomLayout.width / 2, bottomLayout.mapFromItem(root, 0, pos).y);
        return bottomEntry;
    }

    function checkPopout(pos: real): void {
        const ch = findEntry(pos);

        if (ch?.entryId !== "tray")
            closeTray();

        if (!ch) {
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.entryId;

        if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
            const items = (ch.statusIconsItem).items;
            const icon = items.childAt(items.width / 2, mapToItem(items, 0, pos).y);
            if (icon) {
                popouts.currentName = icon.name;
                popouts.currentCenter = Qt.binding(() => icon.mapToItem(root, 0, icon.implicitHeight / 2).y);
                popouts.hasCurrent = true;
            }
        } else if (id === "tray" && Config.bar.popouts.tray) {
            const tray = ch.trayItem;
            const trayPos = mapToItem(ch, 0, pos).y;
            if (!Config.bar.tray.compact || (tray.expanded && !tray.expandIcon.contains(mapToItem(tray.expandIcon, tray.implicitWidth / 2, trayPos)))) {
                const index = Math.floor(((trayPos - tray.padding * 2 + tray.spacing) / tray.layout.implicitHeight) * tray.items.count);
                const trayItem = tray.items.itemAt(index);
                if (trayItem) {
                    popouts.currentName = `traymenu${index}`;
                    popouts.currentCenter = Qt.binding(() => trayItem.mapToItem(root, 0, trayItem.implicitHeight / 2).y);
                    popouts.hasCurrent = true;
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
                tray.expanded = true;
            }
        } else if (id === "activeWindow" && Config.bar.popouts.activeWindow && Config.bar.activeWindow.showOnHover) {
            popouts.currentName = id.toLowerCase();
            popouts.currentCenter = ch.activeWindowItem.mapToItem(root, 0, ch.activeWindowItem.implicitHeight / 2).y ?? 0;
            popouts.hasCurrent = true;
        }
    }

    function handleWheel(pos: real, angleDelta: point): void {
        const ch = findEntry(pos);
        if (ch?.entryId === "workspaces" && Config.bar.scrollActions.workspaces) {
            const mon = (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.workspace.toggle_special("${specialWs.slice(8)}")` : `togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? mon.activeWorkspace?.id : Hypr.activeWsId) > 1)
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

    readonly property var topEntries: ["logo", "workspaces"]
    readonly property var bottomEntries: ["tray", "clock", "statusIcons", "power"]

    ColumnLayout {
        id: topLayout

        anchors.top: parent.top
        anchors.topMargin: root.vPadding
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.width

        spacing: Tokens.spacing.medium

        Repeater {
            id: topRepeater

            model: ScriptModel {
                values: Config.bar.entries.filter(e => (e.enabled ?? true) && root.topEntries.includes(e.id))
            }

            delegate: TopLoader {}
        }
    }

    Loader {
        id: activeWindowLoader

        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: (topLayout.height - bottomLayout.height) / 2
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.width

        active: true

        sourceComponent: ActiveWindow {
            bar: root
            monitor: Brightness.getMonitorForScreen(root.screen)
        }
    }

    ColumnLayout {
        id: bottomLayout

        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.vPadding
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.width

        spacing: Tokens.spacing.medium

        Repeater {
            id: bottomRepeater

            model: ScriptModel {
                values: Config.bar.entries.filter(e => (e.enabled ?? true) && root.bottomEntries.includes(e.id))
            }

            delegate: BottomLoader {}
        }
    }

    Component {
        id: logoComp
        OsIcon {}
    }
    Component {
        id: workspacesComp
        Workspaces {
            screen: root.screen
            fullscreen: root.fullscreen
        }
    }
    Component {
        id: trayComp
        Tray {}
    }
    Component {
        id: clockComp
        Clock {}
    }
    Component {
        id: statusIconsComp
        StatusIcons {}
    }
    Component {
        id: powerComp
        Power {
            visibilities: root.visibilities
        }
    }

    component TopLoader: Loader {
        required property var modelData

        readonly property string entryId: modelData.id
        property var trayItem: item as Tray

        Layout.alignment: Qt.AlignHCenter

        active: true

        sourceComponent: {
            switch (entryId) {
            case "logo": return logoComp
            case "workspaces": return workspacesComp
            default: return null
            }
        }
    }

    component BottomLoader: Loader {
        required property var modelData

        readonly property string entryId: modelData.id
        property var trayItem: item as Tray
        property var statusIconsItem: item as StatusIcons

        Layout.alignment: Qt.AlignHCenter

        active: true

        sourceComponent: {
            switch (entryId) {
            case "tray": return trayComp
            case "clock": return clockComp
            case "statusIcons": return statusIconsComp
            case "power": return powerComp
            default: return null
            }
        }
    }
}
