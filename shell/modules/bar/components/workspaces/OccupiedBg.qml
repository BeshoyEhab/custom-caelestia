import QtQuick
import Quickshell
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property var workspaces
    required property int wsSpacing

    // Connected primary-tinted pill (classic look): no separations, true color.
    readonly property color colour: Qt.rgba(
        (Colours.palette.m3primary.r + Colours.tPalette.m3surfaceContainer.r) / 2,
        (Colours.palette.m3primary.g + Colours.tPalette.m3surfaceContainer.g) / 2,
        (Colours.palette.m3primary.b + Colours.tPalette.m3surfaceContainer.b) / 2,
        1
    )
    property color colourAnimated: colour

    // Instant on fresh Bar load (hover-open): suppress replays so the
    // background appears in final state. Enabled shortly after load.
    property bool animationsReady: false

    Timer {
        interval: 350
        running: true
        repeat: false
        onTriggered: root.animationsReady = true
    }

    Behavior on colourAnimated {
        CAnim {}
    }

    // Continuous pill per run of adjacent occupied workspaces (classic
    // connector look), computed from the engine-owned Workspace items.
    readonly property var groups: {
        const items = root.workspaces ?? [];
        const out = [];
        let start = -1;
        const occ = i => !!(items[i] && items[i].isOccupied);
        for (let i = 0; i <= items.length; i++) {
            if (i < items.length && occ(i)) {
                if (start < 0)
                    start = i;
            } else if (start >= 0) {
                out.push({
                    from: start,
                    to: i - 1
                });
                start = -1;
            }
        }
        return out;
    }

    // Item wrappers because `layer.enabled` clips the content, and the pills
    // extend 1px outside the parent.
    Item {
        anchors.fill: parent
        anchors.margins: -1

        opacity: root.colourAnimated.a
        layer.enabled: opacity < 1 // Forces opacity to apply to children as a single layer

        Item {
            anchors.fill: parent
            anchors.margins: 1

            Repeater {
                model: root.groups.length

                StyledRect {
                    required property int index

                    readonly property var group: root.groups[index]
                    readonly property var first: root.workspaces[group.from]
                    readonly property var last: root.workspaces[group.to]

                    anchors.left: parent?.left
                    anchors.right: parent?.right
                    anchors.margins: -1

                    y: first ? first.y + anchors.margins : 0
                    implicitHeight: first && last ? (last.y + last.LazyListView.visibleHeight) - first.y - anchors.margins * 2 : 0

                    color: Qt.alpha(root.colour, 1)
                    radius: Tokens.rounding.full

                    scale: 0
                    Component.onCompleted: scale = 1

                    Behavior on scale {
                        enabled: root.animationsReady
                        Anim {
                            easing: Tokens.anim.standardDecel
                        }
                    }

                    Behavior on y {
                        enabled: root.animationsReady
                        Anim {}
                    }

                    Behavior on implicitHeight {
                        enabled: root.animationsReady
                        Anim {}
                    }
                }
            }
        }
    }
}
