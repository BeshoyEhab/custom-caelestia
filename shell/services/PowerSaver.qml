pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Caelestia
import Caelestia.Config
import qs.services

Singleton {
    id: root

    property alias enabled: props.enabled
    property alias autoOnBattery: props.autoOnBattery

    readonly property bool hasBattery: UPower.displayDevice.isLaptopBattery
    readonly property bool onBattery: UPower.onBattery
    readonly property real batteryPct: UPower.displayDevice.percentage

    // Latched so the threshold has 2-point hysteresis (no flapping).
    property bool autoLatched: false

    readonly property bool autoWantsEco: root.hasBattery && props.autoOnBattery && root.autoLatched
    readonly property bool ecoActive: props.enabled || root.autoWantsEco
    readonly property bool videoBlocked: root.ecoActive
    readonly property int intervalStretch: root.ecoActive ? 4 : 1
    readonly property int ecoVisualiserBars: 24

    function evalAuto(): void {
        if (!root.hasBattery || !props.autoOnBattery || !UPower.onBattery) {
            if (root.autoLatched)
                root.autoLatched = false;
            return;
        }
        const pct = UPower.displayDevice.percentage * 100;
        const warn = GlobalConfig.general.battery.warningLevel;
        if (!root.autoLatched && pct <= warn)
            root.autoLatched = true;
        else if (root.autoLatched && pct >= warn + 2)
            root.autoLatched = false;
    }

    function setLowGfx(): void {
        Hypr.extras.applyOptions({
            "animations:enabled": 0,
            "decoration:shadow:enabled": 0,
            "decoration:blur:enabled": 0,
            "general:gaps_in": 0,
            "general:gaps_out": 0,
            "general:border_size": 1,
            "decoration:rounding": 0
        });
    }

    function restoreGfx(): void {
        // GameMode owns the low-gfx state while it is on; never reload under it.
        if (!GameMode.enabled)
            Hypr.extras.message("reload");
    }

    onEcoActiveChanged: {
        if (root.ecoActive)
            root.setLowGfx();
        else
            root.restoreGfx();
    }

    Connections {
        function onOnBatteryChanged(): void {
            root.evalAuto();
        }

        target: UPower
    }

    Connections {
        function onPercentageChanged(): void {
            root.evalAuto();
        }

        target: UPower.displayDevice
    }

    Connections {
        function onWarningLevelChanged(): void {
            root.evalAuto();
        }

        target: GlobalConfig.general.battery
    }

    Connections {
        function onConfigReloaded(): void {
            if (root.ecoActive)
                root.setLowGfx();
        }

        target: Hypr
    }

    PersistentProperties {
        id: props

        property bool enabled: false
        property bool autoOnBattery: true
        property bool toastOnChange: true

        reloadableId: "powerSaver"
    }

    IpcHandler {
        function isEnabled(): bool {
            return root.ecoActive;
        }

        function toggle(): void {
            props.enabled = !props.enabled;
        }

        function enable(): void {
            props.enabled = true;
        }

        function disable(): void {
            props.enabled = false;
            root.autoLatched = false;
        }

        function debug(): string {
            return `ecoActive=${root.ecoActive} manual=${props.enabled} auto=${props.autoOnBattery} latched=${root.autoLatched} onBattery=${root.onBattery} pct=${Math.round(root.batteryPct * 100)} hasBattery=${root.hasBattery}`;
        }

        target: "powerSaver"
    }
}
