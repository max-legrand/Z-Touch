const std = @import("std");
const builtin = @import("builtin");
const darwin = @import("darwin.zig");
const windows = @import("windows.zig");
const utils = @import("utils.zig");
const WebView = @import("webview").WebView;
const state = @import("state.zig");
const appName = @import("main.zig").appName;

const nfd = @import("nfd");

pub var w: WebView = undefined;
pub var window_open: bool = false;

pub fn trigger_close(_: [:0]const u8, _: [:0]const u8, _: ?*anyopaque) void {
    std.debug.print("Closing window\n", .{});
    if (comptime builtin.os.tag == .macos) {
        darwin.TriggerClose();
    } else if (comptime builtin.os.tag == .windows) {
        windows.TriggerClose();
    }
    window_open = false;
}

pub fn button_clicked(_: [:0]const u8, _: [:0]const u8, _: ?*anyopaque) void {
    std.debug.print("Button clicked\n", .{});
}

pub fn getFiles(seq: [:0]const u8, _: [:0]const u8, _: ?*anyopaque) void {
    std.debug.print("Getting files\n", .{});
    const example = [_][:0]const u8{"/mnt/d/zutils/src/test.html"};

    const allocator = std.heap.page_allocator;
    const json_string = std.json.stringifyAlloc(allocator, example, .{}) catch |err| {
        std.debug.print("Failed to stringify: {}\n", .{err});
        w.ret(seq, 1, "Failed to stringify file list");
        return;
    };
    defer allocator.free(json_string);

    // Convert the allocated string to a null-terminated slice
    const result = allocator.dupeZ(u8, json_string) catch |err| {
        std.debug.print("Failed to create null-terminated string: {}\n", .{err});
        w.ret(seq, 1, "Failed to create result string");
        return;
    };
    defer allocator.free(result);

    std.debug.print("Returning result: {s}\n", .{result});
    w.ret(seq, 0, result);
}

pub fn logMessage(seq: [:0]const u8, req: [:0]const u8, _: ?*anyopaque) void {
    const timestamp: u64 = @intCast(std.time.timestamp());
    const datetime = utils.fromTimestamp(timestamp);
    const timestamp_str = std.fmt.allocPrint(std.heap.page_allocator, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{ datetime.year, datetime.month, datetime.day, datetime.hours, datetime.minutes, datetime.seconds }) catch {
        std.debug.print("Failed to format timestamp\n", .{});
        return;
    };
    std.debug.print("{s} [WebView Log] {s}\n", .{ timestamp_str, req });
    w.ret(seq, 0, "");
}

pub fn quit(_: [:0]const u8, _: [:0]const u8, _: ?*anyopaque) void {
    std.debug.print("Quitting\n", .{});
    w.destroy();
    std.process.exit(0);
}

pub fn openFolder(_: [:0]const u8, input: [:0]const u8, _: ?*anyopaque) void {
    openHelper(input, true) catch |err| {
        std.debug.print("Failed to open folder: {}\n", .{err});
    };
}

pub fn openHelper(entry: []const u8, isFile: bool) !void {
    std.debug.print("Opening: {s}\n", .{entry});

    // arguments are JSON objects.
    const entryValue = std.json.parseFromSlice(
        [][]const u8,
        std.heap.page_allocator,
        entry,
        .{},
    ) catch |err| {
        std.debug.print("Failed to parse link: {}\n", .{err});
        return;
    };

    // Assert that there is only one link
    if (entryValue.value.len != 1) {
        std.debug.print("Expected one link, got {d}\n", .{entryValue.value.len});
        return;
    }

    const url = entryValue.value[0];
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    switch (builtin.os.tag) {
        .macos => {
            const args = &[_][]const u8{ "open", url };
            var child = std.process.Child.init(args, allocator);
            _ = child.spawnAndWait() catch |err| {
                std.debug.print("Failed to spawn child process: {}\n", .{err});
            };
        },
        .windows => {
            if (isFile) {
                const args = &[_][]const u8{ "explorer.exe", url };
                var child = std.process.Child.init(args, allocator);
                _ = child.spawnAndWait() catch |err| {
                    std.debug.print("Failed to spawn child process: {}\n", .{err});
                };
            } else {
                const args = &[_][]const u8{ "cmd.exe", "/c", "start", "", url };
                var child = std.process.Child.init(args, allocator);
                _ = child.spawnAndWait() catch |err| {
                    std.debug.print("Failed to spawn child process: {}\n", .{err});
                };
            }
        },
        .linux => {
            const args = &[_][]const u8{ "xdg-open", url };
            var child = std.process.Child.init(args, allocator);
            _ = child.spawnAndWait() catch |err| {
                std.debug.print("Failed to spawn child process: {}\n", .{err});
            };
        },
        else => return error.UnsupportedOS,
    }
}

pub fn openLink(_: [:0]const u8, link: [:0]const u8, _: ?*anyopaque) void {
    openHelper(link, false) catch |err| {
        std.debug.print("Failed to open link: {}\n", .{err});
    };
}

pub fn createWindow() !void {
    w = WebView.create(false, null);
    const title = std.heap.page_allocator.dupeZ(u8, appName) catch unreachable;
    w.setTitle(title);
    w.setSize(800, 640, WebView.WindowSizeHint.None);
    w.bind("buttonClicked", button_clicked, null);
    w.bind("triggerClose", trigger_close, null);
    w.bind("minimize", minimize, null);
    w.bind("getFiles", getFiles, null);
    w.bind("zlog", logMessage, null);
    w.bind("quit", quit, null);
    w.bind("openFileDialog", openFileDialog, null);
    w.bind("openLink", openLink, null);
    w.bind("openFolder", openFolder, null);
    w.bind("getProjects", getProjects, null);
    w.bind("getTags", getTags, null);
    w.bind("addProject", addProject, null);
    w.bind("addProjectViaLink", addProjectViaLink, null);
    w.bind("updateIdx", updateIdx, null);
    w.bind("updateProject", updateProject, null);
    w.navigate("http://localhost:11110/");

    window_open = true;
    if (builtin.os.tag == .windows) {
        windows.setWindowIcon();
    }
    // This is a blocking call
    w.run();
}

fn updateIdx(seq: [:0]const u8, data: [:0]const u8, _: ?*anyopaque) void {
    const Input = struct {
        to: isize,
        from: isize,
    };
    var input: Input = undefined;
    // Parse the data as JSON.
    const input_json = std.json.parseFromSlice([]Input, std.heap.page_allocator, data, .{}) catch {
        w.ret(seq, 1, "Failed to parse input JSON");
        return;
    };
    if (input_json.value.len != 1) {
        w.ret(seq, 1, "Invalid input");
        return;
    }
    input = input_json.value[0];

    std.debug.print("Got data: {any}\n", .{input});
    state.AppState.updateIdx(input.to, input.from) catch {
        std.debug.print("Failed to update index\n", .{});
        w.ret(seq, 1, "Failed to update index");
        return;
    };
}

fn getProjects(seq: [:0]const u8, _: [:0]const u8, _: ?*anyopaque) void {
    const projects = state.AppState.getProjects();
    const json_string = std.json.stringifyAlloc(std.heap.page_allocator, projects, .{}) catch {
        w.ret(seq, 1, "Failed to stringify projects array");
        return;
    };

    // Sentinel-terminate the string
    const result = std.heap.page_allocator.dupeZ(u8, json_string) catch {
        w.ret(seq, 1, "Failed to create null-terminated string");
        return;
    };
    w.ret(seq, 0, result);
}

fn addProjectHelper(content: []const u8, isPath: bool, error_message_buffer: *[:0]u8) !void {
    const allocator = std.heap.page_allocator;
    // Turn the input string into a JSON object
    const input_json = std.json.parseFromSlice([][]const u8, allocator, content, .{}) catch {
        error_message_buffer.* = try std.fmt.allocPrintZ(allocator, "Failed to parse input JSON", .{});
        return error.InvalidInput;
    };
    defer input_json.deinit();

    if (input_json.value.len != 1) {
        error_message_buffer.* = try std.fmt.allocPrintZ(allocator, "Expected one project, got {d}", .{input_json.value.len});
        return error.InvalidInput;
    }

    // Get the name of the project from the path.
    const project_path = try allocator.dupeZ(u8, input_json.value[0]);

    std.debug.print("Got project: {s}\n", .{project_path});
    const name = try allocator.dupeZ(u8, std.fs.path.basename(project_path));
    std.debug.print("Basename: {s}", .{name});

    var project = state.Project{
        .id = -1,
        .name = name,
        .path = if (isPath) project_path else null,
        .url = if (isPath) null else project_path,
        .description = "",
        .tags = &[_]state.Tag{},
        .order_idx = @intCast(state.AppState.Projects.items.len),
    };

    state.AppState.addProject(&project) catch {
        error_message_buffer.* = try std.fmt.allocPrintZ(allocator, "Failed to add project", .{});
        return error.InvalidInput;
    };
}

fn addProjectViaLink(seq: [:0]const u8, input: [:0]const u8, _: ?*anyopaque) void {
    var error_message_buffer = std.heap.page_allocator.allocSentinel(u8, 1024, 0) catch {
        w.ret(seq, 1, "Failed to allocate memory");
        return;
    };

    addProjectHelper(input, false, &error_message_buffer) catch {
        w.ret(seq, 1, error_message_buffer);
        return;
    };
    w.ret(seq, 0, "");
}

fn addProject(seq: [:0]const u8, input: [:0]const u8, _: ?*anyopaque) void {
    var error_message_buffer = std.heap.page_allocator.allocSentinel(u8, 1024, 0) catch {
        w.ret(seq, 1, "Failed to allocate memory");
        return;
    };

    addProjectHelper(input, true, &error_message_buffer) catch {
        w.ret(seq, 1, error_message_buffer);
        return;
    };
    w.ret(seq, 0, "");
}

fn openFileDialog(seq: [:0]const u8, _: [:0]const u8, _: ?*anyopaque) void {
    const selected = nfd.openFolderDialog(null) catch |err| {
        std.debug.print("Error opening folder dialog: {}\n", .{err});
        w.ret(seq, 1, "");
        return;
    };

    if (selected) |path| {
        std.debug.print("Selected path: {s}\n", .{path});
        const allocator = std.heap.page_allocator;
        const json_string = std.json.stringifyAlloc(allocator, path, .{}) catch |err| {
            std.debug.print("Failed to stringify: {}\n", .{err});
            w.ret(seq, 1, "Failed to stringify file list");
            return;
        };
        defer allocator.free(json_string);

        // Convert the allocated string to a null-terminated slice
        const result = allocator.dupeZ(u8, json_string) catch |err| {
            std.debug.print("Failed to create null-terminated string: {}\n", .{err});
            w.ret(seq, 1, "Failed to create result string");
            return;
        };
        defer allocator.free(result);

        std.debug.print("Returning result: {s}\n", .{result});
        w.ret(seq, 0, result);
        return;
    }

    w.ret(seq, 1, "");
}

fn minimize(_: [:0]const u8, _: [:0]const u8, _: ?*anyopaque) void {
    std.debug.print("Minimizing window\n", .{});
    if (comptime builtin.os.tag == .macos) {
        darwin.minimizeWindow();
    } else if (comptime builtin.os.tag == .windows) {
        windows.minimizeWindow();
    }
}

fn updateProject(seq: [:0]const u8, data: [:0]const u8, _: ?*anyopaque) void {
    std.debug.print("updateProject\n", .{});
    std.debug.print("data: {s}\n", .{data});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const input = std.json.parseFromSlice([]state.Project, allocator, data, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch |err| {
        std.debug.print("Failed to parse input JSON: {}\n", .{err});
        w.ret(seq, 1, "Failed to parse input JSON");
        return;
    };
    defer input.deinit();

    if (input.value.len != 1) {
        std.debug.print("Expected one project, got {d}\n", .{input.value.len});
        const error_message = std.fmt.allocPrintZ(allocator, "Expected one project, got {d}", .{input.value.len}) catch {
            w.ret(seq, 1, "Failed to create error message");
            return;
        };
        w.ret(seq, 1, error_message);
        return;
    }

    state.AppState.updateProject(&input.value[0]) catch |err| {
        std.debug.print("Failed to update projects: {}\n", .{err});
        w.ret(seq, 1, "Failed to update projects");
        return;
    };

    w.ret(seq, 0, "");
}

fn getTags(seq: [:0]const u8, _: [:0]const u8, _: ?*anyopaque) void {
    const tags = state.AppState.getTags() catch {
        w.ret(seq, 1, "Failed to get tags");
        return;
    };
    for (tags) |tag| {
        std.debug.print("tag: {s}\n", .{tag.name});
    }
    const allocator = std.heap.page_allocator;
    const json_string = std.json.stringifyAlloc(allocator, tags, .{}) catch |err| {
        std.debug.print("Failed to stringify: {}\n", .{err});
        w.ret(seq, 1, "Failed to stringify file list");
        return;
    };
    std.debug.print("json_string: {s}\n", .{json_string});

    // Convert the allocated string to a null-terminated slice
    const result = allocator.dupeZ(u8, json_string) catch |err| {
        std.debug.print("Failed to create null-terminated string: {}\n", .{err});
        w.ret(seq, 1, "Failed to create result string");
        return;
    };
    w.ret(seq, 0, result);
}
