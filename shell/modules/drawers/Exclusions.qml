pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components.containers
import qs.modules.bar as Bar

Scope {
    id: root

    required property ShellScreen screen
    required property Bar.BarWrapper bar

    // The bar's zone follows its edge; the other three edges keep a thin
    // border zone. (Two zones must never share an edge.)
    readonly property int barEdge: GlobalConfig.bar.positioningEdge

    ExclusionZone {
        anchors.left: barEdge === 0
        anchors.right: barEdge === 1
        anchors.top: barEdge === 2
        anchors.bottom: barEdge === 3
        exclusiveZone: root.bar.exclusiveZone
    }

    ExclusionZone {
        anchors.top: barEdge !== 2
    }

    ExclusionZone {
        anchors.right: barEdge !== 1
    }

    ExclusionZone {
        anchors.bottom: barEdge !== 3
    }

    component ExclusionZone: StyledWindow {
        screen: root.screen
        name: "border-exclusion"
        exclusiveZone: contentItem.Config.border.thickness
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
    }
}
