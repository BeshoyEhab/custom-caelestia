#!/usr/bin/env bash
# TDD RED test: hasLyrics NOTIFY must be the signal emitted on every m_hasLyrics mutation.
# clearLines() emits only hasLyricsChanged(); setLines() emits both lyricsChanged() and
# hasLyricsChanged(). If NOTIFY is lyricsChanged, QML bindings go stale after clear.
# Fails before the fix, passes after.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HPP="$REPO_DIR/shell/plugin/src/Caelestia/Services/lyrics.hpp"
CPP="$REPO_DIR/shell/plugin/src/Caelestia/Services/lyrics.cpp"
FAIL=0

echo "═══ cpp_lyrics_notify ═══"

NOTIFY=$(grep -o "Q_PROPERTY(bool hasLyrics READ hasLyrics NOTIFY [A-Za-z]*" "$HPP" | awk '{print $NF}')
echo "  hasLyrics NOTIFY = ${NOTIFY:-<not found>}"
if [[ "$NOTIFY" != "hasLyricsChanged" ]]; then
    echo "  FAIL NOTIFY must be hasLyricsChanged (got: $NOTIFY)"
    FAIL=1
else
    echo "  PASS NOTIFY is hasLyricsChanged"
fi

# every function that mutates m_hasLyrics must emit the NOTIFY signal
for fn in "setLines" "clearLines"; do
    BODY=$(awk "/(void Lyrics::)?$fn\(/,/^}/" "$CPP")
    if echo "$BODY" | grep -q "m_hasLyrics ="; then
        if echo "$BODY" | grep -q "emit $NOTIFY()"; then
            echo "  PASS $fn emits $NOTIFY after mutating m_hasLyrics"
        else
            echo "  FAIL $fn mutates m_hasLyrics but does not emit $NOTIFY()"
            FAIL=1
        fi
    else
        echo "  FAIL could not find m_hasLyrics mutation in $fn"
        FAIL=1
    fi
done

if [[ $FAIL -ne 0 ]]; then
    echo "RESULT: FAIL (red - stale binding bug present)"
    exit 1
fi
echo "RESULT: PASS (green)"
