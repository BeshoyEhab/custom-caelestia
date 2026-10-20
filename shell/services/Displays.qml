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

    function refresh(): void {
        if (!monitorProc.running)
            monitorProc.running = true;
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
        if (!canProject) {
            lastError = "No second display detected";
            return;
        }
        if (["main", "duplicate", "extend", "second"].indexOf(next) === -1)
            return;
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
        const header = DMath.fileHeader(new Date());
        monitorsFile.setText(`${header}\n\n${rules.map(r => DMath.luaMonitor(r)).join("\n\n")}\n`);

        // Workspace pin: only meaningful while a second output is in use.
        let wsRules = DMath.parseWorkspaceRules(workspaceFileText);
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
        reloadProc.running = true;
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
            }
        }

        onExited: root.busy = false // qmllint disable signal-handler-parameters
    }

    Process {
        id: reloadProc

        command: ["hyprctl", "reload"]

        onExited: { // qmllint disable signal-handler-parameters
            root.busy = false;
            root.refresh();
        }
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
                root.pinnedWorkspace = typeof data.workspace === "number" ? data.workspace : 2;
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
