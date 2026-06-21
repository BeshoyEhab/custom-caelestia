pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var network: nState.selectedNetwork
    readonly property bool connected: network?.active ?? false
    readonly property bool loading: Nmcli.connectingSsid === network?.ssid

    onNetworkChanged: {
        if (!network)
            nState.closeSubPage();
    }

    title: network?.ssid ?? qsTr("Network Details")
    isSubPage: true

    Component.onCompleted: {
        if (connected) {
            Network.updateWirelessDeviceDetails();
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Connections {
            function onActiveChanged(): void {
                if (root.connected) {
                    Network.updateWirelessDeviceDetails();
                }
            }
            target: root.network
        }

        // Big action buttons
        ButtonRow {
            Layout.bottomMargin: Tokens.spacing.large - parent.spacing
            Layout.alignment: Qt.AlignHCenter
            Layout.minimumWidth: Math.round(root.cappedWidth * 0.7)
            spacing: Tokens.spacing.small

            TextButton {
                id: forgetBtn

                fillWidth: true
                shapeMorph: true
                isRound: true
                type: ButtonBase.Filled

                inactiveColour: Colours.palette.m3errorContainer
                inactiveOnColour: Colours.palette.m3onErrorContainer
                text: qsTr("Forget")

                onClicked: {
                    if (root.network) {
                        Network.forgetNetwork(root.network.ssid);
                        root.nState.closeSubPage();
                    }
                }
            }

            TextButton {
                id: connectBtn

                fillWidth: true
                shapeMorph: true
                isRound: true
                type: ButtonBase.Filled

                inactiveColour: Colours.palette.m3primaryContainer
                inactiveOnColour: Colours.palette.m3onPrimaryContainer
                text: root.connected ? qsTr("Disconnect") : qsTr("Connect")
                disabled: root.loading

                onClicked: {
                    if (root.network) {
                        if (root.connected) {
                            Network.disconnectFromNetwork();
                        } else {
                            NetworkConnection.handleConnect(root.network);
                        }
                    }
                }
            }
        }

        // Connection strength progress bar
        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: strengthLayout.implicitHeight + Tokens.padding.large * 2
            first: true

            ColumnLayout {
                id: strengthLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Signal strength")
                    }

                    StyledText {
                        text: root.network ? root.network.strength + "%" : ""
                        color: Colours.palette.m3outline
                        font: Tokens.font.body.small
                    }
                }

                StyledProgressBar {
                    Layout.fillWidth: true
                    implicitHeight: Tokens.padding.medium
                    value: root.network ? root.network.strength / 100.0 : 0
                }
            }
        }

        // Info Block 1 (General Connection properties)
        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: infoLayout1.implicitHeight + Tokens.padding.large * 2
            last: !root.connected

            ColumnLayout {
                id: infoLayout1

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Security")
                    }
                    StyledText {
                        text: root.network?.security || qsTr("None")
                        color: Colours.palette.m3outline
                        font: Tokens.font.body.small
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Frequency")
                    }
                    StyledText {
                        text: root.network ? (root.network.frequency / 1000.0).toFixed(3) + " GHz" : ""
                        color: Colours.palette.m3outline
                        font: Tokens.font.body.small
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("BSSID")
                    }
                    StyledText {
                        text: root.network?.bssid || ""
                        color: Colours.palette.m3outline
                        font: Tokens.font.body.small
                    }
                }
            }
        }

        // Info Block 2 (IP / network info - only shown if connected)
        Loader {
            Layout.fillWidth: true
            active: root.connected && Network.wirelessDeviceDetails !== null
            visible: active

            sourceComponent: ConnectedRect {
                implicitHeight: infoLayout2.implicitHeight + Tokens.padding.large * 2
                last: true

                ColumnLayout {
                    id: infoLayout2

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("IP Address")
                        }
                        StyledText {
                            text: Network.wirelessDeviceDetails?.ipAddress || ""
                            color: Colours.palette.m3outline
                            font: Tokens.font.body.small
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Subnet Mask")
                        }
                        StyledText {
                            text: {
                                const subnet = Network.wirelessDeviceDetails?.subnet;
                                if (!subnet) return "";
                                const mask = Network.cidrToSubnetMask(subnet);
                                return mask ? mask + " (/" + subnet + ")" : "/" + subnet;
                            }
                            color: Colours.palette.m3outline
                            font: Tokens.font.body.small
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Gateway")
                        }
                        StyledText {
                            text: Network.wirelessDeviceDetails?.gateway || ""
                            color: Colours.palette.m3outline
                            font: Tokens.font.body.small
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("DNS")
                        }
                        StyledText {
                            text: Network.wirelessDeviceDetails?.dns?.join(", ") || ""
                            color: Colours.palette.m3outline
                            font: Tokens.font.body.small
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("MAC Address")
                        }
                        StyledText {
                            text: Network.wirelessDeviceDetails?.macAddress || ""
                            color: Colours.palette.m3outline
                            font: Tokens.font.body.small
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Speed")
                        }
                        StyledText {
                            text: Network.wirelessDeviceDetails?.speed || ""
                            color: Colours.palette.m3outline
                            font: Tokens.font.body.small
                        }
                    }
                }
            }
        }
    }
}
