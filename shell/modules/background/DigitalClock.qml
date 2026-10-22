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

    readonly property bool showDate: Config.background.desktopClock.digital.showDate
    readonly property bool showSeconds: Config.background.desktopClock.digital.showSeconds
    readonly property bool animateChange: Config.background.desktopClock.digital.animateChange
    readonly property bool adaptive: Config.background.desktopClock.digital.adaptiveAlignment
    readonly property real contentWidth: root.vertical ? verticalLayout.implicitWidth : horizontalLayout.implicitWidth
    readonly property real contentHeight: root.vertical ? verticalLayout.implicitHeight : horizontalLayout.implicitHeight

    implicitWidth: contentWidth
    implicitHeight: contentHeight

    function clockFont(pointSize, weight, spacing) {
        const f = Config.background.desktopClock.digital.font;
        let b = Tokens.font.clock.size(pointSize * root.clockScale * f.size);
        if (weight > 0)
            b = b.weight(weight);
        if (f.family.length > 0)
            b = b.family(f.family);
        return b.vaxes({ "wdth": f.width, "ROND": f.roundness }).letterSpacing(spacing).build();
    }

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
                font: root.clockFont(Tokens.font.headline.medium.pointSize * 3, Config.background.desktopClock.digital.font.weight, 0)
                color: root.primaryColor
                animate: root.animateChange
                Layout.fillWidth: false
            }

            ClockText {
                text: ":"
                font: root.clockFont(Tokens.font.headline.medium.pointSize * 3, 0, 0)
                color: root.tertiaryColor
                opacity: 0.8
                animate: root.animateChange
                Layout.topMargin: -Tokens.padding.large * 1.5 * root.clockScale
                Layout.fillWidth: false
            }

            ClockText {
                text: Time.minuteStr
                font: root.clockFont(Tokens.font.headline.medium.pointSize * 3, Config.background.desktopClock.digital.font.weight, 0)
                color: root.secondaryColor
                animate: root.animateChange
                Layout.fillWidth: false
            }

            ClockText {
                visible: root.showSeconds
                text: Time.secondsStr
                font: root.clockFont(Tokens.font.headline.medium.pointSize * 3 * 0.35, 0, 0)
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
                    font: root.clockFont(Tokens.font.title.medium.pointSize, 0, 0)
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
                text: Time.format("MMMM").toUpperCase()
                font: Tokens.font.clock.size(Tokens.font.title.medium.pointSize * root.clockScale).letterSpacing(4).weight(Font.Bold).build()
                color: root.secondaryColor
                animate: root.animateChange
                horizontalAlignment: root.adaptive ? root.dateAlignment : Text.AlignLeft
                Layout.fillWidth: true
            }

            ClockText {
                text: Time.format("dd")
                font: Tokens.font.clock.size(Tokens.font.headline.medium.pointSize * root.clockScale).letterSpacing(2).weight(Font.Medium).build()
                color: root.primaryColor
                animate: root.animateChange
                horizontalAlignment: root.adaptive ? root.dateAlignment : Text.AlignLeft
                Layout.fillWidth: true
            }

            ClockText {
                text: Time.format("dddd")
                font: Tokens.font.clock.size(Tokens.font.body.large.pointSize * root.clockScale).letterSpacing(2).build()
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
            font: root.clockFont(Tokens.font.headline.medium.pointSize * 3, Config.background.desktopClock.digital.font.weight, 0)
            color: root.primaryColor
            animate: root.animateChange
            horizontalAlignment: root.adaptive ? root.dateAlignment : Text.AlignHCenter
            Layout.fillWidth: true
        }

        ClockText {
            text: Time.minuteStr
            font: root.clockFont(Tokens.font.headline.medium.pointSize * 3, Config.background.desktopClock.digital.font.weight, 0)
            color: root.secondaryColor
            animate: root.animateChange
            horizontalAlignment: root.adaptive ? root.dateAlignment : Text.AlignHCenter
            Layout.topMargin: -Tokens.padding.large * root.clockScale
            Layout.fillWidth: true
        }

        ClockText {
            visible: root.showSeconds
            text: Time.secondsStr
            font: root.clockFont(Tokens.font.headline.medium.pointSize * 3 * 0.35, 0, 0)
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
                font: root.clockFont(Tokens.font.title.medium.pointSize, 0, 0)
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
            text: Time.format("MMM dd").toUpperCase()
            font: Tokens.font.clock.size(Tokens.font.title.medium.pointSize * root.clockScale).letterSpacing(2).weight(Font.Bold).build()
            color: root.secondaryColor
            animate: root.animateChange
            horizontalAlignment: root.adaptive ? root.dateAlignment : Text.AlignHCenter
            Layout.fillWidth: true
        }

        ClockText {
            visible: root.showDate
            text: Time.format("dddd")
            font: Tokens.font.clock.size(Tokens.font.body.large.pointSize * root.clockScale).letterSpacing(1).build()
            color: root.tertiaryColor
            animate: root.animateChange
            horizontalAlignment: root.adaptive ? root.dateAlignment : Text.AlignHCenter
            Layout.fillWidth: true
        }
    }
}
