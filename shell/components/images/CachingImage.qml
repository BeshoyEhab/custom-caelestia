import QtQuick
import Quickshell
import Caelestia.Images

Image {
    id: root

    property string path

    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    source: IUtils.urlForPath(path, fillMode)
    sourceSize: {
        const dpr = (QsWindow.window as QsWindow)?.devicePixelRatio ?? 1;
        // Quantized to even pixels: subpixel width/height changes (drags,
        // resizes) must not each trigger a full image re-decode.
        const w = Math.max(2, Math.round(width * dpr / 2) * 2);
        const h = Math.max(2, Math.round(height * dpr / 2) * 2);
        return Qt.size(w, h);
    }
}
