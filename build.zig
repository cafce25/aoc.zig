const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const run_step = b.step("run", "Run the app");

    const test_step = b.step("test", "Run unit tests");

    const util = b.addModule("aoc_util", .{
        .root_source_file = b.path("util.zig"),
        .target = target,
        .optimize = optimize,
    });

    const util_unit_tests = b.addTest(.{
        .root_source_file = b.path("util.zig"),
        .target = target,
        .optimize = optimize,
    });

    test_step.dependOn(&util_unit_tests.step);

    for (2015..2024 + 1) |year| {
        for (1..25 + 1) |day| {
            // TODO is this really the best way for an inclusive range‽
            for (1..2 + 1) |part| {
                const source = try std.fmt.allocPrint(allocator, "{}/{}/part{}.zig", .{ year, day, part });
                defer allocator.free(source);
                {
                    const absolute_source = std.fs.realpathAlloc(allocator, source) catch {
                        continue;
                    };
                    defer allocator.free(absolute_source);

                    std.fs.accessAbsolute(absolute_source, std.fs.File.OpenFlags{}) catch {
                        continue;
                    };
                }
                const exe_name = try std.fmt.allocPrint(allocator, "aoc.zig-{}-{}p{}", .{ year, day, part });
                defer allocator.free(exe_name);
                const exe = b.addExecutable(.{
                    .name = exe_name,
                    .root_source_file = b.path(source),
                    .target = target,
                    .optimize = optimize,
                });

                exe.root_module.addImport("util", util);

                b.installArtifact(exe);
                const run_cmd = b.addRunArtifact(exe);
                run_cmd.step.dependOn(b.getInstallStep());
                if (b.args) |args| {
                    run_cmd.addArgs(args);
                }

                run_step.dependOn(&run_cmd.step);
                const single_step = b.step(exe_name, "Run the corresponding part");
                single_step.dependOn(&run_cmd.step);

                const exe_unit_tests = b.addTest(.{
                    .root_source_file = b.path(source),
                    .target = target,
                    .optimize = optimize,
                });

                const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

                test_step.dependOn(&run_exe_unit_tests.step);
            }
        }
    }
}
