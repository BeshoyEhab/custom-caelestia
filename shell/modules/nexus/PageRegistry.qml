pragma Singleton

import QtQuick

QtObject {
    id: root

    readonly property list<var> pages: [
        // Appearance
        {
            label: qsTr("Wallpaper & style"),
            icon: "palette",
            description: qsTr("Wallpaper, fonts, colours"),
            category: "appearance",
            keywords: "wallpaper theme colour color font transparency light dark mode video visualiser visualizer clock rotation"
        },

        // Connectivity
        // TODO
        // {
        //     label: qsTr("Display"),
        //     icon: "monitor",
        //     description: qsTr("Output configuration"),
        //     category: "connectivity"
        // },
        {
            label: qsTr("Network"),
            icon: "wifi",
            description: qsTr("Wi-Fi, ethernet, VPN"),
            category: "connectivity",
            keywords: "wifi ethernet vpn dns ip address saved hidden"
        },
        {
            label: qsTr("Connected devices"),
            icon: "devices_other",
            description: qsTr("Bluetooth, pairing"),
            category: "connectivity",
            noFill: true,
            keywords: "bluetooth pairing device"
        },
        {
            label: qsTr("Audio"),
            icon: "volume_up",
            description: qsTr("App volumes, sound devices"),
            category: "connectivity",
            keywords: "volume speaker microphone mic input output sound"
        },

        // System
        {
            label: qsTr("Updates"),
            icon: "update",
            description: qsTr("System updates"),
            category: "system",
            keywords: "update upgrade repository deploy reload"
        },
        {
            label: qsTr("Plugins"),
            icon: "extension",
            description: qsTr("Manage plugins"),
            category: "system",
            keywords: "plugin extension install"
        },
        {
            label: qsTr("Screen lock"),
            icon: "lock",
            description: qsTr("Lock, screen-off and suspend timers"),
            category: "system",
            keywords: "lock idle suspend sleep timeout password"
        },

        // Shell
        {
            label: qsTr("Panels"),
            icon: "dock_to_bottom",
            description: qsTr("Dashboard, taskbar, launcher, sidebar"),
            category: "shell",
            keywords: "dashboard taskbar launcher sidebar bar workspaces clock tray utilities hover panel"
        },
        {
            label: qsTr("Apps"),
            icon: "apps",
            description: qsTr("Default apps, favourites, hidden apps"),
            category: "shell",
            keywords: "default terminal browser favourites favorites hidden"
        },
        {
            label: qsTr("Services"),
            icon: "build",
            description: qsTr("Poll intervals, lyrics backend"),
            category: "shell",
            keywords: "poll interval lyrics gpu battery notification"
        },
        {
            label: qsTr("Language & region"),
            icon: "globe",
            description: qsTr("UI language, weather location, display units"),
            category: "shell",
            keywords: "locale language weather location celsius clock format units"
        },

        // About
        {
            label: qsTr("About"),
            icon: "info",
            description: qsTr("System information, credits"),
            category: "about",
            keywords: "version system info credits"
        },
    ]
}
