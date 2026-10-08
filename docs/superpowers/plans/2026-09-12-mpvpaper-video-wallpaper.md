# mpvpaper Video Wallpaper Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Play video wallpapers in mpvpaper instead of in-process QtMultimedia, cutting ~1.1 GB shell RAM, with QS Video as automatic fallback.

**Architecture:** New `services/VideoWallpaper.qml` singleton owns the mpvpaper lifecycle and reconciles it against `Wallpapers.actualCurrent` plus four new `BackgroundConfig` keys; `Wallpaper.qml`/`Background.qml` yield the layer when external playback is active; theming flow untouched.

**Tech Stack:** QML/Quickshell (`Process`, `IpcHandler`, `Quickshell.execDetached`), C++ Qt config plugin (`CONFIG_PROPERTY`), mpvpaper 1.9 CLI, bash (`install.sh`, restore script).

**Spec:** `docs/superpowers/specs/2026-09-12-mpvpaper-video-wallpaper-design.md`

## Global Constraints

- Edit QML in BOTH `<repo>/shell/` and `~/.config/quickshell/caelestia/` (real dir, not a symlink); verify with `diff -r` per task.
- Never touch `shell/upstream/` (vendored reference copy).
- New config keys need defaults so old `shell.json` files keep working.
- Static wallpapers always render in QS regardless of backend.
- `pragma ComponentBehavior: Bound` must NOT be added to `Bar.qml`-style loader files you touch (not applicable here, but do not add it anywhere new).
- Every QML file using `Colours.palette.*` must keep `import qs.services`.

---

## File map

| File | Responsibility |
|---|---|
| `shell/plugin/src/Caelestia/Config/backgroundconfig.hpp` | 4 new `CONFIG_PROPERTY` keys + `#include <qvariant.h>` if needed |
| `shell/services/VideoWallpaper.qml` (new) | Binary check, reconcile, spawn/kill, `IpcHandler target: "videoWallpaper"` |
| `shell/modules/background/Wallpaper.qml` | Gate internal `Video` on `!VideoWallpaper.externalActive` |
| `shell/modules/background/Background.qml` | Transparent + `Bottom` layer when `VideoWallpaper.externalActive` |
| `shell/modules/nexus/pages/WallpaperAndStyle.qml` | Backend `SelectRow` + auto-stop/auto-mode rows |
| `install.sh` (`deploy_core`, "Tools the shell uses") | `install_pkg mpvpaper true` (AUR, same as `emote true`) |
| `shell/README.md` (config reference ~line 389) | Document the 4 new keys |
| `~/.config/hypr/custom/scripts/__restore_video_wallpaper.sh` (generated file) | Restore hook calling the new IPC target |

Precedents to copy: `CONFIG_PROPERTY(QVariantMap, vaxes, {})` in `appearanceconfig.hpp:139` (map-type key); `availCommand: ["sh", "-c", "command -v howdy"]` in `shell/upstream/modules/lock/Pam.qml:140` (binary check); `IpcHandler { ... target: "wallpaper" }` in `shell/services/Wallpapers.qml:170-184` (IPC pattern); `Process` + `StdioCollector` in `Wallpapers.qml:246-289`.

---

### Task 1: BackgroundConfig video keys + plugin rebuild

**Files:**
- Modify: `shell/plugin/src/Caelestia/Config/backgroundconfig.hpp`
- Test: `~/.config/caelestia/shell.json` (new keys appear with defaults after reload)

**Interfaces:**
- Produces: `Config.background.videoBackend` (QString `"mpvpaper"`), `Config.background.videoAutoStop` (bool `true`), `Config.background.videoAutoMode` (QString `"FULL"`), `Config.background.videoOutputs` (QVariantMap `{}` = ALL); writable via `GlobalConfig.background.*` like `wallpaperMode`.

- [ ] **Step 1: Add the four keys**

In `shell/plugin/src/Caelestia/Config/backgroundconfig.hpp`, add `#include <qvariant.h>` and inside `BackgroundConfig`, after the `wallpaperRotationInterval` line:

```cpp
CONFIG_PROPERTY(QString, videoBackend, QStringLiteral("mpvpaper"))
CONFIG_PROPERTY(bool, videoAutoStop, true)
CONFIG_PROPERTY(QString, videoAutoMode, QStringLiteral("FULL"))
CONFIG_PROPERTY(QVariantMap, videoOutputs, {})
```

- [ ] **Step 2: Rebuild and install the plugin**

Run: `./build-plugin.sh` (repo root; needs sudo for `/usr/lib/qt6/qml` copy)
Expected: BUILD succeeds, `libcaelestia-config.so` reinstalled.

- [ ] **Step 3: Verify keys load with defaults on old shell.json**

Run: `qs -c caelestia &` (restart shell), then check `~/.config/caelestia/shell.json` contains the four keys with defaults, and existing keys (`wallpaperMode`, etc.) unchanged.
Expected: keys present; shell starts with no new QML errors (`journalctl --user -u quickshell` or terminal output clean).

---

### Task 2: VideoWallpaper.qml manager service

**Files:**
- Create: `shell/services/VideoWallpaper.qml`
- Deploy: copy to `~/.config/quickshell/caelestia/services/VideoWallpaper.qml`
- Test: `pgrep -af mpvpaper` after each step

**Interfaces:**
- Consumes: `Wallpapers.actualCurrent`, `Images.isVideo()`, `Config.background.video*`, `Config.background.wallpaperEnabled`
- Produces: `VideoWallpaper.available` (bool), `VideoWallpaper.externalActive` (bool), `VideoWallpaper.restore()` (also via `IpcHandler target: "videoWallpaper"`)

- [ ] **Step 1: Create the service file**

Create `shell/services/VideoWallpaper.qml` with this exact content:

```qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.services
import qs.utils

Singleton {
    id: root

    // Cached mpvpaper presence. Pattern: Pam.qml availCommand.
    property bool available: false
    // True when an external video is (or should be) on screen.
    readonly property bool externalActive: available
        && Config.background.wallpaperEnabled
        && Config.background.videoBackend === "mpvpaper"
        && Wallpapers.actualCurrent !== ""
        && Images.isVideo(Wallpapers.actualCurrent)

    function shQuote(s: string): string {
        return `'${s.replace(/'/g, `'\\''`)}'`;
    }

    function mpvArgs(): string {
        const stop = Config.background.videoAutoStop ? "-s" : "-p";
        const mode = Config.background.videoAutoMode;
        return mode === "" ? stop : `${stop} -a ${mode}`;
    }

    function fillArgs(): string {
        switch (GlobalConfig.background.wallpaperMode) {
        case "fit": return "--keepaspect";
        case "stretch": return "--no-keepaspect";
        default: return "--panscan=1";
        }
    }

    function spawn(target: string, video: string): void {
        const cmd = `mpvpaper ${root.mpvArgs()} -o "no-audio loop hwdec=auto ${root.fillArgs()}" ${target} ${root.shQuote(video)}`;
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    function reconcile(): void {
        // Kill first: exactly-one-instance invariant, no orphans on switch.
        Quickshell.execDetached(["sh", "-c", "pkill -x mpvpaper; sleep 0.2"]);
        if (!root.externalActive)
            return;
        const outs = Config.background.videoOutputs;
        const keys = outs ? Object.keys(outs) : [];
        if (keys.length === 0) {
            root.spawn("ALL", Wallpapers.actualCurrent);
        } else {
            for (const k of keys)
                root.spawn(k, outs[k]);
        }
    }

    function restore(): void {
        availProc.running = true; // re-check binary, then reconcile
    }

    onExternalActiveChanged: root.reconcile()
    Component.onCompleted: root.restore()

    IpcHandler {
        function restore(): void {
            root.restore();
        }

        target: "videoWallpaper"
    }

    Process {
        id: availProc

        command: ["sh", "-c", "command -v mpvpaper"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = text.trim() !== "";
                if (!root.available && root.externalActive)
                    console.warn("[VideoWallpaper] mpvpaper not found, falling back to QS Video");
                root.reconcile();
            }
        }
    }
}
```

- [ ] **Step 2: Deploy to running config and reload**

Run: `cp shell/services/VideoWallpaper.qml ~/.config/quickshell/caelestia/services/VideoWallpaper.qml && pkill quickshell; sleep 0.5; qs -c caelestia &`
Expected: shell restarts clean; with a video wallpaper set, `pgrep -af mpvpaper` shows one process with `-s -a FULL` and `ALL`.

- [ ] **Step 3: Verify kill paths**

Run: pick a static wallpaper in Nexus (or `qs -c caelestia ipc call wallpaper set /path/to/img.jpg`), then `pgrep -af mpvpaper`
Expected: empty (no mpvpaper process). Re-pick the video → process returns.

- [ ] **Step 4: Verify fallback**

Run: `sudo mv /usr/bin/mpvpaper /usr/bin/mpvpaper.bak && qs -c caelestia ipc call videoWallpaper restore` (wait 2s), observe wallpaper; then `sudo mv /usr/bin/mpvpaper.bak /usr/bin/mpvpaper`
Expected: without binary the video still plays (QS `Video` — Task 3 gates on `externalActive`, which is false when `available` is false); warning in shell log; binary restored after.

---

### Task 3: Gate internal Video on externalActive

**Files:**
- Modify: `shell/modules/background/Wallpaper.qml:69-98` (the `Video` block `visible:` and `source:` lines only)
- Deploy: copy to `~/.config/quickshell/caelestia/modules/background/Wallpaper.qml`

**Interfaces:**
- Consumes: `VideoWallpaper.externalActive` (Task 2)

- [ ] **Step 1: Edit the two bindings**

In `shell/modules/background/Wallpaper.qml`, in the `Video { id: video ... }` block:

```qml
visible: root.isVideo && !VideoWallpaper.externalActive
source: (root.isVideo && !VideoWallpaper.externalActive) ? fileUrlFor(root.source) : ""
```

`VideoWallpaper` resolves via existing `import qs.services` (already at line 9). Poster-thumb `CachingImage` path stays untouched so a thumb is always underneath.

- [ ] **Step 2: Deploy, reload, verify both backends**

Run: `cp shell/modules/background/Wallpaper.qml ~/.config/quickshell/caelestia/modules/background/Wallpaper.qml && pkill quickshell; sleep 0.5; qs -c caelestia &`
Expected with video set: mpvpaper process runs AND shell shows video (thumb under mpvpaper surface); set `videoBackend` to `"qs"` in shell.json (or Nexus after Task 5) → mpvpaper dies, QS `Video` plays.

---

### Task 4: Background layer yields to mpvpaper

**Files:**
- Modify: `shell/modules/background/Background.qml:22-23`
- Deploy: copy to `~/.config/quickshell/caelestia/modules/background/Background.qml`

**Interfaces:**
- Consumes: `VideoWallpaper.externalActive` (Task 2)

- [ ] **Step 1: Edit layer/color bindings**

In `shell/modules/background/Background.qml`, replace lines 22-23:

```qml
WlrLayershell.layer: VideoWallpaper.externalActive ? WlrLayer.Bottom : (contentItem.Config.background.wallpaperEnabled ? WlrLayer.Background : WlrLayer.Bottom)
color: VideoWallpaper.externalActive ? "transparent" : (contentItem.Config.background.wallpaperEnabled ? "black" : "transparent")
```

`qs.services` is already imported (line 9). `Visualiser`/`DesktopClock` loaders are untouched and keep drawing above.

- [ ] **Step 2: Deploy, reload, verify no black cover**

Run: same cp + shell restart as Task 3.
Expected: video wallpaper visible (not black); desktop clock (if enabled) and visualiser (if enabled) still render on top; static wallpaper path looks exactly as before.

---

### Task 5: Nexus settings UI

**Files:**
- Modify: `shell/modules/nexus/pages/WallpaperAndStyle.qml` (insert after the Wallpaper-mode `SelectRow`, ~line 223)
- Deploy: copy to `~/.config/quickshell/caelestia/modules/nexus/pages/WallpaperAndStyle.qml`

**Interfaces:**
- Consumes/produces: `GlobalConfig.background.videoBackend`, `.videoAutoStop`, `.videoAutoMode` (Task 1)

- [ ] **Step 1: Add backend + saver rows**

Insert after the wallpaper-mode `SelectRow` block:

```qml
SelectRow {
    label: qsTr("Video backend")
    subtext: GlobalConfig.background.videoBackend === "qs" ? qsTr("In-shell player (more RAM)") : qsTr("mpvpaper (less RAM)")
    enabled: Config.background.wallpaperEnabled
    menuItems: [
        MenuItem {
            text: qsTr("mpvpaper")
            icon: GlobalConfig.background.videoBackend !== "qs" ? "check" : ""
            activeIcon: "movie"
        },
        MenuItem {
            text: qsTr("In-shell")
            icon: GlobalConfig.background.videoBackend === "qs" ? "check" : ""
            activeIcon: "movie"
        }
    ]
    onSelected: {
        GlobalConfig.background.videoBackend = menuItems.indexOf(item) === 1 ? "qs" : "mpvpaper";
    }
}

ToggleRow {
    text: qsTr("Stop video when hidden")
    subtext: GlobalConfig.background.videoAutoStop ? qsTr("Saves CPU + RAM, abrupt resume") : qsTr("Pause only, seamless resume")
    checked: GlobalConfig.background.videoAutoStop
    enabled: Config.background.wallpaperEnabled && GlobalConfig.background.videoBackend !== "qs"
    onToggled: GlobalConfig.background.videoAutoStop = checked
}

SelectRow {
    last: false
    label: qsTr("Auto-stop trigger")
    subtext: GlobalConfig.background.videoAutoMode === "MAX" ? qsTr("Fullscreen or maximized") : GlobalConfig.background.videoAutoMode === "" ? qsTr("Hidden only") : qsTr("Any fullscreen")
    enabled: Config.background.wallpaperEnabled && GlobalConfig.background.videoBackend !== "qs"
    menuItems: [
        MenuItem {
            text: qsTr("Fullscreen")
            icon: GlobalConfig.background.videoAutoMode === "FULL" ? "check" : ""
        },
        MenuItem {
            text: qsTr("Fullscreen / maximized")
            icon: GlobalConfig.background.videoAutoMode === "MAX" ? "check" : ""
        },
        MenuItem {
            text: qsTr("Hidden only")
            icon: GlobalConfig.background.videoAutoMode === "" ? "check" : ""
        }
    ]
    onSelected: {
        const idx = menuItems.indexOf(item);
        GlobalConfig.background.videoAutoMode = idx === 1 ? "MAX" : idx === 2 ? "" : "FULL";
    }
}
```

Check `SelectRow`/`ToggleRow` prop names (`label` vs `text`, `last`, `menuOnTop`) against the existing rows in the same file before finalizing — adapt names to match, do not invent props.

- [ ] **Step 2: Deploy, reload, verify UI drives behavior**

Run: cp + shell restart. Open Nexus → Wallpaper & style with a video set.
Expected: switching backend kills/spawns mpvpaper live (`pgrep -af mpvpaper`); toggling stop mode respawns with `-s`/`-p` respectively; `shell.json` persists choices across restart.

---

### Task 6: Login restore + install.sh dependency

**Files:**
- Modify: `install.sh` — in `deploy_core()`, "Tools the shell uses" block add `install_pkg mpvpaper true`
- Modify: repo copy of the restore script if one exists under `hyprland/`; otherwise write the target state of `~/.config/hypr/custom/scripts/__restore_video_wallpaper.sh` into the plan's restore step below (that file is machine-generated by `switchwall.sh`; do not fight the generator — append-only if managed)
- Test: reboot or `hyprctl dispatch exec` the restore line

**Interfaces:**
- Consumes: `videoWallpaper` IPC target (Task 2)

- [ ] **Step 1: Add install dependency**

In `install.sh` after the `install_pkg gpu-screen-recorder` / `install_pkg emote true` lines:

```bash
# Video wallpaper backend (mpvpaper; QS Video is the fallback)
install_pkg mpvpaper true
```

- [ ] **Step 2: Wire login restore**

Ensure the command run at login (currently `execs.lua` → `__restore_video_wallpaper.sh`) ends with:

```bash
qs -c caelestia ipc call videoWallpaper restore
```

(`VideoWallpaper.Component.onCompleted` already calls `restore()` on shell start, so this covers the race where the shell starts before monitors exist.) If `__restore_video_wallpaper.sh` is generator-managed, add the line in a way that survives regeneration or document it in `shell/README.md` instead.

- [ ] **Step 3: Verify restore**

Run: `pkill -x mpvpaper; qs -c caelestia ipc call videoWallpaper restore; sleep 1; pgrep -af mpvpaper`
Expected: mpvpaper returns playing the current video.

---

### Task 7: Docs + dual-location consistency sweep

**Files:**
- Modify: `shell/README.md` config reference (near `"wallpaperEnabled": true,` ~line 389)
- Test: `diff -r shell/services shell/modules/background shell/modules/nexus/pages ~/.config/quickshell/caelestia/...` per dir

**Interfaces:** none (docs only).

- [ ] **Step 1: Document the keys**

In `shell/README.md` background config section add:

```json
"videoBackend": "mpvpaper",
"videoAutoStop": true,
"videoAutoMode": "FULL",
"videoOutputs": {}
```

with one line each: backend choices, `-s` vs `-p`, `FULL`/`MAX`/empty, `{}` = ALL else `{"DP-1": "/path/video.mp4"}`.

- [ ] **Step 2: Consistency sweep**

Run: `diff -r shell/services/VideoWallpaper.qml ~/.config/quickshell/caelestia/services/VideoWallpaper.qml; diff -r shell/modules/background ~/.config/quickshell/caelestia/modules/background; diff shell/modules/nexus/pages/WallpaperAndStyle.qml ~/.config/quickshell/caelestia/modules/nexus/pages/WallpaperAndStyle.qml`
Expected: no diffs.

---

### Task 8: End-to-end acceptance (spec § Testing)

- [ ] **Step 1: RAM check**

Run: with video wallpaper active, `ps -C quickshell -o comm,rss; ps -C mpvpaper -o comm,rss`
Expected: quickshell RSS an order of magnitude below the old ~1.1 GB video cost; mpvpaper holds the video RSS instead.

- [ ] **Step 2: Fullscreen stop/resume**

Run: fullscreen any window, `pgrep -af mpvpaper` (stopped state) / exit fullscreen (resumes).
Expected: stops on fullscreen (`-a FULL`), resumes after.

- [ ] **Step 3: Rotation + preview**

Run: enable wallpaper rotation with videos in the dir, or pick several videos in a row.
Expected: exactly one mpvpaper instance after each switch (`pgrep -c -x mpvpaper` is 0 or 1); no orphans.

- [ ] **Step 4: Static + disabled paths**

Run: set static image; then toggle Display wallpaper off.
Expected: no mpvpaper process in either case; static image and empty state render as before.
