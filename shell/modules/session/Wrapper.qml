pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components

Item {
    id: root

    required property DrawerVisibilities visibilities
    required property bool sidebarVisible
    // True when docked to the left edge (bar on the right)
    property bool dockLeft: false
    readonly property real nonAnimWidth: content.implicitWidth

    readonly property bool shouldBeActive: visibilities.session && Config.session.enabled
    property real offsetScale: shouldBeActive ? 0 : 1
    property real sidebarOffset: sidebarVisible ? Tokens.spacing.medium : 0

    visible: offsetScale < 1
    anchors.rightMargin: dockLeft ? 0 : (-implicitWidth - Tokens.spacing.extraSmall - sidebarOffset) * offsetScale
    anchors.leftMargin: dockLeft ? (-implicitWidth - Tokens.spacing.extraSmall - sidebarOffset) * offsetScale : 0
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight || (Tokens.sizes.session.button * 4 + Tokens.spacing.large * 3 + Tokens.padding.large * 2)
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: root.dockLeft ? undefined : parent.left
        anchors.right: root.dockLeft ? parent.right : undefined

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            visibilities: root.visibilities
        }
    }
}
