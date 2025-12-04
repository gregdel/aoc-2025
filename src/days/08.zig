const std = @import("std");

const Part = @import("lib/aoc.zig").Part;
const Day = @import("lib/aoc.zig").Day;

pub fn main() !void {
    var day = try Day.init(8, solve);
    defer day.deinit();
    try day.solve();
}

const Segment = struct {
    start: *Point,
    end: *Point,
    distance: f64,
};

fn segCmp(_: void, a: Segment, b: Segment) std.math.Order {
    return std.math.order(a.distance, b.distance);
}

const Circuit = struct {
    points: std.AutoHashMap(*Point, void),

    fn init(allocator: std.mem.Allocator) Circuit {
        return .{ .points = .init(allocator) };
    }

    fn count(self: *const Circuit) usize {
        return self.points.count();
    }

    fn add(self: *Circuit, point: *Point) !void {
        point.circuit = self;
        try self.points.put(point, {});
    }

    fn merge(self: *Circuit, other: *Circuit) !void {
        if (self == other) return;
        var it = other.points.iterator();
        while (it.next()) |p| try self.add(p.key_ptr.*);
        other.points.clearAndFree();
    }
};

const Point = struct {
    x: u64,
    y: u64,
    z: u64,
    circuit: ?*Circuit = null,

    fn init(input: []u8) !Point {
        var it = std.mem.splitScalar(u8, input, ',');
        return .{
            .x = try std.fmt.parseInt(u64, it.next() orelse unreachable, 10),
            .y = try std.fmt.parseInt(u64, it.next() orelse unreachable, 10),
            .z = try std.fmt.parseInt(u64, it.next() orelse unreachable, 10),
        };
    }

    fn toVec(self: *Point) @Vector(3, f64) {
        return .{
            @floatFromInt(self.x),
            @floatFromInt(self.y),
            @floatFromInt(self.z),
        };
    }

    fn distance(self: *Point, other: *Point) !f64 {
        const diff = self.toVec() - other.toVec();
        const squared = diff * diff;
        return @sqrt(squared[0] + squared[1] + squared[2]);
    }
};

fn solve(reader: *std.io.Reader, part: Part) !u64 {
    var gpa: std.heap.DebugAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    var arena: std.heap.ArenaAllocator = .init(gpa.allocator());
    const allocator = arena.allocator();
    defer arena.deinit();

    var points: std.ArrayList(Point) = try .initCapacity(allocator, 8);
    while (try reader.takeDelimiter('\n')) |line| {
        try points.append(allocator, try Point.init(line));
    }

    // Compute all distances
    var distances: std.PriorityDequeue(Segment, void, segCmp) = .init(allocator, {});
    for (points.items, 0..) |*point, i| {
        if (i == points.items.len - 1) break;
        for (i + 1..points.items.len) |j| {
            const other = &points.items[j];
            try distances.add(.{
                .start = point,
                .end = other,
                .distance = try point.distance(other),
            });
        }
    }

    const max = if (part == .one)
        if (@import("builtin").is_test) 10 else 1000
    else
        distances.count();

    var circuits: std.ArrayList(Circuit) = try .initCapacity(allocator, points.items.len);
    for (0..max) |_| {
        var updated: ?*Circuit = null;
        const s = distances.removeMin();
        if (s.start.circuit) |start_circuit| {
            if (s.end.circuit) |end_circuit| {
                try start_circuit.merge(end_circuit);
            } else {
                try start_circuit.add(s.end);
            }
            updated = start_circuit;
        } else {
            if (s.end.circuit) |end_circuit| {
                try end_circuit.add(s.start);
                updated = end_circuit;
            } else {
                const new_id = circuits.items.len;
                try circuits.append(allocator, Circuit.init(allocator));
                var circuit = &circuits.items[new_id];
                try circuit.add(s.start);
                try circuit.add(s.end);
                updated = circuit;
            }
        }

        if (part == .two) if (updated) |c| {
            if (c.count() == points.items.len) {
                return s.start.x * s.end.x;
            }
        };
    }

    var counts: std.ArrayList(u64) = try .initCapacity(allocator, max);
    for (circuits.items) |*circuit| try counts.append(allocator, circuit.count());
    const items = try counts.toOwnedSlice(allocator);
    std.sort.block(u64, items, {}, std.sort.desc(u64));
    return items[0] * items[1] * items[2];
}

const test_input =
    \\162,817,812
    \\57,618,57
    \\906,360,560
    \\592,479,940
    \\352,342,300
    \\466,668,158
    \\542,29,236
    \\431,825,988
    \\739,650,466
    \\52,470,668
    \\216,146,977
    \\819,987,18
    \\117,168,530
    \\805,96,715
    \\346,949,466
    \\970,615,88
    \\941,993,340
    \\862,61,35
    \\984,92,344
    \\425,690,689
;

test "test part 1" {
    var reader = std.io.Reader.fixed(test_input);
    const result = try solve(&reader, .one);
    try std.testing.expectEqual(40, result);
}

test "test part 2" {
    var reader = std.io.Reader.fixed(test_input);
    const result = try solve(&reader, .two);
    try std.testing.expectEqual(25272, result);
}
