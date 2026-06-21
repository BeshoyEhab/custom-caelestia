pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Plugins")

    property var pluginStates: ({})

    readonly property list<var> plugins: [
        {
            name: "CopyQ",
            description: qsTr("Clipboard history manager"),
            icon: "content_paste",
            binaryName: "copyq",
            processName: "copyq"
        },
        {
            name: "Emote",
            description: qsTr("Emoji picker"),
            icon: "mood",
            binaryName: "emote",
            processName: "emote"
        },
        {
            name: "Pyprland",
            description: qsTr("Scratchpads, magnifier, corner helpers"),
            icon: "widgets",
            binaryName: "pypr",
            processName: "pypr"
        },
        {
            name: "Wayscriber",
            description: qsTr("Screen laser annotation tool"),
            icon: "draw",
            binaryName: "wayscriber",
            processName: "wayscriber"
        },
        {
            name: "Hyprland Per-Window Layout",
            description: qsTr("Automatic keyboard layout per window"),
            icon: "keyboard",
            binaryName: "hyprland-per-window-layout",
            processName: "hyprland-per-window-layout"
        },
        {
            name: "EasyEffects",
            description: qsTr("Audio effects and equalizer"),
            icon: "graphic_eq",
            binaryName: "easyeffects",
            processName: "easyeffects"
        },
        {
            name: "Tesseract OCR",
            description: qsTr("Optical character recognition from screenshots"),
            icon: "document_scanner",
            binaryName: "tesseract",
            processName: "tesseract"
        }
    ]

    function getStatusCheckCommand() {
        let cmd = "";
        for (let i = 0; i < plugins.length; i++) {
            let p = plugins[i];
            let bin = p.binaryName;
            let proc = p.processName;
            let procTrunc = proc.substring(0, 15);
            cmd += `${bin}:${procTrunc} `;
        }
        return `for pair in ${cmd.trim()}; do
            bin="\${pair%%:*}"
            proc="\${pair#*:}"
            if which "$bin" >/dev/null 2>&1; then
                if [ "$bin" = "tesseract" ]; then
                    echo "$bin:installed"
                elif pgrep -x "$proc" >/dev/null 2>&1; then
                    echo "$bin:activated"
                else
                    echo "$bin:installed"
                fi
            else
                echo "$bin:not_found"
            fi
        done`;
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Process {
            id: checker
            running: true
            command: ["sh", "-c", root.getStatusCheckCommand()]
            stdout: StdioCollector {
                onStreamFinished: {
                    let lines = text.split("\n");
                    let newStates = {};
                    for (let i = 0; i < lines.length; i++) {
                        let line = lines[i].trim();
                        if (!line) continue;
                        let parts = line.split(":");
                        if (parts.length === 2) {
                            newStates[parts[0]] = parts[1];
                        }
                    }
                    root.pluginStates = newStates;
                }
            }
        }

        SectionHeader {
            first: true
            text: qsTr("Plugins")
        }

        Repeater {
            model: root.plugins

            ConnectedRect {
                id: pluginRow
                Layout.fillWidth: true
                implicitHeight: pluginLayout.implicitHeight + pluginLayout.anchors.margins * 2
                first: index === 0
                last: index === root.plugins.length - 1

                required property var modelData
                required property int index

                readonly property string state: {
                    if (Object.keys(root.pluginStates).length === 0)
                        return "installed";
                    return root.pluginStates[modelData.binaryName] || "not_found";
                }
                readonly property bool isNotFound: state === "not_found"
                readonly property bool isActivated: state === "activated"

                RowLayout {
                    id: pluginLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: modelData.icon
                        color: !pluginRow.isNotFound ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3outline
                        fontStyle: Tokens.font.icon.medium
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.name
                            font: Tokens.font.body.small
                            color: !pluginRow.isNotFound ? Colours.palette.m3onSurface : Colours.palette.m3outline
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: pluginRow.isNotFound ? qsTr("Not installed") : modelData.description
                            color: pluginRow.isNotFound ? Colours.palette.m3error : Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    MaterialIcon {
                        text: pluginRow.isNotFound ? "info" : (pluginRow.isActivated ? "check_circle" : "check_circle_outline")
                        color: pluginRow.isNotFound ? Colours.palette.m3error : (pluginRow.isActivated ? Colours.palette.m3primary : Colours.palette.m3outline)
                        fontStyle: Tokens.font.icon.medium
                    }
                }
            }
        }

        SectionHeader {
            text: qsTr("Install new plugins")
        }

        InfoRow {
            first: true
            last: true
            label: qsTr("Additional plugins can be installed via the terminal.")
            value: qsTr("./install.sh")
        }
    }
}
