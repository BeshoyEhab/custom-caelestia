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

    readonly property color colour: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
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

    // Item wrappers because `layer.enabled` clips the content, and the rects extend 1px outside the parent
    Item {
        anchors.fill: parent
        anchors.margins: -1

        opacity: root.colourAnimated.a
        layer.enabled: opacity < 1 // Forces opacity to apply to children as a single layer

        Item {
            anchors.fill: parent
            anchors.margins: 1

            AnimatedRepeater {
                model: ScriptModel {
                    values: root.workspaces
                }

                removeDuration: Tokens.anim.durations.expressiveDefaultEffects

                OccupiedRect {}
            }
        }
    }

    component OccupiedRect: StyledRect {
        required property int index
        required property Workspace modelData

        property real topRadius: ifAdjacent(0, -1, 0, width / 2)
        property real bottomRadius: ifAdjacent(root.workspaces.length - 1, 1, 0, width / 2)
        property real topPadding: ifAdjacent(0, -1, root.wsSpacing, 0)
        property real bottomPadding: ifAdjacent(root.workspaces.length - 1, 1, root.wsSpacing, 0)

        function ifAdjacent(exclIdx: int, adj: int, yes: real, no: real): real {
            if (AnimatedRepeater.adding || AnimatedRepeater.removing || !modelData?.isOccupied || index === exclIdx)
                return no;
            return root.workspaces[index + adj]?.isOccupied ? yes : no;
        }

        anchors.left: parent?.left
        anchors.right: parent?.right
        anchors.margins: -1

        y: modelData ? modelData.y + anchors.margins - topPadding : 0
        implicitHeight: modelData ? modelData.LazyListView.visibleHeight - anchors.margins * 2 + topPadding + bottomPadding : 0

        color: Qt.alpha(root.colour, 1)
        topLeftRadius: topRadius
        topRightRadius: topRadius
        bottomLeftRadius: bottomRadius
        bottomRightRadius: bottomRadius

        opacity: modelData?.isOccupied ? 1 : 0

        Behavior on topRadius {
            enabled: root.animationsReady
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on bottomRadius {
            enabled: root.animationsReady
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on topPadding {
            enabled: root.animationsReady
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on bottomPadding {
            enabled: root.animationsReady
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on opacity {
            enabled: root.animationsReady
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }
}
