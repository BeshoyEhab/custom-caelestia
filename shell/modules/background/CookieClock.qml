pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import "cookie"

Item {
    id: root

    required property real clockScale
    required property color faceColor
    required property color onFaceColor
    // Layered roles, chosen by DesktopClock: the dial is a subtle container
    // tint, the digits a mid-tone mix, and the hands carry the vivid accents.
    required property color dialColor
    required property color digitColor
    required property color hourColor
    required property color minuteColor
    required property color secondColor
    required property color dayBadgeColor
    required property color onDayBadgeColor
    required property color monthBadgeColor
    required property color onMonthBadgeColor
    required property color captionColor

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
            color: root.dialColor
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: -16 * root.k
            visible: Config.background.desktopClock.cookie.timeIndicators && root.dialStyle !== "numbers"

            ClockText {
                Layout.alignment: Qt.AlignHCenter
                text: Time.hourStr.padStart(2, "0")
                pointSize: root.hourMarks ? 40 : 68
                scale: root.k
                weight: Font.Bold
                color: root.digitColor
                raised: false
            }

            ClockText {
                Layout.alignment: Qt.AlignHCenter
                text: Time.minuteStr.padStart(2, "0")
                pointSize: root.hourMarks ? 40 : 68
                scale: root.k
                weight: Font.Bold
                color: root.digitColor
                raised: false
            }

            Loader {
                Layout.alignment: Qt.AlignHCenter
                active: GlobalConfig.services.useTwelveHourClock
                visible: active

                sourceComponent: ClockText {
                    text: Time.amPmStr
                    pointSize: root.hourMarks ? 20 : 26
                    scale: root.k
                    weight: Font.Bold
                    color: root.digitColor
                    raised: false
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
        dayBubbleColor: root.dayBadgeColor
        onDayBubbleColor: root.onDayBadgeColor
        monthBubbleColor: root.monthBadgeColor
        onMonthBubbleColor: root.onMonthBadgeColor
        textColor: root.onFaceColor
        captionColor: root.captionColor
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
