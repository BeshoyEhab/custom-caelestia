pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

Item {
    id: root

    required property real size
    required property real sides
    required property color color
    required property bool constantlyRotate

    readonly property real amplitude: root.size / 50

    implicitWidth: size
    implicitHeight: size

    RotationAnimation on rotation {
        running: root.constantlyRotate
        duration: 30000
        easing.type: Easing.Linear
        from: 360
        to: 0
        loops: Animation.Infinite
    }

    Shape {
        id: shape

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: shapePath

            strokeWidth: 0
            fillColor: root.color
            pathHints: ShapePath.PathSolid & ShapePath.PathNonIntersecting

            PathPolyline {
                property var pointsList: {
                    const points = [];
                    const cx = shape.width / 2;
                    const cy = shape.height / 2;
                    const steps = 360;
                    const radius = root.size / 2 - root.amplitude;
                    for (let i = 0; i <= steps; i++) {
                        const angle = (i / steps) * 2 * Math.PI;
                        const rotatedAngle = angle * root.sides + Math.PI / 2;
                        const wave = Math.sin(rotatedAngle) * root.amplitude;
                        const x = Math.cos(angle) * (radius + wave) + cx;
                        const y = Math.sin(angle) * (radius + wave) + cy;
                        points.push(Qt.point(x, y));
                    }
                    return points;
                }

                path: pointsList
            }
        }
    }
}
