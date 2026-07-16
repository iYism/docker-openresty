# OpenResty Events-Capable Base Image Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the existing `sungyism/openresty` OpenResty `1.31.1.1` image with the pinned Kong `lua-resty-events` `0.3.1` CORE module and Lua library, verify amd64/arm64 runtime behavior, and hand Ngatex one immutable multi-architecture digest.

**Architecture:** Keep the repository's existing three-stage Dockerfile and compile the events C module into the same OpenResty build with one additional `--add-module` input. Install the Lua half from the same verified archive, then prove worker broadcast, privileged-agent delivery, broker replacement after HUP, and preservation of the existing image inventory before promoting a digest.

**Tech Stack:** Docker multi-stage builds, OpenResty `1.31.1.1`, OpenSSL `3.5.6`, Kong `lua-resty-events` `0.3.1`, POSIX shell, Docker Buildx, GitHub Actions, Docker Hub OCI indexes.

---

## Approval boundary and repository isolation

This is the repository-local prerequisite required by the approved Ngatex Gateway Runtime Phase 2 roadmap at Ngatex commit `d77b8096f281a3ed47e5ce4b237e0c7aa7dfd430`.

- Implementation starts only after this plan is reviewed, as required by the roadmap's **Execution Approval and Resume Checkpoint**.
- Work occurs only in the dedicated `docker-openresty` branch/worktree created from `74c291a27664a1c27232d4020de7ba52e7c17cc0`.
- Do not edit, clean, reset, delete, or reuse the user's original `ngatex` or `docker-openresty` working directories.
- Do not push any intermediate commit while the old workflow can publish from pull requests. The CI safety change in Task 3 must be present and all local gates must pass before the first push.
- Local development and runtime verification on the Apple Silicon host build only the native `linux/arm64` image. Do not perform a local multi-platform build or emulate amd64; the required amd64 evidence is produced only by the CI matrix before publication.
- This plan does not edit Ngatex. Ngatex resumes at Phase 2A Task 1 only after the immutable image digest and evidence are accepted.

## Reviewed immutable inputs

### OpenResty

- Version: `1.31.1.1`
- Archive: `https://openresty.org/download/openresty-1.31.1.1.tar.gz`
- SHA-256: `65b78baadd3f0984055de89bf13f4a1932e5bfe9c31932037a134ea2b1a0ce42`
- Release-signing fingerprint checked during planning: `25451EB088460026195BD62CB550E09EA0E98066`

### lua-resty-events

- Version: `0.3.1`
- Repository: `https://github.com/Kong/lua-resty-events`
- Commit: `bc85295b7c23eda2dbf2b4acec35c93f77b26787`
- Archive: `https://codeload.github.com/Kong/lua-resty-events/tar.gz/bc85295b7c23eda2dbf2b4acec35c93f77b26787`
- SHA-256: `f399db5ca6fab8bca337389b061ec331374f89b8843cca3abeb0a04d9f0505a2`
- License: Apache-2.0; reviewed `LICENSE` SHA-256 `aa9c2870e477001cfa5e3a3dfd3c86c1190cc985a8ed506e9c1e05537e524cdc`
- Nginx declaration: `CORE`, name `ngx_lua_events_module`, source `src/ngx_lua_events_module.c`

The checksums above were independently downloaded and verified while writing this plan. A mismatch stops execution; do not change a reviewed checksum merely to make a build pass.

## Frozen compatibility baseline

Compare the new image against this existing immutable image on both platforms:

```text
sungyism/openresty:1.31.1.1@sha256:3fca0dac0d8d073be2980170a4eda04beb7b4721f6a2ecc65c0a0921ee2a3016
```

The replacement must retain:

- OpenResty `1.31.1.1`, OpenSSL `3.5.6`, ngx_lua `0.10.31rc5`, Lua cJSON `2.1.0.11`, and an executable `resty` CLI.
- HTTP/2, HTTP/3, GeoIP2, Brotli, and every existing configure argument.
- Every existing runtime Lua file.
- The current effective runtime user/config, entrypoint, command, exposed ports, and stop signal.

The only allowed inventory additions are:

- one static configure input for `lua-resty-events-bc85295b7c23eda2dbf2b4acec35c93f77b26787`;
- the reviewed 11 Lua files under `/opt/openresty/lualib/resty/events/`;
- `/opt/openresty/licenses/lua-resty-events/LICENSE`.

The current published base does **not** contain `resty.http`; this plan must preserve that absence. Ngatex Phase 2A installs its separately approved Kong `lua-resty-http` version later.

## Scope

In scope:

- exact OpenResty and events source/checksum/file/license provenance;
- static CORE-module linking and matching Lua installation;
- baseline inventory preservation;
- real `ngx_lua` two-worker, privileged-agent, and generation-aware HUP tests;
- amd64 and arm64 verification before digest promotion;
- main-only publication and immutable digest evidence;
- README and maintainer-document synchronization.

Out of scope:

- adding healthcheck, timer, ctxdump, JSON Schema, or any other Ngatex dependency;
- refactoring the OpenResty build recipe or fixing unrelated floating inputs;
- changing the legacy ineffective `RESTY_HTTP_VER=0.2.3` source step;
- publishing Ngatex code or starting Ngatex Phase 2A before digest acceptance.

Pre-existing floating inputs such as Rocky tags, `NGX_BROTLI_VER=master`, the OpenResty patch URL, unchecksummed unrelated archives, and DNF repositories remain explicit residual risks. The new OpenResty and events inputs are not covered by that exception.

All existing source download URLs and versions stay unchanged, but the clean rebuild may mechanically add the same bounded `curl -fL --retry 5 --retry-all-errors --connect-timeout 20 --max-time 600` transport policy to them. This is reliability hardening required to complete a from-scratch build, not a dependency upgrade or provenance exception.

## File map

| Path | Responsibility |
| --- | --- |
| `dependencies/openresty.lock` | Exact official OpenResty version, URL, SHA-256, and reviewed signing fingerprint |
| `dependencies/lua-resty-events.lock` | Exact events source, archive, checksum, module identity, and license identity |
| `dependencies/lua-resty-events.files.sha256` | Closed upstream file inventory and per-file hashes |
| `Dockerfile` | Verify both archives, statically link the CORE module, and install exact Lua/license files |
| `tests/source-contract.sh` | Offline provenance, checksum-order, static-link, and allowlist contract |
| `tests/events-archive-contract.sh` | Verify the locked archive bytes directly against the per-file manifest |
| `tests/fixtures/events/nginx.conf` | Real two-worker and privileged-agent runtime fixture |
| `tests/image-contract.sh` | Runtime behavior, generation-aware HUP, and final-image content checks |
| `tests/inventory-contract.sh` | Full baseline/new configure, Lua, and image-config comparison |
| `tests/workflow-contract.sh` | Focused shell assertions for CI isolation, job ordering, immutable inputs, and promotion guards |
| `.github/workflows/docker-image.yml` | PR verification and main-only digest publication |
| `README.md` | Consumer-facing component and immutable-digest documentation |
| `CLAUDE.md` | Maintainer build/test/release commands and corrected runtime facts |

### Task 1: Lock source provenance and add the static module

**Files:**

- Create: `dependencies/openresty.lock`
- Create: `dependencies/lua-resty-events.lock`
- Create: `dependencies/lua-resty-events.files.sha256`
- Create: `tests/source-contract.sh`
- Create: `tests/events-archive-contract.sh`
- Modify: `Dockerfile`

- [ ] **Step 1: Write the exact lock files**

Create `dependencies/openresty.lock`:

```text
OPENRESTY_VERSION=1.31.1.1
OPENRESTY_ARCHIVE=https://openresty.org/download/openresty-1.31.1.1.tar.gz
OPENRESTY_SHA256=65b78baadd3f0984055de89bf13f4a1932e5bfe9c31932037a134ea2b1a0ce42
OPENRESTY_SIGNER_FINGERPRINT=25451EB088460026195BD62CB550E09EA0E98066
```

Create `dependencies/lua-resty-events.lock`:

```text
RESTY_EVENTS_REPOSITORY=https://github.com/Kong/lua-resty-events
RESTY_EVENTS_VERSION=0.3.1
RESTY_EVENTS_COMMIT=bc85295b7c23eda2dbf2b4acec35c93f77b26787
RESTY_EVENTS_ARCHIVE=https://codeload.github.com/Kong/lua-resty-events/tar.gz/bc85295b7c23eda2dbf2b4acec35c93f77b26787
RESTY_EVENTS_SHA256=f399db5ca6fab8bca337389b061ec331374f89b8843cca3abeb0a04d9f0505a2
RESTY_EVENTS_LICENSE=Apache-2.0
RESTY_EVENTS_LICENSE_SHA256=aa9c2870e477001cfa5e3a3dfd3c86c1190cc985a8ed506e9c1e05537e524cdc
RESTY_EVENTS_NGINX_MODULE_TYPE=CORE
RESTY_EVENTS_NGINX_MODULE_NAME=ngx_lua_events_module
RESTY_EVENTS_NGINX_MODULE_SOURCE=src/ngx_lua_events_module.c
```

Create `dependencies/lua-resty-events.files.sha256` exactly:

```text
aa9c2870e477001cfa5e3a3dfd3c86c1190cc985a8ed506e9c1e05537e524cdc  LICENSE
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
a2a9f62a94616c2e8f18c6f65b6fbf814b0e7b1aee94bb405b7a71c09e4842a5  lualib/resty/events/worker.lua
```

- [ ] **Step 2: Write the failing offline source contract**

Create executable `tests/source-contract.sh` and `tests/events-archive-contract.sh`. The archive contract accepts the downloaded tarball path, verifies its locked SHA-256, extracts it into a temporary directory, and runs the reviewed per-file manifest against those real bytes. The source contract must:

1. parse every key above and reject missing, duplicate, or changed values;
2. compare `lua-resty-events.files.sha256` byte-for-byte with the 14-line closed inventory above;
3. require Dockerfile to copy the locks into the downloader stage;
4. require OpenResty SHA verification to occur before its `tar -zxf` line;
5. require events SHA verification to occur before its `tar -zxf` line;
6. reject any `ARG RESTY_EVENTS_` override;
7. require `--add-module=${BUILD_DIR}/src/lua-resty-events-${RESTY_EVENTS_COMMIT}` and reject `--add-dynamic-module` for events;
8. require the pinned upstream Makefile installer, followed by an explicit license install;
9. reject glob installation for `resty/events/*.lua`;
10. require the final image to inherit the installed license through the existing `${HOME_DIR}` copy.

Use this ordering helper rather than a comment-only grep:

```sh
line_of() {
    pattern=$1
    file=$2
    line=$(grep -n -F -- "$pattern" "$file" | sed -n '1s/:.*//p')
    [ -n "$line" ] || fail "missing: $pattern"
    printf '%s\n' "$line"
}

assert_before() {
    first=$(line_of "$1" "$3")
    second=$(line_of "$2" "$3")
    [ "$first" -lt "$second" ] || fail "$1 must occur before $2"
}
```

Run:

```bash
sh -n tests/source-contract.sh
tests/source-contract.sh
```

Expected: FAIL because Dockerfile has not copied or enforced the locks and does not contain the events module.

- [ ] **Step 3: Add the minimal Dockerfile changes**

Keep `ARG OPENRESTY_VER=1.31.1.1`; do not add events build arguments. In the downloader stage, copy the three lock files, source the two key/value locks, assert the existing OpenResty ARG matches the reviewed lock, and verify both archives before extraction:

```dockerfile
COPY dependencies/openresty.lock \
     dependencies/lua-resty-events.lock \
     dependencies/lua-resty-events.files.sha256 \
     ${BUILD_DIR}/locks/

RUN set -eux \
    && . ${BUILD_DIR}/locks/openresty.lock \
    && . ${BUILD_DIR}/locks/lua-resty-events.lock \
    && test "${OPENRESTY_VER}" = "${OPENRESTY_VERSION}" \
    && mkdir -p ${BUILD_DIR}/pkg ${BUILD_DIR}/src \
    && cd ${BUILD_DIR}/pkg \
    && curl -fL --retry 5 --retry-all-errors --connect-timeout 20 --max-time 600 \
         -o openresty-${OPENRESTY_VER}.tar.gz "${OPENRESTY_ARCHIVE}" \
    && echo "${OPENRESTY_SHA256}  openresty-${OPENRESTY_VER}.tar.gz" | sha256sum -c - \
    # retain the existing unrelated downloads here, then append: \
    && curl -fL --retry 5 --retry-all-errors --connect-timeout 20 --max-time 600 \
         -o lua-resty-events-${RESTY_EVENTS_COMMIT}.tar.gz "${RESTY_EVENTS_ARCHIVE}" \
    && echo "${RESTY_EVENTS_SHA256}  lua-resty-events-${RESTY_EVENTS_COMMIT}.tar.gz" | sha256sum -c -
```

When editing the existing download chain, add the required trailing `\` to its current last command before appending the events download.

In the builder, source the copied events lock, extract the archive, and verify the closed upstream file inventory from the extraction root:

```dockerfile
RUN set -x \
    && . ${BUILD_DIR}/locks/lua-resty-events.lock \
    && cd ${BUILD_DIR}/src \
    && tar -zxf ${BUILD_DIR}/pkg/lua-resty-events-${RESTY_EVENTS_COMMIT}.tar.gz \
    && cd lua-resty-events-${RESTY_EVENTS_COMMIT} \
    && sha256sum -c ${BUILD_DIR}/locks/lua-resty-events.files.sha256
```

Add this one configure argument next to the existing static modules:

```dockerfile
--add-module=${BUILD_DIR}/src/lua-resty-events-${RESTY_EVENTS_COMMIT} \
```

Use the pinned upstream commit's official one-command Makefile installer. The
archive hash fixes the complete source tree, while the per-file manifest verifies
the runtime files before this target is invoked:

```dockerfile
RUN set -eux \
    && . ${BUILD_DIR}/locks/lua-resty-events.lock \
    && src=${BUILD_DIR}/src/lua-resty-events-${RESTY_EVENTS_COMMIT} \
    && install -d ${HOME_DIR}/licenses/lua-resty-events \
    && cd "${src}" \
    && make install LUA_LIB_DIR="${LUA_LIB}" \
    && install -m 0644 "${src}/LICENSE" "${HOME_DIR}/licenses/lua-resty-events/LICENSE"
```

Do not use LuaRocks, a branch URL, a second C-source copy, or a dynamic module.

- [ ] **Step 4: Run the source contract green**

```bash
sh -n tests/source-contract.sh tests/events-archive-contract.sh
tests/source-contract.sh
tests/events-archive-contract.sh /path/to/the/downloaded/pinned/events-archive.tar.gz
git diff --check
```

Expected: PASS.

- [ ] **Step 5: Commit the provenance/build slice locally**

```bash
git add dependencies Dockerfile tests/source-contract.sh tests/events-archive-contract.sh
git commit -m "build: add pinned lua-resty-events core module"
```

Do not push this commit yet.

### Task 2: Prove the real image and preserve the baseline

**Files:**

- Create: `tests/fixtures/events/nginx.conf`
- Create: `tests/image-contract.sh`
- Create: `tests/inventory-contract.sh`

- [ ] **Step 1: Write a real ngx_lua fixture**

Create `tests/fixtures/events/nginx.conf` with:

- `worker_processes 2`, master mode, foreground execution, and logs to stderr;
- `ngx.process.enable_privileged_agent(100)` in `init_by_lua_block`;
- one `resty.events` instance with `broker_id = 0`, a Unix socket, and `enable_privileged_agent = true`;
- `init_worker_by_lua_block` that calls `init_worker()`, subscribes, and logs `process_type`, worker id, and `ngx.worker.pid()`;
- a Unix-socket server that calls `events:run()`;
- `/ready`, `/broker-ready`, `/modules`, and `/publish?id=...` HTTP locations.

The module endpoint must execute inside Nginx and assert:

```lua
local events = require("resty.events")
assert(events._VERSION == "0.3.1")
assert(require("resty.events.protocol"))
assert(require("resty.events.queue"))
assert(require("resty.expr.v1"))
assert(require("resty.ipmatcher"))
assert(require("resty.radixtree"))
local ok = pcall(require, "resty.http")
assert(not ok, "resty.http must remain absent from the base image")
ngx.say("modules-ok")
```

The subscriber log format must be stable and generation-aware:

```lua
local process = require("ngx.process")
local process_type = process.type()
local worker_id = ngx.worker.id()
local pid = ngx.worker.pid()
local receiver = process_type == "privileged agent"
    and "privileged"
    or "worker-" .. tostring(worker_id)

events:subscribe("contract", "*", function(data, event)
    ngx.log(ngx.WARN, "events-contract event=", event,
        " receiver=", receiver, " pid=", pid, " data=", data)
end)
ngx.log(ngx.WARN, "events-contract initialized receiver=", receiver, " pid=", pid)
```

`/broker-ready` returns 200 only from worker id 0. This, combined with PID replacement and post-HUP delivery, proves the new broker generation is active.

- [ ] **Step 2: Write the failing real-image contract**

Create executable `tests/image-contract.sh IMAGE [PLATFORM]`. Use a helper that branches explicitly instead of splitting an unquoted argument string:

```sh
docker_run() {
    if [ -n "$platform" ]; then
        docker run --platform "$platform" "$@"
    else
        docker run "$@"
    fi
}
```

The script must:

1. register `trap cleanup EXIT` and separate HUP/INT/TERM traps that exit nonzero;
2. write successful container logs to `${EVIDENCE_DIR:-/tmp/openresty-events-evidence}/events-${platform_slug}.log` before cleanup;
3. assert OpenResty/OpenSSL/ngx_lua/H2/H3/GeoIP2/Brotli and the exact events configure path in `nginx -V`;
4. assert no events `.so`, no events `load_module`, no `/build`, no compiler, and no source archive in the final image;
5. compare the final 11 Lua files and their hashes against the reviewed manifest;
6. compare the installed license hash with `aa9c2870...24cdc`;
7. start the fixture and require `/modules` to return `modules-ok`;
8. capture the first worker-0, worker-1, and privileged-agent PIDs from initialization logs;
9. publish `before-hup` and require delivery from all three captured PIDs;
10. send HUP to the container;
11. capture a second, different PID for each receiver;
12. wait until `docker exec ... kill -0 OLD_PID` fails for all old PIDs;
13. require `/broker-ready` after old worker 0 exits;
14. publish `after-hup` and require delivery from all three new PIDs;
15. reject `emerg`, `alert`, `crit`, `publish failed`, or init failure logs.

Do not run `require("resty.events")` under bare LuaJIT; that module requires the real `ngx` API.

Build the unchanged/base-red target before applying Task 1, or temporarily test the frozen baseline digest:

```bash
tests/image-contract.sh \
  sungyism/openresty:1.31.1.1@sha256:3fca0dac0d8d073be2980170a4eda04beb7b4721f6a2ecc65c0a0921ee2a3016
```

Expected: FAIL because the events configure input and Lua files are absent.

- [ ] **Step 3: Write the baseline inventory contract**

Create executable `tests/inventory-contract.sh NEW_IMAGE [PLATFORM]`. Freeze the baseline reference inside the script. For the selected platform it must:

1. pull baseline and new images by the requested platform;
2. capture `nginx -V` from both;
3. remove only the exact events `--add-module=/build/openresty/src/lua-resty-events-bc85295b7c23eda2dbf2b4acec35c93f77b26787` token from the new configure string;
4. require the normalized configure strings to be byte-equal;
5. capture every file path below `/opt/openresty/lualib` in sorted order;
6. remove only the exact 11 `resty/events/...` additions from the new list;
7. require the remaining Lua inventories to be byte-equal;
8. assert exact OpenResty/OpenSSL/ngx_lua/cJSON versions and executable `resty` CLI;
9. compare image Config fields `User`, `Entrypoint`, `Cmd`, `ExposedPorts`, and `StopSignal` as canonical JSON;
10. assert the inspected OS/architecture equals the requested platform.

Use temporary files and `diff -u`; preserve the diff in `${EVIDENCE_DIR}` on failure.

- [ ] **Step 4: Build and run the host-architecture gates**

```bash
sh -n tests/source-contract.sh tests/image-contract.sh tests/inventory-contract.sh
docker build --platform linux/arm64 -t sungyism/openresty:events-contract .
tests/source-contract.sh
tests/image-contract.sh sungyism/openresty:events-contract linux/arm64
tests/inventory-contract.sh sungyism/openresty:events-contract linux/arm64
git diff --check
```

Expected: PASS; evidence identifies two old and two new worker PIDs plus old/new privileged-agent PIDs, with delivery before and after HUP.

- [ ] **Step 5: Commit the runtime contracts locally**

```bash
git add tests/fixtures/events/nginx.conf tests/image-contract.sh tests/inventory-contract.sh
git commit -m "test: verify events runtime and image inventory"
```

Do not push yet.

### Task 3: Make CI verify before main-only publication

**Files:**

- Create: `tests/workflow-contract.sh`
- Modify: `.github/workflows/docker-image.yml`

- [ ] **Step 1: Write a focused failing workflow contract**

Create executable `tests/workflow-contract.sh`. Keep it dependency-free: POSIX shell plus `awk`, `sed`, and `grep` only. Extract each top-level job by its two-space YAML indentation so assertions cannot be satisfied by a different job:

```sh
job_block() {
    job=$1
    awk -v job="$job" '
        $0 == "  " job ":" { in_job=1 }
        in_job && /^  [a-zA-Z0-9_-]+:$/ && $0 != "  " job ":" { exit }
        in_job { print }
    ' "$workflow"
}
```

Assert all of these exact properties:

- global `permissions: contents: read`;
- paths cover `Dockerfile`, `docker-entrypoint.sh`, `dependencies/**`, `tests/**`, `README.md`, `CLAUDE.md`, and the workflow itself;
- `source-contract` has no environment, registry secret, login, or push;
- `build-test` has `needs: source-contract`, exactly the amd64/arm64 matrix, and no environment, registry secret, login, or push;
- `publish` has `needs: [source-contract, build-test]`, `environment: build-image`, and a push-to-main-only condition;
- checkout is pinned to `11bd71901bbe5b1630ceea73d27597364c9af683` with `persist-credentials: false`;
- QEMU is pinned to action `06116385d9baf250c9f4dcb4858b16962ea869c3`, image `docker.io/tonistiigi/binfmt:qemu-v10.2.3@sha256:400a4873b838d1b89194d982c45e5fb3cda4593fbfd7e08a02e76b03b21166f0`, and platform `arm64`;
- Buildx is pinned to action `d7f5e7f509e45cec5c76c4d5afdd7de93d0b3df5`, Buildx `v0.35.0`, and BuildKit `moby/buildkit:v0.31.1@sha256:6b59b7df63a8cb9902736f9ddf7fcff8261613d3e7449b8ea8b7537fc399c03a`;
- login is pinned to `74a5d142397b4f367a81961eba4e8cd7edddf772` and exists only in `publish`;
- artifact upload is pinned to `ea165f8d65b6e75b540449e92b4886f43607fa02`;
- every build/test command precedes the promotion command inside `publish`;
- run-id/run-attempt names, digest-only child references, main-tip verification, release-tag collision check, and all-three-tag digest verification are present.

Run:

```bash
sh -n tests/workflow-contract.sh
tests/workflow-contract.sh
```

Expected: FAIL because the current workflow logs in and publishes on pull requests, uses floating actions, and has no runtime gates.

- [ ] **Step 2: Replace the workflow with three jobs**

Use `ubuntu-24.04`, `permissions: contents: read`, and the pinned actions/images above.

`source-contract`:

```yaml
needs: []
steps:
  - checkout with persist-credentials: false
  - run: |
      sh -n tests/source-contract.sh tests/image-contract.sh tests/inventory-contract.sh tests/workflow-contract.sh
      tests/source-contract.sh
      tests/workflow-contract.sh
```

`build-test`:

```yaml
needs: source-contract
strategy:
  fail-fast: false
  matrix:
    include:
      - platform: linux/amd64
        arch: amd64
      - platform: linux/arm64
        arch: arm64
```

Each row performs checkout, pinned QEMU/Buildx setup, then:

```bash
image="sungyism/openresty:verify-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}-${{ matrix.arch }}"
docker buildx build --platform "${{ matrix.platform }}" --load -t "$image" .
test "$(docker image inspect "$image" --format '{{.Os}}/{{.Architecture}}')" = "${{ matrix.platform }}"
EVIDENCE_DIR="$RUNNER_TEMP/evidence-${{ matrix.arch }}" tests/image-contract.sh "$image" "${{ matrix.platform }}"
EVIDENCE_DIR="$RUNNER_TEMP/evidence-${{ matrix.arch }}" tests/inventory-contract.sh "$image" "${{ matrix.platform }}"
```

Neither job receives Docker Hub credentials or publishes.

`publish` runs only for `push` on `main`, depends on both earlier jobs, uses `environment: build-image`, sets `DOCKER_CONFIG` to a runner-temp directory, and serializes with:

```yaml
concurrency:
  group: openresty-release-main
  cancel-in-progress: false
```

After pinned checkout/QEMU/Buildx/login, verify the run still targets current main:

```bash
remote_head=$(git ls-remote https://github.com/iYism/docker-openresty.git refs/heads/main | awk '{print $1}')
test "$remote_head" = "$GITHUB_SHA"
```

Build and push each platform by digest, without a mutable architecture tag:

```bash
repo=docker.io/sungyism/openresty
for item in linux/amd64:amd64 linux/arm64:arm64; do
  platform=${item%:*}
  arch=${item#*:}
  metadata="$RUNNER_TEMP/${arch}-metadata.json"
  docker buildx build \
    --platform "$platform" \
    --output "type=image,name=${repo},push-by-digest=true,name-canonical=true,push=true" \
    --metadata-file "$metadata" \
    .
  digest=$(jq -er '.["containerimage.digest"] | select(test("^sha256:[0-9a-f]{64}$"))' "$metadata")
  printf '%s=%s\n' "$arch" "$digest" >> "$RUNNER_TEMP/children.env"
  immutable="${repo}@${digest}"
  EVIDENCE_DIR="$RUNNER_TEMP/release-evidence/${arch}" tests/image-contract.sh "$immutable" "$platform"
  EVIDENCE_DIR="$RUNNER_TEMP/release-evidence/${arch}" tests/inventory-contract.sh "$immutable" "$platform"
done
```

Create the candidate index only from the two tested child digests:

```bash
. "$RUNNER_TEMP/children.env"
candidate="${repo}:candidate-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}"
docker buildx imagetools create \
  --metadata-file "$RUNNER_TEMP/index-metadata.json" \
  --tag "$candidate" \
  "${repo}@${amd64}" \
  "${repo}@${arm64}"
index_digest=$(jq -er '.["containerimage.digest"] | select(test("^sha256:[0-9a-f]{64}$"))' "$RUNNER_TEMP/index-metadata.json")
immutable_index="${repo}@${index_digest}"
docker buildx imagetools inspect "$immutable_index" --raw > "$RUNNER_TEMP/index.json"
```

Require the raw index to contain exactly the two expected `platform=digest` pairs, then re-run both image contracts against `immutable_index` before promotion.

Freeze the public version to the lock. If repository variable `OPENRESTY_VERSION` is nonempty and not `1.31.1.1`, fail; never choose the larger value. Define the permanent release tag from the digest prefix:

```bash
version=1.31.1.1
events_version=0.3.1
digest_short=${index_digest#sha256:}
release="${repo}:${version}-events-${events_version}-sha256-${digest_short%${digest_short#????????????}}"
```

If `release` already exists with another digest, fail. Recheck main head immediately before promotion. Promote only the immutable index:

```bash
docker buildx imagetools create \
  --tag "${repo}:latest" \
  --tag "${repo}:${version}" \
  --tag "$release" \
  "$immutable_index"
```

Reinspect `latest`, `1.31.1.1`, and the release tag and require all three digests to equal `index_digest`.

Write `release-evidence.json` with source commit, run id/attempt, workflow URL, source hashes, baseline digest, top-level digest, both child digests, tag mappings, contract results, resolved QEMU/Buildx/BuildKit inputs, and the enumerated residual risks. Upload the JSON, raw index, metadata, inventory diffs, and both architecture logs for 90 days with the pinned artifact action. Append the immutable reference and both child digests to `$GITHUB_STEP_SUMMARY`.

- [ ] **Step 3: Run the local CI contract and host gates**

```bash
sh -n tests/*.sh
tests/source-contract.sh
tests/workflow-contract.sh
docker build --platform linux/arm64 -t sungyism/openresty:events-contract .
tests/image-contract.sh sungyism/openresty:events-contract linux/arm64
tests/inventory-contract.sh sungyism/openresty:events-contract linux/arm64
git diff --check
```

Expected: PASS.

- [ ] **Step 4: Commit the safe CI workflow**

```bash
git add .github/workflows/docker-image.yml tests/workflow-contract.sh
git commit -m "ci: verify events image before digest promotion"
```

The branch remains local until Task 5 review.

### Task 4: Synchronize consumer and maintainer documentation

**Files:**

- Create: `tests/docs-contract.sh`
- Modify: `README.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Write the failing documentation contract**

Create executable `tests/docs-contract.sh`. Parse Dockerfile's defaults and require the exact README table rows for OpenResty `1.31.1.1` and OpenSSL `3.5.6`; reject stale `1.29.2.5` and `3.5.5` values. Require both documents to include:

- `lua-resty-events` `0.3.1`;
- static `ngx_lua_events_module`;
- `tests/source-contract.sh`, `tests/image-contract.sh`, and `tests/inventory-contract.sh`;
- immutable `sungyism/openresty:1.31.1.1@sha256:` consumption;
- the statement that `resty.http` is absent from this base;
- the real runtime-user fact: the `openresty` UID 101 account exists, but no Dockerfile `USER` is set and the default container process is root.

Run:

```bash
sh -n tests/docs-contract.sh
tests/docs-contract.sh
```

Expected: FAIL on the current stale versions and inaccurate component/runtime-user claims.

- [ ] **Step 2: Correct README and CLAUDE**

Update the component tables and commands to match the Dockerfile and runtime evidence. Explain that `latest` and version tags are convenience selectors, while production consumers resolve and pin the tested digest. Do not invent the future digest.

Document the exact local gate:

```bash
tests/source-contract.sh
tests/workflow-contract.sh
docker build --platform linux/arm64 -t sungyism/openresty:events-contract .
tests/image-contract.sh sungyism/openresty:events-contract linux/arm64
tests/inventory-contract.sh sungyism/openresty:events-contract linux/arm64
```

- [ ] **Step 3: Run every local gate**

```bash
sh -n tests/*.sh
tests/source-contract.sh
tests/workflow-contract.sh
tests/docs-contract.sh
docker build --platform linux/arm64 -t sungyism/openresty:events-contract .
tests/image-contract.sh sungyism/openresty:events-contract linux/arm64
tests/inventory-contract.sh sungyism/openresty:events-contract linux/arm64
git diff --check
```

Expected: PASS.

- [ ] **Step 4: Commit documentation**

```bash
git add README.md CLAUDE.md tests/docs-contract.sh
git commit -m "docs: document events-capable image contract"
```

### Task 5: Review, publish, and hand off the immutable digest

**Files:** No source files change unless review finds an issue.

- [ ] **Step 1: Run the complete pre-push gate from a clean worktree**

```bash
sh -n tests/*.sh
tests/source-contract.sh
tests/workflow-contract.sh
tests/docs-contract.sh
docker build --platform linux/arm64 -t sungyism/openresty:events-contract .
tests/image-contract.sh sungyism/openresty:events-contract linux/arm64
tests/inventory-contract.sh sungyism/openresty:events-contract linux/arm64
git diff --check
git status --short
```

Expected: all gates PASS and status is empty.

- [ ] **Step 2: Request code review before the first push**

Use `superpowers:requesting-code-review`. Review must compare the locks to upstream, confirm only the allowed inventory additions, inspect the generation-aware HUP evidence, verify PR credential isolation, and trace child digests through index creation and tag promotion.

Fix every blocking finding and rerun Step 1.

- [ ] **Step 3: Push the reviewed branch and require both PR matrix rows**

The first push occurs only now, after the old unsafe workflow has been replaced in the branch. Require full source, image, inventory, privileged-agent, and HUP gates on both `linux/amd64` and `linux/arm64`. Pull-request jobs must not receive Docker Hub credentials and must not push.

- [ ] **Step 4: Integrate through the repository's normal reviewed flow**

Do not bypass branch protection or force-push. Main publication is authorized only after review accepts the code and both architecture results.

- [ ] **Step 5: Verify the main release evidence independently**

From the successful main workflow, copy the immutable index reference and verify:

```bash
image='sungyism/openresty:1.31.1.1@sha256:<64-lowercase-hex-from-workflow>'
docker buildx imagetools inspect "$image"
tests/image-contract.sh "$image" linux/amd64
tests/inventory-contract.sh "$image" linux/amd64
tests/image-contract.sh "$image" linux/arm64
tests/inventory-contract.sh "$image" linux/arm64
```

Replace the bracketed digest with the actual validated workflow value; never commit or publish a placeholder reference.

- [ ] **Step 6: Return to the Ngatex resume checkpoint**

Hand Ngatex:

- immutable `sungyism/openresty:1.31.1.1@sha256:...` reference;
- docker-openresty source commit and successful workflow URL;
- unique release tag;
- top-level index digest and exact amd64/arm64 child digests;
- source/archive/license hashes;
- confirmation of baseline preservation and events CORE-module/Lua inventory;
- worker, privileged-agent, and post-HUP results for both architectures;
- artifact digest/retention information and explicit residual risks.

Only then begin Ngatex Phase 2A Task 1 in a new isolated Ngatex worktree based on `d77b8096f281a3ed47e5ce4b237e0c7aa7dfd430`.

## Plan self-review

- **Spec coverage:** exact OpenResty and events provenance, static CORE linking, closed Lua/license inventory, existing-image preservation, privileged agent, generation-aware HUP, both architectures, main-only publication, digest handoff, and documentation are mapped to Tasks 1-5.
- **Scope:** the plan changes only the existing OpenResty build, its tests, CI, and truthful docs; it does not add unrelated Ngatex dependencies or edit Ngatex.
- **Dependency discipline:** no `yq`, YAML library, or other parser is added. Workflow checks use repository shell and actual CI execution. No new tool enters the runtime image.
- **Type/name consistency:** lock keys, archive names, module name, file paths, platform names, evidence paths, and digest references are consistent across tasks.
- **Placeholder policy:** the only unavailable value is the future content-addressed image digest. It is captured and validated during release and is never invented in source.
- **Failure policy:** source drift, checksum mismatch, inventory loss, wrong architecture, missing privileged delivery, incomplete process replacement, main-head drift, release-tag collision, or any tag/digest mismatch stops publication.
