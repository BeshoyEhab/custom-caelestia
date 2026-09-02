pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
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

    // Vertical mode when clock is on left or right edge
    readonly property bool isVertical: {
        const pos = Config.background.desktopClock.position;
        return pos === "left" || pos === "right";
    }

    implicitWidth: layout.implicitWidth + (Tokens.padding.large * 4 * root.clockScale)
    implicitHeight: layout.implicitHeight + (Tokens.padding.extraLargeIncreased * root.clockScale)

    Item {
        id: clockContainer

        anchors.fill: parent

        layer.enabled: Config.background.desktopClock.shadow.enabled
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Colours.palette.m3shadow
            shadowOpacity: Config.background.desktopClock.shadow.opacity
            shadowBlur: Config.background.desktopClock.shadow.blur
        }

        Loader {
            asynchronous: true
            anchors.fill: parent
            active: root.blurEnabled

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

            visible: root.bgEnabled
            anchors.fill: parent
            radius: Tokens.rounding.extraLarge * root.clockScale
            opacity: Config.background.desktopClock.background.opacity
            color: Colours.palette.m3surface

            layer.enabled: root.blurEnabled
        }

        // Horizontal mode (default)
        RowLayout {
            id: layout
            visible: !root.isVertical

            anchors.centerIn: parent
            spacing: Tokens.spacing.large * root.clockScale

            RowLayout {
                spacing: Tokens.spacing.small

                ClockText {
                    text: Time.hourStr
                    font: Tokens.font.clock.size(Tokens.font.headline.medium.pointSize * 3 * root.clockScale).weight(Font.Bold).build()
                    color: root.safePrimary
                    Layout.fillWidth: false
                }

                ClockText {
                    text: ":"
                    font: Tokens.font.clock.size(Tokens.font.headline.medium.pointSize * 3 * root.clockScale).build()
                    color: root.safeTertiary
                    opacity: 0.8
                    Layout.topMargin: -Tokens.padding.large * 1.5 * root.clockScale
                    Layout.fillWidth: false
                }

                ClockText {
                    text: Time.minuteStr
                    font: Tokens.font.clock.size(Tokens.font.headline.medium.pointSize * 3 * root.clockScale).weight(Font.Bold).build()
                    color: root.safeSecondary
                    Layout.fillWidth: false
                }

                Loader {
                    asynchronous: true
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: Tokens.padding.large * 1.4 * root.clockScale

                    active: GlobalConfig.services.useTwelveHourClock
                    visible: active

                    sourceComponent: ClockText {
                        text: Time.amPmStr
                        font: Tokens.font.clock.size(Tokens.font.title.medium.pointSize * root.clockScale).build()
                        color: root.safeSecondary
                        Layout.fillWidth: false
                    }
                }
            }

            StyledRect {
                Layout.fillHeight: true
                Layout.preferredWidth: 4 * root.clockScale
                Layout.topMargin: Tokens.spacing.large * root.clockScale
                Layout.bottomMargin: Tokens.spacing.large * root.clockScale
                radius: Tokens.rounding.full
                color: root.safePrimary
                opacity: 0.8
            }

            ColumnLayout {
                spacing: 0

                ClockText {
                    text: Time.format("MMMM").toUpperCase()
                    font: Tokens.font.clock.size(Tokens.font.title.medium.pointSize * root.clockScale).letterSpacing(4).weight(Font.Bold).build()
                    color: root.safeSecondary
                }

                ClockText {
                    text: Time.format("dd")
                    font: Tokens.font.clock.size(Tokens.font.headline.medium.pointSize * root.clockScale).letterSpacing(2).weight(Font.Medium).build()
                    color: root.safePrimary
                }

                ClockText {
                    text: Time.format("dddd")
                    font: Tokens.font.clock.size(Tokens.font.body.large.pointSize * root.clockScale).letterSpacing(2).build()
                    color: root.safeSecondary
                }
            }
        }

        // Vertical mode (for left/right positioned clocks)
        ColumnLayout {
            id: verticalLayout
            visible: root.isVertical

            anchors.centerIn: parent
            spacing: Tokens.spacing.small * root.clockScale

            ClockText {
                text: Time.hourStr
                font: Tokens.font.clock.size(Tokens.font.headline.medium.pointSize * 3 * root.clockScale).weight(Font.Bold).build()
                color: root.safePrimary
                horizontalAlignment: Text.AlignHCenter
            }

            ClockText {
                text: Time.minuteStr
                font: Tokens.font.clock.size(Tokens.font.headline.medium.pointSize * 3 * root.clockScale).weight(Font.Bold).build()
                color: root.safeSecondary
                horizontalAlignment: Text.AlignHCenter
                Layout.topMargin: -Tokens.padding.large * root.clockScale
            }

            Loader {
                asynchronous: true
                active: GlobalConfig.services.useTwelveHourClock
                visible: active

                sourceComponent: ClockText {
                    text: Time.amPmStr
                    font: Tokens.font.clock.size(Tokens.font.title.medium.pointSize * root.clockScale).build()
                    color: root.safeSecondary
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.preferredHeight: 4 * root.clockScale
                Layout.leftMargin: Tokens.spacing.large * root.clockScale
                Layout.rightMargin: Tokens.spacing.large * root.clockScale
                radius: Tokens.rounding.full
                color: root.safePrimary
                opacity: 0.8
            }

            ClockText {
                text: Time.format("MMM dd").toUpperCase()
                font: Tokens.font.clock.size(Tokens.font.title.medium.pointSize * root.clockScale).letterSpacing(2).weight(Font.Bold).build()
                color: root.safeSecondary
                horizontalAlignment: Text.AlignHCenter
            }

            ClockText {
                text: Time.format("dddd")
                font: Tokens.font.clock.size(Tokens.font.body.large.pointSize * root.clockScale).letterSpacing(1).build()
                color: root.safeTertiary
                horizontalAlignment: Text.AlignHCenter
            }
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
}
