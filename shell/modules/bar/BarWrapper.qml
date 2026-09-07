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
    readonly property bool isVertical: GlobalConfig.bar.positioningEdge === 0 || GlobalConfig.bar.positioningEdge === 1
    readonly property bool isRight: GlobalConfig.bar.positioningEdge === 1
    readonly property bool isBottom: GlobalConfig.bar.positioningEdge === 3
    // Fullscreen hides the bar unless the user opted into overlap
    readonly property bool hideForFullscreen: root.fullscreen && !Config.general.showOverFullscreen

    readonly property int clampedWidth: Math.max(Config.border.minThickness, implicitWidth)
    readonly property int clampedHeight: Math.max(Config.border.minThickness, implicitHeight)
    readonly property int padding: Math.max(Tokens.padding.small, Config.border.thickness)
    readonly property int contentWidth: Tokens.sizes.bar.innerWidth + padding * 2
    readonly property int contentHeight: Tokens.sizes.bar.innerWidth + padding * 2
    readonly property int exclusiveZone: {
        if (disabled || (!Config.bar.persistent && !visibilities.bar))
            return Config.border.thickness;
        return isVertical ? contentWidth : contentHeight;
    }
    readonly property bool shouldBeVisible: !hideForFullscreen && !disabled && (Config.bar.persistent || visibilities.bar || isHovered)

    property bool isHovered

    function closeTray(): void {
        (content.item as Bar)?.closeTray();
    }

    function checkPopout(pos: real): void {
        (content.item as Bar)?.checkPopout(pos);
    }

    function handleWheel(pos: real, angleDelta: point): void {
        (content.item as Bar)?.handleWheel(pos, angleDelta);
    }

    // Drawer-style: the blob frame shrinks while the content — anchored to the
    // inner edge (opposite the screen edge) — slides off-screen underneath it.
    // clip is essential: without it the shrinking frame doesn't crop the content
    // and the hide would only be visible as a fade/pop. No opacity fade here:
    // drawers hide by sliding, matching dashboard/osd/launcher/sidebar.
    clip: true
    visible: isVertical ? width > Config.border.thickness : height > Config.border.thickness
    implicitWidth: root.isVertical ? (root.shouldBeVisible ? root.contentWidth : Config.border.thickness) : 0
    implicitHeight: root.isVertical ? 0 : (root.shouldBeVisible ? root.contentHeight : Config.border.thickness)

    Behavior on implicitWidth {
        Anim {}
    }

    Behavior on implicitHeight {
        Anim {}
    }

    Loader {
        id: content

        // Inner-edge anchoring drags the content off-screen as the wrapper
        // shrinks: left bar → right-anchored, right bar → left-anchored,
        // top bar → bottom-anchored, bottom bar → top-anchored.
        anchors.top: root.isVertical ? parent.top : (root.isBottom ? parent.top : undefined)
        anchors.bottom: root.isVertical ? parent.bottom : (root.isBottom ? undefined : parent.bottom)
        anchors.left: root.isVertical ? (root.isRight ? parent.left : undefined) : parent.left
        anchors.right: root.isVertical ? (root.isRight ? undefined : parent.right) : parent.right

        // Stay active while the shrink/slide animation runs (visible is still
        // true), same pattern as the other drawer wrappers.
        active: root.shouldBeVisible || root.visible

        sourceComponent: Bar {
            width: root.contentWidth
            screen: root.screen
            visibilities: root.visibilities
            popouts: root.popouts // qmllint disable incompatible-type
            fullscreen: root.fullscreen
        }
    }
}
