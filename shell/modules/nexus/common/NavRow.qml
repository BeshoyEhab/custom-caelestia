import QtQuick
import Caelestia.Config
import qs.components
import qs.services

RowButton {
    id: root

    // Bridges: custom callers use label:/status:, upstream style uses text:/subtext:.
    // Plain-property + binding (not alias-to-alias) so either spelling works;
    // setting text:/subtext: directly replaces the binding, setting label:/status: flows through.
    property string label
    property string status

    text: root.label
    subtext: root.status
    trailingIcon: "chevron_right"
    subLabel.animate: true
}
