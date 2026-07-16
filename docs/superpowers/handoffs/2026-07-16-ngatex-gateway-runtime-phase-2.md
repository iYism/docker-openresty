# Ngatex Gateway Runtime Phase 2 Handoff

**Recorded:** 2026-07-16 15:15:54 +0800  
**Status:** Active and incomplete. Resume at Task 2 review fixes; do not restart the work.

## User authorization and constraints

- Continue the approved Ngatex Gateway Runtime Phase 2 roadmap from
  `Execution Approval and Resume Checkpoint` without asking again.
- Another Codex task shares `/Users/jiangmeng/GitProjects/ngatex`. Do not edit,
  delete, clean, reset, or otherwise mutate that shared worktree or the other
  task's files.
- The user authorized cloning and changing
  `git@github.com:iYism/docker-openresty.git`.
- Required image approach: all source downloads, patches, CORE modules, and
  installation happen in the Dockerfile; produce a clean source build rather
  than layering patches onto an old image.
- Local verification is native ARM64 only. Multi-platform amd64/arm64 work is a
  CI publication concern.
- Do not use `yq` for this workflow.
- The user explicitly authorized cleaning dangling `<none>` images. Only stale
  working containers created by this task were removed; business containers
  and the dangling images they use were preserved.

## Isolation and current Git state

- Original Ngatex worktree: `/Users/jiangmeng/GitProjects/ngatex` — untouched by
  this task.
- Original docker-openresty worktree:
  `/Users/jiangmeng/GitProjects/docker-openresty` — untouched by this task.
- Active isolated clone/worktree:
  `/private/tmp/docker-openresty-phase2-plan-worktree`
- Branch: `codex/ngatex-phase2-events-base-plan-20260716`
- Current HEAD: `ab67bc1edc276657219cbd01ff7fca26b0bfd570`
- Upstream base used for this work: `74c291a`
- No push, pull request, merge, or Docker Hub publication has occurred.
- Worktree was clean when this handoff was written.

Commits after the upstream base:

```text
9a7eecb docs: plan events-capable OpenResty image
a89a1f8 build: add pinned lua-resty-events core module
a9f776d docs: keep local image verification native
3c43daa fix: verify events archive file manifest
0a37cfb fix: retry clean source downloads
6360a8d fix: fail fast installing events lua files
09fe673 fix: use upstream events installer
e49a5f5 test: guard verified upstream events install
0a0dbb7 build: discard temporary openssl sources
6a21925 test: verify events runtime and image inventory
ab67bc1 docs: add development container workflow rules
```

## Reviewed source inputs

```text
OpenResty version: 1.31.1.1
OpenResty archive SHA-256: 65b78baadd3f0984055de89bf13f4a1932e5bfe9c31932037a134ea2b1a0ce42

lua-resty-events version: 0.3.1
lua-resty-events commit: bc85295b7c23eda2dbf2b4acec35c93f77b26787
lua-resty-events archive SHA-256: f399db5ca6fab8bca337389b061ec331374f89b8843cca3abeb0a04d9f0505a2
lua-resty-events license SHA-256: aa9c2870e477001cfa5e3a3dfd3c86c1190cc985a8ed506e9c1e05537e524cdc
module type: static CORE module
```

The archive plus 14-entry file manifest is enforced by:

- `dependencies/openresty.lock`
- `dependencies/lua-resty-events.lock`
- `dependencies/lua-resty-events.files.sha256`
- `tests/source-contract.sh`
- `tests/events-archive-contract.sh`

The user rejected a hand-written per-file installer. The current Dockerfile uses
the pinned upstream Makefile exactly:

```text
make install LUA_LIB_DIR=/opt/openresty/lualib
```

The per-file manifest remains an installation prerequisite and supply-chain
check; it is not used to reimplement the upstream installer.

## Local ARM64 build and runtime evidence

Production test image:

```text
sungyism/openresty:events-contract
sha256:b527980f497d5c9dfff98b1957d642bda7631472eec2a5a985fd4ff2c61d730a
linux/arm64
```

Development builder image:

```text
sungyism/openresty:events-dev
sha256:fba3205561f847e11fa2a95504ff648b95cfdc6c048ac5c5c12bd6849ffbb914
linux/arm64
```

Confirmed build/runtime facts:

- clean native build completed successfully;
- OpenResty and events archive SHA checks passed during the real build;
- the configure log said `ngx_lua_events_module was configured`;
- the upstream `make install` installed the 10 top-level Lua files plus
  `compat/init.lua`;
- final image has the static configure input exactly once and no events `.so`;
- final image contains the exact 11 reviewed Lua files and license hash;
- production image contains no compiler, `/build`, or source archive;
- baseline inventory remains identical after subtracting the one static module
  token and the 11 reviewed Lua files;
- real cJSON runtime version is `2.1.0.11` in baseline and new image;
- `resty.http` remains unavailable and absent from `/opt/openresty/lualib`.

Fresh Task 2 ARM64 evidence before review fixes:

```text
image-contract: PASS
old worker-0/worker-1/privileged PIDs: 2,3,4
new worker-0/worker-1/privileged PIDs after HUP: 5,6,7
inventory-contract: PASS
```

Evidence log:

```text
/private/tmp/openresty-events-evidence/final-arm64/events-linux-arm64.log
```

The development builder contains Perl and successfully ran:

```text
resty -e 'ngx.say("resty-cli-ok")'
```

The minimal production image intentionally lacks Perl, so its `resty` launcher
file is present/executable but cannot run. Do not add Perl to production merely
for development convenience.

## User-added development behavior rules

Root `AGENTS.md` was added in commit `ab67bc1`. It requires:

- a long-lived native-architecture OpenResty development container for Lua/API
  iteration;
- bind-mounted source and configuration;
- explicit dev-only `NGATEX_DEV_HOT_RELOAD=1` opt-in, off in production/release;
- `docker exec` for container diagnostics;
- `curl` for HTTP API checks;
- `resty` CLI from the builder/development image for focused Lua examples;
- real Nginx workers for privileged-agent, broker, and HUP behavior;
- a clean image rebuild whenever Dockerfile/native dependencies/locks change.

Carry the same development rule into an isolated Ngatex Phase 2A worktree when
the immutable image handoff is complete. Do not edit the currently shared
Ngatex root to add it.

## Blocking Task 2 review findings — fix these first

Commit `6a21925` is functionally green but not review-ready. Three blockers were
found after the commit:

1. **Generation parsing is not anchored after HUP.**
   `tests/image-contract.sh` scans all historical initialization logs and accepts
   any PID different from the initial PID. A pre-HUP worker respawn could be
   misclassified as the reload generation. Capture the pre-HUP log line count,
   wait for a master `SIGHUP/reconfiguring` marker after that boundary, and parse
   replacement initialization lines only after that boundary.
2. **Operations and cleanup use a reusable container name.**
   After `docker run` returns `container_id`, every `logs`, `port`, `exec`,
   `inspect`, `kill`, and `rm` operation must use the immutable ID. This prevents
   cleanup from deleting a different task's container if the original is
   externally removed and its name reused.
3. **Version checks are substring matches.**
   Use an exact full-line check for
   `nginx version: openresty/1.31.1.1`, a version-token boundary for OpenSSL
   `3.5.6`, and exact configure-token comparisons. Current `grep -F` checks could
   accept `1.31.1.10` or `3.5.60`.

After fixing, rerun at minimum:

```sh
sh -n tests/*.sh
tests/source-contract.sh
tests/events-archive-contract.sh /private/tmp/lua-resty-events-bc85295b.tar.gz
EVIDENCE_DIR=/private/tmp/openresty-events-evidence/final-arm64 \
  tests/image-contract.sh sungyism/openresty:events-contract linux/arm64
EVIDENCE_DIR=/private/tmp/openresty-events-evidence/final-arm64 \
  tests/inventory-contract.sh sungyism/openresty:events-contract linux/arm64
git diff --check
```

Commit the review fixes separately and request another locked-commit review.

## Blocking Task 3 CI plan corrections

Before implementing `.github/workflows/docker-image.yml`, update the plan and
contract for all of these:

1. `docker buildx build --metadata-file` uses `containerimage.digest`, but
   `docker buildx imagetools create --metadata-file` uses
   `containerimage.descriptor.digest`.
2. Every registry push-by-digest build must explicitly use
   `--provenance=false --sbom=false`; otherwise default attestations introduce
   `unknown/unknown` descriptors and invalidate the exact two-platform index.
3. Replace Node20 action pins with reviewed Node24 pins:

```text
actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd        # v6.0.2
docker/login-action@4907a6ddec9925e35a0a9e82d7399ccc52663121    # v4.1.0
actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1
```

Keep the already reviewed QEMU/Buildx/BuildKit pins. Candidate index validation
must require exactly these two pairs and no third descriptor:

```text
linux/amd64 -> tested amd64 child digest
linux/arm64 -> tested arm64 child digest
```

The final three public tags must be verified with
`imagetools inspect --format '{{json .Manifest.Digest}}'` against the immutable
index digest. No `yq` is needed.

## Remaining roadmap work

1. Fix and re-review the three Task 2 blockers.
2. Implement Task 3 workflow contract and safe three-job CI.
3. Update README/CLAUDE/docs contracts, including the development-container and
   `resty` CLI workflow without claiming production Perl support.
4. Run the complete clean ARM64 local gate and verification-before-completion.
5. Request final code review.
6. Push the reviewed branch; require both PR matrix rows.
7. Integrate normally, let main publish the tested amd64/arm64 immutable index,
   and independently verify the published digest.
8. Return the immutable image reference, source commit, workflow URL, child
   digests, evidence, and residual risks to Ngatex.
9. Only then create a new isolated Ngatex Phase 2A worktree and begin Task 1.

## Resume command

At the next session, start with:

```sh
cd /private/tmp/docker-openresty-phase2-plan-worktree
cat AGENTS.md
cat docs/superpowers/handoffs/2026-07-16-ngatex-gateway-runtime-phase-2.md
git status --short
git log --oneline -12
```

Then fix the three Task 2 blockers. Do not rebuild from scratch unless the
Dockerfile changes or the local image is no longer present.
