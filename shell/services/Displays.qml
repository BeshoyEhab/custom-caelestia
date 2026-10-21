pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils
import "DisplayMath.js" as DMath

Singleton {
    id: root

    readonly property string monitorsPath: `${Paths.home}/.config/hypr/monitors.lua`
    readonly property string workspacesPath: `${Paths.home}/.config/hypr/workspaces.lua`
    readonly property string statePath: `${Paths.config}/displays.json`

    // [{ name, description, width, height, x, y, scale, refresh, disabled,
    //    mirrorOf, focused, modes: [{ width, height, refresh, label }] }]
    property var monitors: []
    property string preferredMain: ""
    property string preferredSecondary: ""
    property string preferredPlacement: ""
    property int pinnedWorkspace: 2
    property string workspaceFileText: ""
    property bool busy: false
    property bool healing: false
    property double lastHealAt: 0
    property var pendingWsMove: null
    property string lastError: ""

    readonly property var activeMonitors: monitors.filter(m => !m.disabled)
    readonly property string mainName: DMath.pickMain(monitors, preferredMain)
    readonly property var mainMonitor: monitors.find(m => m.name === mainName) ?? null
    readonly property string secondaryName: {
        if (preferredSecondary && preferredSecondary !== mainName && monitors.some(m => m.name === preferredSecondary))
            return preferredSecondary;
        const activeOther = activeMonitors.find(m => m.name !== mainName);
        if (activeOther)
            return activeOther.name;
        const anyOther = monitors.find(m => m.name !== mainName);
        return anyOther?.name ?? "";
    }
    readonly property var secondaryMonitor: monitors.find(m => m.name === secondaryName) ?? null

    readonly property string mode: DMath.detectMode(monitors, mainName)
    readonly property string placement: {
        if (preferredPlacement)
            return preferredPlacement;
        if (mainMonitor && secondaryMonitor)
            return DMath.detectPlacement(mainMonitor, secondaryMonitor);
        return "right";
    }
    readonly property bool canProject: secondaryMonitor !== null

    // A refresh requested while hyprctl is already running must not be lost:
    // at shell start the singleton's first call and show() can race.
    property bool refreshQueued: false
    property int emptyRefreshes: 0

    function refresh(): void {
        if (monitorProc.running) {
            refreshQueued = true;
            return;
        }
        monitorProc.running = true;
    }

    // The first hyprctl call after login can answer with an empty list, which
    // would skip the heal() safety net entirely. Retry a few times.
    Timer {
        id: retryTimer

        interval: 600
        repeat: false
        onTriggered: root.refresh()
    }

    function saveState(): void {
        stateFile.setText(JSON.stringify({
            main: preferredMain,
            secondary: preferredSecondary,
            workspace: pinnedWorkspace,
            placement: preferredPlacement
        }));
    }

    function setMode(next: string): void {
        if (!preferredMain && mainName) {
            preferredMain = mainName;
            saveState();
        }
        if (["main", "duplicate", "extend", "second"].indexOf(next) === -1)
            return;
        if (!canProject && next !== "main") {
            lastError = "No second display detected";
            return;
        }
        if (!preferredSecondary && secondaryMonitor)
            preferredSecondary = secondaryMonitor.name;
        if (next !== "extend")
            preferredPlacement = "";
        apply(next);
    }

    function setMain(name: string): void {
        // Disabled monitors are valid targets: choosing one is how the user
        // gets back from "second only".
        if (!monitors.some(m => m.name === name))
            return;
        if (preferredSecondary === name)
            preferredSecondary = "";
        preferredMain = name;
        saveState();
        // "Second only" means the new main was switched off; choosing it as
        // main must turn it back on instead of re-applying second-only.
        apply(mode === "second" ? "main" : undefined);
    }

    function setSecondary(name: string): void {
        if (!monitors.some(m => m.name === name && m.name !== mainName))
            return;
        preferredSecondary = name;
        saveState();
        apply();
    }

    function setPlacement(next: string): void {
        if (["left", "right", "top", "bottom"].indexOf(next) === -1)
            return;
        preferredPlacement = next;
        saveState();
        if (mode === "extend")
            apply("extend");
    }

    function setPinnedWorkspace(workspace: int): void {
        const clamped = Math.max(1, Math.min(10, workspace));
        if (clamped === pinnedWorkspace)
            return;
        pinnedWorkspace = clamped;
        saveState();
        apply();
    }

    function setResolution(name: string, mode: string): void {
        const parsed = DMath.parseModes([mode])[0];
        if (!parsed)
            return;
        monitors = monitors.map(m => {
            if (m.name !== name)
                return m;
            const next = Object.assign({}, m);
            next.width = parsed.width;
            next.height = parsed.height;
            next.refresh = parsed.refresh;
            return next;
        });
        apply();
    }

    function apply(forcedMode): void {
        if (!mainMonitor) {
            lastError = "No monitors reported by hyprctl";
            return;
        }

        let nextMode = forcedMode || mode;
        if (nextMode === "single")
            nextMode = "main";
        if (!secondaryMonitor && nextMode !== "main")
            nextMode = "main";

        const rules = DMath.layout({
            main: mainMonitor,
            all: monitors,
            mode: nextMode,
            placement: placement,
            secondary: secondaryMonitor
        });

        // A persisted "second only" on a virtual output turns into a black
        // screen at the next login: the virtual output is gone, so the rule
        // that disabled the laptop panel is the only one left. Refuse it.
        if (!DMath.keepsAPhysicalOutput(rules, monitors)) {
            lastError = "Refusing to switch off every physical display. Connect the second screen first.";
            busy = false;
            return;
        }

        const header = DMath.fileHeader(new Date());
        monitorsFile.setText(`${header}\n\n${rules.map(r => DMath.luaMonitor(r)).join("\n\n")}\n`);

        // Workspace pin: only meaningful while a second output is in use.
        // Drop rules for outputs that are gone or that this layout switches
        // off, so a pin cannot point at a dark screen.
        const present = monitors.map(m => m.name);
        const targets = DMath.enabledOutputs(rules);
        let wsRules = DMath.parseWorkspaceRules(workspaceFileText).filter(r =>
            present.indexOf(r.monitor) !== -1 && targets.indexOf(r.monitor) !== -1);
        if (secondaryMonitor && nextMode !== "main") {
            wsRules = DMath.mergeWorkspaceRule(wsRules, {
                workspace: pinnedWorkspace,
                monitor: secondaryMonitor.name,
                isDefault: true
            });
        }
        workspaceFileText = wsRules;
        workspacesFile.setText(wsRules.length
            ? `${header}\n\n${wsRules.map(r => DMath.luaWorkspace(r)).join("\n\n")}\n`
            : `${header}\n`);

        busy = true;
        lastError = "";
        // The workspace move needs the monitor rules to be in effect first,
        // otherwise Hyprland moves the workspace to an output that does not
        // exist yet. evalProc starts the move when it finishes.
        pendingWsMove = secondaryMonitor && nextMode !== "main" ? { workspace: pinnedWorkspace, monitor: secondaryMonitor.name } : null;
        runRules(rules);
    }

    // Apply at runtime with hyprctl eval instead of `hyprctl reload`: a reload
    // re-runs the whole config and has crashed Hyprland 0.56 when an output was
    // disabled at the same time. The generated files keep it across sessions.
    function runRules(rules): void {
        evalProc.code = rules.map(r => DMath.luaMonitor(r)).join("\n");
        evalProc.running = true;
    }

    function heal(): void {
        if (healing || monitors.length === 0)
            return;
        // monitorProc finishes, refresh() runs, the layout is still unhealthy
        // and heal() is called again. Reloading in a loop would thrash the
        // session, so a failed heal waits a minute before trying once more.
        const now = Date.now();
        if (now - lastHealAt < 60000)
            return;
        lastHealAt = now;
        healing = true;
        const rules = DMath.healRules(monitors);
        const header = DMath.fileHeader(new Date());
        monitorsFile.setText(`${header}\n\n${rules.map(r => DMath.luaMonitor(r)).join("\n\n")}\n`);
        lastError = "Restored the display layout: no physical output was active.";
        busy = true;
        // A runtime eval cannot revive an output Hyprland has marked disabled;
        // only a reload re-runs the monitor rules. The file just written is
        // known to keep a physical panel on, so this cannot black-screen.
        healProc.running = true;
    }

    Process {
        id: monitorProc

        command: ["hyprctl", "monitors", "all", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const raw = JSON.parse(text);
                    root.monitors = raw.map(m => ({
                        id: m.id,
                        name: m.name,
                        description: m.description ?? "",
                        width: m.width ?? 0,
                        height: m.height ?? 0,
                        x: m.x ?? 0,
                        y: m.y ?? 0,
                        scale: m.scale ?? 1,
                        refresh: m.refreshRate ?? 60,
                        disabled: m.disabled === true,
                        mirrorOf: m.mirrorOf ?? "none",
                        focused: m.focused === true,
                        modes: DMath.parseModes(m.availableModes)
                    }));
                    root.lastError = "";
                } catch (e) {
                    root.lastError = `Failed to parse hyprctl monitors: ${e}`;
                }

                const usable = root.monitors.filter(m => !m.disabled && m.width > 0 && m.height > 0 && !DMath.isVirtual(m.name));
                if (root.monitors.length === 0) {
                    if (root.emptyRefreshes < 20) {
                        root.emptyRefreshes++;
                        retryTimer.start();
                    } else {
                        root.lastError = "No monitors reported by hyprctl";
                    }
                    return;
                }
                root.emptyRefreshes = 0;
                const hasPhysical = root.monitors.some(m => !DMath.isVirtual(m.name));
                if (hasPhysical && usable.length === 0)
                    root.heal();
            }
        }

        onExited: { // qmllint disable signal-handler-parameters
            root.busy = false;
            if (root.refreshQueued) {
                root.refreshQueued = false;
                Qt.callLater(() => root.refresh());
            }
        }
    }

    Process {
        id: evalProc

        property string code: ""

        command: ["hyprctl", "eval", evalProc.code]

        onExited: { // qmllint disable signal-handler-parameters
            root.busy = false;
            root.healing = false;
            const move = root.pendingWsMove;
            root.pendingWsMove = null;
            if (move)
                wsMoveProc.move(move.workspace, move.monitor);
            root.refresh();
        }
    }

    Process {
        id: healProc

        command: ["hyprctl", "reload"]

        onExited: { // qmllint disable signal-handler-parameters
            root.healing = false;
            root.busy = false;
            root.refresh();
        }
    }

    Process {
        id: wsMoveProc

        property var moveArgs: []

        command: ["hyprctl", "dispatch", "moveworkspacetomonitor"].concat(wsMoveProc.moveArgs)

        function move(workspace, monitor): void {
            moveArgs = [String(workspace), monitor];
            running = true;
        }

        onExited: root.refresh() // qmllint disable signal-handler-parameters
    }

    FileView {
        id: stateFile

        path: root.statePath
        printErrors: false
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.preferredMain = typeof data.main === "string" ? data.main : "";
                root.preferredSecondary = typeof data.secondary === "string" ? data.secondary : "";
                root.preferredPlacement = typeof data.placement === "string" ? data.placement : "";
                const workspace = Number(data.workspace);
                root.pinnedWorkspace = Number.isFinite(workspace) && data.workspace !== null
                    ? Math.max(1, Math.min(10, Math.round(workspace)))
                    : 2;
            } catch (e) {}
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                Qt.callLater(() => stateFile.setText("{}"));
        }
    }

    FileView {
        id: workspacesFile

        path: root.workspacesPath
        printErrors: false
        // Another tool (nwg-displays) may rewrite the pins; re-read them
        // instead of overwriting with the copy loaded at startup.
        watchChanges: true
        onLoaded: root.workspaceFileText = text()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                root.workspaceFileText = "";
        }
    }

    FileView {
        id: monitorsFile

        path: root.monitorsPath
        printErrors: false
    }

    Component.onCompleted: refresh()
}
