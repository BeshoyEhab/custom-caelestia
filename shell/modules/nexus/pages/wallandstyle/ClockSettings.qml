pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<string> clockStyleValues: ["digital", "cookie", "analog"]
    readonly property list<string> orientationValues: ["auto", "horizontal", "vertical"]
    readonly property list<string> dialValues: ["none", "dots", "full", "numbers"]
    readonly property list<string> hourHandValues: ["classic", "fill", "hollow", "hide"]
    readonly property list<string> minuteHandValues: ["classic", "thin", "medium", "bold", "hide"]
    readonly property list<string> secondHandValues: ["classic", "line", "dot", "hide"]
    readonly property list<string> dateStyleValues: ["bubble", "border", "rect", "hide"]

    readonly property bool isDigital: GlobalConfig.background.desktopClock.clockStyle === "digital"
    readonly property bool isCookie: GlobalConfig.background.desktopClock.clockStyle === "cookie"
    readonly property bool isAnalog: GlobalConfig.background.desktopClock.clockStyle === "analog"
    readonly property real rowGap: Tokens.spacing.extraSmall / 2

    function valueIndex(values, value, fallback) {
        const i = values.indexOf(value);
        return i >= 0 ? i : fallback;
    }

    function dialLabel(value) {
        if (value === "none")
            return qsTr("None");
        if (value === "dots")
            return qsTr("Dots");
        if (value === "numbers")
            return qsTr("Numbers");
        return qsTr("Full");
    }

    title: qsTr("Clock")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: root.rowGap

        // General
        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            text: qsTr("Desktop clock")
            subtext: qsTr("Show a clock on the wallpaper")
            checked: GlobalConfig.background.desktopClock.enabled
            onToggled: GlobalConfig.background.desktopClock.enabled = checked
        }

        SelectRow {
            Layout.topMargin: -root.rowGap
            label: qsTr("Clock style")
            subtext: root.isCookie ? qsTr("Cookie (Android)") : root.isAnalog ? qsTr("Analog") : qsTr("Digital")
            menuOnTop: true
            menuItems: [
                MenuItem {
                    text: qsTr("Digital")
                    icon: GlobalConfig.background.desktopClock.clockStyle === "digital" ? "check" : ""
                    activeIcon: "schedule"
                },
                MenuItem {
                    text: qsTr("Cookie (Android)")
                    icon: GlobalConfig.background.desktopClock.clockStyle === "cookie" ? "check" : ""
                    activeIcon: "cookie"
                },
                MenuItem {
                    text: qsTr("Analog")
                    icon: GlobalConfig.background.desktopClock.clockStyle === "analog" ? "check" : ""
                    activeIcon: "watch"
                }
            ]
            active: menuItems[root.valueIndex(root.clockStyleValues, GlobalConfig.background.desktopClock.clockStyle, 0)]
            onSelected: item => {
                const idx = menuItems.indexOf(item);
                if (idx >= 0)
                    GlobalConfig.background.desktopClock.clockStyle = root.clockStyleValues[idx];
            }
        }

        SliderRow {
            Layout.topMargin: -root.rowGap
            label: qsTr("Scale")
            valueLabel: `×${GlobalConfig.background.desktopClock.scale.toFixed(1)}`
            value: (GlobalConfig.background.desktopClock.scale - 0.5) / 1.5
            onMoved: v => GlobalConfig.background.desktopClock.scale = 0.5 + v * 1.5
        }

        ToggleRow {
            Layout.topMargin: -root.rowGap
            text: qsTr("Animate position")
            subtext: qsTr("Slide the clock when it moves or the wallpaper changes")
            checked: GlobalConfig.background.desktopClock.animatePosition
            onToggled: GlobalConfig.background.desktopClock.animatePosition = checked
        }

        ToggleRow {
            Layout.topMargin: -root.rowGap
            text: qsTr("Invert colours")
            subtext: qsTr("Use the opposite palette set for the clock")
            checked: GlobalConfig.background.desktopClock.invertColors
            onToggled: GlobalConfig.background.desktopClock.invertColors = checked
        }

        ToggleRow {
            Layout.topMargin: -root.rowGap
            last: !GlobalConfig.background.desktopClock.quote.enabled
            text: qsTr("Quote")
            subtext: qsTr("Show a short quote below the clock")
            checked: GlobalConfig.background.desktopClock.quote.enabled
            onToggled: GlobalConfig.background.desktopClock.quote.enabled = checked
        }

        TextFieldRow {
            Layout.topMargin: -root.rowGap
            last: true
            visible: GlobalConfig.background.desktopClock.quote.enabled
            label: qsTr("Quote text")
            subtext: qsTr("Shown below the clock and wrapped to its width")
            placeholderText: qsTr("A short line")
            value: GlobalConfig.background.desktopClock.quote.text
            onEditingFinished: text => GlobalConfig.background.desktopClock.quote.text = text
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            Layout.leftMargin: Tokens.padding.small
            text: qsTr("Drag the clock to move it. Double-click it to reset.")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
            wrapMode: Text.Wrap
        }

        // Backdrop
        SectionHeader {
            visible: root.isDigital || root.isCookie
            text: qsTr("Backdrop")
        }

        ToggleRow {
            visible: root.isDigital
            first: true
            text: qsTr("Plate")
            subtext: qsTr("Surface behind the clock")
            checked: GlobalConfig.background.desktopClock.background.enabled
            onToggled: GlobalConfig.background.desktopClock.background.enabled = checked
        }

        SliderRow {
            visible: root.isDigital
            Layout.topMargin: -root.rowGap
            label: qsTr("Plate opacity")
            valueLabel: `${Math.round(GlobalConfig.background.desktopClock.background.opacity * 100)}%`
            value: GlobalConfig.background.desktopClock.background.opacity
            enabled: GlobalConfig.background.desktopClock.background.enabled
            onMoved: v => GlobalConfig.background.desktopClock.background.opacity = v
        }

        ToggleRow {
            visible: root.isDigital
            Layout.topMargin: -root.rowGap
            text: qsTr("Blur wallpaper behind plate")
            subtext: qsTr("Frosted glass effect")
            checked: GlobalConfig.background.desktopClock.background.blur
            onToggled: GlobalConfig.background.desktopClock.background.blur = checked
            enabled: GlobalConfig.background.desktopClock.background.enabled
        }

        ToggleRow {
            visible: root.isDigital || root.isCookie
            first: !root.isDigital
            Layout.topMargin: root.isDigital ? -root.rowGap : 0
            text: qsTr("Shadow")
            subtext: qsTr("Drop shadow behind the clock")
            checked: GlobalConfig.background.desktopClock.shadow.enabled
            onToggled: GlobalConfig.background.desktopClock.shadow.enabled = checked
        }

        SliderRow {
            visible: root.isDigital || root.isCookie
            Layout.topMargin: -root.rowGap
            label: qsTr("Shadow opacity")
            valueLabel: `${Math.round(GlobalConfig.background.desktopClock.shadow.opacity * 100)}%`
            value: GlobalConfig.background.desktopClock.shadow.opacity
            enabled: GlobalConfig.background.desktopClock.shadow.enabled
            onMoved: v => GlobalConfig.background.desktopClock.shadow.opacity = v
        }

        SliderRow {
            visible: root.isDigital || root.isCookie
            Layout.topMargin: -root.rowGap
            last: true
            label: qsTr("Shadow blur")
            valueLabel: `${Math.round(GlobalConfig.background.desktopClock.shadow.blur * 100)}%`
            value: GlobalConfig.background.desktopClock.shadow.blur
            enabled: GlobalConfig.background.desktopClock.shadow.enabled
            onMoved: v => GlobalConfig.background.desktopClock.shadow.blur = v
        }

        // Digital
        SectionHeader {
            visible: root.isDigital
            text: qsTr("Digital")
        }

        SelectRow {
            visible: root.isDigital
            first: true
            label: qsTr("Orientation")
            subtext: GlobalConfig.background.desktopClock.digital.orientation === "auto" ? qsTr("Follow the clock's screen position") : GlobalConfig.background.desktopClock.digital.orientation === "horizontal" ? qsTr("Horizontal") : qsTr("Vertical")
            menuOnTop: true
            menuItems: [
                MenuItem {
                    text: qsTr("Auto")
                    icon: GlobalConfig.background.desktopClock.digital.orientation === "auto" ? "check" : ""
                    activeIcon: "auto_awesome"
                },
                MenuItem {
                    text: qsTr("Horizontal")
                    icon: GlobalConfig.background.desktopClock.digital.orientation === "horizontal" ? "check" : ""
                    activeIcon: "swap_horiz"
                },
                MenuItem {
                    text: qsTr("Vertical")
                    icon: GlobalConfig.background.desktopClock.digital.orientation === "vertical" ? "check" : ""
                    activeIcon: "swap_vert"
                }
            ]
            active: menuItems[root.valueIndex(root.orientationValues, GlobalConfig.background.desktopClock.digital.orientation, 0)]
            onSelected: item => {
                const idx = menuItems.indexOf(item);
                if (idx >= 0)
                    GlobalConfig.background.desktopClock.digital.orientation = root.orientationValues[idx];
            }
        }

        ToggleRow {
            visible: root.isDigital
            Layout.topMargin: -root.rowGap
            text: qsTr("Show date")
            checked: GlobalConfig.background.desktopClock.digital.showDate
            onToggled: GlobalConfig.background.desktopClock.digital.showDate = checked
        }

        ToggleRow {
            visible: root.isDigital
            Layout.topMargin: -root.rowGap
            text: qsTr("Show seconds")
            checked: GlobalConfig.background.desktopClock.digital.showSeconds
            onToggled: GlobalConfig.background.desktopClock.digital.showSeconds = checked
        }

        ToggleRow {
            visible: root.isDigital
            Layout.topMargin: -root.rowGap
            text: qsTr("Animate time change")
            checked: GlobalConfig.background.desktopClock.digital.animateChange
            onToggled: GlobalConfig.background.desktopClock.digital.animateChange = checked
        }

        ToggleRow {
            visible: root.isDigital
            Layout.topMargin: -root.rowGap
            text: qsTr("Adaptive alignment")
            subtext: qsTr("Align the date with the clock's screen third")
            checked: GlobalConfig.background.desktopClock.digital.adaptiveAlignment
            onToggled: GlobalConfig.background.desktopClock.digital.adaptiveAlignment = checked
        }

        TextFieldRow {
            visible: root.isDigital
            Layout.topMargin: -root.rowGap
            label: qsTr("Font family")
            subtext: qsTr("Leave blank to use the theme font")
            placeholderText: qsTr("Theme default")
            value: GlobalConfig.background.desktopClock.digital.font.family
            onEditingFinished: text => GlobalConfig.background.desktopClock.digital.font.family = text
        }

        SliderRow {
            visible: root.isDigital
            Layout.topMargin: -root.rowGap
            label: qsTr("Font weight")
            valueLabel: `${GlobalConfig.background.desktopClock.digital.font.weight}`
            value: (GlobalConfig.background.desktopClock.digital.font.weight - 1) / 999
            onMoved: v => GlobalConfig.background.desktopClock.digital.font.weight = Math.round(1 + v * 999)
        }

        SliderRow {
            visible: root.isDigital
            Layout.topMargin: -root.rowGap
            label: qsTr("Text size")
            valueLabel: `×${GlobalConfig.background.desktopClock.digital.font.size.toFixed(1)}`
            value: (GlobalConfig.background.desktopClock.digital.font.size - 0.5) / 1.5
            onMoved: v => GlobalConfig.background.desktopClock.digital.font.size = 0.5 + v * 1.5
        }

        SliderRow {
            visible: root.isDigital
            Layout.topMargin: -root.rowGap
            label: qsTr("Font width")
            subtext: qsTr("Variable font width axis")
            valueLabel: `${GlobalConfig.background.desktopClock.digital.font.width}`
            value: (GlobalConfig.background.desktopClock.digital.font.width - 25) / 100
            onMoved: v => GlobalConfig.background.desktopClock.digital.font.width = Math.round(25 + v * 100)
        }

        SliderRow {
            visible: root.isDigital
            Layout.topMargin: -root.rowGap
            last: true
            label: qsTr("Font roundness")
            subtext: qsTr("Variable font roundness axis")
            valueLabel: `${GlobalConfig.background.desktopClock.digital.font.roundness}%`
            value: GlobalConfig.background.desktopClock.digital.font.roundness / 100
            onMoved: v => GlobalConfig.background.desktopClock.digital.font.roundness = Math.round(v * 100)
        }

        // Cookie
        SectionHeader {
            visible: root.isCookie
            text: qsTr("Cookie")
        }

        ToggleRow {
            visible: root.isCookie
            first: true
            text: qsTr("Sine cookie")
            subtext: qsTr("Smooth sine-wave outline instead of the star cookie")
            checked: GlobalConfig.background.desktopClock.cookie.useSineCookie
            onToggled: GlobalConfig.background.desktopClock.cookie.useSineCookie = checked
        }

        StepperRow {
            visible: root.isCookie
            Layout.topMargin: -root.rowGap
            label: qsTr("Sides")
            subtext: qsTr("Points on the cookie outline")
            value: GlobalConfig.background.desktopClock.cookie.sides
            from: 4
            to: 40
            stepSize: 1
            onMoved: v => GlobalConfig.background.desktopClock.cookie.sides = v
        }

        ToggleRow {
            visible: root.isCookie
            Layout.topMargin: -root.rowGap
            text: qsTr("Constant rotation")
            subtext: qsTr("Rotate the cookie outline continuously (extra GPU)")
            checked: GlobalConfig.background.desktopClock.cookie.constantlyRotate
            onToggled: GlobalConfig.background.desktopClock.cookie.constantlyRotate = checked
        }

        ToggleRow {
            visible: root.isCookie
            Layout.topMargin: -root.rowGap
            text: qsTr("Date inside clock")
            subtext: qsTr("Show the date on the face instead of below it")
            checked: GlobalConfig.background.desktopClock.cookie.dateInClock
            onToggled: GlobalConfig.background.desktopClock.cookie.dateInClock = checked
        }

        ToggleRow {
            visible: root.isCookie
            Layout.topMargin: -root.rowGap
            text: qsTr("Hour marks")
            subtext: qsTr("Inner ring of 12 marks")
            checked: GlobalConfig.background.desktopClock.cookie.hourMarks
            enabled: GlobalConfig.background.desktopClock.cookie.dialNumberStyle === "dots" || GlobalConfig.background.desktopClock.cookie.dialNumberStyle === "full"
            onToggled: GlobalConfig.background.desktopClock.cookie.hourMarks = checked
        }

        ToggleRow {
            visible: root.isCookie
            Layout.topMargin: -root.rowGap
            text: qsTr("Centre digits")
            subtext: qsTr("Hour and minute in the middle of the face")
            checked: GlobalConfig.background.desktopClock.cookie.timeIndicators
            enabled: GlobalConfig.background.desktopClock.cookie.dialNumberStyle !== "numbers"
            onToggled: GlobalConfig.background.desktopClock.cookie.timeIndicators = checked
        }

        SelectRow {
            visible: root.isCookie
            Layout.topMargin: -root.rowGap
            label: qsTr("Dial style")
            subtext: root.dialLabel(GlobalConfig.background.desktopClock.cookie.dialNumberStyle)
            menuOnTop: true
            menuItems: [
                MenuItem {
                    text: qsTr("None")
                    icon: GlobalConfig.background.desktopClock.cookie.dialNumberStyle === "none" ? "check" : ""
                    activeIcon: "block"
                },
                MenuItem {
                    text: qsTr("Dots")
                    icon: GlobalConfig.background.desktopClock.cookie.dialNumberStyle === "dots" ? "check" : ""
                    activeIcon: "more_horiz"
                },
                MenuItem {
                    text: qsTr("Full")
                    icon: GlobalConfig.background.desktopClock.cookie.dialNumberStyle === "full" ? "check" : ""
                    activeIcon: "schedule"
                },
                MenuItem {
                    text: qsTr("Numbers")
                    icon: GlobalConfig.background.desktopClock.cookie.dialNumberStyle === "numbers" ? "check" : ""
                    activeIcon: "pin"
                }
            ]
            active: menuItems[root.valueIndex(root.dialValues, GlobalConfig.background.desktopClock.cookie.dialNumberStyle, 2)]
            onSelected: item => {
                const idx = menuItems.indexOf(item);
                if (idx < 0)
                    return;
                const value = root.dialValues[idx];
                GlobalConfig.background.desktopClock.cookie.dialNumberStyle = value;
                if (value === "numbers")
                    GlobalConfig.background.desktopClock.cookie.timeIndicators = false;
                if (value !== "dots" && value !== "full")
                    GlobalConfig.background.desktopClock.cookie.hourMarks = false;
            }
        }

        SelectRow {
            visible: root.isCookie
            Layout.topMargin: -root.rowGap
            label: qsTr("Hour hand")
            menuOnTop: true
            menuItems: [
                MenuItem {
                    text: qsTr("Classic")
                    icon: GlobalConfig.background.desktopClock.cookie.hourHandStyle === "classic" ? "check" : ""
                    activeIcon: "horizontal_rule"
                },
                MenuItem {
                    text: qsTr("Fill")
                    icon: GlobalConfig.background.desktopClock.cookie.hourHandStyle === "fill" ? "check" : ""
                    activeIcon: "width_full"
                },
                MenuItem {
                    text: qsTr("Hollow")
                    icon: GlobalConfig.background.desktopClock.cookie.hourHandStyle === "hollow" ? "check" : ""
                    activeIcon: "crop_square"
                },
                MenuItem {
                    text: qsTr("Hide")
                    icon: GlobalConfig.background.desktopClock.cookie.hourHandStyle === "hide" ? "check" : ""
                    activeIcon: "visibility_off"
                }
            ]
            active: menuItems[root.valueIndex(root.hourHandValues, GlobalConfig.background.desktopClock.cookie.hourHandStyle, 1)]
            onSelected: item => {
                const idx = menuItems.indexOf(item);
                if (idx >= 0)
                    GlobalConfig.background.desktopClock.cookie.hourHandStyle = root.hourHandValues[idx];
            }
        }

        SelectRow {
            visible: root.isCookie
            Layout.topMargin: -root.rowGap
            label: qsTr("Minute hand")
            menuOnTop: true
            menuItems: [
                MenuItem {
                    text: qsTr("Classic")
                    icon: GlobalConfig.background.desktopClock.cookie.minuteHandStyle === "classic" ? "check" : ""
                    activeIcon: "horizontal_rule"
                },
                MenuItem {
                    text: qsTr("Thin")
                    icon: GlobalConfig.background.desktopClock.cookie.minuteHandStyle === "thin" ? "check" : ""
                    activeIcon: "remove"
                },
                MenuItem {
                    text: qsTr("Medium")
                    icon: GlobalConfig.background.desktopClock.cookie.minuteHandStyle === "medium" ? "check" : ""
                    activeIcon: "width_normal"
                },
                MenuItem {
                    text: qsTr("Bold")
                    icon: GlobalConfig.background.desktopClock.cookie.minuteHandStyle === "bold" ? "check" : ""
                    activeIcon: "width_full"
                },
                MenuItem {
                    text: qsTr("Hide")
                    icon: GlobalConfig.background.desktopClock.cookie.minuteHandStyle === "hide" ? "check" : ""
                    activeIcon: "visibility_off"
                }
            ]
            active: menuItems[root.valueIndex(root.minuteHandValues, GlobalConfig.background.desktopClock.cookie.minuteHandStyle, 2)]
            onSelected: item => {
                const idx = menuItems.indexOf(item);
                if (idx >= 0)
                    GlobalConfig.background.desktopClock.cookie.minuteHandStyle = root.minuteHandValues[idx];
            }
        }

        SelectRow {
            visible: root.isCookie
            Layout.topMargin: -root.rowGap
            label: qsTr("Second hand")
            menuOnTop: true
            menuItems: [
                MenuItem {
                    text: qsTr("Classic")
                    icon: GlobalConfig.background.desktopClock.cookie.secondHandStyle === "classic" ? "check" : ""
                    activeIcon: "horizontal_rule"
                },
                MenuItem {
                    text: qsTr("Line")
                    icon: GlobalConfig.background.desktopClock.cookie.secondHandStyle === "line" ? "check" : ""
                    activeIcon: "remove"
                },
                MenuItem {
                    text: qsTr("Dot")
                    icon: GlobalConfig.background.desktopClock.cookie.secondHandStyle === "dot" ? "check" : ""
                    activeIcon: "circle"
                },
                MenuItem {
                    text: qsTr("Hide")
                    icon: GlobalConfig.background.desktopClock.cookie.secondHandStyle === "hide" ? "check" : ""
                    activeIcon: "visibility_off"
                }
            ]
            active: menuItems[root.valueIndex(root.secondHandValues, GlobalConfig.background.desktopClock.cookie.secondHandStyle, 2)]
            onSelected: item => {
                const idx = menuItems.indexOf(item);
                if (idx >= 0)
                    GlobalConfig.background.desktopClock.cookie.secondHandStyle = root.secondHandValues[idx];
            }
        }

        SelectRow {
            visible: root.isCookie
            Layout.topMargin: -root.rowGap
            last: true
            label: qsTr("Date style")
            menuOnTop: true
            menuItems: [
                MenuItem {
                    text: qsTr("Bubble")
                    icon: GlobalConfig.background.desktopClock.cookie.dateStyle === "bubble" ? "check" : ""
                    activeIcon: "chat_bubble"
                },
                MenuItem {
                    text: qsTr("Border")
                    icon: GlobalConfig.background.desktopClock.cookie.dateStyle === "border" ? "check" : ""
                    activeIcon: "data_usage"
                },
                MenuItem {
                    text: qsTr("Rect")
                    icon: GlobalConfig.background.desktopClock.cookie.dateStyle === "rect" ? "check" : ""
                    activeIcon: "crop_square"
                },
                MenuItem {
                    text: qsTr("Hide")
                    icon: GlobalConfig.background.desktopClock.cookie.dateStyle === "hide" ? "check" : ""
                    activeIcon: "visibility_off"
                }
            ]
            active: menuItems[root.valueIndex(root.dateStyleValues, GlobalConfig.background.desktopClock.cookie.dateStyle, 0)]
            onSelected: item => {
                const idx = menuItems.indexOf(item);
                if (idx >= 0)
                    GlobalConfig.background.desktopClock.cookie.dateStyle = root.dateStyleValues[idx];
            }
        }

        // Analog
        SectionHeader {
            visible: root.isAnalog
            text: qsTr("Analog")
        }

        StyledText {
            visible: root.isAnalog
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.rightMargin: Tokens.padding.small
            text: qsTr("The analog clock uses the theme colours and follows the system time. It has no extra appearance knobs.")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
            wrapMode: Text.Wrap
        }
    }
}
