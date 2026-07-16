#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DOCKERFILE=${ROOT}/Dockerfile
OPENRESTY_LOCK=${ROOT}/dependencies/openresty.lock
EVENTS_LOCK=${ROOT}/dependencies/lua-resty-events.lock
EVENTS_FILES=${ROOT}/dependencies/lua-resty-events.files.sha256

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
419809989b36e088cc262370d786979cd226e4e47a18531499f61dd84c6eb19f  lualib/resty/events/broker.lua
d197ff6341b73df53fd88b0f0ec02c75684b257bb24f90d35012d8f0bfd06efd  lualib/resty/events/callback.lua
0a7f47fb2b75b0316fa8b509ebd45809ff63c565b8770ce0f908705b71ca2f94  lualib/resty/events/codec.lua
ae455426fc755d828e5fab9d62817164b5c5c199ba6b89b4dcdf4285085bcddd  lualib/resty/events/compat/init.lua
36e04852ab95e3b2819f1284a419ca7e3d227b12554ee753a02f5be0a7171766  lualib/resty/events/disable_listening.lua
56a61213554cabd4ed7f3ecf99234cf5a2eef80768d32aa0f66884d633e544a9  lualib/resty/events/frame.lua
68a47d7f0470dcb41b06133e11cb13cde9796cbb10640c6d577d584bd44c4c84  lualib/resty/events/init.lua
a1575e0410c8e58b74639b44bbfff81289e8d2084a66a2a095fa74aa2ceb58e6  lualib/resty/events/protocol.lua
95ac57abf952524c8a43d187bdcc933c589f7ea6c8e4ca1b88a702792e27c232  lualib/resty/events/queue.lua
201c9d7afb5533dde344a46f818e94f5e1540894e0aa08381898ac1c01720c55  lualib/resty/events/utils.lua
a2a9fbc8fe5cab970eebf679d7bc6cf61b23a69270466b80f1b18fb05f590785  lualib/resty/events/worker.lua'

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
assert_contains 'for file in broker.lua callback.lua codec.lua disable_listening.lua frame.lua init.lua protocol.lua queue.lua utils.lua worker.lua; do \' "$DOCKERFILE"
assert_contains 'install -m 0644 ${src}/lualib/resty/events/${file} ${LUA_LIB}/resty/events/${file}; \' "$DOCKERFILE"
assert_contains 'install -m 0644 ${src}/lualib/resty/events/compat/init.lua ${LUA_LIB}/resty/events/compat/init.lua \' "$DOCKERFILE"
assert_contains 'install -m 0644 ${src}/LICENSE ${HOME_DIR}/licenses/lua-resty-events/LICENSE' "$DOCKERFILE"
assert_not_contains 'resty/events/*.lua' "$DOCKERFILE"
assert_contains 'COPY --from=builder ${HOME_DIR} ${HOME_DIR}' "$DOCKERFILE"

printf 'source-contract: PASS\n'
