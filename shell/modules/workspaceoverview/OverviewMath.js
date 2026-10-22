.pragma library

// Pure logic for the SUPER+TAB overview: window search, keyboard selection
// order and workspace paging. No QML types, so it can be tested with node
// (tests/overview_math_test.js).

function normalize(query) {
    return String(query ?? "").trim().toLowerCase();
}

// A window matches when every whitespace-separated term appears in its title
// or its app class. "kit cat" finds a "kitty" window titled "cat pictures".
function matches(window, query) {
    const needle = normalize(query);
    if (!needle)
        return true;
    const haystack = `${window?.title ?? ""} ${window?.winClass ?? ""}`.toLowerCase();
    return needle.split(/\s+/).every(term => haystack.indexOf(term) !== -1);
}

// Matching windows in reading order: workspace, then top to bottom, then left
// to right. Up/Down cycle through this list, so selection moves the way the
// eye scans the overview.
function orderedMatches(windows, query) {
    return (windows || [])
        .filter(w => matches(w, query))
        .slice()
        .sort((a, b) =>
            (a.wsId - b.wsId) ||
            (a.posY - b.posY) ||
            (a.posX - b.posX) ||
            String(a.address).localeCompare(String(b.address)))
        .map(w => w.address);
}

// First page offset that shows the given workspace.
function pageOffsetFor(wsId, pageSize) {
    const size = Math.max(1, Number(pageSize) || 1);
    const id = Math.max(1, Number(wsId) || 1);
    return Math.floor((id - 1) / size) * size;
}

function pageCount(maxWorkspaceId, pageSize) {
    const size = Math.max(1, Number(pageSize) || 1);
    const max = Math.max(1, Number(maxWorkspaceId) || 1);
    return Math.max(1, Math.ceil(max / size));
}

// Clamp a page index into range and return its workspace offset.
function clampPageOffset(offset, pageSize, maxWorkspaceId) {
    const size = Math.max(1, Number(pageSize) || 1);
    const pages = pageCount(maxWorkspaceId, size);
    const index = Math.max(0, Math.min(pages - 1, Math.floor((Number(offset) || 0) / size)));
    return index * size;
}

// Next/previous address with wraparound. With no current selection, forward
// lands on the first entry and backward on the last one.
function stepAddress(addresses, current, delta) {
    const list = addresses || [];
    if (list.length === 0)
        return "";
    const index = list.indexOf(current);
    if (index === -1)
        return delta < 0 ? list[list.length - 1] : list[0];
    const step = Number(delta) || 0;
    return list[(((index + step) % list.length) + list.length) % list.length];
}
