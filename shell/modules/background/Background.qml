pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.utils

Variants {
    model: Screens.screens.filter(s => GlobalConfig.forScreen(s.name).background.enabled)

    StyledWindow {
        id: win

        required property ShellScreen modelData

        screen: modelData
        name: "background"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: VideoWallpaper.externalActive ? WlrLayer.Bottom : (contentItem.Config.background.wallpaperEnabled ? WlrLayer.Background : WlrLayer.Bottom)
        color: VideoWallpaper.externalActive ? "transparent" : (contentItem.Config.background.wallpaperEnabled ? "black" : "transparent")
        surfaceFormat.opaque: false

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        implicitWidth: modelData?.width ?? 1920
        implicitHeight: modelData?.height ?? 1080

        Item {
            id: behindClock

            anchors.fill: parent

            Loader {
                id: wallpaper

                asynchronous: true

                anchors.fill: parent
                // Inactive while mpvpaper owns the screen: our window sits on
                // the Bottom layer (above mpvpaper's background layer), so a
                // poster thumb left underneath would cover the video.
                active: Config.background.wallpaperEnabled && !VideoWallpaper.externalActive

                sourceComponent: Wallpaper {}
            }

            Visualiser {
                anchors.fill: parent
                screen: win.modelData
                wallpaper: wallpaper
            }
        }

        // Free-drag offset for the desktop clock, remembered per screen.
        // The clock keeps its preset anchors; dragging just translates it,
        // so picking a new preset in settings re-snaps cleanly.
        // NOTE: deliberately not PersistentProperties — that only flushes on
        // graceful exit (states.json stale since Sep 2; this shell usually
        // exits via crash/kill), so offsets were lost every session.
        // FileView writes through to disk immediately instead.
        QtObject {
            id: clockPos

            property bool custom: false
            property real dx: 0
            property real dy: 0
        }

        FileView {
            id: clockPosFile

            path: `${Paths.state}/desktopClockPos-${win.modelData?.name ?? "default"}.json`
            printErrors: false
            onLoaded: {
                try {
                    const d = JSON.parse(text());
                    if (typeof d.dx === "number" && typeof d.dy === "number") {
                        clockPos.dx = d.dx;
                        clockPos.dy = d.dy;
                        clockPos.custom = true;
                    }
                } catch (e) {}
            }
            onLoadFailed: err => {
                if (err === FileViewError.FileNotFound)
                    Qt.callLater(() => clockPosFile.setText("{}"));
            }
        }

        function saveClockPos(): void {
            clockPosFile.setText(JSON.stringify(clockPos.custom ? { dx: clockPos.dx, dy: clockPos.dy } : {}));
        }

        Connections {
            target: Config.background.desktopClock
            function onPositionChanged(): void {
                clockPos.custom = false;
                clockPos.dx = 0;
                clockPos.dy = 0;
                saveClockPos();
            }
        }

        Loader {
            id: clockLoader

            asynchronous: true
            active: Config.background.desktopClock.enabled

            transform: Translate {
                id: clockTrans

                x: clockPos.custom ? clockPos.dx : 0
                y: clockPos.custom ? clockPos.dy : 0
            }

            anchors.margins: Tokens.padding.extraLargeIncreased
            anchors.leftMargin: Tokens.padding.extraLargeIncreased + (GlobalConfig.bar.positioningEdge === 0 ? Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness) : Math.max(Tokens.padding.small, Config.border.thickness))
            anchors.topMargin: Tokens.padding.extraLargeIncreased + (GlobalConfig.bar.positioningEdge === 2 ? Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness) : Math.max(Tokens.padding.small, Config.border.thickness))

            state: Config.background.desktopClock.position
            states: [
                State {
                    name: "top-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "top-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "top-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "middle-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "middle-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "middle-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "bottom-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "bottom-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "bottom-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                    }
                }
            ]

            transitions: Transition {
                AnchorAnim {}
            }

            sourceComponent: DesktopClock {
                wallpaper: behindClock
                absX: clockLoader.x + clockTrans.x
                absY: clockLoader.y + clockTrans.y
            }
        }

        // Drag handle: when nothing covers the desktop, grabbing the clock
        // nudges it anywhere. Only covers the clock rect, so wallpaper
        // clicks everywhere else are unaffected.
        MouseArea {
            visible: clockLoader.active && clockLoader.status === Loader.Ready
            x: clockLoader.x + clockTrans.x
            y: clockLoader.y + clockTrans.y
            width: clockLoader.width
            height: clockLoader.height
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            property real grabDX: 0
            property real grabDY: 0

            onPressed: mouse => {
                clockPos.custom = true;
                const p = mapToItem(clockLoader.parent, mouse.x, mouse.y);
                grabDX = p.x - (clockLoader.x + clockTrans.x);
                grabDY = p.y - (clockLoader.y + clockTrans.y);
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                const p = mapToItem(clockLoader.parent, mouse.x, mouse.y);
                const maxX = clockLoader.parent.width - clockLoader.width;
                const maxY = clockLoader.parent.height - clockLoader.height;
                clockPos.dx = Math.min(Math.max(p.x - clockLoader.x - grabDX, -clockLoader.x), maxX - clockLoader.x);
                clockPos.dy = Math.min(Math.max(p.y - clockLoader.y - grabDY, -clockLoader.y), maxY - clockLoader.y);
            }
            onReleased: saveClockPos()
        }
    }
}
