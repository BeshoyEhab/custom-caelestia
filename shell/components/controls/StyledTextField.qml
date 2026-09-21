pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Caelestia.Config
import qs.components
import qs.services

TextField {
    id: root

    // Upstream sync (functional subset): validation + adornment props used by
    // the network sub-pages and already aliased by TextFieldRow. The
    // leading/trailing icon and supporting/error text visuals are still TODO
    // (upstream renders them in a 300-line rewrite); valid/isError work.
    property string leadingIcon
    property string trailingIcon
    property string supportingText
    property string errorText
    property bool isError
    property bool emptyIsValid: true
    property var validate // Regex or function
    readonly property bool valid: !validate || (!text && emptyIsValid) || (validate instanceof RegExp ? validate.test(text) : !!validate(text))

    color: Colours.palette.m3onSurface
    placeholderTextColor: Colours.palette.m3outline
    font: Tokens.font.body.small
    renderType: echoMode === TextField.Password ? TextField.QtRendering : TextField.NativeRendering
    cursorVisible: !readOnly

    background: null

    cursorDelegate: StyledRect {
        id: cursor

        property bool disableBlink

        implicitWidth: 2
        color: Colours.palette.m3primary
        radius: Tokens.rounding.large

        Connections {
            function onCursorPositionChanged(): void {
                if (root.activeFocus && root.cursorVisible) {
                    cursor.opacity = 1;
                    cursor.disableBlink = true;
                    enableBlink.restart();
                }
            }

            target: root
        }

        Timer {
            id: enableBlink

            interval: 100
            onTriggered: cursor.disableBlink = false
        }

        Timer {
            running: root.activeFocus && root.cursorVisible && !cursor.disableBlink
            repeat: true
            triggeredOnStart: true
            interval: 500
            onTriggered: parent.opacity = parent.opacity === 1 ? 0 : 1
        }

        Binding {
            when: !root.activeFocus || !root.cursorVisible
            cursor.opacity: 0
        }

        Behavior on opacity {
            Anim {
                type: Anim.StandardSmall
            }
        }
    }

    Behavior on color {
        CAnim {}
    }

    Behavior on placeholderTextColor {
        CAnim {}
    }
}
