const std = @import("std");

const Part = @import("lib/aoc.zig").Part;
const Day = @import("lib/aoc.zig").Day;

pub fn main() !void {
    var day = try Day.init(6, solve);
    defer day.deinit();
    try day.solve();
}

const Op = enum { mul, add };

const OpIndex = struct {
    op: Op,
    index: usize,
    len: ?usize = null,

    fn init(scalar: u8, index: usize) !OpIndex {
        return .{
            .index = index,
            .op = switch (scalar) {
                '+' => .add,
                '*' => .mul,
                else => return error.InvalidOp,
            },
        };
    }

    fn setLen(self: *OpIndex, next_index: usize) void {
        self.len = next_index - self.index - 1;
    }

    fn extract(self: *const OpIndex, input: []u8) []u8 {
        if (self.len) |len| {
            return input[self.index .. self.index + len];
        } else {
            return input[self.index..];
        }
    }

    fn extractOne(_: *const OpIndex, input: []u8, index: usize) ?u8 {
        if (index >= input.len) return null;
        return switch (input[index]) {
            ' ' => null,
            else => input[index] - '0',
        };
    }

    fn identity(self: *const OpIndex) u64 {
        return if (self.op == .mul) 1 else 0;
    }
};

fn solve(reader: *std.io.Reader, part: Part) !u64 {
    var gpa: std.heap.DebugAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var ops: std.ArrayList(OpIndex) = try .initCapacity(allocator, 1);
    defer ops.deinit(allocator);

    var lines: std.ArrayList([]u8) = try .initCapacity(allocator, 1);
    defer {
        for (lines.items) |line| allocator.free(line);
        lines.deinit(allocator);
    }

    while (try reader.takeDelimiter('\n')) |line| {
        const is_op = switch (line[0]) {
            '*', '+' => true,
            else => false,
        };
        if (is_op) {
            for (line, 0..) |c, i| {
                if (c == ' ') continue;
                try ops.append(allocator, try .init(c, i));
                if (i > 0) ops.items[ops.items.len - 2].setLen(i);
            }
        } else {
            try lines.append(allocator, try allocator.dupe(u8, line));
        }
    }

    var result: u64 = 0;
    for (ops.items) |op| {
        var acc: u64 = op.identity();
        if (part == .one) {
            for (lines.items) |line| {
                const raw_input = op.extract(line);
                const input = std.mem.trim(u8, raw_input, " ");
                const value = try std.fmt.parseInt(u64, input, 10);
                switch (op.op) {
                    .add => acc += value,
                    .mul => acc *= value,
                }
            }
        } else {
            const start = op.index;
            const len = op.len orelse 4;
            const end = start + len;
            for (start..end) |i| {
                var value: u64 = 0;
                for (lines.items) |line| {
                    if (op.extractOne(line, i)) |v| {
                        value = value * 10 + v;
                    }
                }
                if (value == 0) continue;
                switch (op.op) {
                    .add => acc += value,
                    .mul => acc *= value,
                }
            }
        }
        result += acc;
    }

    return result;
}

const test_input =
    \\123 328  51 64
    \\ 45 64  387 23
    \\  6 98  215 314
    \\*   +   *   +
;

test "test part 1" {
    var reader = std.io.Reader.fixed(test_input);
    const result = try solve(&reader, .one);
    try std.testing.expectEqual(4277556, result);
}

test "test part 2" {
    var reader = std.io.Reader.fixed(test_input);
    const result = try solve(&reader, .two);
    try std.testing.expectEqual(3263827, result);
}
