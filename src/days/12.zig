const std = @import("std");

const Map = @import("lib/map.zig").Map;
const Part = @import("lib/aoc.zig").Part;
const Day = @import("lib/aoc.zig").Day;

pub fn main() !void {
    var day = try Day.init(11, solve);
    defer day.deinit();
    try day.solve();
}

const Region = struct {
    map: Map,
    count: [6]u8,

    fn init(allocator: std.mem.Allocator, input: []u8) !Region {
        const colon_index = std.mem.indexOfScalar(u8, input, ':') orelse unreachable;

        const x_index = std.mem.indexOfScalar(u8, input, 'x') orelse unreachable;

        const width = try std.fmt.parseInt(u8, input[0..x_index], 10);
        const height = try std.fmt.parseInt(u8, input[x_index + 1 .. colon_index], 10);

        var region = Region{
            .map = try Map.initEmpty(allocator, width, height),
            .count = .{0} ** 6,
        };

        var i: usize = 0;
        var it = std.mem.splitScalar(u8, input[colon_index + 2 ..], ' ');
        while (it.next()) |value| {
            region.count[i] = try std.fmt.parseInt(u8, value, 10);
            i += 1;
        }

        return region;
    }

    pub fn format(self: *const Region, writer: *std.io.Writer) std.Io.Writer.Error!void {
        try writer.print(
            "\n{f}\n{any}",
            .{
                self.map,
                self.count,
            },
        );
    }
};

fn solve(reader: *std.io.Reader, part: Part) !u64 {
    var gpa: std.heap.DebugAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    var arena: std.heap.ArenaAllocator = .init(gpa.allocator());
    const allocator = arena.allocator();
    defer arena.deinit();

    _ = part;

    var maps: [6]Map = undefined;

    var i: usize = 0;
    var j: usize = 0;
    while (try reader.takeDelimiter('\n')) |line| {
        if (line.len == 0) {
            i += 1;
            j = 0;
            continue;
        }

        if (i == 6) {
            const region = try Region.init(allocator, line);
            std.debug.print("{f}\n", .{region});
            continue;
        }

        if (std.mem.indexOfScalar(u8, line, ':')) |_| {
            continue;
        }

        if (j == 0) maps[i] = try Map.initEmpty(allocator, 3, 3);

        const y = j;
        std.debug.print("i:{d} j:{d} {s}\n", .{ i, j, line });
        for (line, 0..) |c, x| {
            maps[i].update(x, y, c);
        }
        j += 1;
    }

    for (maps) |map| {
        std.debug.print("\n---------------\n{f}\n", .{map});
    }

    return 0;
}

test "test part 1" {
    const test_input =
        \\0:
        \\###
        \\##.
        \\##.
        \\
        \\1:
        \\###
        \\##.
        \\.##
        \\
        \\2:
        \\.##
        \\###
        \\##.
        \\
        \\3:
        \\##.
        \\###
        \\##.
        \\
        \\4:
        \\###
        \\#..
        \\###
        \\
        \\5:
        \\###
        \\.#.
        \\###
        \\
        \\4x4: 0 0 0 0 2 0
        \\12x5: 1 0 1 0 2 2
        \\12x5: 1 0 1 0 3 2
    ;

    var reader = std.io.Reader.fixed(test_input);
    const result = try solve(&reader, .one);
    try std.testing.expectEqual(2, result);
}
