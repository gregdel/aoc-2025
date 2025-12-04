const std = @import("std");

const Day = @import("lib/aoc.zig").Day;
const Part = @import("lib/aoc.zig").Part;

pub fn main() !void {
    var day = try Day.init(3, solve);
    defer day.deinit();
    try day.solve();
}

fn findMax(line: []u8, current_digits: u8, target_digits: u8, value: u64) ?u64 {
    var i: u8 = 9;
    while (i > 0) : (i -= 1) {
        const index = std.mem.indexOfScalar(u8, line, '0' + i) orelse continue;
        const new_value: u64 = 10 * value + line[index] - '0';
        const found_digits = current_digits + 1;
        if (found_digits == target_digits) return new_value;

        const new_index = index + 1;
        if (new_index >= line.len) continue;

        if (findMax(line[new_index..], found_digits, target_digits, new_value)) |max| {
            return max;
        }
    }
    return null;
}

fn solve(reader: *std.io.Reader, part: Part) !u64 {
    var result: u64 = 0;
    const digits: u8 = if (part == .two) 12 else 2;
    while (try reader.takeDelimiter('\n')) |line| {
        result += findMax(line, 0, digits, 0) orelse unreachable;
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
    const result = try solve(&reader, .one);
    try std.testing.expectEqual(357, result);
}

test "test part 2" {
    var reader = std.io.Reader.fixed(test_input);
    const result = try solve(&reader, .two);
    try std.testing.expectEqual(3121910778619, result);
}
