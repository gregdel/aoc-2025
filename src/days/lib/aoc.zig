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

        const timer_one_start = try std.time.Instant.now();
        const one = try self.solveFn(&file_reader.interface, .one);
        const timer_one_end = try std.time.Instant.now();

        try file_reader.seekTo(0);

        const timer_two_start = try std.time.Instant.now();
        const two = try self.solveFn(&file_reader.interface, .two);
        const timer_two_end = try std.time.Instant.now();

        std.debug.print(
            \\Parts
            \\ 1 — [{d: >4}ms] {d}
            \\ 2 — [{d: >4}ms] {d}
            \\
        , .{
            @divFloor(timer_one_end.since(timer_one_start), std.time.ns_per_ms),
            one,
            @divFloor(timer_two_end.since(timer_two_start), std.time.ns_per_ms),
            two,
        });
    }
};
