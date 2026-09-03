# Development Log

## Sep 3, 2026 — Repo-wide audit: correctness, perf, reliability fixes

**Scope:** C++ plugin (`shell/plugin/src/`), QML (`shell/modules/`), `deploy.sh`, docs.

**QML fixes (all verified in source before changing):**
- Deleted dead files `workspaceoverview/WindowPreview.qml` and `WorkspaceCell.qml`
  (zero references; `OverviewGrid` dynamic previews are the canonical path).
  Note: `deploy.sh` now removes such stale files from the running config.
- `drawers/ContentWindow.qml`: guarded `t.lastIpcObject?.fullscreen` in both
  `.some()` calls (null IPC object during window close broke the binding);
  `Math.max(...[])` → `0` when all panels disabled (was `-Infinity`).
- `bar/components/workspaces/Workspaces.qml`: guarded `Hypr.monitorFor(screen)?.`
  and `Math.max(1, shown)` against div-by-zero in `groupOffset`.
- `nexus/NexusState.qml`: `list<int>` stack → `property var` with copy-on-write
  reassignment so change notifications reliably fire.
- `workspaceoverview/OverviewGrid.qml`: removed position-drift `refreshWindows()`
  triggers (redundant with `Hypr.toplevels.onValuesChanged`; fought the `Behavior`
  animation and caused rebuild churn).

**C++ fixes (build passes, warning-free):**
- `toaster.cpp`: normalize timeout before `singleShot` (default timeouts closed instantly).
- `audiocollector.cpp`: always `queue_buffer` after dequeue; null-check `chunk`.
- `cavaprovider`: `valuesChanged`/`updateValues` take `const QVector<double>&`.
- `blobshape.cpp`: cap exclude-mask loop at 16 (matches shader), `1u` shift.
- `imagecacher.cpp`: mutex-guard static hash, key by path+mtime+size (fixes race
  and stale thumbnails); init `scaleMode` (was `-Wmaybe-uninitialized`).
- `gpu.cpp`: stop fork-execing `nvidia-smi` after 3 consecutive failures.

**Scripts:**
- `deploy.sh`: replaced manual `cp` allowlist with full-tree `*.qml` sync
  (portable `$HOME`/repo-relative paths) + stale-file cleanup that spares
  `custom/` and `shell.json`.
- `install.sh`: sudo approval asked once (`Y=yes to all, o=once, n=skip`).

**Known issues left for later (verified, risky or out of scope):**
- `bar/BarWrapper.qml:31` dead ternary; horizontal-bar geometry (slide on `x`
  only, Loader pinned top/bottom) — see TODO #1 Bar Position Generalization.
- `bar/components/StatusIcons.qml`: duplicate `"audio"` popout name (mic/speaker);
  `Bar.qml` positional `children[]` lookups.
- `Services/storage.cpp`: full sysfs walk on UI thread each tick — needs caching/worker.
- `Services/lyrics.cpp`: 3-4 requests per track + recursive `.lrc` walk on UI thread.
- `Models/filesystemmodel.cpp`: stale-index batch inserts; disk I/O in comparator.

## Jun 22, 2026 — Settings app layout broken: buttons/fields width=0

**Symptom:** All Nexus settings pages showed buttons and text fields with width=0,
but text content was still visible (no background rectangles, no padding, no layout).

**Root cause:** Two issues combined:

1. **`NavPane.qml` used `IconButton.Outlined`** which doesn't exist in the
   `ButtonBase.ButtonType` enum (only `Filled`, `Tonal`, `Text`). This caused
   `type: IconButton.Outlined` to resolve to `undefined`, producing the warning
   `Unable to assign [undefined] to int` on every shell startup. While the nav
   pane restart button still rendered (type fell back to default `Filled`), the
   type error could interfere with QML property binding propagation on some
   frames.

2. **C++ plugin was stale.** The installed `libcaelestia-configplugin.so` was
   built on Jun 21 but the `CMakeLists.txt` at the repo root had an invalid
   version string `"2.0.3-custom"` — CMake `project(VERSION ...)` requires
   `major.minor.patch` format. This prevented rebuilding the plugin from the
   custom-caelestia source, so the installed binary drifted from the source
   tokens (including `Tokens.sizes.nexus.maxContentWidth`). Without
   `maxContentWidth`, the `PageBase.cappedWidth` calculation produced `NaN`,
   which QML coerced to 0, collapsing all page content widths.

**Fixes applied:**

- `NavPane.qml:36`: Changed `IconButton.Outlined` → `IconButton.Tonal`
- `CMakeLists.txt:15`: Changed `VERSION ${VERSION}` → `VERSION 2.0.3` (valid
  CMake format)
- Rebuilt and reinstalled all C++ plugins from custom-caelestia source via
  `build-plugin.sh`

**Lesson:** When the settings app breaks across all pages simultaneously, check:
1. Whether the C++ config plugin is up to date with the source tokens
2. Whether any QML warnings are present in the quickshell log (start with
   `qs -c caelestia 2>&1` to see them)
3. That `CMakeLists.txt` version strings are valid semver
