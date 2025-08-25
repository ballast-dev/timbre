//! Timbre - structured, quality logging
//! By convention, root.zig is the root source file when making a library.

const std = @import("std");

// Re-export public modules for library usage
pub const cli = @import("cli.zig");
pub const config = @import("config.zig");
pub const log = @import("log.zig");
pub const timbre = @import("timbre.zig");
pub const regex = @import("regex");

// Library API
pub const Args = cli.Args;
pub const UserConfig = config.UserConfig;
pub const UserLevel = config.UserLevel;
pub const UserConfigRegex = config.UserConfigRegex;
pub const UserLevelRegex = config.UserLevelRegex;
pub const MatchMode = config.MatchMode;
pub const LogLevel = log.LogLevel;
pub const Logger = log.Logger;
pub const LogFiles = timbre.LogFiles;
pub const Regex = regex.Regex;
pub const RegexError = regex.RegexError;

// Version information
pub const version = .{
    .major = 1,
    .minor = 0,
    .patch = 0,
};

pub fn getVersionString(allocator: std.mem.Allocator) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d}.{d}.{d}", .{ version.major, version.minor, version.patch });
}

// Library tests
test "module imports" {
    // Test that all modules can be imported without errors
    _ = cli;
    _ = config;
    _ = log;
    _ = timbre;
}

test "public API availability" {
    // Test that all public types are accessible
    _ = Args;
    _ = UserConfig;
    _ = UserLevel;
    _ = LogLevel;
    _ = Logger;
    _ = LogFiles;
}

test "version information" {
    try std.testing.expect(version.major == 1);
    try std.testing.expect(version.minor == 0);
    try std.testing.expect(version.patch == 0);
}

test "version string formatting" {
    const allocator = std.testing.allocator;
    const version_str = try getVersionString(allocator);
    defer allocator.free(version_str);

    try std.testing.expectEqualStrings("1.0.0", version_str);
}

test "integration - basic workflow" {
    const allocator = std.testing.allocator;

    // Test basic CLI parsing
    var args = [_][:0]u8{ @constCast("timbre"), @constCast("-v"), @constCast("--quiet") };
    const parsed_args = try Args.parse(allocator, &args);
    try std.testing.expect(parsed_args.verbose == 1);
    try std.testing.expect(parsed_args.quiet == true);

    // Test config initialization
    var user_config = try UserConfig.initWithDefaults(allocator);
    defer user_config.deinit();

    try std.testing.expect(user_config.levels.count() == 4);

    // Test log level setting
    log.setLogLevel(parsed_args.verbose);

    // Test pattern matching
    const error_level = user_config.getLevel("error");
    try std.testing.expect(error_level != null);
    try std.testing.expect(error_level.?.matches("This is an error"));
}

test "integration - config and processing" {
    const allocator = std.testing.allocator;

    // Create a test configuration
    var test_config = UserConfig.init(allocator);
    defer test_config.deinit();

    try test_config.addLevel("test_level", "test|sample", "test.log");

    // Test the processing workflow
    var log_files = LogFiles.init(allocator);
    defer log_files.deinit();

    // Process test lines
    timbre.processLine(&test_config, "This is a test message", &log_files, true);
    timbre.processLine(&test_config, "This is a sample line", &log_files, true);
    timbre.processLine(&test_config, "This is unrelated", &log_files, true);

    const test_level = test_config.getLevel("test_level");
    try std.testing.expect(test_level != null);
    try std.testing.expect(test_level.?.count == 2); // Should match "test" and "sample"
}

test "integration - regex functionality" {
    const allocator = std.testing.allocator;

    // Test that regex module works
    try std.testing.expect(try regex.isMatch(allocator, "error|fail", "An error occurred"));
    try std.testing.expect(try regex.isMatch(allocator, "\\d+", "123"));
    try std.testing.expect(!try regex.isMatch(allocator, "^start", "middle start"));

    // Test regex compilation
    var compiled_regex = try Regex.compile(allocator, "(warn|warning)");
    defer compiled_regex.deinit();

    try std.testing.expect(compiled_regex.isMatch("warning message"));
    try std.testing.expect(compiled_regex.isMatch("warn level"));
    try std.testing.expect(!compiled_regex.isMatch("error level"));
}

// Import all module tests to run them when testing the library
comptime {
    _ = @import("cli.zig");
    _ = @import("config.zig");
    _ = @import("log.zig");
    _ = @import("timbre.zig");
    _ = @import("regex");
}
