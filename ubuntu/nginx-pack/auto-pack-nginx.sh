#!/bin/bash
set -e

# 定义颜色输出函数
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
nc='\033[0m' 

# ====================== 核心配置（统一路径命名，避免混乱） ======================
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# 版本配置
NGINX_VERSION="1.29.4"
OPENSSL_VERSION="3.6.0"

# 下载链接
NGINX_DOWNLOAD_URL="https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"
OPENSSL_DOWNLOAD_URL="https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz"

# 路径配置（绝对路径，避免相对路径混乱）
NGINX_TAR="${SCRIPT_DIR}/nginx-${NGINX_VERSION}.tar.gz"
OPENSSL_TAR="${SCRIPT_DIR}/openssl-${OPENSSL_VERSION}.tar.gz"
OPENSSL_SRC="${SCRIPT_DIR}/openssl-${OPENSSL_VERSION}"
NGINX_SRC="${SCRIPT_DIR}/nginx-${NGINX_VERSION}"

# Deb包配置
DEB_PACKAGE_NAME="nginx"
DEB_ARCH=$(dpkg --print-architecture)
DEB_OUTPUT_DIR="${SCRIPT_DIR}"
DEB_COMMON="${SCRIPT_DIR}/nginx-base"
DEB_WORK="${SCRIPT_DIR}/install-nginx"

# 1. 初始化：清理历史目录，创建工作目录
# 前置检查root权限（必须）
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${red}❌ 错误：请使用root权限执行此脚本（sudo ./xxx.sh）${nc}"
        exit 1
    fi
}
check_root

rm -rf "$DEB_WORK" "$OPENSSL_SRC" "$NGINX_SRC"
echo -e "${green}✅ 清理完成！${nc}"

mkdir -p "$DEB_WORK"

# 2. 下载源码
echo -e "\n${blue}========== 下载源码包 ==========${nc}"
download_file() {
    local url="$1"
    local dest="$2"
    local filename=$(basename "$dest")

    if [ -f "$dest" ] && [ -s "$dest" ]; then
        echo -e "${green}✓ 本地已存在 ${filename}，跳过下载${nc}"
        return 0
    fi

    echo -e "${yellow}📥 正在下载 ${filename}...${nc}"
    if ! wget -c -t 3 -q --show-progress --no-check-certificate -O "$dest" "$url"; then
        echo -e "${red}❌ 下载 ${filename} 失败！${nc}"
        rm -f "$dest"
        exit 1
    fi

    if [ ! -s "$dest" ]; then
        echo -e "${red}❌ ${filename} 下载为空！${nc}"
        rm -f "$dest"
        exit 1
    fi
    echo -e "${green}✓ ${filename} 下载完成${nc}"
}

download_file "${NGINX_DOWNLOAD_URL}" "${NGINX_TAR}"
download_file "${OPENSSL_DOWNLOAD_URL}" "${OPENSSL_TAR}"

# 3. 高效检查并安装编译依赖
check_compile_deps() {
    echo -e "\n${blue}========== 高效检查并安装编译依赖 ==========${nc}"
    # 定义需要的依赖列表
    local required_deps=(
        gcc g++ make cmake autoconf automake libtool
        zlib1g-dev libpcre2-dev libpcre2-8-0 libssl-dev libatomic1
        libgeoip-dev libperl-dev libxslt1-dev libgd-dev
        dh-make devscripts debhelper dpkg-dev fakeroot
        wget curl apt-utils
    )

    # 批量检查已安装的依赖
    echo -e "${yellow}🔍 批量检查依赖安装状态...${nc}"
    local missing_deps=()
    for dep in "${required_deps[@]}"; do
        if ! dpkg -l "${dep}" 2>/dev/null | grep -q "^ii"; then
            missing_deps+=("${dep}")
        fi
    done

    # 仅当有缺失依赖时更新源+安装
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${yellow}📡 刷新apt源缓存...${nc}"
        apt update -qq &>/dev/null

        # 一次性安装所有缺失的依赖
        echo -e "${yellow}📦 安装缺失的依赖：${missing_deps[*]}${nc}"
        apt install -y -qq --no-install-recommends "${missing_deps[@]}" &>/dev/null

        # 验证安装结果
        local still_missing=()
        for dep in "${missing_deps[@]}"; do
            if ! dpkg -l "${dep}" 2>/dev/null | grep -q "^ii"; then
                still_missing+=("${dep}")
            fi
        done
        if [ ${#still_missing[@]} -gt 0 ]; then
            echo -e "${yellow}⚠️  以下依赖未安装（非必需，尝试继续编译）：${still_missing[*]}${nc}"
        else
            echo -e "${green}✓ 所有编译依赖已安装完成${nc}"
        fi
    else
        echo -e "${green}✓ 所有编译依赖已安装，无需操作${nc}"
    fi
}

check_compile_deps

# 4. 编译Nginx

    echo -e "\n${blue}========== 编译Nginx（OpenSSL ${OPENSSL_VERSION}） ==========${nc}"
    # 解压源码
    rm -rf "${NGINX_SRC}" "${OPENSSL_SRC}"
    tar zxf "${NGINX_TAR}" -C "${SCRIPT_DIR}" &>/dev/null
    tar zxf "${OPENSSL_TAR}" -C "${SCRIPT_DIR}" &>/dev/null

    # 编译配置
    cd "${NGINX_SRC}" || { echo -e "${red}❌ 进入Nginx源码目录失败${nc}"; exit 1; }
    echo -e "${yellow}🔧 执行configure配置 ${nc}"

./configure \
--with-cc-opt='-g -O2 -Werror=implicit-function-declaration -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer -ffile-prefix-map=/build/nginx-8acHtg/nginx-1.29.4=. -flto=auto -ffat-lto-objects -fstack-protector-strong -fstack-clash-protection -Wformat -Werror=format-security -fcf-protection -fdebug-prefix-map=/build/nginx-8acHtg/nginx-1.29.4=/usr/src/nginx-1.29.4-6ubuntu1 -fPIC -Wdate-time -D_FORTIFY_SOURCE=3' \
--with-ld-opt='-Wl,-Bsymbolic-functions -flto=auto -ffat-lto-objects -Wl,-z,relro -Wl,-z,now -fPIC' \
--prefix=/usr/share/nginx \
--sbin-path=/usr/sbin/nginx \
--conf-path=/etc/nginx/nginx.conf \
--http-log-path=/var/log/nginx/access.log \
--error-log-path=stderr \
--lock-path=/var/lock/nginx.lock \
--pid-path=/run/nginx.pid \
--modules-path=/usr/lib/nginx/modules \
--http-client-body-temp-path=/var/lib/nginx/body \
--http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
--http-proxy-temp-path=/var/lib/nginx/proxy \
--http-scgi-temp-path=/var/lib/nginx/scgi \
--http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
--with-compat \
--with-debug \
--with-pcre-jit \
--with-http_ssl_module \
--with-http_stub_status_module \
--with-http_realip_module \
--with-http_auth_request_module \
--with-http_v2_module \
--with-http_v3_module \
--with-http_dav_module \
--with-http_slice_module \
--with-threads \
--build=oi-io \
--with-http_addition_module \
--with-http_flv_module \
--with-http_gunzip_module \
--with-http_gzip_static_module \
--with-http_mp4_module \
--with-http_random_index_module \
--with-http_secure_link_module \
--with-http_sub_module \
--with-mail_ssl_module \
--with-stream_ssl_module \
--with-stream_ssl_preread_module \
--with-stream_realip_module \
--with-http_geoip_module=dynamic \
--with-http_image_filter_module=dynamic \
--with-http_perl_module=dynamic \
--with-http_xslt_module=dynamic \
--with-mail=dynamic \
--with-stream=dynamic \
--with-stream_geoip_module=dynamic \
--with-openssl="${OPENSSL_SRC}"

echo -e "${green}✅ 参数配置完成！${nc}"
echo 。。。开始编译。。。
make -j$(nproc)
echo -e "${green}✅ 编译完成！${nc}"

make install DESTDIR="$DEB_WORK/"
echo -e "${green}✅ 安装到打包目录${nc}"

cp -uvpfr "$DEB_COMMON/"* "$DEB_WORK/"
echo -e "${green}✅ 基础文件复制完成！${nc}"

#文件校验
chmod +x "$DEB_WORK"/make-md5sums
cd "$DEB_WORK"/  && ./make-md5sums
rm -f "$DEB_WORK"/make-md5sums
cd -
echo -e "${green}✅ 结束校验！${nc}"

package_deb() {
echo -e "\n${blue}========== 打包Deb包 ==========${nc}"
# 定义唯一的包文件名
local deb_file="${SCRIPT_DIR}/${DEB_PACKAGE_NAME}_${NGINX_VERSION}_${DEB_ARCH}.deb"
    
# 删除旧包（避免重复）
rm -f "${deb_file}"
    
# 打包
echo -e "${yellow}🔧 生成Deb包：${deb_file}${nc}"
dpkg-deb --build "$DEB_WORK/" "${deb_file}" 

    echo -e "${green}✅ Deb包打包完成！${nc}"
    echo -e "${green}📦 包路径：${deb_file}${nc}"
    echo -e "\n${yellow}🔍 包信息：${nc}"
    dpkg -I "${deb_file}" | grep -E "Package|Version|Depends|Provides"
}
package_deb

exit 0
