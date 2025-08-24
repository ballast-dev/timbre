const std = @import("std");

const targets: []const std.Target.Query = &.{
    .{ .cpu_arch = .aarch64, .os_tag = .macos },
    .{ .cpu_arch = .x86_64, .os_tag = .macos },
    .{ .cpu_arch = .aarch64, .os_tag = .linux },
    .{ .cpu_arch = .x86_64, .os_tag = .linux },
    .{ .cpu_arch = .aarch64, .os_tag = .windows },
    .{ .cpu_arch = .x86_64, .os_tag = .windows },
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "timbre",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    // Add run step for native build
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Cross-compilation targets
    const all_step = b.step("all", "Build all cross-compilation targets");
    var target_steps = std.StringHashMap(*std.Build.Step).init(b.allocator);

    for (targets) |t| {
        const resolved_target = b.resolveTargetQuery(t);
        const triple = t.zigTriple(b.allocator) catch {
            std.debug.print("Error getting triple for target\n", .{});
            continue;
        };

        const target_exe = b.addExecutable(.{
            .name = "timbre",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = resolved_target,
                .optimize = optimize,
            }),
        });

        const target_install = b.addInstallArtifact(target_exe, .{
            .dest_dir = .{
                .override = .{
                    .custom = triple,
                },
            },
        });

        // Add a step for building this specific target
        const target_step = b.step(triple, b.fmt("Build for {s}", .{triple}));
        target_step.dependOn(&target_install.step);

        // Store the step in the hash map
        target_steps.put(triple, target_step) catch {
            std.debug.print("Error storing step for triple '{s}'\n", .{triple});
        };

        // Add this target to the "all" step
        all_step.dependOn(&target_install.step);
    }

    // Add test step
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_tests.step);
}
