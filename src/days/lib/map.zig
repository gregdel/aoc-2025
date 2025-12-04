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

const Point = struct {
    x: usize,
    y: usize,
    value: u8,

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

    pub fn format(self: Map, writer: *std.io.Writer) std.Io.Writer.Error!void {
        for (0..self.height) |y| {
            const offset = y * self.width;
            _ = try writer.write(self.data[offset .. offset + self.width]);
            try writer.writeByte('\n');
        }
    }

    pub fn getIndex(self: *Map, i: usize) ?Point {
        const x = i % self.width;
        const y = i / self.height;
        return self.get(x, y);
    }

    fn index(self: *Map, x: usize, y: usize) usize {
        return y * self.width + x;
    }

    pub fn update(self: *Map, x: usize, y: usize, value: u8) void {
        self.data[self.index(x, y)] = value;
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
