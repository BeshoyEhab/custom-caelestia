import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import "WidgetRegistry.js" as Registry

// Vertical host: lays widget frames out in a column and answers hit tests
// against the frames it hosts.
ColumnLayout {
    id: root

    required property var items
    property var hostContext
    property string orientation: "vertical"

    property var frameList: []

    readonly property var frames: frameList

    function hitTest(x: real, y: real): var {
        const hit = root.childAt(x, y);
        return hit ?? null;
    }

    function frameFor(type: string): var {
        const frames = root.frames || [];
        for (let i = 0; i < frames.length; i++) {
            const frame = frames[i];
            if (frame && frame.entryId === type)
                return frame;
        }
        return null;
    }

    Repeater {
        id: frameRepeater

        model: ScriptModel {
            values: Registry.validateItems(root.items).items
        }

        delegate: WidgetFrame {
            id: frame

            required property var modelData

            Component.onCompleted: {
                frame.item = modelData
                frame.hostContext = root.hostContext
                root.frameList.push(frame)
            }

            Component.onDestruction: {
                const frames = root.frameList;
                for (let i = frames.length - 1; i >= 0; i--) {
                    if (frames[i] === frame) {
                        frames.splice(i, 1);
                        break;
                    }
                }
            }
        }
    }
}
