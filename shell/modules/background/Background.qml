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
import "ClockPosition.js" as ClockPosition

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

        property bool analysisPending: false
        property var deferredAnalysis: null
        property string analysisRunKey: ""

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
                analysisTimer.restart();
            else
                analysisTimer.stop();
        }

        Timer {
            id: analysisTimer

            interval: 300
            repeat: false

            onTriggered: {
                if (clockAnalysisCmd.length === 0)
                    return;
                if (analysisProc.running) {
                    win.analysisPending = true;
                    return;
                }
                win.analysisRunKey = JSON.stringify(clockAnalysisCmd);
                analysisProc.exec(clockAnalysisCmd);
            }
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
        // The clock gets a base x/y from the preset or the analyser; dragging
        // only translates it, so a preset change or wallpaper reset re-snaps
        // cleanly.
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
                win.deferredAnalysis = null;
                win.analysisPending = false;
                analysisTimer.stop();
                if (!win.autoClockPlacement)
                    Qt.callLater(() => clockLoader.placementSettled = true);
                saveClockPos();
            }
        }

        Connections {
            target: Wallpapers
            function onActualCurrentChanged(): void {
                if (!win.autoClockPlacement)
                    return;
                clockPos.custom = false;
                clockPos.dx = 0;
                clockPos.dy = 0;
                win.deferredAnalysis = null;
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

            onExited: {
                if (win.analysisPending) {
                    win.analysisPending = false;
                    analysisTimer.restart();
                }
            }

            stdout: StdioCollector {
                onStreamFinished: {
                    if (JSON.stringify(clockAnalysisCmd) !== win.analysisRunKey)
                        return;

                    let result;
                    try {
                        const d = JSON.parse(text);
                        if (typeof d.center_x !== "number" || typeof d.center_y !== "number")
                            throw new Error("bad payload");
                        result = { cx: d.center_x, cy: d.center_y };
                    } catch (e) {
                        console.warn(`[Background] wallpaper region analysis failed: ${e}`);
                        result = { cx: win.width / 2, cy: win.height / 2 };
                    }

                    if (dragArea.dragging) {
                        win.deferredAnalysis = result;
                        return;
                    }

                    autoPos.cx = result.cx;
                    autoPos.cy = result.cy;
                    clockLoader.placementSettled = true;
                }
            }
        }

        Loader {
            id: clockLoader

            readonly property var insets: ({ left: win.clockInsetL, right: win.clockInsetR, top: win.clockInsetT, bottom: win.clockInsetB })
            readonly property var presetPos: win.autoClockPlacement ? ({ x: 0, y: 0 }) : ClockPosition.preset(Config.background.desktopClock.position, win.width, win.height, width, height, insets)
            readonly property var autoPosResult: ClockPosition.fromCenter(autoPos.cx, autoPos.cy, win.width, win.height, width, height, insets)
            readonly property real baseX: win.autoClockPlacement ? autoPosResult.x : presetPos.x
            readonly property real baseY: win.autoClockPlacement ? autoPosResult.y : presetPos.y
            property bool placementSettled: false

            asynchronous: true
            active: Config.background.desktopClock.enabled
            x: baseX
            y: baseY

            Behavior on x {
                enabled: Config.background.desktopClock.animatePosition && clockLoader.placementSettled && !dragArea.dragging
                Anim {
                    type: Anim.DefaultSpatial
                }
            }

            Behavior on y {
                enabled: Config.background.desktopClock.animatePosition && clockLoader.placementSettled && !dragArea.dragging
                Anim {
                    type: Anim.DefaultSpatial
                }
            }

            Component.onCompleted: {
                if (!win.autoClockPlacement)
                    Qt.callLater(() => placementSettled = true);
            }

            transform: Translate {
                id: clockTrans

                x: clockPos.custom ? clockPos.dx : 0
                y: clockPos.custom ? clockPos.dy : 0

                Behavior on x {
                    enabled: Config.background.desktopClock.animatePosition && clockLoader.placementSettled && !dragArea.dragging
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }

                Behavior on y {
                    enabled: Config.background.desktopClock.animatePosition && clockLoader.placementSettled && !dragArea.dragging
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }
            }

            sourceComponent: DesktopClock {
                wallpaper: behindClock
                absX: clockLoader.x + clockTrans.x
                absY: clockLoader.y + clockTrans.y
            }
        }

        // Drag handle: grabbing the clock nudges it anywhere, in every mode.
        // Only covers the clock rect, so wallpaper clicks elsewhere are
        // unaffected.
        MouseArea {
            id: dragArea

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
            property bool dragging: false

            onPressed: mouse => {
                dragging = true;
                const p = mapToItem(clockLoader.parent, mouse.x, mouse.y);
                grabDX = p.x - (clockLoader.x + clockTrans.x);
                grabDY = p.y - (clockLoader.y + clockTrans.y);
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                clockPos.custom = true;
                const p = mapToItem(clockLoader.parent, mouse.x, mouse.y);
                const clamped = ClockPosition.clampOffset(p.x - clockLoader.x - grabDX, p.y - clockLoader.y - grabDY, clockLoader.baseX, clockLoader.baseY, clockLoader.width, clockLoader.height, win.width, win.height, clockLoader.insets);
                clockPos.dx = clamped.dx;
                clockPos.dy = clamped.dy;
            }
            onReleased: {
                dragging = false;
                if (win.deferredAnalysis) {
                    autoPos.cx = win.deferredAnalysis.cx;
                    autoPos.cy = win.deferredAnalysis.cy;
                    clockLoader.placementSettled = true;
                    win.deferredAnalysis = null;
                }
                saveClockPos();
            }
            onDoubleClicked: {
                clockPos.custom = false;
                clockPos.dx = 0;
                clockPos.dy = 0;
                saveClockPos();
            }
        }
    }
}
