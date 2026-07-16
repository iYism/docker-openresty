#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DOCKERFILE=${ROOT}/Dockerfile
OPENRESTY_LOCK=${ROOT}/dependencies/openresty.lock
EVENTS_LOCK=${ROOT}/dependencies/lua-resty-events.lock
EVENTS_FILES=${ROOT}/dependencies/lua-resty-events.files.sha256
IMAGE_CONTRACT=${ROOT}/tests/image-contract.sh
INVENTORY_CONTRACT=${ROOT}/tests/inventory-contract.sh

fail() {
    printf 'source-contract: FAIL: %s\n' "$*" >&2
    exit 1
}

assert_file_exact() {
    expected=$1
    file=$2
    description=$3

    [ -f "$file" ] || fail "missing ${description}: ${file}"
    printf '%s\n' "$expected" | cmp -s - "$file" \
        || fail "${description} differs from the reviewed contract"
}

assert_lock_value() {
    file=$1
    key=$2
    expected=$3
    count=$(awk -F= -v key="$key" '$1 == key { count++ } END { print count + 0 }' "$file")

    [ "$count" -eq 1 ] || fail "${file} must contain ${key} exactly once"
    actual=$(awk -F= -v key="$key" '$1 == key { print substr($0, index($0, "=") + 1) }' "$file")
    [ "$actual" = "$expected" ] || fail "${key} changed: expected ${expected}, found ${actual}"
}

line_of() {
    pattern=$1
    file=$2
    line=$(grep -n -F -- "$pattern" "$file" | sed -n '1s/:.*//p')
    [ -n "$line" ] || fail "missing: ${pattern}"
    printf '%s\n' "$line"
}

assert_before() {
    first=$(line_of "$1" "$3")
    second=$(line_of "$2" "$3")
    [ "$first" -lt "$second" ] || fail "$1 must occur before $2"
}

assert_contains() {
    grep -F -- "$1" "$2" >/dev/null || fail "missing: $1"
}

assert_not_contains() {
    if grep -F -- "$1" "$2" >/dev/null; then
        fail "forbidden content: $1"
    fi
}

function_block() {
    name=$1
    file=$2
    awk -v signature="${name}() {" '
        $0 == signature { in_function=1 }
        in_function { print }
        in_function && $0 == "}" { exit }
    ' "$file"
}

assert_block_contains() {
    description=$1
    block=$2
    pattern=$3

    case "$block" in
        *"$pattern"*) ;;
        *) fail "${description} missing control flow: ${pattern}" ;;
    esac
}

OPENRESTY_EXPECTED='OPENRESTY_VERSION=1.31.1.1
OPENRESTY_ARCHIVE=https://openresty.org/download/openresty-1.31.1.1.tar.gz
OPENRESTY_SHA256=65b78baadd3f0984055de89bf13f4a1932e5bfe9c31932037a134ea2b1a0ce42
OPENRESTY_SIGNER_FINGERPRINT=25451EB088460026195BD62CB550E09EA0E98066'

EVENTS_EXPECTED='RESTY_EVENTS_REPOSITORY=https://github.com/Kong/lua-resty-events
RESTY_EVENTS_VERSION=0.3.1
RESTY_EVENTS_COMMIT=bc85295b7c23eda2dbf2b4acec35c93f77b26787
RESTY_EVENTS_ARCHIVE=https://codeload.github.com/Kong/lua-resty-events/tar.gz/bc85295b7c23eda2dbf2b4acec35c93f77b26787
RESTY_EVENTS_SHA256=f399db5ca6fab8bca337389b061ec331374f89b8843cca3abeb0a04d9f0505a2
RESTY_EVENTS_LICENSE=Apache-2.0
RESTY_EVENTS_LICENSE_SHA256=aa9c2870e477001cfa5e3a3dfd3c86c1190cc985a8ed506e9c1e05537e524cdc
RESTY_EVENTS_NGINX_MODULE_TYPE=CORE
RESTY_EVENTS_NGINX_MODULE_NAME=ngx_lua_events_module
RESTY_EVENTS_NGINX_MODULE_SOURCE=src/ngx_lua_events_module.c'

EVENTS_FILES_EXPECTED='aa9c2870e477001cfa5e3a3dfd3c86c1190cc985a8ed506e9c1e05537e524cdc  LICENSE
078c9ec0ad288036930780e1c5817f8b73238f31b191950723e82ea3cf7f1017  config
0c5058102c567e69b10dda5f34fc704411069c11fb8746b36eed82f4d470c6e5  src/ngx_lua_events_module.c
419809cd75356d9eec8b49c7fdd48646940945d9765e299e1219357123b43948  lualib/resty/events/broker.lua
d197ff17d3702f6ec7424ae8f5963b56cc2499dacf0e92813e85b25f576ab30d  lualib/resty/events/callback.lua
0a7f3450a57ecbb647f6aebc6515fec725197c8151aacce0ea4f11cf6dd0f0b5  lualib/resty/events/codec.lua
ae4550a8db1461305f52a85c329f852f09357995184000fc55c84bf19a5f8f8e  lualib/resty/events/compat/init.lua
36e0a2c31542f0e297f97347788cd5bbf015b6f6b5b965e8ed39153346ac55ba  lualib/resty/events/disable_listening.lua
56a6c4d87af8fe768f6fee0af7086743939b56dd55c700c7a0f7a92d76c139cb  lualib/resty/events/frame.lua
68a47c727314e303355a07a18ff69d9e5d037a84cc2cace0eece1f1aba50d312  lualib/resty/events/init.lua
a157ffe97fa0f1901eef93c52c63b7828b9b42b9f711a56002115d2d19dc495f  lualib/resty/events/protocol.lua
95ac06ca0883dbd1dab05400ade419bc35e5ca92a91951fde505bea9a7ed8cae  lualib/resty/events/queue.lua
201c99be705bba54ee85d46b20d425a3f5f4565514702d627c4d6919333f4286  lualib/resty/events/utils.lua
a2a9f62a94616c2e8f18c6f65b6fbf814b0e7b1aee94bb405b7a71c09e4842a5  lualib/resty/events/worker.lua'

assert_file_exact "$OPENRESTY_EXPECTED" "$OPENRESTY_LOCK" "OpenResty lock"
assert_file_exact "$EVENTS_EXPECTED" "$EVENTS_LOCK" "lua-resty-events lock"
assert_file_exact "$EVENTS_FILES_EXPECTED" "$EVENTS_FILES" "lua-resty-events file inventory"

assert_lock_value "$OPENRESTY_LOCK" OPENRESTY_VERSION 1.31.1.1
assert_lock_value "$OPENRESTY_LOCK" OPENRESTY_ARCHIVE https://openresty.org/download/openresty-1.31.1.1.tar.gz
assert_lock_value "$OPENRESTY_LOCK" OPENRESTY_SHA256 65b78baadd3f0984055de89bf13f4a1932e5bfe9c31932037a134ea2b1a0ce42
assert_lock_value "$OPENRESTY_LOCK" OPENRESTY_SIGNER_FINGERPRINT 25451EB088460026195BD62CB550E09EA0E98066
assert_lock_value "$EVENTS_LOCK" RESTY_EVENTS_REPOSITORY https://github.com/Kong/lua-resty-events
assert_lock_value "$EVENTS_LOCK" RESTY_EVENTS_VERSION 0.3.1
assert_lock_value "$EVENTS_LOCK" RESTY_EVENTS_COMMIT bc85295b7c23eda2dbf2b4acec35c93f77b26787
assert_lock_value "$EVENTS_LOCK" RESTY_EVENTS_ARCHIVE https://codeload.github.com/Kong/lua-resty-events/tar.gz/bc85295b7c23eda2dbf2b4acec35c93f77b26787
assert_lock_value "$EVENTS_LOCK" RESTY_EVENTS_SHA256 f399db5ca6fab8bca337389b061ec331374f89b8843cca3abeb0a04d9f0505a2
assert_lock_value "$EVENTS_LOCK" RESTY_EVENTS_LICENSE Apache-2.0
assert_lock_value "$EVENTS_LOCK" RESTY_EVENTS_LICENSE_SHA256 aa9c2870e477001cfa5e3a3dfd3c86c1190cc985a8ed506e9c1e05537e524cdc
assert_lock_value "$EVENTS_LOCK" RESTY_EVENTS_NGINX_MODULE_TYPE CORE
assert_lock_value "$EVENTS_LOCK" RESTY_EVENTS_NGINX_MODULE_NAME ngx_lua_events_module
assert_lock_value "$EVENTS_LOCK" RESTY_EVENTS_NGINX_MODULE_SOURCE src/ngx_lua_events_module.c

assert_contains 'COPY dependencies/openresty.lock \' "$DOCKERFILE"
assert_contains 'dependencies/lua-resty-events.lock \' "$DOCKERFILE"
assert_contains 'dependencies/lua-resty-events.files.sha256 \' "$DOCKERFILE"
assert_contains '${BUILD_DIR}/locks/' "$DOCKERFILE"
assert_contains '. ${BUILD_DIR}/locks/openresty.lock' "$DOCKERFILE"
assert_contains '. ${BUILD_DIR}/locks/lua-resty-events.lock' "$DOCKERFILE"
assert_contains 'test "${OPENRESTY_VER}" = "${OPENRESTY_VERSION}"' "$DOCKERFILE"

assert_before 'echo "${OPENRESTY_SHA256}  openresty-${OPENRESTY_VER}.tar.gz" | sha256sum -c -' \
    'tar -zxf ${BUILD_DIR}/pkg/openresty-${OPENRESTY_VER}.tar.gz' "$DOCKERFILE"
assert_before 'echo "${RESTY_EVENTS_SHA256}  lua-resty-events-${RESTY_EVENTS_COMMIT}.tar.gz" | sha256sum -c -' \
    'tar -zxf ${BUILD_DIR}/pkg/lua-resty-events-${RESTY_EVENTS_COMMIT}.tar.gz' "$DOCKERFILE"

assert_not_contains 'ARG RESTY_EVENTS_' "$DOCKERFILE"
assert_contains '--add-module=${BUILD_DIR}/src/lua-resty-events-${RESTY_EVENTS_COMMIT} \' "$DOCKERFILE"
assert_not_contains '--add-dynamic-module=${BUILD_DIR}/src/lua-resty-events-' "$DOCKERFILE"
assert_contains '# Install lua-resty-events' "$DOCKERFILE"
assert_contains 'RUN set -eux \' "$DOCKERFILE"
assert_contains '&& cd "${src}" \' "$DOCKERFILE"
assert_contains '&& make install LUA_LIB_DIR="${LUA_LIB}" \' "$DOCKERFILE"
assert_not_contains 'install -m 0644 "${src}/lualib/resty/events/' "$DOCKERFILE"
assert_contains 'install -m 0644 "${src}/LICENSE" "${HOME_DIR}/licenses/lua-resty-events/LICENSE"' "$DOCKERFILE"
assert_before 'sha256sum -c ${BUILD_DIR}/locks/lua-resty-events.files.sha256' \
    '&& make install LUA_LIB_DIR="${LUA_LIB}" \' "$DOCKERFILE"
assert_not_contains 'resty/events/*.lua' "$DOCKERFILE"
assert_contains 'COPY --from=builder ${HOME_DIR} ${HOME_DIR}' "$DOCKERFILE"

assert_contains 'rm -rf "${BUILD_DIR}/src/openssl-${OPENSSL_VER}"' "$DOCKERFILE"

[ -f "$IMAGE_CONTRACT" ] || fail "missing image contract: ${IMAGE_CONTRACT}"
[ -f "$INVENTORY_CONTRACT" ] || fail "missing inventory contract: ${INVENTORY_CONTRACT}"

assert_contains 'grep -F -x -c -- '\''nginx version: openresty/1.31.1.1'\''' "$IMAGE_CONTRACT"
assert_contains '$4 == "3.5.6"' "$IMAGE_CONTRACT"
assert_contains 'require_configure_token '\''' "$IMAGE_CONTRACT"
assert_contains 'grep -F -x -c -- '\''nginx version: openresty/1.31.1.1'\''' "$INVENTORY_CONTRACT"
assert_contains '$4 == "3.5.6"' "$INVENTORY_CONTRACT"
assert_contains 'grep -F -x -c -- "$NGX_LUA_MODULE"' "$INVENTORY_CONTRACT"

assert_contains 'reload_log_boundary=' "$IMAGE_CONTRACT"
assert_contains 'reload_marker_line=$(wait_reload_marker "$reload_log_boundary")' "$IMAGE_CONTRACT"
assert_contains 'receiver_pids_after "$receiver" "$reload_marker_line"' "$IMAGE_CONTRACT"
assert_not_contains 'awk -v old="$old_pid" '\''$0 != old { print; exit }'\''' "$IMAGE_CONTRACT"

assert_contains 'docker logs "$container_id"' "$IMAGE_CONTRACT"
assert_contains 'docker port "$container_id"' "$IMAGE_CONTRACT"
assert_contains 'docker exec "$container_id"' "$IMAGE_CONTRACT"
assert_contains 'docker inspect --format '\''{{.State.Pid}}'\'' "$container_id"' "$IMAGE_CONTRACT"
assert_contains 'docker kill --signal HUP "$container_id"' "$IMAGE_CONTRACT"
assert_contains 'docker rm -f "$container_id"' "$IMAGE_CONTRACT"
assert_not_contains 'docker logs "$container"' "$IMAGE_CONTRACT"
assert_not_contains 'docker port "$container"' "$IMAGE_CONTRACT"
assert_not_contains 'docker exec "$container"' "$IMAGE_CONTRACT"
assert_not_contains 'docker inspect --format '\''{{.State.Pid}}'\'' "$container"' "$IMAGE_CONTRACT"
assert_not_contains 'docker kill --signal HUP "$container"' "$IMAGE_CONTRACT"
assert_not_contains 'docker rm -f "$container"' "$IMAGE_CONTRACT"

assert_contains 'container_created=0' "$IMAGE_CONTRACT"
assert_contains 'run_status=0' "$IMAGE_CONTRACT"
assert_contains ') || run_status=$?' "$IMAGE_CONTRACT"
assert_contains 'if [ -n "$container_id" ]; then' "$IMAGE_CONTRACT"
assert_contains 'container_created=1' "$IMAGE_CONTRACT"
assert_before 'container_id=$(docker_run -d \' \
    'if [ -n "$container_id" ]; then' "$IMAGE_CONTRACT"
assert_before 'container_created=1' \
    '[ "$run_status" -eq 0 ] || fail "unable to start fixture container"' "$IMAGE_CONTRACT"
assert_before '[ "$run_status" -eq 0 ] || fail "unable to start fixture container"' \
    'container_started=1' "$IMAGE_CONTRACT"

assert_contains 'for command in docker curl awk sed grep tr wc sleep mkdir mv rm; do' "$IMAGE_CONTRACT"
assert_contains 'tmp_log=${EVIDENCE_LOG}.tmp.$$' "$IMAGE_CONTRACT"
assert_contains 'mv -f "$tmp_log" "$EVIDENCE_LOG"' "$IMAGE_CONTRACT"
assert_contains 'persist_evidence || fail "unable to persist fixture evidence"' "$IMAGE_CONTRACT"
assert_contains 'remove_container || fail "unable to remove fixture container"' "$IMAGE_CONTRACT"
assert_before 'persist_evidence || fail "unable to persist fixture evidence"' \
    "printf 'image-contract: PASS" "$IMAGE_CONTRACT"
assert_before 'remove_container || fail "unable to remove fixture container"' \
    "printf 'image-contract: PASS" "$IMAGE_CONTRACT"
assert_not_contains 'docker logs "$container_id" 2>&1 || true' "$IMAGE_CONTRACT"
assert_not_contains 'docker rm -f "$container_id" >/dev/null 2>&1 || true' "$IMAGE_CONTRACT"

assert_contains 'if state=$(pid_process_state "$pid" 2>/dev/null); then' "$IMAGE_CONTRACT"
assert_contains 'printf "alive\n"' "$IMAGE_CONTRACT"
assert_contains 'printf "gone\n"' "$IMAGE_CONTRACT"
assert_contains 'running=$(docker inspect --format '\''{{.State.Running}}'\'' "$container_id" 2>/dev/null || true)' "$IMAGE_CONTRACT"
assert_not_contains 'if ! docker exec "$container_id" /bin/sh -c "kill -0 ${pid}"' "$IMAGE_CONTRACT"

cleanup_block=$(function_block cleanup "$IMAGE_CONTRACT")
[ -n "$cleanup_block" ] || fail "missing function: cleanup"
assert_block_contains cleanup "$cleanup_block" 'status=$?'
assert_block_contains cleanup "$cleanup_block" 'cleanup_failed=0'
assert_block_contains cleanup "$cleanup_block" 'if ! persist_evidence; then'
assert_block_contains cleanup "$cleanup_block" 'image-contract: cleanup: unable to persist fixture evidence'
assert_block_contains cleanup "$cleanup_block" 'if [ "$container_created" -eq 1 ]; then'
assert_block_contains cleanup "$cleanup_block" 'if ! remove_container; then'
assert_block_contains cleanup "$cleanup_block" 'image-contract: cleanup: unable to remove fixture container %s'
assert_block_contains cleanup "$cleanup_block" 'if [ "$status" -eq 0 ] && [ "$cleanup_failed" -ne 0 ]; then'
assert_block_contains cleanup "$cleanup_block" 'status=1'
assert_block_contains cleanup "$cleanup_block" 'exit "$status"'
cleanup_status_assignments=$(printf '%s\n' "$cleanup_block" | grep -E -c '^[[:space:]]+status=' || true)
[ "$cleanup_status_assignments" -eq 2 ] \
    || fail "cleanup must preserve the original status and only upgrade success to failure"
cleanup_failure_assignments=$(printf '%s\n' "$cleanup_block" | grep -F -c 'cleanup_failed=1' || true)
[ "$cleanup_failure_assignments" -eq 2 ] \
    || fail "cleanup must record both evidence and container-removal failures"

wait_pid_block=$(function_block wait_pid_gone "$IMAGE_CONTRACT")
[ -n "$wait_pid_block" ] || fail "missing function: wait_pid_gone"
assert_block_contains wait_pid_gone "$wait_pid_block" 'if state=$(pid_process_state "$pid" 2>/dev/null); then'
assert_block_contains wait_pid_gone "$wait_pid_block" 'gone) return 0 ;;'
assert_block_contains wait_pid_gone "$wait_pid_block" 'alive) ;;'
assert_block_contains wait_pid_gone "$wait_pid_block" '*) fail "unexpected process state for old PID ${pid}: ${state}" ;;'
assert_block_contains wait_pid_gone "$wait_pid_block" 'running=$(docker inspect --format '\''{{.State.Running}}'\'' "$container_id" 2>/dev/null || true)'
assert_block_contains wait_pid_gone "$wait_pid_block" '|| fail "fixture container stopped while waiting for old PID ${pid}"'
assert_block_contains wait_pid_gone "$wait_pid_block" 'attempt=$((attempt + 1))'
assert_block_contains wait_pid_gone "$wait_pid_block" 'fail "unable to prove old process exited after HUP: ${pid}"'
wait_pid_success_returns=$(printf '%s\n' "$wait_pid_block" | grep -F -c 'return 0' || true)
[ "$wait_pid_success_returns" -eq 1 ] \
    || fail "wait_pid_gone may return success only for the explicit gone state"

pid_state_block=$(function_block pid_process_state "$IMAGE_CONTRACT")
[ -n "$pid_state_block" ] || fail "missing function: pid_process_state"
assert_block_contains pid_process_state "$pid_state_block" 'docker exec "$container_id" /bin/sh -c '\'''
assert_block_contains pid_process_state "$pid_state_block" 'if kill -0 "$1" 2>/dev/null; then'
assert_block_contains pid_process_state "$pid_state_block" 'printf "alive\n"'
assert_block_contains pid_process_state "$pid_state_block" 'printf "gone\n"'

download_count=$(grep -c '&& curl ' "$DOCKERFILE")
[ "$download_count" -eq 15 ] || fail "expected 15 source downloads, found ${download_count}"
if grep '&& curl ' "$DOCKERFILE" \
    | grep -Fv 'curl -fL --retry 5 --retry-all-errors --connect-timeout 20 --max-time 600' \
    >/dev/null; then
    fail "every source download must use the bounded retry policy"
fi

printf 'source-contract: PASS\n'
