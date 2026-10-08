pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config
import qs.services

Singleton {
    id: root

    property alias enabled: clock.enabled
    readonly property date date: clock.date
    readonly property int hours: clock.hours
    readonly property int minutes: clock.minutes
    // Seconds tick separately: the labels above only show hh:mm, so they
    // must not re-evaluate (and invalidate every consumer) every second.
    readonly property int seconds: secClock.seconds

    // SystemClock(Minutes) reports the upcoming minute during wall-second
    // :59 (verified: minute text flips a full second before :00). Invisible
    // without a seconds reference — but when the seconds clock runs, derive
    // from exact now (floored) so minute and seconds always agree. Costs
    // nothing extra: per-second invalidation already happens then.
    // Wall poll below keeps this within half a second of truth regardless
    // of tick phase (a tick-phase offset otherwise shows stale seconds for
    // up to a second, visibly behind clocks that read wall time directly
    // like the analog face).
    Timer {
        interval: 500
        running: root.secondsNeeded
        repeat: true
        onTriggered: root.wallTick++
    }
    property int wallTick: 0

    readonly property string timeStr: {
        if (root.secondsNeeded) {
            root.wallTick; // subscribe to the wall poll
            const d = new Date();
            d.setMilliseconds(0);
            return Qt.formatDateTime(d, GlobalConfig.services.useTwelveHourClock ? "hh:mm:A" : "hh:mm");
        }
        return format(GlobalConfig.services.useTwelveHourClock ? "hh:mm:A" : "hh:mm");
    }
    readonly property list<string> timeComponents: timeStr.split(":")
    readonly property string hourStr: timeComponents[0] ?? ""
    readonly property string minuteStr: timeComponents[1] ?? ""
    readonly property string amPmStr: timeComponents[2] ?? ""
    // Wall-clock seconds for ticking displays: driven by the wall poll
    // (same phase as timeStr above) instead of the seconds clock, so the
    // two can never disagree by a tick.
    readonly property string secondsStr: {
        root.wallTick;
        return String(new Date().getSeconds()).padStart(2, "0");
    }

    function format(fmt: string): string {
        return Qt.formatDateTime(clock.date, fmt);
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // Seconds wake the shell every second; only run when a visible
    // seconds consumer exists. Bar seconds are Loader-gated in
    // bar/components/Clock.qml:102; desktop clocks only exist when enabled.
    // Dashboard seconds (dash/DateTime.qml:67) render whenever the dashboard
    // is open, so keep ticking while it is visible to avoid frozen seconds.
    readonly property bool secondsNeeded: Config.bar.clock.showSeconds || Config.background.desktopClock.enabled || (Visibilities.getForActive()?.dashboard ?? false)

    SystemClock {
        id: secClock

        enabled: root.secondsNeeded
        precision: SystemClock.Seconds
    }
}
