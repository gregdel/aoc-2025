const std = @import("std");

const Part = @import("lib/aoc.zig").Part;
const Day = @import("lib/aoc.zig").Day;
const Map = @import("lib/map.zig").Map;

pub fn main() !void {
    var day = try Day.init(9, solve);
    defer day.deinit();
    try day.solve();
}

const Point = struct {
    x: u64,
    y: u64,

    fn init(input: []u8) !Point {
        var it = std.mem.splitScalar(u8, input, ',');
        return .{
            .x = try std.fmt.parseInt(u64, it.next() orelse unreachable, 10),
            .y = try std.fmt.parseInt(u64, it.next() orelse unreachable, 10),
        };
    }
};

const Segment = struct {
    a: Point,
    b: Point,

    fn init(a: Point, b: Point) Segment {
        return .{ .a = a, .b = b };
    }

    fn dist(a: u64, b: u64) u64 {
        return if (a > b) (a - b + 1) else (b - a + 1);
    }

    fn areaSize(self: *const Segment) u64 {
        return dist(self.a.x, self.b.x) * dist(self.a.y, self.b.y);
    }
};

const Area = struct {
    allocator: std.mem.Allocator,
    points: std.ArrayList(Point),
    max_area_size: u64 = 0,

    map: Map = undefined,
    x_map: std.AutoHashMap(u64, u64) = undefined,
    y_map: std.AutoHashMap(u64, u64) = undefined,

    fn init(allocator: std.mem.Allocator) !Area {
        return .{
            .allocator = allocator,
            .points = try .initCapacity(allocator, 1),
        };
    }

    fn area(self: *Area, i: usize, j: usize) u64 {
        const a = self.points.items[i];
        const b = self.points.items[j];
        const seg = Segment.init(a, b);
        const size = seg.areaSize();
        if (size <= self.max_area_size) return 0;

        const ca = self.compressed(a);
        const cb = self.compressed(b);

        const x_min = if (ca.x < cb.x) ca.x else cb.x;
        const x_max = if (ca.x < cb.x) cb.x else ca.x;
        const y_min = if (ca.y < cb.y) ca.y else cb.y;
        const y_max = if (ca.y < cb.y) cb.y else ca.y;

        for (x_min..x_max + 1) |x| {
            for (y_min..y_max + 1) |y| {
                const point = self.map.get(x, y) orelse unreachable;
                if (point.value == 'x') {
                    return 0;
                }
            }
        }

        return size;
    }

    fn findMaxArea(self: *Area) !void {
        try self.buildMap();
        self.map.setObstacle('#');
        try self.map.floodFill('x');
        self.max_area_size = 0;

        const total = self.points.items.len;
        for (0..total - 1) |i| {
            for (i + 1..total) |j| {
                self.max_area_size = @max(self.max_area_size, self.area(i, j));
            }
        }
    }

    fn compressed(self: *Area, point: Point) Point {
        return .{
            .x = self.x_map.get(point.x) orelse unreachable,
            .y = self.y_map.get(point.y) orelse unreachable,
        };
    }

    fn buildMap(self: *Area) !void {
        const len = self.points.items.len;
        var x_list: std.ArrayList(u64) = try .initCapacity(self.allocator, len);
        defer x_list.deinit(self.allocator);
        var y_list: std.ArrayList(u64) = try .initCapacity(self.allocator, len);
        defer y_list.deinit(self.allocator);
        for (self.points.items) |point| {
            const x = point.x;
            if (std.mem.indexOfScalar(u64, x_list.items, x)) |_| {} else {
                try x_list.append(self.allocator, point.x);
            }

            const y = point.y;
            if (std.mem.indexOfScalar(u64, y_list.items, y)) |_| {} else {
                try y_list.append(self.allocator, point.y);
            }
        }
        std.sort.block(u64, x_list.items, {}, std.sort.asc(u64));
        std.sort.block(u64, y_list.items, {}, std.sort.asc(u64));
        self.x_map = .init(self.allocator);
        for (x_list.items, 0..) |x, i| try self.x_map.put(x, i);
        self.y_map = .init(self.allocator);
        for (y_list.items, 0..) |y, i| try self.y_map.put(y, i);

        const width = x_list.items.len;
        const height = y_list.items.len;
        self.map = try .initEmpty(self.allocator, width, height);
        for (self.points.items) |point| {
            const cp = self.compressed(point);
            self.map.update(cp.x, cp.y, '#');
        }

        var i: usize = 0;
        const entries = self.points.items.len;
        while (i != entries) : (i += 1) {
            const current = self.compressed(self.points.items[i]);
            const next = self.compressed(self.points.items[(i + 1) % entries]);

            if (current.x == next.x) {
                const min_y = if (current.y < next.y) current.y else next.y;
                const max_y = if (current.y < next.y) next.y else current.y;
                for (min_y..max_y + 1) |y| self.map.update(current.x, y, '#');
            } else if (current.y == next.y) {
                const min_x = if (current.x < next.x) current.x else next.x;
                const max_x = if (current.x < next.x) next.x else current.x;
                for (min_x..max_x + 1) |x| self.map.update(x, current.y, '#');
            } else unreachable;
        }
    }

    fn addPoint(self: *Area, point: Point, part: Part) !void {
        try self.points.append(self.allocator, point);
        if (part == .two) return;

        const entries = self.points.items.len;
        if (entries == 1) return;
        for (0..entries - 2) |i| {
            self.max_area_size = @max(
                self.max_area_size,
                Segment.init(point, self.points.items[i]).areaSize(),
            );
        }
    }
};

fn solve(reader: *std.io.Reader, part: Part) !u64 {
    var gpa: std.heap.DebugAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    var arena: std.heap.ArenaAllocator = .init(gpa.allocator());
    const allocator = arena.allocator();
    defer arena.deinit();

    var area: Area = try .init(allocator);
    while (try reader.takeDelimiter('\n')) |line| {
        try area.addPoint(try Point.init(line), part);
    }

    if (part == .two) try area.findMaxArea();

    return area.max_area_size;
}

const test_input =
    \\7,1
    \\11,1
    \\11,7
    \\9,7
    \\9,5
    \\2,5
    \\2,3
    \\7,3
;

test "test part 1" {
    var reader = std.io.Reader.fixed(test_input);
    const result = try solve(&reader, .one);
    try std.testing.expectEqual(50, result);
}

test "test part 2" {
    var reader = std.io.Reader.fixed(test_input);
    const result = try solve(&reader, .two);
    try std.testing.expectEqual(24, result);
}
