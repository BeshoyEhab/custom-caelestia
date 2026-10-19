# Captive Portal Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make cafe/hotel Wi-Fi just work: plain-DNS fallback on portal networks, automatic opening of the captive portal login page, and a manual "Sign in to network" affordance in the bar and Nexus.

**Architecture:** Three layers matching the three root causes. (A) A `systemd-resolved` drop-in switching `DNSOverTLS=yes` → `opportunistic`, deployed by `install.sh`. (B) NetworkManager's connectivity check re-enabled (D-Bus `ConnectivityCheckEnabled=true` + a conf drop-in). (C) A new `qs.services.CaptivePortal` QML singleton that reads `Nmcli.connectivity`, probes the network through a shell script, opens the portal in a throwaway Brave app-window, toasts, and exposes `active` for the two UI rows.

**Tech Stack:** Quickshell QML (Qt6), `nmcli` / NetworkManager 1.58 D-Bus, `systemd-resolved`, curl, bash, python3 (test fixtures only).

**Spec:** `docs/superpowers/specs/2026-10-19-captive-portal-login-design.md`

## Global Constraints

- Edit files in BOTH `<repo>/shell/` and `~/.config/quickshell/caelestia/` (`./install.sh --update` deploys; `qs -c caelestia` loads the user-config copy — AGENTS.md).
- Never touch `shell/upstream/`.
- Any QML file using `Colours.palette` must `import qs.services` (AGENTS.md).
- Do not touch `shell/modules/bar/Bar.qml`; its no-`pragma ComponentBehavior: Bound` rule stands.
- `nmcli` calls use terse output (`-t -f …`) and `LANG=C.UTF-8`/`LC_ALL=C.UTF-8`, matching `shell/services/Nmcli.qml`.
- Tests must never write `/etc` or restart services: `deploy_system_config` honours `SYSTEM_CONFIG_ROOT` (default `/etc`) and `CI_TEST=true` skips it; subprocess tests stub `sudo`/`systemctl` on `PATH`.
- Probe script contract: `captive_portal_probe.sh <url>` prints ONE line `online|portal|unknown <url> <http-status>` and exits `0|1|2`.
- Python3 is a test-only dependency; the feature itself needs only `curl`, `bash`, `nmcli`.
- Commit per task; conventional-commit prefixes as used in this repo (`feat(...)`, `fix(...)`, `test(...)`, `docs(...)`).
- No AUR dependency, no C++ plugin change.

## Review Focus

Inputs/conditions the spec implies but that no test in this plan covers end-to-end — each has a manual or scripted check in the task that owns the code:

1. **Portal answering 200 with the exact expected body** (`NetworkManager is online`) while still gated — classified `online`, so no window opens. Owning task: 1 (documented as a known limit, not fixed).
2. **HTTPS-only portal / status 511 / no `Location`** — classified `unknown`; the UI row must still appear and open the portal URL by hand. Owning task: 4 (manual check with a fake gateway).
3. **DNS-dead portal where the gateway serves nothing on port 80** — `unknown`; no window spam. Owning task: 1 (refused-port case) + 5 (live wrong-gateway check).
4. **`nmcli monitor` emitting repeated lines (scans, device churn)** — must not re-probe or reopen per line. Owning task: 4 (cooldown/debounce asserts + live rescan check).
5. **Brave missing or renamed** — must fall back to `xdg-open` instead of failing silently. Owning task: 4 (assert + `sudo mv` manual check).

---

### Task 1: Probe classifier (script + hermetic fakes)

**Files:**
- Create: `hyprland/.config/hypr/hyprland/scripts/captive_portal_probe.sh`
- Create: `tests/fixtures/fake_portal_server.py`
- Create: `tests/captive_portal_probe_test.sh`
- Modify: `tests/run.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `captive_portal_probe.sh <url>` → stdout `online|portal|unknown <url> <http-status>`, exit `0|1|2`. Task 4 calls it from QML.

- [ ] **Step 1: Write the failing test**

Create `tests/fixtures/fake_portal_server.py` (mode `online` prints `NetworkManager is online\n`, `no-content` returns 204, `redirect` returns 302 to `http://portal.example.test/login`, `html` returns 200 `<html><body>Please sign in</body></html>`; binds `127.0.0.1:0`, prints the port on its first stdout line, `log_message` silenced).

Create `tests/captive_portal_probe_test.sh` (`set -uo pipefail`, repo `pass`/`fail` counter style from `tests/qml_test.sh`), which for each mode starts the fixture in the background, waits for the port line, runs the probe, and asserts:

```bash
PROBE="$REPO_DIR/hyprland/.config/hypr/hyprland/scripts/captive_portal_probe.sh"
# mode=online        -> "online <url> 200"     exit 0
# mode=no-content    -> "online <url> 204"     exit 0
# mode=redirect      -> "portal http://portal.example.test/login 302"  exit 1
# mode=html          -> "portal http://127.0.0.1:<port>/ 200"          exit 1
# url=http://127.0.0.1:1/ (refused) -> "unknown <url> 000"             exit 2
```

Register the suite in `tests/run.sh` next to the existing `test_suite` calls: `test_suite "captive_portal_probe_test" "tests/captive_portal_probe_test.sh"`.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/captive_portal_probe_test.sh`
Expected: FAIL — `captive_portal_probe.sh` does not exist (all cases fail; the script exits 127).

- [ ] **Step 3: Implement `captive_portal_probe.sh`**

`#!/usr/bin/env bash`, `set -uo pipefail`. Usage guard for `<url>`. One curl call:

```bash
read -r http redirect < <(curl -s -m 8 -o "$body" -w '%{http_code} %{redirect_url}' "$url") || { echo "unknown $url 000"; exit 2; }
```

Classification order: `204` or body starting with `NetworkManager is online` → `online` (exit 0); `3xx` → `portal` with the `Location` header (`redirect`) when non-empty else `$url` (exit 1); other `2xx` → `portal` with `$url` (exit 1); anything else, or a curl failure (exit code 6/7/28) → `unknown $url 000` (exit 2). Body is read with `head -c 256`. Temp body file removed by an `EXIT` trap.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/captive_portal_probe_test.sh`
Expected: PASS for all five cases.

- [ ] **Step 5: Commit**

```bash
chmod +x hyprland/.config/hypr/hyprland/scripts/captive_portal_probe.sh tests/captive_portal_probe_test.sh tests/fixtures/fake_portal_server.py
git add hyprland/.config/hypr/hyprland/scripts/captive_portal_probe.sh tests/fixtures/fake_portal_server.py tests/captive_portal_probe_test.sh tests/run.sh
git commit -m "feat(captive-portal): add portal probe classifier script + hermetic tests"
```

---

### Task 2: DNS + NetworkManager drop-ins and `deploy_system_config()`

**Files:**
- Create: `system/resolved.conf.d/10-captive-portal.conf`
- Create: `system/NetworkManager/conf.d/30-connectivity-enabled.conf`
- Modify: `install.sh` (new `deploy_system_config()`, called first inside `deploy_hyprland()` at `install.sh:730`)
- Modify: `tests/setup_scripts_test.sh` (neutralize + cover the new step)

**Interfaces:**
- Consumes: nothing.
- Produces: `deploy_system_config()` — no args, no return; reads `SYSTEM_CONFIG_ROOT` (default `/etc`), `DRY_RUN`, `NO_INSTALL_USER`, `CI_TEST`.

- [ ] **Step 1: Write the failing test**

In `tests/setup_scripts_test.sh`, add `t_deploy_system_config_hermetic` (sourced-functions style, `source_scripts`): with `SYSTEM_CONFIG_ROOT="$tmp/etc"`, `CI_TEST=false`, `NO_INSTALL_USER=false`, stubbed `sudo() { "$@"; }` and a stub `systemctl` on `PATH`, assert:

```bash
# after deploy_system_config
[[ -f "$tmp/etc/systemd/resolved.conf.d/10-captive-portal.conf" ]]   # PASS
[[ -f "$tmp/etc/NetworkManager/conf.d/30-connectivity-enabled.conf" ]] # PASS
grep -q 'DNSOverTLS=opportunistic' "$tmp/etc/systemd/resolved.conf.d/10-captive-portal.conf" # PASS
# idempotency: second call writes nothing and does not restart
# DRY_RUN=true prints "Would" lines and creates no file
# NO_INSTALL_USER=true prints and creates no file
# CI_TEST=true creates no file
```

Also update the existing `t_update_after_install` (`tests/setup_scripts_test.sh:266-275`) so its real `--update` run cannot touch the host: pass `SYSTEM_CONFIG_ROOT="$tmp/etc"` and a `PATH` stub dir containing `sudo` and `systemctl` (same trick as `t_update_dry_run_skips_git_pull`'s git stub).

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/setup_scripts_test.sh 2>&1 | grep -A2 'deploy_system_config'`
Expected: FAIL — `deploy_system_config: command not found`.

- [ ] **Step 3: Implement the drop-ins and the deployer**

`system/resolved.conf.d/10-captive-portal.conf` (exact content):

```ini
# custom-caelestia: captive portals (cafes, hotels) hand out DNS servers that
# do not speak DNS-over-TLS. With DNSOverTLS=yes every lookup there fails
# ("all DNS requests will fail", resolved.conf(5)), so the login page can never
# be reached. opportunistic keeps DoT whenever the server supports it.
[Resolve]
DNSOverTLS=opportunistic
```

`system/NetworkManager/conf.d/30-connectivity-enabled.conf` (exact content):

```ini
# custom-caelestia: keep NetworkManager's connectivity check on so the
# PORTAL/LIMITED state exists for the shell's captive-portal helper.
# uri stays as shipped in /usr/lib/NetworkManager/conf.d/20-connectivity.conf.
[connectivity]
enabled=true
```

In `install.sh`, add `deploy_system_config()` next to the other deployers: skip with a clear message when `CI_TEST=true`; skip with the printed commands when `NO_INSTALL_USER=true` or `DRY_RUN=true`; otherwise `sudo install -D -m 644` each drop-in **only when it differs** (`cmp -s`), `sudo systemctl restart systemd-resolved` only when the resolved drop-in changed, and `busctl set-property org.freedesktop.NetworkManager /org/freedesktop/NetworkManager org.freedesktop.NetworkManager ConnectivityCheckEnabled b true` guarded by `command -v busctl` (log a warning, never `err`, if sudo fails). Call it as the first statement of `deploy_hyprland()` so `cmd_install` and `cmd_update` both reach it exactly once, after section detection.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/setup_scripts_test.sh` and `bash tests/e2e_deploy_test.sh`
Expected: both PASS; `ls -l /etc/systemd/resolved.conf.d/ /etc/NetworkManager/conf.d/` unchanged by the run (host untouched).

- [ ] **Step 5: Commit**

```bash
git add system install.sh tests/setup_scripts_test.sh
git commit -m "feat(captive-portal): ship DoT-opportunistic + NM connectivity drop-ins via install.sh"
```

---

### Task 3: `Nmcli.connectivity` state

**Files:**
- Create: `tests/qml_captive_portal_test.sh`
- Modify: `shell/services/Nmcli.qml`
- Modify: `tests/run.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `Nmcli.connectivity: string` (`unknown|none|portal|limited|full`) and `Nmcli.recheckConnectivity(callback: var): void`; Task 4 binds to both.

- [ ] **Step 1: Write the failing test**

Create `tests/qml_captive_portal_test.sh` in the `tests/qml_eco_powersaver_test.sh` style (`check <desc> <file> <grep-pattern>`, `FAIL=1` on miss) asserting first the Task 3 surface:

```bash
check "Nmcli exposes connectivity"      "$S/services/Nmcli.qml" 'property string connectivity'
check "Nmcli queries CONNECTIVITY"      "$S/services/Nmcli.qml" '"-t", "-f", "CONNECTIVITY", "general"'
check "Nmcli refreshes on monitor line" "$S/services/Nmcli.qml" 'getConnectivity'
check "Nmcli recheck API"               "$S/services/Nmcli.qml" 'function recheckConnectivity'
```

Register it in `tests/run.sh`: `test_suite "qml_captive_portal_test" "tests/qml_captive_portal_test.sh"`.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/qml_captive_portal_test.sh`
Expected: FAIL on all four checks.

- [ ] **Step 3: Implement in `shell/services/Nmcli.qml`**

Add `property string connectivity: "unknown"` and `readonly property string connectivityFields: "CONNECTIVITY"`. Add `function getConnectivity(): void` → `executeCommand(["-t", "-f", root.connectivityFields, "general"], result => { const line = (result.output || "").trim().split("\n")[0]; root.connectivity = line || "unknown"; })`. Add `function recheckConnectivity(callback: var): void` → `executeCommand(["networking", "connectivity", "check"], () => { getConnectivity(); if (callback) callback(root.connectivity); })`. Call `getConnectivity()` from inside `refreshOnConnectionChange()` (so the existing `nmcli monitor` reader drives it) and from `Component.onCompleted` next to the other initial getters (`Nmcli.qml:1443-1450`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/qml_captive_portal_test.sh` and `bash tests/qml_test.sh` (import/structure gate)
Expected: PASS both. Then deploy and check live: `./install.sh --update --no-install; pkill -x qs; sleep 0.5; setsid qs -c caelestia >/dev/null 2>&1 &`, and confirm the reported value agrees with `nmcli -t -f CONNECTIVITY general` and that `timeout 15 qs -c caelestia 2>&1 | grep -i "Nmcli\|not a type"` is clean.

- [ ] **Step 5: Commit**

```bash
git add shell/services/Nmcli.qml tests/qml_captive_portal_test.sh tests/run.sh
git commit -m "feat(nmcli): expose connectivity state and recheck API"
```

---

### Task 4: `CaptivePortal` service

**Files:**
- Create: `shell/services/CaptivePortal.qml`
- Modify: `shell/modules/ServiceLoader.qml:5-20`
- Modify: `tests/qml_captive_portal_test.sh`

**Interfaces:**
- Consumes: `Nmcli.connectivity`, `Nmcli.recheckConnectivity()`, and `captive_portal_probe.sh <url>` (Task 1).
- Produces: singleton `qs.services.CaptivePortal` with:
  - `readonly property bool active` — row visibility;
  - `property string portalUrl`, `property string lastProbe` (`""|online|portal|unknown`);
  - `function probeNow()` — run the probe chain, update `lastProbe`/`portalUrl`;
  - `function recheck()` — `Nmcli.recheckConnectivity()` then `probeNow()`;
  - `function open()` — user-initiated: `probeNow()` first when `lastProbe !== "portal"`, then always open the window (no cooldown, the click is explicit);
  - internal auto path `maybeAutoOpen()` — only when `lastProbe === "portal"` and `openedFor !== ssid + "|" + portalUrl` and 60 s since `lastOpenTime`;
  - `IpcHandler target: "captivePortal"`: `state(): string`, `probe(url: string): string`, `open(): void`.

  Task 5 calls `CaptivePortal.open()` (row click) and `CaptivePortal.recheck()` ("Recheck connection").

- [ ] **Step 1: Write the failing test**

Append to `tests/qml_captive_portal_test.sh`:

```bash
check "CaptivePortal singleton"     "$S/services/CaptivePortal.qml" 'pragma Singleton'
check "CaptivePortal seen by loader" "$S/modules/ServiceLoader.qml" 'CaptivePortal'
check "active covers unknown"       "$S/services/CaptivePortal.qml" 'connectivity === "unknown"'
check "auto-open requires portal"   "$S/services/CaptivePortal.qml" 'lastProbe === "portal"'
check "uses probe script"           "$S/services/CaptivePortal.qml" 'captive_portal_probe.sh'
check "throwaway brave profile"     "$S/services/CaptivePortal.qml" 'user-data-dir'
check "xdg-open fallback"           "$S/services/CaptivePortal.qml" 'xdg-open'
check "toasts once per episode"     "$S/services/CaptivePortal.qml" 'Toaster.toast'
check "cooldown guard"              "$S/services/CaptivePortal.qml" 'lastOpenTime'
check "IPC target"                  "$S/services/CaptivePortal.qml" 'target: "captivePortal"'
check "re-probe timer"              "$S/services/CaptivePortal.qml" 'interval: 15000'
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/qml_captive_portal_test.sh`
Expected: FAIL on the eleven new checks.

- [ ] **Step 3: Implement `shell/services/CaptivePortal.qml`**

`pragma Singleton`, imports `QtQuick`, `Quickshell`, `Quickshell.Io`, `Caelestia`, `qs.services`, `qs.utils`. State: `readonly property bool connected: Nmcli.isConnected`; `lastProbe`; `portalUrl`; `readonly property bool active: connected && (Nmcli.connectivity === "portal" || Nmcli.connectivity === "limited" || Nmcli.connectivity === "unknown" || lastProbe === "portal")`; `property real lastOpenTime: 0`; `property string openedFor: ""` (episode key `ssid + "|" + portalUrl`). Probe path `${Paths.home}/.config/hypr/hyprland/scripts/captive_portal_probe.sh`. `probeNow()` runs it through a `Process` (`command: ["bash", probePath, url]`, `StdioCollector`) on the NM check URI `http://ping.archlinux.org/nm-check.txt`; on `unknown` retry once against `http://<gateway>/` read from `nmcli -t -f IP4.GATEWAY,IP6.GATEWAY device show <Nmcli.activeInterface>` (strip any `%iface`), falling back to the first default route from `ip route show default`. `open()` launches, in one detached `sh -c`, the throwaway-profile Brave app-window with an `xdg-open` fallback:

```js
Quickshell.execDetached(["sh", "-c",
    'command -v brave >/dev/null 2>&1 && exec brave --app="$1" --user-data-dir="$2" || exec xdg-open "$1"',
    "sh", root.portalUrl, `${Paths.tmp}/portal-profile`]);
```

`maybeAutoOpen()` sets `lastOpenTime`/`openedFor` before launching. Toasts: `Toaster.toast(qsTr("Sign in to network"), qsTr("This network needs you to log in"), "wifi_lock", Toast.Warning)` once per episode, and an "Online" `Toaster.toast` when `Nmcli.connectivity === "full"` ends an episode. `Connections` on `Nmcli.connectivityChanged`: `full` → clear `lastProbe`/`portalUrl`/`openedFor`; otherwise `probeNow()` then `maybeAutoOpen()`. Two `Timer`s while `active`: 15000 ms → `probeNow()`, 60000 ms → `Nmcli.recheckConnectivity()`.

Add `CaptivePortal;` to `shell/modules/ServiceLoader.qml`'s `Component.onCompleted` list.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/qml_captive_portal_test.sh` + `bash tests/qml_test.sh`, then deploy and smoke-test:
`./install.sh --update --no-install; pkill -x qs; sleep 0.5; setsid qs -c caelestia >/dev/null 2>&1 &`
Run: `qs -c caelestia ipc call captivePortal state`
Expected: `full active=false …` on a normal network, no window, no toast. Then `qs -c caelestia ipc call captivePortal probe http://127.0.0.1:1/` → `unknown`, and manual check 5: `sudo mv /usr/bin/brave /usr/bin/brave.bak`, click the row in the bar popout → `xdg-open` path taken, then `sudo mv` back.

- [ ] **Step 5: Commit**

```bash
git add shell/services/CaptivePortal.qml shell/modules/ServiceLoader.qml tests/qml_captive_portal_test.sh
git commit -m "feat(captive-portal): CaptivePortal service with probe, toast and IPC"
```

---

### Task 5: "Sign in to network" rows

**Files:**
- Modify: `shell/modules/bar/popouts/Network.qml` (insert above the `Wireless` heading at `Network.qml:23`)
- Modify: `shell/modules/nexus/pages/NetworkPage.qml` (insert above the Wi-Fi `ToggleRow` at `NetworkPage.qml:63`)
- Modify: `tests/qml_captive_portal_test.sh`

**Interfaces:**
- Consumes: `CaptivePortal.active`, `CaptivePortal.open()`, `CaptivePortal.recheck()`.
- Produces: nothing new.

- [ ] **Step 1: Write the failing test**

Append three checks: bar popout contains `CaptivePortal.active`, Nexus page contains `CaptivePortal.active`, and both mention `qsTr("Sign in to network")`.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/qml_captive_portal_test.sh`
Expected: FAIL on the three new checks.

- [ ] **Step 3: Implement both rows**

Bar popout: `import qs.modules.nexus.common` (for `RowButton`), then a `RowButton { visible: CaptivePortal.active; Layout.preferredHeight: visible ? implicitHeight : 0; icon: "wifi_lock"; text: qsTr("Sign in to network"); subtext: Nmcli.active ? Nmcli.active.ssid : ""; trailingIcon: "open_in_new"; onClicked: CaptivePortal.open() }` as the first layout child, before the "Wireless" `StyledText`.

Nexus page: the same `RowButton` with `first: true` (it is the first row of the group) and `onClicked: CaptivePortal.open()`, plus a "Recheck connection" `RowButton { icon: "refresh"; text: qsTr("Recheck connection"); visible: CaptivePortal.active; onClicked: CaptivePortal.recheck() }`. Keep the existing `NetworkList`/`ToggleRow` order intact below.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/qml_captive_portal_test.sh` + `bash tests/qml_test.sh`, deploy (`./install.sh --update --no-install`), restart the shell, then manual check 3: with `nmcli -t -f STATE,CONNECTIVITY general` showing `full`, confirm no row is visible; then `busctl set-property … ConnectivityCheckEnabled b false` + `nmcli networking connectivity check` to force `unknown`/`limited` and confirm the row appears in both surfaces and does not open a window until clicked.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/bar/popouts/Network.qml shell/modules/nexus/pages/NetworkPage.qml tests/qml_captive_portal_test.sh
git commit -m "feat(ui): sign-in-to-network rows in bar popout and Nexus network page"
```

---

### Task 6: Docs, full deploy, end-to-end verification

**Files:**
- Modify: `AGENTS.md` (Known Issues + Key Files)
- Modify: `README.md` (installation/update notes)
- Modify: `docs/superpowers/plans/2026-10-19-captive-portal-login.md` (tick boxes)

**Interfaces:**
- Consumes: everything above.
- Produces: a deployed, verified system.

- [x] **Step 1: Document**

`AGENTS.md`: add a "Captive portal / portal Wi-Fi" entry under Known Issues (three causes + where the fix lives: `system/`, `shell/services/CaptivePortal.qml`, `captive_portal_probe.sh`) and add the new files to the "Key Files to Know" table. `README.md`: note in the Updating/Installation area that `install.sh` applies a `/etc/systemd/resolved.conf.d/10-captive-portal.conf` (`DNSOverTLS=opportunistic`) and an NM connectivity drop-in, skipping both with `--no-install`, and how to revert (delete the two files, restart `systemd-resolved`).

- [x] **Step 2: Dry-run then deploy**

Run: `./install.sh --dry-run` → expect the two `Would write`/`Would restart` lines and no file changes.
Run: `./install.sh --update` → expect the drop-ins written, `systemd-resolved` restarted, `ConnectivityCheckEnabled` now `true`, and the shell files deployed to `~/.config/quickshell/caelestia/`.

- [x] **Step 3: Verify the three layers**

Run and expect:
- `resolvectl status | grep -i dnsovertls` → `opportunistic` (no `+DNSOverTLS` strict mode).
- `busctl get-property org.freedesktop.NetworkManager /org/freedesktop/NetworkManager org.freedesktop.NetworkManager ConnectivityCheckEnabled` → `b true`.
- `nmcli networking connectivity check` → `full` at home, and `qs -c caelestia ipc call captivePortal state` → `active=false`.
- `bash tests/run.sh` → all suites PASS (including the two new ones).

- [x] **Step 4: Commit**

```bash
git add AGENTS.md README.md docs/superpowers/plans/2026-10-19-captive-portal-login.md
git commit -m "docs(captive-portal): document portal helper, DNS drop-in and verification"
```

#### Task 6 verification record (live run, 2026-10-19)

Deviation from the steps above, recorded per the Task 6 brief:

- **Step 2:** `./install.sh --update` was **not** run. This machine has no passwordless sudo and privileged commands belong to the human, so the run was split into `./install.sh --dry-run` (printed `Would install: /etc/systemd/resolved.conf.d/10-captive-portal.conf`, `Would restart systemd-resolved`, `Would install: /etc/NetworkManager/conf.d/30-connectivity-enabled.conf`; no file changed) plus `./install.sh --update --no-install` (deployed the configs to `~/.config`, printed the manual `sudo install` commands instead of escalating). The real `/etc` application is one human run — see `.superpowers/sdd/2026-10-19-captive-portal-login/task-6-report.md`.
- **Step 3:** `connectivity=full active=false` and `b true` were confirmed, and `bash tests/run.sh` passes. The `opportunistic` expectation did **not** hold: `resolvectl status` still shows `+DNSOverTLS` (strict) because the drop-in is unapplied, and `ConnectivityCheckEnabled` already read `b true` before this task (the NM drop-in file is likewise absent from `/etc`).
- **Not verified live:** the "row becomes visible" state — flipping `ConnectivityCheckEnabled` to `b false` and re-checking still left `connectivity=full`, so `active` never became `true`. The row-visible path is covered only by the QML test checks (`active covers unknown`), not by this machine's session.
- Tasks 1–5 checkboxes were left to their own tasks (reports in `.superpowers/sdd/2026-10-19-captive-portal-login/`); Task 6 ran the full suite over all of them.

##### Round 1 follow-up — hermetic positive-portal check (same day, controller ruling)

`tests/fixtures/fake_portal_server.py html` on `127.0.0.1:<port>` fed the running shell a
genuine positive portal classification via `qs -c caelestia ipc call captivePortal probe`
(no `/etc`, no sudo, no real portal):

- Probe chain **works live**: `state` reported `lastProbe=portal`,
  `portalUrl=http://127.0.0.1:45019/`, `candidateUrl=http://127.0.0.1:45019/`.
- **`active` still did not become `true`** (read three times over ~6 s):
  `connectivity=full active=false lastProbe=portal …`.
- **Root cause (blocking Task 5's acceptance):** `CaptivePortal.active` is
  `root.connected && (…)` and `root.connected` is `Nmcli.isConnected`, whose only writer
  is `Nmcli.refreshStatus()` (`shell/services/Nmcli.qml:850`, assignment at `:870`) — and
  `refreshStatus()` has **zero callers** in the repo, in the deployed `~/.config` copy, and
  in `shell/upstream/services/Nmcli.qml`. `Nmcli.isConnected` therefore never leaves its
  initial `false`, so the two "Sign in to network" rows can never become visible — this is
  a code defect, not an observation gap. `Nmcli.activeInterface`/`activeConnection`
  (written only inside the same dead function) are permanently empty too, so
  `CaptivePortal.resolveGateway()` always takes the `ip route show default` fallback.
- Explicit path **works live**: `ipc call captivePortal open` launched the throwaway
  profile window — `brave --app=http://127.0.0.1:45019/ --user-data-dir=/run/user/1000/caelestia/portal-profile`
  (10 processes at +3 s, `episode=Besho|http://127.0.0.1:45019/`); no automatic window
  opened from the `probe` IPC call alone (that path never opens by design). The window was
  gone at the next check (~1 min later); no kill was issued by the tester.
- Settle-back confirmed: `probe http://ping.archlinux.org/nm-check.txt` →
  `connectivity=full active=false lastProbe=online`, `ConnectivityCheckEnabled` → `b true`.
- `bash tests/run.sh` → 7 passed / 0 failed; `bash tests/qml_captive_portal_test.sh` → PASS.

**Still open (needs a controller ruling, not decided here):** a fix for the dead
`Nmcli.isConnected` gate — either wire `refreshStatus()` into `Component.onCompleted` +
the `nmcli monitor` refresh path, or drop/replace the `connected` clause in
`CaptivePortal.active`. Until then Task 5's "row appears" acceptance cannot pass.
