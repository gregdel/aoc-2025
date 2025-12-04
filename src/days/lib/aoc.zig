const std = @import("std");

const Input = @import("input.zig").Input;

pub const Part = enum { one, two };

pub const Day = struct {
    day: u8,
    input: Input,
    solveFn: *const fn (*std.io.Reader, Part) anyerror!u64,

    pub fn init(day: u8, solveFn: *const fn (*std.io.Reader, Part) anyerror!u64) !Day {
        return .{
            .day = day,
            .input = try Input.init(day),
            .solveFn = solveFn,
        };
    }

    pub fn deinit(self: *Day) void {
        self.input.deinit();
    }

    pub fn solve(self: *Day) !void {
        var buf: [4096]u8 = undefined;
        var file_reader = try self.input.reader(&buf);

        const one = try self.solveFn(&file_reader.interface, .one);
        try file_reader.seekTo(0);
        const two = try self.solveFn(&file_reader.interface, .two);
        std.debug.print("part_one:{d} part_two:{d}\n", .{ one, two });
    }
};
