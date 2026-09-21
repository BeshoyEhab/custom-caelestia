# Task 7 Report — upstream-sync 2026-09-21

## Round fix: GapMarkers boot blocker (AnimatedRepeater missing from installed plugin)

- **Status:** FIXED
- **Commit:** `14249ae6` — `fix: guard GapMarkers until AnimatedRepeater plugin ships`
- **File:** `shell/modules/bar/components/workspaces/Workspaces.qml` (10 insertions, 5 deletions)
- **Root cause:** The GapMarkers `Loader` used `opacity: root.showUnoccupied ? 0 : 1`
  + `active: opacity > 0`. `showUnoccupied` resolves false (custom schema has no
  such key yet), so the Loader activated and loaded `GapMarkers.qml`, which
  needs `AnimatedRepeater` (Caelestia.Components). Task 10 ported
  `animatedrepeater.cpp/hpp` source but the installed .so predates it, so
  `qs -p shell/shell.qml` aborted the full Drawers → ContentWindow → BarWrapper
  → Bar → Workspaces → GapMarkers chain with
  `GapMarkers.qml[16:5]: AnimatedRepeater is not a type`.
- **Fix (minimal, reversible; GapMarkers.qml untouched, no plugin build):**
  - `active: opacity > 0` → `active: false` (opacity line kept for future).
  - `sourceComponent: GapMarkers { … }` commented out — required, not optional:
    even with `active: false` the QML compiler resolves the static GapMarkers
    type reference and still aborts the Bar chain. Restored by uncommenting
    together with `active: opacity > 0` once the Task 10 plugin ships.
  - Guard comment added:
    `// Guarded until Task 10 plugin with AnimatedRepeater is installed; then
    restore active: opacity > 0`.
- **Tests:**
  - `timeout 20 qs -p shell/shell.qml 2>&1 | grep -i "AnimatedRepeater\|GapMarkers"` →
    empty (exit 1, no matches).
  - `timeout 20 qs -p shell/shell.qml 2>&1 | grep -ci "error"`: **8 → 0**
    (only match is a `Colours: ignoring … m3errorDim …` DEBUG line; the
    `Failed to load configuration` ERROR chain is gone).
  - **New tail (benign, environmental):** `caelestia.config` per-monitor overlay
    WARNs, `inotify_add_watch(/usr/local/share/applications) failed:
    (Permission denied)` WARNs, `Failed to open VDPAU backend
    libvdpau_nvidia.so` (no NVIDIA GPU in container). No QML ERRORs remain.
