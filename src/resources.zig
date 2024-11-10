const std = @import("std");
const builtin = @import("builtin");
pub const ICON = @embedFile("resources/icon.ico");
pub const ICON_INV = @embedFile("resources/icon_inv.png");
pub const ICON_PNG = @embedFile("resources/icon.png");
pub const WEB = @embedFile("resources/dist.zip");
const utils = @import("utils.zig");

/// Write the icon to a temp file, and return the path to it
pub fn getIcon() ![]u8 {
    const allocator = std.heap.page_allocator;
    const app_dir = try utils.getHomeDir();
    if (comptime builtin.os.tag == .windows) {
        const filename = try std.fmt.allocPrint(allocator, "{s}\\ztouch_icon.ico", .{app_dir});
        defer allocator.free(filename);

        // Open the file
        const file = try std.fs.createFileAbsolute(filename, .{ .read = true });
        defer file.close();

        // Write the icon data
        try file.writeAll(ICON);

        // Return the path
        return try allocator.dupe(u8, filename);
    } else {
        const filename = try std.fmt.allocPrint(allocator, "{s}/ztouch_icon.png", .{app_dir});
        defer allocator.free(filename);

        // Open the file
        const file = try std.fs.createFileAbsolute(filename, .{ .read = true });
        defer file.close();

        // Write the icon data
        try file.writeAll(ICON_INV);

        // Return the path
        return try allocator.dupe(u8, filename);
    }
}

// Extract the zip file using the Zig standard library
pub fn setupWebResources() ![]u8 {
    const allocator = std.heap.page_allocator;

    const app_dir = try utils.getHomeDir();
    const dirname = try std.fs.path.join(allocator, &[_][]const u8{ app_dir, "web_resources" });
    defer allocator.free(dirname);

    // Open the destination directory
    std.fs.makeDirAbsolute(dirname) catch |err| {
        switch (err) {
            error.PathAlreadyExists => {
                // Delete the existing directory
                try std.fs.deleteTreeAbsolute(dirname);
                try std.fs.makeDirAbsolute(dirname);
            },
            else => return err,
        }
    };
    var dest_dir = try std.fs.openDirAbsolute(dirname, .{ .access_sub_paths = true, .iterate = true });
    defer dest_dir.close();

    // Create a fixed buffer stream from the embedded data
    var fbs = std.io.fixedBufferStream(WEB);
    const stream = fbs.seekableStream();

    // Extract directly from memory
    try std.zip.extract(dest_dir, stream, .{
        .allow_backslashes = true,
    });

    return try allocator.dupe(u8, dirname);
}
