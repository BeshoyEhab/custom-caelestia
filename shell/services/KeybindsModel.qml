pragma Singleton

import QtQuick
import Quickshell
import "Keybinds.js" as Keybinds

Singleton {
    id: root

    // Groups shaped by Keybinds.group(): [{ category, binds: [{ combo, action }] }]
    property var groups: []
    // Flat rows for the ListView: headers and binds in display order.
    property var rows: []
    property string query: ""
    property string lastError: ""
    property bool includeUnlabeled: false
    property string raw: ""

    readonly property int bindCount: groups.reduce((sum, group) => sum + group.binds.length, 0)

    onIncludeUnlabeledChanged: {
        if (raw.length > 0)
            load(raw);
    }

    function load(json: string): void {
        raw = json;
        try {
            groups = Keybinds.group(Keybinds.parseBinds(json, includeUnlabeled));
            lastError = "";
            applyFilter();
        } catch (e) {
            groups = [];
            rows = [];
            lastError = `Could not read keybinds: ${e}`;
        }
    }

    function applyFilter(): void {
        const filtered = Keybinds.filterBinds(groups, query);
        const next = [];
        for (const group of filtered) {
            next.push({ kind: "header", label: group.category, count: group.binds.length });
            for (const bind of group.binds)
                next.push({ kind: "bind", combo: bind.combo, keys: bind.keys, combos: bind.combos, action: bind.action });
        }
        rows = next;
    }

    onQueryChanged: applyFilter()
}
