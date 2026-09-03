pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.modules.bar as Bar

Region {
    id: root

    required property Bar.BarWrapper bar
    required property Panels panels
    required property var win

    readonly property bool barIsLeft: GlobalConfig.bar.positioningEdge === 0
    readonly property bool barIsRight: GlobalConfig.bar.positioningEdge === 1
    readonly property bool barIsTop: GlobalConfig.bar.positioningEdge === 2
    readonly property bool barIsBottom: GlobalConfig.bar.positioningEdge === 3
    readonly property real barOffsetX: barIsLeft ? bar.implicitWidth : 0
    readonly property real barOffsetY: barIsTop ? bar.implicitHeight : 0

    function edgeToString(edge: int): string {
        if (edge === 0) return "left";
        if (edge === 1) return "right";
        if (edge === 2) return "top";
        if (edge === 3) return "bottom";
        return "top";
    }

    function hoverGeom(edge: string, hw: real, hh: real): rect {
        const w = win.width;
        const h = win.height;
        if (edge === "top") return Qt.rect((w - hw) / 2, 0, hw, hh);
        if (edge === "bottom") return Qt.rect((w - hw) / 2, h - hh, hw, hh);
        if (edge === "left") return Qt.rect(0, (h - hh) / 2, hw, hh);
        if (edge === "right") return Qt.rect(w - hw, (h - hh) / 2, hw, hh);
        if (edge === "topLeft") return Qt.rect(0, 0, hw, hh);
        if (edge === "topRight") return Qt.rect(w - hw, 0, hw, hh);
        if (edge === "bottomLeft") return Qt.rect(0, h - hh, hw, hh);
        if (edge === "bottomRight") return Qt.rect(w - hw, h - hh, hw, hh);
        return Qt.rect(0, 0, 0, 0);
    }

    readonly property real borderThickness: win.contentItem.Config.border.thickness
    readonly property real clampedThickness: win.contentItem.Config.border.clampedThickness

    x: (barIsLeft ? bar.clampedWidth : clampedThickness) + win.dragMaskPadding
    y: (barIsTop ? bar.clampedHeight : clampedThickness) + win.dragMaskPadding
    width: win.width - (barIsLeft || barIsRight ? bar.clampedWidth : 0) - clampedThickness * 2 - win.dragMaskPadding * 2
    height: win.height - (barIsTop || barIsBottom ? bar.clampedHeight : 0) - clampedThickness * 2 - win.dragMaskPadding * 2
    intersection: Intersection.Xor

    R {
        panel: root.panels.dashboard
        y: 0
        height: panel.height * (1 - root.panels.dashboard.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.launcher
        y: root.win.height - height
        height: panel.height * (1 - root.panels.launcher.offsetScale) + root.borderThickness
    }

    R {
        id: sessionRegion

        panel: root.panels.sessionWrapper
        x: root.win.width - width
        width: panel.width * (1 - root.panels.session.offsetScale) + root.borderThickness + sidebarRegion.width
    }

    R {
        id: sidebarRegion

        panel: root.panels.sidebar
        x: root.win.width - width
        width: panel.width * (1 - root.panels.sidebar.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.osdWrapper
        x: root.win.width - width
        width: panel.width * (1 - root.panels.osd.offsetScale) + root.borderThickness + sessionRegion.width
    }

    R {
        panel: root.panels.notifications
        y: 0
        height: panel.height + root.borderThickness
    }

    R {
        panel: root.panels.utilities
        y: root.win.height - height
        height: panel.height * (1 - root.panels.utilities.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.popoutsWrapper
        width: panel.width * (1 - root.panels.popoutsWrapper.offsetScale)
    }

    // Hover areas — always accept input so hover detection works.
    Region {
        property var geom: root.hoverGeom(GlobalConfig.launcher.hoverEdge, GlobalConfig.launcher.hoverWidth, GlobalConfig.launcher.hoverHeight)
        x: geom.x
        y: geom.y
        width: geom.width
        height: geom.height
        intersection: Intersection.Subtract
    }
    Region {
        property var geom: root.hoverGeom(GlobalConfig.dashboard.hoverEdge, GlobalConfig.dashboard.hoverWidth, GlobalConfig.dashboard.hoverHeight)
        x: geom.x
        y: geom.y
        width: geom.width
        height: geom.height
        intersection: Intersection.Subtract
    }
    Region {
        property var geom: root.hoverGeom(GlobalConfig.sidebar.hoverEdge, GlobalConfig.sidebar.hoverWidth, GlobalConfig.sidebar.hoverHeight)
        x: geom.x
        y: geom.y
        width: geom.width
        height: geom.height
        intersection: Intersection.Subtract
    }
    // ponytail: bar hover zone — only as wide/tall as the bar itself so input doesn't leak to windows below
    Region {
        x: root.barIsLeft ? 0 : (root.barIsRight ? win.width - bar.clampedWidth : 0)
        y: root.barIsTop ? 0 : (root.barIsBottom ? win.height - bar.clampedHeight : 0)
        width: root.barIsLeft || root.barIsRight ? bar.clampedWidth : win.width
        height: root.barIsLeft || root.barIsRight ? win.height : bar.clampedHeight
        intersection: Intersection.Subtract
    }

    component R: Region {
        required property Item panel

        x: panel.x + root.barOffsetX
        y: panel.y + root.borderThickness + root.barOffsetY
        width: panel.width
        height: panel.height
        intersection: Intersection.Subtract
    }
}
