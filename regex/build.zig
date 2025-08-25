const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the regex library
    const regex_lib = b.addLibrary(.{
        .name = "timbre-regex",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Install the library
    b.installArtifact(regex_lib);

    // Add test step
    const regex_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_regex_tests = b.addRunArtifact(regex_tests);
    const test_step = b.step("test", "Run regex tests");
    test_step.dependOn(&run_regex_tests.step);

    // Add example step
    const example = b.addExecutable(.{
        .name = "regex-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("example.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const example_install = b.addInstallArtifact(example, .{});
    const example_step = b.step("example", "Build and install regex example");
    example_step.dependOn(&example_install.step);

    // Add run example step
    const run_example = b.addRunArtifact(example);
    const run_example_step = b.step("run-example", "Run regex example");
    run_example_step.dependOn(&run_example.step);
}
