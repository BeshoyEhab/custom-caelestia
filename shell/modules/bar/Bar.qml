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

        for (const repeater of [topRepeater, bottomRepeater, leftRepeater, rightRepeater]) {
            for (let i = 0; i < repeater.count; i++) {
                const tray = repeater.itemAt(i)?.trayItem;
                if (tray)
                    tray.expanded = false;
            }
        }
    }

    // pos is a coordinate along the bar's main axis (y when vertical, x when horizontal)
    function findEntry(pos: real): var {
        // Check active window first
        const awLoader = root.isVertical ? activeWindowLoader : horizontalActiveWindowLoader;
        const awWrapper = awLoader.item;
        if (awWrapper) {
            if (root.isVertical) {
                const localPos = awWrapper.mapFromItem(root, 0, pos);
                if (localPos.y >= 0 && localPos.y < awWrapper.height) {
                    return {
                        entryId: "activeWindow",
                        activeWindowItem: awWrapper.activeWindowItem
                    };
                }
            } else {
                const localPos = awWrapper.mapFromItem(root, pos, 0);
                if (localPos.x >= 0 && localPos.x < awWrapper.width) {
                    return {
                        entryId: "activeWindow",
                        activeWindowItem: awWrapper.activeWindowItem
                    };
                }
            }
        }
        if (root.isVertical) {
            const topEntry = topLayout.childAt(topLayout.width / 2, topLayout.mapFromItem(root, 0, pos).y);
            if (topEntry?.entryId)
                return topEntry;
            const bottomEntry = bottomLayout.childAt(bottomLayout.width / 2, bottomLayout.mapFromItem(root, 0, pos).y);
            return bottomEntry;
        }
        const leftEntry = leftLayout.childAt(leftLayout.mapFromItem(root, pos, 0).x, leftLayout.height / 2);
        if (leftEntry?.entryId)
            return leftEntry;
        const rightEntry = rightLayout.childAt(rightLayout.mapFromItem(root, pos, 0).x, rightLayout.height / 2);
        return rightEntry;
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
        } else if (id === "workspaces" && Config.bar.workspaces.workspacePreviewEnabled) {
            const workspacesItem = ch.workspacesItem;
            if (workspacesItem) {
                const localPos = mapToItem(workspacesItem, 0, pos);
                const layout = workspacesItem.contentItem?.children[1]?.children[0]; // ColumnLayout > Repeater > Workspace
                if (layout) {
                    const child = layout.childAt(localPos.x, localPos.y);
                    if (child?.isWorkspace) {
                        popouts.workspacePreviewId = child.ws;
                        const wsObj = Hypr.workspaces.values.find(w => w.id === child.ws);
                        popouts.workspacePreviewName = wsObj?.name || child.ws.toString();
                        popouts.currentName = "workspacepreview";
                        popouts.currentCenter = child.mapToItem(root, 0, child.implicitHeight / 2).y;
                        popouts.hasCurrent = true;
                        return;
                    }
                }
            }
            popouts.hasCurrent = false;
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
        } else if (pos < (root.isVertical ? screen.height : screen.width) / 2 && Config.bar.scrollActions.volume) {
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

        visible: root.isVertical
        anchors.top: parent.top
        anchors.topMargin: root.vPadding
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.width

        spacing: Tokens.spacing.medium

        Repeater {
            id: topRepeater

            model: ScriptModel {
                values: root.isVertical ? Config.bar.entries.filter(e => (e.enabled ?? true) && root.topEntries.includes(e.id)) : []
            }

            delegate: TopLoader {}
        }
    }

    RowLayout {
        id: leftLayout

        visible: !root.isVertical
        anchors.left: parent.left
        anchors.leftMargin: root.vPadding
        anchors.verticalCenter: parent.verticalCenter
        height: root.height

        spacing: Tokens.spacing.medium

        Repeater {
            id: leftRepeater

            model: ScriptModel {
                values: !root.isVertical ? Config.bar.entries.filter(e => (e.enabled ?? true) && root.topEntries.includes(e.id)) : []
            }

            delegate: LeftLoader {}
        }
    }

    Loader {
        id: activeWindowLoader

        visible: root.isVertical
        anchors.top: topLayout.bottom
        anchors.bottom: bottomLayout.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.width

        active: root.isVertical

        clip: true

        sourceComponent: ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: root.vPadding
            anchors.bottomMargin: root.vPadding
            property alias activeWindowItem: activeWindow
            readonly property int availableHeight: height

            Item { Layout.fillHeight: true }

            ActiveWindow {
                id: activeWindow
                bar: root
                monitor: Brightness.getMonitorForScreen(root.screen)
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                maxHeight: availableHeight
            }

            Item { Layout.fillHeight: true }
        }
    }

    Loader {
        id: horizontalActiveWindowLoader

        visible: !root.isVertical
        anchors.left: leftLayout.right
        anchors.right: rightLayout.left
        anchors.verticalCenter: parent.verticalCenter
        height: root.height

        active: !root.isVertical

        clip: true

        sourceComponent: RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.vPadding
            anchors.rightMargin: root.vPadding
            property alias activeWindowItem: activeWindow
            readonly property int availableWidth: width

            Item { Layout.fillWidth: true }

            ActiveWindow {
                id: activeWindow
                bar: root
                monitor: Brightness.getMonitorForScreen(root.screen)
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                // Vertical-oriented component; capped to fit until the
                // horizontal variant lands (see docs/plans/bar-position.md)
                width: Math.min(implicitWidth, availableWidth)
            }

            Item { Layout.fillWidth: true }
        }
    }

    ColumnLayout {
        id: bottomLayout

        visible: root.isVertical
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.vPadding
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.width

        spacing: Tokens.spacing.medium

        Repeater {
            id: bottomRepeater

            model: ScriptModel {
                values: root.isVertical ? Config.bar.entries.filter(e => (e.enabled ?? true) && root.bottomEntries.includes(e.id)) : []
            }

            delegate: BottomLoader {}
        }
    }

    RowLayout {
        id: rightLayout

        visible: !root.isVertical
        anchors.right: parent.right
        anchors.rightMargin: root.vPadding
        anchors.verticalCenter: parent.verticalCenter
        height: root.height

        spacing: Tokens.spacing.medium

        Repeater {
            id: rightRepeater

            model: ScriptModel {
                values: !root.isVertical ? Config.bar.entries.filter(e => (e.enabled ?? true) && root.bottomEntries.includes(e.id)) : []
            }

            delegate: RightLoader {}
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

        active: root.isVertical

        sourceComponent: {
            switch (entryId) {
            case "logo": return logoComp
            case "workspaces": return workspacesComp
            default: return null
            }
        }
    }

    component LeftLoader: Loader {
        required property var modelData

        readonly property string entryId: modelData.id
        property var trayItem: item as Tray

        Layout.alignment: Qt.AlignVCenter

        active: !root.isVertical

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

        active: root.isVertical

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

    component RightLoader: Loader {
        required property var modelData

        readonly property string entryId: modelData.id
        property var trayItem: item as Tray
        property var statusIconsItem: item as StatusIcons

        Layout.alignment: Qt.AlignVCenter

        active: !root.isVertical

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
