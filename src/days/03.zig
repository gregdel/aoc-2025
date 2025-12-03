const std = @import("std");

pub fn main() !void {
    var file = try std.fs.cwd().openFile("inputs/3", .{});
    defer file.close();

    var buf = std.mem.zeroes([4096]u8);
    var file_reader = file.reader(&buf);

    const one = try solve(&file_reader.interface, false);
    const two = try solve(&file_reader.interface, true);
    std.debug.print("Result: part_1:{d} part_2:{d}\n", .{ one, two });
}

fn findMax(line: []u8, digits: u8, acc: u64, current_max: u64) ?u64 {
    if (acc < current_max) return null;
    if (digits == 0) return acc;
    const remaining = digits - 1;
    if (line.len < digits) return null;

    var max = acc;
    for (0..line.len - remaining) |i| {
        const cur = (line[i] - '0') * std.math.pow(u64, 10, digits - 1);
        if (findMax(line[i + 1 ..], remaining, acc + cur, max)) |value| {
            max = @max(max, value);
        } else {
            continue;
        }
    }

    return max;
}

fn solve(reader: *std.io.Reader, part_two: bool) !u64 {
    var result: u64 = 0;
    const digits: u8 = if (part_two) 12 else 2;
    while (try reader.takeDelimiter('\n')) |line| {
        result += findMax(line, digits, 0, 0) orelse unreachable;
    }
    return result;
}

const test_input =
    \\987654321111111
    \\811111111111119
    \\234234234234278
    \\818181911112111
;

test "test part 1" {
    var reader = std.io.Reader.fixed(test_input);
    const result = try solve(&reader, false);
    try std.testing.expectEqual(357, result);
}

test "test part 2" {
    var reader = std.io.Reader.fixed(test_input);
    const result = try solve(&reader, true);
    try std.testing.expectEqual(3121910778619, result);
}
