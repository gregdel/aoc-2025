const std = @import("std");

pub fn main() !void {
    var file = try std.fs.cwd().openFile("inputs/1", .{});
    defer file.close();

    var buf = std.mem.zeroes([4096]u8);
    var file_reader = file.reader(&buf);
    const result = try solve(&file_reader.interface);
    std.debug.print(
        "Result: part_1:{d} part_2:{d}\n",
        .{ result.zero_end, result.zero_passed_by },
    );
}

fn solve(reader: *std.io.Reader) !Handle {
    var handle: Handle = .{ .position = 50 };
    while (try reader.takeDelimiter('\n')) |line| {
        try handle.rotate(line);
    }
    return handle;
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
    const result = try solve(&reader);
    try std.testing.expectEqual(3, result.zero_end);
    try std.testing.expectEqual(6, result.zero_passed_by);
}
