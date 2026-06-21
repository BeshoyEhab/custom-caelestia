pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Add Network")
    isSubPage: true

    property int securityType: 0 // 0 = None, 1 = WPA/WPA2 Personal

    readonly property list<MenuItem> securityItems: [
        MenuItem {
            text: qsTr("None")
        },
        MenuItem {
            text: qsTr("WPA/WPA2 Personal")
        }
    ]

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Action Buttons
        ButtonRow {
            Layout.bottomMargin: Tokens.spacing.large - parent.spacing
            Layout.alignment: Qt.AlignHCenter
            Layout.minimumWidth: Math.round(root.cappedWidth * 0.7)
            spacing: Tokens.spacing.small

            TextButton {
                id: cancelBtn

                fillWidth: true
                shapeMorph: true
                isRound: true
                type: ButtonBase.Filled

                inactiveColour: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
                inactiveOnColour: Colours.palette.m3onSurface
                text: qsTr("Cancel")

                onClicked: root.nState.closeSubPage()
            }

            TextButton {
                id: connectBtn

                fillWidth: true
                shapeMorph: true
                isRound: true
                type: ButtonBase.Filled

                inactiveColour: Colours.palette.m3primaryContainer
                inactiveOnColour: Colours.palette.m3onPrimaryContainer
                text: qsTr("Connect")
                disabled: !ssidInput.text.trim()

                onClicked: {
                    const ssid = ssidInput.text.trim();
                    const isSecure = root.securityType === 1;
                    const pw = isSecure && passwordLoader.item ? passwordLoader.item.password : "";

                    connectBtn.disabled = true;
                    connectingLoader.active = true;
                    errorText.visible = false;

                    Network.connectToNetwork(ssid, pw, "", result => {
                        connectBtn.disabled = false;
                        connectingLoader.active = false;
                        if (result && result.success) {
                            root.nState.closeSubPage();
                        } else {
                            errorText.text = (result && result.error) ? result.error : qsTr("Failed to connect");
                            errorText.visible = true;
                        }
                    });
                }
            }
        }

        // Connecting Indicator
        Loader {
            id: connectingLoader
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: Tokens.spacing.small
            active: false
            visible: active

            sourceComponent: RowLayout {
                spacing: Tokens.spacing.small
                LoadingIndicator {
                    implicitSize: 20
                }
                StyledText {
                    text: qsTr("Connecting...")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3primary
                }
            }
        }

        // Error message text
        StyledText {
            id: errorText
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: Tokens.spacing.small
            horizontalAlignment: Text.AlignHCenter
            color: Colours.palette.m3error
            font: Tokens.font.body.small
            visible: false
            wrapMode: Text.WordWrap
        }

        // Form details
        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: false
            implicitHeight: ssidRowLayout.implicitHeight + Tokens.padding.large * 2

            RowLayout {
                id: ssidRowLayout
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                StyledText {
                    text: qsTr("SSID")
                    font: Tokens.font.body.small
                    Layout.preferredWidth: 80
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                    radius: Tokens.rounding.medium
                    border.width: 1
                    border.color: ssidInput.activeFocus ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 0.3)

                    StyledTextField {
                        id: ssidInput
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.rightMargin: Tokens.padding.medium
                        placeholderText: qsTr("Network Name")
                        verticalAlignment: TextInput.AlignVCenter
                    }
                }
            }
        }

        SelectRow {
            first: false
            last: root.securityType === 0
            label: qsTr("Security")
            menuItems: root.securityItems
            active: root.securityItems[root.securityType]
            onSelected: item => {
                root.securityType = root.securityItems.indexOf(item);
            }
        }

        Loader {
            id: passwordLoader
            Layout.fillWidth: true
            active: root.securityType === 1
            visible: active

            sourceComponent: ConnectedRect {
                first: false
                last: true
                implicitHeight: pwRowLayout.implicitHeight + Tokens.padding.large * 2

                readonly property alias password: passwordInput.text

                RowLayout {
                    id: pwRowLayout
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                      StyledText {
                          text: qsTr("Password")
                          font: Tokens.font.body.small
                          Layout.preferredWidth: 80
                      }

                      StyledRect {
                          Layout.fillWidth: true
                          Layout.preferredHeight: 36
                          color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                          radius: Tokens.rounding.medium
                          border.width: 1
                          border.color: passwordInput.activeFocus ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 0.3)

                          StyledTextField {
                              id: passwordInput
                              anchors.fill: parent
                              anchors.leftMargin: Tokens.padding.medium
                              anchors.rightMargin: Tokens.padding.medium
                              placeholderText: qsTr("Password")
                              echoMode: TextField.Password
                              verticalAlignment: TextInput.AlignVCenter
                          }
                      }
                }
            }
        }
    }
}
