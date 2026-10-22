pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components

Item {
    id: root

    required property real size
    required property string dialStyle
    required property bool hourMarks
    required property color color

    readonly property real k: size / 230

    implicitWidth: size
    implicitHeight: size

    Item {
        anchors.fill: parent
        visible: root.dialStyle === "dots"

        Repeater {
            model: 12

            Item {
                required property int index

                anchors.fill: parent
                rotation: 360 / 12 * index

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 46 * root.k
                    width: 12 * root.k
                    height: width
                    radius: width / 2
                    color: root.color
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.dialStyle === "full"

        Repeater {
            model: 60

            Item {
                id: tick

                required property int index

                anchors.fill: parent
                rotation: 360 / 60 * tick.index

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 46 * root.k
                    width: tick.index % 5 === 0 ? 18 * root.k : 7 * root.k
                    height: tick.index % 5 === 0 ? 4 * root.k : 2 * root.k
                    radius: height / 2
                    color: root.color
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.dialStyle === "numbers"

        Repeater {
            model: 4

            Item {
                id: numberItem

                required property int index

                anchors.fill: parent
                rotation: 360 / 4 * (numberItem.index + 1)

                Item {
                    id: numberBox

                    width: 80 * root.k
                    height: width
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 20 * root.k

                    StyledText {
                        anchors.centerIn: numberBox
                        text: 12 / 4 * (numberItem.index + 1)
                        rotation: -360 / 4 * (numberItem.index + 1)
                        color: root.color
                        font.family: Tokens.font.clock.family
                        font.pixelSize: 80 * root.k
                        font.weight: Font.Black
                    }
                }
            }
        }
    }

    Item {
        anchors.centerIn: parent
        width: root.size * 0.58
        height: width
        visible: root.hourMarks && (root.dialStyle === "dots" || root.dialStyle === "full")

        Repeater {
            model: 12

            Item {
                required property int index

                anchors.fill: parent
                rotation: 360 / 12 * index

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 4 * root.k
                    width: 10 * root.k
                    height: 4 * root.k
                    radius: width / 2
                    color: root.color
                }
            }
        }
    }
}
