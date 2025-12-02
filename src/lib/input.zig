const std = @import("std");

pub fn getInput() !void {
    const token = std.posix.getenv("AOC_SESSION") orelse
        return error.MissingToken;

    const file = try std.fs.cwd().createFile("inputs/1", .{});
    defer file.close();
    errdefer file.close();

    var buf: [4096]u8 = undefined;
    var writer = file.writer(&buf);

    var gpa: std.heap.DebugAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    const cookie = try std.fmt.allocPrint(allocator, "session={s}", .{token});
    defer allocator.free(cookie);

    const opts: std.http.Client.FetchOptions = .{
        .method = .GET,
        .response_writer = &writer.interface,
        .redirect_behavior = .not_allowed,
        .location = .{ .url = "https://adventofcode.com/2025/day/1/input" },
        .headers = .{ .accept_encoding = .{ .override = "text/plain" } },
        .privileged_headers = &.{
            .{ .name = "Cookie", .value = cookie },
        },
    };

    const response = try client.fetch(opts);
    if (response.status != .ok) {
        std.log.debug("Failed to get input: {any}", .{response.status});
        return;
    }

    try writer.interface.flush();
    std.debug.print("Input downloaded", .{});
}
