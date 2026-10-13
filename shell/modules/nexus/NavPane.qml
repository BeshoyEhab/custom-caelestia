import "navpane"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.nexus

ColumnLayout {
    id: root

    required property NexusState nState

    spacing: Tokens.spacing.large

    SearchBar {
        Layout.fillWidth: true
        nState: root.nState
    }

    // No negative Layout margins here: they cancelled the column spacing and
    // put the nav list flush against the searchbar, so scrolled rows clipped
    // right at the searchbar's bottom edge and stole mis-aimed clicks.
    NavLocations {
        Layout.fillWidth: true
        Layout.fillHeight: true
        nState: root.nState
    }
}
