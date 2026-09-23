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

    required property int displayType
    required property bool showWindows
    required property var iconRules
    property string activeLabel
    property string occupiedLabel
    property string label

    // Chain from the bar (popout wiring lives in Workspaces/Bar); kept for
    // hook parity with the previous delegate.
    property var bar

    // Bar-level hover preview looks up delegates via this flag.
    readonly property bool isWorkspace: true

    // Local Hypr service has no toplevelsForWs/isToplevelIgnored helpers, so
    // resolve occupancy here with the same semantics (unmapped or
    // tag-ignored toplevels do not count). Falls back to any mapped
    // toplevel when the filter helper is absent.
    readonly property list<HyprlandToplevel> toplevels: {
        const ignored = GlobalConfig.bar.workspaces.ignoredTags ?? [];
        if (typeof Hypr.toplevelsForWs === "function")
            return Hypr.toplevelsForWs(ws, ignored);
        const filter = typeof Hypr.isToplevelIgnored === "function" ? t => Hypr.isToplevelIgnored(t, ignored) : t => !(t?.lastIpcObject?.mapped ?? false);
        return Hypr.toplevels.values.filter(t => t.workspace && t.workspace.id === ws && !filter(t));
    }
    readonly property bool isOccupied: toplevels.length > 0
    readonly property bool hasWindows: isOccupied && showWindows && Config.bar.workspaces.maxWindowIcons > 0
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
    // overlay layer (Workspaces.qml) above the active disc.
    // (Ported from the pre-rework design; the displayType/shape branch
    // experiment is dropped.)
    readonly property real circleSize: Tokens.sizes.bar.innerWidth - Tokens.padding.extraSmall * 2

    anchors.horizontalCenter: parent?.horizontalCenter
    LazyListView.preferredHeight: LazyListView.removing ? 0 : layout.implicitHeight + (hasWindows ? Tokens.padding.extraSmall : 0)
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
            opacity: root.isOccupied || root.focused ? 1.0 : 0.5

            Behavior on opacity {
                enabled: root.animationsReady
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        Loader {
            id: windows

            asynchronous: true

            Layout.fillWidth: true
            Layout.topMargin: -Tokens.spacing.extraSmall / 2
            Layout.preferredHeight: root.hasWindows && item ? (item as LazyListView).layoutHeight : 0

            visible: active
            active: root.showWindows && Config.bar.workspaces.maxWindowIcons > 0

            sourceComponent: LazyListView {
                spacing: 0
                implicitHeight: contentHeight
                removeDuration: Tokens.anim.durations.expressiveDefaultEffects

                model: ScriptModel {
                    values: {
                        const windows = root.toplevels;
                        const maxIcons = Config.bar.workspaces.maxWindowIcons;
                        return maxIcons > 0 ? windows.slice(0, maxIcons) : windows;
                    }
                }

                delegate: Item {
                    id: win

                    required property var modelData
                    required property int index // Needed, LazyListView will fail to set it if it doesn't exist

                    // Real app icon when resolvable, monochrome category glyph
                    // otherwise (same DesktopEntries lookup as Icons service).
                    readonly property var appEntry: DesktopEntries.heuristicLookup(modelData.lastIpcObject.class)
                    readonly property url appIconSource: appEntry?.icon ? Quickshell.iconPath(appEntry.icon) : ""

                    implicitWidth: fallback.implicitWidth
                    implicitHeight: fallback.implicitHeight

                    CachingIconImage {
                        anchors.fill: parent
                        source: win.appIconSource
                        visible: win.appIconSource != ""
                    }

                    MaterialIcon {
                        id: fallback

                        anchors.centerIn: parent
                        grade: 0
                        horizontalAlignment: Text.AlignHCenter
                        text: Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "terminal")
                        color: root.onOtherMonitor ? root.offMonitorColour : Colours.palette.m3onSurfaceVariant
                        visible: win.appIconSource == ""
                    }

                    opacity: LazyListView.adding || LazyListView.removing ? 0 : 1

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }

                    Behavior on y {
                        Anim {}
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
