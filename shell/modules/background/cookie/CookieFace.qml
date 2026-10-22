pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import M3Shapes
import Caelestia.Config
import qs.services

Item {
    id: root

    required property real size
    required property int sides
    required property bool sine
    required property bool constantlyRotate
    required property color color

    readonly property real faceSize: size

    implicitWidth: size
    implicitHeight: size

    layer.enabled: Config.background.desktopClock.shadow.enabled
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Colours.palette.m3shadow
        shadowOpacity: Config.background.desktopClock.shadow.opacity
        shadowBlur: Config.background.desktopClock.shadow.blur
    }

    // `star()` is an instance method on MaterialShape, not a static one.
    // Keep a hidden instance to build the custom polygon.
    MaterialShape {
        id: shapeBuilder

        visible: false
        width: 0
        height: 0
    }

    Item {
        id: face

        anchors.fill: parent

        RotationAnimation on rotation {
            running: root.constantlyRotate
            duration: 30000
            easing.type: Easing.Linear
            from: 360
            to: 0
            loops: Animation.Infinite
        }

        MaterialShape {
            visible: !root.sine
            anchors.fill: parent
            shape: MaterialShape.Custom
            customShape: shapeBuilder.star(Math.max(3, root.sides), 0.8, Math.min(0.08, 1.5 / Math.max(root.sides, 4)), 0)
            color: root.color
        }

        SineCookie {
            visible: root.sine
            anchors.fill: parent
            size: root.size
            sides: root.sides
            color: root.color
            constantlyRotate: false
        }
    }
}
