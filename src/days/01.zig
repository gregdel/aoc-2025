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
        .one => handle.zero_end,
        .two => handle.zero_passed_by,
    };
}

const Handle = struct {
    position: u8,
    zero_end: u64 = 0,
    zero_passed_by: u64 = 0,

    fn rotate(self: *Handle, input: []const u8) !void {
        const total_ticks = try std.fmt.parseInt(u16, input[1..], 10);
        const ticks = total_ticks % 100;
        const turns = total_ticks / 100;

        var move = ticks;
        var passed_zero = false;
        switch (input[0]) {
            'L' => {
                passed_zero = (self.position != 0) and (move > self.position);
                move = (100 - ticks);
            },
            'R' => {
                passed_zero = (self.position != 0) and (self.position + move > 99);
            },
            else => unreachable,
        }

        self.zero_passed_by += turns;
        self.position = @truncate(@as(u16, (self.position + move) % 100));

        if (self.position == 0) {
            self.zero_end += 1;
            passed_zero = true;
        }

        if (passed_zero) self.zero_passed_by += 1;
    }
};

test "passed by zero" {
    var handle: Handle = .{ .position = 1 };
    try handle.rotate("L2");
    try std.testing.expectEqual(99, handle.position);
    try std.testing.expectEqual(1, handle.zero_passed_by);
    try std.testing.expectEqual(0, handle.zero_end);

    try handle.rotate("R2");
    try std.testing.expectEqual(1, handle.position);
    try std.testing.expectEqual(2, handle.zero_passed_by);
    try std.testing.expectEqual(0, handle.zero_end);

    try handle.rotate("R100");
    try std.testing.expectEqual(1, handle.position);
    try std.testing.expectEqual(3, handle.zero_passed_by);
    try std.testing.expectEqual(0, handle.zero_end);

    try handle.rotate("L100");
    try std.testing.expectEqual(1, handle.position);
    try std.testing.expectEqual(4, handle.zero_passed_by);
    try std.testing.expectEqual(0, handle.zero_end);

    try handle.rotate("L1");
    try std.testing.expectEqual(0, handle.position);
    try std.testing.expectEqual(5, handle.zero_passed_by);
    try std.testing.expectEqual(1, handle.zero_end);

    try handle.rotate("L1");
    try std.testing.expectEqual(99, handle.position);
    try std.testing.expectEqual(5, handle.zero_passed_by);
    try std.testing.expectEqual(1, handle.zero_end);

    try handle.rotate("R1");
    try std.testing.expectEqual(0, handle.position);
    try std.testing.expectEqual(6, handle.zero_passed_by);
    try std.testing.expectEqual(2, handle.zero_end);
}

test "part 2 example" {
    var handle: Handle = .{ .position = 50 };
    try handle.rotate("R1000");
    try std.testing.expectEqual(50, handle.position);
    try std.testing.expectEqual(10, handle.zero_passed_by);
}

test "end at zero" {
    var handle: Handle = .{ .position = 1 };
    try handle.rotate("L1"); // position: 0
    try handle.rotate("R1"); // position: 1
    try handle.rotate("L1"); // position: 0
    try std.testing.expectEqual(2, handle.zero_passed_by);
}

test "tests part 1 and 2" {
    const input =
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

    var reader = std.io.Reader.fixed(input);
    const one = try solve(&reader, .one);
    reader = std.io.Reader.fixed(input);
    const two = try solve(&reader, .two);

    try std.testing.expectEqual(3, one);
    try std.testing.expectEqual(6, two);
}
