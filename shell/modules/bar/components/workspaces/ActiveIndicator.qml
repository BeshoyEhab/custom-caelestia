import QtQuick
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services

StyledRect {
    id: root

    required property Workspace activeWs
    required property Item mask
    property alias contentColour: colouriser.colorizationColor

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

        const goingUp = newStart < start;
        const leadingDuration = Tokens.anim.durations.expressiveDefaultSpatial;
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
    implicitHeight: end - start
    radius: Tokens.rounding.full
    color: Colours.palette.m3primary

    Anim on start {
        id: startAnim
    }

    Anim on end {
        id: endAnim
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

    Colouriser {
        id: colouriser

        source: root.mask
        sourceColor: Colours.palette.m3onSurface
        colorizationColor: Colours.palette.m3onPrimary

        x: 0
        y: -parent.start
        implicitWidth: root.mask.width
        implicitHeight: root.mask.height

        anchors.horizontalCenter: parent.horizontalCenter
    }
}
