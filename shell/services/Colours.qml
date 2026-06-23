pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.services
import qs.utils

Singleton {
    id: root

    property bool showPreview
    property string scheme
    property string flavour
    property string variant
    readonly property bool light: showPreview ? previewLight : currentLight
    property bool currentLight
    property bool previewLight
    readonly property M3Palette palette: showPreview ? preview : current
    readonly property M3TPalette tPalette: M3TPalette {}
    readonly property M3Palette current: M3Palette {}
    readonly property M3Palette preview: M3Palette {}
    readonly property Transparency transparency: Transparency {}
    readonly property alias wallLuminance: analyser.luminance

    property bool cooldownPending
    property real lastBaseTransparency

    function getLuminance(c: color): real {
        if (c.r == 0 && c.g == 0 && c.b == 0)
            return 0;
        return Math.sqrt(0.299 * (c.r ** 2) + 0.587 * (c.g ** 2) + 0.114 * (c.b ** 2));
    }

    function alterColour(c: color, a: real, layer: int): color {
        const luminance = getLuminance(c);

        const offset = (!light || layer == 1 ? 1 : -layer / 2) * (light ? 0.2 : 0.3) * (1 - transparency.base) * (1 + wallLuminance * (light ? (layer == 1 ? 3 : 1) : 2.5));
        const scale = (luminance + offset) / luminance;
        const r = Math.max(0, Math.min(1, c.r * scale));
        const g = Math.max(0, Math.min(1, c.g * scale));
        const b = Math.max(0, Math.min(1, c.b * scale));

        return Qt.rgba(r, g, b, a);
    }

    function layer(c: color, layer: var): color {
        if (!transparency.enabled)
            return c;

        return layer === 0 ? Qt.alpha(c, transparency.base) : alterColour(c, transparency.layers, layer ?? 1);
    }

    function on(c: color): color {
        if (c.hslLightness < 0.5)
            return Qt.hsla(c.hslHue, c.hslSaturation, 0.9, 1);
        return Qt.hsla(c.hslHue, c.hslSaturation, 0.1, 1);
    }

    function load(data: string, isPreview: bool): void {
        const colours = isPreview ? preview : current;
        const scheme = JSON.parse(data);

        if (!isPreview) {
            root.scheme = scheme.name;
            flavour = scheme.flavour;
            root.variant = scheme.variant || "tonalspot";
            currentLight = scheme.mode === "light";
        } else {
            previewLight = scheme.mode === "light";
        }

        for (const [name, colour] of Object.entries(scheme.colours)) {
            const propName = name.startsWith("term") ? name : `m3${name}`;
            if (propName in colours)
                colours[propName] = `#${colour}`;
        }

        if (!isPreview)
            root._recomputeTPalette();
    }

    function setMode(mode: string): void {
        Quickshell.execDetached(["caelestia", "scheme", "set", "--notify", "-m", mode]);
    }

    function reloadHyprRules(): void {
        if (Hypr.usingLua) {
            const rule = `eval hl.layer_rule({ match = { namespace = "caelestia-drawers" }, %1 })`;
            Hypr.extras.batchMessage([rule.arg(`blur = ${transparency.enabled}`), rule.arg(`ignore_alpha = ${transparency.base - 0.03}`)]);
        } else {
            const str = "keyword layerrule %1 %2, match:namespace caelestia-drawers";
            Hypr.extras.batchMessage([str.arg("blur").arg(transparency.enabled ? 1 : 0), str.arg("ignore_alpha").arg(transparency.base - 0.03)]);
        }
    }

    function requestReloadHyprRules(): void {
        if (cooldownTimer.running) {
            root.cooldownPending = true;
        } else {
            root.reloadHyprRules();
            cooldownTimer.restart();
        }
    }

    function _recomputeTPalette(): void {
        const p = root.tPalette;
        const pal = root.palette;
        p.m3primary_paletteKeyColor = root.layer(pal.m3primary_paletteKeyColor);
        p.m3secondary_paletteKeyColor = root.layer(pal.m3secondary_paletteKeyColor);
        p.m3tertiary_paletteKeyColor = root.layer(pal.m3tertiary_paletteKeyColor);
        p.m3neutral_paletteKeyColor = root.layer(pal.m3neutral_paletteKeyColor);
        p.m3neutral_variant_paletteKeyColor = root.layer(pal.m3neutral_variant_paletteKeyColor);
        p.m3background = root.layer(pal.m3background, 0);
        p.m3onBackground = root.layer(pal.m3onBackground);
        p.m3surface = root.layer(pal.m3surface, 0);
        p.m3surfaceDim = root.layer(pal.m3surfaceDim, 0);
        p.m3surfaceBright = root.layer(pal.m3surfaceBright, 0);
        p.m3surfaceContainerLowest = root.layer(pal.m3surfaceContainerLowest);
        p.m3surfaceContainerLow = root.layer(pal.m3surfaceContainerLow);
        p.m3surfaceContainer = root.layer(pal.m3surfaceContainer);
        p.m3surfaceContainerHigh = root.layer(pal.m3surfaceContainerHigh);
        p.m3surfaceContainerHighest = root.layer(pal.m3surfaceContainerHighest);
        p.m3onSurface = root.layer(pal.m3onSurface);
        p.m3surfaceVariant = root.layer(pal.m3surfaceVariant, 0);
        p.m3onSurfaceVariant = root.layer(pal.m3onSurfaceVariant);
        p.m3inverseSurface = root.layer(pal.m3inverseSurface, 0);
        p.m3inverseOnSurface = root.layer(pal.m3inverseOnSurface);
        p.m3outline = root.layer(pal.m3outline);
        p.m3outlineVariant = root.layer(pal.m3outlineVariant);
        p.m3shadow = root.layer(pal.m3shadow);
        p.m3scrim = root.layer(pal.m3scrim);
        p.m3surfaceTint = root.layer(pal.m3surfaceTint);
        p.m3primary = root.layer(pal.m3primary);
        p.m3onPrimary = root.layer(pal.m3onPrimary);
        p.m3primaryContainer = root.layer(pal.m3primaryContainer);
        p.m3onPrimaryContainer = root.layer(pal.m3onPrimaryContainer);
        p.m3inversePrimary = root.layer(pal.m3inversePrimary);
        p.m3secondary = root.layer(pal.m3secondary);
        p.m3onSecondary = root.layer(pal.m3onSecondary);
        p.m3secondaryContainer = root.layer(pal.m3secondaryContainer);
        p.m3onSecondaryContainer = root.layer(pal.m3onSecondaryContainer);
        p.m3tertiary = root.layer(pal.m3tertiary);
        p.m3onTertiary = root.layer(pal.m3onTertiary);
        p.m3tertiaryContainer = root.layer(pal.m3tertiaryContainer);
        p.m3onTertiaryContainer = root.layer(pal.m3onTertiaryContainer);
        p.m3error = root.layer(pal.m3error);
        p.m3onError = root.layer(pal.m3onError);
        p.m3errorContainer = root.layer(pal.m3errorContainer);
        p.m3onErrorContainer = root.layer(pal.m3onErrorContainer);
        p.m3success = root.layer(pal.m3success);
        p.m3onSuccess = root.layer(pal.m3onSuccess);
        p.m3successContainer = root.layer(pal.m3successContainer);
        p.m3onSuccessContainer = root.layer(pal.m3onSuccessContainer);
        p.m3primaryFixed = root.layer(pal.m3primaryFixed);
        p.m3primaryFixedDim = root.layer(pal.m3primaryFixedDim);
        p.m3onPrimaryFixed = root.layer(pal.m3onPrimaryFixed);
        p.m3onPrimaryFixedVariant = root.layer(pal.m3onPrimaryFixedVariant);
        p.m3secondaryFixed = root.layer(pal.m3secondaryFixed);
        p.m3secondaryFixedDim = root.layer(pal.m3secondaryFixedDim);
        p.m3onSecondaryFixed = root.layer(pal.m3onSecondaryFixed);
        p.m3onSecondaryFixedVariant = root.layer(pal.m3onSecondaryFixedVariant);
        p.m3tertiaryFixed = root.layer(pal.m3tertiaryFixed);
        p.m3tertiaryFixedDim = root.layer(pal.m3tertiaryFixedDim);
        p.m3onTertiaryFixed = root.layer(pal.m3onTertiaryFixed);
        p.m3onTertiaryFixedVariant = root.layer(pal.m3onTertiaryFixedVariant);
    }

    Component.onCompleted: {
        root.requestReloadHyprRules();
        root._recomputeTPalette();
    }

    Connections {
        function onConfigReloaded(): void {
            root.reloadHyprRules();
        }

        target: Hypr
    }

    Connections {
        function onPaletteChanged(): void {
            root._recomputeTPalette();
        }

        target: root
    }

    Connections {
        function onLightChanged(): void {
            root._recomputeTPalette();
        }

        function onWallLuminanceChanged(): void {
            root._recomputeTPalette();
        }

        target: root
    }

    FileView {
        path: `${Paths.state}/scheme.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.load(text(), false)
    }

    ImageAnalyser {
        id: analyser

        source: Wallpapers.current
    }

    Timer {
        id: cooldownTimer

        interval: 30
        onTriggered: {
            if (root.cooldownPending) {
                root.cooldownPending = false;
                root.reloadHyprRules();
                restart();
            }
        }
    }

    Timer {
        id: cAnimCompleteTimer

        interval: Tokens.anim.durations.expressiveSlowEffects
        onTriggered: root.requestReloadHyprRules()
    }

    component Transparency: QtObject {
        readonly property bool enabled: Tokens.transparency.enabled
        readonly property real base: Math.max(0, Math.min(1, Tokens.transparency.base - (root.light ? 0.1 : 0)))
        readonly property real layers: Tokens.transparency.layers

        onEnabledChanged: {
            if (enabled)
                root.requestReloadHyprRules();
            else
                cAnimCompleteTimer.start();
            root._recomputeTPalette();
        }
        onBaseChanged: {
            if (root.lastBaseTransparency > base)
                root.requestReloadHyprRules();
            else
                cAnimCompleteTimer.start();
            root.lastBaseTransparency = base;
            root._recomputeTPalette();
        }
    }

    component M3TPalette: QtObject {
        property color m3primary_paletteKeyColor: "transparent"
        property color m3secondary_paletteKeyColor: "transparent"
        property color m3tertiary_paletteKeyColor: "transparent"
        property color m3neutral_paletteKeyColor: "transparent"
        property color m3neutral_variant_paletteKeyColor: "transparent"
        property color m3background: "transparent"
        property color m3onBackground: "transparent"
        property color m3surface: "transparent"
        property color m3surfaceDim: "transparent"
        property color m3surfaceBright: "transparent"
        property color m3surfaceContainerLowest: "transparent"
        property color m3surfaceContainerLow: "transparent"
        property color m3surfaceContainer: "transparent"
        property color m3surfaceContainerHigh: "transparent"
        property color m3surfaceContainerHighest: "transparent"
        property color m3onSurface: "transparent"
        property color m3surfaceVariant: "transparent"
        property color m3onSurfaceVariant: "transparent"
        property color m3inverseSurface: "transparent"
        property color m3inverseOnSurface: "transparent"
        property color m3outline: "transparent"
        property color m3outlineVariant: "transparent"
        property color m3shadow: "transparent"
        property color m3scrim: "transparent"
        property color m3surfaceTint: "transparent"
        property color m3primary: "transparent"
        property color m3onPrimary: "transparent"
        property color m3primaryContainer: "transparent"
        property color m3onPrimaryContainer: "transparent"
        property color m3inversePrimary: "transparent"
        property color m3secondary: "transparent"
        property color m3onSecondary: "transparent"
        property color m3secondaryContainer: "transparent"
        property color m3onSecondaryContainer: "transparent"
        property color m3tertiary: "transparent"
        property color m3onTertiary: "transparent"
        property color m3tertiaryContainer: "transparent"
        property color m3onTertiaryContainer: "transparent"
        property color m3error: "transparent"
        property color m3onError: "transparent"
        property color m3errorContainer: "transparent"
        property color m3onErrorContainer: "transparent"
        property color m3success: "transparent"
        property color m3onSuccess: "transparent"
        property color m3successContainer: "transparent"
        property color m3onSuccessContainer: "transparent"
        property color m3primaryFixed: "transparent"
        property color m3primaryFixedDim: "transparent"
        property color m3onPrimaryFixed: "transparent"
        property color m3onPrimaryFixedVariant: "transparent"
        property color m3secondaryFixed: "transparent"
        property color m3secondaryFixedDim: "transparent"
        property color m3onSecondaryFixed: "transparent"
        property color m3onSecondaryFixedVariant: "transparent"
        property color m3tertiaryFixed: "transparent"
        property color m3tertiaryFixedDim: "transparent"
        property color m3onTertiaryFixed: "transparent"
        property color m3onTertiaryFixedVariant: "transparent"
    }

    component M3Palette: QtObject {
        property color m3primary_paletteKeyColor: "#a8627b"
        property color m3secondary_paletteKeyColor: "#8e6f78"
        property color m3tertiary_paletteKeyColor: "#986e4c"
        property color m3neutral_paletteKeyColor: "#807477"
        property color m3neutral_variant_paletteKeyColor: "#837377"
        property color m3background: "#191114"
        property color m3onBackground: "#efdfe2"
        property color m3surface: "#191114"
        property color m3surfaceDim: "#191114"
        property color m3surfaceBright: "#403739"
        property color m3surfaceContainerLowest: "#130c0e"
        property color m3surfaceContainerLow: "#22191c"
        property color m3surfaceContainer: "#261d20"
        property color m3surfaceContainerHigh: "#31282a"
        property color m3surfaceContainerHighest: "#3c3235"
        property color m3onSurface: "#efdfe2"
        property color m3surfaceVariant: "#514347"
        property color m3onSurfaceVariant: "#d5c2c6"
        property color m3inverseSurface: "#efdfe2"
        property color m3inverseOnSurface: "#372e30"
        property color m3outline: "#9e8c91"
        property color m3outlineVariant: "#514347"
        property color m3shadow: "#000000"
        property color m3scrim: "#000000"
        property color m3surfaceTint: "#ffb0ca"
        property color m3primary: "#ffb0ca"
        property color m3onPrimary: "#541d34"
        property color m3primaryContainer: "#6f334a"
        property color m3onPrimaryContainer: "#ffd9e3"
        property color m3inversePrimary: "#8b4a62"
        property color m3secondary: "#e2bdc7"
        property color m3onSecondary: "#422932"
        property color m3secondaryContainer: "#5a3f48"
        property color m3onSecondaryContainer: "#ffd9e3"
        property color m3tertiary: "#f0bc95"
        property color m3onTertiary: "#48290c"
        property color m3tertiaryContainer: "#b58763"
        property color m3onTertiaryContainer: "#000000"
        property color m3error: "#ffb4ab"
        property color m3onError: "#690005"
        property color m3errorContainer: "#93000a"
        property color m3onErrorContainer: "#ffdad6"
        property color m3success: "#B5CCBA"
        property color m3onSuccess: "#213528"
        property color m3successContainer: "#374B3E"
        property color m3onSuccessContainer: "#D1E9D6"
        property color m3primaryFixed: "#ffd9e3"
        property color m3primaryFixedDim: "#ffb0ca"
        property color m3onPrimaryFixed: "#39071f"
        property color m3onPrimaryFixedVariant: "#6f334a"
        property color m3secondaryFixed: "#ffd9e3"
        property color m3secondaryFixedDim: "#e2bdc7"
        property color m3onSecondaryFixed: "#2b151d"
        property color m3onSecondaryFixedVariant: "#5a3f48"
        property color m3tertiaryFixed: "#ffdcc3"
        property color m3tertiaryFixedDim: "#f0bc95"
        property color m3onTertiaryFixed: "#2f1500"
        property color m3onTertiaryFixedVariant: "#623f21"
        property color term0: "#353434"
        property color term1: "#ff4c8a"
        property color term2: "#ffbbb7"
        property color term3: "#ffdedf"
        property color term4: "#b3a2d5"
        property color term5: "#e98fb0"
        property color term6: "#ffba93"
        property color term7: "#eed1d2"
        property color term8: "#b39e9e"
        property color term9: "#ff80a3"
        property color term10: "#ffd3d0"
        property color term11: "#fff1f0"
        property color term12: "#dcbc93"
        property color term13: "#f9a8c2"
        property color term14: "#ffd1c0"
        property color term15: "#ffffff"
    }
}
