pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Colours")
    isSubPage: true

    readonly property list<string> schemeNames: [
        "dynamic", "catppuccin", "dracula", "everforest",
        "gruvbox", "nord", "oldworld", "onedark",
        "rosepine", "solarized", "tokyonight", "caelestia"
    ]

    readonly property list<string> schemeLabels: [
        "Dynamic", "Catppuccin", "Dracula", "Everforest",
        "Gruvbox", "Nord", "Old World", "One Dark",
        "Rose Pine", "Solarized", "Tokyo Night", "Caelestia"
    ]

    readonly property list<string> schemeSurfacesDark: [
        "#0c0e12", "#1e1e2e", "#282a36", "#2d353b",
        "#282828", "#2e3440", "#1a1614", "#282c34",
        "#191724", "#002b36", "#1a1b26", "#0c0e12"
    ]

    readonly property list<string> schemeSurfacesLight: [
        "#f2f2f7", "#eff1f5", "#282a36", "#fdf6e3",
        "#fbf1c7", "#2e3440", "#1a1614", "#282c34",
        "#faf4ed", "#fdf6e3", "#e1e2e8", "#0c0e12"
    ]

    readonly property list<string> schemePrimariesDark: [
        "#b4c7ed", "#cba6f7", "#bd93f9", "#a7c080",
        "#d79921", "#88c0d0", "#d0b48c", "#61afef",
        "#c4a7e7", "#268bd2", "#7aa2f7", "#b4c7ed"
    ]

    readonly property list<string> schemePrimariesLight: [
        "#3b5b8c", "#8839ef", "#bd93f9", "#5a8f5c",
        "#b57614", "#88c0d0", "#d0b48c", "#61afef",
        "#9b59b6", "#268bd2", "#4569d4", "#b4c7ed"
    ]

    readonly property list<string> schemeSecondariesDark: [
        "#bdc7dc", "#f5c2e7", "#50fa7b", "#dbbc7f",
        "#b8bb26", "#a3be8c", "#8cb89a", "#98c379",
        "#3182ce", "#2aa198", "#9ece6a", "#bdc7dc"
    ]

    readonly property list<string> schemeSecondariesLight: [
        "#757f9a", "#ea76cb", "#50fa7b", "#8a9b6e",
        "#98971a", "#a3be8c", "#8cb89a", "#98c379",
        "#c678dd", "#2aa198", "#7dcfff", "#bdc7dc"
    ]

    readonly property list<string> schemeTertiariesDark: [
        "#eaddff", "#94e2d5", "#ff79c6", "#e67e80",
        "#d3869b", "#b48ead", "#c4927a", "#c678dd",
        "#eb6f92", "#6c71c4", "#bb9af7", "#eaddff"
    ]

    readonly property list<string> schemeTertiariesLight: [
        "#c4a0e8", "#40a02b", "#ff79c6", "#d3869b",
        "#d3869b", "#b48ead", "#c4927a", "#c678dd",
        "#d7827e", "#6c71c4", "#bb9af7", "#eaddff"
    ]

    readonly property list<string> schemeSurfaces: Colours.light ? schemeSurfacesLight : schemeSurfacesDark
    readonly property list<string> schemePrimaries: Colours.light ? schemePrimariesLight : schemePrimariesDark
    readonly property list<string> schemeSecondaries: Colours.light ? schemeSecondariesLight : schemeSecondariesDark
    readonly property list<string> schemeTertiaries: Colours.light ? schemeTertiariesLight : schemeTertiariesDark

    readonly property list<string> variantOrder: [
        "tonalspot", "vibrant", "expressive", "fidelity",
        "fruitsalad", "monochrome", "neutral", "rainbow", "content"
    ]

    readonly property list<string> flavourOrder: [
        "frappe", "latte", "macchiato", "mocha"
    ]

    property string currentScheme: Colours.scheme || "dynamic"
    property string currentVariant: Colours.variant || "tonalspot"
    property string currentFlavour: Colours.flavour || "mocha"
    property bool isCatppuccin: currentScheme === "catppuccin"

    readonly property string precomputeScript:
        Paths.home + "/.config/quickshell/caelestia/scripts/precompute_variants.py"

    readonly property var variantFallback: [
        { name: "tonalspot", primary: "#b4c7ed", secondary: "#bdc7dc", tertiary: "#eaddff" },
        { name: "vibrant", primary: "#ff6b6b", secondary: "#ffd93d", tertiary: "#6bcb77" },
        { name: "expressive", primary: "#c084fc", secondary: "#f472b6", tertiary: "#fbbf24" },
        { name: "fidelity", primary: "#818cf8", secondary: "#34d399", tertiary: "#fb923c" },
        { name: "fruitsalad", primary: "#4ade80", secondary: "#facc15", tertiary: "#f472b6" },
        { name: "monochrome", primary: "#9ca3af", secondary: "#d1d5db", tertiary: "#6b7280" },
        { name: "neutral", primary: "#a8a29e", secondary: "#d6d3d1", tertiary: "#78716c" },
        { name: "rainbow", primary: "#f43f5e", secondary: "#3b82f6", tertiary: "#22c55e" },
        { name: "content", primary: "#a78bfa", secondary: "#f59e0b", tertiary: "#10b981" }
    ]

    readonly property var flavourFallback: [
        { name: "frappe", surface: "#303446", primary: "#ca9ee6", secondary: "#f5bde6", tertiary: "#a6da95" },
        { name: "latte", surface: "#eff1f5", primary: "#8839ef", secondary: "#ea76cb", tertiary: "#40a02b" },
        { name: "macchiato", surface: "#24273a", primary: "#cba6f7", secondary: "#f5c2e7", tertiary: "#a6da95" },
        { name: "mocha", surface: "#1e1e2e", primary: "#cba6f7", secondary: "#f5c2e7", tertiary: "#94e2d5" }
    ]

    readonly property string activeVariantName: isCatppuccin ? currentFlavour : currentVariant

    property var variantTiles: isCatppuccin ? flavourFallback : variantFallback

    function rebuildVariants() {
        if (isCatppuccin) {
            var fc = Colours.flavourColours;
            if (fc && Object.keys(fc).length > 0) {
                var list = [];
                for (var fi = 0; fi < flavourOrder.length; fi++) {
                    var fn = flavourOrder[fi];
                    var c = fc[fn];
                    if (c)
                        list.push({ name: fn, primary: "#" + (c.primary || "000000"), secondary: "#" + (c.secondary || "000000"), tertiary: "#" + (c.tertiary || "000000"), surface: "#" + (c.surface || "000000") });
                }
                if (list.length > 0) { variantTiles = list; return; }
            }
            variantTiles = flavourFallback;
        } else {
            var vc = Colours.variantColours;
            if (vc && Object.keys(vc).length > 0) {
                var list = [];
                for (var vi = 0; vi < variantOrder.length; vi++) {
                    var vn = variantOrder[vi];
                    var c = vc[vn];
                    if (c)
                        list.push({ name: vn, primary: "#" + (c.primary || "000000"), secondary: "#" + (c.secondary || "000000"), tertiary: "#" + (c.tertiary || "000000"), surface: "#" + (c.surface || "000000") });
                }
                if (list.length > 0) { variantTiles = list; return; }
            }
            variantTiles = variantFallback;
        }
    }

    function hexToLuminance(hex) {
        const s = (typeof hex === "string" ? hex : hex.toString()).replace("#", "");
        if (s.length < 6) return 0;
        const r = parseInt(s.slice(0,2), 16) / 255;
        const g = parseInt(s.slice(2,4), 16) / 255;
        const b = parseInt(s.slice(4,6), 16) / 255;
        return 0.299 * r + 0.587 * g + 0.114 * b;
    }

    function clampLuminance(hex, minLum, maxLum) {
        const s = (typeof hex === "string" ? hex : hex.toString()).replace("#", "");
        if (s.length < 6) return Qt.rgba(0.5, 0.5, 0.5, 1);
        let r = parseInt(s.slice(0,2), 16) / 255;
        let g = parseInt(s.slice(2,4), 16) / 255;
        let b = parseInt(s.slice(4,6), 16) / 255;
        let lum = 0.299 * r + 0.587 * g + 0.114 * b;
        if (lum < minLum) {
            const f = (minLum - lum) / (1 - lum || 0.01);
            r = r + (1 - r) * f;
            g = g + (1 - g) * f;
            b = b + (1 - b) * f;
        } else if (lum > maxLum) {
            const f = maxLum / (lum || 0.01);
            r *= f;
            g *= f;
            b *= f;
        }
        return Qt.rgba(r, g, b, 1);
    }

    function hexToColor(h) {
        const c = h.toString().slice(1);
        return Qt.rgba(
            parseInt(c.slice(0,2), 16) / 255,
            parseInt(c.slice(2,4), 16) / 255,
            parseInt(c.slice(4,6), 16) / 255,
            1
        );
    }

    function variantTileBg(primaryHex) {
        const p = hexToColor(primaryHex);
        const base = Colours.palette.m3surfaceContainerLow;
        const w = Colours.light ? 0.5 : 0.65;
        const color = Qt.rgba(
            base.r * w + p.r * (1 - w),
            base.g * w + p.g * (1 - w),
            base.b * w + p.b * (1 - w),
            1
        );
        if (Colours.light) return clampLuminance(color.toString(), 0.55, 1);
        return clampLuminance(color.toString(), 0, 0.25);
    }

    function textOnSurface(hex) {
        const lum = hexToLuminance(hex);
        return lum > 0.4 ? "#1a1a1a" : "#f0f0f0";
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.largeIncreased - ((parent as ColumnLayout).spacing ?? 0)
            Layout.bottomMargin: Tokens.spacing.extraSmall
            Layout.leftMargin: Tokens.padding.small
            text: qsTr("Theme")
            color: root.textOnSurface(Colours.palette.m3surface.toString())
            font.pixelSize: Tokens.font.label.medium.pixelSize
            font.weight: Font.Bold
            elide: Text.ElideRight
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Dark mode")
            checked: !Colours.light
            onToggled: Colours.setMode(checked ? "dark" : "light")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.largeIncreased - ((parent as ColumnLayout).spacing ?? 0)
            Layout.bottomMargin: Tokens.spacing.extraSmall
            Layout.leftMargin: Tokens.padding.small
            text: qsTr("Colour scheme")
            color: root.textOnSurface(Colours.palette.m3surface.toString())
            font.pixelSize: Tokens.font.label.medium.pixelSize
            font.weight: Font.Bold
            elide: Text.ElideRight
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: schemeGrid.implicitHeight + schemeGrid.anchors.margins * 2

            GridLayout {
                id: schemeGrid

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                columns: 4
                rowSpacing: Tokens.spacing.small
                columnSpacing: Tokens.spacing.small

                Repeater {
                    model: root.schemeNames.length

                    Item {
                        required property int index

                        Layout.fillWidth: true
                        Layout.preferredHeight: 72

                        readonly property bool isActive: root.schemeNames[index] === root.currentScheme
                        readonly property string surface: root.schemeSurfaces[index]
                        readonly property string primary: root.schemePrimaries[index]
                        readonly property string secondary: root.schemeSecondaries[index]
                        readonly property string tertiary: root.schemeTertiaries[index]
                        readonly property string schemeLabel: root.schemeLabels[index]
                        readonly property string schemeName: root.schemeNames[index]
                        readonly property string textColor: root.textOnSurface(surface)

                        Rectangle {
                            anchors.fill: parent
                            color: surface
                            radius: Tokens.rounding.medium
                            border.color: isActive ? Colours.palette.m3primary : "transparent"
                            border.width: isActive ? 2 : 0
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Tokens.rounding.medium
                            color: textColor
                            opacity: schemeMouse.containsMouse ? 0.08 : 0
                            Behavior on opacity { Anim {} }
                        }

                        MouseArea {
                            id: schemeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Colours.scheme = schemeName;
                                Quickshell.execDetached(["sh", "-c", `caelestia scheme set -n ${schemeName} --notify && python3 '${root.precomputeScript}'`]);
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Row {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 4

                                Rectangle {
                                    width: 16; height: 16; radius: 8
                                    color: primary
                                }
                                Rectangle {
                                    width: 16; height: 16; radius: 8
                                    color: secondary
                                }
                                Rectangle {
                                    width: 16; height: 16; radius: 8
                                    color: tertiary
                                }
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: schemeLabel
                                color: textColor
                                font.pixelSize: Tokens.font.label.small.pixelSize
                                font.weight: isActive ? Font.Bold : Font.Normal
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.largeIncreased - ((parent as ColumnLayout).spacing ?? 0)
            Layout.bottomMargin: Tokens.spacing.extraSmall
            Layout.leftMargin: Tokens.padding.small
            text: qsTr("Variant")
            color: root.textOnSurface(Colours.palette.m3surface.toString())
            font.pixelSize: Tokens.font.label.medium.pixelSize
            font.weight: Font.Bold
            elide: Text.ElideRight
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: variantGrid.implicitHeight + variantGrid.anchors.margins * 2

            GridLayout {
                id: variantGrid

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                columns: 4
                rowSpacing: Tokens.spacing.small
                columnSpacing: Tokens.spacing.small

                Repeater {
                    model: root.variantTiles

                    Item {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.preferredHeight: 72

                        readonly property string vName: modelData.name
                        readonly property string vLabel: vName.charAt(0).toUpperCase() + vName.slice(1)
                        readonly property string vPrimary: modelData.primary
                        readonly property string vSecondary: modelData.secondary
                        readonly property string vTertiary: modelData.tertiary
                        readonly property bool isActive: vName === root.activeVariantName
                        readonly property string vSurface: modelData.surface
                            ? modelData.surface
                            : root.variantTileBg(isActive ? Colours.palette.m3primary.toString() : vPrimary).toString()
                        readonly property color borderColor: isActive ? Colours.palette.m3primary : "transparent"
                        readonly property string textColor: root.textOnSurface(vSurface)

                        Rectangle {
                            anchors.fill: parent
                            color: vSurface
                            radius: Tokens.rounding.medium
                            border.color: borderColor
                            border.width: isActive ? 2 : 0
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Tokens.rounding.medium
                            color: textColor
                            opacity: variantMouse.containsMouse ? 0.08 : 0
                            Behavior on opacity { Anim {} }
                        }

                        MouseArea {
                            id: variantMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.isCatppuccin) {
                                    Colours.flavour = vName;
                                    Quickshell.execDetached(["sh", "-c", `caelestia scheme set -f ${vName} --notify && python3 '${root.precomputeScript}'`]);
                                } else {
                                    Colours.variant = vName;
                                    Quickshell.execDetached(["sh", "-c", `caelestia scheme set -v ${vName} --notify && python3 '${root.precomputeScript}'`]);
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Row {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 4

                                Rectangle {
                                    width: 16; height: 16; radius: 8
                                    color: vPrimary
                                }
                                Rectangle {
                                    width: 16; height: 16; radius: 8
                                    color: vSecondary
                                }
                                Rectangle {
                                    width: 16; height: 16; radius: 8
                                    color: vTertiary
                                }
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: vLabel
                                color: textColor
                                font.pixelSize: Tokens.font.label.small.pixelSize
                                font.weight: isActive ? Font.Bold : Font.Normal
                            }
                        }
                    }
                }
            }
        }

        Component.onCompleted: {
            root.rebuildVariants();
            Quickshell.execDetached(["sh", "-c", `python3 '${root.precomputeScript}'`]);
        }

        Connections {
            target: Colours
            function onVariantColoursChanged() { root.rebuildVariants(); }
            function onFlavourColoursChanged() { root.rebuildVariants(); }
        }
    }
}
