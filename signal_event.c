#include <windows.h>
#include <stdio.h>

static void print_last_error(const wchar_t* operation, const wchar_t* name, DWORD error) {
    wchar_t message[512];
    DWORD flags = FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS;
    DWORD length = FormatMessageW(
        flags,
        NULL,
        error,
        0,
        message,
        (DWORD)(sizeof(message) / sizeof(message[0])),
        NULL
    );
    if (length == 0) {
        wprintf(L"[!] %ls(%ls) failed with error %lu\n", operation, name, error);
        return;
    }

    while (length > 0 &&
           (message[length - 1] == L'\r' || message[length - 1] == L'\n')) {
        message[length - 1] = 0;
        --length;
    }
    wprintf(L"[!] %ls(%ls) failed with error %lu: %ls\n", operation, name, error, message);
}

static int signal_named_event(const wchar_t* name) {
    wprintf(L"[+] Trying event: %ls\n", name);
    HANDLE handle = OpenEventW(EVENT_MODIFY_STATE, FALSE, name);
    if (!handle) {
        DWORD error = GetLastError();
        print_last_error(L"OpenEventW", name, error);
        return (int)error;
    }

    wprintf(L"[+] Opened event handle\n");
    BOOL ok = SetEvent(handle);
    CloseHandle(handle);
    if (!ok) {
        DWORD error = GetLastError();
        print_last_error(L"SetEvent", name, error);
        return (int)error;
    }

    wprintf(L"[+] SetEvent succeeded\n");
    return 0;
}

int wmain(void) {
    int status = signal_named_event(L"RasAutoDialSharedConnectionEvent");
    if (status == 0) {
        return 0;
    }

    if (status == ERROR_FILE_NOT_FOUND) {
        wprintf(L"[+] Retrying with Global namespace\n");
        return signal_named_event(L"Global\\RasAutoDialSharedConnectionEvent");
    }
    return status;
}
