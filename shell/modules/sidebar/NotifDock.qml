pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    required property Props props
    required property DrawerVisibilities visibilities
    readonly property int notifCount: Notifs.list.reduce((acc, n) => n.closed ? acc : acc + 1, 0)
    property string clearPhase: "idle"
    property int clearAnimatedRemaining: 3

    anchors.fill: parent
    anchors.margins: Tokens.padding.medium

    Component.onCompleted: Notifs.list.forEach(n => n.popup = false)

    Item {
        id: title

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Tokens.padding.extraSmall

        implicitHeight: Math.max(count.implicitHeight, titleText.implicitHeight)

        StyledText {
            id: count

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: root.notifCount > 0 ? 0 : -width - titleText.anchors.leftMargin
            opacity: root.notifCount > 0 ? 1 : 0

            text: root.notifCount
            color: Colours.palette.m3outline
            font: Tokens.font.label.large

            Behavior on anchors.leftMargin {
                Anim {}
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        StyledText {
            id: titleText

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: count.right
            anchors.right: parent.right
            anchors.leftMargin: Tokens.spacing.extraSmall

            text: root.notifCount > 0 ? qsTr("notification%1").arg(root.notifCount === 1 ? "" : "s") : qsTr("Notifications")
            color: Colours.palette.m3outline
            font: Tokens.font.label.large
            elide: Text.ElideRight
        }
    }

    ClippingRectangle {
        id: clipRect

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: title.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Tokens.spacing.medium

        radius: Tokens.rounding.medium
        color: "transparent"

        Loader {
            asynchronous: true
            anchors.centerIn: parent
            active: opacity > 0
            opacity: root.notifCount > 0 ? 0 : 1

            sourceComponent: ColumnLayout {
                spacing: Tokens.spacing.extraLarge

                Image {
                    asynchronous: true
                    source: Paths.absolutePath(Config.paths.noNotifsPic)
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: clipRect.width * 0.8 * ((QsWindow.window as QsWindow)?.devicePixelRatio ?? 1)

                    layer.enabled: true
                    layer.effect: Colouriser {
                        colorizationColor: Colours.palette.m3outlineVariant
                        brightness: 1
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("All up to date!")
                    color: Colours.palette.m3outlineVariant
                    font: Tokens.font.headline.builders.small.width(90).build()
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.StandardExtraLarge
                }
            }
        }

        StyledFlickable {
            id: view

            anchors.fill: parent

            flickableDirection: Flickable.VerticalFlick
            contentWidth: width
            contentHeight: notifList.implicitHeight + (Notifs.hasMore ? loadIndicator.height + Tokens.spacing.small : 0)

            onContentYChanged: {
                if (Notifs.hasMore && contentHeight - contentY - height < 200)
                    Notifs.loadMore();
            }

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: view
            }

            NotifDockList {
                id: notifList

                props: root.props
                visibilities: root.visibilities
                container: view
                clearPhase: root.clearPhase
            }

            Loader {
                id: loadIndicator

                anchors.top: notifList.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: Tokens.spacing.small

                active: Notifs.hasMore
                asynchronous: true

                sourceComponent: RowLayout {
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        Layout.preferredWidth: Tokens.sizes.bar.innerWidth
                        Layout.preferredHeight: Tokens.sizes.bar.innerWidth
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        grade: 0
                        text: "hourglass_top"
                        color: Colours.palette.m3outlineVariant

                        RotationAnimation on rotation {
                            running: Notifs.hasMore
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                        }
                    }

                    StyledText {
                        text: qsTr("Loading more...")
                        color: Colours.palette.m3outlineVariant
                        font: Tokens.font.label.medium
                    }
                }
            }
        }
    }

    Timer {
        id: clearTimer

        repeat: true
        triggeredOnStart: true
        interval: root.clearPhase === "instant" ? 5 : Math.max(15, Math.min(80, 69.8 - 12.3 * Math.log(Notifs.notClosed.length)))
        onTriggered: {
            if (Notifs.notClosed.length === 0) {
                root.clearPhase = "idle";
                stop();
                return;
            }

            if (root.clearPhase === "idle") {
                root.clearAnimatedRemaining = 3;
                root.clearPhase = "animated";
            }

            // After animated batch, close ALL remaining instantly
            if (root.clearPhase === "animated" && root.clearAnimatedRemaining <= 0) {
                root.clearPhase = "instant";
                for (const n of Notifs.notClosed.slice())
                    n.close();
                root.clearPhase = "idle";
                stop();
                return;
            }

            root.clearAnimatedRemaining--;

            // Close one app group with normal timing
            const first = Notifs.notClosed[0];
            if (!first) {
                root.clearPhase = "idle";
                stop();
                return;
            }
            const appName = first.appName;
            for (const n of Notifs.notClosed.filter(n => n.appName === appName))
                n.close();
        }
    }

    Loader {
        asynchronous: true
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.medium

        scale: root.notifCount > 0 ? 1 : 0.5
        opacity: root.notifCount > 0 ? 1 : 0
        active: opacity > 0

        sourceComponent: IconButton {
            id: clearBtn

            icon: "clear_all"
            font: Tokens.font.icon.large
            onClicked: clearTimer.start()

            Elevation {
                anchors.fill: parent
                radius: parent.radius
                z: -1
                level: clearBtn.stateLayer.containsMouse ? 4 : 3
            }
        }

        Behavior on scale {
            Anim {
                type: Anim.FastSpatial
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }
}
