const std = @import("std");
const builtin = @import("builtin");
const utils = @import("utils.zig");
const zqlite = @import("zqlite");

pub const Project = struct {
    id: isize,
    name: []const u8,
    path: ?[]const u8,
    url: ?[]const u8,
    description: []const u8,
    tags: []Tag,
    order_idx: isize,

    fn update(self: *Project, other: *const Project, allocator: std.mem.Allocator) !void {
        // Create new strings first
        const new_name = try allocator.dupeZ(u8, other.name);
        const new_path = if (other.path != null) try allocator.dupeZ(u8, other.path.?) else null;
        const new_url = if (other.url != null) try allocator.dupeZ(u8, other.url.?) else null;
        const new_description = try allocator.dupeZ(u8, other.description);

        // Allocate new tags array
        var new_tags = try allocator.alloc(Tag, other.tags.len);
        var tag_index: usize = 0;
        errdefer {
            while (tag_index > 0) {
                tag_index -= 1;
                allocator.free(new_tags[tag_index].name);
            }
            allocator.free(new_tags);
        }

        // Copy tags
        for (other.tags, 0..) |tag, i| {
            new_tags[i] = Tag{
                .id = tag.id,
                .name = try allocator.dupeZ(u8, tag.name),
                .color = tag.color,
            };
            tag_index += 1;
        }

        // Update with new data
        self.id = other.id;
        self.name = new_name;
        self.path = new_path;
        self.url = new_url;
        self.description = new_description;
        self.order_idx = other.order_idx;
        self.tags = new_tags;
    }
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,

    /// Returns a string representation of the color in the format "#RRGGBB"
    fn toString(self: *const Color, buffer: *[7]u8) void {
        _ = std.fmt.bufPrint(buffer, "#{x:0>2}{x:0>2}{x:0>2}", .{ self.r, self.g, self.b }) catch unreachable;
    }
};

pub const Tag = struct {
    id: isize,
    name: []const u8,
    color: Color,
};

pub const State = struct {
    Projects: std.ArrayList(Project),
    connection: ?zqlite.Conn,

    pub fn getTags(self: *const State) ![]Tag {
        const allocator = std.heap.page_allocator;

        // Get all the tags from all the projects.
        var tag_identifier_set = std.StringHashMap(Tag).init(allocator);
        defer tag_identifier_set.deinit();

        for (self.Projects.items) |project| {
            for (project.tags) |tag| {
                var color_string: [7]u8 = undefined;
                tag.color.toString(&color_string);

                // Create a unique identifier for the tag
                const tag_id = try std.fmt.allocPrint(allocator, "{s}-{d}-{s}", .{ tag.name, tag.id, color_string });

                if (tag_identifier_set.get(tag_id) == null) {
                    // Create a new tag with fresh memory allocation
                    const new_name = try allocator.dupe(u8, tag.name);
                    errdefer allocator.free(new_name);

                    const new_tag = Tag{
                        .id = tag.id,
                        .name = new_name,
                        .color = tag.color,
                    };

                    try tag_identifier_set.put(tag_id, new_tag);
                }
            }
        }

        // Create the final tag list
        var tag_list = std.ArrayList(Tag).init(allocator);
        errdefer {
            for (tag_list.items) |tag| {
                allocator.free(tag.name);
            }
            tag_list.deinit();
        }

        var iter = tag_identifier_set.valueIterator();
        while (iter.next()) |tag| {
            const tag_copy = Tag{
                .id = tag.id,
                .name = try allocator.dupe(u8, tag.name),
                .color = tag.color,
            };
            try tag_list.append(tag_copy);
        }

        return tag_list.items;
    }

    pub fn getProjects(self: *const State) []Project {
        return self.Projects.items;
    }

    pub fn addProject(self: *State, project: *Project) !void {
        const insert_query =
            \\ INSERT INTO Project (
            \\     name,
            \\     path,
            \\     url,
            \\     description,
            \\     order_idx
            \\ )
            \\ VALUES (
            \\     ?,
            \\     ?,
            \\     ?,
            \\     ?,
            \\     ?
            \\ );
        ;

        const get_id_query = "SELECT last_insert_rowid();";

        var conn = self.connection.?;

        // Start a transaction
        try conn.exec("BEGIN TRANSACTION", .{});

        // Insert the project
        const index: isize = @intCast(project.order_idx);
        conn.exec(insert_query, .{
            project.name,
            project.path,
            project.url,
            project.description,
            index,
        }) catch |err| {
            try conn.exec("ROLLBACK", .{});
            return err;
        };

        // Get the last inserted ID
        var stmt = conn.prepare(get_id_query, .{}) catch |err| {
            try conn.exec("ROLLBACK", .{});
            return err;
        };
        defer stmt.deinit();

        const rows = stmt.step() catch |err| {
            try conn.exec("ROLLBACK", .{});
            return err;
        };

        if (rows) {
            project.id = stmt.int(0);
        } else {
            try conn.exec("ROLLBACK", .{});
            return error.NoRowReturned;
        }

        // Commit the transaction
        try conn.exec("COMMIT", .{});

        // Add the project to AppState.Projects
        try self.Projects.append(project.*);
    }

    pub fn updateIdx(self: *State, to: isize, from: isize) !void {
        if (to == from) return;

        var conn = self.connection orelse return error.NoConnection;
        // Start a transaction
        try conn.exec("BEGIN TRANSACTION", .{});
        errdefer conn.exec("ROLLBACK", .{}) catch {};

        // Get the projects at the `from` and `to` indices
        var from_project = self.Projects.items[@intCast(from)];
        var to_project = self.Projects.items[@intCast(to)];

        // Swap the order_idx values
        const temp_idx = from_project.order_idx;
        from_project.order_idx = to_project.order_idx;
        to_project.order_idx = temp_idx;

        // Update both projects in the database
        const update_query =
            \\ UPDATE Project
            \\ SET order_idx = ?
            \\ WHERE id = ?;
        ;

        try conn.exec(update_query, .{ from_project.order_idx, from_project.id });
        try conn.exec(update_query, .{ to_project.order_idx, to_project.id });

        // Swap the projects in the ArrayList
        self.Projects.items[@intCast(to)] = from_project;
        self.Projects.items[@intCast(from)] = to_project;

        // Commit the transaction
        try conn.exec("COMMIT", .{});
    }

    /// Update a project in its entirety
    pub fn updateProject(self: *State, project: *Project) !void {
        var conn = self.connection orelse return error.NoConnection;

        const update_query =
            \\ UPDATE Project
            \\ SET name = ?,
            \\     path = ?,
            \\     url = ?,
            \\     description = ?,
            \\     order_idx = ?,
            \\     tags = ?
            \\ WHERE id = ?;
        ;

        // Start a transaction
        try conn.exec("BEGIN TRANSACTION", .{});
        errdefer conn.exec("ROLLBACK", .{}) catch {};

        const tags_json_string = try std.json.stringifyAlloc(std.heap.page_allocator, project.tags, .{});
        defer std.heap.page_allocator.free(tags_json_string);

        // Update the project in the database
        conn.exec(update_query, .{
            project.name,
            project.path,
            project.url,
            project.description,
            project.order_idx,
            tags_json_string,
            project.id,
        }) catch |err| {
            std.debug.print("Failed to update project: {any}\n", .{err});
            try conn.exec("ROLLBACK", .{});
            return err;
        };

        // Update the project in AppState.Projects
        for (self.Projects.items) |*p| {
            if (p.id == project.id) {
                try p.update(project, std.heap.page_allocator);
                break;
            }
        }

        // Commit the transaction
        try conn.exec("COMMIT", .{});
    }
};

pub var AppState: State = undefined;

pub fn initState() !void {
    const config_dir = try utils.getHomeDir();

    const config_file = try switch (builtin.os.tag) {
        .windows => std.fmt.allocPrintZ(std.heap.page_allocator, "{s}\\ztouch.sqlite", .{config_dir}),
        .macos, .linux => std.fmt.allocPrintZ(std.heap.page_allocator, "{s}/ztouch.sqlite", .{config_dir}),
        else => return error.UnsupportedOS,
    };
    defer std.heap.page_allocator.free(config_file);

    const file = try openOrCreateFile(config_file);
    file.close();

    const flags = zqlite.OpenFlags.Create | zqlite.OpenFlags.ReadWrite | zqlite.OpenFlags.EXResCode;
    var conn = try zqlite.open(config_file, flags);
    errdefer conn.close();

    const create_tables = [_][]const u8{
        \\ -- Create Project table with tags as JSON array
        \\ CREATE TABLE IF NOT EXISTS Project (
        \\     id INTEGER PRIMARY KEY,
        \\     name TEXT NOT NULL,
        \\     path TEXT,
        \\     url TEXT,
        \\     description TEXT NOT NULL,
        \\     order_idx INTEGER NOT NULL CHECK (order_idx >= 0),
        \\     tags JSON
        \\ );
    };

    for (create_tables) |create_table| {
        try conn.exec(create_table, .{});
    }

    const fetch_query =
        \\ SELECT
        \\    id,
        \\    name,
        \\    path,
        \\    url,
        \\    description,
        \\    order_idx,
        \\    tags
        \\ FROM
        \\    Project
        \\ ORDER BY
        \\    order_idx, id;
    ;
    var rows = try conn.rows(fetch_query, .{});
    defer rows.deinit();

    var projects = std.AutoHashMap(isize, Project).init(std.heap.page_allocator);
    defer projects.deinit();

    while (rows.next()) |row| {
        const project_id = row.int(0);
        const project_name = row.text(1);
        const project_path = row.text(2);
        const project_url = row.text(3);
        const project_description = row.text(4);
        const project_order = row.int(5);
        const tags_json = row.text(6);

        var tag_list: []Tag = &[_]Tag{};
        if (tags_json.len > 0) {
            // Parse tags with explicit allocator
            const parsed = try std.json.parseFromSlice([]Tag, std.heap.page_allocator, tags_json, .{
                .ignore_unknown_fields = true,
            });

            // Create new tag list with proper string allocation
            tag_list = try std.heap.page_allocator.alloc(Tag, parsed.value.len);
            for (parsed.value, 0..) |tag, i| {
                tag_list[i] = Tag{
                    .id = tag.id,
                    .name = try std.heap.page_allocator.dupeZ(u8, tag.name),
                    .color = tag.color,
                };
            }
            parsed.deinit();
        }

        const new_project = Project{
            .id = project_id,
            .name = try std.heap.page_allocator.dupeZ(u8, project_name),
            .path = if (project_path.len > 0) try std.heap.page_allocator.dupeZ(u8, project_path) else null,
            .url = if (project_url.len > 0) try std.heap.page_allocator.dupeZ(u8, project_url) else null,
            .description = try std.heap.page_allocator.dupeZ(u8, project_description),
            .order_idx = @intCast(project_order),
            .tags = tag_list,
        };

        try projects.put(project_id, new_project);
    }

    var project_list = try std.ArrayList(Project).initCapacity(std.heap.page_allocator, projects.count());
    var it = projects.valueIterator();
    while (it.next()) |project| {
        try project_list.append(project.*);
    }

    AppState = State{
        .Projects = project_list,
        .connection = conn,
    };
}

fn openOrCreateFile(path: []const u8) !std.fs.File {
    const file = std.fs.openFileAbsolute(path, .{ .mode = .read_write }) catch |err| {
        switch (err) {
            error.FileNotFound => {
                const file = try std.fs.createFileAbsolute(path, .{});
                return file;
            },
            else => return err,
        }
    };
    return file;
}
