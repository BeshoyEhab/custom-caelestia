pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Caelestia.Config
import qs.components
import qs.services
import "ClockColours.js" as ClockColours

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
    // Digital clock: text sits directly on the wallpaper, so light themes need
    // the container tones to stay readable. This keeps the existing behaviour.
    readonly property bool useLightSet: Colours.light ? !invertColors : invertColors
    readonly property color safePrimary: useLightSet ? Colours.palette.m3primaryContainer : Colours.palette.m3primary
    readonly property color safeSecondary: useLightSet ? Colours.palette.m3secondaryContainer : Colours.palette.m3secondary
    readonly property color safeTertiary: useLightSet ? Colours.palette.m3tertiaryContainer : Colours.palette.m3tertiary

    // Cookie clock: the face is a large surface, so Material 3 gives it the
    // container role (a muted tonal version of the accent). The vivid accent is
    // reserved for the hands, and a mid-tone mix for the digits. Using m3primary
    // itself for the face made the clock a giant copy of the shell accent, which
    // is exactly what it should differ from. Mirrors end-4's CookieClock:
    // face = primaryContainer, hands = primary/tertiary, dial = container tinted
    // with secondary, digits = primary/container mix.
    readonly property bool containerFace: !invertColors
    readonly property color faceColor: containerFace ? Colours.palette.m3primaryContainer : Colours.palette.m3primary
    readonly property color onFaceColor: containerFace ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onPrimary
    readonly property color dialColor: containerFace ? ClockColours.mix(Colours.palette.m3secondary, Colours.palette.m3primaryContainer, 0.15) : Colours.palette.m3onPrimary
    readonly property color digitColor: containerFace ? ClockColours.mix(Colours.palette.m3primary, Colours.palette.m3primaryContainer, 0.55) : Colours.palette.m3onPrimary
    readonly property color hourColor: containerFace ? Colours.palette.m3primary : Colours.palette.m3onPrimary
    readonly property color minuteColor: containerFace ? Colours.palette.m3tertiary : Colours.palette.m3onPrimary
    readonly property color secondColor: containerFace ? Colours.palette.m3primary : Colours.palette.m3onPrimary
    readonly property color captionColor: Colours.palette.m3onSurface
    // The quote sits on a surface plate, like the reference widget; without the
    // plate it is plain onSurface text over the wallpaper. onSecondaryContainer
    // is too muted once the 70% plate blends with a light wallpaper, so use the
    // onSurface pair for legibility at any opacity.
    readonly property color quoteColor: Colours.palette.m3onSurface

    // Date badges choose themselves: the first pair that reads against the
    // face, avoiding the other badge's background. Falls back to an inverted
    // chip when the scheme has no legible container pair.
    readonly property var dayBadge: ClockColours.pickBadge(faceColor, onFaceColor, [
        { background: Colours.palette.m3tertiaryContainer, foreground: Colours.palette.m3onTertiaryContainer },
        { background: Colours.palette.m3secondaryContainer, foreground: Colours.palette.m3onSecondaryContainer },
        { background: Colours.palette.m3tertiary, foreground: Colours.palette.m3onTertiary },
        { background: Colours.palette.m3secondary, foreground: Colours.palette.m3onSecondary },
        { background: Colours.palette.m3primaryContainer, foreground: Colours.palette.m3onPrimaryContainer },
        { background: Colours.palette.m3surfaceContainerHigh, foreground: Colours.palette.m3onSurface }
    ], [], 3, 4.5)
    readonly property var monthBadge: ClockColours.pickBadge(faceColor, onFaceColor, [
        { background: Colours.palette.m3secondaryContainer, foreground: Colours.palette.m3onSecondaryContainer },
        { background: Colours.palette.m3tertiaryContainer, foreground: Colours.palette.m3onTertiaryContainer },
        { background: Colours.palette.m3secondary, foreground: Colours.palette.m3onSecondary },
        { background: Colours.palette.m3tertiary, foreground: Colours.palette.m3onTertiary },
        { background: Colours.palette.m3primaryContainer, foreground: Colours.palette.m3onPrimaryContainer },
        { background: Colours.palette.m3surfaceContainerHigh, foreground: Colours.palette.m3onSurface }
    ], [dayBadge.background], 3, 4.5)

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
    // The cookie face is already the whole body, so it needs no body padding;
    // the extra bottom padding pushed the quote plate away from it.
    readonly property real bodyHeight: root.bodyContentHeight + (root.isCookie ? 0 : Tokens.padding.extraLargeIncreased * root.clockScale)

    // Quote plate: when the backdrop is on, the quote gets the same surface as
    // the clock plate instead of floating on the wallpaper. The padding only
    // exists when the plate is visible, so the no-plate layout is unchanged.
    readonly property real quoteGap: Tokens.spacing.small * root.clockScale
    readonly property real quotePad: root.bgEnabled ? Tokens.padding.large * root.clockScale : 0
    readonly property real quotePlateY: root.bodyHeight + (root.quoteVisible ? root.quoteGap : 0)
    readonly property real quotePlateWidth: Math.min(root.bodyWidth, quote.implicitWidth + root.quotePad * 2)
    readonly property real quotePlateHeight: quote.implicitHeight + root.quotePad * 2
    readonly property real quoteY: root.quotePlateY + root.quotePad
    readonly property bool quotePlateVisible: root.quoteVisible && root.bgEnabled
    readonly property bool quoteBlurActive: root.quotePlateVisible && Config.background.desktopClock.background.blur && !GameMode.enabled

    implicitWidth: root.bodyWidth
    implicitHeight: root.bodyHeight + (root.quoteVisible ? root.quoteGap + quote.implicitHeight + root.quotePad * 2 : 0)

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

    Loader {
        id: quoteBlurLoader

        asynchronous: true
        x: quotePlate.x
        y: quotePlate.y
        width: quotePlate.width
        height: quotePlate.height
        active: root.quoteBlurActive

        sourceComponent: MultiEffect {
            source: ShaderEffectSource {
                sourceItem: root.wallpaper
                sourceRect: Qt.rect(root.absX + quotePlate.x, root.absY + quotePlate.y, quotePlate.width, quotePlate.height)
            }
            maskSource: quotePlate
            maskEnabled: true
            blurEnabled: true
            blur: 1
            blurMax: 64
            autoPaddingEnabled: false
        }
    }

    StyledRect {
        id: quotePlate

        visible: root.quotePlateVisible
        x: (root.bodyWidth - root.quotePlateWidth) / 2
        y: root.quotePlateY
        width: root.quotePlateWidth
        height: root.quotePlateHeight
        radius: Tokens.rounding.extraLarge * root.clockScale
        opacity: Config.background.desktopClock.background.opacity
        color: Colours.palette.m3surfaceContainerHigh

        layer.enabled: root.quoteBlurActive
    }

    StyledText {
        id: quote

        visible: root.quoteVisible
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.quoteY
        width: root.bodyWidth
        text: root.quoteText
        color: root.quoteColor
        font: Tokens.font.body.large
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
            textColor: root.captionColor
            vertical: root.isVertical
            dateAlignment: root.dateAlignment
        }
    }

    Component {
        id: cookieComponent

        CookieClock {
            clockScale: root.clockScale
            faceColor: root.faceColor
            onFaceColor: root.onFaceColor
            dialColor: root.dialColor
            digitColor: root.digitColor
            hourColor: root.hourColor
            minuteColor: root.minuteColor
            secondColor: root.secondColor
            dayBadgeColor: root.dayBadge.background
            onDayBadgeColor: root.dayBadge.foreground
            monthBadgeColor: root.monthBadge.background
            onMonthBadgeColor: root.monthBadge.foreground
            captionColor: root.captionColor
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
