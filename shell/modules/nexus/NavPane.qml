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
        icon: "restart_alt"
        type: IconButton.Outlined
        onClicked: resetAllProc.running = true
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
