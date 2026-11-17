.pragma library

// Pure helpers for the launcher's row preview cache.
//
// The first screen of the launcher is needed within a frame of the keypress,
// but AppDb only fills its list ~300-400 ms after the shell starts. The first
// few rows (name, comment, icon) are therefore stored in
// `Paths.state/launcher-preview.json` and rendered immediately, so an early
// open paints complete rows instead of waiting for the DB.
//
// Once AppDb settles the list is extended in place from the preview order, so
// nothing that is already on screen moves. No QML types are used here, so the
// suite runs with node (tests/launcher_preview_test.js).

const VERSION = 1;

function clean(row) {
    if (!row || typeof row !== "object")
        return null;
    const id = typeof row.id === "string" ? row.id : "";
    if (!id)
        return null;
    return {
        id,
        name: typeof row.name === "string" && row.name ? row.name : id,
        comment: typeof row.comment === "string" ? row.comment : "",
        icon: typeof row.icon === "string" ? row.icon : ""
    };
}

// Accepts the file's text (or nothing) and returns the rows it can trust.
// Anything unreadable, of another version, or with the wrong shape yields no
// rows, and the caller simply falls back to waiting for the app DB.
function parse(raw) {
    let data;
    try {
        data = JSON.parse(String(raw ?? ""));
    } catch (e) {
        return { rows: [], savedAt: 0 };
    }

    if (!data || typeof data !== "object" || data.version !== VERSION)
        return { rows: [], savedAt: 0 };

    const rows = Array.isArray(data.rows) ? data.rows.map(clean).filter(Boolean) : [];
    const seen = new Set();
    const unique = rows.filter(row => {
        if (seen.has(row.id))
            return false;
        seen.add(row.id);
        return true;
    });

    const savedAt = Number(data.savedAt);
    return {
        rows: unique,
        savedAt: Number.isFinite(savedAt) && savedAt > 0 ? savedAt : 0
    };
}

function serialize(rows, savedAt) {
    return JSON.stringify({
        version: VERSION,
        savedAt: Number(savedAt) || 0,
        rows: (rows || []).map(clean).filter(Boolean)
    });
}

// Order the live apps the way the preview had them, appending everything else
// in AppDb order. Ids that no longer exist are skipped, so an uninstalled app
// does not leave a hole and a freshly installed one still shows up.
function merge(apps, ids) {
    const list = apps || [];
    const byId = new Map();
    for (const app of list) {
        if (app && typeof app.id === "string")
            byId.set(app.id, app);
    }

    const out = [];
    const seen = new Set();
    for (const id of ids || []) {
        const app = byId.get(id);
        if (!app || seen.has(id))
            continue;
        out.push(app);
        seen.add(id);
    }

    for (const app of list) {
        if (!app || seen.has(app.id))
            continue;
        out.push(app);
        seen.add(app.id);
    }

    return out;
}
