import QtQuick
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services

// Shared circle content for the workspace indicators. Used by both the
// normal list overlay (Workspaces.qml) and the special strip overlay
// (SpecialWorkspaces.qml) so the two look identical. Each caller passes
// its own settings (displayType, showAppIcon, labels), so the strips
// stay independently configurable. Sized/positioned by the caller.
Item {
    id: root

    required property int ws
    required property bool occupied
    required property bool focused
    required property int displayType

    // Caller-owned settings (normal vs special keys). showAppIcon is the
    // raw toggle; the focused-workspace exception lives in
    // Hypr.circleShowsIcon so overlay and strip never drift apart.
    property bool showAppIcon: true
    property string activeLabel: ""
    property string occupiedLabel: ""
    property string label: ""
    property var capitalisation: "preserve"
    // Dot colour for occupied (unfocused) workspaces.
    property color occupiedDotColor: Colours.palette.m3primary

    readonly property bool showShape: displayType === BarWorkspaceDisplay.Shapes
    readonly property bool effectiveShowIcon: Hypr.circleShowsIcon(displayType, showAppIcon, focused)
    readonly property string appIcon: {
        Hypr.appIconsVersion;
        if (!effectiveShowIcon || !occupied)
            return "";
        return Hypr.appIconsPerWorkspace[ws] ?? "";
    }

    // Displayed icon with a fast crossfade on change (no hard cuts when
    // focus moves between apps).
    property string shownIcon: ""
    property string pendingIcon: ""
    onAppIconChanged: {
        if (appIcon === shownIcon)
            return;
        pendingIcon = appIcon;
        if (swapAnim.running)
            swapAnim.restart();
        else
            swapAnim.start();
    }
    Component.onCompleted: shownIcon = appIcon

    SequentialAnimation {
        id: swapAnim

        NumberAnimation {
            target: iconHolder
            property: "opacity"
            to: 0
            duration: 90
        }
        ScriptAction {
            script: shownIcon = pendingIcon
        }
        NumberAnimation {
            target: iconHolder
            property: "opacity"
            to: 1
            duration: 140
        }
    }

    function displayText(): string {
        // Backend label defaults are blank padding ("  "), so only
        // non-blank labels override the number.
        if (focused) {
            if (activeLabel && activeLabel.trim())
                return activeLabel;
        }

        if (focused || occupied) {
            if (occupiedLabel && occupiedLabel.trim())
                return occupiedLabel;
        }

        if (label && label.trim())
            return label;

        const w = Hypr.workspaces.values.find(w => w.id === ws);
        let wsName = (!w || w.name == ws) ? String(ws) : String(w.name).replace(/^special:/, "")[0] ?? String(ws);

        const cap = capitalisation;
        if (cap === BarWorkspaceCapitalisation.Upper || String(cap).toLowerCase() === "upper")
            return wsName.toUpperCase();
        else if (cap === BarWorkspaceCapitalisation.Lower || String(cap).toLowerCase() === "lower")
            return wsName.toLowerCase();
        return wsName;
    }

    StyledText {
        anchors.centerIn: parent
        visible: !root.showShape && (root.shownIcon === "" || appImage.status === Image.Error)
        animate: true
        text: root.displayText()
        color: root.focused ? Colours.palette.m3onPrimary : (root.occupied ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant)
        verticalAlignment: Qt.AlignVCenter
        font.family: Tokens.font.workspaces
    }

    // A resolved icon name can still point at a missing file (unthemed /
    // removed icon): image-missing would render instead. Fall back to the
    // label text when the load fails.
    Item {
        id: iconHolder

        anchors.fill: parent

        IconImage {
            id: appImage

            anchors.centerIn: parent
            visible: !root.showShape && root.shownIcon !== "" && appImage.status !== Image.Error
            implicitSize: Tokens.sizes.bar.innerWidth * 0.62
            source: {
                Hypr.appIconsVersion;
                return root.shownIcon ? Quickshell.iconPath(root.shownIcon, "image-missing") : "";
            }
        }
    }

    // Shapes mode: a plain dot instead of text/icons.
    Rectangle {
        anchors.centerIn: parent
        visible: root.showShape
        width: 8
        height: 8
        radius: 4
        color: root.focused ? Colours.palette.m3onPrimary : (root.occupied ? root.occupiedDotColor : Colours.palette.m3outlineVariant)
    }
}
