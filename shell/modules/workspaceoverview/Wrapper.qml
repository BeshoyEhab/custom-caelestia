pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property DrawerVisibilities visibilities

    readonly property bool shouldBeActive: visibilities.workspaceOverview && Config.bar.workspaces.overviewEnabled
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(QsWindow.window?.screen ?? null)
    readonly property int activeWsId: monitor?.activeWorkspace?.id ?? 1
    readonly property int rows: Config.bar.workspaces.overviewRows ?? 2
    readonly property int columns: Config.bar.workspaces.overviewColumns ?? 5
    readonly property real overviewScale: Config.bar.workspaces.overviewScale ?? 0.18

    readonly property real cardPadding: Tokens.padding.largeIncreased
    readonly property real cardSpacing: 10
    readonly property real searchHeight: 46
    readonly property real footerHeight: 30
    readonly property real wsWidth: (QsWindow.window?.width ?? 1920) * overviewScale
    readonly property real wsHeight: (QsWindow.window?.height ?? 1080) * overviewScale
    readonly property real cardWidth: columns * wsWidth + (columns - 1) * cardSpacing + cardPadding * 2
    readonly property real cardHeight: rows * wsHeight + (rows - 1) * cardSpacing + cardPadding * 2 + searchHeight + footerHeight + cardSpacing * 2

    visible: opacity > 0
    opacity: shouldBeActive ? 1 : 0
    anchors.fill: parent

    focus: shouldBeActive

    // The search field owns the keyboard while the overview is open, so typing
    // filters immediately (GNOME/KDE behaviour) and the pager stays mouse-only.
    // Both directions reset the field: the grid must never reopen with the
    // previous session's filter still dimming every window.
    onShouldBeActiveChanged: {
        search.text = "";
        grid.query = "";
        if (root.shouldBeActive)
            Qt.callLater(() => {
                if (root.shouldBeActive)
                    search.forceActiveFocus();
            });
    }

    Connections {
        target: root.visibilities
        function onLauncherChanged() { if (root.visibilities.launcher) root.visibilities.workspaceOverview = false; }
        function onDashboardChanged() { if (root.visibilities.dashboard) root.visibilities.workspaceOverview = false; }
        function onUtilitiesChanged() { if (root.visibilities.utilities) root.visibilities.workspaceOverview = false; }
        function onSidebarChanged() { if (root.visibilities.sidebar) root.visibilities.workspaceOverview = false; }
        function onSessionChanged() { if (root.visibilities.session) root.visibilities.workspaceOverview = false; }
    }

    // Block all mouse events from passing through to windows behind
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        preventStealing: true
        onPressed: mouse => {
            const lp = mapToItem(cardBg, mouse.x, mouse.y);
            if (lp.x < 0 || lp.y < 0 || lp.x > cardBg.width || lp.y > cardBg.height) {
                mouse.accepted = true;
            } else {
                mouse.accepted = false;
            }
        }
        onReleased: mouse => {
            const lp = mapToItem(cardBg, mouse.x, mouse.y);
            if (lp.x < 0 || lp.y < 0 || lp.x > cardBg.width || lp.y > cardBg.height) {
                root.visibilities.workspaceOverview = false;
            }
        }
    }

    // Floating card background
    StyledRect {
        id: cardBg

        anchors.centerIn: parent
        width: root.cardWidth
        height: root.cardHeight
        radius: Tokens.rounding.extraLarge
        color: Colours.layer(Colours.palette.m3surfaceContainer, 3)
        border.width: 1
        border.color: Colours.layer(Colours.palette.m3outline, 0.2)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Colours.palette.m3shadow
            shadowOpacity: 0.4
            shadowBlur: 0.8
        }

        // Search + pager live inside the card, above and below the grid, so
        // the overview reads like one window instead of a floating grid plus
        // captions.
        Item {
            id: cardContent

            anchors.fill: parent
            anchors.margins: root.cardPadding

            StyledRect {
                id: searchBar

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.searchHeight
                radius: Tokens.rounding.medium
                color: Colours.palette.m3surfaceContainerHighest

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.rightMargin: Tokens.padding.small
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "search"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledTextField {
                        id: search

                        Layout.fillWidth: true
                        placeholderText: "Search windows by title or app…"
                        onTextChanged: grid.query = text
                        onAccepted: grid.focusSelected()
                    }

                    IconButton {
                        icon: "backspace"
                        type: IconButton.Text
                        visible: search.text.length > 0
                        onClicked: {
                            search.text = "";
                            search.forceActiveFocus();
                        }
                    }
                }
            }

            OverviewGrid {
                id: grid

                anchors.top: searchBar.bottom
                anchors.topMargin: root.cardSpacing
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.rows * root.wsHeight + (root.rows - 1) * root.cardSpacing
                activeWsId: root.activeWsId
                overviewOpen: root.shouldBeActive
                rows: root.rows
                columns: root.columns
                wsWidth: root.wsWidth
                wsHeight: root.wsHeight
                cardSpacing: root.cardSpacing
                overviewScale: root.overviewScale
                onClose: root.visibilities.workspaceOverview = false
            }

            Item {
                id: footer

                anchors.top: grid.bottom
                anchors.topMargin: root.cardSpacing
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.footerHeight

                RowLayout {
                    anchors.fill: parent
                    spacing: Tokens.spacing.medium

                    StyledText {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: {
                            const d = grid.detail;
                            if (d)
                                return `${d.title || d.winClass} · Workspace ${d.wsId}`;
                            if (grid.query.trim() !== "")
                                return "No matching windows";
                            return "Type to search · ↑↓ select · Enter open · Esc close";
                        }
                        color: grid.detail ? Colours.palette.m3onSurface : Colours.palette.m3outline
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        id: pager

                        Layout.alignment: Qt.AlignVCenter
                        spacing: Tokens.spacing.extraSmall
                        visible: grid.pages > 1

                        IconButton {
                            icon: "chevron_left"
                            type: IconButton.Text
                            Layout.alignment: Qt.AlignVCenter
                            enabled: grid.pageIndex > 0
                            onClicked: grid.changePage(-1)
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignVCenter
                            text: `${grid.groupOffset + 1}–${Math.min(grid.groupOffset + grid.workspacesShown, grid.maxWorkspaceId)}`
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                        }

                        IconButton {
                            icon: "chevron_right"
                            type: IconButton.Text
                            Layout.alignment: Qt.AlignVCenter
                            enabled: grid.pageIndex < grid.pages - 1
                            onClicked: grid.changePage(1)
                        }
                    }
                }
            }
        }
    }

    // The single-line search field does not handle these, so they bubble up:
    // arrows walk the matching windows, Enter opens the selected one, Esc
    // clears the query before closing the overview.
    Keys.onUpPressed: grid.selectNext(-1)
    Keys.onDownPressed: grid.selectNext(1)
    Keys.onReturnPressed: grid.focusSelected()
    Keys.onEscapePressed: {
        if (search.text.length > 0) {
            search.text = "";
            search.forceActiveFocus();
        } else {
            root.visibilities.workspaceOverview = false;
        }
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}
