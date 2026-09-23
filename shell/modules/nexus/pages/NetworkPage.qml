pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    // Default 5 from NexusConfig backend.
    readonly property int maxShown: Config.nexus.maxNetworksShown ?? 5

    title: qsTr("Network")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Timer {
            running: root.visible && Nmcli.wifiEnabled
            repeat: true
            triggeredOnStart: true
            // Clamped: stored configs may predate the raised stepper minimum.
            interval: Math.max(15000, GlobalConfig.nexus.networkRescanInterval)
            onTriggered: Nmcli.rescanWifi()
        }

        Timer {
            id: wifiScanDelay

            interval: 100
            onTriggered: Nmcli.rescanWifi()
        }

        Connections {
            function onWifiEnabledChanged(): void {
                if (Nmcli.wifiEnabled)
                    wifiScanDelay.start();
            }

            target: Nmcli
        }

        Loader {
            Layout.fillWidth: true
            active: Nmcli.hasAvailableEthernet
            visible: active
            asynchronous: true

            sourceComponent: EthernetSection {
                nState: root.nState
                cappedWidth: root.cappedWidth
            }
        }

        ToggleRow {
            Layout.topMargin: Nmcli.hasAvailableEthernet ? Tokens.spacing.large : 0
            first: true
            text: qsTr("Wi-Fi")
            font: Tokens.font.body.medium
            horizontalPadding: Tokens.padding.largeIncreased
            checked: Nmcli.wifiEnabled
            onToggled: Nmcli.enableWifi(checked)
        }

        NetworkList {
            Layout.bottomMargin: Nmcli.wifiEnabled && Nmcli.networks.length > root.maxShown ? 0 : -parent.spacing
            nState: root.nState
            limit: root.maxShown

            Behavior on Layout.bottomMargin {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        // All networks button, only when > max networks
        RowButton {
            Layout.preferredHeight: Nmcli.wifiEnabled && Nmcli.networks.length > root.maxShown ? implicitHeight : 0
            clip: true

            icon: "expand_content"
            // TRANSLATORS: %1 = number of networks found
            text: qsTr("Show all networks (%1)").arg(Nmcli.networks.length)
            trailingIcon: "chevron_right"
            onClicked: root.nState.openSubPage(5) // All networks sub-page

            Behavior on Layout.preferredHeight {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        // Saved networks button
        RowButton {
            icon: "bookmark"
            text: qsTr("Saved networks")
            trailingIcon: "chevron_right"
            onClicked: root.nState.openSubPage(6) // Saved networks sub-page
        }

        RowButton {
            last: true
            icon: "add"
            text: qsTr("Add network")
            disabled: !Nmcli.wifiEnabled
            onClicked: root.nState.openSubPage(2) // Add network sub-page
        }

        // Custom: upstream VPN section omitted — local VPN service
        // (qs.services VPN) is single-provider and lacks the multi-provider
        // APIs this section needs (providers, selectedProvider, pingMs...).
        // AddVpnPage stays wired at sub-page index 4 for when the service syncs.
    }
}
