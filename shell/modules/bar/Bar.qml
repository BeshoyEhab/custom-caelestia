pragma ComponentBehavior: Bound

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
    readonly property var activeRepeater: barLoader.item ? barLoader.item.children[0] : null

    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;

        const rep = activeRepeater;
        for (let i = 0; i < rep.count; i++) {
            const loader = rep.itemAt(i) as WrappedLoader;
            if (loader?.enabled && loader.id === "tray") {
                (loader.item as Tray).expanded = false;
            }
        }
    }

    function checkPopout(pos: real): void {
        const rep = activeRepeater;
        const ch = isVertical
            ? rep.childAt(rep.width / 2, pos) as WrappedLoader
            : rep.childAt(pos, rep.height / 2) as WrappedLoader;

        if (ch?.id !== "tray")
            closeTray();

        if (!ch) {
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.id;
        const top = isVertical ? ch.y : ch.x;

        if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
            const items = (ch.item as StatusIcons).items;
            const icon = isVertical
                ? items.childAt(items.width / 2, mapToItem(items, 0, pos).y)
                : items.childAt(mapToItem(items, pos, 0).x, items.height / 2);
            if (icon) {
                popouts.currentName = icon.name;
                if (isVertical)
                    popouts.currentCenter = Qt.binding(() => icon.mapToItem(root, 0, icon.implicitHeight / 2).y);
                else
                    popouts.currentCenter = Qt.binding(() => icon.mapToItem(root, icon.implicitWidth / 2, 0).x);
                popouts.hasCurrent = true;
            }
        } else if (id === "tray" && Config.bar.popouts.tray) {
            const tray = ch.item as Tray;
            const trayExtent = isVertical ? tray.implicitHeight : tray.implicitWidth;
            const trayPos = isVertical
                ? mapToItem(ch, 0, pos).y
                : mapToItem(ch, pos, 0).x;
            if (!Config.bar.tray.compact || (tray.expanded && !tray.expandIcon.contains(mapToItem(tray.expandIcon, tray.implicitWidth / 2, trayPos)))) {
                const index = Math.floor(((trayPos - tray.padding * 2 + tray.spacing) / tray.layout.implicitHeight) * tray.items.count);
                const trayItem = tray.items.itemAt(index);
                if (trayItem) {
                    popouts.currentName = `traymenu${index}`;
                    if (isVertical)
                        popouts.currentCenter = Qt.binding(() => trayItem.mapToItem(root, 0, trayItem.implicitHeight / 2).y);
                    else
                        popouts.currentCenter = Qt.binding(() => trayItem.mapToItem(root, trayItem.implicitWidth / 2, 0).x);
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
            if (isVertical)
                popouts.currentCenter = (ch.item as Item).mapToItem(root, 0, (ch.item as Item).implicitHeight / 2).y ?? 0;
            else
                popouts.currentCenter = (ch.item as Item).mapToItem(root, (ch.item as Item).implicitWidth / 2, 0).x ?? 0;
            popouts.hasCurrent = true;
        }
    }

    function handleWheel(pos: real, angleDelta: point): void {
        const rep = activeRepeater;
        const ch = isVertical
            ? rep.childAt(rep.width / 2, pos) as WrappedLoader
            : rep.childAt(pos, rep.height / 2) as WrappedLoader;
        if (ch?.id === "workspaces" && Config.bar.scrollActions.workspaces) {
            const mon = (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.workspace.toggle_special("${specialWs.slice(8)}")` : `togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? mon.activeWorkspace?.id : Hypr.activeWsId) > 1)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "r${angleDelta.y > 0 ? "-" : "+"}1" })` : `workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
        } else if (angleDelta.y !== 0) {
            const halfSize = isVertical ? screen.height / 2 : screen.width / 2;
            if (pos < halfSize && Config.bar.scrollActions.volume) {
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
    }

    Loader {
        id: barLoader
        anchors.fill: parent
        active: true
        sourceComponent: root.isVertical ? verticalBar : horizontalBar
    }

    Component {
        id: verticalBar

        ColumnLayout {
            spacing: Tokens.spacing.medium

            Repeater {
                id: repeaterV
                model: Config.bar.entries
                delegate: barDelegate
            }
        }
    }

    Component {
        id: horizontalBar

        RowLayout {
            spacing: Tokens.spacing.medium

            Repeater {
                id: repeaterH
                model: Config.bar.entries
                delegate: barDelegate
            }
        }
    }

    Component {
        id: barDelegate

        Loader {
            id: barLoader
            required property bool enabled
            required property string id
            required property int index

            property var repeater: root.activeRepeater

            function findFirstEnabled(): Item {
                const rep = repeater;
                const count = rep.count;
                for (let i = 0; i < count; i++) {
                    const item = rep.itemAt(i);
                    if (item?.enabled)
                        return item;
                }
                return null;
            }

            function findLastEnabled(): Item {
                const rep = repeater;
                for (let i = rep.count - 1; i >= 0; i--) {
                    const item = rep.itemAt(i);
                    if (item?.enabled)
                        return item;
                }
                return null;
            }

            asynchronous: true
            Layout.alignment: root.isVertical ? Qt.AlignHCenter : Qt.AlignVCenter
            Layout.topMargin: root.isVertical && findFirstEnabled() === this ? root.vPadding : 0
            Layout.bottomMargin: root.isVertical && findLastEnabled() === this ? root.vPadding : 0
            Layout.leftMargin: !root.isVertical && findFirstEnabled() === this ? root.vPadding : 0
            Layout.rightMargin: !root.isVertical && findLastEnabled() === this ? root.vPadding : 0

            visible: enabled
            active: enabled

            sourceComponent: {
                switch (id) {
                case "logo": return logoComp
                case "workspaces": return workspacesComp
                case "activeWindow": return activeWindowComp
                case "tray": return trayComp
                case "clock": return clockComp
                case "statusIcons": return statusIconsComp
                case "power": return powerComp
                default: return null
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
                    bar: root
                }
            }
            Component {
                id: activeWindowComp
                ActiveWindow {
                    bar: root
                    monitor: Brightness.getMonitorForScreen(root.screen)
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
        }
    }
}
