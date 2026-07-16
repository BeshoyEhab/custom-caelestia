import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Caelestia
import Caelestia.Config

Scope {
    id: root

    property bool warningWarned: false
    property bool criticalWarned: false

    Connections {
        function onOnBatteryChanged(): void {
            if (UPower.onBattery) {
                if (GlobalConfig.utilities.toasts.chargingChanged)
                    Toaster.toast(qsTr("Charger unplugged"), qsTr("Battery is discharging"), "power_off");
            } else {
                if (GlobalConfig.utilities.toasts.chargingChanged)
                    Toaster.toast(qsTr("Charger plugged in"), qsTr("Battery is charging"), "power");
                root.warningWarned = false;
                root.criticalWarned = false;
            }
        }

        target: UPower
    }

    Connections {
        function onPercentageChanged(): void {
            if (!UPower.onBattery)
                return;

            const p = UPower.displayDevice.percentage * 100;

            if (p <= GlobalConfig.general.battery.warningLevel && !root.warningWarned) {
                root.warningWarned = true;
                Toaster.toast(qsTr("Low battery"), qsTr("You might want to plug in a charger"), "battery_android_frame_2", Toast.Warning);
            }

            if (p <= GlobalConfig.general.battery.criticalLevel && !root.criticalWarned) {
                root.criticalWarned = true;
                Toaster.toast(qsTr("Critical battery level"), qsTr("Plug the charger right now!"), "battery_android_alert", Toast.Error);
            }

            if (!hibernateTimer.running && p <= GlobalConfig.general.battery.hibernateLevel) {
                Toaster.toast(qsTr("Hibernating in 5 seconds"), qsTr("Hibernating to prevent data loss"), "battery_android_alert", Toast.Error);
                hibernateTimer.start();
            }
        }

        target: UPower.displayDevice
    }

    Timer {
        id: hibernateTimer

        interval: 5000
        onTriggered: Quickshell.execDetached(["systemctl", "hibernate"])
    }
}
