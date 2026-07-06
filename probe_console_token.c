#include <windows.h>
#include <wtsapi32.h>

#include <lmcons.h>
#include <stdio.h>

#pragma comment(lib, "wtsapi32.lib")
#pragma comment(lib, "advapi32.lib")

int wmain(void) {
    DWORD session_id = WTSGetActiveConsoleSessionId();
    wprintf(L"session=%lu\n", session_id);

    HANDLE token = NULL;
    if (!WTSQueryUserToken(session_id, &token)) {
        wprintf(L"WTSQueryUserToken err=%lu\n", GetLastError());
        return 0;
    }

    if (!ImpersonateLoggedOnUser(token)) {
        wprintf(L"ImpersonateLoggedOnUser err=%lu\n", GetLastError());
        CloseHandle(token);
        return 0;
    }

    WCHAR user[UNLEN + 1];
    DWORD size = UNLEN + 1;
    if (!GetUserNameW(user, &size)) {
        wprintf(L"GetUserNameW err=%lu\n", GetLastError());
    } else {
        wprintf(L"user=%ls\n", user);
    }

    RevertToSelf();
    CloseHandle(token);
    return 0;
}
