pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import M3Shapes
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property real size
    required property string style
    required property bool inClock
    required property color primaryColor
    required property color secondaryColor
    required property color textColor

    readonly property real k: size / 230
    readonly property bool showInside: root.inClock && root.style !== "hide"
    readonly property bool showBelow: !root.inClock && root.style !== "hide"
    readonly property real dateHeight: root.showBelow ? belowColumn.implicitHeight : 0

    implicitWidth: Math.max(root.size, root.showBelow ? belowColumn.implicitWidth : 0)
    implicitHeight: root.inClock ? root.size : root.dateHeight

    MaterialShape {
        id: dayBubble

        visible: root.showInside && root.style === "bubble"
        anchors.left: parent.left
        anchors.top: parent.top
        implicitSize: 64 * root.k
        shape: MaterialShape.Cookie4Sided
        color: root.primaryColor
    }

    StyledText {
        visible: dayBubble.visible
        anchors.centerIn: dayBubble
        text: Time.format("d")
        color: root.textColor
        font.family: Tokens.font.clock.build().family
        font.pixelSize: 30 * root.k
        font.weight: Font.Black
    }

    MaterialShape {
        id: monthBubble

        visible: root.showInside && root.style === "bubble"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        implicitSize: 40 * root.k
        shape: MaterialShape.Pill
        color: root.secondaryColor
    }

    StyledText {
        visible: monthBubble.visible
        anchors.centerIn: monthBubble
        text: Time.format("MM")
        color: root.textColor
        font.family: Tokens.font.clock.build().family
        font.pixelSize: 20 * root.k
        font.weight: Font.Black
    }

    Rectangle {
        id: dateRect

        visible: root.showInside && root.style === "rect"
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 10 * root.k
        width: 45 * root.k
        height: 30 * root.k
        radius: Tokens.rounding.small * root.k
        color: root.secondaryColor

        StyledText {
            anchors.centerIn: parent
            text: Time.format("dd")
            color: root.textColor
            font.family: Tokens.font.clock.build().family
            font.pixelSize: 20 * root.k
            font.weight: 1000
        }
    }

    Item {
        id: borderDate

        visible: root.showInside && root.style === "border"
        anchors.fill: parent

        readonly property string dateText: Time.format("ddd dd")
        readonly property real angleStep: 12 * Math.PI / 180
        readonly property real radius: root.size * 0.39

        rotation: {
            if (Config.background.desktopClock.cookie.secondHandStyle === "hide")
                return 0;
            return 360 / 60 * Time.seconds + 180 - 6 * borderDate.dateText.length;
        }

        Repeater {
            model: borderDate.dateText.length

            Item {
                id: borderChar

                required property int index
                property real angle: borderChar.index * borderDate.angleStep - Math.PI / 2

                width: borderCharText.implicitWidth
                height: borderCharText.implicitHeight
                x: borderDate.width / 2 + borderDate.radius * Math.cos(borderChar.angle) - width / 2
                y: borderDate.height / 2 + borderDate.radius * Math.sin(borderChar.angle) - height / 2
                rotation: borderChar.angle * 180 / Math.PI + 90

                StyledText {
                    id: borderCharText

                    text: borderDate.dateText.charAt(borderChar.index)
                    color: root.textColor
                    font.family: Tokens.font.clock.build().family
                    font.pixelSize: 30 * root.k
                }
            }
        }
    }

    ColumnLayout {
        id: belowColumn

        visible: root.showBelow
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.format("MMMM").toUpperCase()
            color: root.textColor
            font: Tokens.font.clock.size(Tokens.font.title.medium.pointSize * root.k).letterSpacing(4).weight(Font.Bold).build()
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.format("dd")
            color: root.textColor
            font: Tokens.font.clock.size(Tokens.font.headline.medium.pointSize * root.k).letterSpacing(2).weight(Font.Medium).build()
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.format("dddd")
            color: root.textColor
            font: Tokens.font.clock.size(Tokens.font.body.large.pointSize * root.k).letterSpacing(2).build()
        }
    }
}
