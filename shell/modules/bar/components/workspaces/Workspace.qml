import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    required property int modelData
    required property int index
    required property int activeWsId
    required property int ws
    required property HyprlandMonitor monitor

    required property bool showWindows
    // Mirror of the overlay inputs (see WorkspaceContent): needed so the
    // strip can hide whatever icon the circle already shows.
    property int displayType: BarWorkspaceDisplay.Text
    property bool showAppIcon: true

    // Chain from the bar (popout wiring lives in Workspaces/Bar); kept for
    // hook parity with the previous delegate.
    property var bar

    // Bar-level hover preview looks up delegates via this flag.
    readonly property bool isWorkspace: true

    // Local Hypr service has no toplevelsForWs/isToplevelIgnored helpers, so
    // resolve occupancy here with the same semantics (unmapped or
    // tag-ignored toplevels do not count). Falls back to any mapped
    // toplevel when the filter helper is absent. Special-workspace windows
    // are excluded by name: the backend sometimes reports them under a
    // normal workspace id, which leaked their icons onto normal circles.
    readonly property list<HyprlandToplevel> toplevels: {
        const ignored = GlobalConfig.bar.workspaces.ignoredTags ?? [];
        if (typeof Hypr.toplevelsForWs === "function")
            return Hypr.toplevelsForWs(ws, ignored);
        const filter = typeof Hypr.isToplevelIgnored === "function" ? t => Hypr.isToplevelIgnored(t, ignored) : t => !(t?.lastIpcObject?.mapped ?? false);
        return Hypr.toplevels.values.filter(t => t.workspace && Hypr.wsKeyForToplevel(t) === ws && !filter(t));
    }
    readonly property bool isOccupied: toplevels.length > 0
    // Window strip takes space only when there are windows to show, so
    // empty workspaces stay compact. The content overlay tracks live
    // delegate positions (like the active disc), so mixed row heights
    // stay aligned.
    readonly property bool stripActive: showWindows && Config.bar.workspaces.maxWindowIcons > 0
    readonly property bool stripVisible: root.stripActive && root.displayedWindows.length > 0
    // Address of the exact window the circle represents (same two-tier
    // source as the icon map: last-focused window, else first window).
    // That window is hidden from the strip so each window shows once,
    // while same-class siblings still appear.
    readonly property string circleAddr: {
        if (!Hypr.circleShowsIcon(root.displayType, root.showAppIcon, root.focused))
            return "";
        const la = Hypr.lastActivePerWorkspace[ws];
        if (la && Hypr.wsKeyForToplevel(la) === ws)
            return la.lastIpcObject?.address ?? "";
        const all = Hypr.toplevels.values ?? [];
        for (let i = 0; i < all.length; i++) {
            if (Hypr.wsKeyForToplevel(all[i]) === ws)
                return all[i].lastIpcObject?.address ?? "";
        }
        return "";
    }
    // Window strip: one full workspace-sized circle per window in a
    // single centered column with airy gaps — a beaded capsule under the
    // workspace circle. Rows grow with the window count (capped by Max
    // window icons); empty ones stay compact since the strip takes no
    // space then.
    // +8px tuck: the wash slides under the circle pill to hide the seam,
    // reading as one connected unit; icons start below the tuck.
    readonly property real windowIconSize: 14
    readonly property int windowStripCols: 2
    readonly property int windowStripRows: Math.max(1, Math.ceil(root.displayedWindows.length / windowStripCols))
    readonly property real windowStripHeight: root.stripVisible ? (windowStripRows * (windowIconSize + 1)) : 0
    readonly property var displayedWindows: {
        const maxIcons = Config.bar.workspaces.maxWindowIcons;
        if (!(maxIcons > 0))
            return [];
        let wins = toplevels.slice();
        if (root.circleAddr !== "") {
            const addr = root.circleAddr;
            wins = wins.filter(w => w.lastIpcObject?.address !== addr);
        }
        return wins.slice(0, maxIcons);
    }
    readonly property bool focused: activeWsId === ws

    property color offMonitorColour: Colours.palette.m3outlineVariant
    readonly property bool onOtherMonitor: {
        const mon = Hypr.workspaces.values.find(w => w.id === ws)?.monitor;
        return !!(mon && mon !== monitor);
    }

    // Instant on fresh Bar load (hover-open): suppress size/opacity replays.
    // Enabled shortly after load so workspace switches animate normally.
    property bool animationsReady: false

    Timer {
        interval: 350
        running: true
        repeat: false
        onTriggered: root.animationsReady = true
    }

    // Classic indicator: tinted circle. Number/icon content lives in the
    // shared WorkspaceContent overlay above the active disc.
    readonly property real circleSize: Tokens.sizes.bar.innerWidth - Tokens.padding.extraSmall * 2

    anchors.horizontalCenter: parent?.horizontalCenter
    LazyListView.preferredHeight: LazyListView.removing ? 0 : layout.implicitHeight
    LazyListView.visibleHeight: LazyListView.preferredHeight

    opacity: LazyListView.removing || LazyListView.adding ? 0 : 1

    Behavior on LazyListView.visibleHeight {
        enabled: root.animationsReady
        Anim {}
    }

    Behavior on y {
        enabled: root.LazyListView.ready

        Anim {}
    }

    Behavior on opacity {
        enabled: root.animationsReady
        Anim {
            type: Anim.DefaultEffects
        }
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: 0

        // Classic circle background for every workspace. The number/icon
        // content lives in the overlay layer (Workspaces.qml) above the
        // active disc; this rect is background only.
        Rectangle {
            id: circleBg

            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            Layout.preferredWidth: root.circleSize
            Layout.preferredHeight: root.circleSize
            radius: width / 2

            color: root.isOccupied ? Qt.rgba(
                (Colours.palette.m3primary.r + Colours.tPalette.m3surfaceContainer.r) / 2,
                (Colours.palette.m3primary.g + Colours.tPalette.m3surfaceContainer.g) / 2,
                (Colours.palette.m3primary.b + Colours.tPalette.m3surfaceContainer.b) / 2,
                1
            ) : Colours.palette.m3surfaceContainerHighest
            // Transparent when focused: the active pill lives behind the
            // delegates and shows through here, so one highlight contains
            // the circle and its window apps while icons stay visible.
            opacity: root.focused ? 0 : (root.isOccupied ? 1.0 : 0.5)

            Behavior on opacity {
                enabled: root.animationsReady
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        // Bare icons in a centered two-column flow with no background of
        // their own: they sit directly on the pill. Grows with the window
        // count; empty workspaces take no space.
        Item {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraSmall / 2
            Layout.preferredHeight: root.stripVisible ? root.windowStripHeight : 0
            visible: root.stripVisible
            clip: true

            Flow {
                // Fixed two-column width: deterministic wrap. Deriving the
                // width from childrenRect feeds back into the wrap and
                // collapses to zero (all icons stacked) under async
                // incubation, which is exactly how the special strip loads.
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.windowIconSize * root.windowStripCols + (root.windowStripCols - 1)
                spacing: 1

                Repeater {
                    model: root.displayedWindows

                    Item {
                        id: win

                        required property var modelData
                        required property int index // Needed, Repeater will fail to set it if it doesn't exist

                        // Real app icon when resolvable, monochrome category glyph
                        // otherwise (same DesktopEntries lookup as Icons service).
                        // Re-resolves on every icon refresh: a one-shot lookup can
                        // stick on empty when evaluated before the entry DB loads.
                        readonly property var appEntry: {
                            Hypr.appIconsVersion;
                            return DesktopEntries.heuristicLookup(modelData.lastIpcObject.class);
                        }
                        readonly property url appIconSource: appEntry?.icon ? Quickshell.iconPath(appEntry.icon) : ""

                        width: root.windowIconSize
                        height: root.windowIconSize

                        // Plain IconImage (same as the overlay): identical
                        // rendering with no async-loader incubation races.
                        // Synchronous: a failed async load would stick on
                        // the fallback with nothing to retry it.
                        IconImage {
                            id: winImage

                            anchors.fill: parent
                            source: win.appIconSource
                            visible: win.appIconSource != "" && winImage.status !== Image.Error
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            grade: 0
                            horizontalAlignment: Text.AlignHCenter
                            text: Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "terminal")
                            color: root.onOtherMonitor ? root.offMonitorColour : Colours.palette.m3onSurfaceVariant
                            visible: win.appIconSource == "" || winImage.status === Image.Error
                            font.pixelSize: root.windowIconSize
                        }

                        opacity: root.animationsReady ? 1 : 0

                        Behavior on opacity {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }
                    }
                }
            }
        }
    }

    // Local trim: the Hypr service has no trimWsName helper (upstream strips
    // the "special:" prefix); identical semantics.
    function trimName(name: string): string {
        if (typeof Hypr.trimWsName === "function")
            return Hypr.trimWsName(name);
        return name.startsWith("special:") ? name.slice("special:".length) : name;
    }
}
