const std = @import("std");

pub const Direction = enum {
    up,
    upRight,
    right,
    downRight,
    down,
    downLeft,
    left,
    upLeft,
};

pub const all_directions = std.meta.tags(Direction).*;

pub const Point = struct {
    x: usize,
    y: usize,
    value: u8,

    pub fn init(x: usize, y: usize, value: u8) Point {
        return .{
            .x = x,
            .y = y,
            .value = value,
        };
    }

    pub fn format(self: Point, writer: *std.io.Writer) std.Io.Writer.Error!void {
        try writer.print(
            "(x:{d} y:{d}) '{c}'",
            .{ self.x, self.y, self.value },
        );
    }
};

// -----------> x
// |
// |
// |
// |
// v
// y
pub const Map = struct {
    allocator: std.mem.Allocator,
    data: []u8,
    width: usize,
    height: usize,
    obstacle: ?u8 = null,

    pub fn init(allocator: std.mem.Allocator, reader: *std.io.Reader) !Map {
        var width: ?usize = null;
        var height: usize = 0;

        var data: std.ArrayList(u8) = undefined;
        while (try reader.takeDelimiter('\n')) |line| {
            if (width) |w| {
                if (line.len != w) return error.InconsistentMapWidth;
            } else {
                width = line.len;
                data = try std.ArrayList(u8).initCapacity(allocator, width.?);
            }
            try data.appendSlice(allocator, line);
            height += 1;
        }

        return .{
            .data = try data.toOwnedSlice(allocator),
            .allocator = allocator,
            .width = width.?,
            .height = height,
        };
    }

    pub fn initEmpty(allocator: std.mem.Allocator, width: usize, height: usize) !Map {
        const data = try allocator.alloc(u8, width * height);
        @memset(data, '.');
        return .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .data = data,
        };
    }

    pub fn deinit(self: *Map) void {
        self.allocator.free(self.data);
    }

    pub fn dupe(self: *Map) !Map {
        return .{
            .allocator = self.allocator,
            .data = try self.allocator.dupe(u8, self.data),
            .width = self.width,
            .height = self.height,
        };
    }

    pub fn setObstacle(self: *Map, obstacle: u8) void {
        self.obstacle = obstacle;
    }

    pub fn floodFill(self: *Map, c: u8) !void {
        const obstacle = self.obstacle orelse return error.MissingObstacle;

        const Entry = struct {
            index: usize,
            distance: u32,

            const Entry = @This();

            fn cmp(_: void, a: Entry, b: Entry) std.math.Order {
                return std.math.order(a.distance, b.distance);
            }
        };

        var queue: std.PriorityQueue(Entry, void, Entry.cmp) = .init(self.allocator, {});
        defer queue.deinit();

        // Add borders to the todo list
        const last_x = self.width - 1;
        const last_y = self.height - 1;
        for (0..self.width) |x| {
            try queue.add(.{ .index = self.index(x, 0), .distance = 0 });
            try queue.add(.{ .index = self.index(x, last_y), .distance = 0 });
        }
        for (1..self.height - 1) |y| {
            try queue.add(.{ .index = self.index(0, y), .distance = 0 });
            try queue.add(.{ .index = self.index(last_x, y), .distance = 0 });
        }

        var explored: std.AutoHashMap(usize, void) = .init(self.allocator);
        defer explored.deinit();

        const dirs = [_]Direction{ .up, .down, .left, .right };

        while (queue.removeOrNull()) |entry| {
            if (explored.get(entry.index) != null) continue;
            try explored.put(entry.index, {});
            if ((self.data[entry.index]) == obstacle) continue;
            self.data[entry.index] = c;
            const point = self.getIndex(entry.index) orelse unreachable;
            for (dirs) |dir| {
                const next_point = self.next(&point, dir) orelse continue;
                try queue.add(.{ .index = self.indexPoint(next_point), .distance = entry.distance + 1 });
            }
        }

        return;
    }

    pub fn format(self: Map, writer: *std.io.Writer) std.Io.Writer.Error!void {
        for (0..self.height) |y| {
            const offset = y * self.width;
            _ = try writer.write(self.data[offset .. offset + self.width]);
            try writer.writeByte('\n');
        }
        try writer.print(
            "width:{d} height:{d} total:{d}",
            .{
                self.width,
                self.height,
                self.width * self.height,
            },
        );
    }

    pub fn find(self: *Map, rune: u8) ?Point {
        const i = std.mem.indexOfScalar(u8, self.data, rune) orelse return null;
        return self.getIndex(i);
    }

    pub fn getIndex(self: *Map, i: usize) ?Point {
        const x = i % self.width;
        const y = i / self.width;
        return self.get(x, y);
    }

    fn index(self: *Map, x: usize, y: usize) usize {
        return y * self.width + x;
    }

    fn indexPoint(self: *Map, point: Point) usize {
        return self.index(point.x, point.y);
    }

    pub fn update(self: *Map, x: usize, y: usize, value: u8) void {
        self.data[self.index(x, y)] = value;
    }

    pub fn updatePoint(self: *Map, point: Point, value: u8) void {
        self.update(point.x, point.y, value);
    }

    pub fn get(self: *Map, x: usize, y: usize) ?Point {
        if ((x >= self.width) or (y >= self.height)) return null;
        return .{
            .x = x,
            .y = y,
            .value = self.data[self.index(x, y)],
        };
    }

    pub fn next(self: *Map, from: *const Point, direction: Direction) ?Point {
        var x = from.x;
        var y = from.y;

        switch (direction) {
            .upRight, .right, .downRight => {
                x += 1;
                if (x >= self.width) return null;
            },
            .upLeft, .left, .downLeft => {
                if (x == 0) return null;
                x -= 1;
            },
            else => {},
        }

        switch (direction) {
            .upLeft, .up, .upRight => {
                if (y == 0) return null;
                y -= 1;
            },
            .downLeft, .down, .downRight => {
                y += 1;
                if (y >= self.height) return null;
            },
            else => {},
        }

        return self.get(x, y);
    }

    const Iterator = struct {
        current: ?usize = null,
        map: *Map,

        pub fn next(self: *Iterator) ?Point {
            self.current = if (self.current) |c| c + 1 else 0;
            if (self.current == self.map.data.len) return null;
            return self.map.getIndex(self.current.?);
        }
    };

    pub fn iterator(self: *Map) Iterator {
        return .{ .map = self };
    }
};
