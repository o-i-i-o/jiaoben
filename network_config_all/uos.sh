#!/bin/bash
# generate_deb_packages.sh - 批量生成以IP命名的deb网络配置包（修改现有配置）

# 配置参数
OUTPUT_DIR="./deb_packages"
mkdir -p "$OUTPUT_DIR"

# 主机配置数组 (IP地址/前缀 网关 DNS1,DNS2 接口名)
HOSTS=(
    "192.168.1.101/24 192.168.1.1 8.8.8.8,8.8.4.4 enp8s0"
    "192.168.1.102/24 192.168.1.1 114.114.114.114,192.168.1.1 enp8s0"
)

for host_cfg in "${HOSTS[@]}"; do
    IFS=' ' read -r ip_addr gateway dns interface <<< "$host_cfg"
    IFS=',' read -ra dns_servers <<< "$dns"
    
    # 从IP地址生成包名 (替换.为-)
    pkg_name="network-config-$(echo "$ip_addr" | tr './' '-')"
    pkg_dir="$OUTPUT_DIR/$pkg_name"
    
    # 创建deb包结构
    mkdir -p "$pkg_dir/DEBIAN"
    
    # 生成control文件
    cat > "$pkg_dir/DEBIAN/control" <<EOF
Package: $pkg_name
Version: 1.0
Section: admin
Priority: optional
Architecture: all
Maintainer: Network Admin <admin@example.com>
Description: Static network configuration for $ip_addr
 Configures static IP $ip_addr with gateway $gateway
EOF

    # 生成postinst安装脚本（修改现有配置）
    cat > "$pkg_dir/DEBIAN/postinst" <<EOF
#!/bin/bash
# 安装后修改网络配置为静态IP

CONFIG_FILE="/etc/NetworkManager/system-connections/Wired Connection.nmconnection"

# 1. 备份原始配置
BACKUP_FILE="\$CONFIG_FILE.bak.\$(date +%Y%m%d%H%M%S)"
if [ ! -f "\$BACKUP_FILE" ]; then
    cp "\$CONFIG_FILE" "\$BACKUP_FILE"
    echo "原始配置已备份到: \$BACKUP_FILE"
fi

# 2. 修改现有配置文件
sed -i -e '/^\[ipv4\]/,/^\[/ {
    /^method=/c\method=manual
    /^address1=/d
    /^dns=/d
    /^ignore-auto-dns=/c\ignore-auto-dns=true
    a\address1=$ip_addr,$gateway
    a\dns=${dns_servers[0]};${dns_servers[1]};
}' "\$CONFIG_FILE"

# 3. 确保接口名称正确
sed -i -e "s/^interface-name=.*/interface-name=$interface/" "\$CONFIG_FILE"

# 4. 设置文件权限
chmod 600 "\$CONFIG_FILE"
chown root:root "\$CONFIG_FILE"

# 5. 重新加载配置
nmcli connection reload
if nmcli connection show --active | grep -q "有线连接"; then
    nmcli connection down "有线连接" && nmcli connection up "有线连接"
fi

# 6. 标记已安装
echo "$ip_addr" > /etc/.network-static-config

exit 0
EOF

    # 生成prerm卸载脚本（恢复备份）
    cat > "$pkg_dir/DEBIAN/prerm" <<EOF
#!/bin/bash
# 卸载前恢复原始配置

# 检查是否是升级操作
if [ "\$1" = "upgrade" ]; then
    exit 0
fi

# 查找最新的备份文件
BACKUP_FILE=\$(ls -t /etc/NetworkManager/system-connections/Wired\ Connection.nmconnection.bak.* 2>/dev/null | head -1)

if [ -f "\$BACKUP_FILE" ] && [ -f "/etc/.network-static-config" ]; then
    echo "正在从备份恢复网络配置..."
    cp "\$BACKUP_FILE" "/etc/NetworkManager/system-connections/Wired Connection.nmconnection"
    
    # 重新加载配置
    nmcli connection reload
    if nmcli connection show --active | grep -q "有线连接"; then
        nmcli connection down "有线连接" && nmcli connection up "有线连接"
    fi
    
    rm -f /etc/.network-static-config
fi

exit 0
EOF

    # 设置脚本权限
    chmod 755 "$pkg_dir/DEBIAN/postinst"
    chmod 755 "$pkg_dir/DEBIAN/prerm"
    
    # 构建deb包
    dpkg-deb --build "$pkg_dir" "$OUTPUT_DIR/${pkg_name}_1.0_all.deb"
    rm -rf "$pkg_dir"
    
    echo "已生成: $OUTPUT_DIR/${pkg_name}_1.0_all.deb"
done

echo "所有deb包已生成到 $OUTPUT_DIR 目录"
