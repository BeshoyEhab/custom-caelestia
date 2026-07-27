#!/usr/bin/env bash
# QML structure validation tests
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

PASS=0
FAIL=0

pass() { echo -e "  \033[0;32mPASS\033[0m $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  \033[0;31mFAIL\033[0m $1"; FAIL=$((FAIL + 1)); }

SHELL_DIR="$REPO_DIR/shell"

# Collect QML files (excluding upstream/)
mapfile -t QML_FILES < <(find "$SHELL_DIR" -name '*.qml' -not -path '*/upstream/*' | sort)

if [[ ${#QML_FILES[@]} -eq 0 ]]; then
    fail "No QML files found"
    exit 1
fi
pass "Found ${#QML_FILES[@]} QML files"

# ── 1. Basic file integrity ──────────────────────────────────────────────────
for f in "${QML_FILES[@]}"; do
    rel="${f#"$SHELL_DIR/"}"
    if [[ ! -s "$f" ]]; then
        fail "Empty QML file: $rel"
        continue
    fi
    if ! grep -qE '(import |\bItem\b|\bWindow\b|\bPopup\b|\bLoader\b|\bText\b|\bRectangle\b|\bColumnLayout\b|\bRowLayout\b)' "$f" 2>/dev/null; then
        fail "Suspicious QML (no QML patterns): $rel"
        continue
    fi
done
pass "All QML files are non-empty with QML content"

# ── 2. Import resolution: local path imports ───────────────────────────────────
IMPORT_FAILURES=0
for f in "${QML_FILES[@]}"; do
    rel="${f#"$SHELL_DIR/"}"
    qml_dir="$(dirname "$f")"
    while IFS= read -r line; do
        # trim leading whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        [[ "$line" != "import "* ]] && continue
        # Skip multi-line continuations
        [[ "$line" == *"\\" ]] && continue

        # Extract the module/path part
        raw="${line#import }"
        raw="${raw% as *}"
        raw="${raw%\;}"
        raw="${raw#\"}"; raw="${raw%\"}"
        raw="$(echo "$raw" | xargs)"

        # Skip known framework imports
        case "$raw" in
            Qt*|QtQuick*|QtQml*|QtMultimedia*) continue ;;
            Quickshell*|qs.*|Caelestia*|M3Shapes*) continue ;;
            "qrc"/*|"root:"/*) continue ;;
            "") continue ;;
        esac

        # Try to resolve as relative path
        resolved="$qml_dir/$raw"
        if [[ -d "$resolved" ]] || [[ -f "$resolved.qml" ]] || [[ -f "$resolved" ]]; then
            continue
        fi

        # Check if it might be a module via qmldir
        found=false
        while IFS= read -r -d '' qmldir; do
            if grep -qi "module $raw" "$qmldir" 2>/dev/null; then
                found=true; break
            fi
        done < <(find "$SHELL_DIR" -name qmldir -not -path '*/upstream/*' -print0 2>/dev/null)

        if ! $found; then
            fail "Unresolved import '$raw' in $rel"
            IMPORT_FAILURES=$((IMPORT_FAILURES + 1))
        fi
    done < "$f"
done
[[ $IMPORT_FAILURES -eq 0 ]] && pass "All local imports resolve"

# ── 3. Colours.palette needs import qs.services ────────────────────────────────
COLOURS_MISSING=0
for f in "${QML_FILES[@]}"; do
    rel="${f#"$SHELL_DIR/"}"
    if grep -q 'Colours\.palette' "$f" 2>/dev/null; then
        if grep -q 'import qs\.services' "$f" 2>/dev/null; then
            :
        elif grep -q 'import.*Colours' "$f" 2>/dev/null; then
            :
        else
            fail "Missing 'import qs.services' in $rel (uses Colours.palette)"
            COLOURS_MISSING=$((COLOURS_MISSING + 1))
        fi
    fi
done
[[ $COLOURS_MISSING -eq 0 ]] && pass "All Colours.palette usages have import qs.services"

# ── 4. Bar.qml must NOT have pragma ComponentBehavior:Bound ────────────────────
BAR_QML="$SHELL_DIR/modules/bar/Bar.qml"
if [[ -f "$BAR_QML" ]]; then
    if grep -q "pragma ComponentBehavior: Bound" "$BAR_QML"; then
        fail "Bar.qml must NOT have pragma ComponentBehavior:Bound"
    else
        pass "Bar.qml correctly omits pragma ComponentBehavior:Bound"
    fi
fi

# ── 5. Bar component file existence ──────────────────────────────────────────
BAR_COMP="$SHELL_DIR/modules/bar/components"
BAR_POP="$SHELL_DIR/modules/bar/popouts"
BAR_WS="$BAR_COMP/workspaces"

all_bar_files=(
    "$BAR_COMP/ActiveWindow.qml"  "$BAR_COMP/Clock.qml"    "$BAR_COMP/OsIcon.qml"
    "$BAR_COMP/Power.qml"         "$BAR_COMP/StatusIcons.qml" "$BAR_COMP/Tray.qml"
    "$BAR_COMP/TrayItem.qml"
    "$BAR_WS/ActiveIndicator.qml" "$BAR_WS/OccupiedBg.qml" "$BAR_WS/SpecialWorkspaces.qml"
    "$BAR_WS/Workspace.qml"       "$BAR_WS/Workspaces.qml"
    "$BAR_POP/ActiveWindow.qml"   "$BAR_POP/Audio.qml"     "$BAR_POP/Battery.qml"
    "$BAR_POP/Bluetooth.qml"      "$BAR_POP/ClipWrapper.qml" "$BAR_POP/Content.qml"
    "$BAR_POP/kblayout/KbLayout.qml"       "$BAR_POP/kblayout/KbLayoutModel.qml"
    "$BAR_POP/LockStatus.qml"     "$BAR_POP/Network.qml"   "$BAR_POP/PopoutState.qml"
    "$BAR_POP/TrayMenu.qml"       "$BAR_POP/WirelessPassword.qml" "$BAR_POP/Wrapper.qml"
)

missing=0
for file in "${all_bar_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        fail "Missing bar file: ${file#"$SHELL_DIR/"}"
        missing=$((missing + 1))
    fi
done
[[ $missing -eq 0 ]] && pass "All $(( ${#all_bar_files[@]} )) bar component files exist"

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo "qml_test: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
