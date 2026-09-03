pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.images
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Wallpaper & style")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        StyledClippingRect {
            id: wallWrapper

            Layout.alignment: Qt.AlignHCenter
            implicitWidth: {
                const screen = root.nState.screen;
                return implicitHeight / screen.height * screen.width;
            }
            implicitHeight: {
                const screen = root.nState.screen;
                const cWidth = root.cappedWidth;
                return Math.min(Math.round(cWidth * 0.4), cWidth / screen.width * screen.height);
            }

            color: Colours.tPalette.m3surfaceContainer
            radius: Tokens.rounding.large

            Loader {
                anchors.centerIn: parent
                opacity: Config.background.wallpaperEnabled ? 0 : 1
                active: opacity > 0

                sourceComponent: ColumnLayout {
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "hide_image"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.extraLarge
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Wallpaper disabled")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.large
                    }
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.SlowEffects
                    }
                }
            }

            Item {
                anchors.fill: parent
                opacity: Config.background.wallpaperEnabled ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.SlowEffects
                    }
                }

                Loader {
                    id: wallIndicatorLoader

                    anchors.centerIn: parent

                    opacity: 0
                    active: opacity > 0

                    sourceComponent: StyledRect {
                        implicitWidth: wallLoadingIndicator.implicitSize + Tokens.padding.largeIncreased * 2
                        implicitHeight: wallLoadingIndicator.implicitSize + Tokens.padding.largeIncreased * 2

                        color: Colours.palette.m3primaryContainer
                        radius: Tokens.rounding.full

                        LoadingIndicator {
                            id: wallLoadingIndicator

                            anchors.centerIn: parent
                            containsIcon: true
                            implicitSize: Math.min(wallWrapper.implicitWidth, wallWrapper.implicitHeight) * 0.4
                        }
                    }

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }

                Timer {
                    id: wallLoadDebounceTimer

                    interval: 100
                    onTriggered: {
                        if (wallImg.status !== Image.Ready)
                            wallIndicatorLoader.opacity = 1;
                    }
                }

                FadeImage {
                    id: wallImg

                    anchors.fill: parent
                    fillMode: {
                        switch (GlobalConfig.background.wallpaperMode) {
                        case "fit": return Image.PreserveAspectFit;
                        case "stretch": return Image.Stretch;
                        default: return Image.PreserveAspectCrop;
                        }
                    }
                    source: Wallpapers.current
                    preventInit: wallIndicatorLoader.opacity > 0
                    fadeOutAnim: Anim.DefaultEffects
                    fadeInAnim: Anim.SlowEffects

                    onSourceChanged: wallLoadDebounceTimer.restart()

                    onStatusChanged: {
                        if (status === Image.Ready) {
                            wallLoadDebounceTimer.stop();
                            wallIndicatorLoader.opacity = 0;
                        }
                    }
                }
            }
        }

        ButtonRow {
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.small

            IconTextButton {
                icon: "wallpaper"
                text: qsTr("Wallpapers")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                type: IconTextButton.Tonal
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                disabled: !Config.background.wallpaperEnabled
                onClicked: root.nState.openSubPage(1) // Wallpaper page
            }

            IconTextButton {
                icon: "palette"
                text: qsTr("Colours")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                type: IconTextButton.Tonal
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                onClicked: root.nState.openSubPage(3) // Colours page
            }
        }

        ToggleRow {
            first: true
            text: qsTr("Display wallpaper")
            checked: Config.background.wallpaperEnabled
            onToggled: GlobalConfig.background.wallpaperEnabled = checked
        }

        SelectRow {
            label: qsTr("Wallpaper mode")
            subtext: {
                const m = GlobalConfig.background.wallpaperMode;
                if (m === "fit") return qsTr("Fit (preserve aspect ratio)");
                if (m === "stretch") return qsTr("Stretch (fill screen)");
                return qsTr("Crop (fill & clip)");
            }
            enabled: Config.background.wallpaperEnabled
            menuItems: [
                MenuItem {
                    text: qsTr("Crop")
                    icon: GlobalConfig.background.wallpaperMode === "crop" ? "check" : ""
                    activeIcon: "crop"
                },
                MenuItem {
                    text: qsTr("Fit")
                    icon: GlobalConfig.background.wallpaperMode === "fit" ? "check" : ""
                    activeIcon: "fit_screen"
                },
                MenuItem {
                    text: qsTr("Stretch")
                    icon: GlobalConfig.background.wallpaperMode === "stretch" ? "check" : ""
                    activeIcon: "aspect_ratio"
                }
            ]
            active: {
                const m = GlobalConfig.background.wallpaperMode;
                if (m === "fit") return menuItems[1];
                if (m === "stretch") return menuItems[2];
                return menuItems[0];
            }
            onSelected: {
                const idx = menuItems.indexOf(item);
                GlobalConfig.background.wallpaperMode = idx === 1 ? "fit" : idx === 2 ? "stretch" : "crop";
            }
        }

        ToggleRow {
            text: qsTr("Auto-rotate wallpaper")
            subtext: GlobalConfig.background.wallpaperRotation ? qsTr("Every %1h").arg(GlobalConfig.background.wallpaperRotationInterval) : qsTr("Disabled")
            checked: GlobalConfig.background.wallpaperRotation
            onToggled: GlobalConfig.background.wallpaperRotation = checked
        }

        StepperRow {
            label: qsTr("Rotation interval")
            subtext: qsTr("Hours between wallpaper changes")
            value: GlobalConfig.background.wallpaperRotationInterval
            from: 1
            to: 24
            stepSize: 1
            enabled: GlobalConfig.background.wallpaperRotation
            onMoved: v => GlobalConfig.background.wallpaperRotationInterval = v
        }

        ToggleRow {
            text: qsTr("Transparency")
            subtext: qsTr("Base %1, layers %2").arg(Colours.transparency.base).arg(Colours.transparency.layers)
            checked: Colours.transparency.enabled
            onToggled: GlobalConfig.appearance.transparency.enabled = checked
        }

        SelectRow {
            last: true
            menuOnTop: true
            label: qsTr("Theme mode")
            subtext: {
                const fm = GlobalConfig.services.forceMode;
                if (fm === "light") return qsTr("Forced light");
                if (fm === "dark") return qsTr("Forced dark");
                return qsTr("Follow wallpaper");
            }
            menuItems: [
                MenuItem {
                    text: qsTr("Auto")
                    icon: GlobalConfig.services.forceMode ? "" : "check"
                    activeIcon: "wallpaper"
                },
                MenuItem {
                    text: qsTr("Light")
                    icon: GlobalConfig.services.forceMode === "light" ? "check" : ""
                    activeIcon: "light_mode"
                },
                MenuItem {
                    text: qsTr("Dark")
                    icon: GlobalConfig.services.forceMode === "dark" ? "check" : ""
                    activeIcon: "dark_mode"
                }
            ]
            active: {
                const fm = GlobalConfig.services.forceMode;
                if (fm === "light") return menuItems[1];
                if (fm === "dark") return menuItems[2];
                return menuItems[0];
            }
            onSelected: {
                const idx = menuItems.indexOf(item);
                GlobalConfig.services.forceMode = idx === 1 ? "light" : idx === 2 ? "dark" : "";
            }
        }
    }
}
