# OpenResty Image Engineering Rules

## Development loop

- For Lua, gateway-runtime, and HTTP API iteration, prefer one long-lived,
  native-architecture OpenResty development container over rebuilding the image
  after every source edit.
- Bind-mount the source and development configuration into that container. The
  Ngatex development runtime must expose an explicit opt-in
  `NGATEX_DEV_HOT_RELOAD=1` switch for code reload; hot reload must remain off in
  production and release verification.
- Use `docker exec` for in-container inspection and targeted commands. Exercise
  HTTP APIs with `curl` against the running container.
- Use OpenResty's `resty` CLI for focused Lua examples and fast module checks
  when the behavior does not depend on a real master/worker lifecycle. Use the
  builder/development image, which includes the Perl interpreter required by
  the `resty` launcher; do not assume the minimal production runtime can launch
  it merely because the script is present.
- Validate worker initialization, privileged agents, Unix-socket brokers,
  reloads, and HUP recovery under a real Nginx master and worker processes, not
  under `resty` CLI alone.
- Rebuild the image when the Dockerfile, native/CORE modules, system libraries,
  patches, or dependency locks change. A mounted development run never replaces
  the clean-image release contracts.
- Do not remove or mutate containers, images, volumes, worktrees, or files that
  belong to another task. Clean only resources created by the current task or
  resources the user explicitly authorizes.
