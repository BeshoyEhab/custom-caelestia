pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components.containers
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

            StyledWindow {
                id: win

                required property ShellScreen modelData

                screen: modelData
                name: "displays"
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

                Card {
                    anchors.centerIn: parent
                    onClose: root.hide()
                }
            }
        }
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
            return `mode=${Displays.mode} main=${Displays.mainName} secondary=${Displays.secondaryName} placement=${Displays.placement} workspace=${Displays.pinnedWorkspace}`;
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
