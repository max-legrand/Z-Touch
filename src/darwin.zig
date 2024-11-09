const std = @import("std");
const builtin = @import("builtin");

const darwin = @cImport({
    if (builtin.os.tag == .macos) {
        @cInclude("objc/runtime.h");
        @cInclude("objc/message.h");
    }
});

const appName = @import("main.zig").appName;

extern fn objc_getClass(name: [*:0]const u8) ?*anyopaque;
extern fn sel_registerName(name: [*:0]const u8) ?*anyopaque;
extern fn objc_msgSend() void;
extern fn objc_getSelector(name: [*:0]const u8) ?*anyopaque;
const macostype = if (builtin.os.tag == .macos)
    struct {
        NSApplication: *anyopaque,
        sharedApplication: *anyopaque,
        windows: *anyopaque,
        count: *anyopaque,
        objectAtIndex: *anyopaque,
        close: *anyopaque,
        isVisible: *anyopaque,
        title: *anyopaque,
        isEqual: *anyopaque,
        setActivationPolicy: *anyopaque,
        NSString: *anyopaque,
        stringWithUTF8String: *anyopaque,
        miniaturize: *anyopaque,
    }
else
    struct {};

var macos: macostype = undefined;

const objc = struct {
    const messaging = struct {
        pub extern fn objc_msgSend() void;
    };
};

pub fn initmac() void {
    macos = macostype{
        .NSApplication = objc_getClass("NSApplication").?,
        .sharedApplication = sel_registerName("sharedApplication").?,
        .windows = sel_registerName("windows").?,
        .count = sel_registerName("count").?,
        .objectAtIndex = sel_registerName("objectAtIndex:").?,
        .close = sel_registerName("close").?,
        .isVisible = sel_registerName("isVisible").?,
        .title = sel_registerName("title").?,
        .isEqual = sel_registerName("isEqual:").?,
        .setActivationPolicy = sel_registerName("setActivationPolicy:").?,
        .NSString = objc_getClass("NSString").?,
        .stringWithUTF8String = sel_registerName("stringWithUTF8String:").?,
        .miniaturize = sel_registerName("miniaturize:").?,
    };
}

pub fn hideFromDock() void {
    if (builtin.os.tag == .macos) {
        const app = @as(*const fn (?*anyopaque, ?*anyopaque) callconv(.C) ?*anyopaque, @ptrCast(&objc.messaging.objc_msgSend))(macos.NSApplication, macos.sharedApplication);
        _ = @as(*const fn (?*anyopaque, ?*anyopaque, c_long) callconv(.C) void, @ptrCast(&objc.messaging.objc_msgSend))(app, macos.setActivationPolicy, 1);
    }
}

pub fn TriggerClose() void {
    const app = @as(*const fn (?*anyopaque, ?*anyopaque) callconv(.C) ?*anyopaque, @ptrCast(&objc.messaging.objc_msgSend))(macos.NSApplication, macos.sharedApplication);
    const windowsArray = @as(*const fn (?*anyopaque, ?*anyopaque) callconv(.C) ?*anyopaque, @ptrCast(&objc.messaging.objc_msgSend))(app, macos.windows);
    const windowCount = @as(*const fn (?*anyopaque, ?*anyopaque) callconv(.C) usize, @ptrCast(&objc.messaging.objc_msgSend))(windowsArray, macos.count);

    // std.debug.print("Total window count: {}\n", .{windowCount});

    var i: usize = 0;
    while (i < windowCount) : (i += 1) {
        const window = @as(*const fn (?*anyopaque, ?*anyopaque, usize) callconv(.C) ?*anyopaque, @ptrCast(&objc.messaging.objc_msgSend))(windowsArray, macos.objectAtIndex, i);
        const is_visible = @as(*const fn (?*anyopaque, ?*anyopaque) callconv(.C) bool, @ptrCast(&objc.messaging.objc_msgSend))(window, macos.isVisible);
        const window_title = @as(*const fn (?*anyopaque, ?*anyopaque) callconv(.C) ?*anyopaque, @ptrCast(&objc.messaging.objc_msgSend))(window, macos.title);

        // Convert NSString to C string
        // const utf8String = sel_registerName("UTF8String").?;
        // const c_string = @as(*const fn (?*anyopaque, ?*anyopaque) callconv(.C) [*:0]const u8, @ptrCast(&objc.messaging.objc_msgSend))(window_title, utf8String);

        // std.debug.print("Window {}: Visible: {}, Title: {s}\n", .{ i, is_visible, c_string });

        // Check if this is the app window
        const zero_terminated_name = std.heap.page_allocator.dupeZ(u8, appName) catch unreachable;
        const target_title = @as(*const fn (?*anyopaque, ?*anyopaque, [*:0]const u8) callconv(.C) ?*anyopaque, @ptrCast(&objc.messaging.objc_msgSend))(macos.NSString, macos.stringWithUTF8String, zero_terminated_name);
        const title_matches = @as(*const fn (?*anyopaque, ?*anyopaque, ?*anyopaque) callconv(.C) bool, @ptrCast(&objc.messaging.objc_msgSend))(window_title, macos.isEqual, target_title);

        if (is_visible and title_matches) {
            // std.debug.print("Closing window\n", .{});
            _ = @as(*const fn (?*anyopaque, ?*anyopaque) callconv(.C) void, @ptrCast(&objc.messaging.objc_msgSend))(window, macos.close);
            return;
        }
    }

    // std.debug.print("Could not find app window to close\n", .{});
}

pub fn minimizeWindow() void {
    const app = @as(*const fn (?*anyopaque, ?*anyopaque) callconv(.C) ?*anyopaque, @ptrCast(&objc.messaging.objc_msgSend))(macos.NSApplication, macos.sharedApplication);
    const windowsArray = @as(*const fn (?*anyopaque, ?*anyopaque) callconv(.C) ?*anyopaque, @ptrCast(&objc.messaging.objc_msgSend))(app, macos.windows);
    const windowCount = @as(*const fn (?*anyopaque, ?*anyopaque) callconv(.C) usize, @ptrCast(&objc.messaging.objc_msgSend))(windowsArray, macos.count);

    var i: usize = 0;
    while (i < windowCount) : (i += 1) {
        const window = @as(*const fn (?*anyopaque, ?*anyopaque, usize) callconv(.C) ?*anyopaque, @ptrCast(&objc.messaging.objc_msgSend))(windowsArray, macos.objectAtIndex, i);
        const is_visible = @as(*const fn (?*anyopaque, ?*anyopaque) callconv(.C) bool, @ptrCast(&objc.messaging.objc_msgSend))(window, macos.isVisible);
        const window_title = @as(*const fn (?*anyopaque, ?*anyopaque) callconv(.C) ?*anyopaque, @ptrCast(&objc.messaging.objc_msgSend))(window, macos.title);

        // Check if this is the app window
        const zero_terminated_name = std.heap.page_allocator.dupeZ(u8, appName) catch unreachable;
        const target_title = @as(*const fn (?*anyopaque, ?*anyopaque, [*:0]const u8) callconv(.C) ?*anyopaque, @ptrCast(&objc.messaging.objc_msgSend))(macos.NSString, macos.stringWithUTF8String, zero_terminated_name);
        const title_matches = @as(*const fn (?*anyopaque, ?*anyopaque, ?*anyopaque) callconv(.C) bool, @ptrCast(&objc.messaging.objc_msgSend))(window_title, macos.isEqual, target_title);

        if (is_visible and title_matches) {
            _ = @as(*const fn (?*anyopaque, ?*anyopaque, ?*anyopaque) callconv(.C) void, @ptrCast(&objc.messaging.objc_msgSend))(window, macos.miniaturize, window);
            return;
        }
    }
}
