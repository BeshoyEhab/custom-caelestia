pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import M3Shapes
import Caelestia.Config
import qs.components
import qs.services
import ".."

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

    ClockText {
        visible: dayBubble.visible
        anchors.centerIn: dayBubble
        dateFormat: "d"
        pointSize: 30
        scale: root.k
        weight: Font.Black
        color: root.textColor
        raised: false
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

    ClockText {
        visible: monthBubble.visible
        anchors.centerIn: monthBubble
        dateFormat: "MM"
        pointSize: 20
        scale: root.k
        weight: Font.Black
        color: root.textColor
        raised: false
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

        ClockText {
            anchors.centerIn: parent
            dateFormat: "dd"
            pointSize: 20
            scale: root.k
            weight: 1000
            color: root.textColor
            raised: false
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

                ClockText {
                    id: borderCharText

                    text: borderDate.dateText.charAt(borderChar.index)
                    pointSize: 30
                    scale: root.k
                    color: root.textColor
                    raised: false
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

        ClockText {
            Layout.alignment: Qt.AlignHCenter
            dateFormat: "MMMM"
            uppercaseDate: true
            pointSize: Tokens.font.title.medium.pointSize
            scale: root.k
            weight: Font.Bold
            letterSpacing: 4
            color: root.textColor
            raised: false
        }

        ClockText {
            Layout.alignment: Qt.AlignHCenter
            dateFormat: "dd"
            pointSize: Tokens.font.headline.medium.pointSize
            scale: root.k
            weight: Font.Medium
            letterSpacing: 2
            color: root.textColor
            raised: false
        }

        ClockText {
            Layout.alignment: Qt.AlignHCenter
            dateFormat: "dddd"
            pointSize: Tokens.font.body.large.pointSize
            scale: root.k
            letterSpacing: 2
            color: root.textColor
            raised: false
        }
    }
}
