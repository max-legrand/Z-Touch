const std = @import("std");
const builtin = @import("builtin");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "Z-touch",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const bundle = b.option(bool, "bundle", "Build as a bundled application") orelse false;

    if (bundle) {
        std.debug.print("Building as a bundled application\n", .{});
        // Build the web resources.
        const build_args = if (comptime builtin.os.tag == .windows)
            [_][]const u8{ "bun.exe", "run", "build" }
        else
            [_][]const u8{ "bun", "run", "build" };

        const web_dir = std.fs.path.join(b.allocator, &[_][]const u8{ b.build_root.path.?, "web" }) catch |err| {
            std.debug.print("Failed to join paths: {}\n", .{err});
            return;
        };

        _ = std.process.Child.run(.{
            .allocator = b.allocator, //
            .argv = &build_args,
            .cwd = web_dir,
        }) catch |err| {
            std.debug.print("Failed to build web resources: {}\n", .{err});
            return;
        };

        // Zip the web resources
        const zip_args = if (comptime builtin.os.tag == .windows)
            [_][]const u8{ "powershell.exe", "-NoProfile", "-Command", "Compress-Archive -Path .\\dist\\* -DestinationPath .\\dist.zip -Force" }
        else
            [_][]const u8{ "zip", "-r", "../src/resources/dist.zip", "dist" };
        _ = std.process.Child.run(.{
            .allocator = b.allocator, //
            .argv = &zip_args,
            .cwd = web_dir,
        }) catch |err| {
            std.debug.print("Failed to bundle web resources: {}\n", .{err});
            return;
        };
    }

    const webview = b.dependency("webview", .{});
    const webview_module = webview.module("webview");
    exe.root_module.addImport("webview", webview_module);

    const httpz = b.dependency("httpz", .{
        .target = target,
        .optimize = optimize,
    }).module("httpz");
    exe.root_module.addImport("httpz", httpz);

    exe.linkLibrary(webview.artifact("webviewStatic"));
    const nfd = b.dependency("nfd", .{}).module("nfd");
    exe.root_module.addImport("nfd", nfd);

    const zqlite = b.dependency("zqlite", .{}).module("zqlite");
    exe.linkSystemLibrary("sqlite3");
    exe.root_module.addImport("zqlite", zqlite);

    if (comptime builtin.os.tag == .windows) {
        if (bundle) {
            std.debug.print("Building as a bundled application\n", .{});
            exe.subsystem = .Windows;
        }
        exe.addIncludePath(b.path("tray"));
        exe.linkSystemLibrary("gdi32");
        exe.linkSystemLibrary("shell32");
        exe.linkSystemLibrary("user32");
        exe.linkSystemLibrary("comctl32");
        exe.linkSystemLibrary("uxtheme");
        exe.linkSystemLibrary("dwmapi");
        const win_sdk_root = "C:\\Program Files (x86)\\Windows Kits\\10\\";
        const win_sdk_version = "10.0.19041.0"; // Update this to your installed version
        const win_sdk_include = win_sdk_root ++ "Include\\" ++ win_sdk_version ++ "\\";

        const rc_step = b.addSystemCommand(&[_][]const u8{
            "rc.exe",
            "/nologo",
            "/fo",
            "src/resources/windows_resources.res",
            "/I",
            win_sdk_include ++ "um",
            "/I",
            win_sdk_include ++ "shared",
            "src/resources/windows_resources.rc",
        });
        exe.step.dependOn(&rc_step.step);
        exe.addObjectFile(b.path("src/resources/windows_resources.res"));
    } else if (comptime builtin.os.tag == .macos) {
        exe.addIncludePath(b.path("tray-mac"));
        exe.linkFramework("Cocoa");
        exe.linkFramework("WebKit");
        exe.linkFramework("AppKit");
        exe.addCSourceFile(.{ .file = b.path("tray-mac/tray_darwin.m") });
    } else if (comptime builtin.os.tag == .linux) {
        exe.addIncludePath(b.path("tray"));
        exe.linkSystemLibrary("gtk+-3.0");
        // Use environment variables for libappindicator paths
        const env_map = std.process.getEnvMap(std.heap.page_allocator) catch @panic("Failed to get environment variables");
        const include_path = env_map.get("LIBAPPINDICATOR_INCLUDE_PATH");
        const lib_path = env_map.get("LIBAPPINDICATOR_LIB_PATH");

        if (include_path) |path| {
            const lpath = std.Build.LazyPath{ .cwd_relative = path };
            exe.addIncludePath(lpath);
        } else {
            std.debug.print("Warning: LIBAPPINDICATOR_INCLUDE_PATH is not set\n", .{});
        }

        if (lib_path) |path| {
            const lpath = std.Build.LazyPath{ .cwd_relative = path };
            exe.addLibraryPath(lpath);
        } else {
            std.debug.print("Warning: LIBAPPINDICATOR_LIB_PATH is not set\n", .{});
        }

        exe.linkSystemLibrary("appindicator3-0.1");

        // Link other required libraries
        exe.linkSystemLibrary("glib-2.0");
        exe.linkSystemLibrary("gobject-2.0");
    } else {
        @panic("Unsupported OS");
    }
    exe.linkLibC();

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_check = b.addExecutable(.{
        .name = "Z-touch",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_check.linkLibC();
    exe_check.root_module.addImport("webview", webview_module);
    exe_check.root_module.addImport("httpz", httpz);
    exe_check.linkLibrary(webview.artifact("webviewStatic"));
    exe_check.linkSystemLibrary("sqlite3");
    exe_check.root_module.addImport("zqlite", zqlite);

    // Add these lines to use environment variables set by Nix
    if (comptime builtin.os.tag == .windows) {
        exe_check.linkSystemLibrary("gdi32");
        exe_check.linkSystemLibrary("shell32");
        exe_check.linkSystemLibrary("user32");
        exe_check.linkSystemLibrary("uxtheme");
        exe_check.linkSystemLibrary("dwmapi");
        exe_check.addIncludePath(b.path("tray"));
    } else if (comptime builtin.os.tag == .macos) {
        exe_check.addIncludePath(b.path("tray-mac"));
        exe_check.linkFramework("Cocoa");
        exe_check.linkFramework("WebKit");
        exe_check.linkFramework("AppKit");
        exe_check.addCSourceFile(.{ .file = b.path("tray-mac/tray_darwin.m") });
    } else if (comptime builtin.os.tag == .linux) {
        exe_check.addIncludePath(b.path("tray"));
        exe_check.linkSystemLibrary("gtk+-3.0");
        // Use environment variables for libappindicator paths
        const env_map = std.process.getEnvMap(std.heap.page_allocator) catch @panic("Failed to get environment variables");
        const include_path = env_map.get("LIBAPPINDICATOR_INCLUDE_PATH");
        const lib_path = env_map.get("LIBAPPINDICATOR_LIB_PATH");

        if (include_path) |path| {
            const lpath = std.Build.LazyPath{ .cwd_relative = path };
            exe_check.addIncludePath(lpath);
        } else {
            std.debug.print("Warning: LIBAPPINDICATOR_INCLUDE_PATH is not set\n", .{});
        }

        if (lib_path) |path| {
            const lpath = std.Build.LazyPath{ .cwd_relative = path };
            exe_check.addLibraryPath(lpath);
        } else {
            std.debug.print("Warning: LIBAPPINDICATOR_LIB_PATH is not set\n", .{});
        }

        exe_check.linkSystemLibrary("appindicator3-0.1");

        // Link other required libraries
        exe_check.linkSystemLibrary("glib-2.0");
        exe_check.linkSystemLibrary("gobject-2.0");
    } else {
        @panic("Unsupported OS");
    }
    exe_check.root_module.addImport("nfd", nfd);

    const check = b.step("check", "Check if things compile");
    check.dependOn(&exe_check.step);

    if (builtin.os.tag == .macos) {
        // createMacOSBundle(b) catch |err| {
        //     std.debug.print("Failed to create macOS bundle: {}\n", .{err});
        // };
        const bundle_step = b.step("bundle-mac", "Create macOS bundle");

        bundle_step.dependOn(&exe_check.step);
        bundle_step.makeFn = createMacOSBundle;
    }
}

fn createMacOSBundle(step: *std.Build.Step, node: std.Progress.Node) anyerror!void {
    _ = node;
    const name = "Z-touch";
    const version = "1.0.0";
    const identifier = "com.mlegrand.Z-touch";
    const icon_path = "icon.png";
    const b = step.owner;

    // Create app bundle directory structure
    try std.fs.cwd().makePath(b.fmt("{s}.app/Contents/MacOS", .{name}));
    try std.fs.cwd().makePath(b.fmt("{s}.app/Contents/Resources", .{name}));

    // Copy executable
    const src_path = b.getInstallPath(.bin, name);
    const dst_path = b.fmt("{s}.app/Contents/MacOS/{s}", .{ name, name });
    std.fs.cwd().copyFile(src_path, std.fs.cwd(), dst_path, .{}) catch {
        std.debug.print("Failed to copy executable: {s}\n", .{src_path});
        return;
    };

    const icon_src = std.fmt.allocPrint(b.allocator, "{s}/icon.png", .{b.build_root.path.?}) catch unreachable;

    const icon_dst = b.fmt("{s}.app/Contents/Resources/{s}.png", .{ name, name });
    std.fs.cwd().copyFile(icon_src, std.fs.cwd(), icon_dst, .{}) catch {
        std.debug.print("Failed to copy icon: {s}\n", .{icon_path});
        return;
    };

    // Create Info.plist
    const plist = try std.fs.cwd().createFile(b.fmt("{s}.app/Contents/Info.plist", .{name}), .{});
    defer plist.close();
    try plist.writeAll(b.fmt(
        \\<?xml version="1.0" encoding="UTF-8"?>
        \\<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        \\<plist version="1.0">
        \\<dict>
        \\    <key>CFBundleExecutable</key>
        \\    <string>{s}</string>
        \\    <key>CFBundleIconFile</key>
        \\    <string>{s}.png</string>
        \\    <key>CFBundleIdentifier</key>
        \\    <string>{s}</string>
        \\    <key>CFBundleName</key>
        \\    <string>{s}</string>
        \\    <key>CFBundlePackageType</key>
        \\    <string>APPL</string>
        \\    <key>CFBundleShortVersionString</key>
        \\    <string>{s}</string>
        \\    <key>CFBundleVersion</key>
        \\    <string>1</string>
        \\    <key>LSMinimumSystemVersion</key>
        \\    <string>10.15</string>
        \\    <key>NSHighResolutionCapable</key>
        \\    <true/>
        \\    <key>NSPrincipalClass</key>
        \\    <string>NSApplication</string>
        \\    <key>NSMainNibFile</key>
        \\    <string></string>
        \\</dict>
        \\</plist>
    , .{ name, name, identifier, name, version }));

    // Set executable permissions
    const chmod_args = &[_][]const u8{ "chmod", "+x", dst_path };
    _ = try std.process.Child.run(.{
        .allocator = b.allocator,
        .argv = chmod_args,
    });
}
