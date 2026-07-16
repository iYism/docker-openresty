# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository builds a custom OpenResty Docker image from source on Rocky Linux 9. It uses a multi-stage build to minimize the final image size while including additional nginx modules and Lua libraries not available in the official OpenResty image.

Base image format: `rockylinux/rockylinux:9` (Docker Hub official format)

## Build Commands

```bash
# Build the Docker image locally
docker build -t openresty:local .

# Build with proxy (for restricted networks)
docker build \
  --build-arg HTTP_PROXY=${HTTP_PROXY} \
  --build-arg HTTPS_PROXY=${HTTPS_PROXY} \
  --build-arg NO_PROXY=${NO_PROXY} \
  -t openresty:local .

# Build with different base image
docker build \
  --build-arg BASE_IMAGE=rockylinux/rockylinux:10 \
  --build-arg RUNTIME_IMAGE=rockylinux/rockylinux:10-minimal \
  -t openresty:local .

# Build for specific platform
docker buildx build --platform linux/amd64 -t openresty:local .

# Build multi-platform (requires buildx and QEMU)
docker buildx build --platform linux/amd64,linux/arm64 -t openresty:local .
```

## Version Management

Component versions are defined as ARGs at the top of the Dockerfile:
- `OPENRESTY_VER` - OpenResty `1.31.1.1`
- `ZLIB_VER`, `PCRE2_VER`, `OPENSSL_VER` - Core library versions; OpenSSL is `3.5.6`
- `NGX_BROTLI_VER`, `NGX_GEOIP2_VER` - nginx module versions
- `RESTY_EXPR_VER`, `RESTY_IPMATCHER_VER`, `RESTY_RADIXTREE_VER` - Lua library versions

`lua-resty-events` `0.3.1` is installed with the statically linked CORE module `ngx_lua_events_module`.

Proxy settings can be passed via build args:
- `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY` - For restricted network environments

The release workflow freezes its public version to `dependencies/openresty.lock`. If the repository variable `OPENRESTY_VERSION` is configured, it must be empty or exactly match the reviewed lock; it is never used to select a newer version.

## Architecture

The Dockerfile uses three stages:

1. **Downloader** (`rockylinux:9`) - Downloads all source tarballs and patches
2. **Builder** (`rockylinux:9`) - Compiles dependencies and OpenResty with all modules
3. **Runtime** (`rockylinux:9-minimal`) - Minimal image with compiled artifacts only

Key build dependencies are compiled to `/opt/openresty/` subdirectories (zlib, pcre2, openssl3, GeoIP, libmaxminddb, brotli) and linked via rpath.

## Included Modules

- **ngx_brotli** - Brotli compression
- **ngx_http_geoip2_module** - MaxMind GeoIP2 lookup
- **ngx_lua_events_module** - Statically linked CORE module for `lua-resty-events` `0.3.1`
- **lua-resty-expr** - Lua expression evaluator
- **lua-resty-ipmatcher** - IP matching library
- **lua-resty-radixtree** - Radix tree router

`resty.http` is absent from this base image. The legacy `RESTY_HTTP_VER` source-build input does not make it available in the final Lua inventory.

## Verification and Consumption

The `latest` and version tags are convenience selectors; production consumers resolve and pin the tested immutable digest.

Immutable references start with `sungyism/openresty:1.31.1.1@sha256:` and the digest must come from verified release evidence.

### Local ARM64 verification gate

```bash
tests/source-contract.sh
tests/workflow-contract.sh
docker build --platform linux/arm64 -t sungyism/openresty:events-contract .
tests/image-contract.sh sungyism/openresty:events-contract linux/arm64
tests/inventory-contract.sh sungyism/openresty:events-contract linux/arm64
```

## Runtime Configuration

- The `openresty` UID 101 account exists, but the final runtime stage has no `USER` instruction, so the default container process runs as root.
- Config directory: `/etc/nginx`
- Logs: `/var/log/nginx`
- Data: `/var/lib/nginx`
- Entry point scripts: `/docker-entrypoint.d/*.sh` (executed on container start)
