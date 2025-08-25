#!/bin/bash

echo 手动配置子网IPv6地址
LIPv6="2001:db8:b84b:2::/112"
echo "配置的子网ipv6地址：$LIPv6"
# 定义日志函数
log_info() {
    echo "[INFO] $1"
}

# 检查脚本是否以 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
    log_info "请使用 root 权限运行此脚本"
    exit 1
fi


log_info "OpenVPN AS IPv6 自动配置脚本启动"

# 检测可用的物理网络接口
log_info "正在检测可用的物理网络接口..."
interfaces=()
index=1

for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$'); do
    # 检查是否为物理接口
    if [ -d "/sys/class/net/$iface/device" ]; then
        interfaces+=("$iface")
        log_info "[$index] $iface"
        ((index++))
    fi
done

# 获取用户选择的网络接口
if [ ${#interfaces[@]} -eq 0 ]; then
    log_info "未检测到可用的物理网络接口"
    exit 1
elif [ ${#interfaces[@]} -eq 1 ]; then
    selected_index=1
    log_info "仅检测到一个网络接口，自动选择: ${interfaces[0]}"
else
    read -p "请输入网卡编号 [1-${#interfaces[@]}]: " selected_index
    # 验证用户输入
    if ! [[ "$selected_index" =~ ^[0-9]+$ ]] || [ "$selected_index" -lt 1 ] || [ "$selected_index" -gt ${#interfaces[@]} ]; then
        log_info "无效的网卡编号"
        exit 1
    fi
fi

selected_interface=${interfaces[$((selected_index-1))]}
log_info "已选择网卡: $selected_interface"

# 检测网卡的 IPv6 地址
log_info "正在检测网卡 $selected_interface 的IPv6地址..."
ipv6_addresses=()
index=1

while IFS= read -r line; do
    ipv6_address=$(echo "$line" | awk '{print $2}' | cut -d/ -f1)
    # 过滤掉链路本地地址
    if ! [[ "$ipv6_address" =~ ^fe80: ]]; then
        ipv6_addresses+=("$ipv6_address")
        log_info "[$index] $ipv6_address"
        ((index++))
    fi
done < <(ip -6 addr show dev "$selected_interface" scope global | grep 'inet6 ')

# 获取用户选择的 IPv6 地址
if [ ${#ipv6_addresses[@]} -eq 0 ]; then
    log_info "未检测到网卡 $selected_interface 上的全局 IPv6 地址"
    exit 1
elif [ ${#ipv6_addresses[@]} -eq 1 ]; then
    selected_ipv6_index=1
    log_info "仅检测到一个 IPv6 地址，自动选择: ${ipv6_addresses[0]}"
else
    read -p "请输入IPv6地址编号 [1-${#ipv6_addresses[@]}]: " selected_ipv6_index
    # 验证用户输入
    if ! [[ "$selected_ipv6_index" =~ ^[0-9]+$ ]] || [ "$selected_ipv6_index" -lt 1 ] || [ "$selected_ipv6_index" -gt ${#ipv6_addresses[@]} ]; then
        log_info "无效的 IPv6 地址编号"
        exit 1
    fi
fi

selected_ipv6=${ipv6_addresses[$((selected_ipv6_index-1))]}
log_info "已选择IPv6地址: $selected_ipv6"

# 开始配置 OpenVPN AS IPv6 设置
log_info "开始配置 OpenVPN AS IPv6 设置..."
cd /usr/local/openvpn_as/scripts/ || exit

# 配置 OpenVPN AS IPv6 参数
./sacli --key "vpn.routing6.enable" --value "true" ConfigPut
./sacli --key "vpn.client.routing6.reroute_gw" --value "true" ConfigPut
./sacli --key "vpn.server.daemon.vpn_network6.0" --value "${LIPv6}" ConfigPut

# 注意：这里使用用户选择的接口和 IPv6 地址
./sacli --key "vpn.server.routing6.snat_source.0" --value "$selected_interface:$selected_ipv6" ConfigPut

log_info "OpenVPN AS IPv6 配置完成"

# 重启 OpenVPN AS 服务
log_info "正在重启 OpenVPN AS 服务..."
./sacli start

log_info "OpenVPN AS 已成功重启"
log_info "OpenVPN AS IPv6 配置已完成！"
log_info "网络接口: $selected_interface"
log_info "IPv6 地址: $selected_ipv6"    
