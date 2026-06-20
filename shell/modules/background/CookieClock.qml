pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property Item wallpaper
    required property real absX
    required property real absY

    property real clockScale: Config.background.desktopClock.scale
    readonly property bool invertColors: Config.background.desktopClock.invertColors
    readonly property bool useLightSet: Colours.light ? !invertColors : invertColors
    readonly property color colFace: useLightSet ? Colours.palette.m3surface : Colours.palette.m3surface
    readonly property color colOnFace: useLightSet ? Colours.palette.m3onSurface : Colours.palette.m3onSurface
    readonly property color colPrimary: useLightSet ? Colours.palette.m3primary : Colours.palette.m3primary
    readonly property color colSecondary: useLightSet ? Colours.palette.m3secondary : Colours.palette.m3secondary
    readonly property color colTertiary: useLightSet ? Colours.palette.m3tertiary : Colours.palette.m3tertiary
    readonly property color colOutline: useLightSet ? Colours.palette.m3outline : Colours.palette.m3outline
    readonly property color colShadow: Colours.palette.m3shadow

    readonly property int hours: Time.hours % 12
    readonly property int minutes: Time.minutes
    readonly property int seconds: Time.seconds

    readonly property real faceSize: 230 * root.clockScale

    implicitWidth: faceSize
    implicitHeight: faceSize

    // Shadow
    layer.enabled: Config.background.desktopClock.shadow.enabled
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: root.colShadow
        shadowOpacity: Config.background.desktopClock.shadow.opacity
        shadowBlur: Config.background.desktopClock.shadow.blur
    }

    // Clock face (cookie shape - rounded polygon)
    Shape {
        id: cookieShape

        anchors.centerIn: parent
        width: root.faceSize
        height: root.faceSize
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: cookiePath

            fillColor: root.colFace
            strokeColor: "transparent"

            PathAngleArc {
                id: arc
                centerX: cookieShape.width / 2
                centerY: cookieShape.height / 2
                radiusX: root.faceSize / 2
                radiusY: root.faceSize / 2
                startAngle: 0
                sweepAngle: 360
            }
        }
    }

    // Hour marks
    Repeater {
        model: 12

        Item {
            required property int index

            readonly property real angle: (index * 30 - 90) * Math.PI / 180
            readonly property bool isMain: index % 3 === 0

            x: cookieShape.x + cookieShape.width / 2 + Math.cos(angle) * (root.faceSize / 2 - 12 * root.clockScale) - width / 2
            y: cookieShape.y + cookieShape.height / 2 + Math.sin(angle) * (root.faceSize / 2 - 12 * root.clockScale) - height / 2
            width: isMain ? 4 * root.clockScale : 2 * root.clockScale
            height: isMain ? 16 * root.clockScale : 10 * root.clockScale

            rotation: index * 30

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                radius: width / 2
                color: root.colOutline
            }
        }
    }

    // Minute marks
    Repeater {
        model: 60

        Item {
            required property int index

            readonly property real angle: (index * 6 - 90) * Math.PI / 180
            readonly property bool isHour: index % 5 === 0

            visible: !isHour

            x: cookieShape.x + cookieShape.width / 2 + Math.cos(angle) * (root.faceSize / 2 - 10 * root.clockScale) - width / 2
            y: cookieShape.y + cookieShape.height / 2 + Math.sin(angle) * (root.faceSize / 2 - 10 * root.clockScale) - height / 2
            width: 1.5 * root.clockScale
            height: 6 * root.clockScale

            rotation: index * 6

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                radius: width / 2
                color: root.colOutline
                opacity: 0.4
            }
        }
    }

    // Hour hand
    Shape {
        anchors.centerIn: parent
        width: root.faceSize
        height: root.faceSize
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.colPrimary
            strokeColor: "transparent"

            readonly property real handLength: root.faceSize * 0.3
            readonly property real handWidth: 5 * root.clockScale
            readonly property real angle: (root.hours + root.minutes / 60) * 30 - 90
            readonly property real rad: angle * Math.PI / 180

            PathMove {
                x: cookieShape.width / 2 + Math.cos(rad) * handLength - Math.cos(rad + Math.PI / 2) * handWidth / 2
                y: cookieShape.height / 2 + Math.sin(rad) * handLength - Math.sin(rad + Math.PI / 2) * handWidth / 2
            }
            PathLine {
                x: cookieShape.width / 2 + Math.cos(rad) * (-12 * root.clockScale) - Math.cos(rad + Math.PI / 2) * handWidth / 2
                y: cookieShape.height / 2 + Math.sin(rad) * (-12 * root.clockScale) - Math.sin(rad + Math.PI / 2) * handWidth / 2
            }
            PathLine {
                x: cookieShape.width / 2 + Math.cos(rad) * (-12 * root.clockScale) + Math.cos(rad + Math.PI / 2) * handWidth / 2
                y: cookieShape.height / 2 + Math.sin(rad) * (-12 * root.clockScale) + Math.sin(rad + Math.PI / 2) * handWidth / 2
            }
            PathLine {
                x: cookieShape.width / 2 + Math.cos(rad) * handLength + Math.cos(rad + Math.PI / 2) * handWidth / 2
                y: cookieShape.height / 2 + Math.sin(rad) * handLength + Math.sin(rad + Math.PI / 2) * handWidth / 2
            }
        }
    }

    // Minute hand
    Shape {
        anchors.centerIn: parent
        width: root.faceSize
        height: root.faceSize
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.colSecondary
            strokeColor: "transparent"

            readonly property real handLength: root.faceSize * 0.4
            readonly property real handWidth: 3.5 * root.clockScale
            readonly property real angle: root.minutes * 6 - 90
            readonly property real rad: angle * Math.PI / 180

            PathMove {
                x: cookieShape.width / 2 + Math.cos(rad) * handLength - Math.cos(rad + Math.PI / 2) * handWidth / 2
                y: cookieShape.height / 2 + Math.sin(rad) * handLength - Math.sin(rad + Math.PI / 2) * handWidth / 2
            }
            PathLine {
                x: cookieShape.width / 2 + Math.cos(rad) * (-16 * root.clockScale) - Math.cos(rad + Math.PI / 2) * handWidth / 2
                y: cookieShape.height / 2 + Math.sin(rad) * (-16 * root.clockScale) - Math.sin(rad + Math.PI / 2) * handWidth / 2
            }
            PathLine {
                x: cookieShape.width / 2 + Math.cos(rad) * (-16 * root.clockScale) + Math.cos(rad + Math.PI / 2) * handWidth / 2
                y: cookieShape.height / 2 + Math.sin(rad) * (-16 * root.clockScale) + Math.sin(rad + Math.PI / 2) * handWidth / 2
            }
            PathLine {
                x: cookieShape.width / 2 + Math.cos(rad) * handLength + Math.cos(rad + Math.PI / 2) * handWidth / 2
                y: cookieShape.height / 2 + Math.sin(rad) * handLength + Math.sin(rad + Math.PI / 2) * handWidth / 2
            }
        }
    }

    // Second hand
    Shape {
        anchors.centerIn: parent
        width: root.faceSize
        height: root.faceSize
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.colTertiary
            strokeColor: "transparent"

            readonly property real handLength: root.faceSize * 0.42
            readonly property real handWidth: 1.5 * root.clockScale
            readonly property real angle: root.seconds * 6 - 90
            readonly property real rad: angle * Math.PI / 180

            PathMove {
                x: cookieShape.width / 2 + Math.cos(rad) * handLength - Math.cos(rad + Math.PI / 2) * handWidth / 2
                y: cookieShape.height / 2 + Math.sin(rad) * handLength - Math.sin(rad + Math.PI / 2) * handWidth / 2
            }
            PathLine {
                x: cookieShape.width / 2 + Math.cos(rad) * (-20 * root.clockScale) - Math.cos(rad + Math.PI / 2) * handWidth / 2
                y: cookieShape.height / 2 + Math.sin(rad) * (-20 * root.clockScale) - Math.sin(rad + Math.PI / 2) * handWidth / 2
            }
            PathLine {
                x: cookieShape.width / 2 + Math.cos(rad) * (-20 * root.clockScale) + Math.cos(rad + Math.PI / 2) * handWidth / 2
                y: cookieShape.height / 2 + Math.sin(rad) * (-20 * root.clockScale) + Math.sin(rad + Math.PI / 2) * handWidth / 2
            }
            PathLine {
                x: cookieShape.width / 2 + Math.cos(rad) * handLength + Math.cos(rad + Math.PI / 2) * handWidth / 2
                y: cookieShape.height / 2 + Math.sin(rad) * handLength + Math.sin(rad + Math.PI / 2) * handWidth / 2
            }
        }
    }

    // Center dot
    Rectangle {
        anchors.centerIn: parent
        width: 8 * root.clockScale
        height: 8 * root.clockScale
        radius: width / 2
        color: root.colPrimary
    }

    // Date display below clock
    ColumnLayout {
        anchors.top: parent.bottom
        anchors.topMargin: Tokens.spacing.large * root.clockScale
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.format("MMMM").toUpperCase()
            font: Tokens.font.clock.size(Tokens.font.title.medium.pointSize * root.clockScale).letterSpacing(4).weight(Font.Bold).build()
            color: root.colSecondary
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.format("dd")
            font: Tokens.font.clock.size(Tokens.font.headline.medium.pointSize * root.clockScale).letterSpacing(2).weight(Font.Medium).build()
            color: root.colPrimary
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.format("dddd")
            font: Tokens.font.clock.size(Tokens.font.body.large.pointSize * root.clockScale).letterSpacing(2).build()
            color: root.colSecondary
        }
    }

    Behavior on clockScale {
        Anim {}
    }
}
