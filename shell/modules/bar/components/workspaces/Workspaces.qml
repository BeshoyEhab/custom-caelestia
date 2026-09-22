pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services

StyledClippingRect {
    id: root

    required property ShellScreen screen
    required property bool fullscreen
    property var bar

    readonly property bool onSpecial: (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor)?.lastIpcObject.specialWorkspace?.name !== ""
    readonly property int activeWsId: GlobalConfig.bar.workspaces.perMonitorWorkspaces ? (Hypr.monitorFor(screen)?.activeWorkspace?.id ?? 1) : Hypr.activeWsId

    // Upstream v2 ports (logic only — Item root + int-model Repeaters kept):
    // - `perMonitor` maps onto the existing `perMonitorWorkspaces` global key
    //   (custom C++ schema has no `Config.bar.workspaces.perMonitor`).
    // - `showUnoccupied` falls back to true (custom schema has no such key yet),
    //   preserving current fixed-group behaviour until the key is added.
    readonly property bool perMonitor: GlobalConfig.bar.workspaces.perMonitorWorkspaces ?? true
    readonly property bool showUnoccupied: Config.bar.workspaces.showUnoccupied ?? true
    readonly property int shown: Math.max(1, Config.bar.workspaces.shown)
    readonly property int wsCount: root.showUnoccupied ? Config.bar.workspaces.shown : root.wsIds.length

    // Workspace ids to display. Unfiltered path matches upstream
    // (`[1..shown]`); filtered path mirrors upstream windowing around the
    // active workspace, using Math instead of CUtils and tolerating the
    // missing `Hypr.isToplevelIgnored` / `ignoredTags` schema pieces.
    readonly property var wsIds: {
        if (root.showUnoccupied)
            return Array.from({
                length: root.shown
            }, (_, i) => i + 1);

        const allMonitors = !root.perMonitor;
        const mon = Hypr.monitorFor(root.screen);
        const ignoredTags = GlobalConfig.bar.workspaces.ignoredTags ?? [];
        const hasFilter = typeof Hypr.isToplevelIgnored === "function";
        const workspaces = Hypr.workspaces.values.filter(w => {
            if (!(w.id > 0))
                return false;
            if (!allMonitors && w.monitor !== mon)
                return false;
            if (w.id === root.activeWsId)
                return true;
            const tops = w.toplevels?.values ?? [];
            if (hasFilter)
                return tops.some(t => !Hypr.isToplevelIgnored(t, ignoredTags));
            return tops.length > 0 || (w.lastIpcObject?.windows ?? 0) > 0;
        });
        const currentIdx = workspaces.findIndex(w => w.id === root.activeWsId);
        if (currentIdx < 0)
            return [];

        const lo = Math.min(root.shown, workspaces.length);
        const end = Math.min(Math.max(currentIdx + 1, lo), workspaces.length);
        const start = Math.max(0, end - root.shown);

        return workspaces.slice(start, end).map(w => w.id);
    }

    function workspaceIndex(id: int): int {
        if (!root.showUnoccupied)
            return root.wsIds.indexOf(id);

        let index = id - 1;
        while (index < 0)
            index += root.shown;
        return index % root.shown;
    }

    function wsForIndex(idx: int): int {
        if (root.showUnoccupied)
            return root.groupOffset + idx + 1;
        return root.wsIds[idx] ?? 0;
    }

    readonly property int activeWsIdx: root.showUnoccupied ? root.activeWsId - 1 - root.groupOffset : root.wsIds.indexOf(root.activeWsId)

    readonly property var occupied: {
        const occ = {};
        for (const ws of Hypr.workspaces.values)
            occ[ws.id] = ws.lastIpcObject.windows > 0;
        return occ;
    }
    // Only relevant for when showUnoccupied is true (mirrors upstream)
    readonly property int groupOffset: {
        if (!root.showUnoccupied)
            return 0;
        return Math.floor((root.activeWsId - 1) / root.shown) * root.shown;
    }

    readonly property real itemStep: circleSize + 2
    readonly property real circleSize: Tokens.sizes.bar.innerWidth - Tokens.padding.extraSmall * 2

    property real blur: onSpecial ? 1 : 0

    // Instant on fresh Bar load (hover-open): suppress inner replays so the
    // bar feels untouched (only the wrapper slides). Enabled shortly after
    // load so workspace switches animate normally.
    property bool animationsReady: false

    Timer {
        interval: 350
        running: true
        repeat: false
        onTriggered: root.animationsReady = true
    }

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: Config.bar.workspaces.shown * itemStep + Tokens.padding.small

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    Item {
        anchors.fill: parent
        scale: root.onSpecial ? 0.8 : 1
        opacity: root.onSpecial ? 0.5 : 1
        visible: !root.fullscreen || Config.general.showOverFullscreen

        layer.enabled: root.blur > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.blur
            blurMax: 32
        }

        Loader {
            asynchronous: true
            active: true

            anchors.fill: parent
            anchors.margins: Tokens.padding.extraSmall

            sourceComponent: OccupiedBg {
                workspaces: circles
                occupied: root.occupied
                groupOffset: root.groupOffset
            }
        }

        // Upstream v2 GapMarkers (inactive by default: `showUnoccupied`
        // falls back to true until the schema gains the key). The custom C++
        // plugin ships `AnimatedRepeater`, so GapMarkers.qml resolves.
        Loader {
            asynchronous: true
            opacity: root.showUnoccupied ? 0 : 1
            active: opacity > 0

            anchors.fill: parent
            anchors.margins: Tokens.padding.extraSmall

            sourceComponent: GapMarkers {
                workspaces: circles
                wsSpacing: root.itemStep - root.circleSize
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        Repeater {
            id: circles

            model: root.wsCount

            Rectangle {
                required property int index
                readonly property int ws: root.wsForIndex(index)
                readonly property bool isOccupied: root.occupied[ws] ?? false
                readonly property bool isActive: root.activeWsId === ws
                readonly property int size: root.circleSize + 2

                x: (root.width - root.circleSize) / 2
                y: Tokens.padding.extraSmall + index * root.itemStep
                width: root.circleSize
                height: root.circleSize
                radius: width / 2

                color: isOccupied ? Qt.rgba(
                    (Colours.palette.m3primary.r + Colours.tPalette.m3surfaceContainer.r) / 2,
                    (Colours.palette.m3primary.g + Colours.tPalette.m3surfaceContainer.g) / 2,
                    (Colours.palette.m3primary.b + Colours.tPalette.m3surfaceContainer.b) / 2,
                    1
                ) : Colours.palette.m3surfaceContainerHighest
                opacity: isOccupied || isActive ? 1.0 : 0.5
                z: 0

                Behavior on opacity {
                    enabled: root.animationsReady
                    Anim { type: Anim.DefaultEffects }
                }
            }
        }

        Rectangle {
            id: indicator

            property int targetIdx: root.activeWsIdx

            x: (root.width - root.circleSize) / 2
            y: targetIdx >= 0 && targetIdx < root.wsCount
               ? Tokens.padding.extraSmall + targetIdx * root.itemStep
               : -root.circleSize
            width: root.circleSize
            height: root.circleSize
            radius: width / 2
            color: Colours.palette.m3primary
            opacity: targetIdx >= 0 && targetIdx < root.wsCount ? 1 : 0
            z: 1

            Behavior on y {
                enabled: root.animationsReady
                Anim { type: Anim.Emphasized }
            }
            Behavior on opacity {
                enabled: root.animationsReady
                Anim { type: Anim.DefaultEffects }
            }
        }

        Repeater {
            id: numbers

            model: root.wsCount

            Item {
                required property int index
                readonly property int ws: root.wsForIndex(index)
                readonly property bool isOccupied: root.occupied[ws] ?? false
                readonly property bool isActive: root.activeWsId === ws

                readonly property string appIcon: {
                    Hypr.appIconsVersion;
                    if (!Config.bar.workspaces.showAppIcon || !isOccupied)
                        return "";
                    return Hypr.appIconsPerWorkspace[ws] ?? "";
                }
                readonly property bool showAppIcon: appIcon !== ""

                x: (root.width - root.circleSize) / 2
                y: Tokens.padding.extraSmall + index * root.itemStep
                width: root.circleSize
                height: root.circleSize
                z: 2

                MaterialIcon {
                    id: numberIndicator

                    anchors.centerIn: parent
                    visible: !parent.showAppIcon

                    animate: true
                    text: {
                        if (Config.bar.workspaces.showEmptyAsNumber)
                            return parent.ws.toString();
                        if (!parent.isOccupied && !parent.isActive)
                            return "\u2022";
                        const ws = Hypr.workspaces.values.find(w => w.id === parent.ws);
                        const wsName = !ws || ws.name == parent.ws ? parent.ws : ws.name[0];
                        let displayName = wsName.toString();
                        if (Config.bar.workspaces.capitalisation.toLowerCase() === "upper") {
                            displayName = displayName.toUpperCase();
                        } else if (Config.bar.workspaces.capitalisation.toLowerCase() === "lower") {
                            displayName = displayName.toLowerCase();
                        }
                        const label = Config.bar.workspaces.label || displayName;
                        const occupiedLabel = Config.bar.workspaces.occupiedLabel || label;
                        const activeLabel = Config.bar.workspaces.activeLabel || (parent.isOccupied ? occupiedLabel : label);
                        return parent.isActive ? activeLabel : parent.isOccupied ? occupiedLabel : label;
                    }
                    color: parent.isActive ? Colours.palette.m3onPrimary : (parent.isOccupied ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant)
                    verticalAlignment: Qt.AlignVCenter
                    font.family: Tokens.font.workspaces
                    font.pixelSize: parent.isOccupied ? undefined : Tokens.sizes.bar.innerWidth * 0.4
                }

                IconImage {
                    id: appIconDisplay

                    anchors.centerIn: parent
                    visible: parent.showAppIcon

                    implicitSize: Tokens.sizes.bar.innerWidth * 0.55

                    source: {
                        Hypr.appIconsVersion;
                        return parent.appIcon ? Quickshell.iconPath(parent.appIcon, "image-missing") : "";
                    }
                }
            }
        }

        MouseArea {
            x: (root.width - root.circleSize) / 2
            y: Tokens.padding.extraSmall
            width: root.circleSize
            height: root.wsCount * root.itemStep
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: Config.bar.workspaces.workspacePreviewEnabled ?? false

            function getWsFromY(mouseY: real): int {
                const idx = Math.floor((mouseY - Tokens.padding.extraSmall + root.itemStep / 2) / root.itemStep);
                if (idx < 0 || idx >= root.wsCount) return 0;
                const localY = mouseY - (Tokens.padding.extraSmall + idx * root.itemStep);
                if (localY < 0 || localY > root.circleSize) return 0;
                return root.wsForIndex(idx);
            }

            onHoveredChanged: {
                if (!containsMouse || !(Config.bar.workspaces.workspacePreviewEnabled ?? false)) {
                    if (!pressed)
                        root.bar?.popouts && (root.bar.popouts.hasCurrent = false);
                    return;
                }

                const ws = getWsFromY(mouseY);
                if (ws > 0 && root.bar?.popouts) {
                    root.bar.popouts.workspacePreviewId = ws;
                    const wsObj = Hypr.workspaces.values.find(w => w.id === ws);
                    root.bar.popouts.workspacePreviewName = wsObj?.name || ws.toString();
                    root.bar.popouts.currentName = "workspacepreview";
                    root.bar.popouts.currentCenter = mapToItem(root.bar, 0, mouseY).y;
                    root.bar.popouts.hasCurrent = true;
                }
            }
            onClicked: event => {
                const ws = getWsFromY(event.y);
                if (!ws)
                    return;

                if (event.button === Qt.RightButton) {
                    if (root.bar?.popouts) {
                        root.bar.popouts.workspacePreviewId = ws;
                        const wsObj = Hypr.workspaces.values.find(w => w.id === ws);
                        root.bar.popouts.workspacePreviewName = wsObj?.name || ws.toString();
                        root.bar.popouts.currentName = "workspacepreview";
                        root.bar.popouts.currentCenter = root.mapToItem(root.bar, 0, 0).y;
                        root.bar.popouts.hasCurrent = true;
                    }
                    return;
                }

                if (Hypr.activeWsId !== ws)
                    Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "${ws}" })` : `workspace ${ws}`);
                else
                    Hypr.dispatch(Hypr.usingLua ? 'hl.dsp.workspace.toggle_special("special")' : "togglespecialworkspace special");
            }
        }

        Behavior on scale {
            enabled: root.animationsReady
            Anim {}
        }

        Behavior on opacity {
            enabled: root.animationsReady
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Loader {
        id: specialWs

        asynchronous: true

        anchors.fill: parent
        anchors.margins: Tokens.padding.extraSmall

        active: opacity > 0

        scale: root.onSpecial ? 1 : 0.5
        opacity: root.onSpecial ? 1 : 0

        sourceComponent: SpecialWorkspaces {
            screen: root.screen
        }

        Behavior on scale {
            enabled: root.animationsReady
            Anim {}
        }

        Behavior on opacity {
            enabled: root.animationsReady
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Behavior on blur {
        enabled: root.animationsReady
        Anim {
            type: Anim.StandardSmall
        }
    }
}
