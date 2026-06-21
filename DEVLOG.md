# Development Log

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
