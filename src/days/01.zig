const std = @import("std");

const Day = @import("lib/aoc.zig").Day;
const Part = @import("lib/aoc.zig").Part;

pub fn main() !void {
    var day = try Day.init(1, solve);
    defer day.deinit();
    try day.solve();
}

fn solve(reader: *std.io.Reader, part: Part) !u64 {
    var handle: Handle = .{ .position = 50 };
    while (try reader.takeDelimiter('\n')) |line| {
        try handle.rotate(line);
    }
    return switch (part) {
        .one => handle.end_at_zero,
        .two => handle.passed_by_zero,
    };
}

const Handle = struct {
    position: u8,
    end_at_zero: u64 = 0,
    passed_by_zero: u64 = 0,

    fn rotate(self: *Handle, input: []const u8) !void {
        const total_ticks = try std.fmt.parseInt(u16, input[1..], 10);
        const ticks = total_ticks % 100;
        const turns = total_ticks / 100;

        const clockwise = switch (input[0]) {
            'L' => false,
            'R' => true,
            else => return error.InvalidInput,
        };

        const move = if (clockwise) ticks else 100 - ticks;
        var passed_zero = (self.position != 0) and if (clockwise)
            (self.position + ticks > 99)
        else
            (ticks > self.position);

        self.passed_by_zero += turns;
        self.position = @truncate(@as(u16, (self.position + move) % 100));

        if (self.position == 0) {
            self.end_at_zero += 1;
            passed_zero = true;
        }

        if (passed_zero) self.passed_by_zero += 1;
    }
};

test "passed by zero" {
    var handle: Handle = .{ .position = 1 };
    try handle.rotate("L2");
    try std.testing.expectEqual(Handle{
        .position = 99,
        .passed_by_zero = 1,
        .end_at_zero = 0,
    }, handle);

    try handle.rotate("R2");
    try std.testing.expectEqual(1, handle.position);
    try std.testing.expectEqual(2, handle.passed_by_zero);
    try std.testing.expectEqual(0, handle.end_at_zero);

    try handle.rotate("R100");
    try std.testing.expectEqual(1, handle.position);
    try std.testing.expectEqual(3, handle.passed_by_zero);
    try std.testing.expectEqual(0, handle.end_at_zero);

    try handle.rotate("L100");
    try std.testing.expectEqual(1, handle.position);
    try std.testing.expectEqual(4, handle.passed_by_zero);
    try std.testing.expectEqual(0, handle.end_at_zero);

    try handle.rotate("L1");
    try std.testing.expectEqual(0, handle.position);
    try std.testing.expectEqual(5, handle.passed_by_zero);
    try std.testing.expectEqual(1, handle.end_at_zero);

    try handle.rotate("L1");
    try std.testing.expectEqual(99, handle.position);
    try std.testing.expectEqual(5, handle.passed_by_zero);
    try std.testing.expectEqual(1, handle.end_at_zero);

    try handle.rotate("R1");
    try std.testing.expectEqual(0, handle.position);
    try std.testing.expectEqual(6, handle.passed_by_zero);
    try std.testing.expectEqual(2, handle.end_at_zero);
}

test "part 2 example" {
    var handle: Handle = .{ .position = 50 };
    try handle.rotate("R1000");
    try std.testing.expectEqual(50, handle.position);
    try std.testing.expectEqual(10, handle.passed_by_zero);
}

test "end at zero" {
    var handle: Handle = .{ .position = 1 };
    try handle.rotate("L1"); // position: 0
    try handle.rotate("R1"); // position: 1
    try handle.rotate("L1"); // position: 0
    try std.testing.expectEqual(2, handle.passed_by_zero);
}

const test_input =
    \\L68
    \\L30
    \\R48
    \\L5
    \\R60
    \\L55
    \\L1
    \\L99
    \\R14
    \\L82
;

test "tests part 1" {
    var reader = std.io.Reader.fixed(test_input);
    const one = try solve(&reader, .one);
    try std.testing.expectEqual(3, one);
}

test "tests part 2" {
    var reader = std.io.Reader.fixed(test_input);
    const one = try solve(&reader, .two);
    try std.testing.expectEqual(6, one);
}
