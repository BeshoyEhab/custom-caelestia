pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import Caelestia
import Caelestia.Config
import qs.utils
import "OrderCache.js" as OrderCache

Searcher {
    id: root

    function launch(entry: DesktopEntry): void {
        root.remember(entry.id);
        appDb.incrementFrequency(entry.id);

        if (entry.runInTerminal)
            Quickshell.execDetached({
                command: ["app2unit", "--", ...GlobalConfig.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, ...entry.command],
                workingDirectory: entry.workingDirectory
            });
        else
            Quickshell.execDetached({
                command: ["app2unit", "--", ...entry.command],
                workingDirectory: entry.workingDirectory
            });
    }

    // Remember the exact query (typo/synonym/shortcut) the user used to pick this app.
    function remember(id: string): void {
        const q = root.lastQuery;
        if (q)
            appDb.learnQuery(q, id);
    }

    // Normalize the raw search box text into the query form stored/queried for aliases.
    function activeQuery(text: string): string {
        return text.trim().replace(/\s+/g, " ").toLowerCase().replace(/^[@>][a-zA-Z]*\s+/, "");
    }

    property string lastQuery: ""

    // Feed learned aliases into the shared scoring (items are AppEntry, keyed by id).
    function aliasScores(queryText: string): var {
        return appDb.queryAliases(queryText);
    }

    function search(search: string): list<var> {
        root.lastQuery = activeQuery(search);

        // Empty query: the cached default order instead of AppDb's live sort,
        // which reorders whenever an app is launched. See the cache below.
        if (!search.trim())
            return OrderCache.merge(appDb.apps, root.orderIds).map(app => app.entry);

        const prefix = GlobalConfig.launcher.specialPrefix;

        if (search.startsWith(`${prefix}i `)) {
            keys = ["id", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}c `)) {
            keys = ["categories", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}d `)) {
            keys = ["comment", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}e `)) {
            keys = ["execString", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}w `)) {
            keys = ["startupClass", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}g `)) {
            keys = ["genericName", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}k `)) {
            keys = ["keywords", "name"];
            weights = [0.9, 0.1];
        } else {
            keys = ["name", "genericName", "keywords", "comment"];
            weights = [0.5, 0.2, 0.2, 0.1];

            if (!search.startsWith(`${prefix}t `))
                return query(search).map(e => e.entry);
        }

        const results = query(search.slice(prefix.length + 2)).map(e => e.entry);
        if (search.startsWith(`${prefix}t `))
            return results.filter(a => a.runInTerminal);
        return results;
    }

    function selector(item: var): string {
        return keys.map(k => item[k]).join(" ");
    }

    list: appDb.apps
    useFuzzy: GlobalConfig.launcher.useFuzzy.apps

    // AppDb fills in asynchronously: DesktopEntries streams entries in, AppDb
    // batches them (300ms), and the favourite/hidden filters from the config
    // can land after that. Every batch re-sorts the list, so a first open that
    // happens while loading makes the visible rows jump around two or three
    // times. The launcher waits for a quiet period after the last batch; this
    // flips once and stays set.
    property bool settled: false
    property bool sawAppBatch: false
    property bool sawEntries: false

    Timer {
        id: settleTimer

        // The long value is a fallback for systems with no desktop entries at
        // all; entries restart it with a longer grace period than the batches,
        // because AppDb only fills its list 300ms after the entries go quiet.
        interval: root.sawAppBatch ? 400 : root.sawEntries ? 800 : 1500
        onTriggered: root.settled = true

        Component.onCompleted: start()
    }

    Connections {
        target: appDb

        function onEntriesChanged(): void {
            root.sawEntries = true;
            settleTimer.restart();
        }

        function onAppsChanged(): void {
            root.sawAppBatch = true;
            settleTimer.restart();
            if (root.settled)
                root.refreshOrder();
        }
    }

    onSettledChanged: {
        if (settled)
            refreshOrder();
    }

    // ── Cached default order ─────────────────────────────────────────────────
    // AppDb orders the unfiltered list by favourites, then use frequency, then
    // name, and re-sorts on every launch. Persisting that order keeps the
    // launcher's first screen identical across sessions; it is rewritten when
    // the app set changes (install, uninstall, hidden app), when the
    // favourites change, or once it is a day old. See OrderCache.js.
    readonly property string orderPath: `${Paths.state}/launcher-order.json`
    readonly property int orderRefreshMs: 24 * 60 * 60 * 1000

    property var orderIds: []
    property var orderFavourites: []
    property real orderSavedAt: 0
    property bool orderLoaded: false

    function refreshOrder(): void {
        if (!root.settled || !root.orderLoaded)
            return;

        const apps = appDb.apps;
        const favourites = GlobalConfig.launcher.favouriteApps;
        const now = Date.now();
        const cached = {
            ids: root.orderIds,
            favourites: root.orderFavourites,
            savedAt: root.orderSavedAt
        };

        if (!OrderCache.needsRefresh(cached, apps, favourites, now, root.orderRefreshMs))
            return;

        root.orderIds = apps.map(app => app.id);
        root.orderFavourites = favourites.slice();
        root.orderSavedAt = now;
        orderFile.setText(OrderCache.serialize(root.orderIds, root.orderFavourites, now));
    }

    FileView {
        id: orderFile

        path: root.orderPath
        printErrors: false

        onLoaded: {
            const state = OrderCache.parse(text());
            root.orderIds = state.ids;
            root.orderFavourites = state.favourites;
            root.orderSavedAt = state.savedAt;
            root.orderLoaded = true;
            root.refreshOrder();
        }

        onLoadFailed: {
            root.orderLoaded = true;
            root.refreshOrder();
        }
    }

    // A session that stays up for days still refreshes an expired order. The
    // launcher list is a snapshot per open, so this cannot move visible rows.
    Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: root.settled
        onTriggered: root.refreshOrder()
    }

    Connections {
        target: GlobalConfig.launcher

        function onFavouriteAppsChanged(): void {
            root.refreshOrder();
        }
    }

    // Learned alias memory: boost apps you habitually pick for a given query.
    useLearnedAliases: true
    aliasBoost: root.aliasScores
    aliasIdField: "id"
    aliasBoostWeight: 0.5

    AppDb {
        id: appDb

        path: `${Paths.state}/apps.sqlite`
        favouriteApps: GlobalConfig.launcher.favouriteApps
        entries: DesktopEntries.applications.values.filter(a => !Strings.testRegexList(GlobalConfig.launcher.hiddenApps, a.id))
    }
}
