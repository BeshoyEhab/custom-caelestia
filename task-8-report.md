# Task 8 Report — upstream-sync 2026-09-21

## Round fix: AudioPopout I18n boot blocker

- **Status:** FIXED
- **Commit:** `0e6a76c5` — `fix: qsTr-convert AudioPopout drop I18n import`
- **File:** `shell/modules/bar/popouts/AudioPopout.qml` (4 insertions, 5 deletions)
- **Root cause:** `import Caelestia.I18n` (line 8) references a module that does not
  exist (deferred to Task 10). `Content.qml:131-132` instantiates AudioPopout
  eagerly, so `qs -p shell/shell.qml` aborted the full
  Drawers → Panels → ClipWrapper → Wrapper → Content → AudioPopout chain.
- **Fix (Task 6 precedent, Tr → qsTr):**
  - Deleted `import Caelestia.I18n` (line 8).
  - `Tr.trCtx("Output device", …)` → `qsTr("Output device")`
  - `Tr.trCtx("Input device", …)` → `qsTr("Input device")`
  - `Tr.tr("Volume (muted)")` → `qsTr("Volume (muted)")`
  - `Tr.tr("Volume (%1%)").arg(…)` → `qsTr("Volume (%1%)").arg(…)`
  - `Tr.tr("Open settings")` → `qsTr("Open settings")`
- **Tests:**
  - `grep -n "Caelestia.I18n\|Tr\." shell/modules/bar/popouts/AudioPopout.qml` →
    empty (exit 1, no matches).
  - `timeout 20 qs -p shell/shell.qml 2>&1 | grep -ci "error"`: **9 → 8**.
    Baseline chain ended at
    `AudioPopout.qml[8:1]: module "Caelestia.I18n" is not installed`;
    after fix the I18n/AudioPopout link is gone (no `I18n|AudioPopout` lines in
    error output).
  - **Next downstream blocker (out of scope):** chain now ends at
    `Content.qml[46:30]: Composite Singleton Type Network is not creatable.`
