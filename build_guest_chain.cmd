@echo off
setlocal

call "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\VsDevCmd.bat" -arch=amd64
if errorlevel 1 exit /b 1

cd /d C:\Users\Public\Desktop\EXPLOIT

cl /nologo /EHsc /std:c++17 /W3 /O2 /MT exploit_host2.cpp /link /out:exploit_host2.exe
if errorlevel 1 exit /b 1

cl /nologo /W3 /O2 /MT /LD /DUNICODE /D_UNICODE pwn.c /link advapi32.lib /out:pwn.dll
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

exit /b 0
