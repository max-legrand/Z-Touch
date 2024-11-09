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

pub fn setupWebResources() ![]u8 {
    if (builtin.os.tag == .windows) {
        const allocator = std.heap.page_allocator;

        // Get the APPDATA directory
        const envmap = try std.process.getEnvMap(allocator);
        const app_data = envmap.get("APPDATA") orelse return error.AppDataDirNotFound;

        // Create fixed paths for the zip file and extraction directory
        const app_dir = try std.fs.path.join(allocator, &[_][]const u8{ app_data, "Z-touch" });
        defer allocator.free(app_dir);
        std.fs.makeDirAbsolute(app_dir) catch |err| {
            switch (err) {
                error.PathAlreadyExists => {},
                else => return err,
            }
        };

        const zipname = try std.fs.path.join(allocator, &[_][]const u8{ app_dir, "web_resources.zip" });
        defer allocator.free(zipname);
        const dirname = try std.fs.path.join(allocator, &[_][]const u8{ app_dir, "web_resources" });
        defer allocator.free(dirname);

        // Write the zip file
        {
            const zip_file = try std.fs.createFileAbsolute(zipname, .{});
            defer zip_file.close();
            try zip_file.writeAll(WEB);
        }

        // Prepare the PowerShell command to unzip
        const ps_command = try std.fmt.allocPrint(allocator, "if (Test-Path '{s}') {{ Remove-Item '{s}' -Recurse -Force }}; Expand-Archive -Path '{s}' -DestinationPath '{s}' -Force", .{ dirname, dirname, zipname, dirname });
        defer allocator.free(ps_command);

        // Prepare the arguments for the PowerShell process
        const args = [_][]const u8{
            "powershell.exe",
            "-NoProfile",
            "-Command",
            ps_command,
        };

        // Spawn the PowerShell process
        var child = std.process.Child.init(&args, allocator);
        child.stderr_behavior = .Pipe;
        child.stdout_behavior = .Pipe;

        try child.spawn();

        // Wait for the process to finish
        const term = try child.wait();

        // Check if the process was successful
        switch (term) {
            .Exited => |code| {
                if (code != 0) {
                    std.debug.print("PowerShell exited with non-zero status: {}\n", .{code});
                    return error.UnzipFailed;
                }
            },
            else => {
                std.debug.print("PowerShell terminated unexpectedly\n", .{});
                return error.UnzipFailed;
            },
        }

        // Optionally, delete the zip file after extraction
        std.fs.deleteFileAbsolute(zipname) catch |err| {
            std.debug.print("Failed to delete zip file: {}\n", .{err});
        };

        // Return the path to the extracted directory
        return try allocator.dupe(u8, dirname);
    } else if (builtin.os.tag == .macos) {}
    return error.UnsupportedOS;
}
