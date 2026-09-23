import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Classical analog face: M3-tinted, driven by the Time service. Minute and
// hour hands re-evaluate every second (via the Time.seconds read) so motion
// stays correct without waiting for the minute boundary.
Item {
    id: root

    required property real clockScale
    required property color faceColor
    required property color tickColor
    required property color handColor
    required property color secondColor

    // Second ticks depend on Time.seconds so all hands stay live. Angles
    // use wall time (not Time.date, which is minute-aligned and would freeze
    // the second hand at :00).
    readonly property real secondAngle: {
        Time.seconds;
        return (new Date().getSeconds() % 60) * 6;
    }
    readonly property real minuteAngle: {
        Time.seconds;
        const d = new Date();
        return d.getMinutes() * 6 + d.getSeconds() * 0.1;
    }
    readonly property real hourAngle: {
        Time.seconds;
        const d = new Date();
        return (d.getHours() % 12) * 30 + d.getMinutes() * 0.5;
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.faceColor
        border.color: root.tickColor
        border.width: Math.max(1, 1.5 * root.clockScale)
        opacity: 0.92
    }

    Repeater {
        model: 60

        Item {
            required property int index

            readonly property bool isHour: index % 5 === 0

            anchors.fill: parent
            rotation: index * 6

            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 14 * root.clockScale
                anchors.horizontalCenter: parent.horizontalCenter
                width: (isHour ? 5 : 2) * root.clockScale
                height: (isHour ? 20 : 9) * root.clockScale
                radius: width / 2
                color: isHour ? root.tickColor : root.tickColor
                opacity: isHour ? 1 : 0.45
            }
        }
    }

    // Hands: full-face items rotated about the center, rects in top half.
    Item {
        anchors.fill: parent
        rotation: root.hourAngle

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.verticalCenter
            anchors.bottomMargin: -8 * root.clockScale
            width: 9 * root.clockScale
            height: parent.height * 0.26
            radius: width / 2
            color: root.handColor
        }
    }

    Item {
        anchors.fill: parent
        rotation: root.minuteAngle

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.verticalCenter
            anchors.bottomMargin: -8 * root.clockScale
            width: 7 * root.clockScale
            height: parent.height * 0.38
            radius: width / 2
            color: root.handColor
        }
    }

    Item {
        anchors.fill: parent
        rotation: root.secondAngle

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.verticalCenter
            anchors.bottomMargin: -14 * root.clockScale
            width: 2.5 * root.clockScale
            height: parent.height * 0.46
            radius: width / 2
            color: root.secondColor
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 12 * root.clockScale
        height: 12 * root.clockScale
        radius: width / 2
        color: root.secondColor
    }
}
