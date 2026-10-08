# mpvpaper Video Wallpaper Backend — Design

Date: 2026-09-12
Status: approved (chat), pending spec-file review
Approach: A — QML-owned manager service

## Problem

Video wallpapers play inside the `qs -c caelestia` process via
QtMultimedia `Video` (`shell/modules/background/Wallpaper.qml:69-98`),
which costs ~1.1 GB RAM (software decode, frame buffering in-process)
and risks taking the whole shell down on decode failure.

## Goal

Play video wallpapers in `mpvpaper` (already installed: 1.9-1, provides
`-s/-p/-a/-o/-l`), out of the shell process, with hardware decoding,
keeping the existing thumbnail + `caelestia wallpaper -f` theming flow
untouched. QS `Video` remains as automatic fallback.

## Locked decisions

- Backend default `mpvpaper`, fallback QS `Video` when binary missing.
- Output scope: `ALL` default + per-output override map.
- Battery saver: auto-stop (`-s`) + `-a FULL` by default.
- Hard cut on switch acceptable (no fade for external video).

## Architecture

Single owner: new `services/VideoWallpaper.qml` singleton. It watches
`Wallpapers.actualCurrent` and the new `BackgroundConfig` video props
and reconciles external state:

- video + backend=mpvpaper + binary present → exactly one mpvpaper
  instance per target running the current video.
- otherwise (static image, wallpaper disabled, backend=qs, binary
  missing) → no mpvpaper process; QS renders as today.

## Config

Extend `BackgroundConfig`
(`shell/plugin/src/Caelestia/Config/backgroundconfig.hpp`), mirrored in
`shell.json`:

- `videoBackend`: `"mpvpaper"` (default) / `"qs"`.
- `videoAutoStop`: bool, default true (`-s`; false → `-p`).
- `videoAutoMode`: `""` / `"FULL"` (default `"FULL"`) / `"MAX"`.
- `videoOutputs`: string map output → video path, default empty = `ALL`.

Requires C++ plugin rebuild (CMake). Edit both `<repo>/shell/` and
`~/.config/quickshell/caelestia/` per repo convention. Static
wallpapers always render in QS regardless of backend.

## Playback & layering

- `Wallpaper.qml`: when external video is active, skip the internal
  `Video` element; keep showing the extracted poster thumb underneath
  so the screen is never black during spawn/restart.
- `Background.qml`: when external video is active, the QS background
  window goes transparent + `Bottom` layer (mpvpaper owns the
  `Background` layer); otherwise current black + `Background` behavior
  stays. `Visualiser` and `DesktopClock` keep drawing on top.
- `wallpaperMode` mapping: crop → mpv panscan fill, fit → keepaspect,
  stretch → no-aspect. Exact mpv flags finalized at implementation.
- Nexus `WallpaperAndStyle.qml`: backend selector + auto-stop/mode rows.

## Data flow

1. Set video → existing `Wallpapers.setVideoWallpaper` thumb + theme
   script runs unchanged → `actualCurrent` updates.
2. Manager reacts → `pkill mpvpaper`-then-spawn with
   `-s -a FULL -o "no-audio loop hwdec=auto …" <target> <video>`.
3. Set static image / disable wallpaper / backend=qs → kill mpvpaper.
4. Rotation, preview, and login restore (`execs.lua` +
   `__restore_video_wallpaper.sh`) funnel through the same reconcile
   entry point so there is one spawn path.
5. Per-output override: each map entry spawns its own mpvpaper target;
   empty map = single `ALL` instance.

## Error handling

- Binary presence (`command -v mpvpaper`) cached as `available`; when
  missing, silently use QS `Video` + one-time warning log.
- Spawn failure → poster thumb stays visible; retry on next wallpaper
  change only (no respawn loop).
- Rapid picks reuse the existing `flock` serialization in
  `setVideoWallpaper`.
- `install.sh` gains `mpvpaper` as a wallpaper dependency.

## Testing

No QML unit harness exists; verify manually:

1. Pick video → `pgrep -af mpvpaper` shows `-s -a FULL` + right target.
2. QS RSS stays flat (vs ~1.1 GB before).
3. Fullscreen a window → playback stops; un-fullscreen → resumes.
4. `mpvpaper` removed from PATH → QS `Video` plays instead.
5. Static wallpaper → no mpvpaper process.
6. Reboot → restore script brings the video back.

## Out of scope

- mpvpaper pause-on-covered-window daemons (`mpvpaper-stop`); `-s/-a`
  covers the v1 battery goal. Decided 2026-09-12: v2 follow-up after
  measuring real drain; v2 shape if wanted: `videoPauseOnCovered` flag,
  manager passes `--input-ipc-server` and supervises the stop daemon,
  optional `install.sh` dep.
- `swww` (no video), `linux-wallpaperengine` (heavier, partial scene
  support), per-screen Nexus picker UI (override map suffices for v1).
