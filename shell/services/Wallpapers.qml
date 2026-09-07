pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.Models
import qs.services
import qs.utils

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property string rotationTimestampPath: `${Paths.cache}/last_wallpaper_change`
    readonly property list<string> smartArg: (GlobalConfig.services.smartScheme && !GlobalConfig.services.forceMode) ? [] : ["--no-smart"]
    readonly property string fallback: Quickshell.shellPath("assets/wallpaper.webp")

    property bool showPreview: false
    readonly property string current: showPreview ? previewPath : actualCurrent
    property string previewPath
    property string actualCurrent
    property bool previewColourLock
    property bool pendingPreviewClear

    function getCategoryFor(w: FileSystemEntry): string {
        let category = w.parentDir.slice(Paths.wallsdir.length + 1);
        if (category.includes("/"))
            category = category.slice(0, category.indexOf("/"));
        return category;
    }

    function isVideo(path: string): bool {
        return Images.isVideo(path);
    }

    function thumbFor(path: string): string {
        const safe = path.replace(/^\//, "").replace(/[^A-Za-z0-9._-]+/g, "_");
        return `${Paths.cache}/wallpapers-video/${safe}.jpg`;
    }

    function shQuote(s: string): string {
        return `'${s.replace(/'/g, `'\\''`)}'`;
    }

    readonly property string colourSource: isVideo(current) ? thumbFor(current) : current

    function setRandom(): void {
        Quickshell.execDetached(["caelestia", "wallpaper", "-r", ...smartArg]);
    }

    function setWallpaper(path: string): void {
        if (isVideo(path)) {
            setVideoWallpaper(path);
            return;
        }
        actualCurrent = path;
        Quickshell.execDetached(["caelestia", "wallpaper", "-f", path, ...smartArg]);
    }

    function setVideoWallpaper(path: string): void {
        // `caelestia wallpaper -f` rejects video, so: extract a first-frame
        // thumbnail, theme from it via the regular CLI, then point the state
        // back at the video. The shell plays the video natively (looped,
        // muted); the brief poster shown meanwhile is the video's own first
        // frame. `actualCurrent` is left for the state FileView to update so
        // the UI only switches once the thumbnail + colours are ready.
        const thumb = thumbFor(path);
        const stateDir = `${Paths.state}/wallpaper`;
        const smart = smartArg.join(" ");
        const script = [`thumb=${shQuote(thumb)}`, `video=${shQuote(path)}`, `state=${shQuote(stateDir)}`, `mkdir -p "$(dirname "$thumb")"`, `ffmpeg -y -v error -i "$video" -vframes 1 -q:v 3 "$thumb" || exit 1`, `caelestia wallpaper -f "$thumb" ${smart}`, `printf '%s' "$video" > "$state/path.txt"`, `ln -sf "$video" "$state/current"`].join(" && ");
        Quickshell.execDetached(["sh", "-c", script]);
    }

    function preview(path: string): void {
        previewPath = path;
        showPreview = true;

        if (Colours.scheme === "dynamic") {
            if (isVideo(path))
                previewVideo(path);
            else
                getPreviewColoursProc.running = true;
        }
    }

    function previewVideo(path: string): void {
        const thumb = thumbFor(path);
        const smart = smartArg.join(" ");
        const script = [`thumb=${shQuote(thumb)}`, `video=${shQuote(path)}`, `mkdir -p "$(dirname "$thumb")"`, `[ -f "$thumb" ] || ffmpeg -y -v error -i "$video" -vframes 1 -q:v 3 "$thumb" || exit 0`, `caelestia wallpaper -p "$thumb" ${smart}`].join(" && ");
        videoPreviewColoursProc.command = ["sh", "-c", script];
        videoPreviewColoursProc.running = true;
    }

    function stopPreview(): void {
        showPreview = false;
        if (previewColourLock)
            pendingPreviewClear = true;
        else
            Colours.showPreview = false;
    }

    function checkRotation(): void {
        if (!GlobalConfig.background.wallpaperRotation)
            return;
        rotationCheckProc.running = true;
    }

    onPreviewColourLockChanged: {
        if (!previewColourLock && pendingPreviewClear)
            Colours.showPreview = false;
    }

    list: wallpapers.entries
    key: "relativePath"
    useFuzzy: GlobalConfig.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })

    IpcHandler {
        function get(): string {
            return root.actualCurrent;
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function list(): string {
            return root.list.map(w => w.path).join("\n");
        }

        target: "wallpaper"
    }

    FileView {
        path: root.currentNamePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let wall = text().trim();
            if (!wall) {
                wall = root.fallback;
                Quickshell.execDetached(["caelestia", "wallpaper", "-f", root.fallback, ...root.smartArg]);
            }
            root.actualCurrent = wall;
            root.previewColourLock = false;
        }
        onLoadFailed: {
            root.actualCurrent = root.fallback;
            root.previewColourLock = false;
            Quickshell.execDetached(["caelestia", "wallpaper", "-f", root.fallback, ...root.smartArg]);
        }
    }

    FileSystemModel {
        id: wallpapers

        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Files
        // NOTE: previously `Images` (QImageReader-based, excludes video).
        // Files + nameFilters keeps the image coverage (incl. gif, which the
        // CLI supports) while also listing looping video wallpapers.
        nameFilters: Images.validImageExtensions.concat(["gif", "bmp"], Images.validVideoExtensions).map(e => `*.${e}`)
    }

    Timer {
        id: rotationTimer

        interval: 60000
        running: GlobalConfig.background.wallpaperRotation
        repeat: true
        onTriggered: root.checkRotation()
        Component.onCompleted: {
            if (running)
                root.checkRotation();
        }
    }

    Process {
        id: rotationCheckProc

        property int intervalSeconds: GlobalConfig.background.wallpaperRotationInterval * 3600

        command: ["sh", "-c", `ts_file="${root.rotationTimestampPath}"; interval=${intervalSeconds}; now=$(date +%s); last=$(cat "$ts_file" 2>/dev/null || echo 0); if [ $((now - last)) -ge $interval ]; then mkdir -p "$(dirname "$ts_file")" && echo "$now" > "$ts_file" && echo "rotate"; fi`]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "rotate")
                    root.setRandom();
            }
        }
    }

    Process {
        id: getPreviewColoursProc

        command: ["caelestia", "wallpaper", "-p", root.previewPath, ...root.smartArg]
        stdout: StdioCollector {
            onStreamFinished: {
                Colours.load(text, true);
                Colours.showPreview = true;
            }
        }
    }

    Process {
        id: videoPreviewColoursProc

        stdout: StdioCollector {
            onStreamFinished: {
                // The ffmpeg/`-p` chain prints nothing on failure; only apply
                // the preview colours when we actually got scheme JSON back.
                const t = text.trim();
                if (t.startsWith("{")) {
                    Colours.load(t, true);
                    Colours.showPreview = true;
                }
            }
        }
    }
}
