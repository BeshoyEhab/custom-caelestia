pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config

Singleton {
    id: root

    property alias enabled: props.enabled

    onEnabledChanged: {
        if (enabled)
            Toaster.toast(qsTr("Presentation mode enabled"), qsTr("Hover interactions are now disabled"), "presentation");
        else
            Toaster.toast(qsTr("Presentation mode disabled"), qsTr("Hover interactions are now enabled"), "presentation");
    }

    PersistentProperties {
        id: props

        property bool enabled: false

        reloadableId: "presentationMode"
    }

    IpcHandler {
        function isEnabled(): bool {
            return props.enabled;
        }

        function toggle(): void {
            props.enabled = !props.enabled;
        }

        function enable(): void {
            props.enabled = true;
        }

        function disable(): void {
            props.enabled = false;
        }

        target: "presentationMode"
    }
}
