@echo off
setlocal EnableDelayedExpansion

:: =============================================
:: 最终可靠版系统清理脚本
:: 修复：管理员权限检查问题
:: 新增：清理资源管理器“最近使用的文件”
:: 新增：清理Chrome浏览器使用记录
:: 改进：自动强制关闭Chrome实现全自动清理
:: =============================================

:: 使用简单可靠的方法创建日志文件名
set "timestamp=%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%"
set "timestamp=!timestamp: =0!"  REM 替换空格为0
set "logFile=%TEMP%\SystemCleanup_%timestamp%.log"

:: 初始化日志
echo [%time%] 系统清理日志 - %date% > "%logFile%"
echo [%time%] 脚本路径: %~f0 >> "%logFile%"

:: 最可靠的管理员权限检查
fsutil dirty query %SystemDrive% >nul 2>&1
if %errorlevel% neq 0 (
    echo [%time%] 错误：需要管理员权限 >> "%logFile%"
    echo.
    echo 错误：需要管理员权限运行此脚本
    echo 请右键单击此脚本，选择"以管理员身份运行"
    echo.
    pause
    exit /b 1
)

echo [%time%] 已获取管理员权限 >> "%logFile%"
echo 正在执行系统清理，请等待窗口自动关闭......

:: 新增：强制关闭Chrome浏览器
call :CloseChrome

:: 清理系统临时目录 - 删除所有内容
if exist "%TEMP%\" call :CleanAll "%TEMP%"

:: 清理下载目录 - 删除所有内容
if exist "%USERPROFILE%\Downloads\" call :CleanAll "%USERPROFILE%\Downloads"

:: 清理文档目录 - 删除所有内容
if exist "%USERPROFILE%\Documents\" call :CleanAll "%USERPROFILE%\Documents"

:: 安全清理桌面（保留系统文件和快捷方式，但删除所有文件夹）
set "desktopPath=%USERPROFILE%\Desktop"
if exist "%desktopPath%\" (
    echo [%time%] 清理桌面: %desktopPath% >> "%logFile%"
    call :CleanDesktop "%desktopPath%"
)

:: 运行磁盘清理工具
start /B /WAIT cleanmgr /sagerun:1 >nul 2>&1

:: 清理回收站
PowerShell -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" 2>&1 >> "%logFile%"

:: 清理Windows临时目录 - 删除所有内容
if exist "%WINDIR%\Temp\" call :CleanAll "%WINDIR%\Temp"

:: 清理系统更新缓存
net stop wuauserv >nul 2>&1
if !errorlevel! equ 0 (  REM 修复：添加了 if 和 !errorlevel! 之间的空格
    if exist "%WINDIR%\SoftwareDistribution\Download\" (
        call :CleanAll "%WINDIR%\SoftwareDistribution\Download"
    )
    net start wuauserv >nul 2>&1
)

:: 清理Prefetch文件（保留最近的3个）
if exist "%WINDIR%\Prefetch\" (
    cd /d "%WINDIR%\Prefetch\"
    for /f "skip=3 delims=" %%F in ('dir /a-d /b /o-d *.* 2^>nul') do (
        del /f /q "%%F" >nul 2>&1
    )
)

:: 新增：清理资源管理器“最近使用的文件”记录
echo [%time%] 清理资源管理器“最近使用的文件”记录 >> "%logFile%"
del /F /Q "%APPDATA%\Microsoft\Windows\Recent\*" >nul 2>&1
del /F /Q "%APPDATA%\Microsoft\Windows\Recent\AutomaticDestinations\*" >nul 2>&1
del /F /Q "%APPDATA%\Microsoft\Windows\Recent\CustomDestinations\*" >nul 2>&1

:: 新增：清理Chrome浏览器使用记录
echo [%time%] 清理Chrome浏览器使用记录 >> "%logFile%"
call :CleanChromeData

:: 完成提示
echo [%time%] 系统清理完成！ >> "%logFile%"
echo.
echo 系统清理完成！
echo 日志文件位置: "%logFile%"
timeout /t 3 >nul
exit /b

:: ================== 函数定义 ==================

:: 完全清理目录（删除所有内容）
:CleanAll
set "target=%~1"
if not exist "%target%\" exit /b

echo [%time%] 完全清理目录: %target% >> "%logFile%"

:: 删除所有文件（包括隐藏和系统文件）
del /f /q /a "%target%\*" >nul 2>&1

:: 删除所有子目录（包括隐藏和系统文件夹）
for /d %%D in ("%target%\*") do (
    rd /s /q "%%D" >nul 2>&1 || (
        echo [%time%] 警告：无法删除文件夹 "%%D" >> "%logFile%"
    )
)
exit /b

:: 桌面专用清理（保留系统文件和快捷方式，删除所有文件夹）
:CleanDesktop
set "deskPath=%~1"

:: 删除桌面所有文件夹（不区分系统属性）
for /d %%D in ("%deskPath%\*") do (
    rd /s /q "%%D" >nul 2>&1 || (
        echo [%time%] 警告：无法删除桌面文件夹 "%%D" >> "%logFile%"
    )
)

:: 清理桌面文件（保留快捷方式和系统文件）
for %%F in ("%deskPath%\*") do (
     if /i not "%%~xF"==".lnk" if /i not "%%~xF"==".url" (
        attrib "%%F" | findstr /c:" S " >nul || (
            del /f /q "%%F" >nul 2>&1 || (
                echo [%time%] 警告：无法删除桌面文件 "%%F" >> "%logFile%"
            )
        )
    )
)
exit /b

:: 新增：强制关闭Chrome浏览器
:CloseChrome
echo [%time%] 正在检查并关闭Chrome浏览器... >> "%logFile%"

:: 检查Chrome是否正在运行
tasklist /FI "IMAGENAME eq chrome.exe" 2>NUL | find /I /N "chrome.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo [%time%] 检测到Chrome正在运行，尝试关闭... >> "%logFile%"
    
    :: 尝试正常关闭
    taskkill /F /IM chrome.exe /T >nul 2>&1
    
    :: 验证是否已关闭
    timeout /t 2 >nul
    tasklist /FI "IMAGENAME eq chrome.exe" 2>NUL | find /I /N "chrome.exe">NUL
    if "%ERRORLEVEL%"=="0" (
        echo [%time%] 警告：Chrome未正常关闭，正在强制终止... >> "%logFile%"
        taskkill /F /IM chrome.exe /T >nul 2>&1
        
        :: 再次验证
        timeout /t 2 >nul
        tasklist /FI "IMAGENAME eq chrome.exe" 2>NUL | find /I /N "chrome.exe">NUL
        if "%ERRORLEVEL%"=="0" (
            echo [%time%] 错误：无法关闭Chrome浏览器，跳过清理Chrome数据 >> "%logFile%"
            exit /b 1
        ) else (
            echo [%time%] 成功强制关闭Chrome浏览器 >> "%logFile%"
        )
    ) else (
        echo [%time%] 成功关闭Chrome浏览器 >> "%logFile%"
    )
) else (
    echo [%time%] Chrome浏览器未运行 >> "%logFile%"
)
exit /b

:: 清理Chrome浏览器数据
:CleanChromeData
set "chromeDataDir=%LOCALAPPDATA%\Google\Chrome\User Data\Default"

if exist "%chromeDataDir%" (
    echo [%time%] 清理Chrome浏览器数据: %chromeDataDir% >> "%logFile%"
    
    :: 删除历史记录
    if exist "%chromeDataDir%\History" del /f /q "%chromeDataDir%\History" >> "%logFile%" 2>&1
    
    :: 删除缓存
    if exist "%chromeDataDir%\Cache" call :CleanAll "%chromeDataDir%\Cache"
    
    :: 删除Cookie
    if exist "%chromeDataDir%\Cookies" del /f /q "%chromeDataDir%\Cookies" >> "%logFile%" 2>&1
    
    :: 删除下载历史
    if exist "%chromeDataDir%\Download History" del /f /q "%chromeDataDir%\Download History" >> "%logFile%" 2>&1
    
    :: 删除表单数据
    if exist "%chromeDataDir%\Web Data" del /f /q "%chromeDataDir%\Web Data" >> "%logFile%" 2>&1
    
    :: 删除密码
    if exist "%chromeDataDir%\Login Data" del /f /q "%chromeDataDir%\Login Data" >> "%logFile%" 2>&1
    
    :: 删除浏览器会话
    if exist "%chromeDataDir%\Session Storage" call :CleanAll "%chromeDataDir%\Session Storage"
    
    :: 删除其他临时数据
    del /f /q "%chromeDataDir%\* Preferences" >> "%logFile%" 2>&1
    del /f /q "%chromeDataDir%\Top Sites" >> "%logFile%" 2>&1
    del /f /q "%chromeDataDir%\Visited Links" >> "%logFile%" 2>&1
)
exit /b
