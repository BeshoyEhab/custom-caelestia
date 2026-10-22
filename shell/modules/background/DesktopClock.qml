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
    readonly property string clockStyle: Config.background.desktopClock.clockStyle
    readonly property bool isAnalog: clockStyle === "analog"
    readonly property bool isCookie: clockStyle === "cookie"
    readonly property bool isDigital: !isAnalog && !isCookie
    readonly property bool bgEnabled: Config.background.desktopClock.background.enabled
    readonly property bool blurEnabled: bgEnabled && Config.background.desktopClock.background.blur && !GameMode.enabled
    readonly property bool invertColors: Config.background.desktopClock.invertColors
    readonly property bool useLightSet: Colours.light ? !invertColors : invertColors
    readonly property color safePrimary: useLightSet ? Colours.palette.m3primaryContainer : Colours.palette.m3primary
    readonly property color safeSecondary: useLightSet ? Colours.palette.m3secondaryContainer : Colours.palette.m3secondary
    readonly property color safeTertiary: useLightSet ? Colours.palette.m3tertiaryContainer : Colours.palette.m3tertiary
    readonly property color colText: useLightSet ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onPrimary
    readonly property string quoteText: Config.background.desktopClock.quote.text
    readonly property bool quoteVisible: Config.background.desktopClock.quote.enabled && quoteText.length > 0

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

    readonly property real analogDiameter: 300 * root.clockScale
    readonly property real bodyContentWidth: root.isAnalog ? root.analogDiameter : (clockLoader.item?.contentWidth ?? 0)
    readonly property real bodyContentHeight: root.isAnalog ? root.analogDiameter : (clockLoader.item?.contentHeight ?? 0)
    readonly property real bodyWidth: root.bodyContentWidth + (Tokens.padding.large * 4 * root.clockScale)
    readonly property real bodyHeight: root.bodyContentHeight + (Tokens.padding.extraLargeIncreased * root.clockScale)

    implicitWidth: root.bodyWidth
    implicitHeight: root.bodyHeight + (root.quoteVisible ? Tokens.spacing.small * root.clockScale + quote.implicitHeight : 0)

    Item {
        id: clockContainer

        width: root.bodyWidth
        height: root.bodyHeight
        anchors.horizontalCenter: parent.horizontalCenter

        layer.enabled: Config.background.desktopClock.shadow.enabled && root.isDigital
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Colours.palette.m3shadow
            shadowOpacity: Config.background.desktopClock.shadow.opacity
            shadowBlur: Config.background.desktopClock.shadow.blur
        }

        Loader {
            id: blurLoader

            asynchronous: true
            anchors.fill: parent
            active: root.blurEnabled && root.isDigital

            sourceComponent: MultiEffect {
                source: ShaderEffectSource {
                    sourceItem: root.wallpaper
                    sourceRect: Qt.rect(root.absX + clockContainer.x, root.absY + clockContainer.y, clockContainer.width, clockContainer.height)
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

            visible: root.bgEnabled && root.isDigital
            anchors.fill: parent
            radius: Tokens.rounding.extraLarge * root.clockScale
            opacity: Config.background.desktopClock.background.opacity
            color: Colours.palette.m3surface

            layer.enabled: root.blurEnabled
        }

        Loader {
            id: clockLoader

            anchors.centerIn: parent
            sourceComponent: root.isAnalog ? analogComponent : root.isCookie ? cookieComponent : digitalComponent
        }
    }

    StyledText {
        id: quote

        visible: root.quoteVisible
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.bodyHeight + (root.quoteVisible ? Tokens.spacing.small * root.clockScale : 0)
        width: root.bodyWidth
        text: root.quoteText
        color: root.safeSecondary
        font: Tokens.font.body.medium
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        horizontalAlignment: Text.AlignHCenter
    }

    Component {
        id: digitalComponent

        DigitalClock {
            clockScale: root.clockScale
            primaryColor: root.safePrimary
            secondaryColor: root.safeSecondary
            tertiaryColor: root.safeTertiary
            textColor: root.colText
            vertical: root.isVertical
            dateAlignment: root.dateAlignment
        }
    }

    Component {
        id: cookieComponent

        CookieClock {
            clockScale: root.clockScale
            primaryColor: root.safePrimary
            secondaryColor: root.safeSecondary
            tertiaryColor: root.safeTertiary
            textColor: root.colText
        }
    }

    Component {
        id: analogComponent

        AnalogClock {
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
