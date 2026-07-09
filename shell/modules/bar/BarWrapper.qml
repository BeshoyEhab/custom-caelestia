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

    readonly property int clampedWidth: Math.max(Config.border.minThickness, implicitWidth)
    readonly property int padding: Math.max(Tokens.padding.small, Config.border.thickness)
    readonly property int contentWidth: Tokens.sizes.bar.innerWidth + padding * 2
    readonly property int exclusiveZone: {
        if (disabled || (!Config.bar.persistent && !visibilities.bar))
            return Config.border.thickness;
        return isVertical ? contentWidth : contentWidth;
    }
    readonly property bool shouldBeVisible: !fullscreen && !disabled && (Config.bar.persistent || visibilities.bar || isHovered)
    property bool isHovered

    // Keep loader active during hide animation so content stays visible
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

    clip: true
    visible: isVertical ? width > Config.border.thickness : height > Config.border.thickness
    implicitWidth: fullscreen ? 0 : Config.border.thickness

    states: State {
        name: "visible"
        when: root.shouldBeVisible

        PropertyChanges {
            root.implicitWidth: root.contentWidth
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: "implicitWidth"
            }
        },
        Transition {
            from: "visible"
            to: ""

            SequentialAnimation {
                Anim {
                    target: root
                    property: "implicitWidth"
                    type: Anim.Emphasized
                    duration: Tokens.anim.durations.normal * 1.5
                }
                ScriptAction {
                    script: root.keepActive = false
                }
            }
        }
    ]

    Loader {
        id: content

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: !root.isRight ? parent.left : undefined
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

    // Activate keepActive when leaving visible state
    onShouldBeVisibleChanged: {
        if (!shouldBeVisible && visible)
            keepActive = true;
    }
}
