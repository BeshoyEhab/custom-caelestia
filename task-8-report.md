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

## Round fix: Network singleton vs local popout boot blocker

- **Status:** FIXED
- **Commit:** `e691f011` — `fix: qualify local Network popout vs services singleton`
- **File:** `shell/modules/bar/popouts/Content.qml` (3 insertions, 2 deletions)
- **Root cause:** `Content.qml:46` `Network {` resolved to the custom-only
  singleton `qs.services.Network` (`services/Network.qml`, `pragma Singleton`;
  upstream has no such file) instead of the local
  `shell/modules/bar/popouts/Network.qml` component, because the file imports
  `qs.services` unaliased. Error
  `Composite Singleton Type Network is not creatable` aborted the Drawers chain.
- **Fix (minimal, both Networks kept):**
  - Added `import "./" as LocalPopouts` after existing imports (pragma kept,
    no `qs.services` re-alias).
  - `sourceComponent: Network {` → `sourceComponent: LocalPopouts.Network {`
    for the `network` (line 46) and `ethernet` (line 54) popouts only.
  - Left `(networkPopout.item as Network)` casts untouched — no `Network`
    complaints remain in `qs -p` output.
- **Tests:**
  - `timeout 20 qs -p shell/shell.qml 2>&1 | grep -i "Network.*not creatable"` →
    empty (Network blocker gone).
  - `timeout 20 qs -p shell/shell.qml 2>&1 | grep -ci "error"`: **8** (was 8
    with the Network blocker; count unchanged because the chain moved one
    link downstream).
  - **Next downstream blocker (out of scope, same singleton-vs-local
    pattern):** chain now ends at
    `Content.qml[124:30]: Composite Singleton Type Audio is not creatable.`
    (`Content.*unavailable` lines therefore still appear — from Audio, not
    Network).
