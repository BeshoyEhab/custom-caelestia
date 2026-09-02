pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

ColumnLayout {
    id: root

    required property PopoutState popouts

    readonly property int wsId: popouts.workspacePreviewId
    readonly property var ws: Hypr.workspaces.values.find(w => w.id === root.wsId)
    readonly property var windows: Hypr.toplevels.values.filter(c => c.workspace?.id === root.wsId)
    readonly property bool hasWindows: windows.length > 0

    spacing: Tokens.spacing.small

    implicitWidth: 200
    implicitHeight: header.implicitHeight + (root.hasWindows ? previewGrid.implicitHeight : emptyState.implicitHeight) + Tokens.padding.medium * 2

    Item {
        id: header

        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        Layout.margins: Tokens.padding.medium

        implicitHeight: Math.max(wsName.implicitHeight, wsCount.implicitHeight)

        StyledText {
            id: wsName

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            text: root.popouts.workspacePreviewName || root.wsId.toString()
            color: Colours.palette.m3onSurface
            font: Tokens.font.body.medium
            elide: Text.ElideRight
            width: parent.width - wsCount.width - Tokens.spacing.small
        }

        StyledText {
            id: wsCount

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            text: root.windows.length > 0 ? `${root.windows.length} window${root.windows.length === 1 ? "" : "s"}` : ""
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            visible: root.windows.length > 0
        }
    }

    // Window previews grid
    ColumnLayout {
        id: previewGrid

        Layout.fillWidth: true
        Layout.leftMargin: Tokens.padding.medium
        Layout.rightMargin: Tokens.padding.medium
        Layout.bottomMargin: Tokens.padding.medium
        visible: root.hasWindows

        spacing: Tokens.spacing.extraSmall

        Repeater {
            model: Math.min(root.windows.length, 4)

            RowLayout {
                required property int index

                property var windowData: root.windows[parent.index]

                spacing: Tokens.spacing.small

                // App icon
                MaterialIcon {
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    grade: 0
                    text: Icons.getAppCategoryIcon(root.windows[parent.index]?.lastIpcObject?.class ?? "", "terminal")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pixelSize: 14
                }

                // Window title
                StyledText {
                    Layout.fillWidth: true
                    text: root.windows[parent.index]?.lastIpcObject?.title ?? "Unknown"
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }

        // More windows indicator
        StyledText {
            Layout.fillWidth: true
            visible: root.windows.length > 4
            text: `+${root.windows.length - 4} more`
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // Empty state
    Item {
        id: emptyState

        Layout.fillWidth: true
        Layout.preferredHeight: 40
        visible: !root.hasWindows

        StyledText {
            anchors.centerIn: parent
            text: qsTr("Empty workspace")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }
    }
}
