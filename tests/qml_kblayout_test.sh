#!/usr/bin/env bash
# Keyboard-layout popout test.
#
# Regression covered: KbLayoutModel used to call `fetchActiveLayouts`, a
# Process id that only exists in upstream's copy of the file (this tree merged
# it into `fetchDevicesForActive`). The click handler and the XKB-label rebuild
# therefore threw ReferenceError and the active row kept showing the layout the
# popout was opened with until it was destroyed and recreated. The model also
# never listened for Hyprland's `activelayout` events, so a layout switched by
# keybind stayed stale while the popout was open.
#
# Static checks always run (CI-safe). The behavioural checks run the real model
# under a stub `hyprctl` when Quickshell and the Caelestia plugin are installed;
# the event check additionally needs a live Hyprland and is skipped otherwise.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL="${KBLAYOUT_MODEL:-$REPO_DIR/shell/modules/bar/popouts/kblayout/KbLayoutModel.qml}"
FAIL=0

echo "=== qml_kblayout ==="

pass() { echo "  PASS $1"; }
fail() {
    echo "  FAIL $1"
    FAIL=1
}

[[ -f "$MODEL" ]] || {
    fail "model file not found: $MODEL"
    echo "RESULT: FAIL"
    exit 1
}

# ── Static: every `<id>.running` target must be declared in the file ──────────
# This is the exact defect class: an id left behind by a rename compiles but
# throws ReferenceError at runtime.
declared="$(grep -oE '^\s*id:\s*[A-Za-z_][A-Za-z0-9_]*' "$MODEL" | awk '{print $2}' | sort -u)"
missing=0
while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    if ! grep -qx "$target" <<< "$declared"; then
        fail "references undeclared object id '$target' (would throw ReferenceError)"
        missing=$((missing + 1))
    fi
done < <(grep -oE '\b[A-Za-z_][A-Za-z0-9_]*\.running\s*=' "$MODEL" | sed 's/\.running.*//' | sort -u)
[[ $missing -eq 0 ]] && pass "all Process/.running targets are declared ids"

# ── Static: the popout must subscribe to Hyprland layout events ───────────────
if grep -q 'onRawEvent' "$MODEL" && grep -q '"activelayout"' "$MODEL" && grep -q 'target: Hyprland' "$MODEL"; then
    pass "listens for Hyprland activelayout events"
else
    fail "no activelayout subscription (popout goes stale on keybind switches)"
fi

# ── Behavioural (needs quickshell + Caelestia plugin) ────────────────────────
QML_DIR="$(qtpaths6 --query QT_INSTALL_QML 2>/dev/null || true)"
QML_DIR="${QML_DIR:-/usr/lib/qt6/qml}"
QS_BIN="$(command -v qs || true)"

if [[ -z "$QS_BIN" || ! -d "$QML_DIR/Caelestia" ]]; then
    echo "  SKIP runtime checks (quickshell or Caelestia QML module not installed)"
else
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT

    mkdir -p "$TMP/bin"
    cp "$MODEL" "$TMP/KbLayoutModel.qml"

    cat > "$TMP/bin/hyprctl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
state_file="${STUB_STATE:?STUB_STATE must be set}"
idx="$(cat "$state_file")"
case "${1:-}" in
    -j)
        case "${2:-}" in
            getoption) echo '{"option":"input:kb_layout","str":"us,ara","set":true}' ;;
            devices) echo "{\"keyboards\":[{\"name\":\"kbd\",\"main\":true,\"layout\":\"us,ara\",\"active_layout_index\":$idx,\"active_keymap\":\"kbd\"}]}" ;;
            *) echo '{}' ;;
        esac
        ;;
    switchxkblayout) echo "${3:-0}" > "$state_file"; echo ok ;;
    *) echo "stub hyprctl: unsupported: $*" >&2; exit 1 ;;
esac
STUB
    chmod +x "$TMP/bin/hyprctl"
    echo 0 > "$TMP/state"

    run_case() { # run_case <name> <qml> <expected-label-prefix> <extra-log-marker>
        local out
        out="$(PATH="$TMP/bin:$PATH" STUB_STATE="$TMP/state" timeout 30 "$QS_BIN" -p "$TMP/$2" 2>&1)"
        if grep -q 'ReferenceError' <<< "$out"; then
            fail "$1: ReferenceError in model"
            grep 'ReferenceError' <<< "$out" | sed 's/^/        /'
            return
        fi
        if grep -q "KB_$3=" <<< "$out"; then
            pass "$1: active layout tracked ($3)"
        else
            fail "$1: active layout not updated (expected KB_$3=${4:-})"
            grep 'KB_' <<< "$out" | sed 's/^/        /'
        fi
    }

    # Click path: switching from inside the popout must move the active row.
    cat > "$TMP/click.qml" <<'QML'
import QtQuick

Item {
    KbLayoutModel {
        id: kb
    }

    Component.onCompleted: kb.start()

    Timer {
        interval: 900
        running: true
        onTriggered: kb.switchTo(1)
    }

    Timer {
        interval: 2200
        running: true
        onTriggered: {
            console.log("KB_CLICKED=" + kb.activeLabel);
            Qt.quit();
        }
    }
}
QML
    echo 0 > "$TMP/state"
    run_case "click switch" click.qml CLICKED

    # Event path: a layout change made outside the popout (keybind) must be
    # picked up while the popout stays alive. Needs a live Hyprland.
    REAL_HYPRCTL="$(command -v hyprctl || true)"
    if [[ -n "$REAL_HYPRCTL" && -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        # Re-apply the *current* index so the desktop layout does not change
        # for the user; Hyprland emits activelayout all the same.
        cur="$("$REAL_HYPRCTL" -j devices | python3 -c 'import json,sys
kb = [k for k in json.load(sys.stdin)["keyboards"] if k["main"]]
print(kb[0]["active_layout_index"] if kb else 0)')"
        sed "s|\$REAL_CURRENT|$REAL_HYPRCTL switchxkblayout all $cur|" > "$TMP/event.qml" <<QML
import QtQuick
import Quickshell.Io

Item {
    KbLayoutModel {
        id: kb
    }

    Component.onCompleted: kb.start()

    Timer {
        interval: 900
        running: true
        onTriggered: setState.running = true
    }

    Process {
        id: setState

        command: ["/bin/sh", "-c", "echo 1 > $TMP/state"]

        onExited: eventDelay.start()
    }

    Timer {
        id: eventDelay

        interval: 300
        onTriggered: fakeEvent.running = true
    }

    Process {
        id: fakeEvent

        command: ["/bin/sh", "-c", "\$REAL_CURRENT"]
    }

    Timer {
        interval: 3200
        running: true
        onTriggered: {
            console.log("KB_EVENTED=" + kb.activeLabel);
            Qt.quit();
        }
    }
}
QML
        echo 0 > "$TMP/state"
        run_case "external layout event" event.qml EVENTED
    else
        echo "  SKIP external-event check (no live Hyprland)"
    fi
fi

if [[ $FAIL -ne 0 ]]; then
    echo "RESULT: FAIL"
    exit 1
fi
echo "RESULT: PASS"
