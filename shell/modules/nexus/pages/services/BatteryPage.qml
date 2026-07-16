import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Battery")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Warning levels")
        }

        StepperRow {
            first: true
            label: qsTr("Low battery warning")
            subtext: qsTr("Show a warning when battery drops below this level (%%)")
            value: GlobalConfig.general.battery.warningLevel
            from: 5
            to: 50
            stepSize: 1
            onMoved: v => GlobalConfig.general.battery.warningLevel = Math.round(v)
        }

        StepperRow {
            last: true
            label: qsTr("Critical battery warning")
            subtext: qsTr("Show an urgent alert when battery drops below this level (%%)")
            value: GlobalConfig.general.battery.criticalLevel
            from: 1
            to: 30
            stepSize: 1
            onMoved: v => GlobalConfig.general.battery.criticalLevel = Math.round(v)
        }

        SectionHeader {
            text: qsTr("Auto actions")
        }

        StepperRow {
            last: true
            label: qsTr("Hibernate level")
            subtext: qsTr("Automatically hibernate when battery drops below this level (%%)")
            value: GlobalConfig.general.battery.hibernateLevel
            from: 1
            to: 10
            stepSize: 1
            onMoved: v => GlobalConfig.general.battery.hibernateLevel = Math.round(v)
        }
    }
}
