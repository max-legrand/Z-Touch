const std = @import("std");
const builtin = @import("builtin");
const wv = @import("webview.zig");
const appName = @import("main.zig").appName;

const win32 = struct {
    usingnamespace @cImport({
        @cInclude("windows.h");
        @cInclude("winuser.h");
    });
};

const win = struct {
    const PCWSTR = std.os.windows.PCWSTR;
    const WINAPI = std.os.windows.WINAPI;
    const HWND = std.os.windows.HWND;
    const UINT = c_uint;
    const WPARAM = usize;
    const LPARAM = isize;
    const DWORD = std.os.windows.DWORD;
    const WORD = std.os.windows.WORD;
    const WCHAR = u16;
    const LPCWSTR = [*c]const u16;
    const LPWSTR = [*c]u16;

    const ULONG_PTR = usize; // `usize` is pointer-sized

    const WM_SETICON = 0x0080;
    const WM_SETREDRAW = 0x000B;
    const ICON_SMALL = 0;
    const ICON_BIG = 1;
    const IMAGE_ICON = 1;
    const LR_DEFAULTCOLOR = 0x0000;
    const RDW_INVALIDATE = 0x0001;
    const RDW_UPDATENOW = 0x0100;
    const RDW_FRAME = 0x0400;

    const HINSTANCE = std.os.windows.HINSTANCE;
    const HICON = std.os.windows.HICON;
    const HANDLE = *anyopaque;
    const HRGN = HANDLE;

    const RECT = extern struct {
        left: c_long,
        top: c_long,
        right: c_long,
        bottom: c_long,
    };

    const BOOL = c_int;

    extern "user32" fn FindWindowW(lpClassName: [*c]const u16, lpWindowName: [*c]const u16) callconv(WINAPI) ?HWND;
    extern "user32" fn PostMessageW(hWnd: ?HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(WINAPI) i32;
    extern "user32" fn ShowWindow(hWnd: ?HWND, nCmdShow: c_int) callconv(WINAPI) BOOL;
    extern "kernel32" fn GetLogicalDriveStringsW(nBufferLength: DWORD, lpBuffer: LPWSTR) DWORD;
    extern "kernel32" fn GetDriveTypeW(lpRootPathName: LPCWSTR) UINT;

    extern "user32" fn LoadImageW(hInst: ?HINSTANCE, name: LPCWSTR, type: UINT, cx: c_int, cy: c_int, fuLoad: UINT) callconv(WINAPI) ?HICON;
    extern "user32" fn RedrawWindow(hWnd: ?HWND, lprcUpdate: ?*const RECT, hrgnUpdate: ?HRGN, flags: UINT) callconv(WINAPI) BOOL;
    extern "user32" fn SendMessageW(hWnd: ?HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(WINAPI) LPARAM;
    extern "kernel32" fn GetModuleHandleW(lpModuleName: LPCWSTR) callconv(WINAPI) ?HINSTANCE;

    const ResourceNamePtrW = [*:0]align(1) const win.WCHAR;

    extern "user32" fn LoadIconW(
        hInstance: ?win.HINSTANCE,
        lpIconName: ResourceNamePtrW,
    ) callconv(win.WINAPI) ?win.HICON;

    extern "user32" fn LoadCursorW(
        hInstance: ?win.HINSTANCE,
        lpCursorName: ResourceNamePtrW,
    ) callconv(win.WINAPI) ?win.HCURSOR;

    // Resource ordinals are limited to u16
    fn makeIntResourceW(id: u16) ResourceNamePtrW {
        return @ptrFromInt(@as(usize, id));
    }

    const FILE_ATTRIBUTE_DIRECTORY = 0x00000010;

    const WIN32_FIND_DATAW = extern struct {
        dwFileAttributes: DWORD,
        ftCreationTime: FILETIME,
        ftLastAccessTime: FILETIME,
        ftLastWriteTime: FILETIME,
        nFileSizeHigh: DWORD,
        nFileSizeLow: DWORD,
        dwReserved0: DWORD,
        dwReserved1: DWORD,
        cFileName: [260]WCHAR, // MAX_PATH
        cAlternateFileName: [14]WCHAR,
    };

    const FILETIME = extern struct {
        dwLowDateTime: DWORD,
        dwHighDateTime: DWORD,
    };

    extern "kernel32" fn FindFirstFileW(lpFileName: LPCWSTR, lpFindFileData: *WIN32_FIND_DATAW) HANDLE;
    extern "kernel32" fn FindNextFileW(hFindFile: HANDLE, lpFindFileData: *WIN32_FIND_DATAW) BOOL;
    extern "kernel32" fn FindClose(hFindFile: HANDLE) BOOL;

    const WM_CLOSE = 0x0010;

    // Constants for drive types
    const DRIVE_UNKNOWN = 0;
    const DRIVE_NO_ROOT_DIR = 1;
    const DRIVE_REMOVABLE = 2;
    const DRIVE_FIXED = 3;
    const DRIVE_REMOTE = 4;
    const DRIVE_CDROM = 5;
    const DRIVE_RAMDISK = 6;

    // Title bar related items
    const DWMWINDOWATTRIBUTE = enum(c_int) {
        DWMA_USE_IMMERSIVE_DARK_MODE = 20,
    };

    extern "dwmapi" fn DwmSetWindowAttribute(
        hwnd: ?HWND,
        dwAttribute: DWMWINDOWATTRIBUTE,
        pvAttribute: *const anyopaque,
        cbAttribute: c_ulong,
    ) callconv(WINAPI) std.os.windows.HRESULT;
};

pub fn TriggerClose() void {
    const window_title = std.unicode.utf8ToUtf16LeStringLiteral(appName);
    const h_wnd = win.FindWindowW(null, window_title);
    if (h_wnd != null) {
        _ = win.PostMessageW(h_wnd, win.WM_CLOSE, 0, 0);
        std.debug.print("Window close message sent on Windows\n", .{});
    } else {
        std.debug.print("Could not find app window with title\n", .{});
    }
}

pub fn setWindowIcon() void {
    const window_title = std.unicode.utf8ToUtf16LeStringLiteral(appName);
    const h_wnd = win.FindWindowW(null, window_title);
    if (h_wnd) |window| {
        // Set the title bar to dark mode
        const use_dark_mode: win.BOOL = 1;
        const dark_mode_result = win.DwmSetWindowAttribute(window, win.DWMWINDOWATTRIBUTE.DWMA_USE_IMMERSIVE_DARK_MODE, &use_dark_mode, @sizeOf(win.BOOL));
        if (dark_mode_result != 0) {
            std.debug.print("Failed to set window dark mode\n", .{});
        }

        const h_instance = win.GetModuleHandleW(null);
        if (h_instance) |instance| {
            const icon_name = std.unicode.utf8ToUtf16LeStringLiteral("IDI_ICON1");
            const icon = win.LoadIconW(instance, icon_name);
            if (icon) |ic| {
                const ic_ptr_address: isize = @intCast(@intFromPtr(ic));
                _ = win.SendMessageW(window, win.WM_SETICON, win.ICON_SMALL, ic_ptr_address);
                _ = win.RedrawWindow(window, null, null, win.RDW_FRAME | win.RDW_INVALIDATE | win.RDW_UPDATENOW);
            } else {
                std.debug.print("Failed to load icon\n", .{});
            }
        } else {
            std.debug.print("Failed to get module handle\n", .{});
        }
    } else {
        std.debug.print("Could not find app window\n", .{});
    }
}

pub fn minimizeWindow() void {
    const window_title = std.unicode.utf8ToUtf16LeStringLiteral(appName);
    const h_wnd = win.FindWindowW(null, window_title);
    if (h_wnd) |window| {
        // Minimize the window.
        const SW_MINIMIZE = 6;
        _ = win.ShowWindow(window, SW_MINIMIZE);
    } else {
        std.debug.print("Could not find app window\n", .{});
    }
}
