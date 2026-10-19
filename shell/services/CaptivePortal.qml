pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.services
import qs.utils

// Captive portal detection and sign-in helper.
//
// Probes connectivity with the user's probe script and, when a portal
// positively answers, offers (and once per episode performs) the sign-in
// window open. The automatic path only ever launches a browser after a
// probe classified the network as "portal" - never on "online" or
// "unknown". An explicit click (open()) always responds: it launches the
// portal URL, or the best candidate URL on unknown, or reports "already
// online" when the fresh probe says the network is fine.
Singleton {
    id: root

    readonly property bool connected: Nmcli.isConnected
    readonly property string ssid: Nmcli.active?.ssid ?? ""
    readonly property string probeScript: `${Paths.home}/.config/hypr/hyprland/scripts/captive_portal_probe.sh`
    readonly property string checkUri: "http://ping.archlinux.org/nm-check.txt"

    // Last probe classification: "" | "online" | "portal" | "unknown".
    property string lastProbe: ""
    // Where the portal wants us to log in (only set when lastProbe is portal).
    // The auto-open invariant depends on this being empty for online/unknown.
    property string portalUrl: ""
    // Best URL to hand a user who clicked the row: the probe's Location
    // value, else the gateway URL, else the probe URL. Survives an
    // online/unknown classification so an explicit click is never a dead
    // button; kept separate from portalUrl (which stays portal-only).
    property string candidateUrl: ""
    // Episode bookkeeping for the automatic open path. openedFor is the
    // episode key `ssid + "|" + portalUrl` of the last opened sign-in.
    property real lastOpenTime: 0
    property string openedFor: ""

    // Row visibility: show whenever the network cannot be proven healthy,
    // including "unknown", so the user always has the manual escape hatch.
    readonly property bool active: root.connected && (Nmcli.connectivity === "portal" || Nmcli.connectivity === "limited" || Nmcli.connectivity === "unknown" || root.lastProbe === "portal")

    // One probe chain at a time (15 s timer and connectivity changes can
    // otherwise overlap).
    property bool probing: false
    // Set by open() when it needs to wait for a fresh probe result.
    property bool openWhenProbed: false

    function episodeKey(): string {
        return `${root.ssid}|${root.portalUrl}`;
    }

    // ── Probe chain ────────────────────────────────────────────────────────

    // Runs the probe script against url; callback(classification, url).
    // The script prints one line: "<online|portal|unknown> <url> <status>",
    // where <url> is the portal redirect target when one is observed.
    function runProbe(url: string, callback: var): void {
        const proc = probeProc.createObject(root, {
            "url": url,
            "callback": callback
        });
        proc.running = true;
    }

    // Default gateway of the active interface: nmcli first, then the first
    // default route's gateway from `ip route show default`.
    function resolveGateway(callback: var): void {
        const iface = Nmcli.activeInterface;
        if (!iface || iface.length === 0) {
            root.runRouteProbe(callback);
            return;
        }
        const proc = gatewayProc.createObject(root, {
            "iface": iface,
            "callback": gw => {
                if (gw && gw.length > 0)
                    callback(gw);
                else
                    root.runRouteProbe(callback);
            }
        });
        proc.running = true;
    }

    function runRouteProbe(callback: var): void {
        const proc = routeProc.createObject(root, {
            "callback": callback
        });
        proc.running = true;
    }

    // Probe the NetworkManager check URI; on "unknown" retry once against
    // http://<gateway>/. If that also comes back unknown, leave it there:
    // the row stays visible and nothing opens. Candidate for the explicit
    // click is the Location value if the probe saw a redirect, else the URL
    // that was actually probed (the gateway/`checkUri` fallback).
    function probeNow(): void {
        if (root.probing)
            return;
        root.probing = true;
        root.runProbe(root.checkUri, (cls, url) => {
            if (cls !== "unknown") {
                root.finishProbe(cls, url, url || root.checkUri);
                return;
            }
            root.resolveGateway(gw => {
                if (!gw || gw.length === 0) {
                    root.finishProbe("unknown", "", root.checkUri);
                    return;
                }
                const gwUrl = `http://${gw}/`;
                root.runProbe(gwUrl, (cls2, url2) => root.finishProbe(cls2, url2, url2 || gwUrl));
            });
        });
    }

    function finishProbe(cls: string, url: string, candidate: string): void {
        root.probing = false;
        root.lastProbe = cls;
        root.portalUrl = cls === "portal" ? url : "";
        root.candidateUrl = candidate || "";

        if (root.openWhenProbed) {
            root.openWhenProbed = false;
            // Explicit user action: always respond. portalUrl is only set for
            // a portal, so fall back to the candidate URL on unknown; on
            // online there is nothing to open, so just say so.
            if (cls === "portal") {
                root.markOpened();
                root.launchBrowser(root.portalUrl);
            } else if (cls === "unknown") {
                root.launchBrowser(root.candidateUrl);
                Toaster.toast(qsTr("Sign in to network"), qsTr("Opening the network login page"), "wifi_lock");
            } else {
                Toaster.toast(qsTr("Online"), qsTr("This network already looks online"), "wifi", Toast.Success);
            }
        }
        root.maybeAutoOpen();
    }

    // Debug-only: classify an explicit URL (no gateway retry, never opens
    // anything). The result lands in lastProbe/portalUrl/candidateUrl and is
    // readable through the `state` IPC call.
    function probeExplicit(url: string): void {
        root.runProbe(url, (cls, url2) => {
            root.lastProbe = cls;
            root.portalUrl = cls === "portal" ? url2 : "";
            root.candidateUrl = url2 || url;
        });
    }

    // ── Recheck / open ─────────────────────────────────────────────────────

    // Ask NetworkManager for a fresh connectivity verdict, then probe.
    function recheck(): void {
        Nmcli.recheckConnectivity(() => root.probeNow());
    }

    function markOpened(): void {
        root.lastOpenTime = Date.now();
        root.openedFor = root.episodeKey();
    }

    function launchBrowser(url: string): void {
        if (!url || url.length === 0)
            return;
        Quickshell.execDetached(["sh", "-c",
            'command -v brave >/dev/null 2>&1 && exec brave --app="$1" --user-data-dir="$2" || exec xdg-open "$1"',
            "sh", url, `${Paths.tmp}/portal-profile`]);
    }

    // User-initiated: never cooldown-blocked, never a dead button. Launches
    // immediately when a portal is already known; otherwise arms the pending
    // flag (even if a probe is in flight, so the click is consumed not lost)
    // and lets finishProbe respond to the fresh result.
    function open(): void {
        if (root.lastProbe === "portal" && root.portalUrl.length > 0) {
            root.markOpened();
            root.launchBrowser(root.portalUrl);
            return;
        }
        root.openWhenProbed = true;
        root.probeNow();
    }

    // Internal automatic path: only on a positive portal probe, once per
    // episode (ssid + "|" + portalUrl), and at most one auto-open per 60 s.
    function maybeAutoOpen(): void {
        if (root.lastProbe !== "portal" || root.portalUrl.length === 0)
            return;
        if (root.openedFor === root.episodeKey())
            return;
        if (Date.now() - root.lastOpenTime < 60000)
            return;
        root.markOpened();
        Toaster.toast(qsTr("Sign in to network"), qsTr("This network needs you to log in"), "wifi_lock", Toast.Warning);
        root.launchBrowser(root.portalUrl);
    }

    // ── Reactivity ─────────────────────────────────────────────────────────

    Connections {
        target: Nmcli

        function onConnectivityChanged(): void {
            if (Nmcli.connectivity === "full") {
                // The network is healthy again: a later portal on the same
                // SSID is a new episode. Toast only when an episode that
                // actually opened a window just ended.
                const hadEpisode = root.openedFor.length > 0;
                root.lastProbe = "";
                root.portalUrl = "";
                root.candidateUrl = "";
                root.openedFor = "";
                if (hadEpisode)
                    Toaster.toast(qsTr("Online"), qsTr("Connected to the internet"), "wifi", Toast.Success);
            } else if (root.connected) {
                root.probeNow();
            }
        }
    }

    // Only while the row is visible; no polling on healthy networks.
    Timer {
        interval: 15000
        repeat: true
        running: root.active
        onTriggered: root.probeNow()
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.active
        onTriggered: Nmcli.recheckConnectivity()
    }

    IpcHandler {
        function state(): string {
            return `connectivity=${Nmcli.connectivity} connected=${root.connected} iface=${Nmcli.activeInterface} active=${root.active} lastProbe=${root.lastProbe} portalUrl=${root.portalUrl} candidateUrl=${root.candidateUrl} ssid=${root.ssid} episode=${root.openedFor}`;
        }

        // Quickshell IPC returns are synchronous, so the classification
        // cannot be returned from inside the call: this kicks off the probe
        // and the result shows up in `state` a moment later.
        function probe(url: string): string {
            if (!url || url.length === 0)
                return "error: probe requires a url";
            root.probeExplicit(url);
            return `probing ${url}; read the result with: state`;
        }

        function open(): void {
            root.open();
        }

        target: "captivePortal"
    }

    Component {
        id: probeProc

        Process {
            id: proc

            property string url: ""
            property var callback: null

            command: ["bash", root.probeScript, url]
            stdout: StdioCollector {}
            stderr: StdioCollector {}

            onExited: code => { // qmllint disable signal-handler-parameters
                Qt.callLater(() => {
                    const cb = proc.callback;
                    const line = (proc.stdout?.text ?? "").trim().split("\n")[0] ?? "";
                    const parts = line.split(" ");
                    const raw = parts[0] ?? "";
                    const resultUrl = parts[1] ?? "";
                    const cls = raw === "online" || raw === "portal" || raw === "unknown" ? raw : "unknown";
                    proc.destroy();
                    cb?.(cls, resultUrl);
                });
            }
        }
    }

    Component {
        id: gatewayProc

        Process {
            id: proc

            property string iface: ""
            property var callback: null

            command: ["nmcli", "-t", "-f", "IP4.GATEWAY,IP6.GATEWAY", "device", "show", iface]
            stdout: StdioCollector {}

            onExited: code => { // qmllint disable signal-handler-parameters
                Qt.callLater(() => {
                    const cb = proc.callback;
                    const lines = (proc.stdout?.text ?? "").trim().split("\n");
                    let gw = "";
                    for (const line of lines) {
                        const idx = line.indexOf(":");
                        if (idx < 0)
                            continue;
                        const value = line.slice(idx + 1).trim();
                        if (!value || value === "--")
                            continue;
                        // Strip any "%iface" suffix from a link-local v6 gateway.
                        gw = value.split("%")[0];
                        break;
                    }
                    proc.destroy();
                    cb?.(gw);
                });
            }
        }
    }

    Component {
        id: routeProc

        Process {
            id: proc

            property var callback: null

            command: ["ip", "route", "show", "default"]
            stdout: StdioCollector {}

            onExited: code => { // qmllint disable signal-handler-parameters
                Qt.callLater(() => {
                    const cb = proc.callback;
                    const first = (proc.stdout?.text ?? "").trim().split("\n")[0] ?? "";
                    const tokens = first.split(/\s+/);
                    const via = tokens.indexOf("via");
                    const gw = via >= 0 && via + 1 < tokens.length ? tokens[via + 1] : "";
                    proc.destroy();
                    cb?.(gw);
                });
            }
        }
    }
}
