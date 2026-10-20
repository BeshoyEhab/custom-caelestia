pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Caelestia.Config
import qs.components.misc
import qs.services

Scope {
    id: root

    property bool opened: false

    function reload(): void {
        if (!bindsProc.running)
            bindsProc.running = true;
    }

    function show(): void {
        root.opened = true;
        root.reload();
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
                title: "Keyboard shortcuts"
                color: "transparent"
                surfaceFormat.opaque: false
                implicitWidth: Math.min(1240, modelData.width * 0.78)
                implicitHeight: Math.min(880, modelData.height * 0.78)
                contentItem.Config.screen: screen.name
                contentItem.Tokens.screen: screen.name

                // The compositor closes a window with SUPER+Q; mirror that back
                // into our state so the next toggle reopens it.
                onVisibleChanged: {
                    if (!visible && root.opened)
                        root.opened = false;
                }

                Content {
                    anchors.fill: parent
                    onClose: root.hide()
                }
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (event.name === "configreloaded" && root.opened)
                root.reload();
        }
    }

    Process {
        id: bindsProc

        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: KeybindsModel.load(text)
        }
    }

    onOpenedChanged: {
        if (root.opened)
            KeybindsModel.query = "";
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
            return `open=${root.opened} groups=${KeybindsModel.groups.length} rows=${KeybindsModel.rows.length} binds=${KeybindsModel.bindCount} query=${KeybindsModel.query}`;
        }

        target: "cheatsheet"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "cheatsheet"
        description: "Toggle cheat sheet"
        onPressed: root.toggle()
    }
}
