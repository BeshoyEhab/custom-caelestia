# Upstream Sync `20e625d6 → 5f1c59c0` + Biweekly Sync Rule — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the 12 new upstream commits into `custom-caelestia/shell` without touching custom features, and add an "at least once every 2 weeks" upstream-sync planning rule to AGENTS.md.

**Architecture:** Refresh vendored `shell/upstream` first, then classify each of the 61 changed upstream files: 7 verbatim copies (custom never touched them, upstream delta = clang-tidy only), 4 targeted hand-ports of *functional* commits, 1 pipewire 3-way merge (the only real conflict), everything cosmetic deliberately skipped (lives in `shell/upstream` only).

**Tech Stack:** Quickshell QML (`qs -c caelestia`), C++ QML plugin (CMake, `build-plugin.sh`), `merge-upstream.sh`, `deploy.sh`, `tests/*.sh` (17 sandboxed tests).

**Spec:** Analysis in conversation 2026-10-10. Delta `20e625d6..5f1c59c0` = 61 files, of which **1 QML + 49 plugin + 11 meta**. Functional commits only: `80c40a14` (drawers QML), `4ffb060a` (qalculate), `55f98a55` (filesystemmodel), `6f7ce62b` (image grabs), `90ef9e1c`+`17fa999e` (pipewire), `c4abc387` (tokens/per-monitor → **skipped**, custom already has `MonitorConfigManager::tokensForScreen`); rest = `ee6d0e0a` clang-tidy + `e40cc08e` formatting + flake/issue-template noise.

## Global Constraints

- Edit ONLY `<repo>/shell/` in git; sync to `~/.config/quickshell/caelestia/` via `./deploy.sh`, never hand-edit live config.
- Never run `./merge-upstream.sh merge-all`.
- `pragma ComponentBehavior: Bound` MUST NOT be added to `shell/modules/bar/Bar.qml`; Bar root stays `Item`.
- Every QML file using `Colours.palette.*` MUST have `import qs.services`.
- **Do NOT copy `plugin/src/Caelestia/Config/anim.hpp`** — it's coupled to skipped `c4abc387` (moves `bindDurations`/`bindCurves` private, needs `rootnodes.hpp`/`ConfigSingleton` which custom doesn't have; custom calls `m_anim->bindDurations(...)` in `tokensattached.cpp:81` → build break).
- Cosmetic commits (`ee6d0e0a`, `e40cc08e`) are never hand-ported into diverged files.
- WIP on `feat/unified-setup-script` must be committed first (user decision); sync runs on new branch `chore/upstream-sync-2026-10-10` from it.
- `CMakeLists.txt` `project(VERSION ...)` stays valid semver `2.0.3`.
- Commit after every task.

---

### Task 0: Commit in-flight WIP + record baselines

**Files:**
- Modify (commit): `install.sh` (+223), `update.sh`, `docs/superpowers/plans/2026-10-10-unified-setup-script.md`, `docs/superpowers/specs/2026-10-10-unified-setup-script-design.md`, `shell/plugin/src/Caelestia/Components/CMakeLists.txt`, `Components/visualiserbars.{cpp,hpp}` (deleted), `shell/plugin/src/Caelestia/Config/tokens.hpp` (adds `CONFIG_PROPERTY(int, audioWidth, 320)`)
- Test: `tests/*.sh`, `build-plugin.sh`

**Interfaces:**
- Consumes: current `feat/unified-setup-script` branch state
- Produces: clean tree, test FAIL-line baseline, boot-error baseline

- [ ] **Step 1: Confirm WIP is the only dirt**

Run: `git -C /home/Bisho/custom-caelestia status --porcelain`
Expected: exactly the 8 known entries (install.sh, update.sh, 2× ` D visualiserbars`, Components/CMakeLists, tokens.hpp, 2× `?? docs/...unified-setup-script*`). Anything else → STOP and report.

- [ ] **Step 2: No dangling references to removed component**

Run: `grep -rn "Components/visualiserbars\|caelestia-components.*visualiserbars" /home/Bisho/custom-caelestia/shell/plugin/src/Caelestia/Components/ || echo CLEAN`
Expected: `CLEAN` (the `Internal/visualiserbars.cpp` copy at `shell/plugin/src/Caelestia/Internal/` + its `Internal/CMakeLists.txt` entry remain — that's the live one; QML resolves via `import Caelestia.Internal` in `Visualiser.qml`).

- [ ] **Step 3: Build still green with the deletion**

Run: `./build-plugin.sh 2>&1 | tail -n 10`
Expected: exit 0, no `visualiserbars` / undefined-symbol errors.

- [ ] **Step 4: Record test baseline (FAIL lines are the baseline)**

```bash
for t in tests/*.sh; do bash "$t" >/tmp/opencode/t.log 2>&1 && echo "PASS $t" || echo "FAIL $t"; done | tee /tmp/opencode/tests-baseline.txt
```
Expected: all `PASS`. Any `FAIL` → fix before proceeding (WIP isn't ready).

- [ ] **Step 5: Record boot baseline**

Run: `timeout 20 qs -c caelestia 2>&1 | grep -ci "error\|Unable to assign\|is not a type\|NaN" | tee /tmp/opencode/boot-baseline.txt`
Expected: a number N (paste into Task 8).

- [ ] **Step 6: Commit WIP in two commits**

```bash
git -C /home/Bisho/custom-caelestia add install.sh update.sh docs/superpowers/plans/2026-10-10-unified-setup-script.md docs/superpowers/specs/2026-10-10-unified-setup-script-design.md
git -C /home/Bisho/custom-caelestia commit -m "feat: unified setup script single entrypoint for install+update"
git -C /home/Bisho/custom-caelestia add -A shell/plugin/src/Caelestia/Components shell/plugin/src/Caelestia/Config/tokens.hpp
git -C /home/Bisho/custom-caelestia commit -m "chore(plugin): drop duplicate Components visualiserbars, add bar audioWidth token"
git -C /home/Bisho/custom-caelestia status --porcelain | wc -l
```
Expected: `0`.

---

### Task 1: Branch + refresh vendored base

**Files:**
- Modify: `shell/upstream/` (whole tree)
- Test: `diff -rq` = 0

**Interfaces:**
- Consumes: `~/caelestia` @ `5f1c59c0` (already pulled this session)
- Produces: branch `chore/upstream-sync-2026-10-10`, `shell/upstream` byte-identical to live upstream

- [ ] **Step 1: Create branch**

```bash
git -C /home/Bisho/custom-caelestia checkout -b chore/upstream-sync-2026-10-10
git -C /home/Bisho/caelestia rev-parse --short HEAD
```
Expected: branch created; SHA = `5f1c59c0`.

- [ ] **Step 2: Recopy base**

```bash
rm -rf shell/upstream && cp -a /home/Bisho/caelestia shell/upstream && rm -rf shell/upstream/.git
diff -rq shell/upstream /home/Bisho/caelestia 2>&1 | grep -v "\.git" | wc -l
```
Expected: `0`.

- [ ] **Step 3: Commit**

```bash
git -C /home/Bisho/custom-caelestia add shell/upstream
git -C /home/Bisho/custom-caelestia commit -m "chore: refresh shell/upstream to ~/caelestia@5f1c59c0"
```

---

### Task 2: Verbatim copy — 7 untouched files (clang-tidy delta only)

**Files:**
- Modify: `shell/plugin/src/Caelestia/Components/{animatedrepeater.cpp,animatedrepeater.hpp,buttonrow.cpp,circularindicatormanager.hpp,linearindicatormanager.cpp}`, `shell/plugin/src/Caelestia/Settings/{listnode.cpp,settingsfile.hpp}`
- Test: build

**Interfaces:**
- Consumes: refreshed `shell/upstream` (Task 1)
- Produces: 7 files byte-identical to upstream; **`anim.hpp` deliberately NOT copied** (Global Constraint)

- [ ] **Step 1: Prove each file's only upstream commit is clang-tidy**

```bash
for f in plugin/src/Caelestia/Components/animatedrepeater.cpp plugin/src/Caelestia/Components/animatedrepeater.hpp plugin/src/Caelestia/Components/buttonrow.cpp plugin/src/Caelestia/Components/circularindicatormanager.hpp plugin/src/Caelestia/Components/linearindicatormanager.cpp plugin/src/Caelestia/Settings/listnode.cpp plugin/src/Caelestia/Settings/settingsfile.hpp; do echo "$f => $(git -C /home/Bisho/caelestia log --format=%s 20e625d6..5f1c59c0 -- $f)"; done
```
Expected: every line ends with `chore: fix clang-tidy warnings`. Any functional commit → STOP, move that file to a hand-port task.

- [ ] **Step 2: Copy verbatim**

```bash
cd /home/Bisho/custom-caelestia
for f in plugin/src/Caelestia/Components/animatedrepeater.cpp plugin/src/Caelestia/Components/animatedrepeater.hpp plugin/src/Caelestia/Components/buttonrow.cpp plugin/src/Caelestia/Components/circularindicatormanager.hpp plugin/src/Caelestia/Components/linearindicatormanager.cpp plugin/src/Caelestia/Settings/listnode.cpp plugin/src/Caelestia/Settings/settingsfile.hpp; do cp "shell/upstream/$f" "shell/$f"; done
```

- [ ] **Step 3: Verify identical + build**

```bash
for f in plugin/src/Caelestia/Components/animatedrepeater.cpp plugin/src/Caelestia/Components/animatedrepeater.hpp plugin/src/Caelestia/Components/buttonrow.cpp plugin/src/Caelestia/Components/circularindicatormanager.hpp plugin/src/Caelestia/Components/linearindicatormanager.cpp plugin/src/Caelestia/Settings/listnode.cpp plugin/src/Caelestia/Settings/settingsfile.hpp; do diff -q "shell/upstream/$f" "shell/$f" || echo "DIFF $f"; done; echo VERIFY-DONE
./build-plugin.sh 2>&1 | tail -n 10
```
Expected: only `VERIFY-DONE`; build exit 0.

- [ ] **Step 4: Commit**

```bash
git -C /home/Bisho/custom-caelestia add shell/plugin/src/Caelestia/Components shell/plugin/src/Caelestia/Settings
git -C /home/Bisho/custom-caelestia commit -m "chore(plugin): adopt upstream clang-tidy cleanups on untouched files"
```

---

### Task 3: Drawers drag-mask one-liner (upstream `80c40a14`)

**Files:**
- Modify: `shell/modules/drawers/ContentWindow.qml:57`
- Test: grep + boot

**Interfaces:**
- Consumes: upstream hunk `windows > 0` → `toplevels.values.length > 0`
- Produces: drag mask uses live toplevels (matches AGENTS.md bar rules — no layout files touched)

- [ ] **Step 1: Show current line**

Run: `grep -n "lastIpcObject?.windows > 0" /home/Bisho/custom-caelestia/shell/modules/drawers/ContentWindow.qml`
Expected: 1 hit at line 57 (inside `dragMaskPadding`).

- [ ] **Step 2: Edit — replace exactly**

In `shell/modules/drawers/ContentWindow.qml`, change:

```qml
// old
if (monitor?.lastIpcObject.specialWorkspace?.name || monitor?.activeWorkspace?.lastIpcObject?.windows > 0)
// new
if (monitor?.lastIpcObject.specialWorkspace?.name || monitor?.activeWorkspace?.toplevels.values.length > 0)
```

- [ ] **Step 3: Verify**

```bash
grep -c "toplevels.values.length > 0" /home/Bisho/custom-caelestia/shell/modules/drawers/ContentWindow.qml
grep -c "lastIpcObject?.windows > 0" /home/Bisho/custom-caelestia/shell/modules/drawers/ContentWindow.qml
```
Expected: `1` then `0`.

- [ ] **Step 4: Commit**

```bash
git -C /home/Bisho/custom-caelestia add shell/modules/drawers/ContentWindow.qml
git -C /home/Bisho/custom-caelestia commit -m "fix(drawers): use live toplevels for drag mask padding (upstream 80c40a14)"
```

---

### Task 4: Qalculate display format (upstream `4ffb060a`)

**Files:**
- Modify: `shell/plugin/src/Caelestia/qalculator.cpp` (2 spots: `evaluate()` ~line 58, second eval ~line 122)
- Test: build

**Interfaces:**
- Consumes: upstream fix `po.interval_display = INTERVAL_DISPLAY_SIGNIFICANT_DIGITS`
- Produces: calculator results print with significant-digit intervals instead of raw ranges

- [ ] **Step 1: Locate both `PrintOptions po;` declarations**

Run: `grep -n "PrintOptions po;" $(find /home/Bisho/custom-caelestia/shell/plugin -name qalculator.cpp)`
Expected: exactly 2 hits (~58, ~122). If count ≠ 2 → STOP and re-inspect.

- [ ] **Step 2: Add the line after EACH declaration**

```cpp
PrintOptions po;
po.interval_display = INTERVAL_DISPLAY_SIGNIFICANT_DIGITS;
```

(Keep the existing custom comment blocks about `comma_as_separator` untouched.)

- [ ] **Step 3: Verify + build**

```bash
grep -c "INTERVAL_DISPLAY_SIGNIFICANT_DIGITS" $(find /home/Bisho/custom-caelestia/shell/plugin -name qalculator.cpp)
./build-plugin.sh 2>&1 | tail -n 10
```
Expected: `2`; build exit 0.

- [ ] **Step 4: Commit**

```bash
git -C /home/Bisho/custom-caelestia add shell/plugin/src/Caelestia/qalculator.cpp
git -C /home/Bisho/custom-caelestia commit -m "feat(core): improve qalculate display format (upstream 4ffb060a)"
```

---

### Task 5: FileSystemModel rescanned-subdir fix (upstream `55f98a55`)

**Files:**
- Modify: `shell/plugin/src/Caelestia/Models/filesystemmodel.cpp` (`updateEntriesForDir` @283, `applyChanges` @377)
- Test: patch dry-run + build

**Interfaces:**
- Consumes: upstream patch (cpp only — its `.hpp` change is clang-tidy, skipped)
- Produces: wallpaper/file listings keep entries outside a rescanned subdirectory; no duplicate entries on rescan

- [ ] **Step 1: Generate + dry-run the upstream patch**

```bash
git -C /home/Bisho/caelestia diff 20e625d6..5f1c59c0 -- plugin/src/Caelestia/Models/filesystemmodel.cpp > /tmp/opencode/fs-fix.patch
cd /home/Bisho/custom-caelestia/shell && patch -p1 --dry-run < /tmp/opencode/fs-fix.patch
```
Expected: `Hunk #1 succeeded`, `Hunk #2 succeeded` (fuzz offsets OK). If FAILED → Step 2 fallback.

- [ ] **Step 2: Fallback — apply by hand (only if dry-run fails)**

In `updateEntriesForDir` (~line 292 region), replace the oldPaths block with:

```cpp
const bool isRoot = dir == m_path;
const QString prefix = dir.endsWith(u'/') ? dir : dir + u'/';
QSet<QString> oldPaths;
for (const auto& entry : std::as_const(m_entries)) {
    if (isRoot || entry->path().startsWith(prefix))
        oldPaths << entry->path();
}
```

In `applyChanges`, before `QList<FileSystemEntry*> newEntries;` add:

```cpp
QSet<QString> existing;
for (const auto& entry : std::as_const(m_entries))
    existing << entry->path();
```

and guard creation:

```cpp
for (const auto& path : addedPaths) {
    if (!existing.contains(path))
        newEntries << new FileSystemEntry(path, m_dir.relativeFilePath(path), this);
}
```

- [ ] **Step 3: Apply (if dry-run passed) + verify**

```bash
cd /home/Bisho/custom-caelestia/shell && patch -p1 < /tmp/opencode/fs-fix.patch
grep -c "isRoot\|existing.contains" plugin/src/Caelestia/Models/filesystemmodel.cpp
./build-plugin.sh 2>&1 | tail -n 10
```
Expected: count ≥ `3`; build exit 0.

- [ ] **Step 4: Commit**

```bash
git -C /home/Bisho/custom-caelestia add shell/plugin/src/Caelestia/Models/filesystemmodel.cpp
git -C /home/Bisho/custom-caelestia commit -m "fix(models): keep entries outside rescanned subdirectory (upstream 55f98a55)"
```

---

### Task 6: Release image grabs after saving (upstream `6f7ce62b`)

**Files:**
- Modify: `shell/plugin/src/Caelestia/cutils.cpp` (`CUtils::saveItem`, ~lines 93-140)
- Test: build

**Interfaces:**
- Consumes: upstream fix essence — take `image()` early, don't drag `grabResult` into the worker thread, single-shot connection (Qt 6.11.2 ✓)
- Produces: screenshot/screenshot-save path releases grab result; custom `QFutureWatcher` + engine-callback structure preserved

- [ ] **Step 1: Preconditions**

```bash
grep -c "SingleShotConnection" /home/Bisho/custom-caelestia/shell/plugin/src/Caelestia/cutils.cpp
grep -c "saveItem" /home/Bisho/custom-caelestia/shell/plugin/src/Caelestia/cutils.cpp
```
Expected: `0` then ≥ `1`.

- [ ] **Step 2: Edit `saveItem` — current → new**

Current (custom):

```cpp
QObject::connect(grabResult.data(), &QQuickItemGrabResult::ready, this,
    [grabResult, scaledRect, path, onSaved, onFailed, this]() {
        const auto future = QtConcurrent::run([=]() {
            QImage image = grabResult->image();

            if (scaledRect.isValid()) {
                image = image.copy(scaledRect);
            }

            const QString file = path.toLocalFile();
            const QString parent = QFileInfo(file).absolutePath();
            return QDir().mkpath(parent) && image.save(file);
        });
```

Replace with (keep everything after `}` — the `QFutureWatcher` block — untouched):

```cpp
QObject::connect(grabResult.data(), &QQuickItemGrabResult::ready, this,
    [grabResult, scaledRect, path, onSaved, onFailed, this]() {
        const QImage source = grabResult->image();
        const auto future = QtConcurrent::run([=]() {
            QImage image = scaledRect.isValid() ? source.copy(scaledRect) : source;

            const QString file = path.toLocalFile();
            const QString parent = QFileInfo(file).absolutePath();
            return QDir().mkpath(parent) && image.save(file);
        });
```

…and at the **end of this connect call**, after the outer lambda's closing `},`, add the connection type argument:

```cpp
        },
        Qt::SingleShotConnection);
```

(Do not touch the *other* `QObject::connect` calls in the file — only the one for `QQuickItemGrabResult::ready`.)

- [ ] **Step 3: Verify + build**

```bash
grep -c "SingleShotConnection" /home/Bisho/custom-caelestia/shell/plugin/src/Caelestia/cutils.cpp
grep -c "grabResult->image()" /home/Bisho/custom-caelestia/shell/plugin/src/Caelestia/cutils.cpp
./build-plugin.sh 2>&1 | tail -n 10
```
Expected: `1`, `1` (image taken once in outer lambda only); build exit 0.

- [ ] **Step 4: Commit**

```bash
git -C /home/Bisho/custom-caelestia add shell/plugin/src/Caelestia/cutils.cpp
git -C /home/Bisho/custom-caelestia commit -m "fix(core): release image grabs after saving (upstream 6f7ce62b)"
```

---

### Task 7: Pipewire quantum ring buffer (upstream `90ef9e1c` + `17fa999e`) — hardest

**Files:**
- Create: `shell/plugin/include/util/ringbuffer.hpp` (copy)
- Modify: `shell/plugin/src/Caelestia/Services/CMakeLists.txt`, `shell/plugin/src/Caelestia/Services/audiocollector.cpp`, `.../audiocollector.hpp`
- Test: build + boot

**Interfaces:**
- Consumes: upstream commits `90ef9e1c` (ring buffer replaces pow2-latency + atomic double-buffer) and `17fa999e` (pipewire correctness); custom's existing `PipeWireWorker` async-negotiation code
- Produces: audio collector with upstream's quantum handling, keeping custom stream-negotiation; `caelestia-util` include path linked into Services

- [ ] **Step 1: Add the new header + link the util include path**

```bash
cp /home/Bisho/custom-caelestia/shell/upstream/plugin/include/util/ringbuffer.hpp /home/Bisho/custom-caelestia/shell/plugin/include/util/ringbuffer.hpp
```

Edit `shell/plugin/src/Caelestia/Services/CMakeLists.txt` — final block must be:

```cmake
    LIBRARIES
        PkgConfig::Pipewire
        PkgConfig::Aubio
        PkgConfig::Cava
        Sensors::Sensors
        caelestia-config
        caelestia-internal
        caelestia-util
)
```

(Verified: `shell/plugin/cmake/qml-module.cmake:48` forwards `${arg_LIBRARIES}` into `target_link_libraries`, and `caelestia-util` is the INTERFACE lib carrying `plugin/include/`.)

- [ ] **Step 2: Study both upstream commits**

```bash
git -C /home/Bisho/caelestia show 90ef9e1c -- plugin/src/Caelestia/Services/audiocollector.cpp plugin/src/Caelestia/Services/audiocollector.hpp plugin/src/Caelestia/circularbuffer.hpp
git -C /home/Bisho/caelestia show 17fa999e -- plugin/src/Caelestia/Services/audiocollector.cpp plugin/src/Caelestia/Services/audiocollector.hpp
```
Expected: `90ef9e1c` = add `#include <mutex>`/`<span>`, remove `PW_KEY_NODE_LATENCY` + `nextPowerOf2` (cpp+hpp), remove `m_writeBuffer`/`m_readBuffer` atomic exchange, route process path through ring buffer; `17fa999e` = +41/-16 const-buffer/stream correctness.

- [ ] **Step 3: Show both sides of the 3-way**

```bash
cd /home/Bisho/custom-caelestia && ./merge-upstream.sh diff plugin/src/Caelestia/Services/audiocollector.cpp
grep -n "m_paramBuilder\|m_paramBuffer\|outlive\|PipeWireWorker::createStream\|std::stop_token" shell/plugin/src/Caelestia/Services/audiocollector.cpp
```

Merge rules (hand edit, no bulk copy):
- **TAKE from upstream:** `util/ringbuffer.hpp`/`<mutex>`/`<span>` includes; delete `nextPowerOf2` (cpp body + hpp decl) and the `PW_KEY_NODE_LATENCY` pow2-latency `pw_properties_setf`; delete `m_writeBuffer`/`m_readBuffer` members + their exchange sites; adopt upstream's ring-buffer read/process path and `17fa999e` const-buffer hunks.
- **KEEP custom:** everything matching `m_paramBuilder` / `m_paramBuffer` / comment `must outlive the async connect negotiation`, the custom `PipeWireWorker::PipeWireWorker(std::stop_token, AudioCollector*, bool micEnabled)` ctor and custom `createStream`/connect flow (custom-vs-base delta ≈376 lines — these are custom's own pipewire correctness work).
- `audiocollector.hpp`: same rule — swap buffer members for upstream's ring-buffer member + include, keep all custom fields/signatures.
- Do NOT touch `shell/plugin/src/Caelestia/Internal/circularbuffer.*` (custom's own, used by `Internal/sparklineitem` — upstream's rework of *its* circularbuffer isn't needed: upstream audio uses `util/ringbuffer.hpp` directly).

- [ ] **Step 4: Build + boot**

```bash
./build-plugin.sh 2>&1 | tail -n 20
grep -c "util/ringbuffer.hpp" /home/Bisho/custom-caelestia/shell/plugin/src/Caelestia/Services/audiocollector.hpp
timeout 20 qs -c caelestia 2>&1 | grep -ci "error\|Unable to assign\|is not a type\|NaN"
```
Expected: build exit 0; grep ≥ 1; boot count ≤ baseline from Task 0 Step 5.

- [ ] **Step 5: Commit**

```bash
git -C /home/Bisho/custom-caelestia add shell/plugin/include/util/ringbuffer.hpp shell/plugin/src/Caelestia/Services/
git -C /home/Bisho/custom-caelestia commit -m "fix(services): pipewire quantum ring buffer (upstream 90ef9e1c+17fa999e) keep custom stream negotiation"
```

---

### Task 8: Full verification + deploy

**Files:**
- Modify: none (verification)
- Test: full suite, boot, deploy, interactive

**Interfaces:**
- Consumes: Tasks 0-7
- Produces: deployed live config, verified parity with baseline

- [ ] **Step 1: Final build**

Run: `./build-plugin.sh 2>&1 | tail -n 10` → exit 0.

- [ ] **Step 2: Test suite matches baseline**

```bash
for t in tests/*.sh; do bash "$t" >/tmp/opencode/t.log 2>&1 && echo "PASS $t" || echo "FAIL $t"; done > /tmp/opencode/tests-after.txt
diff /tmp/opencode/tests-baseline.txt /tmp/opencode/tests-after.txt && echo TESTS-MATCH-BASELINE
```
Expected: `TESTS-MATCH-BASELINE` (ideally zero FAILs both sides).

- [ ] **Step 3: Boot parity + deploy**

```bash
timeout 20 qs -c caelestia 2>&1 | grep -ci "error\|Unable to assign\|is not a type\|NaN"
./deploy.sh
```
Expected: count ≤ baseline; deploy succeeds (ContentWindow.qml lands in `~/.config/quickshell/caelestia/`, shell restarts).

- [ ] **Step 4: Interactive smoke check**

Run: `qs -c caelestia &` then manually: bar + workspaces render; open 2 windows and open drawers (drag mask behaviour); tray audio popout moves volume (exercises AudioCollector); launcher `>2+2` (qalculator); `SUPER+I` Nexus opens. Kill: `pkill -f "qs -c caelestia"`.
Expected: no black icons (Colours imports intact), no QML errors in logs.

---

### Task 9: AGENTS.md biweekly rule + save plan + push

**Files:**
- Modify: `AGENTS.md` (insert new section before `## Key Files to Know`)
- Create: `docs/superpowers/plans/2026-10-10-upstream-sync.md` (this plan, verbatim)

**Interfaces:**
- Consumes: this plan
- Produces: durable cadence rule + plan doc; branch pushed

- [ ] **Step 1: Insert into `AGENTS.md` immediately before the `## Key Files to Know` heading**

```markdown
## Upstream Sync Cadence

- **Plan an upstream sync at least once every 2 weeks.** Never let the gap between sync plans (`~/caelestia` → `shell/upstream` → `shell/`) exceed 14 days, even if only a few upstream commits landed.
- Freshness check: `git -C ~/caelestia fetch origin && git -C ~/caelestia rev-list --count HEAD..origin/main`; last-plan date = newest `docs/superpowers/plans/*-upstream-sync.md`.
- Every sync gets its own plan in `docs/superpowers/plans/YYYY-MM-DD-upstream-sync.md`, modeled on `2026-09-21-upstream-sync.md` / `2026-10-10-upstream-sync.md`: refresh vendored base → verbatim-copy untouched files → targeted 3-way hand-ports of functional commits only → build/boot/deploy verification.
- Do not port cosmetic-only upstream commits (clang-tidy sweeps, formatting) into hand-merged custom files; they stay in `shell/upstream` only.
- Never run `./merge-upstream.sh merge-all`.
```

- [ ] **Step 2: Verify**

Run: `grep -n "Upstream Sync Cadence\|at least once every 2 weeks" /home/Bisho/custom-caelestia/AGENTS.md`
Expected: 2 hits.

- [ ] **Step 3: Save plan doc + commit + push**

```bash
# write this plan verbatim to docs/superpowers/plans/2026-10-10-upstream-sync.md
git -C /home/Bisho/custom-caelestia add AGENTS.md docs/superpowers/plans/2026-10-10-upstream-sync.md
git -C /home/Bisho/custom-caelestia commit -m "docs: upstream sync plan + biweekly sync cadence rule"
git -C /home/Bisho/custom-caelestia push -u origin chore/upstream-sync-2026-10-10
```

---

## Self-Review

1. **Spec coverage:** WIP-first (T0) ✓, base refresh (T1) ✓, 61-file delta fully accounted — 7 verbatim (T2), 1 QML (T3), 4 functional C++ (T4-T6), pipewire 3-way (T7), explicit skip set (c4abc387/anim.hpp documented in constraints; clang-tidy/format/flake/meta/vendor-only files stay in `shell/upstream`) ✓, verify+deploy (T8) ✓, AGENTS cadence rule per user's "at least once per 2 weeks" (T9) ✓.
2. **Placeholder scan:** every task has exact paths, exact code for the 3 editable hunks (ContentWindow/qalculator/cutils/fsmodel), exact copy lists, Run/Expected pairs; Task 7's merge is rules-based by necessity (376-line custom divergence) with exact keep/take greps — mirrors the repo's established `2026-09-21` plan style.
3. **Type consistency:** `caelestia-util` matches `shell/plugin/CMakeLists.txt:19` INTERFACE target; `INTERVAL_DISPLAY_SIGNIFICANT_DIGITS` from libqalculate (already linked); `Qt::SingleShotConnection` needs Qt ≥6.0 (system = 6.11.2 ✓); patch `-p1` paths verified against `git diff` a/b prefixes; branch names consistent.
