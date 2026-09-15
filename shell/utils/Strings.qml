pragma Singleton

import QtQuick
import Quickshell

Singleton {
    property var _regexCache: ({})

    function testRegexList(filterList: list<string>, target: string): bool {
        const regexChecker = /^\^.*\$$/;
        for (const filter of filterList) {
            if (regexChecker.test(filter)) {
                let re = _regexCache[filter];
                if (!re) {
                    re = new RegExp(filter);
                    _regexCache[filter] = re;
                }
                if (re.test(target))
                    return true;
            } else {
                if (filter === target)
                    return true;
            }
        }
        return false;
    }

    // Returns Qt.RightToLeft for Arabic/Hebrew text, Qt.LeftToRight otherwise
    function textDirection(text: string): var {
        if (!text || text.length === 0)
            return Qt.LeftToRight;
        for (let i = 0; i < text.length; i++) {
            const code = text.charCodeAt(i);
            if (code < 0x0590 || code > 0x08FF) {
                if ((code >= 0x0600 && code <= 0x06FF) || (code >= 0x0750 && code <= 0x077F) || (code >= 0x08A0 && code <= 0x08FF) || (code >= 0xFB50 && code <= 0xFDFF) || (code >= 0xFE70 && code <= 0xFEFF))
                    return Qt.RightToLeft;
                if ((code >= 0x0590 && code <= 0x05FF) || (code >= 0xFB1D && code <= 0xFB4F))
                    return Qt.RightToLeft;
                return Qt.LeftToRight;
            }
        }
        return Qt.LeftToRight;
    }

    // Wraps text with Unicode directional override for proper RTL/LTR rendering
    function directionalText(text: string): string {
        if (!text || text.length === 0)
            return text;
        const dir = textDirection(text);
        if (dir === Qt.RightToLeft)
            return "\u202B" + text + "\u202C";
        return text;
    }

    // Formats a 0..1 ratio as a rounded percent string, e.g. 0.428 -> "43%"
    function percent(v: real): string {
        return Math.round(v * 100) + "%";
    }

    // Formats seconds as h:mm:ss (m:ss under an hour); negative -> "-1:-1"
    function clockDuration(s: int): string {
        if (s < 0)
            return "-1:-1";

        const hours = Math.floor(s / 3600);
        const mins = Math.floor((s % 3600) / 60);
        const secs = Math.floor(s % 60).toString().padStart(2, "0");

        if (hours > 0)
            return `${hours}:${mins.toString().padStart(2, "0")}:${secs}`;
        return `${mins}:${secs}`;
    }
}
