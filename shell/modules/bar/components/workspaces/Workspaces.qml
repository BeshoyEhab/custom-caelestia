import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Caelestia
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.services

StyledClippingRect {
    id: root

    required property ShellScreen screen
    required property bool fullscreen
    property var bar

    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property bool onSpecial: monitor?.lastIpcObject.specialWorkspace?.name !== ""
    readonly property int activeWsId: monitor.activeWorkspace?.id ?? 1
    readonly property int activeWsIdx: workspaceIndex(activeWsId)
    readonly property int shown: Math.max(1, Config.bar.workspaces.shown)
    readonly property real circleSize: Tokens.sizes.bar.innerWidth - Tokens.padding.extraSmall * 2
    readonly property real itemStep: circleSize + 2

    // Task 1 keys are source-built, not installed: fall back to true so the
    // bar keeps the fixed-group behaviour until the plugin is reinstalled.
    readonly property bool showUnoccupied: Config.bar.workspaces.showUnoccupied ?? true

    // Single source for the workspace row pitch: matches the pre-rework
    // rhythm (circle + 2px). The LazyListView spacing below uses it, so the
    // classic indicator math stays aligned with the delegates.
    readonly property real wsSpacing: root.itemStep - root.circleSize

    readonly property var wsIds: {
        if (root.showUnoccupied)
            return Array.from({
                length: shown
            }, (_, i) => i + 1);

        const allMonitors = false; // per-monitor filtering is now unconditional
        const ignoredTags = GlobalConfig.bar.workspaces.ignoredTags ?? [];
        // Local Hypr service has no isToplevelIgnored helper; count any
        // mapped toplevel (or IPC-reported windows) when it is absent.
        const hasFilter = typeof Hypr.isToplevelIgnored === "function";
        const workspaces = Hypr.workspaces.values.filter(w => {
            if (!(w.id > 0))
                return false;
            if (!allMonitors && w.monitor !== root.monitor)
                return false;
            if (w.id === activeWsId)
                return true;
            const tops = w.toplevels?.values ?? [];
            if (hasFilter)
                return tops.some(t => !Hypr.isToplevelIgnored(t, ignoredTags));
            return tops.length > 0 || (w.lastIpcObject?.windows ?? 0) > 0;
        });
        const currentIdx = workspaces.findIndex(w => w.id === activeWsId);
        if (currentIdx < 0)
            return [];

        const end = CUtils.clamp(currentIdx + 1, Math.min(shown, workspaces.length), workspaces.length);
        const start = Math.max(0, end - shown);

        return workspaces.slice(start, end).map(w => w.id);
    }

    // Workspace-shaped delegates owned by the LazyListView below. OccupiedBg
    // and GapMarkers consume this array (their delegates require Workspace
    // items exposing .ws/.focused/.y), mirroring upstream exactly. Named
    // workspaceItems (not workspaces): a root property shadows the child
    // LazyListView id of the same name, which made every bare `workspaces.*`
    // read resolve to the array (undefined .spacing/.layoutHeight/.itemAt).
    readonly property var workspaceItems: {
        workspaces.itemsDirty;
        return wsIds.map(id => workspaces.itemAtIndex(workspaceIndex(id)));
    }

    // Only relevant for when showUnoccupied is true
    readonly property int groupOffset: {
        if (!root.showUnoccupied)
            return 0;
        return Math.floor((activeWsId - 1) / shown) * shown;
    }

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

    function workspaceIndex(id: int): int {
        if (!root.showUnoccupied)
            return wsIds.indexOf(id);

        let index = id - 1;
        while (index < 0)
            index += shown;
        return index % shown;
    }

    // Local Hypr service has no focusWorkspace/toggleSpecial helpers;
    // dispatch with the same strings as the upstream implementations.
    function focusWs(ws: int): void {
        if (typeof Hypr.focusWorkspace === "function")
            Hypr.focusWorkspace(ws);
        else
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "${ws}" })` : `workspace ${ws}`);
    }

    function toggleSpecialWs(): void {
        if (typeof Hypr.toggleSpecial === "function")
            Hypr.toggleSpecial("special");
        else
            Hypr.dispatch(Hypr.usingLua ? 'hl.dsp.workspace.toggle_special("special")' : "togglespecialworkspace special");
    }

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: workspaces.layoutHeight + workspaces.anchors.margins * 2

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
            opacity: Config.bar.workspaces.occupiedBg ? 1 : 0
            active: opacity > 0

            anchors.fill: parent
            anchors.margins: Tokens.padding.extraSmall

            sourceComponent: OccupiedBg {
                workspaces: root.workspaceItems
                wsSpacing: root.wsSpacing
            }

            Behavior on opacity {
                enabled: root.animationsReady
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        LazyListView {
            id: workspaces

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.extraSmall
            implicitHeight: contentHeight

            spacing: root.wsSpacing
            removeDuration: Tokens.anim.durations.expressiveDefaultEffects

            model: ScriptModel {
                values: root.wsIds
            }

            delegate: Workspace {
                activeWsId: root.activeWsId
                ws: root.showUnoccupied ? root.groupOffset + index + 1 : modelData
                monitor: root.monitor
                bar: root.bar

                // Backend default is Icons (2); ?? must match it, because
                // per-screen Config reads of never-set keys yield undefined.
                // Prefer the global value: per-screen Config reads of keys
                // absent from shell.json yield undefined here even when the
                // backend default exists. Fallback matches backend default.
                displayType: GlobalConfig.bar.workspaces.displayType ?? Config.bar.workspaces.displayType ?? BarWorkspaceDisplay.Text
                showWindows: Config.bar.workspaces.showWindows
                iconRules: GlobalConfig.bar.workspaces.workspaceIcons ?? []
                activeLabel: Config.bar.workspaces.activeLabel
                occupiedLabel: Config.bar.workspaces.occupiedLabel
                label: Config.bar.workspaces.label
            }
        }

        Loader {
            asynchronous: true
            opacity: root.showUnoccupied ? 0 : 1
            active: opacity > 0

            anchors.fill: parent
            anchors.margins: Tokens.padding.extraSmall

            sourceComponent: GapMarkers {
                workspaces: root.workspaceItems
                wsSpacing: root.wsSpacing
            }

            Behavior on opacity {
                enabled: root.animationsReady
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        // Active disc: solid primary, slides with Emphasized easing. It sits
        // below the delegate list (z:2 above), so numbers/icons stay visible;
        // the focused circle goes transparent to reveal it. Position tracks
        // the live delegate (not pitch math) so variable-height rows with
        // window icons stay aligned.
        Rectangle {
            // Starts on the first workspace every load, then glides to the
            // active one once animations arm.
            property int targetIdx: root.animationsReady ? root.activeWsIdx : 0

            readonly property var targetDelegate: targetIdx >= 0 ? workspaces.itemAtIndex(targetIdx) : null

            x: (root.width - root.circleSize) / 2
            y: targetDelegate ? targetDelegate.y + workspaces.contentY + workspaces.y : -root.circleSize
            width: root.circleSize
            height: root.circleSize
            radius: width / 2
            color: Colours.palette.m3primary
            opacity: (targetIdx >= 0 && targetIdx < root.wsIds.length) && Config.bar.workspaces.activeIndicator ? 1 : 0
            z: 1

            Behavior on y {
                enabled: root.animationsReady
                Anim {
                    type: Anim.Emphasized
                }
            }
            Behavior on opacity {
                enabled: root.animationsReady
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        // Content overlay: numbers + app icons above the active disc (old
        // numbers-layer architecture: circles z:0, disc z:1, content z:2).
        Item {
            id: contentOverlay

            anchors.fill: parent
            z: 2

            function trimWsName(name: string): string {
                if (typeof Hypr.trimWsName === "function")
                    return Hypr.trimWsName(name);
                return name.startsWith("special:") ? name.slice("special:".length) : name;
            }

            Repeater {
                model: root.wsIds.length

                // Fixed-pitch positioning like the classic numbers layer (no
                // delegate lookup: itemAtIndex is null-prone during list
                // transitions and silently blanks the overlay).
                Item {
                    required property int index

                    readonly property int ws: root.showUnoccupied ? root.groupOffset + index + 1 : root.wsIds[index]
                    readonly property bool occupied: {
                        const w = Hypr.workspaces.values.find(w => w.id === ws);
                        return ((w?.lastIpcObject?.windows ?? 0) > 0) || root.activeWsId === ws;
                    }
                    readonly property bool focused: root.activeWsId === ws
                    readonly property string appIcon: {
                        Hypr.appIconsVersion;
                        if (!(Config.bar.workspaces.showAppIcon ?? true) || !occupied)
                            return "";
                        return Hypr.appIconsPerWorkspace[ws] ?? "";
                    }

                    x: workspaces.x
                    width: workspaces.width
                    // Same box as the delegate circle: list offset + pitch.
                    // (No extra padding: workspaces.y already holds the top
                    // margin; adding it again drifts every row downward.)
                    y: workspaces.y + index * root.itemStep
                    height: root.circleSize

                    StyledText {
                        anchors.centerIn: parent
                        visible: parent.appIcon === ""
                        animate: true
                        text: {
                            if (parent.focused) {
                                const label = Config.bar.workspaces.activeLabel;
                                if (label)
                                    return label;
                            }

                            if (parent.focused || parent.occupied) {
                                const label = Config.bar.workspaces.occupiedLabel;
                                if (label)
                                    return label;
                            }

                            const label = Config.bar.workspaces.label;
                            if (label)
                                return label;

                            const w = Hypr.workspaces.values.find(w => w.id === parent.ws);
                            const wsName = !w || w.name == parent.ws ? parent.ws : contentOverlay.trimWsName(w.name)[0];

                            const capitalisation = Config.bar.workspaces.capitalisation;
                            if (capitalisation === BarWorkspaceCapitalisation.Upper || String(capitalisation).toLowerCase() === "upper")
                                return String(wsName).toUpperCase();
                            else if (capitalisation === BarWorkspaceCapitalisation.Lower || String(capitalisation).toLowerCase() === "lower")
                                return String(wsName).toLowerCase();
                            return wsName;
                        }
                        color: parent.focused ? Colours.palette.m3onPrimary : (parent.occupied ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant)
                        verticalAlignment: Qt.AlignVCenter
                        font.family: Tokens.font.workspaces
                    }

                    IconImage {
                        anchors.centerIn: parent
                        visible: parent.appIcon !== ""
                        implicitSize: Tokens.sizes.bar.innerWidth * 0.55
                        source: {
                            Hypr.appIconsVersion;
                            return parent.appIcon ? Quickshell.iconPath(parent.appIcon, "image-missing") : "";
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: workspaces
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: false

            onClicked: event => {
                const ws = (workspaces.itemAt(event.x, event.y) as Workspace)?.ws;
                if (!ws)
                    return;

                if (event.button === Qt.RightButton) {
                    if (root.bar?.popouts) {
                        root.bar.popouts.workspacePreviewId = ws;
                        const wsObj = Hypr.workspaces.values.find(w => w.id === ws);
                        root.bar.popouts.workspacePreviewName = wsObj?.name || ws.toString();
                        root.bar.popouts.currentName = "workspacepreview";
                        root.bar.popouts.currentCenter = mapToItem(root.bar, 0, event.y).y;
                        root.bar.popouts.hasCurrent = true;
                    }
                    return;
                }

                if (Hypr.activeWsId !== ws)
                    root.focusWs(ws);
                else
                    root.toggleSpecialWs();
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

        anchors.fill: parent

        asynchronous: true
        active: opacity > 0
        opacity: root.onSpecial ? 1 : 0

        sourceComponent: Item {
            StyledRect {
                anchors.fill: parent
                radius: Tokens.rounding.full
                color: Qt.alpha(Colours.palette.m3scrim, Colours.light ? 0 : 0.2)
            }

            SpecialWorkspaces {
                anchors.fill: parent
                anchors.margins: Tokens.padding.extraSmall
                monitor: root.monitor

                scale: 0.5
                Component.onCompleted: scale = Qt.binding(() => root.onSpecial ? 1 : 0.5)

                Behavior on scale {
                    enabled: root.animationsReady
                    Anim {}
                }
            }
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

    Behavior on implicitHeight {
        enabled: root.animationsReady
        Anim {}
    }
}
