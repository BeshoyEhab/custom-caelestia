import QtQuick
import QtQuick.Layouts
import Quickshell
import "WidgetRegistry.js" as Registry

// Vertical host: lays widget frames out in a column and answers hit tests
// against the frames it hosts.
ColumnLayout {
    id: root

    required property var items
    property var hostContext
    property string orientation: "vertical"

    // The frames are the repeater's live delegates: the list is derived from
    // the repeater, so it re-evaluates when the repeater's count changes and
    // never retains a destroyed delegate.
    readonly property var frames: {
        const out = [];
        for (let i = 0; i < frameRepeater.count; i++) {
            const frame = frameRepeater.itemAt(i);
            if (frame)
                out.push(frame);
        }
        return out;
    }

    function hitTest(x: real, y: real): var {
        // A hit anywhere inside a frame maps back to the frame itself, not
        // to the inner child that contains the point.
        const frames = root.frames;
        for (let i = 0; i < frames.length; i++) {
            const frame = frames[i];
            if (frame && frame.x <= x && x < frame.x + frame.width &&
                          frame.y <= y && y < frame.y + frame.height)
                return frame;
        }
        return null;
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
            // visibleItems, not validateItems: validation keeps disabled items
            // and the dock must not render widgets the user turned off (the
            // old bar filtered e.enabled before building its loaders).
            values: Registry.visibleItems(root.items)
        }

        delegate: WidgetFrame {
            id: frame

            required property var modelData

            item: modelData
            hostContext: root.hostContext
            orientation: root.orientation
        }
    }
}
