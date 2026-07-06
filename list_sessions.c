#include <windows.h>
#include <wtsapi32.h>

#include <stdio.h>

#pragma comment(lib, "wtsapi32.lib")

static const wchar_t* state_name(WTS_CONNECTSTATE_CLASS state) {
    switch (state) {
    case WTSActive:
        return L"Active";
    case WTSConnected:
        return L"Connected";
    case WTSConnectQuery:
        return L"ConnectQuery";
    case WTSShadow:
        return L"Shadow";
    case WTSDisconnected:
        return L"Disconnected";
    case WTSIdle:
        return L"Idle";
    case WTSListen:
        return L"Listen";
    case WTSReset:
        return L"Reset";
    case WTSDown:
        return L"Down";
    case WTSInit:
        return L"Init";
    default:
        return L"Unknown";
    }
}

int wmain(void) {
    PWTS_SESSION_INFOW sessions = NULL;
    DWORD count = 0;

    if (!WTSEnumerateSessionsW(WTS_CURRENT_SERVER_HANDLE, 0, 1, &sessions, &count)) {
        return (int)GetLastError();
    }

    for (DWORD i = 0; i < count; ++i) {
        LPWSTR user = NULL;
        DWORD user_len = 0;
        LPWSTR domain = NULL;
        DWORD domain_len = 0;

        WTSQuerySessionInformationW(
            WTS_CURRENT_SERVER_HANDLE,
            sessions[i].SessionId,
            WTSUserName,
            &user,
            &user_len
        );
        WTSQuerySessionInformationW(
            WTS_CURRENT_SERVER_HANDLE,
            sessions[i].SessionId,
            WTSDomainName,
            &domain,
            &domain_len
        );

        wprintf(
            L"id=%lu state=%ls station=%ls user=%ls\\\\%ls\n",
            sessions[i].SessionId,
            state_name(sessions[i].State),
            sessions[i].pWinStationName ? sessions[i].pWinStationName : L"",
            domain ? domain : L"",
            user ? user : L""
        );

        if (user) {
            WTSFreeMemory(user);
        }
        if (domain) {
            WTSFreeMemory(domain);
        }
    }

    WTSFreeMemory(sessions);
    return 0;
}
