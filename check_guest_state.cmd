@echo off
setlocal

cd /d C:\Users\Public\Desktop\EXPLOIT

echo [quser]
quser
echo.
echo [list_sessions]
list_sessions.exe
echo.
echo [probe_console_token]
probe_console_token.exe
echo.
echo [administrators]
net localgroup Administrators
