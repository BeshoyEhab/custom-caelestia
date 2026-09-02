pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property int index
    required property int activeWsId
    required property var occupied
    required property int groupOffset
    required property Repeater workspaces
    property var bar

    readonly property bool isWorkspace: true
    readonly property int ws: groupOffset + index + 1
    readonly property bool isOccupied: occupied[ws] ?? false
    readonly property bool isActive: root.activeWsId === root.ws

    readonly property string appIcon: {
        Hypr.appIconsVersion;
        if (!Config.bar.workspaces.showAppIcon || !root.isOccupied)
            return "";
        return Hypr.appIconsPerWorkspace[root.ws] ?? "";
    }
    readonly property bool showAppIcon: appIcon !== ""

    readonly property real circleSize: Tokens.sizes.bar.innerWidth - Tokens.padding.extraSmall * 2
    readonly property int size: circleSize + 2

    Layout.alignment: Qt.AlignHCenter
    Layout.preferredWidth: root.circleSize
    Layout.preferredHeight: root.size

    // Grey circle background for ALL workspaces
    Rectangle {
        id: circleBg

        anchors.centerIn: parent
        width: root.circleSize
        height: root.circleSize
        radius: width / 2

        color: root.isOccupied ? Qt.rgba(
            (Colours.palette.m3primary.r + Colours.tPalette.m3surfaceContainer.r) / 2,
            (Colours.palette.m3primary.g + Colours.tPalette.m3surfaceContainer.g) / 2,
            (Colours.palette.m3primary.b + Colours.tPalette.m3surfaceContainer.b) / 2,
            1
        ) : "#606060"
        opacity: root.isOccupied || root.isActive ? 1.0 : 0.5

        Behavior on opacity {
            Anim { type: Anim.DefaultEffects }
        }
    }

    // Workspace number or dot (when no app icon)
    MaterialIcon {
        id: numberIndicator

        anchors.centerIn: circleBg
        visible: !root.showAppIcon

        animate: true
        text: {
            if (Config.bar.workspaces.showEmptyAsNumber)
                return root.ws.toString();
            if (!root.isOccupied && !root.isActive)
                return "\u2022";
            const ws = Hypr.workspaces.values.find(w => w.id === root.ws);
            const wsName = !ws || ws.name == root.ws ? root.ws : ws.name[0];
            let displayName = wsName.toString();
            if (Config.bar.workspaces.capitalisation.toLowerCase() === "upper") {
                displayName = displayName.toUpperCase();
            } else if (Config.bar.workspaces.capitalisation.toLowerCase() === "lower") {
                displayName = displayName.toLowerCase();
            }
            const label = Config.bar.workspaces.label || displayName;
            const occupiedLabel = Config.bar.workspaces.occupiedLabel || label;
            const activeLabel = Config.bar.workspaces.activeLabel || (root.isOccupied ? occupiedLabel : label);
            return root.isActive ? activeLabel : root.isOccupied ? occupiedLabel : label;
        }
        color: root.isActive ? "#ffffff" : (root.isOccupied ? "#cccccc" : "#999999")
        verticalAlignment: Qt.AlignVCenter
        font.family: Tokens.font.workspaces
        font.pixelSize: root.isOccupied ? undefined : Tokens.sizes.bar.innerWidth * 0.4
    }

    // App icon (when available)
    IconImage {
        id: appIconDisplay

        anchors.centerIn: circleBg
        visible: root.showAppIcon

        implicitSize: Tokens.sizes.bar.innerWidth * 0.55

        source: {
            Hypr.appIconsVersion;
            return root.appIcon ? Quickshell.iconPath(root.appIcon, "image-missing") : "";
        }
    }
}
