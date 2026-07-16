#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
LOCK=${ROOT}/dependencies/lua-resty-events.lock
MANIFEST=${ROOT}/dependencies/lua-resty-events.files.sha256
ARCHIVE=${1:?usage: tests/events-archive-contract.sh ARCHIVE}

fail() {
    printf 'events-archive-contract: FAIL: %s\n' "$*" >&2
    exit 1
}

value() {
    key=$1
    result=$(sed -n "s/^${key}=//p" "$LOCK")
    [ -n "$result" ] || fail "missing lock key: ${key}"
    [ "$(printf '%s\n' "$result" | wc -l | tr -d ' ')" -eq 1 ] \
        || fail "duplicate lock key: ${key}"
    printf '%s\n' "$result"
}

commit=$(value RESTY_EVENTS_COMMIT)
expected_archive_sha=$(value RESTY_EVENTS_SHA256)

printf '%s  %s\n' "$expected_archive_sha" "$ARCHIVE" | sha256sum -c -

tmp=$(mktemp -d "${TMPDIR:-/tmp}/events-archive-contract.XXXXXX")
cleanup() {
    rm -rf "$tmp"
}
trap cleanup EXIT HUP INT TERM

tar -xzf "$ARCHIVE" -C "$tmp"
source_root=${tmp}/lua-resty-events-${commit}
[ -d "$source_root" ] || fail "unexpected archive root"

(
    cd "$source_root"
    sha256sum -c "$MANIFEST"
)

printf 'events-archive-contract: PASS\n'
