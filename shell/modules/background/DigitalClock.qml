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
    required property bool vertical
    required property int dateAlignment

    readonly property var digitalFont: Config.background.desktopClock.digital.font
    readonly property bool showDate: Config.background.desktopClock.digital.showDate
    readonly property bool showSeconds: Config.background.desktopClock.digital.showSeconds
    readonly property bool animateChange: Config.background.desktopClock.digital.animateChange
    readonly property bool adaptive: Config.background.desktopClock.digital.adaptiveAlignment
    readonly property real contentWidth: root.vertical ? verticalLayout.implicitWidth : horizontalLayout.implicitWidth
    readonly property real contentHeight: root.vertical ? verticalLayout.implicitHeight : horizontalLayout.implicitHeight

    implicitWidth: contentWidth
    implicitHeight: contentHeight

    RowLayout {
        id: horizontalLayout

        visible: !root.vertical
        anchors.centerIn: parent
        spacing: Tokens.spacing.large * root.clockScale

        RowLayout {
            id: timeGroup

            spacing: Tokens.spacing.small

            ClockText {
                text: Time.hourStr
                pointSize: Tokens.font.headline.medium.pointSize * 3
                scale: root.clockScale
                fontSettings: root.digitalFont
                weight: root.digitalFont.weight
                color: root.primaryColor
                animate: root.animateChange
                Layout.fillWidth: false
            }

            ClockText {
                text: ":"
                pointSize: Tokens.font.headline.medium.pointSize * 3
                scale: root.clockScale
                fontSettings: root.digitalFont
                color: root.tertiaryColor
                opacity: 0.8
                animate: root.animateChange
                Layout.topMargin: -Tokens.padding.large * 1.5 * root.clockScale
                Layout.fillWidth: false
            }

            ClockText {
                text: Time.minuteStr
                pointSize: Tokens.font.headline.medium.pointSize * 3
                scale: root.clockScale
                fontSettings: root.digitalFont
                weight: root.digitalFont.weight
                color: root.secondaryColor
                animate: root.animateChange
                Layout.fillWidth: false
            }

            ClockText {
                visible: root.showSeconds
                text: Time.secondsStr
                pointSize: Tokens.font.headline.medium.pointSize * 3 * 0.35
                scale: root.clockScale
                fontSettings: root.digitalFont
                color: root.secondaryColor
                animate: root.animateChange
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: Tokens.padding.large * 0.5 * root.clockScale
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
                    pointSize: Tokens.font.title.medium.pointSize
                    scale: root.clockScale
                    fontSettings: root.digitalFont
                    color: root.secondaryColor
                    animate: root.animateChange
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
            color: root.primaryColor
            opacity: 0.8
        }

        ColumnLayout {
            id: dateLayout

            visible: root.showDate
            Layout.preferredWidth: root.adaptive ? timeGroup.implicitWidth : -1
            spacing: 0

            ClockText {
                dateFormat: "MMMM"
                uppercaseDate: true
                pointSize: Tokens.font.title.medium.pointSize
                scale: root.clockScale
                weight: Font.Bold
                letterSpacing: 4
                color: root.secondaryColor
                animate: root.animateChange
                horizontalAlignment: root.adaptive ? root.dateAlignment : Text.AlignLeft
                Layout.fillWidth: true
            }

            ClockText {
                dateFormat: "dd"
                pointSize: Tokens.font.headline.medium.pointSize
                scale: root.clockScale
                weight: Font.Medium
                letterSpacing: 2
                color: root.primaryColor
                animate: root.animateChange
                horizontalAlignment: root.adaptive ? root.dateAlignment : Text.AlignLeft
                Layout.fillWidth: true
            }

            ClockText {
                dateFormat: "dddd"
                pointSize: Tokens.font.body.large.pointSize
                scale: root.clockScale
                letterSpacing: 2
                color: root.secondaryColor
                animate: root.animateChange
                horizontalAlignment: root.adaptive ? root.dateAlignment : Text.AlignLeft
                Layout.fillWidth: true
            }
        }
    }

    ColumnLayout {
        id: verticalLayout

        visible: root.vertical
        anchors.centerIn: parent
        spacing: Tokens.spacing.small * root.clockScale

        ClockText {
            text: Time.hourStr
            pointSize: Tokens.font.headline.medium.pointSize * 3
            scale: root.clockScale
            fontSettings: root.digitalFont
            weight: root.digitalFont.weight
            color: root.primaryColor
            animate: root.animateChange
            horizontalAlignment: root.adaptive ? root.dateAlignment : Text.AlignHCenter
            Layout.fillWidth: true
        }

        ClockText {
            text: Time.minuteStr
            pointSize: Tokens.font.headline.medium.pointSize * 3
            scale: root.clockScale
            fontSettings: root.digitalFont
            weight: root.digitalFont.weight
            color: root.secondaryColor
            animate: root.animateChange
            horizontalAlignment: root.adaptive ? root.dateAlignment : Text.AlignHCenter
            Layout.topMargin: -Tokens.padding.large * root.clockScale
            Layout.fillWidth: true
        }

        ClockText {
            visible: root.showSeconds
            text: Time.secondsStr
            pointSize: Tokens.font.headline.medium.pointSize * 3 * 0.35
            scale: root.clockScale
            fontSettings: root.digitalFont
            color: root.secondaryColor
            animate: root.animateChange
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }

        Loader {
            asynchronous: true
            active: GlobalConfig.services.useTwelveHourClock
            visible: active
            Layout.alignment: Qt.AlignHCenter

            sourceComponent: ClockText {
                text: Time.amPmStr
                pointSize: Tokens.font.title.medium.pointSize
                scale: root.clockScale
                fontSettings: root.digitalFont
                color: root.secondaryColor
                animate: root.animateChange
                horizontalAlignment: Text.AlignHCenter
            }
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 4 * root.clockScale
            Layout.leftMargin: Tokens.spacing.large * root.clockScale
            Layout.rightMargin: Tokens.spacing.large * root.clockScale
            radius: Tokens.rounding.full
            color: root.primaryColor
            opacity: 0.8
        }

        ClockText {
            visible: root.showDate
            dateFormat: "MMM dd"
            uppercaseDate: true
            pointSize: Tokens.font.title.medium.pointSize
            scale: root.clockScale
            weight: Font.Bold
            letterSpacing: 2
            color: root.secondaryColor
            animate: root.animateChange
            horizontalAlignment: root.adaptive ? root.dateAlignment : Text.AlignHCenter
            Layout.fillWidth: true
        }

        ClockText {
            visible: root.showDate
            dateFormat: "dddd"
            pointSize: Tokens.font.body.large.pointSize
            scale: root.clockScale
            letterSpacing: 1
            color: root.tertiaryColor
            animate: root.animateChange
            horizontalAlignment: root.adaptive ? root.dateAlignment : Text.AlignHCenter
            Layout.fillWidth: true
        }
    }
}
