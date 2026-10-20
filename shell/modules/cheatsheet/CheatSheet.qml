pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.components.containers
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

            StyledWindow {
                id: win

                required property ShellScreen modelData

                screen: modelData
                name: "cheatsheet"
                color: "transparent"
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true
                implicitWidth: modelData.width
                implicitHeight: modelData.height

                Rectangle {
                    anchors.fill: parent
                    color: Colours.palette.m3scrim
                    opacity: 0.55

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.hide()
                    }
                }

                Content {
                    anchors.centerIn: parent
                    implicitWidth: Math.min(1240, modelData.width * 0.78)
                    implicitHeight: Math.min(880, modelData.height * 0.78)
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
