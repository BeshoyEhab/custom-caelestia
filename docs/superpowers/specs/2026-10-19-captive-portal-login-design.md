# Captive portal login design

Date: 2026-10-19. Scope: Hyprland + Caelestia on Arch (this machine). Fixes the
"cafe Wi-Fi never shows the login page" problem: it has three stacked causes —
strict DNS-over-TLS kills DNS on portal networks, nothing in the shell reacts
to portal state, and NetworkManager's connectivity check is switched off.

## 1. Evidence (live system, 2026-10-19)

| Finding | Evidence |
|---|---|
| Strict DoT kills DNS on portal networks | `/etc/systemd/resolved.conf`: `DNS=45.90.28.0#a8cae2.dns.nextdns.io` (+3), `DNSOverTLS=yes`. `man resolved.conf`: *"If the DNS server does not support DNS-over-TLS **all DNS requests will fail**."* |
| resolved is the resolver in play | `/etc/NetworkManager/conf.d/dns.conf`: `dns=systemd-resolved`; `/etc/resolv.conf` → `nameserver 127.0.0.53` |
| No portal handling anywhere | `grep -ri 'captive\|portal\|connectivity' shell/`.qml → only unrelated hits |
| NM check pipeline works when it runs | `curl http://ping.archlinux.org/nm-check.txt` → `200` + body `NetworkManager is online`; `nmcli networking connectivity check` → `full` |
| Connectivity check is **off** at runtime | `ConnectivityCheckEnabled = false` (persisted in `/var/lib/NetworkManager/NetworkManager-intern.conf`; NM docs: the D-Bus value "gets stored in NetworkManager-intern.conf"). Setting it `true` over D-Bus works unprivileged in an active session |
| Reproduced symptom | User: connect at cafe → "connected", any site → DNS error, no redirect, no notification |

Root cause chain: cafe DHCP hands out a DNS server that does not speak DoT on
853 → `DNSOverTLS=yes` makes resolved fail every lookup (no plain fallback) →
browser reports DNS failure, NM's check can't resolve either (so NM would say
`limited`, not `portal`, even if enabled) → and even if the state were known,
no component on Hyprland/Caelestia opens a browser for it (GNOME Shell and
Plasma ship that component — NM's docs: *"GNOME's portal helper uses this as
signal to show a captive portal login page"*).

## 2. Goals / non-goals / anti-goals

Goals (each verifiable):

- **G1** DNS resolves on portal networks: `resolvectl query example.com` succeeds at the cafe.
- **G2** Redirect-style portal: login page opens automatically within ~5 s of connecting.
- **G3** DNS-walled portal (no resolution at all): login page still opens by probing the default gateway IP over HTTP.
- **G4** Manual affordance: a "Sign in to network" row appears in the bar network popout and the Nexus Network page whenever a device is connected and the state is `portal`/`limited` **or** the last probe said portal **or** the state is `unknown` (check off / not run yet); clicking runs a fresh probe and opens the portal. A "Recheck" action re-runs NM's check. The row never appears when the state is `full`.
- **G5** No false positives: nothing opens on normal networks.
- **G6** Deployed by `install.sh`, idempotent, respects `--dry-run`/`--no-install`; repo stays the source of truth (AGENTS.md: repo + user config both edited).

Non-goals:

- No RFC 8910 / DHCP option 114 portal-API discovery (nice-to-have, not needed).
- No iwd backend switch, no VPN changes, no keybind requirement.
- No `shell/upstream/` or C++ plugin changes; no new AUR dependency.

Anti-goals (failures even if it "works"):

- **A1** Window spam / reopen loops. Auto-open at most once per portal episode; reopen only on user action.
- **A2** Weakening DNS privacy more than needed: `yes` → `opportunistic` only (DoT still used whenever the server supports it).
- **A3** Opening a browser when the connection is actually online.

## 3. Architecture

Three layers, one per cause.

### Layer A — DNS (root, once)

Ship `system/resolved.conf.d/10-captive-portal.conf`:

```ini
[Resolve]
DNSOverTLS=opportunistic
```

`install.sh` copies it to `/etc/systemd/resolved.conf.d/` (write-if-differs,
sudo, honors `--dry-run`; on `--no-install` it prints the command instead) and
runs `systemctl restart systemd-resolved`. Rationale: home NextDNS and 1.1.1.3
keep using DoT; a cafe's plain DNS server gets plain DNS instead of total
failure. This is the user's explicit decision (`yes` → `opportunistic`).

### Layer B — NetworkManager

- Enable the connectivity check so the PORTAL/LIMITED state exists at all:
  `busctl set-property org.freedesktop.NetworkManager /org/freedesktop/NetworkManager
  org.freedesktop.NetworkManager ConnectivityCheckEnabled b true` (works
  unprivileged, persists to `NetworkManager-intern.conf`), run by `install.sh`.
- Ship `/etc/NetworkManager/conf.d/30-connectivity-enabled.conf`
  (`[connectivity] enabled=true`) so a fresh `intern.conf` still lands enabled;
  Arch's default URI lives in `/usr/lib/NetworkManager/conf.d/20-connectivity.conf`
  and stays authoritative for `uri`.

### Layer C — shell (QML, no new daemon)

| # | File | Change |
|---|---|---|
| C1 | `shell/services/Nmcli.qml` | Add `connectivity` (string: `unknown/none/portal/limited/full`), refreshed by a small `Process` running `nmcli -t -f CONNECTIVITY general` on every `nmcli monitor` line; add `recheckConnectivity(cb)` → `nmcli networking connectivity check`. |
| C2 | `shell/services/CaptivePortal.qml` (new singleton) | `active` (bool, see state machine below); `portalUrl`; `open()`; `probe(url)`; `recheck()`; toast once per episode; cooldown; `IpcHandler target:"captivePortal"` (`state`, `probe(url)`, `open`) for manual debugging. |
| C2b | `hyprland/.config/hypr/hyprland/scripts/captive_portal_probe.sh` (new) | Pure probe + classifier (curl + header/body comparison), so tests run it directly without a live Quickshell. `captive_portal_probe.sh <url>` prints one line `online|portal|unknown <url> <http-status>`; exit 0/1/2. Deployed with the Hyprland tree (install.sh already `chmod +x`es that directory). |
| C3 | `shell/modules/ServiceLoader.qml` | `CaptivePortal;` so it loads at shell start. |
| C4 | `shell/modules/bar/popouts/Network.qml` | "Sign in to network" row at the top when `CaptivePortal.active` → `CaptivePortal.open()`. |
| C5 | `shell/modules/nexus/pages/NetworkPage.qml` | Same row, plus a "Recheck connection" action → `CaptivePortal.recheck()`. |

Detection and probe (C2) — state machine:

- Run a probe when: a device reaches `connected`, `Nmcli.connectivity` changes,
  or the user clicks the row/`recheck()`.
- `active` = connected && (`connectivity` ∈ {`portal`,`limited`} ||
  `lastProbe === "portal"` || `connectivity === "unknown"`). Auto-`open()` fires
  only when `lastProbe === "portal"`, so a benign `limited`/`unknown` shows the
  row without spawning a window (A3).
- While `active`: re-probe every 15 s and call
  `nmcli networking connectivity check` every 60 s, so the post-login state
  resolves in seconds instead of NM's 300 s cadence. First probe that reports
  `online` ends the episode, clears `portalUrl`, and toasts "Online".
- Probe (C2b) is one `curl` invocation per candidate URL, 8 s timeout,
  capturing status code, `redirect_url`, `remote_ip` and the body:
  **online** = status 204 or body starts with `NetworkManager is online` (NM's
  documented expected response); **portal** = 3xx with `Location`, or 200 with
  unexpected body (portal HTML); **unknown** = DNS/connect error.
- Probe order: `http://ping.archlinux.org/nm-check.txt` (Arch's URI — most
  redirect portals hijack it), and only if that is inconclusive
  `http://<gateway>/` over the **active interface** (G3). Gateway source:
  `nmcli -t -f IP4.GATEWAY,IP6.GATEWAY device show <Nmcli.activeInterface>`,
  falling back to the first default route from `ip route show default`; strip
  the `%iface` zone off IPv6 addresses.
- `portalUrl` = `Location` header, else the gateway URL, else the probe URL.
- `open()` → `Quickshell.execDetached(["brave", "--app=" + portalUrl,
  "--user-data-dir=" + tmpProfile])`, falling back to `["xdg-open", portalUrl]`
  when Brave is absent. Throwaway profile because the daily profile's HSTS /
  "always HTTPS" / cached cookies break portal pages (same reason
  `captive-browser` does it).
- Toast via the plugin's `Toaster` (`import Caelestia`), mirroring
  `shell/modules/BatteryMonitor.qml`: "Sign in to network" on detection, and an
  "Online" confirmation after the state returns to `full`.
- A1: auto-open once per (SSID, portalUrl) episode with a 60 s floor; once the
  user has been shown a window for an episode, only the UI reopens it.
- A3: `open()` is only reachable when a probe classified the network as portal.
- Note (AGENTS.md): mirror every `shell/` edit into
  `~/.config/quickshell/caelestia/`.

## 4. Testing / verification

- **T1 probe classifier, no cafe needed**: fake portals on localhost
  (`python3` one-off servers): 204 + expected body → `online`; 302 + `Location`
  → `portal` + URL; 200 HTML → `portal`; refused port → `unknown`. Run
  `captive_portal_probe.sh` directly against them (no live Quickshell needed);
  test script `tests/captive_portal_probe_test.sh`. The `IpcHandler
  target:"captivePortal"` (`state`, `probe(url)`, `open`) exists for manual
  debugging at the cafe, not as test infrastructure.
- **T2 real portal** (user, at the cafe): window opens; after login
  `nmcli networking connectivity check` → `full` and the "Online" toast appears.
- **T3 G1**: `resolvectl query example.com` succeeds at the cafe.
- **T4 regressions**: `./install.sh --dry-run` lists the new files;
  `tests/install_test.sh` and `tests/e2e_deploy_test.sh` still pass; no change
  to `--check` semantics.

## 5. Calls I made (check these while reading)

1. QML service instead of an external watcher daemon (no extra process; toasts,
   IPC and the existing `nmcli monitor` are already there). The probe itself
   lives in a shell script (C2b) purely so it is testable without a live
   Quickshell session.
2. DoT: global `opportunistic` (user's call) rather than a root helper flipping
   it per network.
3. Brave app-window with a throwaway profile; `xdg-open` fallback.
4. Auto-open at most once per portal episode; UI reopens.
5. No auto-close of the portal window (avoids fighting the user).
6. Gateway-IP probe as the DNS-dead fallback (G3), gateway URL as last-resort
   `portalUrl`; gateway read from the active interface, `ip route` only as a
   fallback.
7. `active` includes `unknown` so the affordance is visible when NM's check has
   never run; auto-open still requires a positive portal probe.
8. Auto-recheck cadence (15 s probe / 60 s `nmcli check`) while the episode is
   live, instead of waiting for NM's 300 s interval.

## 6. install.sh and root-owned files (decided by the user)

`install.sh` applies Layer A/B itself, with sudo, automatically on install and
update:

- write-if-differs `/etc/systemd/resolved.conf.d/10-captive-portal.conf`, then
  `systemctl restart systemd-resolved`;
- write-if-differs `/etc/NetworkManager/conf.d/30-connectivity-enabled.conf`;
- `busctl set-property … ConnectivityCheckEnabled b true` (unprivileged, but run
  in the same step for sequence clarity);
- idempotent, honors `--dry-run` (prints the commands it would run) and
  `--no-install` (prints them instead of running); a failed sudo degrades to a
  clear warning, never a hard failure of the deploy.

New helper `deploy_system_config()`, called from `cmd_install` and `cmd_update`
when the Hyprland section is detected; does not use `deploy_tree`'s manifest
(it targets `$HOME` only and `/etc` is a shared directory). Existing install
tests (`tests/install_test.sh`, `tests/e2e_deploy_test.sh`) get updated for the
new step.
