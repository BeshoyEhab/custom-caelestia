.pragma library

// Pure logic for the launcher's cached default order.
//
// The unfiltered list is ordered by AppDb: favourites first, then use
// frequency, then name. That order keeps moving as apps get launched, so the
// first screen of the launcher changed between sessions and during the startup
// load. `Apps` writes the ids of the settled order to
// `Paths.state/launcher-order.json` and reuses it until the app set or the
// favourites change, or the file is older than a day.
//
// No QML types are used here, so the suite runs with node
// (tests/launcher_order_test.js).

const VERSION = 1;

const EMPTY = Object.freeze({ ids: [], favourites: [], savedAt: 0 });

// Accepts the file's text (or nothing) and returns a usable state. Anything
// unreadable, of another version, or with the wrong shape falls back to EMPTY
// so the caller simply rebuilds the cache.
function parse(raw) {
    let data;
    try {
        data = JSON.parse(String(raw ?? ""));
    } catch (e) {
        return { ids: [], favourites: [], savedAt: 0 };
    }

    if (!data || typeof data !== "object" || data.version !== VERSION)
        return { ids: [], favourites: [], savedAt: 0 };

    const savedAt = Number(data.savedAt);
    return {
        ids: Array.isArray(data.ids) ? data.ids.filter(id => typeof id === "string" && id.length > 0) : [],
        favourites: Array.isArray(data.favourites) ? data.favourites.filter(f => typeof f === "string") : [],
        savedAt: Number.isFinite(savedAt) && savedAt > 0 ? savedAt : 0
    };
}

function serialize(ids, favourites, savedAt) {
    return JSON.stringify({
        version: VERSION,
        savedAt: Number(savedAt) || 0,
        favourites: Array.from(favourites || []),
        ids: Array.from(ids || [])
    });
}

// Order the live apps the way the cache says, appending anything the cache has
// never seen (a freshly installed app) in AppDb order. Ids that no longer
// exist (uninstalled app, newly hidden) are skipped.
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

function sameStrings(a, b) {
    const left = a || [];
    const right = b || [];
    if (left.length !== right.length)
        return false;
    for (let i = 0; i < left.length; i++)
        if (left[i] !== right[i])
            return false;
    return true;
}

// Whether the file should be rewritten. Deliberately ignores pure reordering:
// AppDb resorts on every launch, and following that would defeat the cache.
// A changed set (install/uninstall/hide), changed favourites, a missing file or
// an expired one all trigger a rewrite.
function needsRefresh(cached, apps, favourites, now, maxAgeMs) {
    const list = apps || [];
    if (list.length === 0)
        return false; // never replace a good cache with a DB that has not filled in

    const state = cached || EMPTY;
    if (!state.savedAt)
        return true;

    const maxAge = Number(maxAgeMs);
    const age = Number(now) - state.savedAt;
    if (Number.isFinite(maxAge) && maxAge > 0 && Number.isFinite(age) && age > maxAge)
        return true;

    const known = new Set(state.ids || []);
    if (known.size !== list.length)
        return true;
    for (const app of list) {
        if (!app || !known.has(app.id))
            return true;
    }

    return !sameStrings(state.favourites, favourites);
}
