pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property real clockScale
    required property color primaryColor
    required property color secondaryColor
    required property color tertiaryColor
    required property color textColor

    readonly property bool invertColors: Config.background.desktopClock.invertColors
    readonly property bool useLightSet: Colours.light ? !invertColors : invertColors
    readonly property color faceColor: root.primaryColor
    readonly property color onFaceColor: useLightSet ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onPrimary
    readonly property color hourColor: useLightSet ? Colours.palette.m3primary : Colours.palette.m3primaryContainer
    readonly property color minuteColor: useLightSet ? Colours.palette.m3tertiary : Colours.palette.m3tertiaryContainer
    readonly property color secondColor: root.hourColor

    readonly property real faceSize: 230 * root.clockScale
    readonly property real k: root.faceSize / 230
    readonly property string dialStyle: Config.background.desktopClock.cookie.dialNumberStyle
    readonly property bool hourMarks: Config.background.desktopClock.cookie.hourMarks && (dialStyle === "dots" || dialStyle === "full")
    readonly property bool dateInClock: Config.background.desktopClock.cookie.dateInClock
    readonly property real dateSpacing: Tokens.spacing.large * root.clockScale

    readonly property real dateWidth: date.implicitWidth
    readonly property real contentWidth: Math.max(root.faceSize, root.dateWidth)
    readonly property real contentHeight: root.faceSize + (root.dateInClock ? 0 : (date.dateHeight > 0 ? date.dateHeight + root.dateSpacing : 0))

    implicitWidth: contentWidth
    implicitHeight: contentHeight

    Item {
        id: body

        width: root.faceSize
        height: root.faceSize
        anchors.horizontalCenter: parent.horizontalCenter

        CookieFace {
            anchors.fill: parent
            size: root.faceSize
            sides: Config.background.desktopClock.cookie.sides
            sine: Config.background.desktopClock.cookie.useSineCookie
            constantlyRotate: Config.background.desktopClock.cookie.constantlyRotate
            color: root.faceColor
        }

        CookieDial {
            anchors.fill: parent
            size: root.faceSize
            dialStyle: root.dialStyle
            hourMarks: root.hourMarks
            color: root.onFaceColor
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: -16 * root.k
            visible: Config.background.desktopClock.cookie.timeIndicators && root.dialStyle !== "numbers"

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Time.hourStr.padStart(2, "0")
                color: root.onFaceColor
                font.family: Tokens.font.clock.family
                font.pixelSize: (root.hourMarks ? 40 : 68) * root.k
                font.weight: Font.Bold
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Time.minuteStr.padStart(2, "0")
                color: root.onFaceColor
                font.family: Tokens.font.clock.family
                font.pixelSize: (root.hourMarks ? 40 : 68) * root.k
                font.weight: Font.Bold
            }

            Loader {
                Layout.alignment: Qt.AlignHCenter
                active: GlobalConfig.services.useTwelveHourClock
                visible: active

                sourceComponent: StyledText {
                    text: Time.amPmStr
                    color: root.onFaceColor
                    font.family: Tokens.font.clock.family
                    font.pixelSize: (root.hourMarks ? 20 : 26) * root.k
                    font.weight: Font.Bold
                }
            }
        }

        CookieHands {
            anchors.fill: parent
            size: root.faceSize
            hour: Time.hours % 12
            minute: Time.minutes
            second: Time.seconds
            hourStyle: Config.background.desktopClock.cookie.hourHandStyle
            minuteStyle: Config.background.desktopClock.cookie.minuteHandStyle
            secondStyle: Config.background.desktopClock.cookie.secondHandStyle
            hourColor: root.hourColor
            minuteColor: root.minuteColor
            secondColor: root.secondColor
            faceColor: root.faceColor
        }
    }

    CookieDate {
        id: date

        x: (root.contentWidth - root.dateWidth) / 2
        y: root.dateInClock ? 0 : root.faceSize + root.dateSpacing
        width: root.dateWidth
        height: root.dateInClock ? root.faceSize : date.dateHeight
        size: root.faceSize
        style: Config.background.desktopClock.cookie.dateStyle
        inClock: root.dateInClock
        primaryColor: root.tertiaryColor
        secondaryColor: root.secondaryColor
        textColor: root.onFaceColor
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
