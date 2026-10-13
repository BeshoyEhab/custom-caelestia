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

        // Insets the clock keeps from each edge (bar + border aware on all
        // sides). Auto-placement analyses with the max and clamps with each.
        readonly property real clockInsetL: contentItem.Tokens.padding.extraLargeIncreased + (GlobalConfig.bar.positioningEdge === 0 ? contentItem.Tokens.sizes.bar.innerWidth : 0) + Math.max(contentItem.Tokens.padding.small, contentItem.Config.border.thickness)
        readonly property real clockInsetR: contentItem.Tokens.padding.extraLargeIncreased + (GlobalConfig.bar.positioningEdge === 1 ? contentItem.Tokens.sizes.bar.innerWidth : 0) + Math.max(contentItem.Tokens.padding.small, contentItem.Config.border.thickness)
        readonly property real clockInsetT: contentItem.Tokens.padding.extraLargeIncreased + (GlobalConfig.bar.positioningEdge === 2 ? contentItem.Tokens.sizes.bar.innerWidth : 0) + Math.max(contentItem.Tokens.padding.small, contentItem.Config.border.thickness)
        readonly property real clockInsetB: contentItem.Tokens.padding.extraLargeIncreased + (GlobalConfig.bar.positioningEdge === 3 ? contentItem.Tokens.sizes.bar.innerWidth : 0) + Math.max(contentItem.Tokens.padding.small, contentItem.Config.border.thickness)
        readonly property real clockInsetMax: Math.max(clockInsetL, clockInsetR, clockInsetT, clockInsetB)

        // position = auto-empty (flattest) / auto-full (busiest): the clock
        // snaps to the least/most busy region of the wallpaper (end-4 style).
        readonly property bool autoClockPlacement: {
            const p = contentItem.Config.background.desktopClock.position;
            return p === "auto-empty" || p === "auto-full";
        }

        // Rebuilt whenever anything that affects the analysis changes
        // (placement mode, wallpaper, screen, box size, fill mode, insets).
        // Empty means "don't analyse"; a non-empty value change kicks the run.
        readonly property var clockAnalysisCmd: {
            if (!win.autoClockPlacement || clockLoader.status !== Loader.Ready || clockLoader.width <= 0)
                return [];
            const img = Wallpapers.colourSource;
            if (!img)
                return [];
            return [
                "python3", Quickshell.shellPath("scripts/least_busy_region.py"),
                "--screen-width", String(Math.round(win.width)),
                "--screen-height", String(Math.round(win.height)),
                "--width", String(Math.round(clockLoader.width)),
                "--height", String(Math.round(clockLoader.height)),
                "--pad", String(Math.round(win.clockInsetMax)),
                "--mode", contentItem.Config.background.wallpaperMode,
                ...(contentItem.Config.background.desktopClock.position === "auto-full" ? ["--busiest"] : []),
                img
            ];
        }

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

        onClockAnalysisCmdChanged: {
            if (clockAnalysisCmd.length > 0)
                analysisProc.exec(clockAnalysisCmd);
        }

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

        // Centre of the region found by least_busy_region.py; falls back to
        // the screen centre until the first result (or after a failure).
        QtObject {
            id: autoPos

            property real cx: win.width / 2
            property real cy: win.height / 2
        }

        Process {
            id: analysisProc

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const d = JSON.parse(text);
                        if (typeof d.center_x !== "number" || typeof d.center_y !== "number")
                            throw new Error("bad payload");
                        autoPos.cx = d.center_x;
                        autoPos.cy = d.center_y;
                    } catch (e) {
                        console.warn(`[Background] wallpaper region analysis failed: ${e}`);
                        autoPos.cx = win.width / 2;
                        autoPos.cy = win.height / 2;
                    }
                }
            }
        }

        Loader {
            id: clockLoader

            asynchronous: true
            active: Config.background.desktopClock.enabled

            transform: Translate {
                id: clockTrans

                x: !win.autoClockPlacement && clockPos.custom ? clockPos.dx : 0
                y: !win.autoClockPlacement && clockPos.custom ? clockPos.dy : 0
            }

            anchors.margins: Tokens.padding.extraLargeIncreased
            anchors.leftMargin: Tokens.padding.extraLargeIncreased + (GlobalConfig.bar.positioningEdge === 0 ? Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness) : Math.max(Tokens.padding.small, Config.border.thickness))
            anchors.topMargin: Tokens.padding.extraLargeIncreased + (GlobalConfig.bar.positioningEdge === 2 ? Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness) : Math.max(Tokens.padding.small, Config.border.thickness))

            state: win.autoClockPlacement ? "auto" : Config.background.desktopClock.position
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
                },
                // Auto-placement: leaving a preset state reverts its anchors,
                // so the clock is unanchored here and driven purely by x/y
                // centred on the analysed region (clamped to the insets).
                State {
                    name: "auto"

                    PropertyChanges {
                        target: clockLoader

                        x: Math.max(win.clockInsetL, Math.min(autoPos.cx - clockLoader.width / 2, win.width - win.clockInsetR - clockLoader.width))
                        y: Math.max(win.clockInsetT, Math.min(autoPos.cy - clockLoader.height / 2, win.height - win.clockInsetB - clockLoader.height))
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
        // nudges it anywhere. Disabled during auto-placement (the analysis
        // owns the position); only covers the clock rect, so wallpaper
        // clicks everywhere else are unaffected.
        MouseArea {
            visible: clockLoader.active && clockLoader.status === Loader.Ready && !win.autoClockPlacement
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
