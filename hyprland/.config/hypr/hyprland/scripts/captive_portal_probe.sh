#!/usr/bin/env bash
# captive_portal_probe.sh <url>
#
# Classify <url> as online / portal / unknown. Prints exactly one line to
# stdout: "<classification> <url> <http-status>" (unknown -> status 000).
# Diagnostics, if any, go to stderr.
# Exit status: 0 online, 1 portal (login needed), 2 unknown or usage error.
set -uo pipefail

if [[ $# -lt 1 || -z "${1:-}" ]]; then
    printf 'Usage: %s <url>\n' "$0" >&2
    exit 2
fi

url="$1"
body="$(mktemp)"
trap 'rm -f "$body"' EXIT

# Single curl call; deliberately no -L: redirects must be observed, not
# followed. %{redirect_url} is populated from a 3xx Location header anyway.
curl_out="$(curl -s -m 8 -o "$body" -w '%{http_code} %{redirect_url}' "$url")"
curl_rc=$?

http=""
redirect=""
read -r http redirect <<<"$curl_out"

case "$curl_rc" in
    6|7|28) # resolve failure, connect failure, timeout
        printf 'unknown %s 000\n' "$url"
        exit 2
        ;;
esac

if [[ -z "$http" ]]; then
    printf 'unknown %s 000\n' "$url"
    exit 2
fi

body_head="$(head -c 256 "$body")"

if [[ "$http" == "204" || "$body_head" == "NetworkManager is online"* ]]; then
    printf 'online %s %s\n' "$url" "$http"
    exit 0
fi

case "$http" in
    3??)
        if [[ -n "$redirect" ]]; then
            printf 'portal %s %s\n' "$redirect" "$http"
        else
            printf 'portal %s %s\n' "$url" "$http"
        fi
        exit 1
        ;;
    2??)
        printf 'portal %s %s\n' "$url" "$http"
        exit 1
        ;;
esac

printf 'unknown %s 000\n' "$url"
exit 2
