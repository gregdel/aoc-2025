const std = @import("std");

const Part = @import("lib/aoc.zig").Part;
const Day = @import("lib/aoc.zig").Day;
const Map = @import("lib/map.zig").Map;

pub fn main() !void {
    var day = try Day.init(11, solve);
    defer day.deinit();
    try day.solve();
}

const Node = struct {
    allocator: std.mem.Allocator,
    name: []u8,
    children: std.ArrayList(*Node),
    children_names: std.ArrayList([]u8),

    paths: u64 = 0,
    parents: std.ArrayList(*Node) = undefined,

    fn init(allocator: std.mem.Allocator, line: []const u8) !Node {
        var it = std.mem.splitScalar(u8, line, ' ');
        const name = if (it.next()) |n| n[0 .. n.len - 1] else unreachable;
        var children_names: std.ArrayList([]u8) = try .initCapacity(allocator, 2);
        while (it.next()) |n| try children_names.append(allocator, try allocator.dupe(u8, n));
        return .{
            .allocator = allocator,
            .name = try allocator.dupe(u8, name),
            .children = try .initCapacity(allocator, children_names.items.len),
            .children_names = children_names,
            // .paths = try .initCapacity(allocator, 16),
            .parents = try .initCapacity(allocator, 1),
        };
    }

    fn addChild(self: *Node, child: *Node) !void {
        try self.children.append(self.allocator, child);
    }

    fn initPath(self: *Node) !void {
        self.parents.clearRetainingCapacity();
        // self.paths = 0;
        // self.paths.clearRetainingCapacity();
    }

    fn shouldUpdateChilds(self: *Node) bool {
        for (self.children.items) |child| {
            if (child.paths) |_| return true;
        }

        return false;
    }

    fn updatePath(self: *Node) !void {
        if (self.parents.items.len == 0) {
            self.paths = 1;
            return;
        }

        var total: u64 = 0;
        for (self.parents.items) |parent| total += parent.paths;
        if (self.paths != total) self.paths = total;
    }

    fn upsertParent(self: *Node, new_parent: *Node) !void {
        if (self == new_parent) return;
        for (self.parents.items) |parent| {
            if (parent == new_parent) return;
        }

        try self.parents.append(self.allocator, new_parent);
    }

    fn addParentPaths(self: *Node, new_parent: *Node) !void {
        try self.upsertParent(new_parent);

        // std.debug.print("{s} as {d} now parents\n", .{ self.name, self.parents.items.len });
        if (self == new_parent) {
            self.paths = 1;
        } else {
            try self.updatePath();
        }
    }
};

fn findAllPaths(start: *Node, end: *Node) u64 {
    if (start == end) return 1;
    var result: u64 = 0;
    if (start.children.items.len == 0) {}
    for (start.children.items) |child| {
        result += findAllPaths(child, end);
    }
    return result;
}

const Entry = struct {
    node: *Node,
    parent: *Node,
    distance: u32,

    fn cmp(_: void, a: Entry, b: Entry) std.math.Order {
        return std.math.order(a.distance, b.distance);
    }
};

fn exploreGraph(allocator: std.mem.Allocator, start: *Node, end: *Node) !u64 {
    var explored: std.AutoHashMap(*Node, void) = .init(allocator);
    defer explored.deinit();
    var queue: std.PriorityQueue(Entry, void, Entry.cmp) = .init(allocator, {});
    defer queue.deinit();
    try queue.add(.{ .node = start, .distance = 0, .parent = start });
    start.paths = 1;

    var final_queue: std.ArrayList(*Node) = try .initCapacity(allocator, 604);
    defer final_queue.deinit(allocator);

    // start.paths.append(allocator, try .initCapacity())

    while (queue.removeOrNull()) |element| {
        const node = element.node;
        const distance = element.distance;
        const parent = element.parent;
        // std.debug.print("exploring {s}({d}) from {s}({d}):\n", .{ node.name, node.paths, parent.name, parent.paths });
        if (explored.get(element.node)) |_| {
            // std.debug.print("{s} already explored adding paths from {s}:\n", .{ node.name, parent.name });
            try node.addParentPaths(parent);

            // if (node.shouldUpdateChilds()) {
            //     try final_queue.append(allocator, node);
            // }

            continue;
        }

        try node.initPath();
        try node.addParentPaths(parent);
        try final_queue.append(allocator, node);
        try explored.put(node, {});
        if (node == end) continue;
        for (node.children.items) |child| {
            try queue.add(.{
                .parent = node,
                .node = child,
                .distance = distance + 1,
            });
        }
    }

    // var i: usize = final_queue.items.len;
    // while (i != 0) : (i -= 1) {
    //     const node = final_queue.items[i - 1];
    //     try node.updatePath();
    // }

    for (final_queue.items) |node| {
        try node.updatePath();
    }

    std.debug.print("final queue size {d}\n", .{final_queue.items.len});

    return end.paths;
}

fn solve(reader: *std.io.Reader, part: Part) !u64 {
    var gpa: std.heap.DebugAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    var arena: std.heap.ArenaAllocator = .init(gpa.allocator());
    const allocator = arena.allocator();
    defer arena.deinit();

    var nodes: std.ArrayList(Node) = try .initCapacity(allocator, 604);
    var nodes_names: std.StringHashMap(*Node) = .init(allocator);

    try nodes.append(allocator, try Node.init(allocator, "out:"));
    const end = &nodes.items[0];
    try nodes_names.put("out", end);

    while (try reader.takeDelimiter('\n')) |line| {
        try nodes.append(allocator, try Node.init(allocator, line));
        const node = &nodes.items[nodes.items.len - 1];
        try nodes_names.put(node.name, node);
    }

    for (nodes.items) |*node| for (node.children_names.items) |child_name| {
        const child = nodes_names.get(child_name) orelse unreachable;
        try node.addChild(child);
    };

    if (part == .one) {
        const start = nodes_names.get("you") orelse unreachable;
        return findAllPaths(start, end);
    } else {
        // std.debug.print("digraph G\n", .{});
        // for (nodes.items) |node| for (node.children.items) |child| {
        //     std.debug.print("\t{s} -> {s};\n", .{ node.name, child.name });
        // };
        // std.debug.print("------------\n", .{});

        const start = nodes_names.get("svr") orelse unreachable;
        const fft = nodes_names.get("fft") orelse unreachable;
        const dac = nodes_names.get("dac") orelse unreachable;

        const start_fft = try exploreGraph(allocator, start, fft);
        const fft_dac = try exploreGraph(allocator, fft, dac);
        const dac_end = try exploreGraph(allocator, dac, end);
        const start_end = try exploreGraph(allocator, start, end);

        std.debug.print(
            \\start_end: {d}
            \\start_fft: {d}
            \\fft_dac  : {d}
            \\dac_end  : {d}
            \\
        , .{
            start_end,
            start_fft,
            fft_dac,
            dac_end,
        });

        // 101995230261100 no right
        // 13983399208600 too low
        return start_fft * fft_dac * dac_end;
    }
}

// test "test part 1" {
//     const test_input =
//         \\aaa: you hhh
//         \\you: bbb ccc
//         \\bbb: ddd eee
//         \\ccc: ddd eee fff
//         \\ddd: ggg
//         \\eee: out
//         \\fff: out
//         \\ggg: out
//         \\hhh: ccc fff iii
//         \\iii: out
//     ;
//     var reader = std.io.Reader.fixed(test_input);
//     const result = try solve(&reader, .one);
//     try std.testing.expectEqual(5, result);
// }

test "test part 2" {
    const test_input =
        \\svr: aaa bbb
        \\aaa: fft
        \\fft: ccc
        \\bbb: tty
        \\tty: ccc
        \\ccc: ddd eee
        \\ddd: hub
        \\hub: fff
        \\eee: dac
        \\dac: fff
        \\fff: ggg hhh
        \\ggg: out
        \\hhh: out
    ;

    var reader = std.io.Reader.fixed(test_input);
    const result = try solve(&reader, .two);
    try std.testing.expectEqual(2, result);
}
