import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import M3Shapes
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
    readonly property list<int> focusedShapeList: [MaterialShape.Slanted, MaterialShape.Oval, MaterialShape.Pill, MaterialShape.Triangle, MaterialShape.Arrow, MaterialShape.Diamond, MaterialShape.Pentagon, MaterialShape.Gem, MaterialShape.VerySunny, MaterialShape.Sunny, MaterialShape.Cookie4Sided, MaterialShape.Cookie6Sided, MaterialShape.Cookie7Sided, MaterialShape.Cookie9Sided, MaterialShape.Cookie12Sided, MaterialShape.Clover4Leaf, MaterialShape.SoftBurst, MaterialShape.Ghostish]

    property color offMonitorColour: Colours.palette.m3outlineVariant
    readonly property bool onOtherMonitor: {
        if (Config.bar.workspaces.perMonitor ?? true)
            return false;
        const mon = Hypr.workspaces.values.find(w => w.id === ws)?.monitor;
        return !!(mon && mon !== monitor);
    }
    readonly property color fgColour: {
        if (onOtherMonitor)
            return offMonitorColour;
        if (focused || isOccupied || Config.bar.workspaces.occupiedBg)
            return Colours.palette.m3onSurface;
        return Colours.layer(Colours.palette.m3outlineVariant, 2);
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

    function updateShape(): void {
        const shape = indicator.item as MaterialShape;
        if (!shape)
            return;

        if (focused)
            shape.shape = focusedShapeList[Math.floor(Math.random() * focusedShapeList.length)];
        else
            shape.shape = Qt.binding(() => isOccupied ? MaterialShape.Square : MaterialShape.Circle);
    }

    anchors.horizontalCenter: parent?.horizontalCenter
    LazyListView.preferredHeight: LazyListView.removing ? 0 : layout.implicitHeight + (hasWindows ? Tokens.padding.extraSmall : 0)
    LazyListView.visibleHeight: LazyListView.preferredHeight

    opacity: LazyListView.removing || LazyListView.adding ? 0 : 1

    onFocusedChanged: updateShape()
    Component.onCompleted: updateShape()

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

    Component {
        id: shapeComponent

        MaterialShape {
            implicitSize: Tokens.sizes.bar.innerWidth - Tokens.padding.small

            color: root.fgColour
            scale: root.focused ? 2 / 3 : root.isOccupied ? 1 / 3 : 1 / 4

            animationEasing: Tokens.anim.expressiveDefaultSpatial
            animationDuration: Tokens.anim.durations.expressiveDefaultSpatial * Tokens.anim.durations.scale

            Behavior on color {
                CAnim {}
            }

            Behavior on scale {
                Anim {}
            }
        }
    }

    Component {
        id: textComponent

        StyledText {
            animate: true
            text: {
                if (root.focused) {
                    const label = root.activeLabel;
                    if (label)
                        return label;
                }

                if (root.focused || root.isOccupied) {
                    const label = root.occupiedLabel;
                    if (label)
                        return label;
                }

                const label = root.label;
                if (label)
                    return label;

                const ws = Hypr.workspaces.values.find(w => w.id === root.ws);
                const wsName = !ws || ws.name == root.ws ? root.ws : trimName(ws.name)[0];

                // The local schema stores capitalisation as a string while
                // upstream compares the BarWorkspaceCapitalisation enum;
                // accept both so JSON string values keep working.
                const capitalisation = Config.bar.workspaces.capitalisation;
                if (capitalisation === BarWorkspaceCapitalisation.Upper || String(capitalisation).toLowerCase() === "upper")
                    return String(wsName).toUpperCase();
                else if (capitalisation === BarWorkspaceCapitalisation.Lower || String(capitalisation).toLowerCase() === "lower")
                    return String(wsName).toLowerCase();
                return wsName;
            }
            color: root.fgColour
            verticalAlignment: Qt.AlignVCenter
            font.family: Tokens.font.workspaces
        }
    }

    Component {
        id: iconComponent

        MaterialIcon {
            fill: 1
            grade: 25
            text: iconCacher.icon
            color: root.fgColour
            verticalAlignment: Qt.AlignVCenter

            WsIconCacher {
                id: iconCacher
            }
        }
    }

    Component {
        id: iconLoaderComponent

        Loader {
            sourceComponent: loaderIconCacher.icon ? iconComponent : textComponent

            WsIconCacher {
                id: loaderIconCacher
            }
        }
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: 0

        Loader {
            id: indicator

            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            Layout.preferredHeight: Tokens.sizes.bar.innerWidth - Tokens.padding.small
            sourceComponent: {
                // Show app icon path only when enabled; otherwise shapes.
                if (root.displayType === BarWorkspaceDisplay.Icons && Config.bar.workspaces.showAppIcon)
                    return iconLoaderComponent;
                if (root.displayType === BarWorkspaceDisplay.Text)
                    return textComponent;
                return shapeComponent;
            }

            onItemChanged: root.updateShape()
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

    component WsIconCacher: QtObject {
        id: cacher

        property string name
        // Local Icons service has no matchIconRuleList; matchIconConfig is
        // the same single-rule matcher, so loop here with identical outcome.
        readonly property string icon: {
            if (!name)
                return "";
            const clean = root.trimName(name);
            const rules = root.iconRules;
            const list = rules?.values ?? rules ?? [];
            if (typeof list !== "object" || typeof list[Symbol.iterator] !== "function")
                return "";
            for (const rule of list)
                if (rule && Icons.matchIconConfig(clean, rule))
                    return rule.icon;
            return "";
        }
        readonly property HyprlandWorkspace wsObj: Hypr.workspaces.values.find(w => w.id === root.ws) ?? null

        readonly property Connections conn: Connections {
            function onNameChanged(): void {
                cacher.updateName();
            }

            target: cacher.wsObj
        }

        function updateName(): void {
            if (wsObj)
                name = wsObj.name;
        }

        onWsObjChanged: updateName()
        Component.onCompleted: updateName()
    }
}
