#include <windows.h>
#include <tlhelp32.h>
#include <userenv.h>
#include <wtsapi32.h>

#include <stdio.h>
#include <wchar.h>

#pragma comment(lib, "Advapi32.lib")
#pragma comment(lib, "Userenv.lib")
#pragma comment(lib, "Wtsapi32.lib")

static void print_last_error(const wchar_t* operation, DWORD error) {
    wchar_t message[512];
    DWORD flags = FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS;
    DWORD length = FormatMessageW(
        flags, NULL, error, 0, message, (DWORD)(sizeof(message) / sizeof(message[0])), NULL
    );
    if (length == 0) {
        fwprintf(stderr, L"[!] %ls failed with error %lu\n", operation, error);
        return;
    }
    while (length > 0 &&
           (message[length - 1] == L'\r' || message[length - 1] == L'\n')) {
        message[--length] = 0;
    }
    fwprintf(stderr, L"[!] %ls failed with error %lu: %ls\n", operation, error, message);
}

static void enable_privilege(const wchar_t* name) {
    HANDLE token = NULL;
    if (!OpenProcessToken(
            GetCurrentProcess(),
            TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY,
            &token
        )) {
        return;
    }
    TOKEN_PRIVILEGES privileges = {0};
    privileges.PrivilegeCount = 1;
    if (!LookupPrivilegeValueW(NULL, name, &privileges.Privileges[0].Luid)) {
        CloseHandle(token);
        return;
    }
    privileges.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
    AdjustTokenPrivileges(token, FALSE, &privileges, 0, NULL, NULL);
    CloseHandle(token);
}

static DWORD find_console_pid(DWORD session_id) {
    static const wchar_t* names[] = {L"explorer.exe", L"userinit.exe", L"RuntimeBroker.exe"};
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot == INVALID_HANDLE_VALUE) {
        return 0;
    }
    PROCESSENTRY32W entry = {sizeof(entry)};
    for (BOOL ok = Process32FirstW(snapshot, &entry); ok; ok = Process32NextW(snapshot, &entry)) {
        DWORD process_session = 0;
        if (!ProcessIdToSessionId(entry.th32ProcessID, &process_session) ||
            process_session != session_id) {
            continue;
        }
        for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); ++i) {
            if (_wcsicmp(entry.szExeFile, names[i]) == 0) {
                CloseHandle(snapshot);
                return entry.th32ProcessID;
            }
        }
    }
    CloseHandle(snapshot);
    return 0;
}

int wmain(int argc, wchar_t** argv) {
    int wait = 0;
    int first_arg = 1;
    if (argc > 1 && wcscmp(argv[1], L"--wait") == 0) {
        wait = 1;
        first_arg = 2;
    }
    if (argc <= first_arg) {
        return 64;
    }

    enable_privilege(L"SeDebugPrivilege");
    enable_privilege(L"SeImpersonatePrivilege");

    wchar_t cmdline[2048];
    cmdline[0] = 0;
    for (int i = first_arg; i < argc; ++i) {
        if (i != first_arg) {
            wcscat_s(cmdline, 2048, L" ");
        }
        wcscat_s(cmdline, 2048, argv[i]);
    }

    DWORD session_id = WTSGetActiveConsoleSessionId();
    DWORD pid = find_console_pid(session_id);
    if (pid == 0) {
        fputws(L"[!] could not find a console user process\n", stderr);
        return 1;
    }

    HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!process) {
        print_last_error(L"OpenProcess", GetLastError());
        return 2;
    }

    HANDLE token = NULL;
    if (!OpenProcessToken(
            process,
            TOKEN_DUPLICATE | TOKEN_ASSIGN_PRIMARY | TOKEN_QUERY | TOKEN_IMPERSONATE,
            &token
        )) {
        print_last_error(L"OpenProcessToken", GetLastError());
        CloseHandle(process);
        return 3;
    }
    CloseHandle(process);

    HANDLE primary = NULL;
    if (!DuplicateTokenEx(
            token,
            MAXIMUM_ALLOWED,
            NULL,
            SecurityImpersonation,
            TokenPrimary,
            &primary
        )) {
        print_last_error(L"DuplicateTokenEx", GetLastError());
        CloseHandle(token);
        return 4;
    }
    CloseHandle(token);

    STARTUPINFOW si = {0};
    PROCESS_INFORMATION pi = {0};
    si.cb = sizeof(si);
    si.lpDesktop = L"winsta0\\default";
    BOOL ok = CreateProcessWithTokenW(
        primary,
        LOGON_WITH_PROFILE,
        NULL,
        cmdline,
        CREATE_NO_WINDOW,
        NULL,
        L"C:\\Users\\Public\\Desktop\\EXPLOIT",
        &si,
        &pi
    );
    DWORD error = ok ? 0 : GetLastError();
    CloseHandle(primary);
    if (!ok) {
        print_last_error(L"CreateProcessWithTokenW", error);
        return (int)error;
    }

    if (wait) {
        WaitForSingleObject(pi.hProcess, INFINITE);
        DWORD code = 0;
        GetExitCodeProcess(pi.hProcess, &code);
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
        return (int)code;
    }

    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return 0;
}
