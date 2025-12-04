const std = @import("std");

pub const Input = struct {
    day: u8,
    file: ?std.fs.File = null,

    pub fn init(day: u8) !Input {
        return .{
            .day = day,
            .file = try bootstrap(day),
        };
    }

    pub fn deinit(self: *Input) void {
        if (self.file) |*file| {
            file.close();
        }
    }

    pub fn reader(self: *Input, buf: []u8) !std.fs.File.Reader {
        if (self.file) |file| {
            return file.reader(buf);
        }
        return error.MissingInputFile;
    }
};

pub fn bootstrap(day: u8) !std.fs.File {
    std.fs.cwd().makeDir("inputs") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    var buf: [16]u8 = undefined;
    const file_name = try std.fmt.bufPrint(&buf, "inputs/{d}", .{day});

    if (std.fs.cwd().openFile(file_name, .{ .mode = .read_only })) |file| {
        return file;
    } else |err| switch (err) {
        error.FileNotFound => return getInput(day), // Continue to download
        else => return err,
    }
}

pub fn getInput(day: u8) !std.fs.File {
    std.debug.print("Fetching input for day {d}\n", .{day});

    const token = std.posix.getenv("AOC_SESSION") orelse
        return error.MissingToken;

    var gpa: std.heap.DebugAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file_name = try std.fmt.allocPrint(allocator, "inputs/{d}", .{day});
    defer allocator.free(file_name);

    const file = try std.fs.cwd().createFile(file_name, .{});
    defer file.close();

    var write_buffer: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buffer);

    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    const url = try std.fmt.allocPrint(
        allocator,
        "https://adventofcode.com/2025/day/{d}/input",
        .{day},
    );
    defer allocator.free(url);

    const cookie = try std.fmt.allocPrint(allocator, "session={s}", .{token});
    defer allocator.free(cookie);

    const opts: std.http.Client.FetchOptions = .{
        .method = .GET,
        .location = .{ .url = url },
        .response_writer = &file_writer.interface,
        .extra_headers = &.{
            .{ .name = "Cookie", .value = cookie },
        },
    };

    const response = try client.fetch(opts);
    if (response.status != .ok) {
        std.log.debug("Failed to get input: {any}", .{response.status});
        return error.GetInput;
    }

    std.debug.print("Input fetched\n", .{});
    return std.fs.cwd().openFile(file_name, .{ .mode = .read_only });
}
