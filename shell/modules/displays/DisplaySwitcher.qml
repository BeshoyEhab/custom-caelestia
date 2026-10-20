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

    LazyLoader {
        id: loader

        active: root.opened

        Variants {
            model: Screens.screens

            FloatingWindow {
                id: win

                required property ShellScreen modelData

                screen: modelData
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
    }

    // The first hyprctl call can land before Hyprland is ready (e.g. right
    // after login) and return no monitors. Keep asking until one appears.
    Timer {
        interval: 600
        repeat: true
        running: root.opened && Displays.monitors.length === 0
        onTriggered: Displays.refresh()
    }

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
