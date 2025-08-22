<#
.SYNOPSIS
    生成批量网络配置BAT脚本（ANSI编码）
.DESCRIPTION
    此脚本会为多台PC生成独立的BAT网络配置脚本（使用ANSI编码），
    每个脚本以IPv4地址命名并配置相应的IPv4和IPv6地址。
.NOTES
    文件名: Generate-NetworkConfigBATScripts.ps1
    版本: 1.4
   !重要
   1. 在powershell窗口先执行 
    Set-ExecutionPolicy Bypass -Scope Process -Force 
    再运行此脚本
   2.win10的powershell对utf-8编码支持不好，若是使用直接下载的脚本，中文会乱码，建议使用记事本等工具转换为ansi或者gb18030等编码再运行。
   3. 依赖powershell，在win10、win11测试可用。
#>

# 配置参数
$outputFolder = "C:\NetworkConfigBATScripts"
$subnetMask = "255.255.255.0" #IPv4掩码
$ipv6PrefixLength = "112"  # IPv6前缀
$defaultGatewayIPv4 = "192.168.4.1"
$defaultGatewayIPv6 = "FE80::D23A"  # IPv6网关
$dnsServersIPv4 = @("114.114.114.114", "192.168.6.6")  #IPv4 DNS
$dnsServersIPv6 = @("2400:3200::1", "fd0a::6") #IPv6 DNS
$testServer = "aliyun.com"  # 测试连通性的服务器

# 定义PC列表，我自己使用excel生成IP信息粘贴过来运行；
# 因为我的需求是ipv4和ipv6一一对应，且不具备可简单复用的规律，所以使用此方法。
$pcList = @(
  @{ IPv4 = "192.168.4.10"; IPv6 = "2001::2:5" }
@{ IPv4 = "192.168.4.11"; IPv6 = "2001::2:6" }
excel公式：'@{ IPv4 = "&ipv4单元格& '"; IPv6 = "&ipv6单元格&'" }  因为双引号会被识别为公式，所以在每个单元格前面加个'符号，此处公式&旁边是一个单元格完整的内容

)

# 创建输出目录
if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory $outputFolder | Out-Null
}

foreach ($pc in $pcList) {
    $ipv4 = $pc.IPv4
    $ipv6 = $pc.IPv6
    $scriptPath = "$outputFolder\$ipv4.bat"
    $currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # 生成BAT脚本内容
    $batContent = @"
@echo off
:: Windows网络静态配置脚本 - $ipv4
:: 生成时间: $currentTime
:: 需要以管理员身份运行此脚本

:: 获取管理员权限
%1 mshta vbscript:CreateObject("Shell.Application").ShellExecute("cmd.exe","/c %~s0 ::","","runas",1)(window.close)&&exit cd /d "%~dp0"

:: 智能检测活动物理网卡
echo 正在检测活动网络接口...
for /f "delims=" %%i in ('powershell -command "(Get-NetAdapter -Physical | Where-Object { `$_.Status -eq 'Up' -and `$_.Name -notlike '*Loopback*' } | Select-Object -First 1).Name"') do (
    set "interfaceName=%%i"
)

if "%interfaceName%"=="" (
    echo 错误: 未找到活动的物理网络适配器
    pause
    exit /b 1
)

echo 已选择网络接口: "%interfaceName%"

:: 显示当前配置
echo [当前配置]
ipconfig | findstr /i "IPv4 IPv6"
echo.

:: 配置IPv4地址
echo 正在配置IPv4地址: $ipv4
netsh interface ipv4 set address "%interfaceName%" static $ipv4 $subnetMask $defaultGatewayIPv4 1
IF %ERRORLEVEL% NEQ 0 (
    echo 错误: 配置IPv4地址失败
    pause
    exit /b 1
)

:: 配置IPv6地址
echo 正在配置IPv6地址: $ipv6
netsh interface ipv6 set address "%interfaceName%" $ipv6/$ipv6PrefixLength
IF %ERRORLEVEL% NEQ 0 (
    echo 错误: 配置IPv6地址失败
    pause
    exit /b 1
)

:: 配置IPv6网关（使用PowerShell）
echo 正在配置IPv6网关: $defaultGatewayIPv6
powershell -Command "`$interface = Get-NetAdapter -Name '%interfaceName%' -ErrorAction SilentlyContinue; if (`$interface) { try { Remove-NetRoute -DestinationPrefix '::/0' -InterfaceAlias `$interface.Name -Confirm:`$false -ErrorAction SilentlyContinue; New-NetRoute -InterfaceAlias `$interface.Name -DestinationPrefix '::/0' -NextHop '$defaultGatewayIPv6' -ErrorAction Stop; Write-Host 'IPv6网关配置成功!' -ForegroundColor Green } catch { Write-Host '配置失败: ' + `$_.Exception.Message -ForegroundColor Red } } else { Write-Host '未找到网卡: %interfaceName%!' -ForegroundColor Red }"

:: 配置DNS服务器
echo 正在配置DNS服务器...
echo 设置IPv4 DNS: $($dnsServersIPv4[0]) 和 $($dnsServersIPv4[1])
netsh interface ipv4 set dns "%interfaceName%" static $($dnsServersIPv4[0]) primary >nul
netsh interface ipv4 add dns "%interfaceName%" $($dnsServersIPv4[1]) index=2 >nul 

echo 设置IPv6 DNS: $($dnsServersIPv6[0]) 和 $($dnsServersIPv6[1])
netsh interface ipv6 set dns "%interfaceName%" static $($dnsServersIPv6[0]) primary >nul
netsh interface ipv6 add dns "%interfaceName%" $($dnsServersIPv6[1]) index=2 >nul 

:: 显示配置结果
echo.
echo [新配置]
ipconfig /all | findstr /i "IPv4 IPv6 Subnet Default Gateway DNS Servers"

echo.

echo 配置完成，等待网卡响应
timeout /t 6 /nobreak 

:: 测试网络连接
echo.
echo 正在测试网络连接...
ping -4 -n 2 $testServer >nul && (
    echo IPv4 服务器 $testServer 可达
) || (
    echo 警告: IPv4 服务器 $testServer 不可达
)

ping -6 -n 2 $testServer >nul && (
    echo IPv6 服务器 $testServer 可达
) || (
    echo 警告: IPv6 服务器 $testServer 不可达
)

echo.
echo 打开系统网络设置可视化检查配置！
ncpa.cpl
pause
"@

    # 以ANSI编码保存文件
    $batContent | Out-File $scriptPath -Encoding Default
    Write-Host "已生成: $scriptPath"
}

Write-Host "`n脚本生成完成，请以管理员身份运行生成的BAT文件" -ForegroundColor Green


