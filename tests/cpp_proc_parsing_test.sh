#!/usr/bin/env bash
# TDD RED test: /proc parsing must avoid per-tick full-file read + QString + QRegularExpression.
# Fails on old cpu.cpp/memory.cpp, passes after optimized parsing lands.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CPU="$REPO_DIR/shell/plugin/src/Caelestia/Services/cpu.cpp"
MEM="$REPO_DIR/shell/plugin/src/Caelestia/Services/memory.cpp"
FAIL=0

check() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "  PASS $desc"
    else
        echo "  FAIL $desc"
        FAIL=1
    fi
}

check_not() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "  FAIL $desc (forbidden pattern present)"
        FAIL=1
    else
        echo "  PASS $desc"
    fi
}

echo "═══ cpp_proc_parsing ═══"
echo "-- cpu.cpp:refreshPercentage must use readLine (not readAll) --"
# extract refreshPercentage body and assert on it
CPU_BODY=$(awk '/void Cpu::refreshPercentage/,/^}/' "$CPU")
echo "$CPU_BODY" | grep -q "readLine" && echo "  PASS cpu uses readLine" || { echo "  FAIL cpu uses readLine"; FAIL=1; }
echo "$CPU_BODY" | grep -q "readAll" && { echo "  FAIL cpu still uses readAll in hot path"; FAIL=1; } || echo "  PASS cpu avoids readAll in hot path"
echo "$CPU_BODY" | grep -q "QRegularExpression\|fromLatin1\|captured" && { echo "  FAIL cpu still uses QString/regex in hot path"; FAIL=1; } || echo "  PASS cpu avoids QString/regex in hot path"
echo "$CPU_BODY" | grep -Eq "sscanf|strtoull|fromChars" && echo "  PASS cpu parses bytes numerically" || { echo "  FAIL cpu parses bytes numerically"; FAIL=1; }

echo "-- memory.cpp:tick must scan lines (not readAll+regex) --"
MEM_BODY=$(awk '/void Memory::tick/,/^}/' "$MEM")
echo "$MEM_BODY" | grep -q "readLine" && echo "  PASS mem uses readLine" || { echo "  FAIL mem uses readLine"; FAIL=1; }
echo "$MEM_BODY" | grep -q "readAll" && { echo "  FAIL mem still uses readAll in hot path"; FAIL=1; } || echo "  PASS mem avoids readAll in hot path"
echo "$MEM_BODY" | grep -q "QRegularExpression\|fromLatin1" && { echo "  FAIL mem still uses QString/regex in hot path"; FAIL=1; } || echo "  PASS mem avoids QString/regex in hot path"
echo "$MEM_BODY" | grep -q "MemTotal" && echo "  PASS mem looks for MemTotal" || { echo "  FAIL mem looks for MemTotal"; FAIL=1; }
echo "$MEM_BODY" | grep -q "MemAvailable" && echo "  PASS mem looks for MemAvailable" || { echo "  FAIL mem looks for MemAvailable"; FAIL=1; }

# keep one-shot name parsing allowed to use regex (runs once), but hot paths must not
echo "$CPU_BODY" | grep -q "QRegularExpression" && { echo "  FAIL cpu hot path still uses QRegularExpression"; FAIL=1; } || echo "  PASS cpu hot path has no QRegularExpression"
grep -q "qregularexpression" "$MEM" && { echo "  FAIL memory.cpp still includes qregularexpression"; FAIL=1; } || echo "  PASS memory.cpp has no qregularexpression include"

if [[ $FAIL -ne 0 ]]; then
    echo "RESULT: FAIL (red - optimization missing)"
    exit 1
fi
echo "RESULT: PASS (green)"
