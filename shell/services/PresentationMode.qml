pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import qs.services

Singleton {
    id: root

    property alias enabled: props.enabled

    onEnabledChanged: {
        if (enabled)
            Toaster.toast(qsTr("Presentation mode enabled"), qsTr("Hover-to-open disabled"), "slideshow");
        else
            Toaster.toast(qsTr("Presentation mode disabled"), qsTr("Hover-to-open restored"), "slideshow");
    }

    PersistentProperties {
        id: props

        property bool enabled

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
