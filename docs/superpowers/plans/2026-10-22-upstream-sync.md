# Upstream Sync `5f1c59c0 → 11eed7ce` (2026-10-22) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh the vendored upstream tree and port the three commits that apply cleanly to this fork — the C++ `ClipRect` race fix, the Caps Lock refresh binding, and the empty session-gif guard — while leaving the video-wallpaper cluster and all cosmetic commits in `shell/upstream` only.

**Architecture:** Refresh `shell/upstream` to `11eed7ce` first, then copy only the new `ClipRect`/`RoundedMask` infrastructure verbatim (5 files + one CMake edit), swap the 15 QML call sites by type name, and hand-apply two small hunks to diverged files. Nothing is deployed in this plan: the live tree currently holds uncommitted work from `feat/desktop-clock-controls` that overlaps four of the files this sync touches.

**Tech Stack:** Quickshell QML, C++ QML plugin (CMake, `qt_add_shaders`), `build-plugin.sh`, `tests/run.sh` (26 scripts, 12 suites).

**Spec:** This document's scope table, derived from `git -C ~/caelestia log 5f1c59c0..origin/main` on 2026-10-22: 24 non-merge commits, 179 changed files. Vendored base confirmed byte-identical to `5f1c59c0`. Target confirmed `origin/main` = `11eed7ce`.

## Global Constraints

- All work happens in the worktree `/home/Bisho/.local/share/opencode/worktree/0ccf01/displays-cheatsheet` (`REPO` below) on a new branch from local `master` (`34836aa3`). Never write to `/home/Bisho/custom-caelestia`'s working tree — it holds `feat/desktop-clock-controls` WIP (its file set changes while that work is in progress; record it in Task 0, do not assume a count).
- **Do not deploy in this plan.** Three files this sync modifies are dirty in that branch (`modules/bar/popouts/Wrapper.qml`, `modules/bar/components/workspaces/Workspaces.qml`, `modules/nexus/pages/WallpaperAndStyle.qml`), and a fourth dirty file, `modules/drawers/Interactions.qml`, is not touched here. Deploying would revert that work, and deploying only part of the swap would leave the live tree referencing a deleted `StyledClippingRect`. Deploy is a follow-up after that branch merges. Re-check the dirty set when executing.
- Never run `./merge-upstream.sh merge-all`.
- Cosmetic upstream commits (clang-tidy, formatting, CI, nix, scripts) stay in `shell/upstream` only; never hand-port them into diverged files.
- Every QML file using `Colours.palette.*` must import `qs.services`.
- `pragma ComponentBehavior: Bound` must not be added to `shell/modules/bar/Bar.qml`.
- Commit after every task. No push.
- Commit target: `11eed7ce`. Commit messages cite the upstream SHA they port.

**Scope table (all 24 commits, oldest first):**

| Commit | Subject | Disposition |
|---|---|---|
| `196af98c` | chore(scripts): Ruff warnings | skip — cosmetic |
| `5862d206` | chore(nix): flake inputs | skip — CI |
| `21a75375` | ci: path filtering | skip — CI |
| `ea890577` | docs: issue template | skip — docs |
| `a3a8fe59` | chore: lowercase enum warning | skip — cosmetic |
| `a2c3b775` | chore(nix): flake inputs | skip — CI |
| `f371822b` | chore: linter warnings | skip — cosmetic |
| `0ed56a8b` | refactor: remove lint disables | skip — cosmetic |
| `71c28332` | chore(config,settings): clazy | skip — cosmetic |
| `9ff0a9d8` | chore(nix): flake inputs | skip — CI |
| `f7447a81` | fix(services): capslock state | **port** — Task 4 |
| `1c406e4e` | feat(background): video wallpapers | **defer** — cluster |
| `e62207a3` | fix: clipping rect race | **port** — Tasks 2–3 |
| `5dec9b54` | ci: reusable workflow | skip — CI |
| `507d6628` | feat(settings): don't watch backing file | skip — `RootNode` is unused in this fork's rewritten config backend (no construction site) |
| `b7959294` | feat(utilities): pause wallpaper toggle | **defer** — needs State module |
| `29794ec8` | refactor: add daemons dir | **defer** — file moves + custom `Shortcuts.qml` |
| `9ae5bdbf` | refactor(services): state module | **defer** — depends on daemons dir |
| `6c70d5cb` | chore(config): remove logs | skip — file is `Config/rootnodes.cpp`, absent in this fork |
| `d6cc0d5d` | fix(nexus): video wallpapers | **defer** — needs video backend |
| `588562ea` | refactor(session): hide empty gif | **port** — Task 4 |
| `29fcf69a` | fix(components): update wall if ready | **defer** — `WallpaperImpl` is part of the video cluster |
| `35f3d210` | refactor: CachingImage → Visual | **defer** — 15 custom call sites, prerequisite for video walls |
| `11eed7ce` | fix(drawers): sidebar + utilities | skip — this fork already has the equivalent guard at `modules/drawers/Interactions.qml:323-328` (`inBottomPanel(panels.utilities, …)`) |

**Deferred cluster** (`1c406e4e`, `35f3d210`, `29fcf69a`, `d6cc0d5d`, `b7959294`, `29794ec8`, `9ae5bdbf`, and `507d6628` once reachable): video wallpapers need `Visual`, a 5.6k-line vendored `rgbcx`, a new `Multimedia` plugin module and 25 shaders; they also collide with this fork's background stack (`DesktopClock.qml`, `CookieClock.qml`, `Wallpaper.qml`, the rewritten Nexus `WallpaperAndStyle.qml`). It needs its own spec and live video testing.

## Review Focus

1. A call site still using `StyledClippingRect`/`ClippingRectangle` after the swap → `StyledClippingRect is not a type` at boot. Pinned by Task 3's grep (must be 0).
2. The plugin `.so` not rebuilt/installed before QML loads → `RoundedMask is not a type`. Pinned by Task 2's build + `RoundedMask` in the generated `.qmltypes`, and Task 5's boot-log grep.
3. `qt_add_shaders` rejects the GLSL profile or the Qt ShaderTools component is missing → plugin build fails. Pinned by Task 2's build and the two `.qsb` outputs.
4. A partial or premature deploy over the clock WIP → reverted clock UI, or live QML referencing a deleted type. Pinned by Task 5's deploy gate (this plan contains no deploy command).
5. The session-gif `Loader` collapses to zero height or overlaps the buttons → invisible gif. Pinned by Task 4's byte-level comparison against upstream's `588562ea` file.

---

### Task 0: Preflight and baselines

**Files:** none (verification only).

**Interfaces:**
- Consumes: local `master` = `34836aa3`, `~/caelestia` origin/main = `11eed7ce`
- Produces: clean-tree confirmation, build and test baselines, target SHA recorded

- [ ] **Step 1: Confirm the worktree is clean and on master**

```bash
cd /home/Bisho/.local/share/opencode/worktree/0ccf01/displays-cheatsheet
git status --porcelain | wc -l
git branch --show-current
git log -1 --oneline
```

Expected: `0`, `master`, `34836aa3 feat(overview): search, keyboard selection and workspace paging`. Any dirt → STOP.

- [ ] **Step 2: Record the fork's live WIP without touching it**

```bash
git -C /home/Bisho/custom-caelestia branch --show-current
git -C /home/Bisho/custom-caelestia status --porcelain
```

Expected: `feat/desktop-clock-controls` and a list containing at least `modules/bar/popouts/Wrapper.qml`, `modules/bar/components/workspaces/Workspaces.qml`, `modules/nexus/pages/WallpaperAndStyle.qml`. Paste the full list into the execution log; the deploy gate in Task 5 depends on it.

- [ ] **Step 3: Confirm target and base**

```bash
rm -rf /tmp/opencode/up-base && mkdir /tmp/opencode/up-base
git -C ~/caelestia archive 5f1c59c0 | tar -x -C /tmp/opencode/up-base
git -C ~/caelestia rev-parse --short origin/main
diff -rq /tmp/opencode/up-base /home/Bisho/.local/share/opencode/worktree/0ccf01/displays-cheatsheet/shell/upstream | wc -l
```

Expected: `11eed7ce`, `0`.

- [ ] **Step 4: Record build and test baselines**

```bash
cd /home/Bisho/.local/share/opencode/worktree/0ccf01/displays-cheatsheet
./build-plugin.sh 2>&1 | tail -3
bash tests/run.sh 2>&1 | tail -3
```

Expected: build exit 0 (`Done! Plugin rebuilt…`); `Results: 12 passed, 0 failed`.

- [ ] **Step 5: No commit** (nothing changed).

---

### Task 1: Branch + refresh vendored base

**Files:**
- Modify: `shell/upstream/` (whole tree)

**Interfaces:**
- Consumes: `~/caelestia` at `11eed7ce`
- Produces: branch `chore/upstream-sync-2026-10-22`, `shell/upstream` byte-identical to upstream

- [ ] **Step 1: Create the branch**

```bash
cd /home/Bisho/.local/share/opencode/worktree/0ccf01/displays-cheatsheet
git checkout -b chore/upstream-sync-2026-10-22
```

Expected: `Switched to a new branch 'chore/upstream-sync-2026-10-22'`.

- [ ] **Step 2: Recopy the base**

```bash
cd /home/Bisho/.local/share/opencode/worktree/0ccf01/displays-cheatsheet
rm -rf shell/upstream
cp -a /home/Bisho/caelestia shell/upstream
rm -rf shell/upstream/.git
diff -rq shell/upstream /home/Bisho/caelestia 2>&1 | grep -v '\.git' | wc -l
```

Expected: `0`.

- [ ] **Step 3: Commit**

```bash
git add shell/upstream
git commit -m "chore: refresh shell/upstream to ~/caelestia@11eed7ce"
```

---

### Task 2: `ClipRect` + `RoundedMask` infrastructure (upstream `e62207a3`)

**Files:**
- Create: `shell/components/ClipRect.qml`
- Create: `shell/plugin/src/Caelestia/Components/roundedmask.cpp`
- Create: `shell/plugin/src/Caelestia/Components/roundedmask.hpp`
- Create: `shell/plugin/src/Caelestia/Components/shaders/roundedmask.frag`
- Create: `shell/plugin/src/Caelestia/Components/shaders/roundedmask.vert`
- Modify: `shell/plugin/src/Caelestia/Components/CMakeLists.txt`

**Interfaces:**
- Consumes: `git -C ~/caelestia show 11eed7ce:<path>` for each new file; Qt6 `ShaderTools` is already required at `shell/plugin/CMakeLists.txt:1`
- Produces: QML type `qs.components/ClipRect` with `radius`, `topLeftRadius`, `topRightRadius`, `bottomRightRadius`, `bottomLeftRadius`, `color`, `contentData`; C++ type `RoundedMask` in module `Caelestia.Components`

- [ ] **Step 1: Copy the five files from the target commit**

```bash
cd /home/Bisho/.local/share/opencode/worktree/0ccf01/displays-cheatsheet
git -C ~/caelestia show 11eed7ce:components/ClipRect.qml > shell/components/ClipRect.qml
for f in roundedmask.cpp roundedmask.hpp; do
  git -C ~/caelestia show "11eed7ce:plugin/src/Caelestia/Components/$f" > "shell/plugin/src/Caelestia/Components/$f"
done
mkdir -p shell/plugin/src/Caelestia/Components/shaders
for f in roundedmask.frag roundedmask.vert; do
  git -C ~/caelestia show "11eed7ce:plugin/src/Caelestia/Components/shaders/$f" > "shell/plugin/src/Caelestia/Components/shaders/$f"
done
wc -l shell/components/ClipRect.qml shell/plugin/src/Caelestia/Components/roundedmask.cpp shell/plugin/src/Caelestia/Components/roundedmask.hpp shell/plugin/src/Caelestia/Components/shaders/roundedmask.frag shell/plugin/src/Caelestia/Components/shaders/roundedmask.vert
```

Expected: `41`, `261`, `112`, `26`, `19`.

- [ ] **Step 2: Edit `shell/plugin/src/Caelestia/Components/CMakeLists.txt`**

Add `roundedmask.cpp` after `linearindicatormanager.cpp`, add `Qt::Gui` to `LIBRARIES` (keep the existing `Qt::Quick` and the two `set_source_files_properties` lines untouched), and append after them:

```cmake
qt_add_shaders(caelestia-components "components_shaders"
    BATCHABLE OPTIMIZED NOHLSL NOMSL
    GLSL "300es,330"
    PREFIX "/"
    FILES
        shaders/roundedmask.frag
        shaders/roundedmask.vert
)
```

Do **not** copy upstream's CMakeLists verbatim: it lists `sparklineitem.cpp`, `visualiserbars.cpp` and `caelestia-core`, which this fork does not build.

- [ ] **Step 3: Build and verify the shader + type registration**

```bash
cd /home/Bisho/.local/share/opencode/worktree/0ccf01/displays-cheatsheet
./build-plugin.sh 2>&1 | tail -5
find build -name '*.qsb' | grep -c roundedmask
find build -name 'libcaelestia-componentsplugin.so' -exec strings {} + | grep -c RoundedMask
```

Expected: build exit 0; `2`; at least `1`. A build failure here means the shader profile or ShaderTools wiring is wrong — do not proceed to Task 3.

- [ ] **Step 4: Commit**

```bash
git add shell/components/ClipRect.qml shell/plugin/src/Caelestia/Components
git commit -m "feat(components): add C++ backed ClipRect and RoundedMask (upstream e62207a3)"
```

---

### Task 3: Swap the 15 clipping call sites (upstream `e62207a3`, QML half)

**Files (all in `shell/`):**
- Modify: `modules/lock/Media.qml:11`, `modules/lock/NotifGroup.qml:108`, `modules/lock/NotifDock.qml:32`, `modules/windowinfo/Preview.qml:21`, `modules/launcher/items/WallpaperItem.qml:71`, `modules/sidebar/NotifGroup.qml:129`, `modules/sidebar/NotifDock.qml:77`, `modules/dashboard/performance/BatteryTank.qml:10`, `modules/dashboard/Content.qml:69`, `modules/bar/popouts/Wrapper.qml:138`, `modules/bar/components/workspaces/Workspaces.qml:12`, `modules/nexus/common/WallItem.qml:52`, `modules/nexus/pages/WallpaperAndStyle.qml:27`, `modules/notifications/Content.qml:198`, `modules/notifications/Notification.qml:120`
- Delete: `shell/components/StyledClippingRect.qml`

**Interfaces:**
- Consumes: `ClipRect` from Task 2; all 15 files already import `qs.components`, so no import is added
- Produces: zero references to `StyledClippingRect`/`ClippingRectangle` outside `shell/upstream`

- [ ] **Step 1: Replace the type names**

Every site sets only `radius` and/or `color`, which `ClipRect` supports, so a word-boundary rename is exact (it also catches the two `sourceComponent: StyledClippingRect {` children):

```bash
cd /home/Bisho/.local/share/opencode/worktree/0ccf01/displays-cheatsheet
FILES=(
  shell/modules/lock/Media.qml
  shell/modules/lock/NotifGroup.qml
  shell/modules/lock/NotifDock.qml
  shell/modules/windowinfo/Preview.qml
  shell/modules/launcher/items/WallpaperItem.qml
  shell/modules/sidebar/NotifGroup.qml
  shell/modules/sidebar/NotifDock.qml
  shell/modules/dashboard/performance/BatteryTank.qml
  shell/modules/dashboard/Content.qml
  shell/modules/bar/popouts/Wrapper.qml
  shell/modules/bar/components/workspaces/Workspaces.qml
  shell/modules/nexus/common/WallItem.qml
  shell/modules/nexus/pages/WallpaperAndStyle.qml
  shell/modules/notifications/Content.qml
  shell/modules/notifications/Notification.qml
)
sed -i -E 's/\b(StyledClippingRect|ClippingRectangle)\b/ClipRect/g' "${FILES[@]}"
```

- [ ] **Step 2: Drop the now-unused import and the old component**

```bash
cd /home/Bisho/.local/share/opencode/worktree/0ccf01/displays-cheatsheet
sed -i '/^import Quickshell\.Widgets$/d' shell/modules/dashboard/Content.qml
rm shell/components/StyledClippingRect.qml
```

Only `dashboard/Content.qml` loses the import (upstream does the same; the other files still use other `Quickshell.Widgets` symbols).

- [ ] **Step 3: Verify no stragglers**

```bash
cd /home/Bisho/.local/share/opencode/worktree/0ccf01/displays-cheatsheet
grep -rn "StyledClippingRect\|ClippingRectangle" shell --include=*.qml --exclude-dir=upstream | wc -l
grep -rn "ClipRect {" shell --include=*.qml --exclude-dir=upstream | wc -l
grep -c "import Quickshell.Widgets" shell/modules/dashboard/Content.qml || true
```

Expected: `0`, `15`, `0`.

- [ ] **Step 4: Run the static QML suites**

```bash
bash tests/run.sh 2>&1 | tail -3
```

Expected: `Results: 12 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add shell/modules shell/components
git commit -m "fix(components): use ClipRect instead of ClippingRectangle at 15 sites (upstream e62207a3)"
```

---

### Task 4: Caps Lock refresh + empty session gif (upstream `f7447a81`, `588562ea`)

**Files:**
- Modify: `shell/services/Hypr.qml:235-241`
- Modify: `shell/modules/session/Content.qml:56-66`

**Interfaces:**
- Consumes: current diverged files (both regions are still identical to the pre-fix upstream base, verified 2026-10-22)
- Produces: `code:66` Caps Lock binding in both the Lua and legacy branches; session gif wrapped in a `Loader` gated on `Config.paths.sessionGif.trim() !== ""`

- [ ] **Step 1: Replace `reloadDynamicConfs()` in `shell/services/Hypr.qml`**

```qml
    function reloadDynamicConfs(): void {
        if (usingLua) {
            extras.batchMessage(['eval hl.bind("Caps_Lock", hl.dsp.global("caelestia:refreshDevices"), { locked = true, non_consuming = true, ignore_mods = true, release = true })', 'eval hl.bind("Num_Lock", hl.dsp.global("caelestia:refreshDevices"), { locked = true, non_consuming = true, ignore_mods = true, release = true })', 'eval hl.bind("code:66", hl.dsp.global("caelestia:refreshDevices"), { locked = true, non_consuming = true, ignore_mods = true, release = true })']);
        } else {
            extras.batchMessage(["keyword bindlni ,Caps_Lock,global,caelestia:refreshDevices", "keyword bindlni ,Num_Lock,global,caelestia:refreshDevices", "keyword bindlni ,code:66,global,caelestia:refreshDevices"]);
        }
    }
```

- [ ] **Step 2: Replace the `AnimatedImage` block in `shell/modules/session/Content.qml` with upstream's `Loader`**

```qml
    Loader {
        active: Config.paths.sessionGif.trim() !== ""

        sourceComponent: AnimatedImage {
            width: Tokens.sizes.session.button
            height: Tokens.sizes.session.button
            sourceSize.width: width * ((QsWindow.window as QsWindow)?.devicePixelRatio ?? 1)

            playing: visible
            asynchronous: true
            speed: Config.general.sessionGifSpeed
            source: Paths.absolutePath(Config.paths.sessionGif)
            fillMode: AnimatedImage.PreserveAspectFit
        }
    }
```

- [ ] **Step 3: Verify the hunks match upstream exactly**

```bash
cd /home/Bisho/.local/share/opencode/worktree/0ccf01/displays-cheatsheet
grep -c 'code:66' shell/services/Hypr.qml
grep -c 'Config.paths.sessionGif.trim() !== ""' shell/modules/session/Content.qml
diff <(sed -n '/^    Loader {/,/^    }$/p' shell/modules/session/Content.qml) <(git -C ~/caelestia show 588562ea:modules/session/Content.qml | sed -n '/^    Loader {/,/^    }$/p') && echo GIF-MATCHES-UPSTREAM
```

Expected: `2`, `1`, `GIF-MATCHES-UPSTREAM`.

- [ ] **Step 4: Tests**

```bash
bash tests/run.sh 2>&1 | tail -3
```

Expected: `Results: 12 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add shell/services/Hypr.qml shell/modules/session/Content.qml
git commit -m "fix(services,session): capslock code:66 refresh + hide empty gif (upstream f7447a81, 588562ea)"
```

---

### Task 5: Verify the branch and stop at the deploy gate

**Files:** none (verification only).

**Interfaces:**
- Consumes: Tasks 1–4
- Produces: green build + suites, a diff whitelist check, and an explicit decision not to deploy yet

- [ ] **Step 1: Build and full suite**

```bash
cd /home/Bisho/.local/share/opencode/worktree/0ccf01/displays-cheatsheet
./build-plugin.sh 2>&1 | tail -3
bash tests/run.sh 2>&1 | tail -3
```

Expected: build exit 0; `Results: 12 passed, 0 failed`.

- [ ] **Step 2: Diff whitelist — nothing outside the planned set**

```bash
cd /home/Bisho/.local/share/opencode/worktree/0ccf01/displays-cheatsheet
git diff --name-only master...HEAD | grep -v '^shell/upstream/' | sort
```

Expected exactly these 24 entries:

```
shell/components/ClipRect.qml
shell/components/StyledClippingRect.qml
shell/modules/bar/components/workspaces/Workspaces.qml
shell/modules/bar/popouts/Wrapper.qml
shell/modules/dashboard/Content.qml
shell/modules/dashboard/performance/BatteryTank.qml
shell/modules/launcher/items/WallpaperItem.qml
shell/modules/lock/Media.qml
shell/modules/lock/NotifDock.qml
shell/modules/lock/NotifGroup.qml
shell/modules/nexus/common/WallItem.qml
shell/modules/nexus/pages/WallpaperAndStyle.qml
shell/modules/notifications/Content.qml
shell/modules/notifications/Notification.qml
shell/modules/session/Content.qml
shell/modules/sidebar/NotifDock.qml
shell/modules/sidebar/NotifGroup.qml
shell/modules/windowinfo/Preview.qml
shell/plugin/src/Caelestia/Components/CMakeLists.txt
shell/plugin/src/Caelestia/Components/roundedmask.cpp
shell/plugin/src/Caelestia/Components/roundedmask.hpp
shell/plugin/src/Caelestia/Components/shaders/roundedmask.frag
shell/plugin/src/Caelestia/Components/shaders/roundedmask.vert
shell/services/Hypr.qml
```

Any other path → STOP and account for it.

- [ ] **Step 3 (optional, needs the human's OK): boot the branch's QML for 8 seconds**

This starts a second shell instance, so a duplicate bar appears during the window. Skip it if the desktop is in active use.

```bash
cd /home/Bisho/.local/share/opencode/worktree/0ccf01/displays-cheatsheet
SIG=$(ls -t /run/user/1000/hypr/ | head -1)
timeout 8 env HYPRLAND_INSTANCE_SIGNATURE="$SIG" qs -p "$PWD/shell" > /tmp/opencode/sync-boot.log 2>&1 || true
grep -E "RoundedMask|ClipRect|StyledClippingRect|is not a type|ReferenceError|TypeError" /tmp/opencode/sync-boot.log | head
```

Expected: no matching lines. Matching `RoundedMask`/`ClipRect` errors → the plugin install or a swap is wrong.

- [ ] **Step 4: Deploy gate — do not deploy**

Record and report: the live config `~/.config/quickshell/caelestia/` currently carries `feat/desktop-clock-controls` WIP. Deploy only after that branch is committed and merged, then run `./install.sh --update` and restart the shell. The post-deploy smoke must cover: notifications (sidebar + lock), bar workspace pills, launcher wallpaper grid, Nexus wallpaper page, and the session menu gif with an empty `sessionGif` path.

- [ ] **Step 5: No commit.**

---

## Self-Review

1. **Spec coverage:** all 24 commits in the scope table — 3 ported (`e62207a3` → Tasks 2–3, `f7447a81` + `588562ea` → Task 4), 3 skipped with a file/line reason (`507d6628`, `6c70d5cb`, `11eed7ce`), 7 deferred as one named cluster, 11 cosmetic/CI/nix/scripts. Base refresh (Task 1), verification and deploy gate (Task 5).
2. **Placeholder scan:** every task has exact paths, exact replacement text, and Run/Expected pairs; the only copied-by-command content is verbatim upstream source, pinned to `11eed7ce`.
3. **Type consistency:** `ClipRect` lives in `qs.components` and has `radius`/per-corner radii/`color`/`contentData`; all 15 sites set only `radius`/`color`; `RoundedMask` is exported by `Caelestia.Components`, which `ClipRect.qml` imports; `CAnim` resolves implicitly from `shell/components/`; `qt_add_shaders` is available because `ShaderTools` is already in `find_package`.
4. **Review Focus:** each of the five failure modes has a check in its owning task (greps in Tasks 3–4, build/qmltypes in Task 2, boot-log grep and deploy gate in Task 5).
5. **Proportion:** five tasks, ~1 file of prose for a 179-file upstream delta; the deferred cluster is described, not planned.
