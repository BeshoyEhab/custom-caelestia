import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.services

// One widget instance inside its frame: creates the widget the validated
// registry item points at, stretches it when the item opted in via
// options.fillWidth, and reports failures through errorText instead of letting
// a bad widget take the whole host down.
Item {
    id: root

    required property var item
    required property var hostContext
    property string orientation: "vertical"

    readonly property string entryId: root.item?.type ?? ""

    readonly property alias widgetItem: created

    property string errorText: ""

    property var created: null

    function buildWidget(): void {
        if (root.created !== null || root.errorText !== "")
            return;

        try {
            const comp = WidgetCatalog.componentFor(root.item?.type ?? "");
            if (!comp) {
                root.errorText = "Unknown widget type: " + (root.item?.type ?? "");
                return;
            }
            root.created = comp.createObject(root, {
                item: root.item,
                host: root.hostContext,
                orientation: root.orientation
            });
            root.errorText = "";
        } catch (err) {
            root.created = null;
            root.errorText = "Widget failed to create: " + err;
        }
    }

    Component.onCompleted: root.buildWidget()

    Layout.alignment: root.orientation === "vertical" ? Qt.AlignHCenter : Qt.AlignVCenter

    Layout.fillWidth: root.item?.options?.fillWidth ?? false

    Binding {
        target: root.widgetItem
        property: "width"
        value: root.width
        when: root.widgetItem !== null && (root.item?.options?.fillWidth ?? false)
    }

    Text {
        id: errorLabel

        visible: root.errorText !== ""

        text: root.errorText

        color: Colours.palette.m3error
    }

    implicitWidth: root.errorText !== "" ? errorLabel.implicitWidth : (root.created ? root.created.implicitWidth : 0)

    implicitHeight: root.errorText !== "" ? errorLabel.implicitHeight : (root.created ? root.created.implicitHeight : 0)
}
