pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components

Item {
    id: root

    required property DrawerVisibilities visibilities
    readonly property Props props: Props {}
    // True when docked to the left edge (bar on the right)
    property bool dockLeft: false
    readonly property int sidePad: Tokens.padding.large

    readonly property bool shouldBeActive: visibilities.sidebar && Config.sidebar.enabled
    property real offsetScale: shouldBeActive ? 0 : 1

    visible: offsetScale < 1
    anchors.rightMargin: dockLeft ? 0 : (-implicitWidth - Tokens.spacing.extraSmall) * offsetScale
    anchors.leftMargin: dockLeft ? (-implicitWidth - Tokens.spacing.extraSmall) * offsetScale : 0
    implicitWidth: Tokens.sizes.sidebar.width
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: root.dockLeft ? undefined : parent.left
        anchors.right: root.dockLeft ? parent.right : undefined
        anchors.leftMargin: root.dockLeft ? content.anchors.margins : root.sidePad
        anchors.rightMargin: root.dockLeft ? root.sidePad : undefined
        anchors.margins: CUtils.clamp(root.sidePad - Config.border.thickness, 0, root.sidePad)
        anchors.bottomMargin: 0

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            implicitWidth: Tokens.sizes.sidebar.width - root.sidePad - content.anchors.margins
            props: root.props
            visibilities: root.visibilities
        }
    }
}
