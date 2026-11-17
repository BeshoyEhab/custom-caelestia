pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import Caelestia
import Caelestia.Config
import qs.utils
import "PreviewCache.js" as PreviewCache

Searcher {
    id: root

    // `entry` is a DesktopEntry, or a cached preview row ({id, name, ...}) when
    // the launcher opened before AppDb had settled. Resolve the row by id; the
    // DB is always loaded by the time a row can be clicked.
    function launch(entry: var): void {
        const resolved = root.resolve(entry);
        if (!resolved)
            return;

        root.remember(resolved.id);
        appDb.incrementFrequency(resolved.id);

        if (resolved.runInTerminal)
            Quickshell.execDetached({
                command: ["app2unit", "--", ...GlobalConfig.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, ...resolved.command],
                workingDirectory: resolved.workingDirectory
            });
        else
            Quickshell.execDetached({
                command: ["app2unit", "--", ...resolved.command],
                workingDirectory: resolved.workingDirectory
            });
    }

    function resolve(entry: var): var {
        if (!entry)
            return null;
        if (entry.command !== undefined)
            return entry;
        // Preview row that the DB settle handler already bound to its entry.
        if (entry.entry)
            return entry.entry;

        for (const app of appDb.apps)
            if (app.id === entry.id)
                return app.entry;

        return null;
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
                previewTimer.restart();
        }
    }

    onSettledChanged: {
        if (settled)
            writePreview();
    }

    // ── Row preview cache ───────────────────────────────────────────────────
    // The first screen needs rows within a frame, but AppDb fills in ~300-400ms
    // after the shell starts. The first few rows are kept on disk (name,
    // comment, icon) and painted straight away, so an open during startup shows
    // complete rows instead of waiting. `expandPreview()` swaps them for the
    // real entries once the DB settles, keeping the preview order so nothing on
    // screen moves. See PreviewCache.js.
    readonly property string previewPath: `${Paths.state}/launcher-preview.json`
    // Config.launcher.maxShown defaults to 7; two spare rows keep the visible
    // area covered on a taller panel.
    readonly property int previewCount: 12

    property var previewRows: []

    readonly property bool previewReady: previewRows.length > 0

    // Rows for the pre-settle list: plain objects the delegate can render.
    function previewResults(): var {
        return root.previewRows;
    }

    // Real entries, preview order first, everything else appended in AppDb
    // order. The preview rows keep their identity (the delegate binds to them
    // and only their `entry` is filled in), so the rows on screen are not
    // rebuilt when the DB settles. Used when the DB settles while the launcher
    // is already open.
    function expandPreview(rows: var, ids: var): var {
        const known = new Set(ids);

        for (const row of rows) {
            const app = root.appById(row.id);
            if (app)
                row.entry = app.entry;
        }

        const out = rows.slice();
        for (const app of PreviewCache.merge(appDb.apps, ids))
            if (!known.has(app.id))
                out.push(app.entry);

        return out;
    }

    function appById(id: string): var {
        for (const app of appDb.apps)
            if (app.id === id)
                return app;
        return null;
    }

    function writePreview(): void {
        if (!root.settled)
            return;

        const rows = [];
        for (const app of appDb.apps) {
            if (rows.length >= root.previewCount)
                break;
            const entry = app.entry;
            if (!entry)
                continue;
            rows.push({
                id: app.id,
                name: entry.name || app.name || app.id,
                comment: entry.comment || entry.genericName || "",
                icon: entry.icon || ""
            });
        }

        root.previewRows = rows;
        if (rows.length)
            previewFile.setText(PreviewCache.serialize(rows, Date.now()));
    }

    FileView {
        id: previewFile

        path: root.previewPath
        printErrors: false

        onLoaded: root.previewRows = PreviewCache.parse(text()).rows
        onLoadFailed: root.previewRows = []
    }

    // Installs, removals, hidden apps and favourites can all change the first
    // screen; coalesce the batches AppDb emits while it re-sorts.
    Timer {
        id: previewTimer

        interval: 1500
        onTriggered: root.writePreview()
    }

    Connections {
        target: GlobalConfig.launcher

        function onFavouriteAppsChanged(): void {
            previewTimer.restart();
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
