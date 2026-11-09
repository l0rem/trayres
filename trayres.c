// trayres: tray icon that switches the primary display between a few modes.
// Plain Win32, no CRT. See README.md.
#define WIN32_LEAN_AND_MEAN
#define UNICODE
#define _UNICODE
#include <windows.h>
#include <shellapi.h>

#define WM_TRAY    (WM_APP + 1)
#define ID_MODE    100
#define ID_STARTUP 200
#define ID_EXIT    201
#define MAX_MODES  16
#define X_OF(v)    ((int)(short)LOWORD(v))
#define Y_OF(v)    ((int)(short)HIWORD(v))

typedef struct { DWORD w, h, hz; } Mode; // hz 0 = highest the monitor lists

static const WCHAR kRun[] = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
static const char kDefaultIni[] =
    "; trayres display modes, one per line: WIDTH x HEIGHT @ HZ\r\n"
    "; If the monitor doesn't list HZ for that size, the highest it lists is used.\r\n"
    "; Leave out \"@ HZ\" to always use the highest. Changes apply the next time you open the menu.\r\n"
    "[modes]\r\n"
    "2560x1440@480\r\n"
    "1440x1080@480\r\n"
    "1920x1080@480\r\n";

static HWND g_hwnd;
static UINT g_taskbarCreated;
static NOTIFYICONDATAW g_nid;
static Mode g_modes[MAX_MODES];
static DWORD g_freq[MAX_MODES]; // resolved refresh rate, 0 = size not offered
static int g_count;
static WCHAR g_exe[MAX_PATH], g_ini[MAX_PATH];
static char g_buf[4096];

// The compiler may emit memset for zeroed structs; there is no CRT to provide it.
void *memset(void *d, int c, SIZE_T n) {
    void *p = d;
    __asm__ volatile("rep stosb" : "+D"(p), "+c"(n) : "a"(c) : "memory");
    return d;
}

static void trim(void) { SetProcessWorkingSetSize(GetCurrentProcess(), (SIZE_T)-1, (SIZE_T)-1); }

static void parse(const char *s) {
    g_count = 0;
    while (*s && g_count < MAX_MODES) {
        DWORD num[3] = {0}; int n = 0, in = 0;
        if (*s != ';' && *s != '#' && *s != '[') {
            for (; *s && *s != '\n' && *s != ';' && n < 3; s++) {
                if (*s >= '0' && *s <= '9') { num[n] = num[n] * 10 + (DWORD)(*s - '0'); in = 1; }
                else if (in) { n++; in = 0; }
            }
            if (in) n++;
        }
        if (n >= 2 && num[0] && num[1]) {
            g_modes[g_count].w = num[0]; g_modes[g_count].h = num[1];
            g_modes[g_count].hz = n >= 3 ? num[2] : 0;
            g_count++;
        }
        while (*s && *s != '\n') s++;
        if (*s) s++;
    }
}

// Re-read the config and match each mode against what the monitor offers.
static void refresh(void) {
    DWORD got = 0;
    HANDLE f = CreateFileW(g_ini, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                           NULL, OPEN_EXISTING, 0, NULL);
    if (f != INVALID_HANDLE_VALUE) { ReadFile(f, g_buf, sizeof g_buf - 1, &got, NULL); CloseHandle(f); }
    g_buf[got] = 0;
    parse(f != INVALID_HANDLE_VALUE ? g_buf : kDefaultIni);

    for (int i = 0; i < g_count; i++) g_freq[i] = 0;
    DEVMODEW dm = {0};
    dm.dmSize = sizeof dm;
    for (DWORD k = 0; EnumDisplaySettingsW(NULL, k, &dm); k++) {
        if (dm.dmBitsPerPel != 32 || (dm.dmDisplayFlags & DM_INTERLACED)) continue;
        for (int i = 0; i < g_count; i++) {
            Mode *m = &g_modes[i];
            if (dm.dmPelsWidth != m->w || dm.dmPelsHeight != m->h) continue;
            if (m->hz && g_freq[i] == m->hz) continue; // exact match already found
            if (dm.dmDisplayFrequency == m->hz || dm.dmDisplayFrequency > g_freq[i]) g_freq[i] = dm.dmDisplayFrequency;
        }
    }
}

static void current(DEVMODEW *dm) {
    *dm = (DEVMODEW){0};
    dm->dmSize = sizeof *dm;
    EnumDisplaySettingsW(NULL, ENUM_CURRENT_SETTINGS, dm);
}

static BOOL startup_on(void) {
    return RegGetValueW(HKEY_CURRENT_USER, kRun, L"trayres", RRF_RT_REG_SZ, NULL, NULL, NULL) == ERROR_SUCCESS;
}

static void set_startup(BOOL on) {
    if (on) {
        WCHAR v[MAX_PATH + 3];
        wsprintfW(v, L"\"%s\"", g_exe);
        RegSetKeyValueW(HKEY_CURRENT_USER, kRun, L"trayres", REG_SZ, v, (DWORD)(lstrlenW(v) + 1) * sizeof(WCHAR));
    } else {
        RegDeleteKeyValueW(HKEY_CURRENT_USER, kRun, L"trayres");
    }
}

static void set_tip(void) {
    DEVMODEW dm;
    current(&dm);
    wsprintfW(g_nid.szTip, L"trayres\n%lu × %lu @ %lu Hz", dm.dmPelsWidth, dm.dmPelsHeight, dm.dmDisplayFrequency);
}

static void add_icon(void) {
    g_nid.cbSize = sizeof g_nid;
    g_nid.hWnd = g_hwnd;
    g_nid.uID = 1;
    g_nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP;
    g_nid.uCallbackMessage = WM_TRAY;
    if (!g_nid.hIcon)
        g_nid.hIcon = (HICON)LoadImageW(GetModuleHandleW(NULL), MAKEINTRESOURCEW(1), IMAGE_ICON,
                                        GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON), 0);
    set_tip();
    // Right after logon the taskbar can be slow to answer; if it isn't there at all,
    // TaskbarCreated brings us back here once it is.
    for (int t = 0; t < 10 && !Shell_NotifyIconW(NIM_ADD, &g_nid); t++) {
        Shell_NotifyIconW(NIM_DELETE, &g_nid);
        Sleep(500);
    }
    g_nid.uVersion = NOTIFYICON_VERSION_4;
    Shell_NotifyIconW(NIM_SETVERSION, &g_nid);
}

static void show_menu(int x, int y) {
    WCHAR label[64];
    DEVMODEW cur;
    refresh();
    current(&cur);
    HMENU m = CreatePopupMenu();
    for (int i = 0; i < g_count; i++) {
        Mode *md = &g_modes[i];
        UINT flags = MF_STRING;
        if (g_freq[i]) {
            wsprintfW(label, L"%lu × %lu @ %lu Hz", md->w, md->h, g_freq[i]);
            if (cur.dmPelsWidth == md->w && cur.dmPelsHeight == md->h && cur.dmDisplayFrequency == g_freq[i])
                flags |= MF_CHECKED;
        } else {
            wsprintfW(label, L"%lu × %lu (not offered)", md->w, md->h);
            flags |= MF_GRAYED;
        }
        AppendMenuW(m, flags, ID_MODE + i, label);
    }
    AppendMenuW(m, MF_SEPARATOR, 0, NULL);
    AppendMenuW(m, MF_STRING | (startup_on() ? MF_CHECKED : 0), ID_STARTUP, L"Start with Windows");
    AppendMenuW(m, MF_STRING, ID_EXIT, L"Exit");
    SetForegroundWindow(g_hwnd);
    UINT align = GetSystemMetrics(SM_MENUDROPALIGNMENT) ? TPM_RIGHTALIGN : TPM_LEFTALIGN;
    TrackPopupMenuEx(m, align | TPM_BOTTOMALIGN | TPM_RIGHTBUTTON, x, y, g_hwnd, NULL);
    PostMessageW(g_hwnd, WM_NULL, 0, 0);
    DestroyMenu(m);
    trim();
}

static void command(int id) {
    if (id >= ID_MODE && id < ID_MODE + MAX_MODES) {
        int i = id - ID_MODE;
        refresh();
        if (i >= g_count || !g_freq[i]) return;
        // Same fields HRC set: size, depth, refresh. Scaling and position are left to the driver.
        DEVMODEW dm = {0};
        dm.dmSize = sizeof dm;
        dm.dmFields = DM_PELSWIDTH | DM_PELSHEIGHT | DM_BITSPERPEL | DM_DISPLAYFREQUENCY;
        dm.dmPelsWidth = g_modes[i].w;
        dm.dmPelsHeight = g_modes[i].h;
        dm.dmBitsPerPel = 32;
        dm.dmDisplayFrequency = g_freq[i];
        LONG r = ChangeDisplaySettingsExW(NULL, &dm, NULL, CDS_UPDATEREGISTRY, NULL);
        if (r != DISP_CHANGE_SUCCESSFUL) {
            WCHAR msg[128];
            wsprintfW(msg, L"Couldn't switch to %lu × %lu @ %lu Hz (error %ld).",
                      dm.dmPelsWidth, dm.dmPelsHeight, dm.dmDisplayFrequency, r);
            MessageBoxW(NULL, msg, L"trayres", MB_OK | MB_ICONWARNING | MB_SETFOREGROUND);
        }
    } else if (id == ID_STARTUP) {
        set_startup(!startup_on());
    } else if (id == ID_EXIT) {
        DestroyWindow(g_hwnd);
    }
    trim();
}

static LRESULT CALLBACK wndproc(HWND h, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
    case WM_TRAY:
        switch (LOWORD(lp)) {
        case NIN_SELECT: case NIN_KEYSELECT: case WM_CONTEXTMENU:
            show_menu(X_OF(wp), Y_OF(wp));
        }
        return 0;
    case WM_COMMAND:
        command(LOWORD(wp));
        return 0;
    case WM_DISPLAYCHANGE:
        set_tip();
        Shell_NotifyIconW(NIM_MODIFY, &g_nid);
        return 0;
    case WM_DESTROY:
        Shell_NotifyIconW(NIM_DELETE, &g_nid);
        PostQuitMessage(0);
        return 0;
    }
    if (msg == g_taskbarCreated && msg) { add_icon(); trim(); return 0; }
    return DefWindowProcW(h, msg, wp, lp);
}

static BOOL write_default_ini(void) {
    DWORD put = 0;
    HANDLE f = CreateFileW(g_ini, GENERIC_WRITE, 0, NULL, CREATE_NEW, 0, NULL);
    if (f == INVALID_HANDLE_VALUE) return FALSE;
    BOOL ok = WriteFile(f, kDefaultIni, sizeof kDefaultIni - 1, &put, NULL);
    CloseHandle(f);
    return ok;
}

void WINAPI start(void) {
    CreateMutexW(NULL, TRUE, L"Local\\trayres");
    if (GetLastError() == ERROR_ALREADY_EXISTS) ExitProcess(0);

    GetModuleFileNameW(NULL, g_exe, MAX_PATH);
    lstrcpyW(g_ini, g_exe);
    WCHAR *dot = g_ini + lstrlenW(g_ini);
    while (dot > g_ini && *dot != L'.' && *dot != L'\\') dot--;
    if (*dot != L'.') dot = g_ini + lstrlenW(g_ini);
    lstrcpyW(dot, L".ini");

    // First run (no config yet): write the defaults and add ourselves to startup.
    // Later runs: if startup is on, keep the entry pointing at this exe.
    if (GetFileAttributesW(g_ini) == INVALID_FILE_ATTRIBUTES) {
        if (write_default_ini()) set_startup(TRUE);
    } else if (startup_on()) {
        set_startup(TRUE);
    }

    HINSTANCE inst = GetModuleHandleW(NULL);
    WNDCLASSW wc = {0};
    wc.lpfnWndProc = wndproc;
    wc.hInstance = inst;
    wc.lpszClassName = L"trayres";
    RegisterClassW(&wc);
    // A hidden top-level window (not message-only) so it receives the TaskbarCreated broadcast.
    g_hwnd = CreateWindowExW(WS_EX_TOOLWINDOW, L"trayres", L"trayres", WS_POPUP, 0, 0, 0, 0, NULL, NULL, inst, NULL);
    g_taskbarCreated = RegisterWindowMessageW(L"TaskbarCreated");
    ChangeWindowMessageFilterEx(g_hwnd, g_taskbarCreated, MSGFLT_ALLOW, NULL);
    add_icon();
    trim();

    MSG msg;
    while (GetMessageW(&msg, NULL, 0, 0) > 0) DispatchMessageW(&msg);
    ExitProcess(0);
}
