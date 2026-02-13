const std = @import("std");

const Map = @import("lib/map.zig").Map;
const Part = @import("lib/aoc.zig").Part;
const Day = @import("lib/aoc.zig").Day;

pub fn main() !void {
    var day = try Day.init(12, solve);
    defer day.deinit();
    try day.solve();
}

fn rotate90(map: *Map) !Map {
    var result = try map.dupe();
    for (0..3) |i| {
        for (0..3) |j| {
            const point = map.get(i, j) orelse unreachable;
            result.update(j, 2 - i, point.value);
        }
    }
    return result;
}

fn flipHorizontal(map: *Map) !Map {
    var result = try map.dupe();
    for (0..3) |i| {
        for (0..3) |j| {
            const point = map.get(i, j) orelse unreachable;
            result.update(i, 2 - j, point.value);
        }
    }
    return result;
}

fn getAllVariants(shape: *Map, allocator: std.mem.Allocator) ![]Map {
    var variants = try std.ArrayList(Map).initCapacity(allocator, 8);

    var current = shape;
    var next: Map = undefined;

    for (0..4) |_| {
        try variants.append(allocator, try current.dupe());
        next = try rotate90(current);
        current = &next;
    }

    next = try flipHorizontal(shape);
    current = &next;

    for (0..4) |_| {
        try variants.append(allocator, try current.dupe());
        next = try rotate90(current);
        current = &next;
    }

    return variants.toOwnedSlice(allocator);
}

fn getUniqueVariants(shape: *Map, allocator: std.mem.Allocator) ![]Map {
    const all = try getAllVariants(shape, allocator);
    defer allocator.free(all);

    var unique = try std.ArrayList(Map).initCapacity(allocator, 8);

    outer: for (all) |*variant| {
        for (unique.items) |*existing| {
            if (mapsEqual(variant, existing)) continue :outer;
        }
        try unique.append(allocator, try variant.dupe());
    }

    return unique.toOwnedSlice(allocator);
}

fn mapsEqual(a: *Map, b: *Map) bool {
    for (0..3) |i| {
        for (0..3) |j| {
            const point_a = a.get(i, j) orelse unreachable;
            const point_b = b.get(i, j) orelse unreachable;
            if (point_a.value != point_b.value) return false;
        }
    }
    return true;
}

fn count(map: *Map) u64 {
    var c: u64 = 0;
    for (0..3) |i| {
        for (0..3) |j| {
            const point_a = map.get(i, j) orelse unreachable;
            if (point_a.value == '#')
                c += 1;
        }
    }
    return c;
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

    fn isPossible(self: *const Region, shapes: []Map) bool {
        var total: u64 = 0;
        for (self.count, 0..) |r, i| {
            const p = count(&shapes[i]);
            total += p * r;
        }
        if (total > self.map.width * self.map.height) {
            return false;
        }

        return true;
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

pub fn place(area: *Map, shape: *Map, x: u8, y: u8) bool {
    for (0..3) |i| {
        for (0..3) |j| {
            const areaPoint = area.get(x + i, y + j) orelse return false;
            const shapePoint = shape.get(x + i, y + j) orelse return false;
            if (shapePoint.value == '.') continue;
            if (areaPoint.value == '#') return false;
            area.update(x + i, y + j, '#');
        }
    }
    return true;
}

fn solve(reader: *std.io.Reader, part: Part) !u64 {
    var gpa: std.heap.DebugAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    var arena: std.heap.ArenaAllocator = .init(gpa.allocator());
    const allocator = arena.allocator();
    defer arena.deinit();

    _ = part;

    var shapes: [6]Map = undefined;

    // var shapes_variants: [6]std.ArrayList(Map) = undefined;
    var shapes_variants: [6][]Map = undefined;

    var i: usize = 0;
    var j: usize = 0;
    var t: u64 = 0;
    var skipped: u64 = 0;
    while (try reader.takeDelimiter('\n')) |line| {
        if (line.len == 0) {
            i += 1;
            j = 0;
            continue;
        }

        if (i == 6) {
            for (shapes, 0..) |_, k| {
                shapes_variants[k] = try getUniqueVariants(&shapes[k], allocator);
                // std.debug.print("\n---------------\n\n", .{});
                // for (shapes_variants[k]) |variant| {
                // std.debug.print("\n-----\n{f}\n", .{variant});
                // }
                break;
            }
            var region = try Region.init(allocator, line);
            // std.debug.print("{f}\n", .{region});

            if (!region.isPossible(&shapes)) {
                skipped += 1;
                continue;
            }
            std.debug.print("Need to solve thisn\n", .{});
            t += 1;

            // for (0..region.count[0]) |ifirst| {
            //     for (shapes_variants[0]) |variant| {
            //         for (0..region.map.width) |ifirstX| {
            //             for (0..region.map.heigth) |ifirstY| {
            //                 if (! place(&region.map, &variant, ifirstX, ifirstY)) continue;
            //             }
            //         }
            //
            //     }
            // }
            // _ = place(&region.map, &shapes_variants[0][0], 0, 0);
            // std.debug.print("\n---------------\n\n", .{});
            // std.debug.print("{f}\n", .{region});
        }

        if (std.mem.indexOfScalar(u8, line, ':')) |_| {
            continue;
        }

        if (j == 0) shapes[i] = try Map.initEmpty(allocator, 3, 3);

        const y = j;
        // std.debug.print("i:{d} j:{d} {s}\n", .{ i, j, line });
        for (line, 0..) |c, x| {
            shapes[i].update(x, y, c);
        }
        j += 1;
    }

    std.debug.print("Need to solve : {d}, skippe:{d} total:{d}\n", .{ t, skipped, t + skipped });

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
