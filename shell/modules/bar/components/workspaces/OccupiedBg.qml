pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property Repeater workspaces
    required property var occupied
    required property int groupOffset

    readonly property real circleSize: Tokens.sizes.bar.innerWidth - Tokens.padding.extraSmall * 2

    readonly property color connectorColor: Qt.rgba(
        (Colours.palette.m3primary.r + Colours.tPalette.m3surfaceContainer.r) / 2,
        (Colours.palette.m3primary.g + Colours.tPalette.m3surfaceContainer.g) / 2,
        (Colours.palette.m3primary.b + Colours.tPalette.m3surfaceContainer.b) / 2,
        1
    )

    property list<var> pills: []

    onOccupiedChanged: {
        if (!occupied)
            return;
        let count = 0;
        const start = groupOffset;
        const end = start + Config.bar.workspaces.shown;
        for (const [ws, occ] of Object.entries(occupied)) {
            if (ws > start && ws <= end && occ) {
                const isFirstInGroup = Number(ws) === start + 1;
                const isLastInGroup = Number(ws) === end;
                if (isFirstInGroup || !occupied[ws - 1]) {
                    if (pills[count])
                        pills[count].start = ws;
                    else
                        pills.push(pillComp.createObject(root, {
                            start: ws
                        }));
                    count++;
                }
                if ((isLastInGroup || !occupied[ws + 1]) && pills[count - 1])
                    pills[count - 1].end = ws;
            }
        }
        if (pills.length > count)
            pills.splice(count, pills.length - count).forEach(p => p.destroy());
    }

    Repeater {
        model: ScriptModel {
            values: root.pills.filter(p => p)
        }

        Rectangle {
            id: rect

            required property var modelData

            readonly property var start: root.workspaces.count > 0 ? root.workspaces.itemAt(getWsIdx(modelData.start)) ?? null : null
            readonly property var end: root.workspaces.count > 0 ? root.workspaces.itemAt(getWsIdx(modelData.end)) ?? null : null

            function getWsIdx(ws: int): int {
                let i = ws - 1;
                while (i < 0)
                    i += Config.bar.workspaces.shown;
                return i % Config.bar.workspaces.shown;
            }

            anchors.horizontalCenter: root.horizontalCenter

            y: start ? start.y - Tokens.padding.extraSmall : 0
            implicitWidth: Tokens.sizes.bar.innerWidth - Tokens.padding.extraSmall * 2
            implicitHeight: start && end ? (end.y - start.y) + root.circleSize : 0

            color: root.connectorColor
            radius: Tokens.rounding.full

            scale: 0
            Component.onCompleted: scale = 1

            Behavior on scale {
                Anim {
                    easing: Tokens.anim.standardDecel
                }
            }

            Behavior on y {
                Anim {}
            }

            Behavior on implicitHeight {
                Anim {}
            }
        }
    }

    Component {
        id: pillComp

        Pill {}
    }

    component Pill: QtObject {
        property int start
        property int end
    }
}
