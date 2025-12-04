const std = @import("std");

const Input = @import("lib/input.zig").Input;
const Part = @import("lib/aoc.zig").Part;
const Map = @import("lib/map.zig").Map;
const Day = @import("lib/aoc.zig").Day;
const all_directions = @import("lib/map.zig").all_directions;

pub fn main() !void {
    var day = try Day.init(4, solve);
    defer day.deinit();
    try day.solve();
}

fn cleanup_map(map: *Map) !u64 {
    var new_map = try map.dupe();
    defer new_map.deinit();

    var result: u64 = 0;
    var it = map.iterator();
    while (it.next()) |point| {
        if (point.value != '@') continue;

        var papers_around: u8 = 0;
        for (all_directions) |direction| {
            if (map.next(&point, direction)) |next| {
                if (next.value != '@') continue;
                papers_around += 1;
            }
        }

        if (papers_around < 4) {
            new_map.update(point.x, point.y, 'x');
            result += 1;
        }
    }

    @memcpy(map.data, new_map.data);
    return result;
}

fn solve(reader: *std.io.Reader, part: Part) !u64 {
    var gpa: std.heap.DebugAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = try Map.init(allocator, reader);
    defer map.deinit();

    var result: u64 = 0;
    var i: usize = 0;
    while (true) : (i += 1) {
        const r: u64 = try cleanup_map(&map);
        result += r;
        if (r == 0) break;
        if (part == .one) break;
    }

    return result;
}

const test_input =
    \\..@@.@@@@.
    \\@@@.@.@.@@
    \\@@@@@.@.@@
    \\@.@@@@..@.
    \\@@.@@@@.@@
    \\.@@@@@@@.@
    \\.@.@.@.@@@
    \\@.@@@.@@@@
    \\.@@@@@@@@.
    \\@.@.@@@.@.
;

test "test part 1" {
    var reader = std.io.Reader.fixed(test_input);
    const result = try solve(&reader, .one);
    try std.testing.expectEqual(13, result);
}

test "test part 2" {
    var reader = std.io.Reader.fixed(test_input);
    const result = try solve(&reader, .two);
    try std.testing.expectEqual(43, result);
}
