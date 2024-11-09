const std = @import("std");
const WebView = @import("webview").WebView;
const builtin = @import("builtin");
const resources = @import("resources.zig");
const server = @import("server.zig");
const webview = @import("webview.zig");

const darwin = @import("darwin.zig");
const windows = @import("windows.zig");
const tray = @import("tray.zig");
const state = @import("state.zig");

pub const appName: []const u8 = "Z-touch";

pub fn main() !void {
    if (comptime builtin.os.tag == .macos) {
        darwin.initmac();
    }
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    var dev_mode = false;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--dev")) {
            dev_mode = true;
        }
    }

    if (!dev_mode) {
        const t = std.Thread.spawn(.{}, server.spinUpServer, .{}) catch |err| {
            std.debug.print("Failed to spin up server: {}\n", .{err});
            return error.ServerInitFailed;
        };

        t.detach();
    }

    try state.initState();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var trayInstance = try tray.Tray.init(allocator);
    defer trayInstance.deinit();

    try webview.createWindow();

    var running = true;
    while (running) {
        webview.window_open = false;
        if (comptime builtin.os.tag == .macos) {
            darwin.hideFromDock();
        }

        if (trayInstance.loop() != 0) {
            running = false;
        }
        std.time.sleep(1000 * 10);
    }
}