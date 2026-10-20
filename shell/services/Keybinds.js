.pragma library

// Turns `hyprctl binds -j` output into cheat-sheet groups. Pure functions so
// the parser can be unit-tested with node (tests/keybinds_parse_test.js).

// Hyprland modifier bits: [bit, plain name, keycap label]. Windows-style
// keycaps: the Windows key glyph plus the labels printed on PC keyboards.
const MODS = [
    [64, "SUPER", "⊞"],
    [4, "CTRL", "Ctrl"],
    [8, "ALT", "Alt"],
    [1, "SHIFT", "Shift"]
];

const KEY_NAMES = {
    Slash: "/",
    Period: ".",
    Comma: ",",
    Semicolon: ";",
    Apostrophe: "'",
    Minus: "-",
    Equal: "=",
    Backslash: "\\",
    BracketLeft: "[",
    BracketRight: "]",
    Grave: "`",
    Space: "Space",
    Return: "Enter",
    Tab: "Tab",
    Escape: "Esc",
    Page_Up: "Page Up",
    Page_Down: "Page Down",
    Home: "Home",
    End: "End",
    Insert: "Insert",
    Delete: "Delete",
    Left: "Left",
    Right: "Right",
    Up: "Up",
    Down: "Down"
};

// Keycap glyphs: modifiers and navigation keys read faster as symbols.
const KEY_SYMBOLS = Object.assign({}, KEY_NAMES, {
    Space: "Space",
    Return: "Enter",
    Tab: "Tab",
    Escape: "Esc",
    Page_Up: "PgUp",
    Page_Down: "PgDn",
    Home: "Home",
    End: "End",
    Insert: "Ins",
    Delete: "Del",
    Backspace: "Backspace",
    Left: "←",
    Right: "→",
    Up: "↑",
    Down: "↓",
    Print: "PrtSc",
    Caps_Lock: "Caps",
    Menu: "Menu"
});

const MOUSE_NAMES = {
    272: "Left Click",
    273: "Right Click",
    274: "Middle Click",
    275: "Side Click",
    276: "Extra Click"
};

function keyLabel(key, symbols) {
    if (!key)
        return "";
    if (key.startsWith("mouse:")) {
        const code = key.slice(6);
        return MOUSE_NAMES[code] ?? `Mouse ${code}`;
    }
    if (key.startsWith("code:"))
        return `Keycode ${key.slice(5)}`;
    const map = symbols ? KEY_SYMBOLS : KEY_NAMES;
    return map[key] ?? key;
}

function comboFor(bind, symbols) {
    const parts = [];
    const mask = Number(bind.modmask) || 0;
    for (const mod of MODS) {
        if (mask & mod[0])
            parts.push(symbols ? mod[2] : mod[1]);
    }
    parts.push(keyLabel(String(bind.key ?? ""), symbols));
    return parts.filter(p => p.length > 0).join(" + ");
}

function keysFor(bind) {
    const keys = [];
    const mask = Number(bind.modmask) || 0;
    for (const mod of MODS) {
        if (mask & mod[0])
            keys.push(mod[2]);
    }
    keys.push(keyLabel(String(bind.key ?? ""), true));
    return keys.filter(k => k.length > 0);
}

// Hyprland reports an empty key for binds written with `code:<n>` (the
// workspace 1-10 binds in this config are loop-generated that way). When the
// description ends in a number we can still show the pair, collapsed.
function numberedFallback(bind) {
    const description = String(bind.description ?? "").trim();
    const match = description.match(/\s(\d+)$/);
    if (!match)
        return null;
    return {
        key: "<Number>",
        description: description.slice(0, match.index) + " <Number>"
    };
}

// Workspace numbers are ten near-identical binds: keep the first and show it
// as <Number>. Directions are NOT merged: "send to workspace left" and
// "...right" are different actions, and merging them produced rows with eight
// key combos.
function isRepetitiveTail(bind) {
    const key = String(bind.key ?? "");
    if (/^(mouse|page)/i.test(key))
        return false;
    if (key === "<Number>")
        return false;
    return /^[2-9]$/.test(key) || key === "0";
}

function isRepetitiveHead(bind) {
    const key = String(bind.key ?? "");
    return key === "1" || key === "<Number>";
}

function genericKey(key) {
    return String(key ?? "").replace(/^1$/, "<Number>");
}

function genericAction(action) {
    return String(action ?? "").replace(/\b1\b/, "<Number>");
}

function blankTo(value, fallback) {
    const text = String(value ?? "");
    return text.length > 0 ? text : fallback;
}

function splitDescription(description) {
    const text = String(description ?? "").trim();
    const index = text.indexOf(": ");
    if (index === -1)
        return { category: "Other", action: text };
    return {
        category: text.slice(0, index).trim(),
        action: text.slice(index + 2).trim()
    };
}

function parseBinds(json, includeUnlabeled) {
    let raw;
    try {
        raw = JSON.parse(json);
    } catch (e) {
        return [];
    }
    if (!Array.isArray(raw))
        return [];

    const binds = [];
    for (const bind of raw) {
        if (!bind)
            continue;
        if (bind.submap)
            continue;

        let key = String(bind.key ?? "");
        let description = String(bind.description ?? "").trim();
        if (!key) {
            const fallback = description ? numberedFallback(bind) : null;
            if (!fallback)
                continue;
            key = fallback.key;
            description = fallback.description;
        }
        if (!description && !includeUnlabeled)
            continue;

        const split = description ? splitDescription(description) : { category: "Unlabeled", action: "No description in config" };
        binds.push({
            combo: comboFor({ modmask: bind.modmask, key: key }, false),
            keys: keysFor({ modmask: bind.modmask, key: key }),
            key: key,
            modmask: Number(bind.modmask) || 0,
            description: description,
            category: split.category,
            action: split.action,
            mouse: bind.mouse === true,
            submap: bind.submap ?? ""
        });
    }
    return binds;
}

function group(binds) {
    const byCategory = new Map();
    for (const bind of binds || []) {
        if (!byCategory.has(bind.category))
            byCategory.set(bind.category, []);
        byCategory.get(bind.category).push(bind);
    }
    const groups = [];
    for (const category of [...byCategory.keys()].sort((a, b) => a.localeCompare(b))) {
        const items = byCategory.get(category);
        items.sort((a, b) => (a.combo.length - b.combo.length) || a.combo.localeCompare(b.combo));

        const seen = new Set();
        const kept = [];
        for (const bind of items) {
            if (isRepetitiveTail(bind))
                continue;
            let combo = bind.combo;
            let keys = bind.keys;
            let action = bind.action;
            if (isRepetitiveHead(bind)) {
                const generic = { modmask: bind.modmask, key: genericKey(bind.key) };
                combo = comboFor(generic, false);
                keys = keysFor(generic);
                action = genericAction(bind.action);
            }
            const signature = `${combo}|${action}`;
            if (seen.has(signature))
                continue;
            seen.add(signature);
            kept.push(Object.assign({}, bind, { combo: combo, keys: keys, action: action }));
        }
        // Two keys with the same description are the same action: show them
        // in one row so the equivalence is visible.
        const byAction = new Map();
        const merged = [];
        for (const bind of kept) {
            const signature = bind.action.toLowerCase();
            if (!byAction.has(signature)) {
                const entry = Object.assign({}, bind, { combos: [] });
                byAction.set(signature, entry);
                merged.push(entry);
            }
            byAction.get(signature).combos.push({
                combo: bind.combo,
                keys: bind.keys,
                mouse: bind.mouse
            });
        }

        if (merged.length > 0)
            groups.push({ category: category, binds: merged });
    }
    return groups;
}

function matches(bind, query) {
    const needle = query.toLowerCase();
    if (bind.action.toLowerCase().includes(needle) || bind.category.toLowerCase().includes(needle))
        return true;
    const combos = bind.combos || [{ combo: bind.combo }];
    return combos.some(c => String(c.combo).toLowerCase().includes(needle));
}

function filterBinds(groups, query) {
    const needle = String(query ?? "").trim();
    if (!needle)
        return groups || [];
    const out = [];
    for (const groupEntry of groups || []) {
        const hits = groupEntry.binds.filter(b => matches(b, needle));
        if (hits.length > 0)
            out.push({ category: groupEntry.category, binds: hits });
    }
    return out;
}
