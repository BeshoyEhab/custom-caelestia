pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.services
import qs.utils

Singleton {
    id: root

    // Cached mpvpaper presence. Pattern: Pam.qml availCommand.
    property bool available: false
    // Last spawned command set + spawn timestamp: drives idempotence
    // (same state → verify alive instead of respawning) and shields the
    // liveness check from a spawn still inside its 0.3s kill-settle sleep.
    property var lastCmds: []
    property var pendingCheck: []
    property double lastSpawnMs: 0
    // True when an external video is (or should be) on screen.
    readonly property bool externalActive: available
        && GlobalConfig.background.wallpaperEnabled
        && GlobalConfig.background.videoBackend === "mpvpaper"
        && Wallpapers.actualCurrent !== ""
        && Images.isVideo(Wallpapers.actualCurrent)
        && root.workspaceVisible

    // True unless every output's active workspace is fullscreen-covered.
    // Fail-visible: unknown Hypr state keeps the video playing (never black).
    // Fullscreen = Hyprland IPC fullscreen 2/3 (maximized alone still shows
    // the wallpaper through gaps, so it keeps playing).
    function workspaceCovered(ws): bool {
        const tls = ws?.toplevels?.values ?? [];
        for (const t of tls) {
            if ((t.lastIpcObject?.fullscreen ?? 0) >= 2)
                return true;
        }
        return false;
    }

    readonly property bool workspaceVisible: {
        const mons = Hypr.monitors?.values ?? [];
        if (mons.length === 0)
            return true;
        for (const m of mons) {
            if (!root.workspaceCovered(m.activeWorkspace))
                return true;
        }
        return false;
    }

    function shQuote(s: string): string {
        return `'${s.replace(/'/g, `'\\''`)}'`;
    }

    function mpvArgs(): string {
        const stop = GlobalConfig.background.videoAutoStop ? "-s" : "-p";
        const mode = GlobalConfig.background.videoAutoMode;
        return mode === "" ? stop : `${stop} -a ${mode}`;
    }

    function fillArgs(): string {
        switch (GlobalConfig.background.wallpaperMode) {
        case "fit": return "--keepaspect";
        case "stretch": return "--no-keepaspect";
        default: return "--panscan=1";
        }
    }

    function spawnCmd(target: string, video: string): string {
        return `mpvpaper ${root.mpvArgs()} -o "no-audio loop hwdec=auto ${root.fillArgs()}" ${target} ${root.shQuote(video)}`;
    }

    function spawn(target: string, video: string): void {
        Quickshell.execDetached(["sh", "-c", root.spawnCmd(target, video)]);
    }

    function reconcile(): void {
        // Kill-first, chained in ONE shell invocation per reconcile:
        // separate kill-then-spawn execDetached calls race (the kill can
        // land after the new spawn), blacking the wallpaper until the
        // next change.
        // Idempotent: an already-correct instance is left alone, so
        // workspace switches (same video, same flags) don't churn.
        if (!root.externalActive) {
            if (root.lastCmds.length > 0) {
                console.log(`[VideoWallpaper] kill (${root.inactiveReason()})`);
                Quickshell.execDetached(["sh", "-c", "pkill -x mpvpaper"]);
                root.lastCmds = [];
            }
            return;
        }
        const outs = GlobalConfig.background.videoOutputs;
        const keys = outs ? Object.keys(outs) : [];
        const cmds = [];
        if (keys.length === 0) {
            cmds.push(root.spawnCmd("ALL", Wallpapers.actualCurrent));
        } else {
            for (const k of keys) {
                if (outs[k])
                    cmds.push(root.spawnCmd(k, outs[k]));
            }
        }
        if (cmds.length === 0)
            return;
        if (cmds.join("\n") !== root.lastCmds.join("\n")) {
            console.log(`[VideoWallpaper] spawn: ${cmds.join(" ; ")}`);
            Quickshell.execDetached(["sh", "-c", `pkill -x mpvpaper; sleep 0.3; ${cmds.join(" & ")} &`]);
            root.lastCmds = cmds.slice();
            root.lastSpawnMs = Date.now();
        } else {
            // Same desired state (e.g. workspace switch): respawn only if
            // the process died behind our back.
            root.pendingCheck = cmds.slice();
            if (!aliveProc.running)
                aliveProc.running = true;
        }
    }

    function restore(): void {
        availProc.running = true; // re-check binary, then reconcile
    }

    function inactiveReason(): string {
        if (!root.available)
            return "mpvpaper missing";
        if (!GlobalConfig.background.wallpaperEnabled)
            return "wallpaper disabled";
        if (GlobalConfig.background.videoBackend !== "mpvpaper")
            return "backend=qs";
        if (Wallpapers.actualCurrent === "" || !Images.isVideo(Wallpapers.actualCurrent))
            return "not a video";
        if (!root.workspaceVisible)
            return "fullscreen-covered";
        return "unknown";
    }

    // One-line state snapshot for debugging (qs ipc call videoWallpaper debug).
    function debugState(): string {
        const mons = Hypr.monitors?.values ?? [];
        const info = [];
        for (const m of mons) {
            const ws = m.activeWorkspace;
            const tls = ws?.toplevels?.values ?? [];
            const wins = [];
            for (const t of tls)
                wins.push(`${t.lastIpcObject?.class ?? "?"}@${ws?.id ?? "?"}:fs=${t.lastIpcObject?.fullscreen ?? "?"}`);
            info.push(`${m.name}:ws=${ws?.id ?? "?"}[${wins.join(",")}]`);
        }
        return `externalActive=${root.externalActive} workspaceVisible=${root.workspaceVisible} avail=${root.available} mons={${info.join(" ")}}`;
    }

    // All change handlers funnel through this 400ms coalescing timer:
    // startup fires onActualCurrentChanged + onExternalActiveChanged (+
    // availProc finish) for one state change, and chained kill+spawn in
    // one shell invocation can no longer converge duplicates away.
    Timer {
        id: reconcileTimer

        interval: 400
        onTriggered: root.reconcile()
    }

    function requestReconcile(): void {
        reconcileTimer.restart();
    }

    // externalActive only flips on bool edges: a video->video switch or a
    // -s/-p/-a/mode/output change keeps it true, so reconcile on the
    // inputs directly as well.
    onExternalActiveChanged: root.requestReconcile()

    Connections {
        function onActualCurrentChanged(): void {
            root.requestReconcile();
        }

        target: Wallpapers
    }

    Connections {
        function onVideoBackendChanged(): void {
            root.requestReconcile();
        }

        function onVideoAutoStopChanged(): void {
            if (root.externalActive)
                root.requestReconcile();
        }

        function onVideoAutoModeChanged(): void {
            if (root.externalActive)
                root.requestReconcile();
        }

        function onVideoOutputsChanged(): void {
            if (root.externalActive)
                root.requestReconcile();
        }

        function onWallpaperEnabledChanged(): void {
            root.requestReconcile();
        }

        target: GlobalConfig.background
    }

    Connections {
        function onWallpaperModeChanged(): void {
            if (root.externalActive)
                root.requestReconcile();
        }

        target: GlobalConfig.background
    }

    // Workspace visibility: fullscreen flips and workspace switches.
    // (workspaceVisible binding edges also fire onExternalActiveChanged.)
    Connections {
        function onToplevelDataChanged(): void {
            root.requestReconcile();
        }

        function onFocusedWorkspaceChanged(): void {
            root.requestReconcile();
        }

        target: Hypr
    }

    Component.onCompleted: root.restore()

    IpcHandler {
        function restore(): void {
            root.restore();
        }

        function debug(): string {
            return root.debugState();
        }

        target: "videoWallpaper"
    }

    Process {
        id: availProc

        command: ["sh", "-c", "command -v mpvpaper"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = text.trim() !== "";
                const wantsExternal = GlobalConfig.background.wallpaperEnabled
                    && GlobalConfig.background.videoBackend === "mpvpaper"
                    && Wallpapers.actualCurrent !== ""
                    && Images.isVideo(Wallpapers.actualCurrent);
                if (!root.available && wantsExternal)
                    console.warn("[VideoWallpaper] mpvpaper not found, falling back to QS Video");
                root.requestReconcile();
            }
        }
    }

    // Liveness check for the idempotent path: `pgrep -x` matches the exact
    // process name, so the `sh -c` wrapper never self-matches.
    Process {
        id: aliveProc

        command: ["sh", "-c", "pgrep -x mpvpaper || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const cmds = root.pendingCheck.slice();
                root.pendingCheck = [];
                if (text.trim() === "" && cmds.length > 0 && root.externalActive && Date.now() - root.lastSpawnMs > 1500) {
                    console.log("[VideoWallpaper] respawn (process died)");
                    Quickshell.execDetached(["sh", "-c", `pkill -x mpvpaper; sleep 0.3; ${cmds.join(" & ")} &`]);
                    root.lastCmds = cmds;
                    root.lastSpawnMs = Date.now();
                }
            }
        }
    }

    // Supervisor: recover a crashed/killed mpvpaper within ~10s even when
    // no state change fires reconcile.
    Timer {
        id: supervisorTimer

        interval: 10000
        repeat: true
        running: true
        onTriggered: {
            if (root.externalActive && root.lastCmds.length > 0) {
                root.pendingCheck = root.lastCmds.slice();
                if (!aliveProc.running)
                    aliveProc.running = true;
            }
        }
    }
}
