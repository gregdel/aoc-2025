const std = @import("std");

const Input = @import("lib/input.zig").Input;
const Part = @import("lib/aoc.zig").Part;

pub fn main() !void {
    var input = try Input.init(2);
    defer input.deinit();

    var buf: [4096]u8 = undefined;
    var file_reader = try input.reader(&buf);

    const one = try solve(&file_reader.interface, .one);
    try file_reader.seekTo(0);
    const two = try solve(&file_reader.interface, .two);
    std.debug.print("part_one:{d} part_two:{d}\n", .{ one, two });
}

fn solve(reader: *std.io.Reader, part: Part) !u64 {
    var result: u64 = 0;
    while (try reader.takeDelimiter(',')) |input| {
        const range = std.mem.trim(u8, input, "\n");
        const index = std.mem.indexOf(u8, range, "-") orelse unreachable;
        const start = try std.fmt.parseInt(u64, range[0..index], 10);
        const end = try std.fmt.parseInt(u64, range[index + 1 ..], 10);

        for (start..end + 1) |i| {
            const digits = std.math.log(u64, 10, i) + 1;
            switch (part) {
                .one => {
                    if (isInvalid(i, digits, 2)) result += i;
                },
                .two => {
                    for (2..digits + 1) |parts| {
                        if (isInvalid(i, digits, parts)) {
                            result += i;
                            break;
                        }
                    }
                },
            }
        }
    }
    return result;
}

fn isInvalid(input: u64, digits: u64, parts: u64) bool {
    if (digits % parts != 0) return false;
    const pow = std.math.pow(u64, 10, digits / parts);
    const part = input % pow;

    var value: u64 = 0;
    for (0..parts) |_| {
        value *= pow;
        value += part;
    }

    return value == input;
}

const test_input =
    \\11-22,95-115,998-1012,1188511880-1188511890,
    \\222220-222224,1698522-1698528,446443-446449,
    \\38593856-38593862,565653-565659,
    \\824824821-824824827,2121212118-2121212124
;

test "test part 1" {
    var reader = std.io.Reader.fixed(test_input);
    const result = try solve(&reader, .one);
    try std.testing.expectEqual(1227775554, result);
}

test "test part 2" {
    var reader = std.io.Reader.fixed(test_input);
    const result = try solve(&reader, .two);
    try std.testing.expectEqual(4174379265, result);
}
