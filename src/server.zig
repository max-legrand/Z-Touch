const std = @import("std");
const resources = @import("resources.zig");
const httpz = @import("httpz");

var dist_dir: []const u8 = "";

pub fn spinUpServer() !void {
    std.debug.print("Spinning up server\n", .{});
    const resources_dir = try resources.setupWebResources();
    std.debug.print("resources_dir: {s}\n", .{resources_dir});
    dist_dir = try std.fs.path.join(std.heap.page_allocator, &[_][]const u8{ resources_dir, "dist" });
    std.debug.print("dist_dir: {s}\n", .{dist_dir});

    const allocator = std.heap.page_allocator;
    var server = try httpz.Server().init(allocator, .{ .port = 11110 });

    server.dispatcher(dispatch);

    // overwrite the default notFound handler
    server.notFound(notFound);

    // overwrite the default error handler
    server.errorHandler(errorHandler);

    var router = server.router();
    router.get("/", indexHandler);
    router.get("/static/*", staticFileHandler); // Wildcard route for all static files

    try server.listen();
}

fn dispatch(action: httpz.Action(void), req: *httpz.Request, res: *httpz.Response) !void {
    const method: []const u8 = @tagName(req.method);
    const path = req.url.path;

    var timer = try std.time.Timer.start();

    action(req, res) catch |err| {
        const elapsed = timer.read();
        std.debug.print("[{s}] {s} {d:.3}ms - failed with error: {any}\n", .{ method, path, @as(f64, @floatFromInt(elapsed)) / 1_000_000.0, err });
        return err;
    };

    const elapsed = timer.read();
    std.debug.print("[{s}] {s} {d:.3}ms\n", .{ method, path, @as(f64, @floatFromInt(elapsed)) / 1_000_000.0 });
}

fn staticFileHandler(req: *httpz.Request, res: *httpz.Response) !void {
    const allocator = std.heap.page_allocator;

    // Extract the path after "/static/"
    const static_path = req.url.path[7..]; // Skip "/static/"

    // Use runtime string concatenation
    const file_path = try std.fs.path.join(allocator, &[_][]const u8{ dist_dir, "static", static_path });
    defer allocator.free(file_path);

    const file = std.fs.openFileAbsolute(file_path, .{}) catch {
        return notFound(req, res);
    };
    defer file.close();

    res.body = try file.readToEndAlloc(allocator, std.math.maxInt(usize));

    // Set content-type based on file extension
    if (std.mem.endsWith(u8, static_path, ".js")) {
        res.header("content-type", "application/javascript");
    } else if (std.mem.endsWith(u8, static_path, ".css")) {
        res.header("content-type", "text/css");
    } else {
        res.header("content-type", "application/octet-stream");
    }
}

fn indexHandler(_: *httpz.Request, res: *httpz.Response) !void {
    const allocator = std.heap.page_allocator;

    // Use runtime string concatenation
    const index_path = try std.fs.path.join(allocator, &[_][]const u8{ dist_dir, "index.html" });
    defer allocator.free(index_path);

    std.debug.print("Serving index.html from {s}\n", .{index_path});
    const file = try std.fs.openFileAbsolute(index_path, .{});
    defer file.close();

    res.body = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    res.header("content-type", "text/html");
}

fn notFound(_: *httpz.Request, res: *httpz.Response) !void {
    res.status = 404;

    // you can set the body directly to a []u8, but note that the memory
    // must be valid beyond your handler. Use the res.arena if you need to allocate
    // memory for the body.
    res.body = "Not Found";
}

// note that the error handler return `void` and not `!void`
fn errorHandler(req: *httpz.Request, res: *httpz.Response, err: anyerror) void {
    res.status = 500;
    res.body = "Internal Server Error";
    std.log.warn("httpz: unhandled exception for request: {s}\nErr: {}", .{ req.url.raw, err });
}
