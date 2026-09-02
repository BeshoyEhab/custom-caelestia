pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Caelestia
import Caelestia.Config
import qs.components.misc
import qs.services
import qs.utils

Singleton {
    id: root

    property list<NotifData> list: []
    readonly property list<NotifData> notClosed: list.filter(n => !n.closed)
    readonly property list<NotifData> popups: list.filter(n => n.popup)
    property alias dnd: props.dnd

    property bool loaded
    property var rawNotifications: []
    property int loadedCount: 0
    readonly property bool hasMore: loadedCount < rawNotifications.length
    property int batchSize: 20

    function loadMore(): bool {
        if (!hasMore)
            return false;

        const end = Math.min(loadedCount + batchSize, rawNotifications.length);
        for (let i = loadedCount; i < end; i++)
            root.list.push(notifComp.createObject(root, rawNotifications[i]));
        root.list.sort((a, b) => b.time - a.time);
        loadedCount = end;
        return hasMore;
    }

    function hasFullscreen(): bool {
        for (const monitor of Hypr.monitors.values) {
            if (monitor?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1))
                return true;
        }
        return false;
    }

    function shouldShowPopup(): bool {
        if (props.dnd || [...Visibilities.screens.values()].some(v => v.sidebar))
            return false;
        if (GlobalConfig.notifs.fullscreen === "off" && hasFullscreen())
            return false;
        return true;
    }

    onDndChanged: {
        if (!GlobalConfig.utilities.toasts.dndChanged)
            return;

        if (dnd)
            Toaster.toast(qsTr("Do not disturb enabled"), qsTr("Popup notifications are now disabled"), "do_not_disturb_on");
        else
            Toaster.toast(qsTr("Do not disturb disabled"), qsTr("Popup notifications are now enabled"), "do_not_disturb_off");
    }

    onListChanged: {
        if (loaded)
            saveTimer.restart();
    }

    Timer {
        id: saveTimer

        interval: 1000
        onTriggered: {
            const loadedNotifs = root.notClosed.map(n => ({
                time: n.time, id: n.id, summary: n.summary, body: n.body,
                appIcon: n.appIcon, appName: n.appName, image: n.image,
                expireTimeout: n.expireTimeout, urgency: n.urgency,
                resident: n.resident, hasActionIcons: n.hasActionIcons, actions: n.actions
            }));
            const loadedIds = new Set(loadedNotifs.map(n => n.id));
            const unloaded = root.rawNotifications.slice(root.loadedCount).filter(n => !loadedIds.has(n.id));
            storage.setText(JSON.stringify([...loadedNotifs, ...unloaded]));
        }
    }

    PersistentProperties {
        id: props

        property bool dnd

        reloadableId: "notifs"
    }

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notif => {
            notif.tracked = true;

            const comp = notifComp.createObject(root, {
                popup: root.shouldShowPopup(),
                notification: notif
            });
            root.rawNotifications.unshift({
                time: Date.now(), id: notif.id, summary: comp.summary, body: comp.body,
                appIcon: comp.appIcon, appName: comp.appName, image: comp.image,
                expireTimeout: comp.expireTimeout, urgency: comp.urgency,
                resident: comp.resident, hasActionIcons: comp.hasActionIcons, actions: comp.actions
            });
            root.loadedCount++;
            root.list = [comp, ...root.list];
        }
    }

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.state}/notifs.json`
        onLoaded: {
            const data = JSON.parse(text());
            root.rawNotifications = data;
            const end = Math.min(root.batchSize, data.length);
            for (let i = 0; i < end; i++)
                root.list.push(notifComp.createObject(root, data[i]));
            root.list.sort((a, b) => b.time - a.time);
            root.loadedCount = end;
            root.loaded = true;
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.loaded = true;
                Qt.callLater(() => setText("[]"));
            }
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "clearNotifs"
        description: "Clear all notifications"
        onPressed: {
            for (const notif of root.list.slice())
                notif.close();
            root.rawNotifications = [];
            root.loadedCount = 0;
        }
    }

    IpcHandler {
        function clear(): void {
            for (const notif of root.list.slice())
                notif.close();
            root.rawNotifications = [];
            root.loadedCount = 0;
        }

        function isDndEnabled(): bool {
            return props.dnd;
        }

        function toggleDnd(): void {
            props.dnd = !props.dnd;
        }

        function enableDnd(): void {
            props.dnd = true;
        }

        function disableDnd(): void {
            props.dnd = false;
        }

        target: "notifs"
    }

    Component {
        id: notifComp

        NotifData {}
    }
}
