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
}
