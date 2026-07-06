#include <windows.h>

#include <wchar.h>

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

    wchar_t cmdline[2048];
    cmdline[0] = 0;
    for (int i = first_arg; i < argc; ++i) {
        if (i != first_arg) {
            wcscat_s(cmdline, 2048, L" ");
        }
        wcscat_s(cmdline, 2048, argv[i]);
    }

    STARTUPINFOW si = {0};
    PROCESS_INFORMATION pi = {0};
    si.cb = sizeof(si);
    si.lpDesktop = L"winsta0\\default";

    BOOL ok = CreateProcessWithLogonW(
        L"Guest",
        L"ASRITHA-WINDOWS",
        L"password",
        LOGON_WITH_PROFILE,
        NULL,
        cmdline,
        CREATE_NEW_CONSOLE,
        NULL,
        L"C:\\Users\\Public\\Desktop\\EXPLOIT",
        &si,
        &pi
    );
    if (!ok) {
        return (int)GetLastError();
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
