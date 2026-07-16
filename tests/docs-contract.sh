#!/bin/sh

set -eu

case $0 in
    */*) script_dir=${0%/*} ;;
    *) script_dir=. ;;
esac

ROOT=$(CDPATH= cd -- "${script_dir}/.." && pwd)
DOCKERFILE=${ROOT}/Dockerfile
README=${ROOT}/README.md
CLAUDE=${ROOT}/CLAUDE.md
EVENTS_LOCK=${ROOT}/dependencies/lua-resty-events.lock

fail() {
    printf 'docs-contract: FAIL: %s\n' "$*" >&2
    exit 1
}

assert_not_contains() {
    pattern=$1
    file=$2
    if grep -F -- "$pattern" "$file" >/dev/null; then
        fail "${file#${ROOT}/} contains stale or inaccurate content: ${pattern}"
    fi
}

visible_document() {
    awk '
        in_comment {
            if (/-->/) {
                in_comment = 0
            }
            next
        }
        /<!--/ {
            if ($0 !~ /-->/) {
                in_comment = 1
            }
            next
        }
        { print }
    ' "$1"
}

assert_visible_exact_line() {
    expected=$1
    line=$2
    file=$3
    actual=$(visible_document "$file" | grep -F -x -c -- "$line" || true)
    [ "$actual" -eq "$expected" ] \
        || fail "${file#${ROOT}/} expected ${expected} visible exact line(s): ${line}; found ${actual}"
}

assert_visible_not_matches() {
    pattern=$1
    file=$2
    if visible_document "$file" | grep -E -- "$pattern" >/dev/null; then
        fail "${file#${ROOT}/} contains a stale visible version matching: ${pattern}"
    fi
}

assert_docker_code_count() {
    expected=$1
    pattern=$2
    actual=$(awk -v pattern="$pattern" '
        /^[[:space:]]*#/ { next }
        index($0, pattern) { count++ }
        END { print count + 0 }
    ' "$DOCKERFILE")
    [ "$actual" -eq "$expected" ] \
        || fail "Dockerfile expected ${expected} code occurrence(s) of: ${pattern}; found ${actual}"
}

docker_arg_default() {
    key=$1
    awk -v key="$key" '
        $1 == "ARG" && index($2, key "=") == 1 {
            count++
            value=substr($2, length(key) + 2)
        }
        END {
            if (count != 1 || value == "") {
                exit 1
            }
            print value
        }
    ' "$DOCKERFILE" || fail "Dockerfile must define exactly one default for ${key}"
}

narrative_text() {
    visible_document "$1" | awk '
        /^```/ { in_fence = !in_fence; next }
        in_fence { next }
        { print }
    '
}

assert_narrative_contains() {
    description=$1
    narrative=$2
    pattern=$3
    case $narrative in
        *"$pattern"*) ;;
        *) fail "${description} narrative missing: ${pattern}" ;;
    esac
}

extract_local_gate() {
    visible_document "$1" | awk '
        $0 == "### Local ARM64 verification gate" { heading_count++; after_heading=1; next }
        after_heading && $0 == "```bash" { in_gate=1; after_heading=0; next }
        in_gate && $0 == "```" { in_gate=0; complete=1; next }
        in_gate { print }
        END {
            if (heading_count != 1 || !complete) {
                exit 1
            }
        }
    ' || fail "${1#${ROOT}/} must contain one complete visible Local ARM64 verification gate"
}

assert_no_invented_digest() {
    file=$1
    if grep -E 'sungyism/openresty:1[.]31[.]1[.]1@sha256:[0-9a-f]{64}' "$file" >/dev/null; then
        fail "${file#${ROOT}/} must not invent or reuse an unverified events image digest"
    fi
}

for file in "$DOCKERFILE" "$README" "$CLAUDE" "$EVENTS_LOCK"; do
    [ -f "$file" ] || fail "missing required file: ${file#${ROOT}/}"
done

openresty_version=$(docker_arg_default OPENRESTY_VER)
openssl_version=$(docker_arg_default OPENSSL_VER)
[ "$openresty_version" = 1.31.1.1 ] \
    || fail "unexpected Dockerfile OPENRESTY_VER default: ${openresty_version}"
[ "$openssl_version" = 3.5.6 ] \
    || fail "unexpected Dockerfile OPENSSL_VER default: ${openssl_version}"

events_version=$(awk -F= '$1 == "RESTY_EVENTS_VERSION" { count++; value=$2 } END { if (count != 1) exit 1; print value }' "$EVENTS_LOCK") \
    || fail "lua-resty-events lock must define exactly one version"
[ "$events_version" = 0.3.1 ] || fail "unexpected lua-resty-events version: ${events_version}"

assert_visible_exact_line 1 "| \`OPENRESTY_VER\` | \`${openresty_version}\` | OpenResty version |" "$README"
assert_visible_exact_line 1 "| \`OPENSSL_VER\` | \`${openssl_version}\` | OpenSSL version |" "$README"
assert_not_contains 'Runs as non-root user `openresty` (UID 101) by default' "$README"
assert_not_contains '| **lua-resty-http** | HTTP client library for OpenResty |' "$README"
assert_not_contains '- **lua-resty-http** - HTTP client for OpenResty' "$CLAUDE"

for document in "$README" "$CLAUDE"; do
    assert_visible_not_matches '(^|[^0-9.])1[.]29[.]2[.]5([^0-9.]|$)' "$document"
    assert_visible_not_matches '(^|[^0-9.])3[.]5[.]5([^0-9.]|$)' "$document"
done

assert_docker_code_count 1 'useradd -r -u 101 -g $USER'
assert_docker_code_count 1 '--add-module=${BUILD_DIR}/src/lua-resty-events-${RESTY_EVENTS_COMMIT} \'

runtime_stage_summary=$(awk '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    toupper($1) == "FROM" {
        from_count++
        in_runtime=($2 == "${RUNTIME_IMAGE}")
        if (in_runtime) {
            runtime_count++
        }
        last_from=$2
        next
    }
    in_runtime && toupper($1) == "USER" { runtime_user_count++ }
    END {
        printf "%d %d %s\n", runtime_count, runtime_user_count, last_from
    }
' "$DOCKERFILE")
set -- $runtime_stage_summary
[ "$1" -eq 1 ] || fail "Dockerfile must contain exactly one runtime stage"
[ "$2" -eq 0 ] || fail "final runtime stage must not contain a USER instruction"
[ "$3" = '${RUNTIME_IMAGE}' ] || fail "runtime stage must be the final Dockerfile stage"

events_sentence='`lua-resty-events` `0.3.1` is installed with the statically linked CORE module `ngx_lua_events_module`.'
http_sentence='`resty.http` is absent from this base image.'
user_sentence='The `openresty` UID 101 account exists, but the final runtime stage has no `USER` instruction, so the default container process runs as root.'
tag_sentence='The `latest` and version tags are convenience selectors; production consumers resolve and pin the tested immutable digest.'
digest_sentence='Immutable references start with `sungyism/openresty:1.31.1.1@sha256:` and the digest must come from verified release evidence.'
version_rule_sentence='The release workflow freezes its public version to `dependencies/openresty.lock`. If the repository variable `OPENRESTY_VERSION` is configured, it must be empty or exactly match the reviewed lock; it is never used to select a newer version.'

expected_gate='tests/source-contract.sh
tests/workflow-contract.sh
docker build --platform linux/arm64 -t sungyism/openresty:events-contract .
tests/image-contract.sh sungyism/openresty:events-contract linux/arm64
tests/inventory-contract.sh sungyism/openresty:events-contract linux/arm64'

for document in "$README" "$CLAUDE"; do
    narrative=$(narrative_text "$document")
    assert_narrative_contains "${document#${ROOT}/}" "$narrative" "$events_sentence"
    assert_narrative_contains "${document#${ROOT}/}" "$narrative" "$http_sentence"
    assert_narrative_contains "${document#${ROOT}/}" "$narrative" "$user_sentence"
    assert_narrative_contains "${document#${ROOT}/}" "$narrative" "$tag_sentence"
    assert_narrative_contains "${document#${ROOT}/}" "$narrative" "$digest_sentence"
    assert_no_invented_digest "$document"
    actual_gate=$(extract_local_gate "$document")
    [ "$actual_gate" = "$expected_gate" ] \
        || fail "${document#${ROOT}/} local ARM64 verification gate is incomplete or out of order"
done

claude_narrative=$(narrative_text "$CLAUDE")
assert_narrative_contains CLAUDE.md "$claude_narrative" "$version_rule_sentence"

printf 'docs-contract: PASS\n'
