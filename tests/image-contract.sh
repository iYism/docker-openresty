#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FIXTURE=${ROOT}/tests/fixtures/events/nginx.conf
EVENTS_FILES=${ROOT}/dependencies/lua-resty-events.files.sha256
IMAGE=${1:-}
platform=${2:-}
EVIDENCE_DIR=${EVIDENCE_DIR:-/tmp/openresty-events-evidence}
platform_slug=$(printf '%s' "${platform:-native}" | tr '/:' '--')
EVIDENCE_LOG=${EVIDENCE_DIR}/events-${platform_slug}.log
container=openresty-events-contract-$$
container_id=
container_started=0
old_worker_0=
old_worker_1=
old_privileged=
new_worker_0=
new_worker_1=
new_privileged=

fail() {
    printf 'image-contract: FAIL: %s\n' "$*" >&2
    exit 1
}

docker_run() {
    if [ -n "$platform" ]; then
        docker run --platform "$platform" "$@"
    else
        docker run "$@"
    fi
}

cleanup() {
    status=$?
    trap - EXIT
    mkdir -p "$EVIDENCE_DIR"
    if [ "$container_started" -eq 1 ]; then
        {
            docker logs "$container_id" 2>&1 || true
            printf '\nevents-contract summary old_worker_0=%s old_worker_1=%s old_privileged=%s\n' \
                "$old_worker_0" "$old_worker_1" "$old_privileged"
            printf 'events-contract summary new_worker_0=%s new_worker_1=%s new_privileged=%s\n' \
                "$new_worker_0" "$new_worker_1" "$new_privileged"
        } >"$EVIDENCE_LOG"
        docker rm -f "$container_id" >/dev/null 2>&1 || true
    fi
    exit "$status"
}

interrupted() {
    fail "interrupted by $1"
}

trap cleanup EXIT
trap 'interrupted HUP' HUP
trap 'interrupted INT' INT
trap 'interrupted TERM' TERM

[ -n "$IMAGE" ] || fail "usage: $0 IMAGE [PLATFORM]"
[ -f "$FIXTURE" ] || fail "missing fixture: $FIXTURE"
[ -f "$EVENTS_FILES" ] || fail "missing reviewed events inventory: $EVENTS_FILES"

for command in docker curl awk sed grep tr; do
    command -v "$command" >/dev/null 2>&1 || fail "required command not found: $command"
done

nginx_v=$(docker_run --rm --entrypoint /bin/sh "$IMAGE" -c '/usr/sbin/nginx -V 2>&1') \
    || fail "unable to execute nginx -V"

nginx_version_count=$(printf '%s\n' "$nginx_v" \
    | grep -F -x -c -- 'nginx version: openresty/1.31.1.1' || true)
[ "$nginx_version_count" -eq 1 ] \
    || fail "nginx version line count is ${nginx_version_count}, expected exact OpenResty 1.31.1.1 once"

openssl_version_count=$(printf '%s\n' "$nginx_v" | awk '
    $1 == "built" && $2 == "with" && $3 == "OpenSSL" && $4 == "3.5.6" { count++ }
    END { print count + 0 }
')
[ "$openssl_version_count" -eq 1 ] \
    || fail "OpenSSL version token count is ${openssl_version_count}, expected 3.5.6 once"

configure_line_count=$(printf '%s\n' "$nginx_v" | grep -c '^configure arguments: ' || true)
[ "$configure_line_count" -eq 1 ] \
    || fail "configure arguments line count is ${configure_line_count}, expected 1"
configure_args=$(printf '%s\n' "$nginx_v" | sed -n 's/^configure arguments: //p')

require_configure_token() {
    token_count=$(printf '%s\n' "$configure_args" | tr ' ' '\n' | grep -F -x -c -- "$1" || true)
    [ "$token_count" -eq 1 ] || fail "configure token count for $1 is ${token_count}, expected 1"
}

require_configure_token '--add-module=../ngx_lua-0.10.31rc5'
require_configure_token '--with-http_v2_module'
require_configure_token '--with-http_v3_module'
require_configure_token '--add-module=/build/openresty/src/ngx_http_geoip2_module-3.4'
require_configure_token '--add-module=/build/openresty/src/ngx_brotli-master'

events_module=--add-module=/build/openresty/src/lua-resty-events-bc85295b7c23eda2dbf2b4acec35c93f77b26787
require_configure_token "$events_module"
if printf '%s\n' "$nginx_v" | grep -F -- '--add-dynamic-module=/build/openresty/src/lua-resty-events-' >/dev/null; then
    fail "lua-resty-events must not be a dynamic module"
fi

docker_run --rm \
    -v "${EVENTS_FILES}:/contract/events.sha256:ro" \
    --entrypoint /bin/sh "$IMAGE" -eu -c '
        test ! -e /build
        for command in gcc cc clang make cmake; do
            if command -v "$command" >/dev/null 2>&1; then
                echo "unexpected build tool: $command" >&2
                exit 1
            fi
        done
        if find / -xdev -type f -name "*events*.so" -print 2>/dev/null | grep .; then
            echo "unexpected events shared object" >&2
            exit 1
        fi
        if grep -R -E "load_module.*events" /etc/nginx /opt/openresty 2>/dev/null; then
            echo "unexpected events load_module directive" >&2
            exit 1
        fi
        if find / -xdev -type f -name "lua-resty-events-*.tar.gz" -print 2>/dev/null | grep .; then
            echo "unexpected events source archive" >&2
            exit 1
        fi

        count=0
        while read -r expected path; do
            case "$path" in
                lualib/resty/events/*)
                    actual=$(sha256sum "/opt/openresty/$path" | awk '\''{print $1}'\'')
                    test "$actual" = "$expected" || {
                        echo "hash mismatch: $path" >&2
                        exit 1
                    }
                    count=$((count + 1))
                    ;;
            esac
        done </contract/events.sha256
        test "$count" -eq 11

        expected_paths=$(awk '\''$2 ~ /^lualib\/resty\/events\// { sub(/^lualib\//, "", $2); print $2 }'\'' /contract/events.sha256 | sort)
        actual_paths=$(find /opt/openresty/lualib/resty/events -type f -print | sed "s#^/opt/openresty/lualib/##" | sort)
        test "$actual_paths" = "$expected_paths" || {
            echo "events Lua file inventory differs" >&2
            printf "expected:\n%s\nactual:\n%s\n" "$expected_paths" "$actual_paths" >&2
            exit 1
        }

        expected_license=aa9c2870e477001cfa5e3a3dfd3c86c1190cc985a8ed506e9c1e05537e524cdc
        actual_license=$(sha256sum /opt/openresty/licenses/lua-resty-events/LICENSE | awk '\''{print $1}'\'')
        test "$actual_license" = "$expected_license"
    ' || fail "final-image filesystem contract failed"

container_id=$(docker_run -d \
    --name "$container" \
    -p 127.0.0.1::8080 \
    -v "${FIXTURE}:/etc/nginx/nginx.conf:ro" \
    --entrypoint /usr/sbin/nginx \
    "$IMAGE" -c /etc/nginx/nginx.conf) || fail "unable to start fixture container"
[ -n "$container_id" ] || fail "docker did not return a container id"
container_started=1

host_port=
attempt=0
while [ "$attempt" -lt 100 ]; do
    host_port=$(docker port "$container_id" 8080/tcp 2>/dev/null | sed -n '1s/.*://p')
    [ -n "$host_port" ] && break
    attempt=$((attempt + 1))
    sleep 0.1
done
[ -n "$host_port" ] || fail "unable to discover fixture HTTP port"
base_url=http://127.0.0.1:${host_port}

wait_body() {
    path=$1
    expected=$2
    attempt=0
    while [ "$attempt" -lt 150 ]; do
        body=$(curl -fsS --max-time 2 "${base_url}${path}" 2>/dev/null || true)
        if [ "$body" = "$expected" ]; then
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 0.1
    done
    fail "${path} did not return ${expected}"
}

logs_after_line() {
    boundary=$1
    docker logs "$container_id" 2>&1 | sed -n "$((boundary + 1)),\$p"
}

receiver_pids_after() {
    receiver=$1
    boundary=$2
    logs_after_line "$boundary" \
        | sed -n "s/.*events-contract initialized receiver=${receiver} pid=\([0-9][0-9]*\).*/\1/p" \
        | awk '!seen[$0]++'
}

wait_initial_pid() {
    receiver=$1
    attempt=0
    while [ "$attempt" -lt 150 ]; do
        pid=$(receiver_pids_after "$receiver" 0 | sed -n '1p')
        if [ -n "$pid" ]; then
            printf '%s\n' "$pid"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 0.1
    done
    fail "missing initial PID for ${receiver}"
}

wait_reload_marker() {
    boundary=$1
    attempt=0
    while [ "$attempt" -lt 200 ]; do
        marker_offset=$(logs_after_line "$boundary" \
            | grep -n -F 'signal 1 (SIGHUP) received, reconfiguring' \
            | sed -n '1s/:.*//p')
        if [ -n "$marker_offset" ]; then
            printf '%s\n' "$((boundary + marker_offset))"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 0.1
    done
    fail "missing post-HUP master reconfiguring marker"
}

wait_new_pid() {
    receiver=$1
    reload_marker_line=$2
    attempt=0
    while [ "$attempt" -lt 200 ]; do
        pid=$(receiver_pids_after "$receiver" "$reload_marker_line" | sed -n '1p')
        if [ -n "$pid" ]; then
            printf '%s\n' "$pid"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 0.1
    done
    fail "missing replacement PID for ${receiver}"
}

assert_distinct() {
    [ "$1" != "$2" ] && [ "$1" != "$3" ] && [ "$2" != "$3" ] \
        || fail "receiver PIDs must be distinct: $1 $2 $3"
}

wait_delivery() {
    event=$1
    receiver=$2
    pid=$3
    pattern="events-contract event=${event} receiver=${receiver} pid=${pid} data=${event}"
    attempt=0
    while [ "$attempt" -lt 150 ]; do
        if docker logs "$container_id" 2>&1 | grep -F -- "$pattern" >/dev/null; then
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 0.1
    done
    fail "missing delivery: ${pattern}"
}

reject_delivery() {
    event=$1
    receiver=$2
    pid=$3
    pattern="events-contract event=${event} receiver=${receiver} pid=${pid} data=${event}"
    if docker logs "$container_id" 2>&1 | grep -F -- "$pattern" >/dev/null; then
        fail "stale-generation delivery observed: ${pattern}"
    fi
}

wait_pid_gone() {
    pid=$1
    attempt=0
    while [ "$attempt" -lt 200 ]; do
        if ! docker exec "$container_id" /bin/sh -c "kill -0 ${pid}" >/dev/null 2>&1; then
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 0.1
    done
    fail "old process still alive after HUP: ${pid}"
}

wait_broker_pid() {
    pid=$1
    attempt=0
    while [ "$attempt" -lt 150 ]; do
        body=$(curl -fsS --max-time 2 "${base_url}/broker-ready" 2>/dev/null || true)
        if [ "$body" = "broker-ready pid=${pid}" ]; then
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 0.1
    done
    fail "broker worker ${pid} did not become ready"
}

wait_body /ready ready
wait_body /modules modules-ok

old_worker_0=$(wait_initial_pid worker-0)
old_worker_1=$(wait_initial_pid worker-1)
old_privileged=$(wait_initial_pid privileged)
assert_distinct "$old_worker_0" "$old_worker_1" "$old_privileged"
wait_broker_pid "$old_worker_0"
master_pid=$(docker inspect --format '{{.State.Pid}}' "$container_id")

wait_body '/publish?id=before-hup' published-before-hup
wait_delivery before-hup worker-0 "$old_worker_0"
wait_delivery before-hup worker-1 "$old_worker_1"
wait_delivery before-hup privileged "$old_privileged"

reload_log_boundary=$(docker logs "$container_id" 2>&1 | wc -l | tr -d ' ')
docker kill --signal HUP "$container_id" >/dev/null
reload_marker_line=$(wait_reload_marker "$reload_log_boundary")

new_worker_0=$(wait_new_pid worker-0 "$reload_marker_line")
new_worker_1=$(wait_new_pid worker-1 "$reload_marker_line")
new_privileged=$(wait_new_pid privileged "$reload_marker_line")
assert_distinct "$new_worker_0" "$new_worker_1" "$new_privileged"
[ "$new_worker_0" != "$old_worker_0" ] || fail "worker-0 PID did not change"
[ "$new_worker_1" != "$old_worker_1" ] || fail "worker-1 PID did not change"
[ "$new_privileged" != "$old_privileged" ] || fail "privileged-agent PID did not change"

wait_pid_gone "$old_worker_0"
wait_pid_gone "$old_worker_1"
wait_pid_gone "$old_privileged"
[ "$(docker inspect --format '{{.State.Pid}}' "$container_id")" = "$master_pid" ] \
    || fail "master PID changed across HUP"
wait_broker_pid "$new_worker_0"

wait_body '/publish?id=after-hup' published-after-hup
wait_delivery after-hup worker-0 "$new_worker_0"
wait_delivery after-hup worker-1 "$new_worker_1"
wait_delivery after-hup privileged "$new_privileged"
reject_delivery after-hup worker-0 "$old_worker_0"
reject_delivery after-hup worker-1 "$old_worker_1"
reject_delivery after-hup privileged "$old_privileged"

logs=$(docker logs "$container_id" 2>&1)
if printf '%s\n' "$logs" | grep -E '\[(emerg|alert|crit)\]|events-contract (publish|init|privileged-agent init) failed|publish failed' >/dev/null; then
    fail "fixture logs contain a fatal contract error"
fi

printf 'image-contract: PASS image=%s platform=%s old=%s,%s,%s new=%s,%s,%s evidence=%s\n' \
    "$IMAGE" "${platform:-native}" \
    "$old_worker_0" "$old_worker_1" "$old_privileged" \
    "$new_worker_0" "$new_worker_1" "$new_privileged" "$EVIDENCE_LOG"
