pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.utils
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen

    readonly property bool disabled: Strings.testRegexList(Config.bar.excludedScreens, screen.name)

    // Edge-aware: 0=Left, 1=Right (vertical bar), 2=Top, 3=Bottom (horizontal bar)
    readonly property bool isVertical: Config.bar.positioningEdge === 0 || Config.bar.positioningEdge === 1
    readonly property bool isRight: Config.bar.positioningEdge === 1
    readonly property bool isBottom: Config.bar.positioningEdge === 3
    // Fullscreen hides the bar unless the user opted into overlap
    readonly property bool hideForFullscreen: root.fullscreen && !Config.general.showOverFullscreen

    readonly property int clampedWidth: Math.max(Config.border.minThickness, implicitWidth)
    readonly property int padding: Math.max(Tokens.padding.small, Config.border.thickness)
    readonly property int contentWidth: Tokens.sizes.bar.innerWidth + padding * 2
    readonly property int exclusiveZone: {
        if (disabled || (!Config.bar.persistent && !visibilities.bar))
            return Config.border.thickness;
        return isVertical ? contentWidth : contentWidth;
    }
    readonly property bool shouldBeVisible: !hideForFullscreen && !disabled && (Config.bar.persistent || visibilities.bar || isHovered)

    // Drawer-style: content slides off while the blob frame shrinks
    property real slideProgress: root.shouldBeVisible ? 0 : 1

    property bool isHovered
    property bool keepActive: false

    function closeTray(): void {
        (content.item as Bar)?.closeTray();
    }

    function checkPopout(pos: real): void {
        (content.item as Bar)?.checkPopout(pos);
    }

    function handleWheel(pos: real, angleDelta: point): void {
        (content.item as Bar)?.handleWheel(pos, angleDelta);
    }

    visible: isVertical ? width > Config.border.thickness : height > Config.border.thickness
    implicitWidth: root.shouldBeVisible ? root.contentWidth : Config.border.thickness
    opacity: 1 - slideProgress

    // Slide content on/off screen (elements move with the bar)
    x: {
        if (!root.isVertical)
            return 0;
        const slide = (root.contentWidth + 5) * root.slideProgress;
        return root.isRight ? slide : -slide;
    }

    Behavior on slideProgress {
        Anim {}
    }

    Behavior on implicitWidth {
        Anim {}
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: root.isRight ? parent.right : undefined

        active: root.shouldBeVisible || root.keepActive

        sourceComponent: Bar {
            width: root.contentWidth
            screen: root.screen
            visibilities: root.visibilities
            popouts: root.popouts // qmllint disable incompatible-type
            fullscreen: root.fullscreen
        }
    }

    onShouldBeVisibleChanged: {
        if (!shouldBeVisible && visible) {
            keepActive = true;
            slideProgress = 1;
        } else if (shouldBeVisible) {
            slideProgress = 0;
        }
    }
}
