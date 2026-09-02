import QtQuick

QtObject {
    property string currentName
    property bool hasCurrent
    property int workspacePreviewId
    property string workspacePreviewName

    signal detachRequested(mode: string)
}
