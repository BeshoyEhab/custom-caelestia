pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

VerticalFadeFlickable {
    id: root

    required property NexusState nState

    // Search filter (int model + index lookup: Repeater with a JS-array
    // model does not render delegates in this build; and every read of a
    // list<var> rewraps its elements, so reference identity never survives
    // across reads — carry the registry index explicitly instead of indexOf).
    readonly property var filteredPages: {
        const q = root.nState.searchText.trim().toLowerCase();
        const all = PageRegistry.pages;
        const out = [];
        for (let i = 0; i < all.length; i++) {
            const p = all[i];
            if (!q || `${p.label ?? ""} ${p.description ?? ""} ${p.keywords ?? ""}`.toLowerCase().includes(q))
                out.push({
                    page: p,
                    idx: i
                });
        }
        return out;
    }

    readonly property bool showingResults: root.nState.searchText.trim().length > 0

    // Deep-search results: SearchIndex.query returns RAW entries
    // {item,labelFn,subFn,page,subs} — materialize the label strings here,
    // rank label-matches before sub-matches (stable), and number each row's
    // occurrence among same-(page,subs,label) matches so a click can jump
    // to the exact duplicate via gotoRow.
    // Int-model + index lookup (see filteredPages above): the Repeater uses
    // searchResults.length as its model and reads searchResults[index] per
    // delegate — never model:<js-array>.
    readonly property var searchResults: {
        const q = root.nState.searchText.trim().toLowerCase();
        const raw = SearchIndex.query(root.nState.searchText);
        const mat = [];
        for (let i = 0; i < raw.length; i++) {
            const e = raw[i];
            const label = String(e.labelFn ? e.labelFn() : "");
            const sub = String(e.subFn ? e.subFn() : "");
            mat.push({
                page: e.page,
                subs: e.subs,
                label: label,
                sub: sub,
                labelHit: label.toLowerCase().includes(q)
            });
        }
        // Stable rank: label hits first, sub-only hits after.
        const ranked = mat.filter(r => r.labelHit).concat(mat.filter(r => !r.labelHit));
        const sameKey = (a, b) => {
            if (a.page !== b.page || a.label !== b.label)
                return false;
            const sa = a.subs ?? [];
            const sb = b.subs ?? [];
            if (sa.length !== sb.length)
                return false;
            for (let k = 0; k < sa.length; k++)
                if (sa[k] !== sb[k])
                    return false;
            return true;
        };
        const out = [];
        for (let i = 0; i < ranked.length; i++) {
            const r = ranked[i];
            let n = 0;
            for (let j = 0; j < i; j++)
                if (sameKey(ranked[j], r))
                    n++;
            out.push({
                page: r.page,
                subs: r.subs,
                label: r.label,
                sub: r.sub,
                occurrence: n
            });
        }
        return out;
    }

    topMargin: Tokens.padding.large
    bottomMargin: Tokens.padding.large
    contentHeight: content.implicitHeight

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.extraSmall

        Repeater {
            id: list

            model: root.showingResults ? root.searchResults.length : root.filteredPages.length

            StyledRect {
                id: item

                required property int index

                // Results branch (search non-empty): materialized row match.
                // Pages branch (empty query): identical reads to before.
                readonly property var result: root.showingResults ? root.searchResults[index] : null
                readonly property string resultPageLabel: result == null ? "" : (PageRegistry.pages[result.page]?.label ?? "")
                readonly property string resultIcon: result == null ? "" : (PageRegistry.pages[result.page]?.icon ?? "")
                readonly property bool resultNoFill: result != null && PageRegistry.pages[result.page]?.noFill === true
                readonly property string resultSub: result == null ? "" : (result.sub !== "" ? `${resultPageLabel} › ${result.sub}` : resultPageLabel)

                readonly property var modelData: root.filteredPages[index]?.page
                // Filtered position differs from registry position: the entry
                // carries the real index (indexOf is unusable — list<var>
                // reads rewrap elements, so identity never matches).
                // During filter transitions a delegate can outlive its row
                // (entry undefined, pageIdx -1): every access below tolerates
                // that.
                readonly property int pageIdx: root.filteredPages[index]?.idx ?? -1

                readonly property bool isCurrentPage: root.showingResults ? false : pageIdx === root.nState.currentPageIdx
                // Results are one flat group (first/last rounding); pages
                // branch keeps the per-category grouping exactly as before.
                readonly property bool isCategoryStart: root.showingResults ? index === 0 : (index === 0 || root.filteredPages[index - 1]?.page.category !== modelData?.category)
                readonly property bool isCategoryEnd: root.showingResults ? index === root.searchResults.length - 1 : (index === root.filteredPages.length - 1 || root.filteredPages[index + 1]?.page.category !== modelData?.category)

                Layout.fillWidth: true
                Layout.topMargin: index !== 0 && isCategoryStart ? Tokens.spacing.medium : 0
                implicitHeight: {
                    const h = layout.implicitHeight + layout.anchors.margins * 2;
                    return h % 2 === 0 ? h : h + 1;
                }

                color: isCurrentPage ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

                topLeftRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : isCategoryStart ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
                topRightRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : isCategoryStart ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
                bottomLeftRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : isCategoryEnd ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
                bottomRightRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : isCategoryEnd ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall

                RadiusBehavior on topLeftRadius {}
                RadiusBehavior on topRightRadius {}
                RadiusBehavior on bottomLeftRadius {}
                RadiusBehavior on bottomRightRadius {}

                StateLayer {
                    id: stateLayer

                    anchors.fill: parent
                    topLeftRadius: parent.topLeftRadius
                    topRightRadius: parent.topRightRadius
                    bottomLeftRadius: parent.bottomLeftRadius
                    bottomRightRadius: parent.bottomRightRadius

                    onClicked: {
                        if (root.showingResults) {
                            // Jump to the exact row; keep the search text so
                            // back navigation returns to this results list.
                            const r = item.result;
                            if (r != null)
                                root.nState.gotoRow({
                                    page: r.page,
                                    subs: r.subs,
                                    label: r.label,
                                    occurrence: r.occurrence
                                });
                        } else if (item.pageIdx >= 0) {
                            // Never write a stale -1 (transient delegate): it would
                            // stick the content on the under-construction fallback.
                            root.nState.currentPageIdx = item.pageIdx;
                        }
                    }
                }

                RowLayout {
                    id: layout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.medium

                    StyledRect {
                        Layout.fillHeight: true
                        Layout.topMargin: -1
                        Layout.bottomMargin: -1
                        implicitWidth: height

                        radius: Tokens.rounding.full
                        color: item.isCurrentPage ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer

                        MaterialIcon {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 1

                            text: root.showingResults ? item.resultIcon : (item.modelData?.icon ?? "")
                            color: item.isCurrentPage ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                            fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                            grade: 25
                            fill: (root.showingResults ? item.resultNoFill : item.modelData?.noFill) ? 0 : 1
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: root.showingResults ? (item.result?.label ?? "") : (item.modelData?.label ?? "")
                            font: Tokens.font.body.medium
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.showingResults ? item.resultSub : (item.modelData?.description ?? "")
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    component RadiusBehavior: Behavior {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}
