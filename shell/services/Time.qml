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

    readonly property string timeStr: format(GlobalConfig.services.useTwelveHourClock ? "hh:mm:A" : "hh:mm")
    readonly property list<string> timeComponents: timeStr.split(":")
    readonly property string hourStr: timeComponents[0] ?? ""
    readonly property string minuteStr: timeComponents[1] ?? ""
    readonly property string amPmStr: timeComponents[2] ?? ""
    // Wall-clock seconds for ticking displays: format() reads the
    // minute-precision clock (always :00), so this re-evaluates per tick.
    readonly property string secondsStr: {
        secClock.seconds;
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
