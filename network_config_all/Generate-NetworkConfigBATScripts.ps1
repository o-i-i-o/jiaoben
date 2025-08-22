<#
.SYNOPSIS
    ����������������BAT�ű���ANSI���룩
.DESCRIPTION
    �˽ű���Ϊ��̨PC���ɶ�����BAT�������ýű���ʹ��ANSI���룩��
    ÿ���ű���IPv4��ַ������������Ӧ��IPv4��IPv6��ַ��
.NOTES
    �ļ���: Generate-NetworkConfigBATScripts.ps1
    �汾: 1.4
    ���£���ָ����BAT�ű��߼���ȫһ��
    ��powershell������ִ�� Set-ExecutionPolicy Bypass -Scope Process -Force �����нű�
#>

# ���ò���
$outputFolder = "C:\NetworkConfigBATScripts"
$subnetMask = "255.255.255.0"
$ipv6PrefixLength = "96"  # ��ʾ������һ��
$defaultGatewayIPv4 = "192.168.2.1"
$defaultGatewayIPv6 = "FE80::D238"  # ��ʾ������һ��
$dnsServersIPv4 = @("114.114.114.114", "192.168.6.6")
$dnsServersIPv6 = @("2400:3200::1", "fd0a::6")
$testServer = "aliyun.com"  # ������ͨ�Եķ�����

# ����PC�б�
$pcList = @(
    @{ IPv4 = "192.168.2.10"; IPv6 = "240E:638::1031:3" }
    @{ IPv4 = "192.168.2.11"; IPv6 = "240E:638::1031:4" }
    @{ IPv4 = "192.168.2.12"; IPv6 = "240E:638::1031:5" }
)

# �������Ŀ¼
if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory $outputFolder | Out-Null
}

foreach ($pc in $pcList) {
    $ipv4 = $pc.IPv4
    $ipv6 = $pc.IPv6
    $scriptPath = "$outputFolder\$ipv4.bat"
    $currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # ����BAT�ű�����
    $batContent = @"
@echo off
:: Windows���羲̬���ýű� - $ipv4
:: ����ʱ��: $currentTime
:: ��Ҫ�Թ���Ա������д˽ű�

:: ��ȡ����ԱȨ��
%1 mshta vbscript:CreateObject("Shell.Application").ShellExecute("cmd.exe","/c %~s0 ::","","runas",1)(window.close)&&exit cd /d "%~dp0"

:: ���ܼ����������
echo ���ڼ������ӿ�...
for /f "delims=" %%i in ('powershell -command "(Get-NetAdapter -Physical | Where-Object { `$_.Status -eq 'Up' -and `$_.Name -notlike '*Loopback*' } | Select-Object -First 1).Name"') do (
    set "interfaceName=%%i"
)

if "%interfaceName%"=="" (
    echo ����: δ�ҵ������������������
    pause
    exit /b 1
)

echo ��ѡ������ӿ�: "%interfaceName%"

:: ��ʾ��ǰ����
echo [��ǰ����]
ipconfig | findstr /i "IPv4 IPv6"
echo.

:: ����IPv4��ַ
echo ��������IPv4��ַ: $ipv4
netsh interface ipv4 set address "%interfaceName%" static $ipv4 $subnetMask $defaultGatewayIPv4 1
IF %ERRORLEVEL% NEQ 0 (
    echo ����: ����IPv4��ַʧ��
    pause
    exit /b 1
)

:: ����IPv6��ַ
echo ��������IPv6��ַ: $ipv6
netsh interface ipv6 set address "%interfaceName%" $ipv6/$ipv6PrefixLength
IF %ERRORLEVEL% NEQ 0 (
    echo ����: ����IPv6��ַʧ��
    pause
    exit /b 1
)

:: ����IPv6���أ�ʹ��PowerShell��
echo ��������IPv6����: $defaultGatewayIPv6
powershell -Command "$interface = Get-NetAdapter -Name '%interfaceName%' -ErrorAction SilentlyContinue; if ($interface) { try { Remove-NetRoute -DestinationPrefix '::/0' -InterfaceAlias $interface.Name -Confirm:`$false -ErrorAction SilentlyContinue; New-NetRoute -InterfaceAlias $interface.Name -DestinationPrefix '::/0' -NextHop '$defaultGatewayIPv6' -ErrorAction Stop; Write-Host 'IPv6�������óɹ�!' -ForegroundColor Green } catch { Write-Host '����ʧ��: ' + `$_.Exception.Message -ForegroundColor Red } } else { Write-Host 'δ�ҵ�����: %interfaceName%!' -ForegroundColor Red }"

:: ����DNS������
echo ��������DNS������...
echo ����IPv4 DNS: $($dnsServersIPv4[0]) �� $($dnsServersIPv4[1])
netsh interface ipv4 set dns "%interfaceName%" static $($dnsServersIPv4[0]) primary >nul
netsh interface ipv4 add dns "%interfaceName%" $($dnsServersIPv4[1]) index=2 >nul 

echo ����IPv6 DNS: $($dnsServersIPv6[0]) �� $($dnsServersIPv6[1])
netsh interface ipv6 set dns "%interfaceName%" static $($dnsServersIPv6[0]) primary >nul
netsh interface ipv6 add dns "%interfaceName%" $($dnsServersIPv6[1]) index=2 >nul 

:: ��ʾ���ý��
echo.
echo [������]
ipconfig /all | findstr /i "IPv4 IPv6 Subnet Default Gateway DNS Servers"

echo.

echo �ȴ���������
timeout /t 6 /nobreak 

:: ������������
echo.
echo ���ڲ�����������...
ping -4 -n 2 $testServer >nul && (
    echo IPv4 ������ $testServer �ɴ�
) || (
    echo ����: IPv4 ������ $testServer ���ɴ�
)

ping -6 -n 2 $testServer >nul && (
    echo IPv6 ������ $testServer �ɴ�
) || (
    echo ����: IPv6 ������ $testServer ���ɴ�
)

echo.
echo �����������!��ϵͳ�������ÿ��ӻ�������ã�
ncpa.cpl
pause
"@

    # ��ANSI���뱣���ļ�
    $batContent | Out-File $scriptPath -Encoding Default
    Write-Host "������: $scriptPath"
}

Write-Host "`n�ű�������ɣ����Թ���Ա����������ɵ�BAT�ļ�" -ForegroundColor Green
