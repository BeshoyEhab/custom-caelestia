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
    readonly property var barContent: barLoader.item

    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;

        const rep = barContent?.repeater;
        if (!rep) return;
        for (let i = 0; i < rep.count; i++) {
            const entry = rep.itemAt(i);
            const tray = entry?.item as Tray;
            if (tray)
                tray.expanded = false;
        }
    }

    function checkPopout(pos: real): void {
        const rep = barContent?.repeater;
        if (!rep) return;

        const ch = isVertical
            ? rep.childAt(rep.width / 2, pos)
            : rep.childAt(pos, rep.height / 2);

        if (ch?.entryId !== "tray")
            closeTray();

        if (!ch) {
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.entryId;
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
        const rep = barContent?.repeater;
        if (!rep) return;

        const ch = isVertical
            ? rep.childAt(rep.width / 2, pos)
            : rep.childAt(pos, rep.height / 2);

        if (ch?.entryId === "workspaces" && Config.bar.scrollActions.workspaces) {
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
            property alias repeater: repeaterV

            spacing: Tokens.spacing.medium

            Repeater {
                id: repeaterV
                model: ScriptModel {
                    values: Config.bar.entries.filter(e => e.enabled ?? true)
                }
                delegate: EntryDelegate {}
            }
        }
    }

    Component {
        id: horizontalBar

        RowLayout {
            property alias repeater: repeaterH

            spacing: Tokens.spacing.medium

            Repeater {
                id: repeaterH
                model: ScriptModel {
                    values: Config.bar.entries.filter(e => e.enabled ?? true)
                }
                delegate: EntryDelegate {}
            }
        }
    }

    component EntryDelegate: Item {
        required property var modelData
        required property int index
        property alias item: contentItem.children
        readonly property string entryId: modelData.id

        Layout.topMargin: index === 0 ? root.vPadding : 0
        Layout.bottomMargin: index === (barContent?.repeater?.count ?? 0) - 1 ? root.vPadding : 0
        Layout.alignment: root.isVertical ? Qt.AlignHCenter : Qt.AlignVCenter
        Layout.fillWidth: !root.isVertical && (entryId === "activeWindow" || entryId === "spacer")
        Layout.fillHeight: root.isVertical && entryId === "spacer"

        implicitWidth: contentItem.childrenRect.width
        implicitHeight: contentItem.childrenRect.height

        Item {
            id: contentItem
            anchors.fill: parent

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

            Loader {
                anchors.fill: parent
                active: true
                sourceComponent: {
                    switch (entryId) {
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
            }
        }
    }
}
