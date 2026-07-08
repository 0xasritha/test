#include <windows.h>

#include <wchar.h>

static int parse_args(
    int argc,
    wchar_t** argv,
    int* wait,
    const wchar_t** user,
    const wchar_t** password,
    int* first_arg
) {
    *wait = 0;
    *user = L"guestlab";
    *password = L"password";
    *first_arg = 1;

    while (*first_arg < argc) {
        if (wcscmp(argv[*first_arg], L"--wait") == 0) {
            *wait = 1;
            ++*first_arg;
            continue;
        }
        if (wcscmp(argv[*first_arg], L"--user") == 0) {
            ++*first_arg;
            if (*first_arg >= argc) {
                return 64;
            }
            *user = argv[*first_arg];
            ++*first_arg;
            continue;
        }
        if (wcscmp(argv[*first_arg], L"--password") == 0) {
            ++*first_arg;
            if (*first_arg >= argc) {
                return 64;
            }
            *password = argv[*first_arg];
            ++*first_arg;
            continue;
        }
        break;
    }

    if (argc <= *first_arg) {
        return 64;
    }
    return 0;
}

int wmain(int argc, wchar_t** argv) {
    int wait = 0;
    const wchar_t* user = L"guestlab";
    const wchar_t* password = L"password";
    int first_arg = 1;
    int parse_status = parse_args(
        argc,
        argv,
        &wait,
        &user,
        &password,
        &first_arg
    );
    if (parse_status != 0) {
        return parse_status;
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

    BOOL ok = CreateProcessWithLogonW(
        user,
        L".",
        password,
        LOGON_WITH_PROFILE,
        NULL,
        cmdline,
        CREATE_NO_WINDOW,
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
