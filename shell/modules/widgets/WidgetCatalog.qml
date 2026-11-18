pragma Singleton

import QtQuick
import Quickshell
import "WidgetRegistry.js" as Registry
import "builtin"
import "helpers"

// QML half of the widget registry: maps a registry id to the component that
// renders it. Metadata stays in WidgetRegistry.js so it remains node-testable.
Singleton {
    id: root

    readonly property list<var> catalog: Registry.registry()

    function meta(type) {
        return Registry.get(type);
    }

    function componentFor(type: string): Component {
        switch (type) {
        case "logo":
            return logoComp;
        case "workspaces":
            return workspacesComp;
        case "activeWindow":
            return activeWindowComp;
        case "tray":
            return trayComp;
        case "clock":
            return clockComp;
        case "statusIcons":
            return statusIconsComp;
        case "power":
            return powerComp;
        case "spacer":
            return spacerComp;
        case "separator":
            return separatorComp;
        case "group":
            return groupComp;
        default:
            return null;
        }
    }

    Component {
        id: logoComp

        DockLogo {}
    }

    Component {
        id: workspacesComp

        DockWorkspaces {}
    }

    Component {
        id: activeWindowComp

        DockActiveWindow {}
    }

    Component {
        id: trayComp

        DockTray {}
    }

    Component {
        id: clockComp

        DockClock {}
    }

    Component {
        id: statusIconsComp

        DockStatusIcons {}
    }

    Component {
        id: powerComp

        DockPower {}
    }

    Component {
        id: spacerComp

        Spacer {}
    }

    Component {
        id: separatorComp

        Separator {}
    }

    Component {
        id: groupComp

        Group {}
    }
}
