import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Screen lock")

    // The idle timeouts are stored in GeneralIdle.timeouts as a list of
    // { timeout (seconds), idleAction, enabled? } maps. Here we edit the entries
    // by index: 0 = lock, 1 = screen off (DPMS), 2 = suspend — preserving the
    // actions and treating a 0 value as "never" (enabled = false).
    function timeoutMinutes(index: int): int {
        const entry = GlobalConfig.general.idle.timeouts[index];
        if (!entry || entry.enabled === false)
            return 0;
        return Math.round((entry.timeout ?? 0) / 60);
    }

    function setTimeoutMinutes(index: int, minutes: int): void {
        const timeouts = [...GlobalConfig.general.idle.timeouts];
        const entry = timeouts[index];
        if (!entry)
            return;
        timeouts[index] = Object.assign({}, entry, minutes <= 0
            ? { enabled: false, timeout: 0 }
            : { enabled: true, timeout: Math.round(minutes * 60) });
        GlobalConfig.general.idle.timeouts = timeouts;
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Screen lock")
        }

        StepperRow {
            first: true
            label: qsTr("Lock screen after")
            subtext: qsTr("Minutes of inactivity before the lock screen appears (0 = never)")
            value: root.timeoutMinutes(0)
            from: 0
            to: 120
            stepSize: 1
            onMoved: v => root.setTimeoutMinutes(0, Math.round(v))
        }

        ToggleRow {
            text: qsTr("Lock before sleep")
            subtext: qsTr("Show the lock screen when waking from suspend")
            checked: GlobalConfig.general.idle.lockBeforeSleep
            onToggled: GlobalConfig.general.idle.lockBeforeSleep = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Pause while media plays")
            subtext: qsTr("Don't lock or blank the screen while something is playing")
            checked: GlobalConfig.general.idle.inhibitWhenAudio
            onToggled: GlobalConfig.general.idle.inhibitWhenAudio = checked
        }

        SectionHeader {
            text: qsTr("Display & suspend")
        }

        StepperRow {
            first: true
            label: qsTr("Turn screen off after")
            subtext: qsTr("Minutes of inactivity before the display turns off (0 = never)")
            value: root.timeoutMinutes(1)
            from: 0
            to: 120
            stepSize: 1
            onMoved: v => root.setTimeoutMinutes(1, Math.round(v))
        }

        StepperRow {
            last: true
            label: qsTr("Suspend after")
            subtext: qsTr("Minutes of inactivity before suspending the system (0 = never)")
            value: root.timeoutMinutes(2)
            from: 0
            to: 240
            stepSize: 1
            onMoved: v => root.setTimeoutMinutes(2, Math.round(v))
        }
    }
}