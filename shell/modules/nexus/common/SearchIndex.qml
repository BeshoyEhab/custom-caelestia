pragma Singleton

import QtQuick

QtObject {
    id: root

    property var entries: []
    property int currentPage: 0
    property var currentSubs: []

    function setLocation(page: int, subs: var): void {
        currentPage = page;
        currentSubs = subs.slice();
    }

    function pushSub(idx: int): void {
        currentSubs = [...currentSubs, idx];
    }

    function popSub(): void {
        currentSubs = currentSubs.slice(0, -1);
    }

    function registerRow(item: var, labelFn: var, subFn: var): void {
        unregisterRow(item);
        entries = [...entries, {
            item: item,
            labelFn: labelFn,
            subFn: subFn,
            page: currentPage,
            subs: currentSubs.slice()
        }];
    }

    function unregisterRow(item: var): void {
        entries = entries.filter(e => e.item !== item);
    }

    function query(text: string): var {
        const q = text.trim().toLowerCase();
        if (!q)
            return [];
        const out = [];
        for (const e of entries) {
            if (!e.item)
                continue;
            const label = String(e.labelFn ? e.labelFn() : "");
            const sub = String(e.subFn ? e.subFn() : "");
            if (label.toLowerCase().includes(q) || sub.toLowerCase().includes(q))
                out.push(e);
        }
        return out.slice(0, 30);
    }
}
