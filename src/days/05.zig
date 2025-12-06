const std = @import("std");

const Part = @import("lib/aoc.zig").Part;
const Day = @import("lib/aoc.zig").Day;

pub fn main() !void {
    var day = try Day.init(5, solve);
    defer day.deinit();
    try day.solve();
}

fn solve(reader: *std.io.Reader, part: Part) !u64 {
    var gpa: std.heap.DebugAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var ranges = try Ranges.init(allocator);
    defer ranges.deinit();

    var result: u64 = 0;
    var in_ranges = true;
    while (try reader.takeDelimiter('\n')) |line| {
        if (line.len == 0) {
            in_ranges = false;
            try ranges.compactAll();
            continue;
        }

        if (in_ranges) {
            try ranges.append(try Range.parse(line));
        } else {
            const number = try std.fmt.parseInt(u64, line, 10);
            if (part == .one) {
                if (ranges.contains(number)) result += 1;
            }
        }
    }

    if (part == .two) result = ranges.total();
    return result;
}

const Ranges = struct {
    allocator: std.mem.Allocator,
    data: std.ArrayList(Range),

    fn append(self: *Ranges, new_range: Range) !void {
        for (self.data.items) |*range| {
            if (range.merge(new_range)) return;
        }

        try self.data.append(self.allocator, new_range);
    }

    fn total(self: *Ranges) u64 {
        var result: u64 = 0;
        for (self.data.items) |range| result += range.total();
        return result;
    }

    fn compactAll(self: *Ranges) !void {
        while (try self.compactOne()) {}
    }

    fn compactOne(self: *Ranges) !bool {
        for (self.data.items[0 .. self.data.items.len - 1], 0..) |*range, i| {
            for (self.data.items[i + 1 ..], i + 1..) |other, j| {
                if (!range.merge(other)) continue;
                _ = self.data.swapRemove(j);
                return true;
            }
        }
        return false;
    }

    fn contains(self: *Ranges, number: u64) bool {
        for (self.data.items) |range| {
            if (range.contains(number)) return true;
        }
        return false;
    }

    fn init(allocator: std.mem.Allocator) !Ranges {
        return .{
            .allocator = allocator,
            .data = try std.ArrayList(Range).initCapacity(allocator, 1),
        };
    }

    fn deinit(self: *Ranges) void {
        self.data.deinit(self.allocator);
    }
};

const Range = struct {
    start: u64,
    end: u64,

    fn total(self: Range) u64 {
        return self.end - self.start + 1;
    }

    fn parse(line: []u8) !Range {
        const index = std.mem.indexOfScalar(u8, line, '-') orelse return error.InvalidRange;
        const start = try std.fmt.parseInt(u64, line[0..index], 10);
        const end = try std.fmt.parseInt(u64, line[index + 1 ..], 10);
        return .{
            .start = start,
            .end = end,
        };
    }

    fn contains(self: Range, number: u64) bool {
        return (number >= self.start and number <= self.end);
    }

    fn merge(self: *Range, other: Range) bool {
        const overlap = (self.contains(other.start) or
            other.contains(self.start) or
            self.contains(other.end) or
            other.contains(self.end));

        if (overlap) {
            self.start = @min(self.start, other.start);
            self.end = @max(self.end, other.end);
        }
        return overlap;
    }
};

const test_input =
    \\3-5
    \\10-14
    \\16-20
    \\12-18
    \\
    \\1
    \\5
    \\8
    \\11
    \\17
    \\32
;

test "test part 1" {
    var reader = std.io.Reader.fixed(test_input);
    const result = try solve(&reader, .one);
    try std.testing.expectEqual(3, result);
}

test "test part 2" {
    var reader = std.io.Reader.fixed(test_input);
    const result = try solve(&reader, .two);
    try std.testing.expectEqual(14, result);
}
