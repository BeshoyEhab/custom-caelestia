pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var builtinIcons: ({
            lockStatus: qsTr("Lock keys"),
            kbLayout: qsTr("Keyboard layout"),
            audio: qsTr("Speakers"),
            microphone: qsTr("Microphone"),
            network: qsTr("Network"),
            bluetooth: qsTr("Bluetooth"),
            battery: qsTr("Battery")
        })

    function labelForId(id: string): string {
        const pretty = root.builtinIcons[id];
        if (pretty)
            return pretty;
        const label = id.replace(/([A-Z])/g, " $1");
        return label.charAt(0).toUpperCase() + label.slice(1).toLowerCase();
    }

    // Old-framework QVariantList is a plain JS array: no .values/.at/.insert/
    // .move/.remove, so every mutation copies the list and assigns it back.
    function entries(): var {
        return ((GlobalConfig.bar.status.statusIcons ?? []).map(e => ({
                        id: e.id,
                        enabled: e.enabled
                    })));
    }

    function moveEntry(from: int, to: int): void {
        const list = root.entries();
        const moved = list.splice(from, 1);
        if (moved.length > 0)
            list.splice(to, 0, moved[0]);
        GlobalConfig.bar.status.statusIcons = list;
    }

    function removeEntry(index: int): void {
        const list = root.entries();
        list.splice(index, 1);
        GlobalConfig.bar.status.statusIcons = list;
    }

    function setEntryEnabled(index: int, checked: bool): void {
        const list = root.entries();
        if (index >= 0 && index < list.length)
            list[index].enabled = checked;
        GlobalConfig.bar.status.statusIcons = list;
    }

    title: qsTr("Status icons")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Visible icons
        SectionHeader {
            first: true
            text: qsTr("Visible icons")
        }

        ListEditor {
            function labelFor(item: var): string {
                return root.labelForId(item.id);
            }

            function toggledFor(item: var): bool {
                return item.enabled;
            }

            z: 1
            first: true
            values: Config.bar.status.statusIcons ?? []
            onItemMoved: (from, to) => root.moveEntry(from, to)
            onItemRemoved: index => root.removeEntry(index)
            onItemToggled: (index, checked) => root.setEntryEnabled(index, checked)
        }

        // Behaviour
        SectionHeader {
            text: qsTr("Behaviour")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Popout on hover")
            subtext: qsTr("Show a details popout when hovering the status icons")
            checked: Config.bar.popouts.statusIcons
            onToggled: GlobalConfig.bar.popouts.statusIcons = checked
        }
    }
}
