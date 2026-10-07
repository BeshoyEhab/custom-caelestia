import QtQuick
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    required property Workspace activeWs
    required property Item mask

    property real start
    property real end

    // Instant on fresh Bar load (hover-open): the first placement jumps
    // instead of replaying the trailing animation. Enabled shortly after
    // load so workspace switches animate normally.
    property bool animationsReady: false

    Timer {
        interval: 350
        running: true
        repeat: false
        onTriggered: root.animationsReady = true
    }

    function runAnim(): void {
        if (!activeWs)
            return;

        const newStart = activeWs.LazyListView.layoutY;
        const newEnd = newStart + activeWs.LazyListView.preferredHeight;
        if (!root.animationsReady) {
            startAnim.stop();
            endAnim.stop();
            root.start = newStart;
            root.end = newEnd;
            return;
        }

        // Fast glide (not the slow default spatial): snappy workspace
        // switching. The trail asymmetry stays via activeTrail.
        const goingUp = newStart < start;
        const leadingDuration = Tokens.anim.durations.expressiveFastSpatial;
        const trailingDuration = leadingDuration * (Config.bar.workspaces.activeTrail ? 1.5 : 1);

        startAnim.stop();
        endAnim.stop();
        startAnim.to = newStart;
        endAnim.to = newEnd;
        startAnim.duration = goingUp ? leadingDuration : trailingDuration;
        endAnim.duration = goingUp ? trailingDuration : leadingDuration;
        startAnim.start();
        endAnim.start();
    }

    onActiveWsChanged: runAnim()
    Component.onCompleted: runAnim()

    clip: true
    y: start + mask.y
    // Full delegate height plus one half-icon of tail below, so the
    // trail reads longer without moving any icons or spacing. Row gaps
    // leave room for the tail (see wsSpacing), so it never touches the
    // next workspace. Null-safe: evaluated during teardown after activeWs
    // is gone.
    implicitHeight: end - start + (activeWs?.windowIconSize ?? 0) / 2
    radius: Tokens.rounding.full
    color: Colours.palette.m3primary

    Anim on start {
        id: startAnim

        type: Anim.FastSpatial
    }

    Anim on end {
        id: endAnim

        type: Anim.FastSpatial
    }

    Connections {
        function onLayoutYChanged(): void {
            root.runAnim();
        }

        function onPreferredHeightChanged(): void {
            root.runAnim();
        }

        target: root.activeWs?.LazyListView ?? null
    }
}
