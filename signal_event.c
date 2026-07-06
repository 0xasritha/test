#include <windows.h>

int wmain(void) {
    HANDLE handle = OpenEventW(
        EVENT_MODIFY_STATE,
        FALSE,
        L"RasAutoDialSharedConnectionEvent"
    );
    if (!handle) {
        return (int)GetLastError();
    }

    BOOL ok = SetEvent(handle);
    CloseHandle(handle);
    return ok ? 0 : (int)GetLastError();
}
