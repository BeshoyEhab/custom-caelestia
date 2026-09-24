import QtQuick
import Caelestia.Config
import qs.components
import qs.modules.nexus
import qs.modules.nexus.common

Item {
    id: root

    required property NexusState nState

    property int lastPageIdx
    property int animOff
    property Item currentItem

    function loadPage(idx: int): void {
        const pending = root.nState.pendingRow;
        if (pending && pending.page === idx) {
            // Search jump to this page: gotoRow's sub-pushes went to the
            // outgoing StackView (now doomed) and the setLocation below
            // resets SearchIndex. Clear the stack so the fresh StackPage
            // replays nothing; consumePendingRow re-drives the subs
            // post-attach through openSubPage (correct progressive
            // SearchIndex locations + live pushes).
            root.nState.subPageIdxStack = [];
        } else if (pending) {
            // Stale jump (user navigated elsewhere first): abandon silently
            // so a later attach never scrolls to the wrong page.
            root.nState.pendingRow = null;
        }
        SearchIndex.setLocation(idx, []);
        if (currentItem)
            currentItem.destroy();

        // Clamp: a stale index (e.g. from a list in transition) must land on
        // a real page, never on the under-construction fallback.
        const safeIdx = (idx >= 0 && idx < PageCompRegistry.pageComps.length) ? idx : 0;
        const comp = PageCompRegistry.pageComps[safeIdx] ?? PageCompRegistry.placeholderComp;
        const incubator = comp.incubateObject(container, {
            nState
        });

        const attach = () => {
            incubator.object.anchors.fill = container;
            currentItem = incubator.object;
            root.consumePendingRow();
        };

        if (incubator.status === Component.Ready)
            attach();
        else
            incubator.onStatusChanged = status => {
                if (status === Component.Ready)
                    attach();
            };
    }

    // Deep-search jump consumer (CF2): re-applies pendingRow.subs post-load
    // in order, then centers the viewport on the matching row with retries.
    // Entry shape: {page, subs (array copy), label, occurrence}.
    function consumePendingRow(): void {
        const target = root.nState.pendingRow;
        if (!target)
            return;
        root.nState.pendingRow = null;
        if (!root.currentItem)
            return;
        if ((target.page ?? -1) !== root.nState.currentPageIdx)
            return;
        const want = target.subs ?? [];
        const have = root.nState.subPageIdxStack ?? [];
        let match = want.length === have.length;
        if (match) {
            for (let i = 0; i < want.length; i++) {
                if (want[i] !== have[i]) {
                    match = false;
                    break;
                }
            }
        }
        if (!match) {
            root.nState.subPageIdxStack = [];
            SearchIndex.setLocation(target.page, []);
            for (const s of want)
                root.nState.openSubPage(s);
        }
        scrollTimer.target = target;
        scrollTimer.attempts = 0;
        scrollTimer.start();
    }

    // Nth live row matching page + element-wise subs + label (occurrence
    // counts same-key matches in registration order).
    function findRowItem(target: var): var {
        if (!target)
            return null;
        const wantSubs = target.subs ?? [];
        const label = target.label ?? "";
        const occ = target.occurrence ?? 0;
        let seen = 0;
        const all = SearchIndex.entries ?? [];
        for (let i = 0; i < all.length; i++) {
            const e = all[i];
            if (!e || !e.item)
                continue;
            if ((e.page ?? -1) !== target.page)
                continue;
            const es = e.subs ?? [];
            if (es.length !== wantSubs.length)
                continue;
            let same = true;
            for (let k = 0; k < es.length; k++) {
                if (es[k] !== wantSubs[k]) {
                    same = false;
                    break;
                }
            }
            if (!same)
                continue;
            let l = "";
            try {
                l = String(e.labelFn ? e.labelFn() : "");
            } catch (err) {
                continue;
            }
            if (l !== label)
                continue;
            if (seen === occ)
                return e.item;
            seen++;
        }
        return null;
    }

    // Center the visible sub-page's flickable on item. False = retry later
    // (row not registered yet or layout not ready).
    function tryCenter(target: var): bool {
        const item = root.findRowItem(target);
        if (!item || !item.mapToItem)
            return false;
        // currentItem is the StackPage (StackView); the visible PageBase
        // with the flickable is its currentItem.
        const stack = root.currentItem;
        const page = stack ? stack.currentItem : null;
        if (!page || !page.flickable)
            return false;
        const flick = page.flickable;
        if (!flick || !flick.contentItem)
            return false;
        if ((flick.height ?? 0) <= 0)
            return false;
        let p = null;
        try {
            p = item.mapToItem(flick.contentItem, 0, 0);
        } catch (err) {
            return false;
        }
        if (!p)
            return false;
        const h = flick.height;
        const maxY = Math.max(0, (flick.contentHeight ?? 0) - h);
        const y = p.y - h / 2 + (item.height ?? 0) / 2;
        flick.contentY = Math.max(0, Math.min(maxY, y));
        return true;
    }

    Timer {
        id: scrollTimer

        interval: 120
        repeat: true
        property var target: null
        property int attempts: 0
        onTriggered: {
            attempts++;
            if (!target) {
                stop();
                return;
            }
            if (root.tryCenter(target)) {
                target = null;
                stop();
            } else if (attempts >= 8) {
                target = null;
                stop();
            }
        }
    }

    Item {
        id: container

        objectName: "PageContainer"
        anchors.fill: parent
        layer.enabled: opacity < 1
        Component.onCompleted: root.loadPage(root.nState.currentPageIdx)
    }

    Connections {
        function onCurrentPageIdxChanged(): void {
            switchAnim.complete();
            root.animOff = root.Tokens.padding.extraLarge * (root.nState.currentPageIdx > root.lastPageIdx ? 1 : -1);
            switchAnim.start();
            root.lastPageIdx = root.nState.currentPageIdx;
        }

        target: root.nState
    }

    SequentialAnimation {
        id: switchAnim

        Anim {
            target: container
            property: "opacity"
            to: 0
            type: Anim.DefaultEffects
        }
        ScriptAction {
            script: root.loadPage(root.nState.currentPageIdx)
        }
        PropertyAction {
            target: container.anchors
            property: "topMargin"
            value: root.animOff
        }
        PropertyAction {
            target: container.anchors
            property: "bottomMargin"
            value: -root.animOff
        }
        ParallelAnimation {
            Anim {
                target: container
                property: "opacity"
                from: 0
                to: 1
                type: Anim.SlowEffects
            }
            Anim {
                target: container.anchors
                properties: "topMargin,bottomMargin"
                to: 0
                type: Anim.SlowEffects
            }
        }
    }
}
