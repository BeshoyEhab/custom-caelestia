import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Caelestia
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services

Item {
    id: root

    required property HyprlandMonitor monitor

    readonly property int activeSpecialId: monitor?.lastIpcObject.specialWorkspace?.id ?? 0
    readonly property var wsIds: {
        const allMonitors = false; // per-monitor filtering is now unconditional
        return Hypr.workspaces.values.filter(w => w.name.startsWith("special:") && (allMonitors || w.monitor === root.monitor)).map(w => w.id);
    }
    readonly property int activeIdx: wsIds.indexOf(activeSpecialId)
    readonly property real maxViewY: Math.max(0, view.contentHeight - height)

    // Overlay box = the delegate circle; fallback pitch matches a compact
    // (strip-less) delegate for when live delegates are absent mid-transition.
    readonly property real circleSize: Tokens.sizes.bar.innerWidth - Tokens.padding.extraSmall * 2

    readonly property Workspace activeWs: {
        // count/itemsDirty: itemAtIndex is a plain function call, so without
        // these the binding never re-evaluates when delegates appear.
        view.itemsDirty;
        view.count;
        return view.itemAtIndex(activeIdx) as Workspace;
    }

    // Instant on fresh Bar load (hover-open): suppress scroll/opacity
    // replays. Enabled shortly after load so interactions animate normally.
    property bool animationsReady: false

    Timer {
        interval: 350
        running: true
        repeat: false
        onTriggered: root.animationsReady = true
    }

    // Local Hypr service has no toggleSpecial/trimWsName helpers; dispatch
    // with the same strings as the upstream implementations.
    function toggleSpecialByName(name: string): void {
        const clean = (typeof Hypr.trimWsName === "function" ? Hypr.trimWsName(name) : name.startsWith("special:") ? name.slice("special:".length) : name);
        if (typeof Hypr.toggleSpecial === "function")
            Hypr.toggleSpecial(clean);
        else
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.workspace.toggle_special("${clean}")` : `togglespecialworkspace ${clean}`);
    }

    function ensureVisible(animate = true): void {
        if (!activeWs)
            return;

        const top = activeWs.LazyListView.layoutY;
        const bottom = top + activeWs.LazyListView.preferredHeight;

        let target = view.y;
        if (top < -target)
            target = -top;
        else if (bottom > -target + height)
            target = -(bottom - height);

        target = CUtils.clamp(target, -maxViewY, 0);
        if (target !== view.y) {
            if (animate) {
                const type = viewYAnim.type;
                viewYAnim.type = Anim.DefaultSpatial;
                view.y = target;
                viewYAnim.type = type;
            } else {
                viewYBehavior.enabled = false;
                view.y = target;
                viewYBehavior.enabled = true;
            }
        }
    }

    onActiveWsChanged: ensureVisible()
    onHeightChanged: ensureVisible(false)
    Component.onCompleted: ensureVisible(false)
    onMaxViewYChanged: ensureVisible()

    layer.enabled: true
    layer.effect: Mask {
        maskSource: mask
    }

    Connections {
        function onLayoutYChanged(): void {
            root.ensureVisible();
        }

        function onPreferredHeightChanged(): void {
            root.ensureVisible();
        }

        target: root.activeWs?.LazyListView ?? null
    }

    Item {
        id: mask

        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: Tokens.rounding.full

            gradient: Gradient {
                orientation: Gradient.Vertical

                GradientStop {
                    position: 0
                    color: Qt.rgba(0, 0, 0, 0)
                }
                GradientStop {
                    position: 0.2
                    color: Qt.rgba(0, 0, 0, 1)
                }
                GradientStop {
                    position: 0.8
                    color: Qt.rgba(0, 0, 0, 1)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(0, 0, 0, 0)
                }
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right

            radius: Tokens.rounding.full
            implicitHeight: parent.height / 2
            opacity: view.y < -Tokens.padding.extraSmall ? 0 : 1

            Behavior on opacity {
                enabled: root.animationsReady
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right

            radius: Tokens.rounding.full
            implicitHeight: parent.height / 2
            opacity: view.y > -root.maxViewY + Tokens.padding.extraSmall ? 0 : 1

            Behavior on opacity {
                enabled: root.animationsReady
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }
    }

    // Active pill lives BELOW the delegates (z:0, file order): the
    // focused circle is transparent so the pill shows through it, and
    // strip icons paint over the pill. Circle-wide so empty rows read
    // as exact circles.
    Loader {
        asynchronous: true
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.circleSize
        // Gate on a real target: without it the pill renders at a stale
        // position when no special workspace is open.
        active: Config.bar.workspaces.activeIndicator && root.activeIdx >= 0
        z: 0

        sourceComponent: ActiveIndicator {
            activeWs: root.activeWs
            mask: view
            color: Colours.palette.m3primary
        }
    }

    LazyListView {
        id: view

        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: contentHeight

        // Same rhythm as the normal list, including room for the active
        // trail's tail (see wsSpacing there) so the pill never touches
        // the next workspace.
        spacing: Tokens.spacing.extraSmall / 2 + 7
        removeDuration: Tokens.anim.durations.expressiveDefaultEffects

        onContentHeightChanged: root.ensureVisible()

        model: ScriptModel {
            values: root.wsIds
        }

        delegate: Workspace {
            activeWsId: root.activeSpecialId
            ws: modelData
            monitor: root.monitor
            offMonitorColour: Colours.palette.m3outline
            showWindows: Config.bar.workspaces.showWindowsOnSpecialWorkspaces
            displayType: Config.bar.workspaces.specialDisplayType ?? BarWorkspaceDisplay.Icons
            showAppIcon: Config.bar.workspaces.showAppIconOnSpecialWorkspaces ?? true
        }

        Behavior on y {
            id: viewYBehavior

            enabled: root.animationsReady

            Anim {
                id: viewYAnim

                type: Anim.FastEffects
            }
        }
    }

    // Content overlay: numbers + app icons above the highlight pill
    // (same layering as the normal list).
    Item {
        anchors.fill: parent
        z: 2

        Repeater {
            model: root.wsIds.length

                Item {
                    required property int index

                    // Live delegate position when available (exact with
                    // window rows), fixed pitch fallback (matches normal
                    // list rhythm when delegates are absent mid-transition).
                    readonly property var delegate: view.itemAtIndex(index)
                    readonly property int ws: root.wsIds[index]
                readonly property bool occupied: {
                    const w = Hypr.workspaces.values.find(w => w.id === ws);
                    return ((w?.lastIpcObject?.windows ?? 0) > 0) || root.activeSpecialId === ws;
                }
                readonly property bool focused: root.activeSpecialId === ws

                    x: view.x
                    width: view.width
                    y: view.y + (delegate ? delegate.y + view.contentY : index * (root.circleSize + view.spacing))
                    height: root.circleSize

                    // Shared look with the normal list; special settings.
                    WorkspaceContent {
                        anchors.fill: parent
                        ws: parent.ws
                        occupied: parent.occupied
                        focused: parent.focused
                        displayType: Config.bar.workspaces.specialDisplayType ?? BarWorkspaceDisplay.Icons
                        showAppIcon: Config.bar.workspaces.showAppIconOnSpecialWorkspaces ?? true
                        activeLabel: Config.bar.workspaces.activeLabel
                        occupiedLabel: Config.bar.workspaces.occupiedLabel
                        label: Config.bar.workspaces.label
                        capitalisation: Config.bar.workspaces.capitalisation
                    }
            }
        }
    }

    MouseArea {
        property real startY
        property real startViewY
        property bool dragging

        anchors.fill: parent

        onPressed: event => {
            startY = event.y;
            startViewY = view.y;
            dragging = false;
        }

        onPositionChanged: event => {
            if (!dragging && Math.abs(event.y - startY) > drag.threshold)
                dragging = true;

            if (dragging)
                view.y = CUtils.clamp(startViewY + (event.y - startY), -root.maxViewY, 0);
        }

        onClicked: event => {
            if (dragging)
                return;

            const ws = view.itemAt(event.x, event.y - view.y) as Workspace;
            if (ws) {
                const match = Hypr.workspaces.values.find(w => w.id === ws.ws);
                if (match)
                    root.toggleSpecialByName(match.name);
            } else {
                root.toggleSpecialByName("special");
            }
        }
    }
}
