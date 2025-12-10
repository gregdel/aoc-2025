const std = @import("std");

const Part = @import("lib/aoc.zig").Part;
const Day = @import("lib/aoc.zig").Day;
const Map = @import("lib/map.zig").Map;

pub fn main() !void {
    var day = try Day.init(10, solve);
    defer day.deinit();
    try day.solve();
}

const Machine = struct {
    allocator: std.mem.Allocator,
    on: u16 = 0,
    counter: @Vector(10, u16) = @splat(0),
    buttons: std.ArrayList(u16),
    button_vectors: std.ArrayList(@Vector(10, u16)),
    cache: std.AutoHashMap(struct { v: @Vector(10, u16), r: usize }, void),
    vector_cache: std.AutoHashMap(@Vector(10, u16), usize),
    best_move: ?u64 = null,
    skipped: u64 = 0,

    fn init(allocator: std.mem.Allocator) !Machine {
        return .{
            .allocator = allocator,
            .buttons = try .initCapacity(allocator, 8),
            .button_vectors = try .initCapacity(allocator, 8),
            .cache = .init(allocator),
            .vector_cache = .init(allocator),
        };
    }

    fn clear(self: *Machine) void {
        self.best_move = null;
        self.skipped = 0;
        self.on = 0;
        self.counter = @splat(0);
        self.buttons.clearRetainingCapacity();
        self.button_vectors.clearRetainingCapacity();
        self.cache.clearRetainingCapacity();
        self.vector_cache.clearRetainingCapacity();
    }

    fn shift(i: usize) u16 {
        return @shlExact(@as(u16, 1), @as(u4, @truncate(i)));
    }

    fn parse(self: *Machine, line: []u8) !void {
        var it = std.mem.splitScalar(u8, line, ' ');
        while (it.next()) |item| {
            switch (item[0]) {
                '[' => {
                    const last = std.mem.indexOfScalar(u8, item, ']') orelse unreachable;
                    const input = item[1..last];
                    for (input, 0..) |c, i| switch (c) {
                        '#' => self.on |= shift(i),
                        else => continue,
                    };
                },
                '(' => {
                    const last = std.mem.indexOfScalar(u8, item, ')') orelse unreachable;
                    var entries = std.mem.splitScalar(u8, item[1..last], ',');
                    var button: u16 = 0;
                    var button_vector: @Vector(10, u16) = @splat(0);
                    var i: usize = 0;
                    while (entries.next()) |entry| {
                        const value = try std.fmt.parseInt(usize, entry, 10);
                        button |= shift(value);
                        button_vector[value] = 1;
                        i += 1;
                    }
                    try self.buttons.append(self.allocator, button);
                    try self.button_vectors.append(self.allocator, button_vector);
                },
                '{' => {
                    const last = std.mem.indexOfScalar(u8, item, '}') orelse unreachable;
                    var entries = std.mem.splitScalar(u8, item[1..last], ',');
                    var i: usize = 0;
                    while (entries.next()) |entry| {
                        const value = try std.fmt.parseInt(u16, entry, 10);
                        self.counter[i] = value;
                        i += 1;
                    }
                },
                else => {},
            }
        }
    }

    fn press(self: *Machine, initial: u16, remaining: usize) bool {
        if (remaining == 0) return false;
        for (self.buttons.items) |button| {
            const value = initial ^ button;
            if (value == self.on) return true;
            if (self.press(value, remaining - 1)) return true;
        }
        return false;
    }

    fn minButtons(self: *Machine) u64 {
        for (1..10) |presses| if (self.press(0, presses)) return presses;
        return 0;
    }

    fn pressVector(self: *Machine, initial: @Vector(10, u16), remaining: usize) !bool {
        if (self.cache.get(.{ .v = initial, .r = remaining })) |_| {
            // std.debug.print("*** {any} {d}\n", .{ initial, remaining });
            return false;
        }
        try self.cache.put(.{ .v = initial, .r = remaining }, {});

        // std.debug.print("{d:0>3} {any}\n", .{ remaining, initial });
        if (remaining == 0) return false;
        for (self.button_vectors.items) |v| {
            const value = initial + v;
            // std.debug.print("{d:0>3} {any} + {any} = {any}\n", .{ remaining, initial, v, value });
            // std.debug.print("{any}: initial:{any} value:{any} remaining:{d}\n", .{ self.counter, initial, value, remaining });
            if (@reduce(.Or, value > self.counter)) return false;
            if (@reduce(.And, value == self.counter)) return true;
            if (try self.pressVector(value, remaining - 1)) return true;
        }
        return false;
    }

    fn minVectors(self: *Machine) !u64 {
        const min = @reduce(.Max, self.counter);
        std.debug.print("Starting with min:{d}\n", .{min});

        // for (1..255) |presses| if (self.pressVector(@splat(0), presses)) return presses;
        for (min..min + 10) |presses| {
            self.vector_cache.clearRetainingCapacity();
            if (try self.pressVector(@splat(0), presses)) return presses;
            std.debug.print("* {d} (cache:{d})\n", .{ presses, self.cache.count() });
        }
        return 0;
    }

    fn doStuff(self: *Machine) !u64 {
        const timer_one_start = try std.time.Instant.now();
        const yolo = self.stuff(self.counter, 0);
        const timer_one_end = try std.time.Instant.now();
        std.debug.print("{d}ms\n", .{
            @divFloor(timer_one_end.since(timer_one_start), std.time.ns_per_ms),
        });
        return yolo;
    }

    const zero_vector: @Vector(10, u16) = @splat(0);

    fn stuff(self: *Machine, input: @Vector(10, u16), moves: u64) !u64 {
        if (self.best_move) |m| if (moves >= m) {
            self.skipped += 1;
            return 0;
        };

        // if (self.vector_cache.get(input)) |cached_moves| {
        //     if (cached_moves < moves) {
        //         self.skipped += 1;
        //         // std.debug.print("skipped:{any} skipped:{d}\n", .{ input, self.skipped });
        //         return 0;
        //     }
        // }
        // try self.vector_cache.put(input, moves);

        if (@reduce(.And, input == zero_vector)) {
            self.best_move = if (self.best_move) |m| @min(m, moves) else moves;
            std.debug.print("solution found:{d} skipped:{d}\n", .{ self.best_move.?, self.skipped });
            return 0;
            // return moves;
        }
        // std.debug.print("working on:{any} moves:{d}\n", .{ input, moves });

        const i_max = std.mem.indexOfMax(u16, &@as([10]u16, input));
        const value_max = input[i_max];
        // std.debug.print("input:{any} i_max:{d} value_max:{d} moves:{d}\n", .{ input, i_max, value_max, moves });
        // var times = if (self.best_move) |m| @min(m, value_max) else value_max;
        var times = value_max;
        // if (self.best_move) |m| {
        //     const pwet = @min(m - times, times);
        //     if (pwet != times) {
        //         std.debug.print("times:{d} self+times:{d} m:{d} pwet:{d}\n", .{ times, m + times, m, pwet });
        //     }
        // } else {
        //     // std.debug.print("times:{d} self+times:{d}\n", .{ times, times });
        // }

        while (times > 0) : (times -= 1) {
            if (self.best_move) |m| if (times + moves > m) {
                self.skipped += 1;
                continue;
            };

            for (self.button_vectors.items) |v| {
                if (v[i_max] == 0) continue;
                const factor: @Vector(10, u16) = @splat(times);
                const candidate = v * factor;
                if (@reduce(.Or, candidate > input)) continue;
                const next_candidate = input - candidate;
                // std.debug.print("next_candidate: {any} times:{d}\n", .{ next_candidate, times });
                const result = try self.stuff(next_candidate, moves + times);
                // std.debug.print("-->{d} {any}\n", .{ result, candidate });
                if (result != 0) return result;
            }
        }
        return 0;
    }
};

fn solve(reader: *std.io.Reader, part: Part) !u64 {
    var gpa: std.heap.DebugAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    var arena: std.heap.ArenaAllocator = .init(gpa.allocator());
    const allocator = arena.allocator();
    defer arena.deinit();

    std.debug.print("{any}\n", .{part});

    var result: u64 = 0;
    var machine = try Machine.init(allocator);
    while (try reader.takeDelimiter('\n')) |line| {
        machine.clear();
        try machine.parse(line);
        switch (part) {
            .one => result += machine.minButtons(),
            .two => {
                // const value = try machine.minVectors();
                _ = try machine.doStuff();
                const value = machine.best_move orelse unreachable;
                result += value;
                std.debug.print("--> {d} skipped:{d}\n", .{ value, machine.skipped });
            },
        }
        // break;
    }

    return result;
}

const test_input =
    \\[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}
    \\[...#.] (0,2,3,4) (2,3) (0,4) (0,1,2) (1,2,3,4) {7,5,12,7,2}
    \\[.###.#] (0,1,2,3,4) (0,3,4) (0,1,2,4,5) (1,2) {10,11,11,5,10,5}
;

// test "test part 1" {
//     var reader = std.io.Reader.fixed(test_input);
//     const result = try solve(&reader, .one);
//     try std.testing.expectEqual(7, result);
// }

test "test part 2" {
    var reader = std.io.Reader.fixed(test_input);
    const result = try solve(&reader, .two);
    try std.testing.expectEqual(33, result);
}
