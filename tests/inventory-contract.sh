#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BASELINE_IMAGE=sungyism/openresty:1.31.1.1@sha256:3fca0dac0d8d073be2980170a4eda04beb7b4721f6a2ecc65c0a0921ee2a3016
NEW_IMAGE=${1:-}
platform_arg=${2:-}
EVIDENCE_DIR=${EVIDENCE_DIR:-/tmp/openresty-events-evidence}
EVENTS_FILES=${ROOT}/dependencies/lua-resty-events.files.sha256
EVENTS_MODULE=--add-module=/build/openresty/src/lua-resty-events-bc85295b7c23eda2dbf2b4acec35c93f77b26787
NGX_LUA_MODULE=--add-module=../ngx_lua-0.10.31rc5
tmpdir=

fail() {
    printf 'inventory-contract: FAIL: %s\n' "$*" >&2
    exit 1
}

docker_run() {
    if [ -n "$platform_arg" ]; then
        docker run --platform "$platform_arg" "$@"
    else
        docker run "$@"
    fi
}

normalize_platform() {
    os=${1%/*}
    arch=${1#*/}
    case "$arch" in
        aarch64) arch=arm64 ;;
        x86_64) arch=amd64 ;;
    esac
    printf '%s/%s\n' "$os" "$arch"
}

cleanup() {
    status=$?
    trap - EXIT
    if [ -n "$tmpdir" ] && [ -d "$tmpdir" ]; then
        rm -rf "$tmpdir"
    fi
    exit "$status"
}

trap cleanup EXIT
trap 'fail "interrupted by HUP"' HUP
trap 'fail "interrupted by INT"' INT
trap 'fail "interrupted by TERM"' TERM

[ -n "$NEW_IMAGE" ] || fail "usage: $0 NEW_IMAGE [PLATFORM]"
[ -f "$EVENTS_FILES" ] || fail "missing reviewed events inventory: $EVENTS_FILES"
for command in docker jq awk sed grep sort comm diff mktemp cp tr wc rm mkdir; do
    command -v "$command" >/dev/null 2>&1 || fail "required command not found: $command"
done

if [ -n "$platform_arg" ]; then
    requested_platform=$(normalize_platform "$platform_arg")
else
    native_platform=$(docker info --format '{{.OSType}}/{{.Architecture}}') \
        || fail "unable to inspect Docker native platform"
    requested_platform=$(normalize_platform "$native_platform")
fi
case "$requested_platform" in
    linux/amd64|linux/arm64) ;;
    *) fail "unsupported platform: $requested_platform" ;;
esac
platform_slug=$(printf '%s' "$requested_platform" | tr '/' '-')

inspect_platform() {
    docker image inspect "$1" --format '{{.Os}}/{{.Architecture}}' 2>/dev/null \
        | sed -n '1p'
}

ensure_image() {
    image=$1
    actual=$(inspect_platform "$image" || true)
    if [ "$(normalize_platform "${actual:-unknown/unknown}")" = "$requested_platform" ]; then
        return 0
    fi
    docker pull --platform "$requested_platform" "$image" >/dev/null \
        || fail "unable to pull $image for $requested_platform"
    actual=$(inspect_platform "$image" || true)
    [ "$(normalize_platform "${actual:-unknown/unknown}")" = "$requested_platform" ] \
        || fail "$image resolved to ${actual:-unknown}, expected $requested_platform"
}

ensure_image "$BASELINE_IMAGE"
ensure_image "$NEW_IMAGE"

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/openresty-inventory.XXXXXX")
mkdir -p "$EVIDENCE_DIR"

compare_files() {
    label=$1
    baseline=$2
    candidate=$3
    diff_file=${tmpdir}/${label}.diff
    if ! diff -u "$baseline" "$candidate" >"$diff_file"; then
        evidence=${EVIDENCE_DIR}/${label}-${platform_slug}.diff
        cp "$diff_file" "$evidence"
        fail "${label} differs; preserved diff at ${evidence}"
    fi
}

capture_nginx_v() {
    image=$1
    output=$2
    docker_run --rm --entrypoint /bin/sh "$image" -c '/usr/sbin/nginx -V 2>&1' >"$output" \
        || fail "unable to capture nginx -V from $image"
}

capture_lualib() {
    image=$1
    output=$2
    docker_run --rm --entrypoint /bin/sh "$image" -c \
        'cd /opt/openresty/lualib && find . -type f -print | sed "s#^./##" | sort' >"$output" \
        || fail "unable to capture Lua inventory from $image"
}

capture_config() {
    image=$1
    output=$2
    docker image inspect "$image" \
        | jq -cS '.[0].Config | {User,Entrypoint,Cmd,ExposedPorts,StopSignal,WorkingDir,Env}' >"$output" \
        || fail "unable to capture image Config from $image"
}

capture_nginx_v "$BASELINE_IMAGE" "${tmpdir}/baseline-nginx-v"
capture_nginx_v "$NEW_IMAGE" "${tmpdir}/new-nginx-v"

for file in "${tmpdir}/baseline-nginx-v" "${tmpdir}/new-nginx-v"; do
    nginx_version_count=$(grep -F -x -c -- 'nginx version: openresty/1.31.1.1' "$file" || true)
    [ "$nginx_version_count" -eq 1 ] \
        || fail "OpenResty version line changed in $file"
    openssl_version_count=$(awk '
        $1 == "built" && $2 == "with" && $3 == "OpenSSL" && $4 == "3.5.6" { count++ }
        END { print count + 0 }
    ' "$file")
    [ "$openssl_version_count" -eq 1 ] \
        || fail "OpenSSL version token changed in $file"
    ngx_lua_count=$(sed -n 's/^configure arguments: //p' "$file" \
        | tr ' ' '\n' | grep -F -x -c -- "$NGX_LUA_MODULE" || true)
    [ "$ngx_lua_count" -eq 1 ] \
        || fail "ngx_lua configure token changed in $file"
done

sed -n 's/^configure arguments: //p' "${tmpdir}/baseline-nginx-v" >"${tmpdir}/baseline-configure"
sed -n 's/^configure arguments: //p' "${tmpdir}/new-nginx-v" >"${tmpdir}/new-configure"
[ "$(wc -l <"${tmpdir}/baseline-configure" | tr -d ' ')" -eq 1 ] \
    || fail "baseline configure arguments are missing or duplicated"
[ "$(wc -l <"${tmpdir}/new-configure" | tr -d ' ')" -eq 1 ] \
    || fail "new configure arguments are missing or duplicated"

baseline_events_count=$(tr ' ' '\n' <"${tmpdir}/baseline-configure" | grep -F -x -c -- "$EVENTS_MODULE" || true)
new_events_count=$(tr ' ' '\n' <"${tmpdir}/new-configure" | grep -F -x -c -- "$EVENTS_MODULE" || true)
[ "$baseline_events_count" -eq 0 ] || fail "baseline unexpectedly contains events configure input"
[ "$new_events_count" -eq 1 ] || fail "new configure input count is ${new_events_count}, expected 1"
awk -v token="$EVENTS_MODULE" '{ sub(" " token, "", $0); print }' \
    "${tmpdir}/new-configure" >"${tmpdir}/new-configure-normalized"
compare_files configure "${tmpdir}/baseline-configure" "${tmpdir}/new-configure-normalized"

capture_lualib "$BASELINE_IMAGE" "${tmpdir}/baseline-lualib"
capture_lualib "$NEW_IMAGE" "${tmpdir}/new-lualib"
awk '$2 ~ /^lualib\/resty\/events\// { sub(/^lualib\//, "", $2); print $2 }' \
    "$EVENTS_FILES" | sort >"${tmpdir}/expected-events"
comm -13 "${tmpdir}/baseline-lualib" "${tmpdir}/new-lualib" >"${tmpdir}/actual-additions"
compare_files lua-additions "${tmpdir}/expected-events" "${tmpdir}/actual-additions"
awk 'NR == FNR { added[$0] = 1; next } !added[$0]' \
    "${tmpdir}/expected-events" "${tmpdir}/new-lualib" >"${tmpdir}/new-lualib-normalized"
compare_files lua-inventory "${tmpdir}/baseline-lualib" "${tmpdir}/new-lualib-normalized"
if grep -E '^resty/http(\.lua|/)' "${tmpdir}/baseline-lualib" "${tmpdir}/new-lualib" >/dev/null; then
    fail "resty.http must remain absent from /opt/openresty/lualib"
fi

for image in "$BASELINE_IMAGE" "$NEW_IMAGE"; do
    cjson_version=$(docker_run --rm --entrypoint /opt/openresty/luajit/bin/luajit "$image" \
        -e 'print(require("cjson")._VERSION)') || fail "unable to load cJSON from $image"
    [ "$cjson_version" = 2.1.0.11 ] || fail "cJSON runtime version is $cjson_version in $image"
    docker_run --rm --entrypoint /bin/sh "$image" -c \
        'command -v resty >/dev/null && test -x "$(command -v resty)"' \
        || fail "resty CLI is not executable in $image"
done

capture_config "$BASELINE_IMAGE" "${tmpdir}/baseline-config"
capture_config "$NEW_IMAGE" "${tmpdir}/new-config"
compare_files image-config "${tmpdir}/baseline-config" "${tmpdir}/new-config"

for image in "$BASELINE_IMAGE" "$NEW_IMAGE"; do
    actual=$(normalize_platform "$(inspect_platform "$image")")
    [ "$actual" = "$requested_platform" ] \
        || fail "$image platform is $actual, expected $requested_platform"
done

printf 'inventory-contract: PASS baseline=%s new=%s platform=%s\n' \
    "$BASELINE_IMAGE" "$NEW_IMAGE" "$requested_platform"
