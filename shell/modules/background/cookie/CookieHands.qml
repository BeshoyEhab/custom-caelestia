pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components

Item {
    id: root

    required property real size
    required property int hour
    required property int minute
    required property int second
    required property string hourStyle
    required property string minuteStyle
    required property string secondStyle
    required property color hourColor
    required property color minuteColor
    required property color secondColor
    required property color faceColor

    readonly property real k: size / 230
    // Hoisted out of the Behavior below: QQuickBehavior is not a QQuickItem and
    // cannot inherit a screen, so per-monitor Config reads there warn.
    readonly property bool constantRotate: Config.background.desktopClock.cookie.constantlyRotate
    readonly property real hourWidth: 20 * k
    readonly property real minuteWidth: root.minuteStyle === "bold" ? 20 * k : root.minuteStyle === "medium" ? 12 * k : 5 * k

    implicitWidth: size
    implicitHeight: size

    Item {
        id: hourHand

        anchors.fill: parent
        visible: root.hourStyle !== "hide"
        rotation: -90 + 30 * (root.hour + root.minute / 60)

        Behavior on rotation {
            RotationAnimation {
                direction: RotationAnimation.Clockwise
                duration: 300
                easing: Tokens.anim.emphasized
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: (parent.width - root.hourWidth) / 2 - (root.hourStyle === "classic" ? 15 * root.k : 0)
            width: 72 * root.k
            height: root.hourStyle === "classic" ? 8 * root.k : root.hourWidth
            radius: root.hourStyle === "classic" ? 2 * root.k : height / 2
            color: Qt.rgba(root.hourColor.r, root.hourColor.g, root.hourColor.b, root.hourStyle === "hollow" ? 0 : 1)
            border.color: root.hourColor
            border.width: root.hourStyle === "hollow" ? 4 * root.k : 0
        }
    }

    Item {
        id: minuteHand

        anchors.fill: parent
        visible: root.minuteStyle !== "hide"
        rotation: -90 + 6 * root.minute

        Behavior on rotation {
            RotationAnimation {
                direction: RotationAnimation.Clockwise
                duration: 300
                easing: Tokens.anim.emphasized
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: (parent.width - root.minuteWidth) / 2 - (root.minuteStyle === "classic" ? 15 * root.k : 0)
            width: 95 * root.k
            height: root.minuteWidth
            radius: root.minuteStyle === "classic" ? 2 * root.k : height / 2
            color: root.minuteColor
        }
    }

    Item {
        id: secondHand

        anchors.fill: parent
        visible: root.secondStyle !== "hide"
        rotation: -90 + 6 * root.second

        Behavior on rotation {
            enabled: root.constantRotate

            RotationAnimation {
                direction: RotationAnimation.Clockwise
                duration: 1000
                easing.type: Easing.InOutQuad
            }
        }

        Rectangle {
            visible: root.secondStyle !== "dot"
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width / 2 + 10 * root.k
            width: 95 * root.k
            height: 2 * root.k
            radius: height / 2
            color: root.secondColor
        }

        Rectangle {
            visible: root.secondStyle === "dot"
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width / 2 + 30 * root.k
            width: 20 * root.k
            height: width
            radius: width / 2
            color: root.secondColor
        }

        Rectangle {
            visible: root.secondStyle === "classic"
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width / 2 + 40 * root.k
            width: 14 * root.k
            height: width
            radius: 2 * root.k
            color: root.secondColor
        }
    }

    Rectangle {
        visible: root.minuteStyle !== "bold"
        anchors.centerIn: parent
        width: 6 * root.k
        height: width
        radius: width / 2
        color: root.minuteStyle === "medium" ? root.faceColor : root.minuteColor
        z: 5
    }
}
