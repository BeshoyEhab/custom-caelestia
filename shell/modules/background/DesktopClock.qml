pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property Item wallpaper
    required property real absX
    required property real absY

    property real clockScale: Config.background.desktopClock.scale
    readonly property bool bgEnabled: Config.background.desktopClock.background.enabled
    readonly property bool blurEnabled: bgEnabled && Config.background.desktopClock.background.blur && !GameMode.enabled
    readonly property bool invertColors: Config.background.desktopClock.invertColors
    readonly property bool useLightSet: Colours.light ? !invertColors : invertColors
    readonly property color safePrimary: useLightSet ? Colours.palette.m3primaryContainer : Colours.palette.m3primary
    readonly property color safeSecondary: useLightSet ? Colours.palette.m3secondaryContainer : Colours.palette.m3secondary
    readonly property color safeTertiary: useLightSet ? Colours.palette.m3tertiaryContainer : Colours.palette.m3tertiary
    readonly property color colText: useLightSet ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onPrimary

    // Vertical mode: explicit setting, or the left/right edge presets when
    // orientation is "auto". The preset keys are middle-left, bottom-right,
    // etc., so compare suffixes.
    readonly property bool isVertical: {
        const orientation = Config.background.desktopClock.digital.orientation;
        if (orientation === "vertical")
            return true;
        if (orientation === "horizontal")
            return false;
        const pos = Config.background.desktopClock.position;
        return pos.endsWith("left") || pos.endsWith("right");
    }

    // The date column aligns to the clock's screen third when adaptive
    // alignment is on.
    readonly property int dateAlignment: {
        if (!root.wallpaper || root.wallpaper.width <= 0)
            return Text.AlignHCenter;
        const center = root.absX + root.width / 2;
        if (center < root.wallpaper.width / 3)
            return Text.AlignLeft;
        if (center > root.wallpaper.width * 2 / 3)
            return Text.AlignRight;
        return Text.AlignHCenter;
    }

    // Classical analog face instead of the digital layouts
    readonly property bool isAnalog: Config.background.desktopClock.clockStyle === "analog"
    readonly property real analogDiameter: 300 * root.clockScale

    implicitWidth: root.isAnalog ? root.analogDiameter + (Tokens.padding.large * 4 * root.clockScale) : digitalClock.contentWidth + (Tokens.padding.large * 4 * root.clockScale)
    implicitHeight: root.isAnalog ? root.analogDiameter + (Tokens.padding.extraLargeIncreased * root.clockScale) : digitalClock.contentHeight + (Tokens.padding.extraLargeIncreased * root.clockScale)

    Item {
        id: clockContainer

        anchors.fill: parent

        layer.enabled: Config.background.desktopClock.shadow.enabled && !root.isAnalog
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Colours.palette.m3shadow
            shadowOpacity: Config.background.desktopClock.shadow.opacity
            shadowBlur: Config.background.desktopClock.shadow.blur
        }

        Loader {
            asynchronous: true
            anchors.fill: parent
            active: root.blurEnabled && !root.isAnalog

            sourceComponent: MultiEffect {
                source: ShaderEffectSource {
                    sourceItem: root.wallpaper
                    sourceRect: Qt.rect(root.absX, root.absY, root.width, root.height)
                }
                maskSource: backgroundPlate
                maskEnabled: true
                blurEnabled: true
                blur: 1
                blurMax: 64
                autoPaddingEnabled: false
            }
        }

        StyledRect {
            id: backgroundPlate

            visible: root.bgEnabled && !root.isAnalog
            anchors.fill: parent
            radius: Tokens.rounding.extraLarge * root.clockScale
            opacity: Config.background.desktopClock.background.opacity
            color: Colours.palette.m3surface

            layer.enabled: root.blurEnabled
        }

        DigitalClock {
            id: digitalClock

            visible: !root.isAnalog
            anchors.centerIn: parent

            clockScale: root.clockScale
            primaryColor: root.safePrimary
            secondaryColor: root.safeSecondary
            tertiaryColor: root.safeTertiary
            textColor: root.colText
            vertical: root.isVertical
            dateAlignment: root.dateAlignment
        }

        // Classical analog face
        AnalogClock {
            visible: root.isAnalog

            anchors.centerIn: parent
            width: root.analogDiameter
            height: root.analogDiameter

            clockScale: root.clockScale
            faceColor: Colours.palette.m3surfaceContainerHigh
            tickColor: Colours.palette.m3onSurfaceVariant
            handColor: root.safePrimary
            secondColor: root.safeTertiary
        }
    }

    Behavior on clockScale {
        Anim {}
    }

    Behavior on implicitWidth {
        Anim {
            type: Anim.StandardSmall
        }
    }

    Behavior on implicitHeight {
        Anim {
            type: Anim.StandardSmall
        }
    }
}
