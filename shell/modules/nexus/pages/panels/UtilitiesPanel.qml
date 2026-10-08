pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common

PageBase {
    id: root

    // Canonical toggle set. Keep in sync with the backend defaults in
    // utilitiesconfig.hpp: reads and writes both go through
    // currentToggles(), so a missing id means the same thing everywhere
    // and partial lists heal instead of flipping other rows.
    readonly property var toggleDefaults: [
        { id: "wifi", enabled: true },
        { id: "bluetooth", enabled: true },
        { id: "mic", enabled: true },
        { id: "settings", enabled: true },
        { id: "gameMode", enabled: true },
        { id: "eco", enabled: true },
        { id: "dnd", enabled: true },
        { id: "vpn", enabled: false }
    ]

    readonly property var toggleRows: [
        { id: "wifi", text: qsTr("Wi-Fi"), sub: qsTr("Toggle wireless networking") },
        { id: "bluetooth", text: qsTr("Bluetooth"), sub: qsTr("Toggle the Bluetooth adapter") },
        { id: "mic", text: qsTr("Microphone"), sub: qsTr("Mute or unmute the default source") },
        { id: "settings", text: qsTr("Settings"), sub: qsTr("Open the settings window") },
        { id: "gameMode", text: qsTr("Game mode"), sub: qsTr("Toggle game mode") },
        { id: "eco", text: qsTr("Eco mode"), sub: qsTr("Shell power saver (visuals, video, polling)") },
        { id: "dnd", text: qsTr("Do not disturb"), sub: qsTr("Silence notifications") },
        { id: "vpn", text: qsTr("VPN"), sub: qsTr("Connect or disconnect the VPN") }
    ]

    // Single source of truth: always a complete, plain-JS list. Read
    // GlobalConfig, NOT Config: once this key exists in shell.json the
    // per-screen overlay shadows it and stops syncing global writes, so
    // Config reads go stale. Array.from also tolerates non-array
    // list wrappers where Array.isArray would read everything as off.
    function currentToggles(): var {
        const raw = GlobalConfig.utilities.quickToggles;
        const src = raw ? Array.from(raw) : [];
        const byId = {};
        for (const t of src)
            if (t && t.id !== undefined)
                byId[t.id] = t.enabled ?? true;
        return root.toggleDefaults.map(d => ({
            id: d.id,
            enabled: byId[d.id] ?? d.enabled
        }));
    }

    function isToggleOn(id: string): bool {
        return currentToggles().find(t => t.id === id)?.enabled ?? false;
    }

    function setToggleOn(id: string, on: bool): void {
        GlobalConfig.utilities.quickToggles = currentToggles().map(t => ({
            id: t.id,
            enabled: t.id === id ? on : t.enabled
        }));
    }

    title: qsTr("Utilities")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // General
        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Enabled")
            subtext: qsTr("Show the utilities panel")
            checked: Config.utilities.enabled
            onToggled: GlobalConfig.utilities.enabled = checked
        }

        // Cards
        SectionHeader {
            text: qsTr("Cards")
        }

        ToggleRow {
            first: true
            text: qsTr("Keep awake")
            subtext: qsTr("Show the idle inhibitor card")
            checked: Config.utilities.cards.keepAwake
            onToggled: GlobalConfig.utilities.cards.keepAwake = checked
        }

        ToggleRow {
            text: qsTr("Screen recorder")
            subtext: qsTr("Show the screen recorder card")
            checked: Config.utilities.cards.recorder
            onToggled: GlobalConfig.utilities.cards.recorder = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Quick toggles")
            subtext: qsTr("Show the quick toggles card")
            checked: Config.utilities.cards.quickToggles
            onToggled: GlobalConfig.utilities.cards.quickToggles = checked
        }

        // Quick toggles
        SectionHeader {
            text: qsTr("Quick toggles")
        }

        Repeater {
            model: root.toggleRows

            delegate: ToggleRow {
                id: row

                required property var modelData
                required property int index

                first: index === 0
                last: index === root.toggleRows.length - 1
                text: modelData.text
                subtext: modelData.sub
                disabled: !Config.utilities.cards.quickToggles
                checked: root.isToggleOn(modelData.id)

                onToggled: {
                    root.setToggleOn(modelData.id, checked);
                    // A Switch flips its own checked on click, which breaks
                    // the binding above; re-bind so the row keeps following
                    // the config afterwards.
                    checked = Qt.binding(() => root.isToggleOn(row.modelData.id));
                }
            }
        }
    }
}
