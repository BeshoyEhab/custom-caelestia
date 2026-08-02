import "scripts/fzf.js" as Fzf
import "scripts/fuzzysort.js" as Fuzzy
import "scripts/levendist.js" as Lev
import QtQuick
import Quickshell

Singleton {
    readonly property bool debug: false

    required property list<QtObject> list
    property string key: "name"
    property bool useFuzzy: false
    property var extraOpts: ({})

    // Extra stuff for fuzzy
    property list<string> keys: [key]
    property list<real> weights: [1]

    // Score threshold
    property real scoreThreshold: 0.25

    // Learned alias memory (e.g. "ff"->Firefox, "gim"->GIMP). When enabled, the
    // scores from `aliasBoost(query)` get added (times `aliasBoostWeight`) to
    // each matching item so apps you habitually pick for a given query (including
    // its typos and synonyms) rise to the top next time.
    property bool useLearnedAliases: false
    property var aliasBoost: null // function(query) -> {idKey: 0..1}
    property string aliasIdField: "id"
    property real aliasBoostWeight: 0.4

    function learnedScore(item: var, aliasMap: var): real {
        if (!aliasMap || !item)
            return 0;
        const v = aliasMap[item[aliasIdField]];
        return v ? Math.min(1.0, v) * aliasBoostWeight : 0;
    }

    readonly property var fzf: useFuzzy ? [] : new Fzf.Finder(list, Object.assign({
        selector
    }, extraOpts))

    function transformSearch(search: string): string {
        return search;
    }

    function selector(item: var): string {
        return keys.map(k => item[k]).join(" ");
    }

    // 1 if every char of `needle` appears in `hay` in order (allowing a split).
    function isSubsequence(needle: string, hay: string): bool {
        if (!needle || !hay)
            return false;
        let j = 0;
        for (let i = 0; i < hay.length && j < needle.length; i++) {
            if (hay[i] === needle[j])
                j++;
        }
        return j === needle.length;
    }

    // Near/fuzzy score in [0,1] for a single field, tolerant of typos.
    function getFieldScore(needle: string, hay: string): real {
        if (!needle || !hay)
            return 0;

        if (hay === needle)
            return 1;
        if (hay.startsWith(needle))
            return 0.9 + 0.05 * Math.min(1, needle.length / Math.max(1, hay.length));
        if (hay.includes(needle))
            return 0.8;

        // Levenshtein near-match: fixes "thubderbird" -> "thunderbird".
        const levScore = Lev.computeTextMatchScore(needle, hay);
        if (levScore >= 0.6)
            return levScore;

        // Subsequence fallback: "frfx" -> "firefox".
        if (isSubsequence(needle, hay))
            return 0.5;

        return Math.max(0, Math.min(1, levScore));
    }

    // Best near/fuzzy score across every configured key.
    function getMatchScore(item: var, searchLower: string): real {
        let best = 0;
        for (const k of keys) {
            const t = (item[k] || "").toLowerCase();
            const s = getFieldScore(searchLower, t);
            if (s > best)
                best = s;
        }
        return best;
    }

    // Get usage 0..1 normalized to the most-used app in the list.
    function getUsageScore(item: var, maxFreq: real): real {
        return maxFreq > 0 ? (item.frequency || 0) / maxFreq : 0;
    }

    function query(search: string): list<var> {
        const q = transformSearch(search.trim().replace(/\s+/g, " "));
        if (!q)
            return [...list];

        const searchLower = q.toLowerCase();
        const searchLen = searchLower.length;

        let maxFreq = 0;
        for (const entry of list)
            maxFreq = Math.max(maxFreq, entry.frequency || 0);

        // Dynamic weights: short queries lean on usage more (a single letter is
        // ambiguous), long queries almost entirely on the actual text match.
        let matchWeight, usageWeight;
        if (searchLen === 1) {
            matchWeight = 0.45;
            usageWeight = 0.55;
        } else if (searchLen === 2) {
            matchWeight = 0.55;
            usageWeight = 0.45;
        } else if (searchLen === 3) {
            matchWeight = 0.7;
            usageWeight = 0.3;
        } else {
            matchWeight = 0.85;
            usageWeight = 0.15;
        }

        const aliasMap = useLearnedAliases && typeof aliasBoost === "function"
            ? aliasBoost(searchLower) : null;

        const results = list.map(item => {
            const match = getMatchScore(item, searchLower);
            const usage = getUsageScore(item, maxFreq);
            const aliased = learnedScore(item, aliasMap);

            // never let usage beat a clearly-better text match: usage only
            // contributes once the text genuinely matches, so Thunderbird keeps
            // beating Ferdium even if Ferdium was launched more often.
            let score = match * matchWeight + aliased;
            if (match >= 0.35)
                score += usage * usageWeight * (1 - match);

            return { item, match, usage, score };
        });

        // Longer queries drop clearly-unrelated entries; a lone keystroke keeps
        // the whole (sorted) list so one char still leans on history.
        const minMatch = searchLen <= 2 ? 0 : 0.3;
        return results
            .filter(r => r.match >= minMatch)
            .sort((a, b) => {
                if (b.score !== a.score)
                    return b.score - a.score;
                if (b.match !== a.match)
                    return b.match - a.match;
                return b.usage - a.usage;
            })
            .map(r => r.item);
    }
}