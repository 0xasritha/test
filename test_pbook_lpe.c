#include <windows.h>
#include <ras.h>
#include <stdio.h>

#pragma comment(lib, "rasapi32.lib")

int wmain(void) {
    const wchar_t* pbk = L"C:\\Users\\Public\\Desktop\\EXPLOIT\\pwn.pbk";
    const wchar_t* entry = L"LpeLabVpn";

    DWORD validate = RasValidateEntryNameW((LPWSTR)pbk, (LPWSTR)entry);
    wprintf(L"RasValidateEntryNameW -> %lu\n", validate);

    RASENTRYNAMEW names[8];
    ZeroMemory(names, sizeof(names));
    for (int i = 0; i < 8; ++i) {
        names[i].dwSize = sizeof(RASENTRYNAMEW);
    }
    DWORD names_size = sizeof(names);
    DWORD count = 0;
    DWORD enum_err = RasEnumEntriesW(NULL, (LPWSTR)pbk, names, &names_size, &count);
    wprintf(L"RasEnumEntriesW -> %lu count=%lu size=%lu\n", enum_err, count, names_size);
    for (DWORD i = 0; i < count && i < 8; ++i) {
        wprintf(L"  [%lu] %ls\n", i, names[i].szEntryName);
    }

    DWORD size = 6724;
    DWORD device_size = 0;
    BYTE* buffer = (BYTE*)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, size);
    if (!buffer) {
        return 1;
    }
    ((LPRASENTRYW)buffer)->dwSize = sizeof(RASENTRYW);
    DWORD props = RasGetEntryPropertiesW(
        (LPWSTR)pbk,
        (LPWSTR)entry,
        (LPRASENTRYW)buffer,
        &size,
        NULL,
        &device_size
    );
    wprintf(
        L"RasGetEntryPropertiesW -> %lu size=%lu device_size=%lu device=%ls phone=%ls dll=%hs\n",
        props,
        size,
        device_size,
        ((LPRASENTRYW)buffer)->szDeviceName,
        ((LPRASENTRYW)buffer)->szLocalPhoneNumber,
        ((LPRASENTRYW)buffer)->szCustomDialDll
    );
    HeapFree(GetProcessHeap(), 0, buffer);
    return 0;
}
