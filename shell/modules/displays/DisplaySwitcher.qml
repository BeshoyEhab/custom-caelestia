pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components.misc
import qs.services

Scope {
    id: root

    property bool opened: false

    function show(): void {
        root.retries = 0;
        Displays.refresh();
        root.opened = true;
    }

    function hide(): void {
        root.opened = false;
    }

    function toggle(): void {
        if (root.opened)
            root.hide();
        else
            root.show();
    }

    // One window on the focused screen, not one per screen: this is a
    // single popup, and a per-screen Variants opened a copy on every monitor.
    readonly property ShellScreen targetScreen: Screens.screens.find(s => s.name === Hypr.focusedMonitor?.name) ?? Screens.screens[0] ?? null

    LazyLoader {
        id: loader

        active: root.opened && root.targetScreen !== null

        FloatingWindow {
            id: win

            screen: root.targetScreen
            title: "Displays"
            color: "transparent"
            surfaceFormat.opaque: false
            implicitWidth: card.implicitWidth
            implicitHeight: card.implicitHeight
            contentItem.Config.screen: screen.name
            contentItem.Tokens.screen: screen.name

            // SUPER+Q closes the focused window; keep our state in sync.
            onVisibleChanged: {
                if (!visible && root.opened)
                    root.opened = false;
            }

            Card {
                id: card

                anchors.fill: parent
                onClose: root.hide()
            }
        }
    }

    // The first hyprctl call can land before Hyprland is ready (e.g. right
    // after login) and return no monitors. Keep asking for a few seconds, then
    // stop instead of polling forever; reopening the popup retries.
    property int retries: 0

    Timer {
        interval: 600
        repeat: true
        running: root.opened && Displays.monitors.length === 0 && root.retries < 20
        onTriggered: {
            root.retries++;
            Displays.refresh();
        }
    }

    // `Displays` is a lazy singleton: without a reference at shell start its
    // Component.onCompleted (which runs heal()) never fires, so a broken
    // persisted layout would not be repaired at login. Touch it here.
    Component.onCompleted: Displays.refresh()

    IpcHandler {
        function open(): void {
            root.show();
        }

        function close(): void {
            root.hide();
        }

        function toggle(): void {
            root.toggle();
        }

        function state(): string {
            return `mode=${Displays.mode} main=${Displays.mainName} secondary=${Displays.secondaryName} placement=${Displays.placement} workspace=${Displays.pinnedWorkspace} busy=${Displays.busy} error=${Displays.lastError}`;
        }

        function setMode(mode: string): void {
            Displays.setMode(mode);
        }

        function setMain(name: string): void {
            Displays.setMain(name);
        }

        function setPlacement(placement: string): void {
            Displays.setPlacement(placement);
        }

        function setWorkspace(workspace: int): void {
            Displays.setPinnedWorkspace(workspace);
        }

        function refresh(): void {
            Displays.refresh();
        }

        target: "displays"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "displays"
        description: "Open display switcher"
        onPressed: root.toggle()
    }
}
