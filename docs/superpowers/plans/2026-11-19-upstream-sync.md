# Upstream Sync `11eed7ce → e72df8eb` (2026-11-19) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh the vendored upstream tree to `e72df8eb` and hand-port the five commits whose behaviour this fork can actually consume — a dashboard tab clamp, unnamed-Bluetooth-device ordering in two lists, Ctrl+U on the lock screen, and a Do-Not-Disturb shortcut — while leaving the sixteen commits that need subsystems this fork replaced (I18n, the C++ config backend, `daemons/`, the sidebar hover model, `Visual`/video) documented but unported.

**Architecture:** Refresh `shell/upstream` first (it is excluded from deployment by `install.sh:435`, so it cannot affect the live shell). Then port each fix directly into the fork's own file, rewritten against the fork's conventions: `qsTr(...)` instead of `Tr.tr(...)` and `dashState.currentTab` instead of `screenState.dashboardTab`. No C++ is touched, so no plugin rebuild is needed.

**Tech Stack:** Quickshell QML, Hyprland global shortcuts (`CustomShortcut` → `caelestia:<name>`), `tests/run.sh` (20 suites), Qt6 `qmllint` at `/usr/lib/qt6/bin/qmllint`.

**Spec:** This document's scope table, derived from `git -C ~/caelestia log 11eed7ce..origin/main` on 2026-11-19: **22 non-merge commits, 196 changed files**. Vendored base confirmed byte-identical to `11eed7ce` (`diff -rq` over the whole tree = 0 differences). Target confirmed `origin/main` = `e72df8eb`.

## Global Constraints

- Work in the worktree `/home/Bisho/.local/share/opencode/worktree/0ccf01/widget-foundation` (`REPO` below), on branch `chore/upstream-sync-2026-11-19`, created from local `master` (`d08699e3`). It is already created and checked out.
- **No C++ changes.** No ported commit touches `plugin/`; `./build-plugin.sh` is not run.
- **The live config is only written in Task 6.** `~/config/quickshell/caelestia` is the running shell; deploying earlier would put unverified QML in front of the user mid-branch.
- Never run `./merge-upstream.sh merge-all`.
- This fork has **no I18n module** (`plugin/src/Caelestia/I18n/` is absent, `Tr` is unresolvable, every fork-owned file uses `qsTr`). Any upstream hunk containing `Tr.tr`/`Tr.trCtx`/`Tr.trN` must be rewritten to `qsTr`/`qsTr(...).arg(...)` before it enters a fork file.
- Cosmetic and infrastructure commits (nix flake bumps, CI, docs, clang-tidy, namespace renames) stay in `shell/upstream` only.
- Commit after every task. No push. Commit messages cite the upstream SHA they port.
- Every commit leaves `bash tests/run.sh` green.

**Scope table (all 22 commits, oldest first):**

| Commit | Subject | Disposition |
|---|---|---|
| `196af98c`→ already in base | — | — |
| `e72df8eb` | chore(nix): flake inputs | skip — nix |
| `fd630ffe` | fix(dashboard): clamp tab index when tab count changes | **port** — Task 2 |
| `80bd0021` | fix: fully qualify QML exposed types | skip — needs `0b0beb52`'s namespace, and the files it edits (`Config/common.hpp`, `rootnodes.hpp`) do not exist in this fork's rewritten config backend |
| `5cbf60e7` | refactor: use absolute module imports | defer — non-functional import-style refactor across 15 files, 12 of which this fork has rewritten; nothing currently misresolves |
| `f80a9807` | chore(nix): flake inputs | skip — nix |
| `cb43fc71` | fix(nexus): sort unnamed bt devices last | **port** — Task 3 |
| `72f60b1d` | fix(bar): sort unnamed devices last in bluetooth popout | **port** — Task 3 |
| `bcbb5d51` | fix(drawers): match border radius to game mode radius | defer — depends on `b9a15ba9`'s configurable `gameMode.options` and on `qs.daemons`, which this fork does not have |
| `b9a15ba9` | feat(utilities): make GameMode options configurable | defer — edits `daemons/GameMode.qml` (this fork's GameMode is `services/GameMode.qml`) and `utilitiesconfig.hpp` in the replaced C++ backend; a feature, not a fix |
| `3628f561` | ci: check-pr-title | skip — CI |
| `8ba51e4b` | chore(nix): flake inputs | skip — nix |
| `b51fdb35` | ci: remove check-pr-approvals | skip — CI |
| `48b323fa` | feat(lock): clear password with Ctrl+U | **port** — Task 4 |
| `4b1dae84` | fix(i18n): format dates and times based on locale | defer — adds `Tr.formatDateTime`/`Tr.locale`; the fork has no I18n module or `Tr` at all |
| `44ed8f76` | chore(nix): flake inputs | skip — nix |
| `2e1c51fa` | feat(nexus): sidebar showOnHover toggle | defer — the fork's sidebar hover is `GlobalConfig.sidebar.hoverEdge/hoverWidth/hoverHeight` plus `visibilities.sidebar`; upstream's `Config.sidebar.showOnHover` does not exist here, so the toggle would bind to nothing |
| `46e970cd` | fix(drawers): sidebarShortcutActive | defer — same sidebar-model divergence, and it edits `daemons/Shortcuts.qml` (fork equivalent is `modules/Shortcuts.qml`) |
| `be553a69` | feat(notifs): CustomShortcut to toggle DND | **port** — Task 5 (rewritten against `Notifs.dnd`; this fork has no `PersistentState`) |
| `9dfa80da` | chore(nix): flake inputs | skip — nix |
| `0b0beb52` | refactor: caelestia namespace → caelestia::shell | skip — pure rename over 156 C++ files; the fork's `Config/` is a different implementation and would need the rename applied by hand for no behaviour change |
| `28fcf7d3` | feat(launcher,nexus): improve wallpaper previews | defer — needs `Caelestia.State` (`PersistentState`) and `Visual`, neither of which exists here |
| `f3cebbbd` | perf(multimedia): unload media player when not playing | defer — edits `Visual.qml`/`visualsource.*`, part of the deferred video-wallpaper cluster |

The deferred set is the same block of subsystems identified in `2026-10-22-upstream-sync.md`; this sync adds the i18n and sidebar-hover divergences to that list.

## Review Focus

1. **A hunk copied verbatim re-introduces `Tr.` into a fork file** → `Tr is not defined` at load, whole shell down (this fork has no I18n module). Pinned by the `no Tr in fork QML` assertion in Task 2's suite, which greps the five touched files for `Tr\.`.
2. **The dashboard clamp is guarded against a zero-tab dashboard** → `itemAt(-1)` would return `null` every frame and the tab strip would collapse to 0×0 instead of hiding cleanly. Pinned by the `dashboardTabs.length > 0 ?` assertion.
3. **`deviceName` does not exist on the device type** → the sort key coerces `undefined` and silently does nothing. Verified against `/usr/lib/qt6/qml/Quickshell/Bluetooth/quickshell-bluetooth.qmltypes` (`deviceName` present) and pinned by Task 3's assertion.
4. **Ctrl+U reaches the printable-text branch** → `event.text` is `"\x15"`, a control character, so the existing printable guard would swallow it and the buffer would not clear. Pinned by the key-check ordering in Task 4 and its assertion.
5. **The DND shortcut writes a different flag than the IPC handler** → the shortcut and `qs ipc call notifs toggleDnd` would disagree. Pinned by Task 5's assertion that both paths write `root.dnd`.

---

### Task 0: Preflight and baselines

**Files:** none (verification only).

**Interfaces:**
- Consumes: branch `chore/upstream-sync-2026-11-19` at `d08699e3`, `~/caelestia` `origin/main` = `e72df8eb`
- Produces: recorded baselines and the confirmed vendored-base identity

- [ ] **Step 1: Confirm branch, clean tree and target**

```bash
cd /home/Bisho/.local/share/opencode/worktree/0ccf01/widget-foundation
git status --porcelain | wc -l          # expect 0
git log -1 --oneline                    # expect d08699e3 docs(agents): …
git -C ~/caelestia rev-parse --short origin/main   # expect e72df8eb
```

- [ ] **Step 2: Confirm the vendored base really is `11eed7ce`**

```bash
rm -rf /tmp/opencode/upbase && mkdir -p /tmp/opencode/upbase
git -C ~/caelestia archive 11eed7ce | tar -x -C /tmp/opencode/upbase
diff -rq /tmp/opencode/upbase shell/upstream | grep -v '\.git' | wc -l   # expect 0
```

- [ ] **Step 3: Record the test baseline**

```bash
bash tests/run.sh 2>&1 | tail -2      # expect Results: 20 passed, 0 failed
```

- [ ] **Step 4: No commit.**

---

### Task 1: Refresh the vendored base to `e72df8eb`

**Files:**
- Modify: `shell/upstream/` (whole tree)

**Interfaces:**
- Consumes: `~/caelestia` at `e72df8eb`
- Produces: `shell/upstream` byte-identical to upstream `e72df8eb`

- [ ] **Step 1: Recopy the upstream tree**

```bash
cd /home/Bisho/.local/share/opencode/worktree/0ccf01/widget-foundation
rm -rf shell/upstream && mkdir -p shell/upstream
git -C ~/caelestia archive e72df8eb | tar -x -C shell/upstream
```

Use `git archive`, not `cp -a ~/caelestia`: `cp` copies `.git`, uncommitted user state, and the fork's own experimental files.

- [ ] **Step 2: Prove the copy is exact**

```bash
cd /home/Bisho/.local/share/opencode/worktree/0ccf01/widget-foundation
rm -rf /tmp/opencode/upnew && mkdir -p /tmp/opencode/upnew
git -C ~/caelestia archive e72df8eb | tar -x -C /tmp/opencode/upnew
diff -rq /tmp/opencode/upnew shell/upstream | wc -l     # expect 0
test ! -e shell/upstream/.git && echo "no .git"
```

- [ ] **Step 3: Commit**

```bash
git add shell/upstream
git commit -m "chore: refresh shell/upstream to ~/caelestia@e72df8eb"
```

---

### Task 2: Dashboard tab clamp (upstream `fd630ffe`)

**Files:**
- Modify: `shell/modules/dashboard/Content.qml:48-49`, `:83`, and the `Repeater` at `:129-137`
- Create: `tests/upstream_ports_test.sh`
- Modify: `tests/run.sh` (register the suite after `widget_registry_test`)

**Interfaces:**
- Consumes: `root.dashState.currentTab` (writable `int`, `modules/dashboard/Content.qml:83`), `repeater` (id on the `Repeater` at `:129`)
- Produces: `tests/upstream_ports_test.sh`, a `pass`/`fail` suite in the style of `tests/widget_test.sh`, which later tasks extend

- [ ] **Step 1: Create the suite with the three dashboard assertions**

`tests/upstream_ports_test.sh`:

```bash
#!/usr/bin/env bash
# Structural gate for commits ported from upstream. Each assertion is tied to a
# specific fix; deleting the fix must fail the suite.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHELL_DIR="$REPO_DIR/shell"
PASS=0
FAIL=0

pass() { echo -e "  \033[0;32mPASS\033[0m $1"; ((++PASS)); }
fail() { echo -e "  \033[0;31mFAIL\033[0m $1"; ((++FAIL)); }

DASH="$SHELL_DIR/modules/dashboard/Content.qml"

grep -qF 'Math.min(root.dashState.currentTab, repeater.count - 1)' "$DASH" \
    && pass "dashboard tab index is clamped to the tab count" \
    || fail "dashboard tab index is not clamped (upstream fd630ffe)"

grep -qF 'dashboardTabs.length > 0 ? view.implicitWidth' "$DASH" \
    && pass "dashboard width collapses to zero with no tabs" \
    || fail "dashboard width is not guarded for zero tabs (upstream fd630ffe)"

grep -qF 'root.dashState.currentTab = Math.max(0, count - 1)' "$DASH" \
    && pass "dashboard clamps the stored tab on count change" \
    || fail "dashboard does not clamp the stored tab on count change (upstream fd630ffe)"

echo ""
echo "upstream_ports_test: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 2: Register the suite**

In `tests/run.sh`, after the `widget_registry_test` line:

```bash
test_suite "upstream_ports_test" "tests/upstream_ports_test.sh"
```

- [ ] **Step 3: Run it to prove it fails**

```bash
chmod +x tests/upstream_ports_test.sh
bash tests/upstream_ports_test.sh
```

Expected: `0 passed, 3 failed`. If any assertion passes before the port, the assertion is wrong — fix it before continuing.

- [ ] **Step 4: Apply the three edits**

```qml
    readonly property real nonAnimWidth: dashboardTabs.length > 0 ? view.implicitWidth + viewWrapper.anchors.margins * 2 : 0
    readonly property real nonAnimHeight: dashboardTabs.length > 0 ? tabs.implicitHeight + tabs.anchors.topMargin + view.implicitHeight + viewWrapper.anchors.margins * 2 : 0
```

```qml
            readonly property int currentIndex: Math.min(root.dashState.currentTab, repeater.count - 1)
```

Inside `Repeater` (id `repeater`), directly after its `model: ScriptModel { … }` block and before `delegate:`:

```qml
                    onCountChanged: {
                        if (root.dashState.currentTab >= count)
                            root.dashState.currentTab = Math.max(0, count - 1);
                    }
```

The upstream commit's `CUtils.dependency(repeater.count)` line is deliberately not ported: this fork's `currentItem` already reads `repeater.count;` directly, which has the same effect.

- [ ] **Step 5: Run the suite and the runner**

```bash
bash tests/upstream_ports_test.sh    # expect 3 passed, 0 failed
bash tests/run.sh 2>&1 | tail -2     # expect Results: 21 passed, 0 failed
```

- [ ] **Step 6: Commit**

```bash
git add tests/upstream_ports_test.sh tests/run.sh shell/modules/dashboard/Content.qml
git commit -m "fix(dashboard): clamp tab index when tab count changes (upstream fd630ffe)"
```

---

### Task 3: Unnamed Bluetooth devices sort last (upstream `72f60b1d`, `cb43fc71`)

**Files:**
- Modify: `shell/modules/bar/popouts/Bluetooth.qml:54`, `:65`
- Modify: `shell/modules/nexus/pages/bluetooth/BluetoothPairing.qml:76`
- Test: `tests/upstream_ports_test.sh` (append)

**Interfaces:**
- Consumes: `BluetoothDevice.deviceName` (string; present in `/usr/lib/qt6/qml/Quickshell/Bluetooth/quickshell-bluetooth.qmltypes:187`), `BluetoothDevice.connected` (bool)
- Produces: nothing consumed by later tasks

- [ ] **Step 1: Append the three assertions**

Add before the summary block of `tests/upstream_ports_test.sh`:

```bash
BT_POPOUT="$SHELL_DIR/modules/bar/popouts/Bluetooth.qml"
BT_PAIRING="$SHELL_DIR/modules/nexus/pages/bluetooth/BluetoothPairing.qml"

grep -qF '(!a.deviceName - !b.deviceName)' "$BT_POPOUT" \
    && pass "bluetooth popout sorts self-named devices first" \
    || fail "bluetooth popout does not sort unnamed devices last (upstream 72f60b1d)"

grep -qF '(!a.deviceName - !b.deviceName)' "$BT_PAIRING" \
    && pass "pairing list sorts self-named devices first" \
    || fail "pairing list does not sort unnamed devices last (upstream cb43fc71)"

grep -qF 'devices.reduce((total, d) => total + d.connected, 0)' "$BT_POPOUT" \
    && pass "bluetooth popout counts connected devices without an allocation" \
    || fail "bluetooth popout still filters for the connected count (upstream 72f60b1d)"
```

- [ ] **Step 2: Run it to prove the new assertions fail**

```bash
bash tests/upstream_ports_test.sh
```

Expected: `3 passed, 3 failed` (Task 2's three still pass).

- [ ] **Step 3: Apply the popout edits**

`Bluetooth.qml:54`:

```qml
            const connected = devices.reduce((total, d) => total + d.connected, 0);
```

`Bluetooth.qml:65`:

```qml
            // Connected/paired devices first, then devices that report their own name, and unnamed ones last
            values: [...Bluetooth.devices.values].sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || (!a.deviceName - !b.deviceName) || a.name.localeCompare(b.name)).slice(0, 5) // qmllint disable unresolved-type
```

Keep the trailing `// qmllint disable unresolved-type` comment — this file has no `import Quickshell.Bluetooth` type registration in qmllint's view.

- [ ] **Step 4: Apply the pairing-list edit**

`BluetoothPairing.qml:76`, inside `values:`:

```qml
                values: Bluetooth.devices.values.filter(d => !d.bonded).sort((a, b) => (b.pairing - a.pairing) || (!a.deviceName - !b.deviceName) || a.name.localeCompare(b.name)) // qmllint disable unresolved-type
```

- [ ] **Step 5: Run the suite and the runner**

```bash
bash tests/upstream_ports_test.sh    # expect 6 passed, 0 failed
bash tests/run.sh 2>&1 | tail -2     # expect 21 passed, 0 failed
```

- [ ] **Step 6: Commit**

```bash
git add tests/upstream_ports_test.sh shell/modules/bar/popouts/Bluetooth.qml shell/modules/nexus/pages/bluetooth/BluetoothPairing.qml
git commit -m "fix(bluetooth): sort unnamed devices last (upstream 72f60b1d, cb43fc71)"
```

---

### Task 4: Ctrl+U clears the lock password (upstream `48b323fa`)

**Files:**
- Modify: `shell/modules/lock/Pam.qml:26-33`
- Test: `tests/upstream_ports_test.sh` (append)

**Interfaces:**
- Consumes: `buffer` (local property on `Scope`), `event: KeyEvent`
- Produces: nothing consumed by later tasks

- [ ] **Step 1: Append the assertion**

```bash
PAM="$SHELL_DIR/modules/lock/Pam.qml"

grep -qF 'event.key === Qt.Key_U' "$PAM" \
    && pass "lock screen clears the password with Ctrl+U" \
    || fail "lock screen ignores Ctrl+U (upstream 48b323fa)"
```

- [ ] **Step 2: Run it to prove it fails**

```bash
bash tests/upstream_ports_test.sh    # expect 6 passed, 1 failed
```

- [ ] **Step 3: Replace the key-handling branch**

Replace the current `Key_Backspace` branch with:

```qml
        } else if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_U) && (event.modifiers & Qt.ControlModifier)) {
            buffer = "";
        } else if (event.key === Qt.Key_Backspace) {
            buffer = buffer.slice(0, -1);
```

Ctrl+Backspace still clears (the first branch now matches it), and plain Backspace still deletes one character. The branch must stay **before** the printable-text check: `event.text` for Ctrl+U is `"\x15"`, which the `/^[^\x00-\x1F\x7F-\x9F]+$/` guard rejects.

- [ ] **Step 4: Run the suite and the runner**

```bash
bash tests/upstream_ports_test.sh    # expect 7 passed, 0 failed
bash tests/run.sh 2>&1 | tail -2     # expect 21 passed, 0 failed
```

- [ ] **Step 5: Commit**

```bash
git add tests/upstream_ports_test.sh shell/modules/lock/Pam.qml
git commit -m "feat(lock): clear password with Ctrl+U (upstream 48b323fa)"
```

---

### Task 5: Do-Not-Disturb shortcut (upstream `be553a69`)

**Files:**
- Modify: `shell/services/Notifs.qml` (after the `clearNotifs` `CustomShortcut`, before the `IpcHandler`)
- Test: `tests/upstream_ports_test.sh` (append)

**Interfaces:**
- Consumes: `root.dnd` (`property alias dnd: props.dnd`, `services/Notifs.qml:20`), `CustomShortcut` (`components/misc/CustomShortcut.qml` → `GlobalShortcut { appid: "caelestia" }`)
- Produces: global shortcut name `caelestia:toggleDnd`, bindable with `hl.dsp.global("caelestia:toggleDnd")`

- [ ] **Step 1: Append the two assertions**

```bash
NOTIFS="$SHELL_DIR/services/Notifs.qml"

grep -qF 'name: "toggleDnd"' "$NOTIFS" \
    && pass "notifications expose a toggleDnd shortcut" \
    || fail "no toggleDnd shortcut (upstream be553a69)"

grep -qF 'onPressed: root.dnd = !root.dnd' "$NOTIFS" \
    && pass "toggleDnd writes the same flag as the IPC handler" \
    || fail "toggleDnd writes a different flag than the IPC handler"
```

- [ ] **Step 2: Run it to prove it fails**

```bash
bash tests/upstream_ports_test.sh    # expect 7 passed, 2 failed
```

- [ ] **Step 3: Add the shortcut**

```qml
    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "toggleDnd"
        description: "Toggle do not disturb"
        onPressed: root.dnd = !root.dnd
    }
```

Upstream's body is `PersistentState.doNotDisturb = !PersistentState.doNotDisturb`; this fork has no `PersistentState`, and `root.dnd` is the same value the `toggleDnd()` IPC function writes (`services/Notifs.qml:175`). Place it next to `clearNotifs` so the two notification shortcuts stay together.

- [ ] **Step 4: Run the suite and the runner**

```bash
bash tests/upstream_ports_test.sh    # expect 9 passed, 0 failed
bash tests/run.sh 2>&1 | tail -2     # expect 21 passed, 0 failed
```

- [ ] **Step 5: Commit**

```bash
git add tests/upstream_ports_test.sh shell/services/Notifs.qml
git commit -m "feat(notifs): add toggleDnd shortcut (upstream be553a69)"
```

---

### Task 6: Deploy and verify live

**Files:** none in the repo (deployment + verification only).

**Interfaces:**
- Consumes: the branch's five ported files; `install.sh --update --no-install --on-conflict keep`
- Produces: a deployed tree matching the branch, a restarted shell with no load errors

- [ ] **Step 1: Deploy without escalating**

```bash
cd /home/Bisho/.local/share/opencode/worktree/0ccf01/widget-foundation
./install.sh --update --no-install --on-conflict keep 2>&1 | tail -6
```

Expected summary: the five ported files added/updated, no `Kept:` line for any of them. `--no-install` keeps this from touching `/etc`; `--on-conflict keep` leaves unrelated user-edited files (kitty, nvim) alone. Do **not** use `--non-interactive` — it forces `--on-conflict replace`.

- [ ] **Step 2: Prove the deployed copies match**

```bash
D=~/.config/quickshell/caelestia
for f in modules/dashboard/Content.qml modules/bar/popouts/Bluetooth.qml \
         modules/nexus/pages/bluetooth/BluetoothPairing.qml \
         modules/lock/Pam.qml services/Notifs.qml; do
  diff -q "shell/$f" "$D/$f" || echo "DIFFERS: $f"
done
echo "(no output above = deployed matches repo)"
```

- [ ] **Step 3: Restart the shell with logging**

```bash
cat > /tmp/opencode/start-shell.sh <<'EOF'
#!/usr/bin/env bash
cd /tmp/opencode
setsid nohup /usr/local/bin/qs -c caelestia >/tmp/opencode/qs-sync.log 2>&1 </dev/null &
disown
EOF
chmod +x /tmp/opencode/start-shell.sh
pkill -x qs; sleep 1; /tmp/opencode/start-shell.sh; sleep 9
grep -E "Configuration Loaded|Failed to load|Type .* unavailable" /tmp/opencode/qs-sync.log | head -6
```

Expected: exactly one `Configuration Loaded`, no `Failed to load`, no `unavailable`. Use `pkill -x qs` (not `pkill -f "qs -c caelestia"`, which matches and kills the invoking shell).

- [ ] **Step 4: Check for runtime errors**

```bash
grep -iE "error|is not defined|Unable to assign|TypeError" /tmp/opencode/qs-sync.log \
  | grep -v "VDPAU\|m3errorDim\|Colours: ignoring" | head -10
```

Expected: no output.

- [ ] **Step 5: Manual verification (human, mouse required)**

- Dashboard: disable the current tab in Nexus → the strip selects a valid tab and never renders blank/collapsed.
- Bluetooth: with an unnamed device paired, it sorts below named devices in both the bar popout and Nexus → Bluetooth → Pair new device.
- Lock screen: type text, press Ctrl+U → the field empties; Ctrl+Backspace still empties; Backspace deletes one character.
- DND: `qs -c caelestia ipc call notifs toggleDnd` flips it; the shortcut itself needs a bind (`hl.dsp.global("caelestia:toggleDnd")`) before a key can fire it.

- [ ] **Step 6: No commit** (unless a verification step required a fix; then commit the fix separately).

---

## Self-Review

**Spec coverage:** all 22 commits have a disposition in the scope table; five are implemented by Tasks 2–5; the vendored base is refreshed in Task 1; deployment is Task 6. The `2026-10-22-upstream-sync.md` deferred cluster is carried forward explicitly.

**Step scan:** each port step names the exact file, line, and replacement expression; each test step states the expected pass/fail counts so the implementer can tell a real failure from a broken suite.

**Type consistency:** `root.dashState.currentTab` (int), `repeater.count` (int), `BluetoothDevice.deviceName` (string), `root.dnd` (bool, alias of `props.dnd`) — all verified against the current tree in this session.

**Review Focus:** each of the five risks has an assertion in `tests/upstream_ports_test.sh` except #4's ordering, which is pinned by the grep on `Qt.Key_U` plus the explicit note that the branch must precede the printable guard.
