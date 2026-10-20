.pragma library

// Turns `hyprctl binds -j` output into cheat-sheet groups. Pure functions so
// the parser can be unit-tested with node (tests/keybinds_parse_test.js).

// Hyprland modifier bits, in display order.
const MODS = [
    [64, "SUPER"],
    [4, "CTRL"],
    [8, "ALT"],
    [1, "SHIFT"]
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
    Delete: "Delete"
};

const MOUSE_NAMES = {
    272: "Left Click",
    273: "Right Click",
    274: "Middle Click",
    275: "Side Click",
    276: "Extra Click"
};

function keyLabel(key) {
    if (!key)
        return "";
    if (key.startsWith("mouse:")) {
        const code = key.slice(6);
        return MOUSE_NAMES[code] ?? `Mouse ${code}`;
    }
    if (key.startsWith("code:"))
        return `Keycode ${key.slice(5)}`;
    return KEY_NAMES[key] ?? key;
}

function comboFor(bind) {
    const parts = [];
    const mask = Number(bind.modmask) || 0;
    for (const [bit, name] of MODS) {
        if (mask & bit)
            parts.push(name);
    }
    parts.push(keyLabel(String(bind.key ?? "")));
    return parts.filter(p => p.length > 0).join(" + ");
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

function parseBinds(json) {
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
        if (bind.has_description === false)
            continue;
        const description = String(bind.description ?? "").trim();
        if (!description)
            continue;
        const split = splitDescription(description);
        binds.push({
            combo: comboFor(bind),
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
        groups.push({ category: category, binds: items });
    }
    return groups;
}

function matches(bind, query) {
    const needle = query.toLowerCase();
    return bind.combo.toLowerCase().includes(needle)
        || bind.action.toLowerCase().includes(needle)
        || bind.category.toLowerCase().includes(needle);
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
