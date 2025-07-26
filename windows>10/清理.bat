@echo off
setlocal EnableDelayedExpansion

:: =============================================
:: ���տɿ���ϵͳ����ű�
:: �޸�������ԱȨ�޼������
:: ������������Դ�����������ʹ�õ��ļ���
:: ����������Chrome�����ʹ�ü�¼
:: �Ľ����Զ�ǿ�ƹر�Chromeʵ��ȫ�Զ�����
:: =============================================

:: ʹ�ü򵥿ɿ��ķ���������־�ļ���
set "timestamp=%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%"
set "timestamp=!timestamp: =0!"  REM �滻�ո�Ϊ0
set "logFile=%TEMP%\SystemCleanup_%timestamp%.log"

:: ��ʼ����־
echo [%time%] ϵͳ������־ - %date% > "%logFile%"
echo [%time%] �ű�·��: %~f0 >> "%logFile%"

:: ��ɿ��Ĺ���ԱȨ�޼��
fsutil dirty query %SystemDrive% >nul 2>&1
if %errorlevel% neq 0 (
    echo [%time%] ������Ҫ����ԱȨ�� >> "%logFile%"
    echo.
    echo ������Ҫ����ԱȨ�����д˽ű�
    echo ���Ҽ������˽ű���ѡ��"�Թ���Ա�������"
    echo.
    pause
    exit /b 1
)

echo [%time%] �ѻ�ȡ����ԱȨ�� >> "%logFile%"
echo ����ִ��ϵͳ������ȴ������Զ��ر�......

:: ������ǿ�ƹر�Chrome�����
call :CloseChrome

:: ����ϵͳ��ʱĿ¼ - ɾ����������
if exist "%TEMP%\" call :CleanAll "%TEMP%"

:: ��������Ŀ¼ - ɾ����������
if exist "%USERPROFILE%\Downloads\" call :CleanAll "%USERPROFILE%\Downloads"

:: �����ĵ�Ŀ¼ - ɾ����������
if exist "%USERPROFILE%\Documents\" call :CleanAll "%USERPROFILE%\Documents"

:: ��ȫ�������棨����ϵͳ�ļ��Ϳ�ݷ�ʽ����ɾ�������ļ��У�
set "desktopPath=%USERPROFILE%\Desktop"
if exist "%desktopPath%\" (
    echo [%time%] ��������: %desktopPath% >> "%logFile%"
    call :CleanDesktop "%desktopPath%"
)

:: ���д���������
start /B /WAIT cleanmgr /sagerun:1 >nul 2>&1

:: �������վ
PowerShell -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" 2>&1 >> "%logFile%"

:: ����Windows��ʱĿ¼ - ɾ����������
if exist "%WINDIR%\Temp\" call :CleanAll "%WINDIR%\Temp"

:: ����ϵͳ���»���
net stop wuauserv >nul 2>&1
if !errorlevel! equ 0 (  REM �޸�������� if �� !errorlevel! ֮��Ŀո�
    if exist "%WINDIR%\SoftwareDistribution\Download\" (
        call :CleanAll "%WINDIR%\SoftwareDistribution\Download"
    )
    net start wuauserv >nul 2>&1
)

:: ����Prefetch�ļ������������3����
if exist "%WINDIR%\Prefetch\" (
    cd /d "%WINDIR%\Prefetch\"
    for /f "skip=3 delims=" %%F in ('dir /a-d /b /o-d *.* 2^>nul') do (
        del /f /q "%%F" >nul 2>&1
    )
)

:: ������������Դ�����������ʹ�õ��ļ�����¼
echo [%time%] ������Դ�����������ʹ�õ��ļ�����¼ >> "%logFile%"
del /F /Q "%APPDATA%\Microsoft\Windows\Recent\*" >nul 2>&1
del /F /Q "%APPDATA%\Microsoft\Windows\Recent\AutomaticDestinations\*" >nul 2>&1
del /F /Q "%APPDATA%\Microsoft\Windows\Recent\CustomDestinations\*" >nul 2>&1

:: ����������Chrome�����ʹ�ü�¼
echo [%time%] ����Chrome�����ʹ�ü�¼ >> "%logFile%"
call :CleanChromeData

:: �����ʾ
echo [%time%] ϵͳ������ɣ� >> "%logFile%"
echo.
echo ϵͳ������ɣ�
echo ��־�ļ�λ��: "%logFile%"
timeout /t 3 >nul
exit /b

:: ================== �������� ==================

:: ��ȫ����Ŀ¼��ɾ���������ݣ�
:CleanAll
set "target=%~1"
if not exist "%target%\" exit /b

echo [%time%] ��ȫ����Ŀ¼: %target% >> "%logFile%"

:: ɾ�������ļ����������غ�ϵͳ�ļ���
del /f /q /a "%target%\*" >nul 2>&1

:: ɾ��������Ŀ¼���������غ�ϵͳ�ļ��У�
for /d %%D in ("%target%\*") do (
    rd /s /q "%%D" >nul 2>&1 || (
        echo [%time%] ���棺�޷�ɾ���ļ��� "%%D" >> "%logFile%"
    )
)
exit /b

:: ����ר����������ϵͳ�ļ��Ϳ�ݷ�ʽ��ɾ�������ļ��У�
:CleanDesktop
set "deskPath=%~1"

:: ɾ�����������ļ��У�������ϵͳ���ԣ�
for /d %%D in ("%deskPath%\*") do (
    rd /s /q "%%D" >nul 2>&1 || (
        echo [%time%] ���棺�޷�ɾ�������ļ��� "%%D" >> "%logFile%"
    )
)

:: ���������ļ���������ݷ�ʽ��ϵͳ�ļ���
for %%F in ("%deskPath%\*") do (
     if /i not "%%~xF"==".lnk" if /i not "%%~xF"==".url" (
        attrib "%%F" | findstr /c:" S " >nul || (
            del /f /q "%%F" >nul 2>&1 || (
                echo [%time%] ���棺�޷�ɾ�������ļ� "%%F" >> "%logFile%"
            )
        )
    )
)
exit /b

:: ������ǿ�ƹر�Chrome�����
:CloseChrome
echo [%time%] ���ڼ�鲢�ر�Chrome�����... >> "%logFile%"

:: ���Chrome�Ƿ���������
tasklist /FI "IMAGENAME eq chrome.exe" 2>NUL | find /I /N "chrome.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo [%time%] ��⵽Chrome�������У����Թر�... >> "%logFile%"
    
    :: ���������ر�
    taskkill /F /IM chrome.exe /T >nul 2>&1
    
    :: ��֤�Ƿ��ѹر�
    timeout /t 2 >nul
    tasklist /FI "IMAGENAME eq chrome.exe" 2>NUL | find /I /N "chrome.exe">NUL
    if "%ERRORLEVEL%"=="0" (
        echo [%time%] ���棺Chromeδ�����رգ�����ǿ����ֹ... >> "%logFile%"
        taskkill /F /IM chrome.exe /T >nul 2>&1
        
        :: �ٴ���֤
        timeout /t 2 >nul
        tasklist /FI "IMAGENAME eq chrome.exe" 2>NUL | find /I /N "chrome.exe">NUL
        if "%ERRORLEVEL%"=="0" (
            echo [%time%] �����޷��ر�Chrome���������������Chrome���� >> "%logFile%"
            exit /b 1
        ) else (
            echo [%time%] �ɹ�ǿ�ƹر�Chrome����� >> "%logFile%"
        )
    ) else (
        echo [%time%] �ɹ��ر�Chrome����� >> "%logFile%"
    )
) else (
    echo [%time%] Chrome�����δ���� >> "%logFile%"
)
exit /b

:: ����Chrome���������
:CleanChromeData
set "chromeDataDir=%LOCALAPPDATA%\Google\Chrome\User Data\Default"

if exist "%chromeDataDir%" (
    echo [%time%] ����Chrome���������: %chromeDataDir% >> "%logFile%"
    
    :: ɾ����ʷ��¼
    if exist "%chromeDataDir%\History" del /f /q "%chromeDataDir%\History" >> "%logFile%" 2>&1
    
    :: ɾ������
    if exist "%chromeDataDir%\Cache" call :CleanAll "%chromeDataDir%\Cache"
    
    :: ɾ��Cookie
    if exist "%chromeDataDir%\Cookies" del /f /q "%chromeDataDir%\Cookies" >> "%logFile%" 2>&1
    
    :: ɾ��������ʷ
    if exist "%chromeDataDir%\Download History" del /f /q "%chromeDataDir%\Download History" >> "%logFile%" 2>&1
    
    :: ɾ��������
    if exist "%chromeDataDir%\Web Data" del /f /q "%chromeDataDir%\Web Data" >> "%logFile%" 2>&1
    
    :: ɾ������
    if exist "%chromeDataDir%\Login Data" del /f /q "%chromeDataDir%\Login Data" >> "%logFile%" 2>&1
    
    :: ɾ��������Ự
    if exist "%chromeDataDir%\Session Storage" call :CleanAll "%chromeDataDir%\Session Storage"
    
    :: ɾ��������ʱ����
    del /f /q "%chromeDataDir%\* Preferences" >> "%logFile%" 2>&1
    del /f /q "%chromeDataDir%\Top Sites" >> "%logFile%" 2>&1
    del /f /q "%chromeDataDir%\Visited Links" >> "%logFile%" 2>&1
)
exit /b