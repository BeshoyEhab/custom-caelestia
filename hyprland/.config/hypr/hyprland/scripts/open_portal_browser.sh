#!/usr/bin/env bash
# open_portal_browser.sh <url> [profile-dir]
#
# Open a captive-portal login URL: prefer a Brave app-window on a throwaway
# profile (no cookies/history from the user's session), fall back to
# xdg-open when Brave is missing. Only http(s) URLs are accepted — a portal's
# Location header can be anything (file:///, javascript:, …), so anything
# else is refused and nothing is launched.
# Exit status: 2 on a usage error or a non-http(s) URL.
set -uo pipefail

if [[ $# -lt 1 || -z "${1:-}" ]]; then
    printf 'Usage: %s <url> [profile-dir]\n' "$0" >&2
    exit 2
fi

url="$1"

case "$url" in
    http://* | https://*) ;;
    *)
        printf 'Refusing to open a non-http(s) URL: %s\n' "$url" >&2
        exit 2
        ;;
esac

profile="${2:-${XDG_RUNTIME_DIR:-/tmp}/caelestia/portal-profile}"

if command -v brave >/dev/null 2>&1; then
    exec brave --app="$url" --user-data-dir="$profile"
fi
exec xdg-open "$url"
