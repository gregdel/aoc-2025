const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{
        .default_target = .{ .abi = .musl },
    });
    const optimize = b.standardOptimizeOption(.{});

    var buf: [64]u8 = undefined;
    const day = b.option(u8, "day", "Day to run") orelse 0;

    const file = try std.fmt.bufPrint(&buf, "src/days/{d:0>2}.zig", .{day});

    const mod = b.addModule("aoc", .{
        .root_source_file = b.path(file),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "aoc",
        .root_module = mod,
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
