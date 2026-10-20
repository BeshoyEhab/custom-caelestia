.pragma library

// Pure display-layout logic. Keep this file free of QML types so it can be
// unit-tested with node (tests/display_math_test.js).
//
// Coordinate rules: Hyprland reports monitor width/height in physical pixels
// but layout positions (x/y) in logical pixels. Every position computed here
// goes through logicalSize() so a scaled monitor is not misplaced.

function logicalSize(monitor) {
    const scale = monitor && monitor.scale > 0 ? monitor.scale : 1;
    return {
        w: (monitor ? monitor.width : 0) / scale,
        h: (monitor ? monitor.height : 0) / scale
    };
}

function fmtNumber(n) {
    const v = Number(n);
    return Number.isFinite(v) ? String(v) : "1";
}

function modeString(monitor) {
    if (!monitor || !monitor.width || !monitor.height)
        return "preferred";
    const refresh = Number(monitor.refresh);
    return `${monitor.width}x${monitor.height}@${Number.isFinite(refresh) ? refresh.toFixed(2) : "60.00"}`;
}

function parseModes(list) {
    const modes = [];
    for (const entry of list || []) {
        const m = /^(\d+)x(\d+)@([\d.]+)Hz?$/.exec(String(entry).trim());
        if (!m)
            continue;
        const width = parseInt(m[1], 10);
        const height = parseInt(m[2], 10);
        const refresh = parseFloat(m[3]);
        modes.push({
            width: width,
            height: height,
            refresh: refresh,
            label: `${width}×${height} @ ${refresh.toFixed(0)} Hz`
        });
    }
    modes.sort((a, b) => (b.width * b.height - a.width * a.height) || (b.refresh - a.refresh));
    return modes;
}

function pickMain(all, preferred) {
    const monitors = all || [];
    const usable = monitors.filter(m => !m.disabled);
    if (preferred) {
        // The stored main may be temporarily switched off ("second only");
        // keep it as the main so the state reads back as second-only.
        const match = monitors.find(m => m.name === preferred);
        if (match)
            return match.name;
    }
    const origin = usable.find(m => m.x === 0 && m.y === 0);
    if (origin)
        return origin.name;
    const focused = usable.find(m => m.focused);
    if (focused)
        return focused.name;
    return usable.length ? usable[0].name : monitors.length ? monitors[0].name : "";
}

function detectMode(all, mainName) {
    const monitors = all || [];
    const active = monitors.filter(m => !m.disabled);
    if (active.length === 0)
        return "single";
    if (active.length === 1)
        return active[0].name === mainName ? (monitors.length === 1 ? "single" : "main") : "second";

    const main = active.find(m => m.name === mainName) || active[0];
    const others = active.filter(m => m.name !== main.name);
    // hyprctl reports mirrorOf as the target monitor's ID (string), not its
    // name, so accept both forms.
    const mirrorsMain = o => o.mirrorOf === main.name || (main.id !== undefined && String(o.mirrorOf) === String(main.id));
    if (others.every(mirrorsMain))
        return "duplicate";
    return "extend";
}

function detectPlacement(main, other) {
    if (!main || !other)
        return "right";
    const ms = logicalSize(main);
    const os = logicalSize(other);
    if (other.x >= main.x + ms.w)
        return "right";
    if (other.x + os.w <= main.x)
        return "left";
    if (other.y + os.h <= main.y)
        return "top";
    return "bottom";
}

// positions relative to the main output being placed at 0x0
function positionFor(mainSize, otherSize, placement) {
    switch (placement) {
    case "left":
        return `-${Math.round(otherSize.w)}x0`;
    case "top":
        return `0x-${Math.round(otherSize.h)}`;
    case "bottom":
        return `0x${Math.round(mainSize.h)}`;
    default:
        return `${Math.round(mainSize.w)}x0`;
    }
}

// Returns [{output, mode?, position?, scale?, mirror?, disabled?}]
function layout(opts) {
    const options = opts || {};
    const main = options.main;
    const all = options.all || [];
    const mode = options.mode || "main";
    const placement = options.placement || "right";
    if (!main)
        return [];

    const others = all.filter(m => m.name !== main.name);
    const secondary = options.secondary || others[0] || null;
    const rules = [];

    if (mode === "second" && secondary) {
        rules.push({ output: main.name, disabled: true });
        rules.push({
            output: secondary.name,
            mode: modeString(secondary),
            position: "0x0",
            scale: secondary.scale > 0 ? secondary.scale : 1
        });
    } else if (mode === "duplicate" && secondary) {
        rules.push({
            output: main.name,
            mode: modeString(main),
            position: "0x0",
            scale: main.scale > 0 ? main.scale : 1
        });
        rules.push({
            output: secondary.name,
            mode: modeString(secondary),
            position: "0x0",
            scale: secondary.scale > 0 ? secondary.scale : 1,
            mirror: main.name
        });
    } else if (mode === "extend" && secondary) {
        rules.push({
            output: main.name,
            mode: modeString(main),
            position: "0x0",
            scale: main.scale > 0 ? main.scale : 1
        });
        rules.push({
            output: secondary.name,
            mode: modeString(secondary),
            position: positionFor(logicalSize(main), logicalSize(secondary), placement),
            scale: secondary.scale > 0 ? secondary.scale : 1
        });
    } else {
        rules.push({
            output: main.name,
            mode: modeString(main),
            position: "0x0",
            scale: main.scale > 0 ? main.scale : 1
        });
    }

    for (const other of others) {
        const alreadyHandled = rules.some(r => r.output === other.name);
        if (alreadyHandled)
            continue;
        rules.push({ output: other.name, disabled: true });
    }
    return rules;
}

function luaMonitor(rule) {
    const fields = [`    output = "${rule.output}"`];
    if (rule.disabled) {
        fields.push("    disabled = true");
    } else {
        if (rule.mode)
            fields.push(`    mode = "${rule.mode}"`);
        if (rule.position)
            fields.push(`    position = "${rule.position}"`);
        if (rule.scale !== undefined)
            fields.push(`    scale = ${fmtNumber(rule.scale)}`);
        if (rule.mirror)
            fields.push(`    mirror = "${rule.mirror}"`);
    }
    return `hl.monitor({\n${fields.join(",\n")}\n})`;
}

function luaWorkspace(rule) {
    const fields = [`    workspace = "${rule.workspace}"`, `    monitor = "${rule.monitor}"`];
    if (rule.isDefault)
        fields.push("    default = true");
    return `hl.workspace_rule({\n${fields.join(",\n")}\n})`;
}

function parseWorkspaceRules(text) {
    const rules = [];
    if (!text)
        return rules;
    const blockRe = /hl\.workspace_rule\(\{([\s\S]*?)\}\)/g;
    let block;
    while ((block = blockRe.exec(text)) !== null) {
        const body = block[1];
        const ws = /workspace\s*=\s*"([^"]+)"/.exec(body);
        const mon = /monitor\s*=\s*"([^"]+)"/.exec(body);
        if (!ws || !mon)
            continue;
        rules.push({
            workspace: parseInt(ws[1], 10),
            monitor: mon[1],
            isDefault: /default\s*=\s*true/.test(body)
        });
    }
    return rules;
}

function mergeWorkspaceRule(rules, next) {
    const kept = [];
    for (const rule of rules || []) {
        // Replace the rule for the same workspace, and drop whatever default
        // workspace this monitor previously owned (otherwise changing the pin
        // leaves the old workspace glued to the monitor).
        if (rule.workspace === next.workspace)
            continue;
        if (next.isDefault && rule.monitor === next.monitor && rule.isDefault)
            continue;
        if (next.isDefault && rule.monitor === next.monitor) {
            const cleared = Object.assign({}, rule);
            cleared.isDefault = false;
            kept.push(cleared);
        } else {
            kept.push(rule);
        }
    }
    kept.push(next);
    return kept;
}

function fileHeader(date) {
    const d = date || new Date();
    const pad = n => String(n).padStart(2, "0");
    const day = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
    const time = `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
    return `-- Generated by custom-caelestia on ${day} at ${time}. Do not edit manually.`;
}
