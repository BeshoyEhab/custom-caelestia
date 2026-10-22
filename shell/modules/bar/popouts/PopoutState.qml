import QtQuick

QtObject {
    id: root

    property string currentName
    property bool hasCurrent
    property int workspacePreviewId
    property string workspacePreviewName

    // Hover debounce, both directions: moving onto an entry waits this long
    // before its popout opens, and leaving the bar/popout waits this long
    // before the open one closes. Small enough to feel immediate, long enough
    // to survive a shaky hand or a quick pass over another entry.
    property int hoverDelay: 150

    property Timer closeTimer: Timer {
        interval: root.hoverDelay
        repeat: false
        onTriggered: root.hasCurrent = false
    }

    signal detachRequested(mode: string)

    function closeSoon(): void {
        // Only arm the countdown once: continued movement keeps reporting the
        // same "outside" state and must not push the deadline back forever.
        if (!closeTimer.running)
            closeTimer.restart();
    }

    function cancelClose(): void {
        closeTimer.stop();
    }
}
