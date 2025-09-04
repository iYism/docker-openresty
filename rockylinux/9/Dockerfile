# Dockerfile - Rocky Linux 9 - Source Build
# Maintained by iYism <admin@iyism.com>
# https://github.com/iYism/docker-openresty

# Define version arguments for OpenResty and its dependencies
ARG OPENRESTY_VER=1.27.1.2
ARG ZLIB_VER=1.3.1
ARG PCRE2_VER=10.46
ARG OPENSSL_VER=3.5.2
ARG GEOIP_VER=1.6.12
ARG LIBMAXMINDDB_VER=1.12.2
ARG BROTLI_VER=1.1.0
ARG NGX_BROTLI_VER=master
ARG NGX_GEOIP2_VER=3.4
ARG RESTY_EXPR_VER=1.3.2
ARG RESTY_IPMATCHER_VER=0.6.1
ARG RESTY_RADIXTREE_VER=2.9.2

# Define arguments for OpenResty user, directories, and build path
ARG USER=openresty
ARG HOME_DIR=/opt/openresty
ARG CONF_DIR=/etc/nginx
ARG DATA_DIR=/var/lib/nginx
ARG LOGS_DIR=/var/log/nginx
ARG LUA_LIB=${HOME_DIR}/lualib
ARG BUILD_DIR=/build/openresty


### Download Stage
FROM rockylinux:9 AS downloader

# Set environment variables for the build stage
ARG OPENRESTY_VER \
    ZLIB_VER \
    PCRE2_VER \
    OPENSSL_VER \
    GEOIP_VER \
    LIBMAXMINDDB_VER \
    BROTLI_VER \
    NGX_BROTLI_VER \
    NGX_GEOIP2_VER \
    RESTY_EXPR_VER \
    RESTY_IPMATCHER_VER \
    RESTY_RADIXTREE_VER \
    USER \
    CONF_DIR \
    HOME_DIR \
    DATA_DIR \
    LOGS_DIR \
    LUA_LIB \
    BUILD_DIR

USER root
WORKDIR ${BUILD_DIR}

RUN set -x \
    && mkdir -p {pkg,src} \
    && cd ${BUILD_DIR}/pkg \
# Download openresty
    && curl -Lo openresty-${OPENRESTY_VER}.tar.gz https://openresty.org/download/openresty-${OPENRESTY_VER}.tar.gz \
# Download zlib
    && curl -Lo zlib-${ZLIB_VER}.tar.gz https://www.zlib.net/zlib-${ZLIB_VER}.tar.gz \
# Download pcre2
    && curl -Lo pcre2-${PCRE2_VER}.tar.gz https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE2_VER}/pcre2-${PCRE2_VER}.tar.gz \
# Download openssl
    && curl -Lo openssl-${OPENSSL_VER}.tar.gz https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VER}/openssl-${OPENSSL_VER}.tar.gz \
# Download openssl sess_set_get_cb_yield.patch
    && STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" -LI https://github.com/openresty/openresty/raw/refs/heads/master/patches/openssl-${OPENSSL_VER}-sess_set_get_cb_yield.patch); \
       if [ "${STATUS_CODE:-0}" -eq 200 ]; then \
           curl -Lo openssl-${OPENSSL_VER}-sess_set_get_cb_yield.patch https://github.com/openresty/openresty/raw/refs/heads/master/patches/openssl-${OPENSSL_VER}-sess_set_get_cb_yield.patch ; \
       else \
           curl -Lo openssl-${OPENSSL_VER}-sess_set_get_cb_yield.patch https://github.com/openresty/openresty/raw/refs/heads/master/patches/openssl-"${OPENSSL_VER%.*}.0"-sess_set_get_cb_yield.patch ; \
       fi \
# Download GeoIP
    && curl -Lo GeoIP-${GEOIP_VER}.tar.gz https://github.com/maxmind/geoip-api-c/releases/download/v${GEOIP_VER}/GeoIP-${GEOIP_VER}.tar.gz \
# Download libmaxminddb
    && curl -Lo libmaxminddb-${LIBMAXMINDDB_VER}.tar.gz https://github.com/maxmind/libmaxminddb/releases/download/${LIBMAXMINDDB_VER}/libmaxminddb-${LIBMAXMINDDB_VER}.tar.gz \
# Download brotli
    && curl -Lo brotli-${BROTLI_VER}.tar.gz https://github.com/google/brotli/archive/refs/tags/v${BROTLI_VER}.tar.gz \
# Download ngx_brotli
    && curl -Lo ngx_brotli-${NGX_BROTLI_VER}.tar.gz https://github.com/google/ngx_brotli/archive/refs/heads/${NGX_BROTLI_VER}.tar.gz \
# Download ngx_http_geoip2_module
    && curl -Lo ngx_http_geoip2_module-${NGX_GEOIP2_VER}.tar.gz https://github.com/leev/ngx_http_geoip2_module/archive/refs/tags/${NGX_GEOIP2_VER}.tar.gz \
# Download lua-resty-expr
    && curl -Lo lua-resty-expr-${RESTY_EXPR_VER}.tar.gz https://github.com/api7/lua-resty-expr/archive/refs/tags/v${RESTY_EXPR_VER}.tar.gz \
# Download lua-resty-ipmatcher
    && curl -Lo lua-resty-ipmatcher-${RESTY_IPMATCHER_VER}.tar.gz https://github.com/api7/lua-resty-ipmatcher/archive/refs/tags/v${RESTY_IPMATCHER_VER}.tar.gz \
# Download lua-resty-radixtree
    && curl -Lo lua-resty-radixtree-${RESTY_RADIXTREE_VER}.tar.gz https://github.com/api7/lua-resty-radixtree/archive/refs/tags/v${RESTY_RADIXTREE_VER}.tar.gz


### Build Stage
FROM rockylinux:9 AS builder

ARG OPENRESTY_VER \
    ZLIB_VER \
    PCRE2_VER \
    OPENSSL_VER \
    GEOIP_VER \
    LIBMAXMINDDB_VER \
    BROTLI_VER \
    NGX_BROTLI_VER \
    NGX_GEOIP2_VER \
    RESTY_EXPR_VER \
    RESTY_IPMATCHER_VER \
    RESTY_RADIXTREE_VER \
    USER \
    CONF_DIR \
    HOME_DIR \
    DATA_DIR \
    LOGS_DIR \
    LUA_LIB \
    BUILD_DIR

ENV OPENRESTY_VER=$OPENRESTY_VER \
    ZLIB_VER=$ZLIB_VER \
    PCRE2_VER=$PCRE2_VER \
    OPENSSL_VER=$OPENSSL_VER \
    GEOIP_VER=$GEOIP_VER \
    LIBMAXMINDDB_VER=$LIBMAXMINDDB_VER \
    BROTLI_VER=$BROTLI_VER \
    NGX_BROTLI_VER=$NGX_BROTLI_VER \
    NGX_GEOIP2_VER=$NGX_GEOIP2_VER \
    RESTY_EXPR_VER=$RESTY_EXPR_VER \
    RESTY_IPMATCHER_VER=$RESTY_IPMATCHER_VER \
    RESTY_RADIXTREE_VER=$RESTY_RADIXTREE_VER \
    USER=$USER \
    CONF_DIR=$CONF_DIR \
    HOME_DIR=$HOME_DIR \
    DATA_DIR=$DATA_DIR \
    LOGS_DIR=$LOGS_DIR \
    LUA_LIB=$LUA_LIB \
    BUILD_DIR=$BUILD_DIR

USER root
WORKDIR ${BUILD_DIR}


RUN set -x \
# Install development packages
    && dnf -q -d 0 install -y make cmake gcc gcc-c++ autoconf automake perl patch \
        diffutils libtool procps-ng gd-devel libxslt-devel libxml2-devel

COPY --from=downloader ${BUILD_DIR} ${BUILD_DIR}

# Install zlib
RUN set -x \
    && cd ${BUILD_DIR}/src \
    && tar -zxf ${BUILD_DIR}/pkg/zlib-${ZLIB_VER}.tar.gz \
    && cd zlib-${ZLIB_VER} \
    && ./configure --prefix=${HOME_DIR}/zlib \
    && make -j`nproc` CFLAGS='-O3 -fPIC -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN' \
      SFLAGS='-O3 -fPIC -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN' > build.log 2>&1 || { cat build.log ; exit 1; } \
    && make install > build.log 2>&1 || { cat build.log ; exit 1; } \
    && rm -rf ${HOME_DIR}/zlib/lib/*.la \
    && rm -rf ${HOME_DIR}/zlib/share

# Install pcre2
RUN set -x \
    && cd ${BUILD_DIR}/src \
    && tar -zxf ${BUILD_DIR}/pkg/pcre2-${PCRE2_VER}.tar.gz \
    && cd pcre2-${PCRE2_VER} \
    && CFLAGS="-fPIC -O3" ./configure \
      --prefix=${HOME_DIR}/pcre2 \
      --libdir=${HOME_DIR}/pcre2/lib \
      --enable-jit \
      --enable-pcre2grep-jit \
      --disable-bsr-anycrlf \
      --disable-coverage \
      --disable-ebcdic \
      --disable-fuzz-support \
      --disable-jit-sealloc \
      --disable-never-backslash-C \
      --enable-newline-is-lf \
      --enable-pcre2-8 \
      --enable-pcre2-16 \
      --enable-pcre2-32 \
      --enable-pcre2grep-callout \
      --enable-pcre2grep-callout-fork \
      --disable-pcre2grep-libbz2 \
      --disable-pcre2grep-libz \
      --disable-pcre2test-libedit \
      --enable-percent-zt \
      --disable-rebuild-chartables \
      --enable-shared \
      --disable-static \
      --disable-silent-rules \
      --enable-unicode \
      --disable-valgrind \
    && make -j`nproc` > build.log 2>&1 || { cat build.log ; exit 1; } \
    && make install > build.log 2>&1 || { cat build.log ; exit 1; } \
    && rm -rf ${HOME_DIR}/pcre2/lib/*.la \
    && rm -rf ${HOME_DIR}/pcre2/share

# Install openssl
RUN set -x \
    && cd ${BUILD_DIR}/src \
    && tar -zxf ${BUILD_DIR}/pkg/openssl-${OPENSSL_VER}.tar.gz \
    && cd openssl-${OPENSSL_VER} \
    && patch -p1 < ${BUILD_DIR}/pkg/openssl-${OPENSSL_VER}-sess_set_get_cb_yield.patch || exit 1 \
    && ./config \
      shared zlib \
      --prefix=${HOME_DIR}/openssl3 \
      --libdir=lib \
      enable-camellia enable-seed enable-rfc3779 \
      enable-cms enable-md2 enable-rc5 \
      enable-weak-ssl-ciphers \
      enable-ssl3 enable-ssl3-method \
      enable-md2 enable-ktls enable-fips \
      -I${HOME_DIR}/zlib/include \
      -L${HOME_DIR}/zlib/lib \
      -Wl,-rpath,${HOME_DIR}/zlib/lib:${HOME_DIR}/openssl3/lib \
    && make -j`nproc` > build.log 2>&1 || { cat build.log ; exit 1; } \
    && make install_sw > build.log 2>&1 || { cat build.log ; exit 1; }

# Install GeoIP
RUN set -x \
    && cd ${BUILD_DIR}/src \
    && tar -zxf ${BUILD_DIR}/pkg/GeoIP-${GEOIP_VER}.tar.gz \
    && cd GeoIP-${GEOIP_VER} \
    && ./bootstrap \
    && ./configure --prefix=${HOME_DIR}/GeoIP \
    && make -j`nproc` CFLAGS="-O3 -fPIC" > build.log 2>&1 || { cat build.log ; exit 1; } \
    && make install > build.log 2>&1 || { cat build.log ; exit 1; } \
    && rm -rf ${HOME_DIR}/GeoIP/lib/*.la \
    && rm -rf ${HOME_DIR}/GeoIP/share

# Install libmaxminddb
RUN set -x \
    && cd ${BUILD_DIR}/src \
    && tar -zxf ${BUILD_DIR}/pkg/libmaxminddb-${LIBMAXMINDDB_VER}.tar.gz \
    && cd libmaxminddb-${LIBMAXMINDDB_VER} \
    && ./configure --prefix=${HOME_DIR}/libmaxminddb \
    && make -j`nproc` > build.log 2>&1 || { cat build.log ; exit 1; } \
    && make install > build.log 2>&1 || { cat build.log ; exit 1; } \
    && rm -rf ${HOME_DIR}/libmaxminddb/lib/*.la \
    && rm -rf ${HOME_DIR}/libmaxminddb/share

# Install brotli && Unpack ngx_brotli, inject specific Brotli source into its deps
RUN set -x \
    && cd ${BUILD_DIR}/src \
    && tar -zxf ${BUILD_DIR}/pkg/brotli-${BROTLI_VER}.tar.gz \
    && cd brotli-${BROTLI_VER} \
    && mkdir out && cd out \
    && cmake -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${HOME_DIR}/brotli \
        -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,${HOME_DIR}/brotli/lib" \
        -DCMAKE_INSTALL_LIBDIR=lib .. > build.log 2>&1 || { cat build.log ; exit 1; } \
    && cmake --build . --config Release --target install > build.log 2>&1 || { cat build.log ; exit 1; } \
    && cd ../.. \
    && tar -zxf ${BUILD_DIR}/pkg/ngx_brotli-${NGX_BROTLI_VER}.tar.gz \
    && cd ngx_brotli-${NGX_BROTLI_VER} \
    && mv ../brotli-${BROTLI_VER} deps/ \
    && rm -fr deps/brotli \
    && mv deps/brotli-${BROTLI_VER} deps/brotli

# Unpack ngx_http_geoip2_module
RUN set -x \
    && cd ${BUILD_DIR}/src \
    && tar -zxf ${BUILD_DIR}/pkg/ngx_http_geoip2_module-${NGX_GEOIP2_VER}.tar.gz

# Install openresty
RUN set -x \
    && cd ${BUILD_DIR}/src \
    && tar -zxf ${BUILD_DIR}/pkg/openresty-${OPENRESTY_VER}.tar.gz \
    && cd openresty-${OPENRESTY_VER} \
    && ./configure \
         --prefix=${HOME_DIR} \
         --sbin-path=/usr/sbin/nginx \
         --conf-path=${CONF_DIR}/nginx.conf \
         --modules-path=${HOME_DIR}/nginx/modules \
         --error-log-path=${LOGS_DIR}/error.log \
         --http-log-path=${LOGS_DIR}/access.log \
         --pid-path=/run/nginx.pid \
         --lock-path=/run/nginx.lock \
         --http-client-body-temp-path=${DATA_DIR}/client_temp \
         --http-proxy-temp-path=${DATA_DIR}/proxy_temp \
         --http-fastcgi-temp-path=${DATA_DIR}/fastcgi_temp \
         --http-uwsgi-temp-path=${DATA_DIR}/uwsgi_temp \
         --http-scgi-temp-path=${DATA_DIR}/scgi_temp \
         --with-cc-opt=" \
           -DNGX_LUA_ABORT_AT_PANIC \
           -I${HOME_DIR}/zlib/include \
           -I${HOME_DIR}/pcre2/include \
           -I${HOME_DIR}/openssl3/include \
           -I${HOME_DIR}/GeoIP/include \
           -I${HOME_DIR}/libmaxminddb/include \
           -I${HOME_DIR}/brotli/include" \
         --with-ld-opt=" \
           -L${HOME_DIR}/zlib/lib \
           -L${HOME_DIR}/pcre2/lib \
           -L${HOME_DIR}/openssl3/lib \
           -L${HOME_DIR}/GeoIP/lib \
           -L${HOME_DIR}/libmaxminddb/lib \
           -L${HOME_DIR}/brotli/lib \
           -Wl,-rpath,${HOME_DIR}/zlib/lib:${HOME_DIR}/pcre2/lib:${HOME_DIR}/openssl3/lib:${HOME_DIR}/GeoIP/lib:${HOME_DIR}/libmaxminddb/lib:${HOME_DIR}/brotli/lib" \
        --with-http_iconv_module \
        --with-select_module \
        --with-poll_module \
        --with-threads \
        --with-file-aio \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_v3_module \
        --with-http_realip_module \
        --with-http_addition_module \
        --with-http_xslt_module \
        --with-http_image_filter_module \
        --with-http_geoip_module \
        --with-http_sub_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_mp4_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_auth_request_module \
        --with-http_random_index_module \
        --with-http_secure_link_module \
        --with-http_degradation_module \
        --with-http_slice_module \
        --with-http_stub_status_module \
        --with-mail \
        --with-mail_ssl_module \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_realip_module \
        --with-stream_geoip_module \
        --with-stream_ssl_preread_module \
        --with-compat \
        --with-pcre \
        --with-pcre-jit \
        --add-module=${BUILD_DIR}/src/ngx_http_geoip2_module-${NGX_GEOIP2_VER} \
        --add-module=${BUILD_DIR}/src/ngx_brotli-${NGX_BROTLI_VER} \
        --with-luajit-xcflags='-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT' \
    && make -j`nproc` > build.log 2>&1 || { cat build.log ; exit 1; } \
    && make install

# Install lua-resty-expr
RUN set -x \
    && cd ${BUILD_DIR}/src \
    && tar -zxf ${BUILD_DIR}/pkg/lua-resty-expr-${RESTY_EXPR_VER}.tar.gz \
    && cd lua-resty-expr-${RESTY_EXPR_VER} \
    && install -d ${LUA_LIB}/resty/expr \
    && install lib/resty/expr/*.lua ${LUA_LIB}/resty/expr

# Install lua-resty-ipmatcher
RUN set -x \
    && cd ${BUILD_DIR}/src \
    && tar -zxf ${BUILD_DIR}/pkg/lua-resty-ipmatcher-${RESTY_IPMATCHER_VER}.tar.gz \
    && cd lua-resty-ipmatcher-${RESTY_IPMATCHER_VER} \
    && make install INST_LUADIR=${LUA_LIB}

# Install lua-resty-radixtree
RUN set -x \
    && cd ${BUILD_DIR}/src \
    && tar -zxf ${BUILD_DIR}/pkg/lua-resty-radixtree-${RESTY_RADIXTREE_VER}.tar.gz \
    && cd lua-resty-radixtree-${RESTY_RADIXTREE_VER} \
    && make \
    && make install INST_LUADIR=${LUA_LIB} INST_LIBDIR=${LUA_LIB}


### Runtime Stage
FROM rockylinux:9-minimal

ARG USER \
    CONF_DIR \
    HOME_DIR \
    DATA_DIR \
    LOGS_DIR \
    LUA_LIB

ENV USER=$USER \
    CONF_DIR=$CONF_DIR \
    HOME_DIR=$HOME_DIR \
    DATA_DIR=$DATA_DIR \
    LOGS_DIR=$LOGS_DIR \
    LUA_LIB=$LUA_LIB

COPY --from=builder ${CONF_DIR} ${CONF_DIR}
COPY --from=builder ${HOME_DIR} ${HOME_DIR}
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx

RUN set -x \
# Add nginx user
    && getent group $USER >/dev/null || groupadd -r $USER -g 101 \
    && getent passwd $USER >/dev/null || useradd -r -u 101 -g $USER -s /sbin/nologin \
        -d ${DATA_DIR} -m -c "$USER user" $USER \
# Create the directories required for Tengine dependencies
    && mkdir -p ${DATA_DIR} ${LOGS_DIR} \
# Install required packages
    && microdnf install -y findutils gd libxslt libxml2 \
    && microdnf clean all

# Add Lua paths
ENV LUA_PATH="${LUA_LIB}/?.lua;${LUA_LIB}/?/init.lua;${HOME_DIR}/luajit/share/luajit-2.1/?.lua;./?.lua;/usr/local/share/luajit-2.1/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua"
ENV LUA_CPATH="${LUA_LIB}/?.so;./?.so;/usr/local/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/loadall.so"

# Add custom compiled binaries to the PATH
ENV PATH=$HOME_DIR/pcre2/bin:$HOME_DIR/openssl3/bin:$HOME_DIR/GeoIP/bin:$HOME_DIR/libmaxminddb/bin:$HOME_DIR/brotli/bin:$HOME_DIR/luajit/bin:$HOME_DIR/bin:$PATH

# Set the working directory to the Tengine home directory
WORKDIR ${HOME_DIR}

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

# Expose Nginx ports
EXPOSE 80 443

# Start the Nginx server
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]

# Set the signal that will be used to stop the container
STOPSIGNAL SIGQUIT
