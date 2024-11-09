const std = @import("std");
const webview = @import("webview.zig");
const builtin = @import("builtin");
const resources = @import("resources.zig");

const c = @cImport({
    // Platform-specific defines
    if (builtin.os.tag == .windows) {
        @cDefine("TRAY_WINAPI", "1");
    } else if (builtin.os.tag == .linux) {
        @cDefine("TRAY_APPINDICATOR", "1");
    } else if (builtin.os.tag == .macos) {
        @cDefine("TRAY_APPKIT", "1");
    }
    @cInclude("tray.h");
});

const MenuItemType = if (builtin.os.tag == .macos) c.struct_tray_menu_item else c.tray_menu;

pub const Tray = struct {
    allocator: std.mem.Allocator,
    icon: [:0]u8,
    menu_items: []MenuItemType,
    item_texts: [][:0]u8,
    tray: c.tray,

    pub fn init(allocator: std.mem.Allocator) !*Tray {
        const self = try allocator.create(Tray);
        errdefer allocator.destroy(self);

        self.allocator = allocator;
        self.icon = try allocator.dupeZ(u8, try resources.getIcon());

        // Allocate memory for item_texts
        self.item_texts = try allocator.alloc([:0]u8, 3);
        errdefer allocator.free(self.item_texts);

        // Initialize item_texts
        self.item_texts[0] = try allocator.dupeZ(u8, "Hello");
        errdefer allocator.free(self.item_texts[0]);
        self.item_texts[1] = try allocator.dupeZ(u8, "Open");
        errdefer allocator.free(self.item_texts[1]);
        self.item_texts[2] = try allocator.dupeZ(u8, "Quit");
        errdefer allocator.free(self.item_texts[2]);

        if (comptime builtin.os.tag == .macos) {
            self.menu_items = try allocator.alloc(c.struct_tray_menu_item, 4);
            self.menu_items[0] = .{ .text = self.item_texts[0].ptr, .cb = cb_mac, .disabled = 0, .checked = 0, .submenu = null };
            self.menu_items[1] = .{ .text = self.item_texts[1].ptr, .cb = open_mac, .disabled = 0, .checked = 0, .submenu = null };
            self.menu_items[2] = .{ .text = self.item_texts[2].ptr, .cb = quit_mac, .disabled = 0, .checked = 0, .submenu = null };
            self.menu_items[3] = .{ .text = null, .cb = null, .disabled = 0, .checked = 0, .submenu = null }; // Terminator
            self.tray = c.tray{
                .icon_filepath = self.icon.ptr,
                .menu = &self.menu_items[0],
            };
        } else {
            self.menu_items = try allocator.alloc(c.tray_menu, 4);
            self.menu_items[0] = .{ .text = self.item_texts[0].ptr, .cb = cb, .disabled = 0, .checked = 0, .submenu = null };
            self.menu_items[1] = .{ .text = self.item_texts[1].ptr, .cb = open, .disabled = 0, .checked = 0, .submenu = null };
            self.menu_items[2] = .{ .text = self.item_texts[2].ptr, .cb = quit, .disabled = 0, .checked = 0, .submenu = null };
            self.menu_items[3] = .{ .text = null, .cb = null, .disabled = 0, .checked = 0, .submenu = null }; // Terminator
            self.tray = c.tray{
                .icon = self.icon.ptr,
                .menu = &self.menu_items[0],
            };
        }

        if (c.tray_init(&self.tray) != 0) {
            std.debug.print("Failed to initialize tray\n", .{});
            return error.TrayInitFailed;
        }

        return self;
    }

    pub fn deinit(self: *Tray) void {
        c.tray_exit();
        self.allocator.free(self.icon);
        for (self.item_texts) |text| {
            self.allocator.free(text);
        }
        self.allocator.free(self.item_texts);
        self.allocator.free(self.menu_items);
        self.allocator.destroy(self);
    }

    pub fn loop(self: *Tray) c_int {
        _ = self;
        return c.tray_loop(0);
    }
};

// Global variables to keep allocations alive
var icon: [:0]u8 = undefined;
var menu_text: [:0]u8 = undefined;
var quit_text: [:0]u8 = undefined;
var open_text: [:0]u8 = undefined;
var menu_items: [4]MenuItemType = undefined;
var tray: c.tray = undefined;

pub fn cb_mac(item: ?*c.struct_tray_menu_item) callconv(.C) void {
    if (item) |menu_item| {
        if (menu_item.text) |text| {
            const slice = std.mem.span(text);
            std.debug.print("Menu item clicked: {s}\n", .{slice});
        }
    }
}

pub fn cb(item: ?*c.tray_menu) callconv(.C) void {
    if (item) |menu_item| {
        if (menu_item.text) |text| {
            const slice = std.mem.span(text);
            std.debug.print("Menu item clicked: {s}\n", .{slice});
        }
    }
}

pub fn quit_inner() void {
    c.tray_exit();
    webview.w.destroy();
    std.process.exit(0);
}

pub fn quit_mac(_: ?*c.struct_tray_menu_item) callconv(.C) void {
    quit_inner();
}
pub fn quit(_: ?*c.tray_menu) callconv(.C) void {
    quit_inner();
}

pub fn open_inner() void {
    if (!webview.window_open) {
        std.debug.print("Opening window\n", .{});
        webview.createWindow() catch |err| {
            std.debug.print("Failed to create window: {}\n", .{err});
        };
    } else {
        std.debug.print("Window is already open\n", .{});
    }
}

pub fn open(_: ?*c.tray_menu) callconv(.C) void {
    open_inner();
}
pub fn open_mac(_: ?*c.struct_tray_menu_item) callconv(.C) void {
    open_inner();
}
