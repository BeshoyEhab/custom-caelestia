import QtQuick
import Quickshell
import Quickshell.Bluetooth

QtObject {
    property ShellScreen screen
    property bool isWindow
    property bool animatingContainer
    property int currentPageIdx
    property var subPageIdxStack: []
    property bool searchOpen

    property string selectedWallpaperCategory
    property BluetoothDevice selectedBtDevice
    property var selectedNetwork
    property DesktopEntry selectedApp

    signal close
    signal subPageOpened(idx: int)
    signal subPageClosed

    function openSubPage(idx: int): void {
        subPageIdxStack = [...subPageIdxStack, idx];
        subPageOpened(idx);
    }

    function closeSubPage(): void {
        subPageClosed();
        subPageIdxStack = subPageIdxStack.slice(0, -1);
    }

    onCurrentPageIdxChanged: subPageIdxStack = []
}
