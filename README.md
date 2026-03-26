# OpenResty Docker Image

A high-performance, source-compiled OpenResty Docker image built on Enterprise Linux, featuring additional nginx modules, optimized libraries, and extended Lua libraries for modern web applications and API gateways.

[![Docker Build](https://github.com/iYism/docker-openresty/actions/workflows/docker-image.yml/badge.svg)](https://github.com/iYism/docker-openresty/actions/workflows/docker-image.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/sungyism/openresty.svg)](https://hub.docker.com/r/sungyism/openresty)
[![License](https://img.shields.io/github/license/iYism/docker-openresty.svg)](LICENSE)

## Requirements

> **Important:** This image requires **Enterprise Linux 9 or later** as the base OS, including:
> - Rocky Linux 9 / 10
> - AlmaLinux 9 / 10
> - CentOS Stream 9 / 10
> - Red Hat Enterprise Linux 9 / 10
>
> EL8 and earlier versions are **not supported**.

## Features

- **Source-compiled** - All components built from source with optimized compiler flags
- **Multi-stage build** - Minimal runtime image size without build dependencies
- **Multi-platform** - Supports `linux/amd64` and `linux/arm64` architectures
- **Modern TLS** - OpenSSL 3.x with OpenResty-specific patches for yield support
- **Brotli compression** - Native support for Brotli encoding
- **GeoIP2** - MaxMind GeoIP2 integration for geolocation
- **Enhanced Lua** - Additional Lua libraries for routing, IP matching, and expression evaluation

## Quick Start

```bash
# Pull from Docker Hub
docker pull sungyism/openresty:latest

# Run a basic container
docker run -d --name openresty \
  -p 80:80 \
  sungyism/openresty:latest

# Verify
curl http://localhost/
```

## Usage

### Basic Usage

```bash
docker run -d --name openresty \
  -p 80:80 \
  -p 443:443 \
  sungyism/openresty:latest
```

### With Custom Configuration

```bash
docker run -d --name openresty \
  -p 80:80 \
  -p 443:443 \
  -v /path/to/nginx.conf:/etc/nginx/nginx.conf:ro \
  -v /path/to/conf.d:/etc/nginx/conf.d:ro \
  -v /path/to/certs:/etc/nginx/certs:ro \
  -v /path/to/html:/opt/openresty/nginx/html:ro \
  sungyism/openresty:latest
```

### Docker Compose

```yaml
version: '3.8'

services:
  openresty:
    image: sungyism/openresty:latest
    container_name: openresty
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./conf.d:/etc/nginx/conf.d:ro
      - ./html:/opt/openresty/nginx/html:ro
      - ./logs:/var/log/nginx
    environment:
      - NGINX_ENTRYPOINT_QUIET_LOGS=1
```

## Building from Source

### Default Build (Rocky Linux 9)

```bash
docker build -t openresty:local .
```

### Build with Proxy

If you are behind a corporate firewall or have network restrictions, you can pass proxy settings:

```bash
# Using environment variables (recommended)
docker build \
  --build-arg HTTP_PROXY=${HTTP_PROXY} \
  --build-arg HTTPS_PROXY=${HTTPS_PROXY} \
  --build-arg NO_PROXY=${NO_PROXY} \
  -t openresty:local .

# Or with explicit proxy values
docker build \
  --build-arg HTTP_PROXY=http://proxy.example.com:8080 \
  --build-arg HTTPS_PROXY=http://proxy.example.com:8080 \
  --build-arg NO_PROXY=localhost,127.0.0.1,.internal \
  -t openresty:local .
```

### Custom Base Image

```bash
# Rocky Linux 10
docker build \
  --build-arg BASE_IMAGE=rockylinux/rockylinux:10 \
  --build-arg RUNTIME_IMAGE=rockylinux/rockylinux:10-minimal \
  -t openresty:local .

# AlmaLinux 9
docker build \
  --build-arg BASE_IMAGE=almalinux:9 \
  --build-arg RUNTIME_IMAGE=almalinux:9-minimal \
  -t openresty:local .
```

### Multi-platform Build

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t openresty:local \
  .
```

## Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `BASE_IMAGE` | `rockylinux/rockylinux:9` | Base image for download and build stages |
| `RUNTIME_IMAGE` | `rockylinux/rockylinux:9-minimal` | Base image for final runtime stage |
| `HTTP_PROXY` | *(none)* | HTTP proxy for network requests |
| `HTTPS_PROXY` | *(none)* | HTTPS proxy for network requests |
| `NO_PROXY` | *(none)* | Hosts to bypass proxy |
| `OPENRESTY_VER` | `1.29.2.2` | OpenResty version |
| `OPENSSL_VER` | `3.5.5` | OpenSSL version |
| `ZLIB_VER` | `1.3.2` | zlib compression library version |
| `PCRE2_VER` | `10.47` | PCRE2 regex library version |
| `GEOIP_VER` | `1.6.12` | Legacy GeoIP library version |
| `LIBMAXMINDDB_VER` | `1.13.3` | MaxMind DB reader library version |
| `BROTLI_VER` | `1.2.0` | Brotli compression library version |
| `NGX_BROTLI_VER` | `master` | nginx Brotli module version |
| `NGX_GEOIP2_VER` | `3.4` | nginx GeoIP2 module version |
| `RESTY_EXPR_VER` | `1.3.2` | lua-resty-expr version |
| `RESTY_HTTP_VER` | `0.2.3` | lua-resty-http version |
| `RESTY_IPMATCHER_VER` | `0.6.1` | lua-resty-ipmatcher version |
| `RESTY_RADIXTREE_VER` | `2.9.2` | lua-resty-radixtree version |

## Included Components

### Core

| Component | Description |
|-----------|-------------|
| **OpenResty** | Full-fledged web platform with LuaJIT |
| **LuaJIT** | Just-In-Time compiler for Lua with Lua 5.2 compatibility |
| **OpenSSL 3.x** | TLS/SSL library with OpenResty session yield patch |
| **zlib** | General-purpose lossless compression library |
| **PCRE2** | Perl-compatible regular expressions with JIT enabled |

### Nginx Modules

| Module | Description |
|--------|-------------|
| **ngx_brotli** | Brotli compression filter module |
| **ngx_http_geoip2_module** | GeoIP2 country/city lookup using MaxMind databases |
| **ngx_http_ssl_module** | HTTPS/TLS support |
| **ngx_http_v2_module** | HTTP/2 support |
| **ngx_http_v3_module** | HTTP/3 (QUIC) support |
| **ngx_http_realip_module** | Client real IP extraction |
| **ngx_http_image_filter_module** | Image transformation |
| **ngx_http_xslt_module** | XSLT transformations |
| **ngx_stream_module** | TCP/UDP proxying |

### Lua Libraries

| Library | Description |
|---------|-------------|
| **lua-resty-expr** | Expression evaluator for complex rule matching |
| **lua-resty-http** | HTTP client library for OpenResty |
| **lua-resty-ipmatcher** | High-performance IP/CIDR matching |
| **lua-resty-radixtree** | Radix tree implementation for efficient routing |

## Directory Structure

| Path | Description |
|------|-------------|
| `/etc/nginx` | Configuration directory |
| `/etc/nginx/nginx.conf` | Main configuration file |
| `/opt/openresty` | OpenResty installation directory |
| `/opt/openresty/lualib` | Lua library path |
| `/opt/openresty/nginx` | Nginx server root |
| `/var/log/nginx` | Log files |
| `/var/lib/nginx` | Runtime data (temp files, client bodies) |
| `/docker-entrypoint.d` | Entrypoint initialization scripts |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `NGINX_ENTRYPOINT_QUIET_LOGS` | Set to suppress entrypoint log output |
| `LUA_PATH` | Lua module search path |
| `LUA_CPATH` | Lua C module search path |
| `PATH` | Includes OpenResty binaries |

## Entrypoint Scripts

The container supports initialization scripts placed in `/docker-entrypoint.d/`:

- `*.sh` files are executed on container startup
- `*.envsh` files are sourced into the environment
- Scripts must be executable (`chmod +x`)

Example initialization script:

```bash
#!/bin/sh
# /docker-entrypoint.d/10-init-lua.sh
echo "Initializing Lua cache..."
mkdir -p /var/lib/nginx/lua_cache
```

## Image Variants

Images are available on Docker Hub:

- `sungyism/openresty:latest` - Latest stable build
- `sungyism/openresty:1.29.2.2` - Version-specific tag

## Security Considerations

- Runs as non-root user `openresty` (UID 101) by default
- Minimal runtime image reduces attack surface
- Compiled with security-hardened flags
- OpenSSL built with FIPS support enabled

## Performance Tuning

The image is built with optimizations:

- `-O3` compiler optimization level
- Position-independent code (`-fPIC`)
- PCRE2 with JIT enabled
- LuaJIT with dual-number mode and Lua 5.2 compatibility

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## AI-Driven Development

This project is maintained using **Claude Code** (claude.ai/code), Anthropic's AI-powered coding assistant. All code modifications, documentation updates, and maintenance tasks are orchestrated through AI-assisted development workflows.

This approach enables:

- **Rapid iteration** - Faster response to updates and security patches
- **Consistent quality** - Uniform coding standards and best practices
- **Comprehensive documentation** - Thorough and well-structured project documentation
- **Continuous improvement** - Regular updates and optimization of the build process

For transparency, all commit messages include Co-Authored-By attribution indicating AI assistance.

## Acknowledgments

- [OpenResty](https://openresty.org/) - The web platform powering this image
- [Rocky Linux](https://rockylinux.org/) - The reliable enterprise Linux distribution
- [Claude Code](https://claude.ai/code) - AI-powered development assistant

## Maintainer

Maintained by iYism <admin@iyism.com>

- GitHub: [https://github.com/iYism/docker-openresty](https://github.com/iYism/docker-openresty)
- Docker Hub: [https://hub.docker.com/r/sungyism/openresty](https://hub.docker.com/r/sungyism/openresty)
