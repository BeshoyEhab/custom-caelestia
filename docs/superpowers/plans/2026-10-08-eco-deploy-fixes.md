# Eco Toggle + deploy.sh Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the dead Eco quick-toggle (QML TypeError) and the deploy/restart scripts aborting under `set -e` when `killall qs` returns non-zero.

**Architecture:** Two independent, root-caused fixes. (1) The Eco handlers `enable()/disable()/toggle()` live only inside the `IpcHandler` child of `PowerSaver.qml`, so QML call sites raise `TypeError: Property 'enable' of object PowerSaver_... is not a function`; hoist them to singleton root and let the IPC handler delegate. (2) `killall qs 2>/dev/null` aborts `deploy.sh`/`restart.sh` under `set -euo pipefail` when no `qs` process exists or `killall` (psmisc) is missing, so the `setsid qs` launch line never runs; guard with `|| true`.

**Tech Stack:** QML (Quickshell), bash, repo structural-test suite in `tests/`.

**Spec:** Root causes were established by evidence, not speculation:
- `/tmp/qs-deploy.log:1226` → `WARN scene: @modules/utilities/cards/Toggles.qml[146:-1]: TypeError: Property 'enable' of object PowerSaver_QMLTYPE_19(0x...) is not a function`
- `bash -c 'set -euo pipefail; killall <nonexistent> 2>/dev/null; echo after'; echo $?` → `exit=1`, nothing printed
- Friend's PC run of `deploy.sh` stopped after the `Restarting shell...` echo (the line immediately before `killall qs`)

## Global Constraints

- Every QML file using `PowerSaver.*` must keep `import qs.services`.
- Colour tokens: only `Colours.palette.m3*` / `Colours.tPalette.m3*` (no raw hex) — not exercised by this plan.
- Edit both `<repo>/shell/` (source of truth) and `~/.config/quickshell/caelestia/` (running config) — `deploy.sh` performs the sync; Task 4 runs it.
- `PowerSaver.disable()` must keep clearing `autoLatched` (otherwise a low-battery auto-eco makes the toggle appear stuck on).
- IPC surface must keep working: `qs -c caelestia ipc call powerSaver {isEnabled,toggle,enable,disable,debug}`.
- `deploy.sh`/`restart.sh` keep `set -euo pipefail` (asserted by `tests/script_safety_test.sh`).
- No comments added to code unless the file already documents the pattern.
- Do not kill or restart the running shell (`qs`, pid found via `pgrep -x qs`) before Task 4.

---

### Task 1: RED tests for both fixes

**Files:**
- Modify: `tests/qml_eco_powersaver_test.sh`
- Modify: `tests/script_safety_test.sh`

**Interfaces:**
- Produces: failing assertions that Task 2 (root-level `function enable()`/`disable()` above `IpcHandler`) and Task 3 (`killall qs ... || true`) must satisfy.

- [ ] **Step 1: Add the PowerSaver assertions**

Append, before the `if [[ $FAIL -ne 0 ]]` block of `tests/qml_eco_powersaver_test.sh`:

```bash
# Eco toggle handlers must be QML-callable on the singleton itself. They
# lived only inside IpcHandler, so Toggles.qml:146 raised
# "TypeError: Property 'enable' of object PowerSaver_... is not a function".
ipc_line=$(grep -n "IpcHandler {" "$S/services/PowerSaver.qml" | head -1 | cut -d: -f1)
for fn in enable disable; do
    fn_line=$(grep -n "function $fn()" "$S/services/PowerSaver.qml" | head -1 | cut -d: -f1)
    if [[ -n "$fn_line" && -n "$ipc_line" && "$fn_line" -lt "$ipc_line" ]]; then
        echo "  PASS root-level PowerSaver.$fn (line $fn_line < IpcHandler $ipc_line)"
    else
        echo "  FAIL root-level PowerSaver.$fn (defined at '${fn_line:-missing}', IpcHandler at '$ipc_line')"
        FAIL=1
    fi
done
```

- [ ] **Step 2: Add the killall assertions**

Append at the end of `tests/script_safety_test.sh`, before its summary/exit logic (if none, at end of file):

```bash
echo "-- killall must not abort the script under set -e --"
for s in deploy.sh restart.sh; do
    if grep -qE '^killall qs.*\|\|[[:space:]]*true' "$REPO_DIR/$s"; then
        echo "  PASS $s killall guarded"
    else
        echo "  FAIL $s killall unguarded (set -e aborts before launch)"
        FAIL=1
    fi
done
```

- [ ] **Step 3: Run both tests, confirm FAIL**

Run: `bash tests/qml_eco_powersaver_test.sh; bash tests/script_safety_test.sh`
Expected: FAIL in both — `root-level PowerSaver.enable` and `deploy.sh killall guarded` (plus `restart.sh`).

- [ ] **Step 4: Commit**

```bash
git add tests/qml_eco_powersaver_test.sh tests/script_safety_test.sh
git commit -m "test: RED asserts for root-level eco handlers and killall guard"
```

---

### Task 2: Hoist PowerSaver eco handlers to singleton root

**Files:**
- Modify: `shell/services/PowerSaver.qml`

**Interfaces:**
- Produces: `PowerSaver.enable()`, `PowerSaver.disable()`, `PowerSaver.toggle()` callable from QML; `IpcHandler` target `"powerSaver"` keeps the same four IPC endpoints delegating to them.
- Consumers: `shell/modules/utilities/cards/Toggles.qml:146`, `shell/modules/nexus/pages/ServicesPage.qml:247` (no edits needed).

- [ ] **Step 1: Add root-level functions**

Insert immediately above the `IpcHandler {` block in `shell/services/PowerSaver.qml`:

```qml
    function enable(): void {
        props.enabled = true;
    }

    function disable(): void {
        props.enabled = false;
        root.autoLatched = false;
    }

    function toggle(): void {
        props.enabled = !props.enabled;
    }
```

- [ ] **Step 2: Delegate the IPC endpoints**

Replace the bodies of the `toggle()`, `enable()`, `disable()` functions inside `IpcHandler` with one-line delegations, leaving `isEnabled()` and `debug()` untouched:

```qml
        function toggle(): void {
            root.toggle();
        }

        function enable(): void {
            root.enable();
        }

        function disable(): void {
            root.disable();
        }
```

- [ ] **Step 3: Run the test**

Run: `bash tests/qml_eco_powersaver_test.sh`
Expected: PASS (`RESULT: PASS (green)`).

- [ ] **Step 4: Commit**

```bash
git add shell/services/PowerSaver.qml
git commit -m "fix: expose eco enable/disable/toggle on PowerSaver singleton"
```

---

### Task 3: Guard killall in deploy.sh and restart.sh

**Files:**
- Modify: `deploy.sh:60`
- Modify: `restart.sh:15`

**Interfaces:**
- Consumes: nothing.
- Produces: scripts that reach their `setsid qs -c caelestia` launch line regardless of whether a `qs` process was running or `killall` exists.

- [ ] **Step 1: Guard both call sites**

In `deploy.sh` line 60 change `killall qs 2>/dev/null` to:

```bash
killall qs 2>/dev/null || true
```

Apply the identical change to `restart.sh` line 15.

- [ ] **Step 2: Run the test**

Run: `bash tests/script_safety_test.sh`
Expected: PASS, including the two new `killall guarded` lines.

- [ ] **Step 3: Commit**

```bash
git add deploy.sh restart.sh
git commit -m "fix: guard killall so deploy/restart reach the launch line under set -e"
```

---

### Task 4: Full suite, deploy, live verification

**Files:**
- None modified by hand; runs `./deploy.sh` (syncs `shell/` → `~/.config/quickshell/caelestia/` and restarts the shell).

**Interfaces:**
- Consumes: Tasks 1-3.

- [ ] **Step 1: Run the whole suite**

Run: `bash tests/run.sh`
Expected: all suites PASS.

- [ ] **Step 2: Deploy and restart**

Run: `./deploy.sh`
Expected: prints `Deployed N files.` … `Done.` and does NOT stop after `Restarting shell...`.

- [ ] **Step 3: Verify the shell is up and eco IPC works**

Run: `qs -c caelestia ipc call powerSaver debug`
Expected: a line like `ecoActive=... manual=...` (exit 0).

- [ ] **Step 4: Verify the toggle path in the log**

Run: `grep -c "Toggles.qml\[146" /tmp/qs-deploy.log`
Expected: `0` after pressing the Eco quick-toggle once (ask the human to press it; the previous run logged a TypeError there).

- [ ] **Step 5: Commit any deploy-induced diffs**

```bash
git status --short
git add -A && git commit -m "chore: deploy sync" || true
```
