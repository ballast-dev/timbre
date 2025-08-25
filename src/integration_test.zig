const std = @import("std");
const config = @import("config.zig");
const timbre = @import("timbre.zig");
const cli = @import("cli.zig");

test "integration - full CLI workflow" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test CLI argument parsing
    var args = [_][:0]u8{ @constCast("timbre"), @constCast("-q"), @constCast("-d"), @constCast("/tmp") };
    const parsed_args = try cli.Args.parse(allocator, &args);
    defer if (parsed_args.log_dir) |log_dir| allocator.free(log_dir);
    defer if (parsed_args.config_file) |config_file| allocator.free(config_file);

    try std.testing.expect(parsed_args.quiet == true);
    try std.testing.expect(parsed_args.log_dir != null);
    try std.testing.expectEqualStrings("/tmp", parsed_args.log_dir.?);
}

test "integration - regex config workflow" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create config with default regex patterns
    var user_config = try config.UserConfig.initWithDefaults(allocator);
    defer user_config.deinit();

    // Test that the regex patterns work
    const error_level = user_config.getLevel("error");
    try std.testing.expect(error_level != null);

    // Test various error patterns
    try std.testing.expect(error_level.?.matches("This is an error"));
    try std.testing.expect(error_level.?.matches("Operation failed"));
    try std.testing.expect(error_level.?.matches("CRITICAL system failure"));
    try std.testing.expect(error_level.?.matches("exception in thread"));
    try std.testing.expect(!error_level.?.matches("This is just info"));

    // Test warn patterns
    const warn_level = user_config.getLevel("warn");
    try std.testing.expect(warn_level != null);
    try std.testing.expect(warn_level.?.matches("warning: low memory"));
    try std.testing.expect(warn_level.?.matches("WARN about config"));
    try std.testing.expect(!warn_level.?.matches("This is an error"));
}

test "integration - custom regex patterns" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var user_config = config.UserConfig.init(allocator);
    defer user_config.deinit();

    // Add custom patterns with anchors and character classes
    try user_config.addLevel("http_errors", "HTTP [45]\\d\\d", "http_errors.log");
    try user_config.addLevel("timestamps", "\\d{4}-\\d{2}-\\d{2}", "timestamped.log");
    try user_config.addLevel("structured", "\\[[A-Z]+\\]", "structured.log");

    const http_level = user_config.getLevel("http_errors");
    const timestamp_level = user_config.getLevel("timestamps");
    const structured_level = user_config.getLevel("structured");

    try std.testing.expect(http_level != null);
    try std.testing.expect(timestamp_level != null);
    try std.testing.expect(structured_level != null);

    // Test HTTP error patterns
    try std.testing.expect(http_level.?.matches("HTTP 404 Not Found"));
    try std.testing.expect(http_level.?.matches("HTTP 500 Internal Error"));
    try std.testing.expect(!http_level.?.matches("HTTP 200 OK"));

    // Test timestamp patterns
    try std.testing.expect(timestamp_level.?.matches("Log entry 2023-12-25 occurred"));
    try std.testing.expect(!timestamp_level.?.matches("Log entry today occurred"));

    // Test structured log patterns
    try std.testing.expect(structured_level.?.matches("[ERROR] Database failed"));
    try std.testing.expect(structured_level.?.matches("[INFO] System started"));
    try std.testing.expect(!structured_level.?.matches("ERROR: Database failed"));
}

test "integration - log processing simulation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var user_config = try config.UserConfig.initWithDefaults(allocator);
    defer user_config.deinit();

    var log_files = timbre.LogFiles.init(allocator);
    defer log_files.deinit();

    // Simulate processing various log lines
    const test_lines = [_][]const u8{
        "2023-12-25 10:00:00 INFO: System started successfully",
        "2023-12-25 10:01:00 ERROR: Database connection failed",
        "2023-12-25 10:01:30 WARN: High memory usage detected",
        "2023-12-25 10:02:00 DEBUG: Processing user request",
        "2023-12-25 10:02:15 CRITICAL: Disk space low",
        "2023-12-25 10:03:00 INFO: User logged in successfully",
        "2023-12-25 10:03:30 Exception in thread main",
    };

    for (test_lines) |line| {
        timbre.processLine(&user_config, line, &log_files, true); // quiet mode
    }

    // Verify counts
    const error_level = user_config.getLevel("error");
    const warn_level = user_config.getLevel("warn");
    const info_level = user_config.getLevel("info");
    const debug_level = user_config.getLevel("debug");

    try std.testing.expect(error_level != null);
    try std.testing.expect(warn_level != null);
    try std.testing.expect(info_level != null);
    try std.testing.expect(debug_level != null);

    // Check that appropriate lines were matched
    try std.testing.expect(error_level.?.count >= 1); // ERROR and CRITICAL
    try std.testing.expect(warn_level.?.count >= 1); // WARN
    try std.testing.expect(info_level.?.count >= 1); // INFO lines
    try std.testing.expect(debug_level.?.count >= 1); // DEBUG
}

test "integration - help and version" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test help flag
    var help_args = [_][:0]u8{ @constCast("timbre"), @constCast("--help") };
    const help_parsed = try cli.Args.parse(allocator, &help_args);
    try std.testing.expect(help_parsed.help == true);

    // Test version flag
    var version_args = [_][:0]u8{ @constCast("timbre"), @constCast("--version") };
    const version_parsed = try cli.Args.parse(allocator, &version_args);
    try std.testing.expect(version_parsed.version == true);
}
