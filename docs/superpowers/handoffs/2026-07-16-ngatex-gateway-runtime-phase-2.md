# Ngatex Gateway Runtime Phase 2 Handoff

**Recorded:** 2026-07-16 15:15:54 +0800  
**Updated:** 2026-07-16 17:45:24 +0800
**Status:** Task 3 CI implementation is complete and re-reviewed. Stop before Task 4; no push or registry publication has occurred.

## 2026-07-16 17:45 Task 3 completion and review update

Task 3 continued only in the persistent worktree and object store established
before Task 2 completion:

```text
Git common directory: /Users/jiangmeng/GitProjects/docker-openresty/.git
persistent worktree: /Users/jiangmeng/GitProjects/docker-openresty-phase2-events-resume-20260716
branch: codex/ngatex-phase2-events-base-resume-20260716
reviewed code head before this handoff update: 81db9de050da3c67ae4170c8c5b20478519d4b65
```

The original `/Users/jiangmeng/GitProjects/docker-openresty` worktree remains
clean on `main` at `74c291a`. The old resume worktree remains intact and clean
at `3f68c45`, with its Git common directory still at
`/private/tmp/docker-openresty-phase2-plan-repo/.git`. No old worktree or
`/private/tmp` Git data was removed.

Task 3 was implemented as these local commits:

```text
f701fb1 docs: correct task 3 ci contracts
d302423 docs: clarify task 3 workflow validity
edaf18f ci: verify events image before digest promotion
81db9de test: lock CI credential isolation
```

The first workflow contract run produced the required TDD red result against
the legacy single-job workflow:

```text
workflow-contract: FAIL: top-level jobs must be exactly source-contract, build-test, and publish
```

The completed workflow now has exactly three jobs:

- `source-contract` runs only offline source/workflow validation and has no
  environment, secret, login, or push path;
- `build-test` runs the exact `linux/amd64` and `linux/arm64` matrix, builds a
  local image, and runs both runtime contracts without credentials or push;
- `publish` is gated to a `push` on `refs/heads/main`, depends on both earlier
  jobs, uses the protected `build-image` environment, and is serialized by
  `openresty-release-main`.

All action, QEMU, Buildx, BuildKit, and binfmt inputs use the reviewed immutable
pins. Checkout does not persist credentials. The publish job derives
`DOCKER_CONFIG` from `$RUNNER_TEMP` through `$GITHUB_ENV` before Docker setup
and login, so registry credentials do not use the default runner config.

Publication is verify-before-promote and remains unexecuted locally:

1. verify the workflow SHA is still current `main` before any registry build;
2. push each platform by digest with `--provenance=false --sbom=false`;
3. read child metadata from `containerimage.digest` and run both contracts on
   each immutable child;
4. create a candidate only from those two child digests, read
   `containerimage.descriptor.digest`, and require exactly the expected
   `linux/amd64` and `linux/arm64` descriptors with no third descriptor;
5. rerun both contracts through the immutable two-platform index;
6. freeze the version to the `1.31.1.1` lock, fail closed on an unexpected
   repository variable or release-tag collision/inspection error, and recheck
   current `main` immediately before promotion;
7. promote only the immutable index to `latest`, `1.31.1.1`, and the
   content-addressed release tag, then verify every public tag with
   `imagetools inspect --format '{{json .Manifest.Digest}}'`;
8. write and retain release evidence for 90 days, including source hashes,
   child/index/tag digests, contract results, resolved build inputs, artifact
   digest reporting, and all approved residual risks.

Two implementation-time Actions validity issues were caught by pinned local
`actionlint` `v1.7.7` and corrected before commit: a root job cannot use an
empty `needs: []`, and the `runner` context is unavailable in job-level `env`.
Focused smoke probes also proved that:

- the candidate-index step accepts exactly the expected two descriptors and
  rejects an added `unknown/unknown` third descriptor;
- an explicit missing release tag is accepted, while a registry transport
  error fails closed and an existing different digest is rejected;
- `release-evidence.json` is valid JSON with the expected digest and residual
  risk structure.

Fresh complete local Task 3 gate at reviewed code head `81db9de`:

```text
sh -n tests/*.sh: PASS
tests/source-contract.sh: PASS
tests/workflow-contract.sh: PASS
actionlint v1.7.7 .github/workflows/docker-image.yml: PASS
docker build --platform linux/arm64 -t sungyism/openresty:events-contract .: PASS
  image id: sha256:60b4bb50ed4d11597d78e4b762c72776eec9b7a12ce1731b1b9a5d6848a8b390
tests/image-contract.sh sungyism/openresty:events-contract linux/arm64: PASS
  old worker-0/worker-1/privileged PIDs: 2,3,4
  new worker-0/worker-1/privileged PIDs: 5,6,7
tests/inventory-contract.sh sungyism/openresty:events-contract linux/arm64: PASS
git diff --check: PASS
git status --short: clean
```

Review order and result:

```text
specification review at 81db9de: PASS, blocking findings 0
code-quality review at 81db9de: PASS, blocking findings 0
```

The quality review recorded three non-blocking follow-ups only:

1. the focused workflow contract intentionally uses strict whole-file counts
   and some substring assertions, so future harmless action/comment changes may
   require synchronized exact-line refinements;
2. release-tag absence currently accepts registry errors containing the generic
   text `not found`; a future hardening can narrow this to explicit manifest
   404/`manifest unknown` responses;
3. the actual artifact digest is written to the workflow summary, while the
   JSON records where that post-upload digest is reported; a companion
   post-upload attestation can make it independently machine-auditable later.

None blocks the reviewed Task 3 implementation. No workflow was pushed or run
on GitHub, no amd64 CI evidence exists yet, and no Docker Hub child, candidate,
index, or public tag was published. Those remain behind the later plan gates.
Task 4 documentation work is the next plan task but was intentionally not
started. Ngatex Phase 2A remains blocked on the eventual reviewed, published,
and independently verified immutable multi-architecture digest.

## 2026-07-16 16:47 Task 2 completion and persistent migration update

The resume branch was migrated non-destructively into the persistent Git object
store requested by the user:

```text
Git common directory: /Users/jiangmeng/GitProjects/docker-openresty/.git
persistent worktree: /Users/jiangmeng/GitProjects/docker-openresty-phase2-events-resume-20260716
branch: codex/ngatex-phase2-events-base-resume-20260716
code head before this handoff update: aa47853
```

The migration was first verified at the required pre-development HEAD
`3f68c451419a7b53f1dc783c2610c029f14115ed`. The original
`/Users/jiangmeng/GitProjects/docker-openresty` worktree remains clean on
`main` at `74c291a`. The old resume worktree remains intact at:

```text
/Users/jiangmeng/GitProjects/ngatex/.worktrees/docker-openresty-phase2-events-resume
Git common directory: /private/tmp/docker-openresty-phase2-plan-repo/.git
HEAD: 3f68c451419a7b53f1dc783c2610c029f14115ed
```

No old worktree or `/private/tmp` Git data was removed. File hashes for the
Dockerfile, dependency locks, Task 2 contracts, and this handoff matched across
the old and persistent worktrees immediately after migration.

Task 2 specification compliance passed before code-quality review. The quality
review then found two blocking failure-mode gaps:

1. a successful-looking image contract could print `PASS` before durable
   evidence capture and suppress evidence/container cleanup failures;
2. any failed `docker exec` could be mistaken for proof that an old PID exited.

These were fixed and locked by separate commits:

```text
b136712 test: fail closed on events evidence cleanup
2ec01ef test: lock events cleanup control flow
aa47853 test: require cleanup failure accounting
```

The image contract now atomically writes logs plus the old/new PID summary,
successfully removes the exact immutable `container_id`, and only then prints
`PASS`. Old-process exit succeeds only when a successful in-container probe
returns the explicit `gone` state; Docker exec/daemon failures retry or fail
instead of false-passing. The source contract locks the cleanup status flow,
both cleanup-failure assignments, the unique `gone` success return, and the
explicit `alive`/`gone` probe.

Regression probes proved that the source contract rejects all of these
deliberate regressions:

- cleanup failure overwrites or bypasses the original status policy;
- `alive` is allowed to return success;
- either evidence or container-removal cleanup failure is not recorded.

An unwritable evidence-directory probe also exited nonzero without printing
`image-contract: PASS`, while still removing the task container. The reviewer's
cached-mutable-image concern was re-evaluated as non-blocking/YAGNI: approved
mutable tags are freshly built local candidates, while remote release inputs
are immutable `repo@sha256` references.

Final review result:

```text
specification review: PASS
code-quality re-review: Blocking findings resolved
```

Fresh complete Task 2 gate at code head `aa47853`:

```text
sh -n tests/*.sh: PASS
tests/source-contract.sh: PASS
tests/events-archive-contract.sh /private/tmp/lua-resty-events-bc85295b.tar.gz: PASS
tests/image-contract.sh sungyism/openresty:events-contract linux/arm64: PASS
  old worker-0/worker-1/privileged PIDs: 2,3,4
  new worker-0/worker-1/privileged PIDs: 5,6,7
tests/inventory-contract.sh sungyism/openresty:events-contract linux/arm64: PASS
git diff --check: PASS
git status --short: clean
```

Evidence remains at:

```text
/private/tmp/openresty-events-evidence/final-arm64/events-linux-arm64.log
```

Task 3 is the next plan task but was intentionally not started. No push, PR,
merge, image publication, or Ngatex Phase 2A work occurred.

## 2026-07-16 15:53 pause update

The user explicitly paused development before restarting Codex with
`--dangerously-bypass-approvals-and-sandbox`. No Task 3 work has started.

The work was not lost. The original isolated worktree described below remains
at commit `691e139`. Because the restricted patch tool could not edit that
`/private/tmp` path, continuation was made in a second docker-openresty worktree:

```text
/Users/jiangmeng/GitProjects/ngatex/.worktrees/docker-openresty-phase2-events-resume
branch: codex/ngatex-phase2-events-base-resume-20260716
code head before this handoff update: dd060be0268457db5319dda0eb5e6df59e9c2906
```

That path is Git-ignored by Ngatex and belongs to the isolated docker-openresty
clone; its commits are not Ngatex commits. Commit `dd060be` changes only:

- `tests/source-contract.sh`
- `tests/image-contract.sh`
- `tests/inventory-contract.sh`

It fixes the three Task 2 review blockers by:

1. recording the pre-HUP log boundary, waiting for the post-boundary master
   `signal 1 (SIGHUP) received, reconfiguring` marker, and accepting replacement
   receiver initialization only after that marker;
2. using the immutable `container_id` for every post-start Docker operation and
   cleanup, while retaining the reusable name only for `docker run --name`;
3. requiring an exact OpenResty version line, exact OpenSSL version token, and
   exact configure tokens in both image and inventory contracts.

Fresh TDD and static evidence for `dd060be`:

```text
RED: source-contract: FAIL: missing: grep -F -x -c -- 'nginx version: openresty/1.31.1.1'
GREEN: sh -n tests/*.sh
GREEN: tests/source-contract.sh
GREEN: tests/events-archive-contract.sh /private/tmp/lua-resty-events-bc85295b.tar.gz
GREEN: negative probes reject 1.31.1.10, OpenSSL 3.5.60, and configure-token suffixes
GREEN: git diff --check
```

A direct Docker smoke command succeeded and returned `aarch64`, OpenResty
`1.31.1.1`, and OpenSSL `3.5.6`. The restricted runner nevertheless denied
Docker socket access when Docker was invoked from inside `tests/image-contract.sh`.
Therefore the complete post-fix image and inventory contracts were **not**
rerun and must not be reported as fresh passes. Earlier ARM64 evidence remains
historical evidence only.

Three implementation subagents and one specification-review subagent stalled
without changing files and were interrupted. Task 2 is not complete until the
full ARM64 image/inventory gate passes on `dd060be`, followed by specification
compliance review and then code-quality review.

Resume exactly here:

```sh
cd /Users/jiangmeng/GitProjects/ngatex/.worktrees/docker-openresty-phase2-events-resume
cat AGENTS.md
cat docs/superpowers/handoffs/2026-07-16-ngatex-gateway-runtime-phase-2.md
git status --short
git log --oneline -14
```

Then run the complete Task 2 gate, perform the two reviews in order, and fix and
re-review every blocking finding. Only after Task 2 approval proceed to Task 3.
Before Task 3 implementation, preserve the CI corrections already recorded in
this handoff: the imagetools metadata key, `--provenance=false --sbom=false`,
Node 24 action pins, exactly two platform descriptors, and exact final-tag
digest verification. No push, PR, merge, or Docker Hub publication has occurred.

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
