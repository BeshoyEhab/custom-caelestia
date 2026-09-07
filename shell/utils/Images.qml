pragma Singleton

import Quickshell

Singleton {
    readonly property list<string> validImageTypes: ["jpeg", "png", "webp", "tiff", "svg"]
    readonly property list<string> validImageExtensions: ["jpg", "jpeg", "png", "webp", "tif", "tiff", "svg"]
    readonly property list<string> validVideoExtensions: ["mp4", "webm", "mkv", "mov", "avi", "m4v"]

    function isValidImageByName(name: string): bool {
        return validImageExtensions.some(t => name.endsWith(`.${t}`));
    }

    function isVideoByName(name: string): bool {
        const lower = name.toLowerCase();
        return validVideoExtensions.some(t => lower.endsWith(`.${t}`));
    }

    function isVideo(path: string): bool {
        return isVideoByName(path);
    }
}
