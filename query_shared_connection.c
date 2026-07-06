#include <windows.h>
#include <stdio.h>

typedef DWORD (WINAPI* RasQuerySharedConnectionFn)(DWORD*);

int wmain(void) {
    HMODULE module = LoadLibraryW(L"rasapi32.dll");
    if (!module) {
        wprintf(L"LoadLibrary failed: %lu\n", GetLastError());
        return 1;
    }

    RasQuerySharedConnectionFn fn =
        (RasQuerySharedConnectionFn)GetProcAddress(module, "RasQuerySharedConnectionW");
    if (!fn) {
        fn = (RasQuerySharedConnectionFn)GetProcAddress(module, "RasQuerySharedConnection");
    }
    if (!fn) {
        wprintf(L"GetProcAddress failed: %lu\n", GetLastError());
        return 2;
    }

    DWORD value = 0;
    DWORD err = fn(&value);
    wprintf(L"RasQuerySharedConnection -> err=%lu value=%lu (0x%08lx)\n", err, value, value);
    return (int)err;
}
