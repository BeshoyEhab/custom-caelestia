import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Scaled map of the current monitor arrangement. Delegates are created
// imperatively: a Repeater over a JS array does not render in this build
// (see AGENTS.md "Workspace Overview").
Item {
    id: root

    property var monitors: []
    property string mainName: ""

    readonly property var activeMonitors: (root.monitors || []).filter(m => !m.disabled)

    Component {
        id: monitorComp

        StyledRect {
            id: rect

            property string label: ""
            property bool isMain: false
            readonly property bool isMonitorRect: true

            color: isMain ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHighest
            radius: Tokens.rounding.medium
            border.width: 2
            border.color: isMain ? Colours.palette.m3primary : Colours.palette.m3outline

            StyledText {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, rect.width - 8)
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                text: rect.label
                color: rect.isMain ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }
        }
    }

    function rebuild(): void {
        for (let i = root.children.length - 1; i >= 0; i--) {
            const child = root.children[i];
            if (child && child.isMonitorRect)
                child.destroy();
        }

        const list = root.activeMonitors;
        if (list.length === 0 || root.width < 10 || root.height < 10)
            return;

        let minX = Infinity;
        let minY = Infinity;
        let maxX = -Infinity;
        let maxY = -Infinity;
        for (const m of list) {
            const scale = m.scale > 0 ? m.scale : 1;
            minX = Math.min(minX, m.x);
            minY = Math.min(minY, m.y);
            maxX = Math.max(maxX, m.x + m.width / scale);
            maxY = Math.max(maxY, m.y + m.height / scale);
        }

        const padding = 14;
        const k = Math.min((root.width - padding * 2) / Math.max(1, maxX - minX), (root.height - padding * 2) / Math.max(1, maxY - minY));
        const offsetX = (root.width - (maxX - minX) * k) / 2;
        const offsetY = (root.height - (maxY - minY) * k) / 2;

        for (const m of list) {
            const scale = m.scale > 0 ? m.scale : 1;
            monitorComp.createObject(root, {
                x: offsetX + (m.x - minX) * k,
                y: offsetY + (m.y - minY) * k,
                width: Math.max(30, (m.width / scale) * k),
                height: Math.max(22, (m.height / scale) * k),
                label: m.name,
                isMain: m.name === root.mainName
            });
        }
    }

    onMonitorsChanged: rebuild()
    onMainNameChanged: rebuild()
    onWidthChanged: rebuild()
    onHeightChanged: rebuild()
    Component.onCompleted: rebuild()
}
