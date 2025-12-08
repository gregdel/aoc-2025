const std = @import("std");

const Part = @import("lib/aoc.zig").Part;
const Day = @import("lib/aoc.zig").Day;
const Map = @import("lib/map.zig").Map;
const Point = @import("lib/map.zig").Point;
const Direction = @import("lib/map.zig").Direction;

const split_directions = [_]Direction{ .left, .right };

pub fn main() !void {
    var day = try Day.init(7, solve);
    defer day.deinit();
    try day.solve();
}

fn solve(reader: *std.io.Reader, part: Part) !u64 {
    var gpa: std.heap.DebugAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = try Map.init(allocator, reader);
    defer map.deinit();

    const start = map.find('S') orelse unreachable;
    if (part == .one) {
        return handleOne(&map, start);
    }

    var entries: std.AutoHashMap(Point, u64) = .init(allocator);
    defer entries.deinit();
    return try handleTwo(&map, &entries);
}

fn handleTwo(map: *Map, entries: *std.AutoHashMap(Point, u64)) !u64 {
    var it = map.iterator();
    while (it.next()) |point| {
        switch (point.value) {
            'S' => try entries.put(point, 1),
            '.',
            '|',
            => {
                const up = map.next(&point, .up) orelse continue;
                const value = entries.get(up) orelse continue;
                const prev_value = entries.get(point) orelse 0;
                try entries.put(point, prev_value + value);
            },
            '^' => {
                const up = map.next(&point, .up) orelse unreachable;
                const value = entries.get(up) orelse continue;
                for (split_directions) |direction| {
                    if (map.next(&point, direction)) |n| {
                        const prev_value = entries.get(n) orelse 0;
                        try entries.put(n, prev_value + value);
                    }
                }
            },
            else => unreachable,
        }
    }

    var result: u64 = 0;
    for (0..map.width) |x| {
        const y = map.height - 1;
        const point = map.get(x, y) orelse unreachable;
        const value = entries.get(point) orelse 0;
        result += value;
    }

    return result;
}

fn handleOne(map: *Map, point: Point) u64 {
    map.updatePoint(point, '|');
    const next = map.next(&point, .down) orelse return 0;

    var split: u64 = 1;
    switch (next.value) {
        '|' => return 0,
        '.' => return handleOne(map, next),
        '^' => {
            for (split_directions) |direction| {
                if (map.next(&next, direction)) |n| {
                    split += handleOne(map, n);
                }
            }
        },
        else => unreachable,
    }
    return split;
}

const test_input =
    \\.......S.......
    \\...............
    \\.......^.......
    \\...............
    \\......^.^......
    \\...............
    \\.....^.^.^.....
    \\...............
    \\....^.^...^....
    \\...............
    \\...^.^...^.^...
    \\...............
    \\..^...^.....^..
    \\...............
    \\.^.^.^.^.^...^.
    \\...............
;

// test "test part 1" {
//     var reader = std.io.Reader.fixed(test_input);
//     const result = try solve(&reader, .one);
//     try std.testing.expectEqual(21, result);
// }

test "test part 2" {
    var reader = std.io.Reader.fixed(test_input);
    const result = try solve(&reader, .two);
    try std.testing.expectEqual(40, result);
}
