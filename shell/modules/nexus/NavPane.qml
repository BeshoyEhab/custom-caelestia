import "navpane"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.nexus

ColumnLayout {
    id: root

    required property NexusState nState

    spacing: Tokens.spacing.large

    // Two-step destructive confirm: first click arms (icon swap + timeout),
    // second click executes. Deleting shell.json is irreversible.
    property bool confirmReset: false

    Timer {
        id: confirmResetTimer
        interval: 3000
        repeat: false
        onTriggered: root.confirmReset = false
    }

    SearchBar {
        Layout.fillWidth: true
        nState: root.nState
    }

    NavLocations {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: -topMargin
        Layout.bottomMargin: -bottomMargin
        nState: root.nState
    }

    IconButton {
        Layout.fillWidth: true
        Layout.margins: Tokens.padding.large
        Layout.topMargin: 0
        icon: root.confirmReset ? "warning" : "restart_alt"
        type: root.confirmReset ? IconButton.Filled : IconButton.Tonal
        onClicked: {
            if (root.confirmReset)
                resetAllProc.running = true;
            else {
                root.confirmReset = true;
                confirmResetTimer.restart();
            }
        }
    }

    Process {
        id: resetAllProc
        command: ["sh", "-c", "rm -f ~/.config/caelestia/shell.json"]
        onRunningChanged: {
            if (!running)
                Quickshell.quit()
        }
    }
}
