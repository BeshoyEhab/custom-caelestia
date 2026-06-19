import "scripts/fzf.js" as Fzf
import "scripts/fuzzysort.js" as Fuzzy
import "scripts/levendist.js" as Lev
import QtQuick
import Quickshell

Singleton {
    required property list<QtObject> list
    property string key: "name"
    property bool useFuzzy: false
    property var extraOpts: ({})

    // Extra stuff for fuzzy
    property list<string> keys: [key]
    property list<real> weights: [1]

    // Score threshold
    property real scoreThreshold: 0.2

    readonly property var fzf: useFuzzy ? [] : new Fzf.Finder(list, Object.assign({
        selector
    }, extraOpts))
    readonly property list<var> fuzzyPrepped: useFuzzy ? list.map(e => {
        const obj = { _item: e };
        for (const k of keys)
            obj[k] = Fuzzy.prepare(e[k]);
        return obj;
    }) : []

    function transformSearch(search: string): string {
        return search;
    }

    function selector(item: var): string {
        return keys.map(k => item[k]).join(" ");
    }

    // Get frequency score 0-1 (normalized to max frequency in list)
    function getFreqScore(item: var): real {
        let maxFreq = 0;
        for (const entry of list) {
            const freq = entry.frequency || 0;
            if (freq > maxFreq) maxFreq = freq;
        }
        if (maxFreq === 0) return 0;
        return (item.frequency || 0) / maxFreq;
    }

    // Match score: first letter match bonus, substring match bonus, partial penalty
    function getMatchScore(nameLower: string, searchLower: string): real {
        if (!nameLower || !searchLower) return 0;

        let score = 0;

        // First letter match: huge bonus (decisive for 1-2 char queries)
        if (nameLower[0] === searchLower[0]) {
            score += 0.8;
        } else {
            // First letter mismatch: strong penalty
            score -= 0.5;
        }

        // Starts with search: strong bonus
        if (nameLower.startsWith(searchLower)) {
            score += 0.3;
        }
        // Contains search as substring: moderate bonus
        else if (nameLower.includes(searchLower)) {
            score += 0.15;
        }
        // Subsequence match (fuzzy): smaller bonus
        else {
            let si = 0;
            for (let ni = 0; ni < nameLower.length && si < searchLower.length; ni++) {
                if (nameLower[ni] === searchLower[si]) si++;
            }
            // Full subsequence found
            if (si === searchLower.length) {
                score += 0.05;
            } else {
                // Partial match: penalty based on how few chars matched
                score -= 0.15 * (1 - si / searchLower.length);
            }
        }

        return score;
    }

    function query(search: string): list<var> {
        search = transformSearch(search.trim().replace(/\s+/g, " "));
        if (!search)
            return [...list];

        const searchLen = search.length;
        const searchLower = search.toLowerCase();

        // Dynamic weights: 1 char = 60% freq, 2 = 50%, 3 = 40%, 4+ = 30%
        let matchWeight, usageWeight;
        if (searchLen === 1) {
            matchWeight = 0.4;
            usageWeight = 0.6;
        } else if (searchLen === 2) {
            matchWeight = 0.5;
            usageWeight = 0.5;
        } else if (searchLen === 3) {
            matchWeight = 0.6;
            usageWeight = 0.4;
        } else {
            matchWeight = 0.7;
            usageWeight = 0.3;
        }

        // Short queries (≤3): fuzzysort + frequency + first-letter scoring
        if (useFuzzy && searchLen <= 3) {
            const fuzzyResults = Fuzzy.go(search, fuzzyPrepped, Object.assign({
                all: true,
                keys,
                scoreFn: r => weights.reduce((a, w, i) => a + r[i].score * w, 0)
            }, extraOpts));

            const results = fuzzyResults.map(r => {
                const item = r.obj._item;
                const nameLower = (item.name || "").toLowerCase();

                // Fuzzysort match score (normalize to 0-1)
                const fuzzyScore = Math.min(1.0, Math.max(0, (r.score + 100) / 100));

                // First-letter / substring match score
                const letterScore = getMatchScore(nameLower, searchLower);

                // Combined: weighted average of fuzzy + letter score
                const matchScore = (fuzzyScore + letterScore) / 2;

                const usageScore = getFreqScore(item);
                const combinedScore = matchScore * matchWeight + usageScore * usageWeight;
                return { item, combinedScore };
            });

            return results
                .sort((a, b) => b.combinedScore - a.combinedScore)
                .map(r => r.item);
        }

        // Longer queries (>3): levenshtein + frequency
        if (searchLen > 3) {
            const results = list.map(item => ({
                item,
                score: Lev.computeScore((item.name || "").toLowerCase(), searchLower)
            }))
            .filter(r => r.score > scoreThreshold);

            const combined = results.map(r => {
                const usageScore = getFreqScore(r.item);
                const combinedScore = r.score * matchWeight + usageScore * usageWeight;
                return { item: r.item, combinedScore };
            });

            return combined
                .sort((a, b) => b.combinedScore - a.combinedScore)
                .map(r => r.item);
        }

        // FZF mode (default, no fuzzy)
        return fzf.find(search).sort((a, b) => {
            if (a.score === b.score)
                return selector(a.item).trim().length - selector(b.item).trim().length;
            return b.score - a.score;
        }).map(r => r.item);
    }
}
