const std = @import("std");
const config = @import("config.zig");
const log = @import("log.zig");

const VERSION_MAJOR = 1;
const VERSION_MINOR = 0;
const VERSION_PATCH = 0;

pub fn printVersion() void {
    std.debug.print("timbre version {d}.{d}.{d}\n", .{ VERSION_MAJOR, VERSION_MINOR, VERSION_PATCH });
}

pub const LogFiles = std.StringHashMap(std.fs.File);

pub fn openLogFiles(user_config: *config.UserConfig, append: bool) !LogFiles {
    var log_files = LogFiles.init(user_config.allocator);

    // Create log directory
    user_config.createLogDirectory() catch {
        log.log(.err, "Failed to create log directory");
        return log_files;
    };

    var level_iter = user_config.getLevels().iterator();
    while (level_iter.next()) |entry| {
        const level_name = entry.key_ptr.*;
        const level_config = entry.value_ptr;

        const file_path = try std.fmt.allocPrint(user_config.allocator, "{s}/{s}", .{ user_config.getLogDir(), level_config.path });
        defer user_config.allocator.free(file_path);

        const file = std.fs.cwd().createFile(file_path, .{
            .truncate = !append,
        }) catch {
            log.log(.err, "Failed to open log file");
            continue;
        };

        try log_files.put(try user_config.allocator.dupe(u8, level_name), file);
    }

    return log_files;
}

pub fn closeLogFiles(log_files: *LogFiles, allocator: std.mem.Allocator) void {
    var file_iter = log_files.iterator();
    while (file_iter.next()) |entry| {
        // Free the key (level name) that was duped
        allocator.free(entry.key_ptr.*);
        // Close the file
        entry.value_ptr.close();
    }
    log_files.deinit();
}

pub fn processLine(
    user_config: *config.UserConfig,
    line: []const u8,
    log_files: *LogFiles,
    quiet: bool,
) void {
    // Always write to stdout (tee behavior) unless quiet mode is enabled
    if (!quiet) {
        std.debug.print("{s}\n", .{line});
    }

    if (line.len == 0) return;

    // Check each level for pattern matches
    var level_iter = user_config.getLevels().iterator();
    while (level_iter.next()) |entry| {
        const level_name = entry.key_ptr.*;
        const level_config = entry.value_ptr;

        if (level_config.matches(line)) {
            level_config.count += 1;

            if (log_files.getPtr(level_name)) |file| {
                const line_with_newline = std.fmt.allocPrint(user_config.allocator, "{s}\n", .{line}) catch {
                    log.log(.err, "Failed to format line for writing");
                    return;
                };
                defer user_config.allocator.free(line_with_newline);

                file.writeAll(line_with_newline) catch {
                    log.log(.err, "Failed to write to log file");
                    return;
                };
            }
            return; // Only match the first level
        }
    }
}

// Tests
test "printVersion output format" {
    // We can't easily test the exact output, but we can test that it doesn't crash
    printVersion();
}

test "version constants" {
    try std.testing.expect(VERSION_MAJOR == 1);
    try std.testing.expect(VERSION_MINOR == 0);
    try std.testing.expect(VERSION_PATCH == 0);
}

test "LogFiles initialization and cleanup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var log_files = LogFiles.init(allocator);
    defer log_files.deinit();

    try std.testing.expect(log_files.count() == 0);
}

test "openLogFiles with test config" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var test_config = config.UserConfig.init(allocator);
    defer test_config.deinit();

    // Set a temporary log directory that we know exists
    try test_config.setLogDir("/tmp");

    // Add a test level
    try test_config.addLevel("test", "test", "test_timbre.log");

    var log_files = openLogFiles(&test_config, false) catch {
        // If this fails, it might be due to permission issues or other OS-level problems
        // We'll skip this test in that case
        return;
    };
    defer closeLogFiles(&log_files, allocator);

    // Clean up the test file
    std.fs.cwd().deleteFile("/tmp/test_timbre.log") catch {};
}

test "processLine with empty line" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var test_config = try config.UserConfig.initWithDefaults(allocator);
    defer test_config.deinit();

    var log_files = LogFiles.init(allocator);
    defer log_files.deinit();

    // Should not crash with empty line
    processLine(&test_config, "", &log_files, true);
}

test "processLine pattern matching" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var test_config = config.UserConfig.init(allocator);
    defer test_config.deinit();

    // Add a test level with known pattern
    try test_config.addLevel("test_error", "error", "test_error.log");

    var log_files = LogFiles.init(allocator);
    defer log_files.deinit();

    // Test that processLine can handle pattern matching
    processLine(&test_config, "This is an error message", &log_files, true);

    // Check that the count was incremented
    const level = test_config.getLevel("test_error");
    try std.testing.expect(level != null);
    try std.testing.expect(level.?.count == 1);

    // Test non-matching line
    processLine(&test_config, "This is just info", &log_files, true);
    try std.testing.expect(level.?.count == 1); // Should not increment
}

test "processLine multiple patterns" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var test_config = config.UserConfig.init(allocator);
    defer test_config.deinit();

    // Add multiple test levels
    try test_config.addLevel("error_level", "error", "error.log");
    try test_config.addLevel("warning_level", "warning", "warning.log");
    try test_config.addLevel("info_level", "info", "info.log");

    var log_files = LogFiles.init(allocator);
    defer log_files.deinit();

    // Test that error pattern matches first (and only first)
    processLine(&test_config, "This is an error warning info message", &log_files, true);

    const error_level = test_config.getLevel("error_level");
    const warning_level = test_config.getLevel("warning_level");
    const info_level = test_config.getLevel("info_level");

    try std.testing.expect(error_level != null);
    try std.testing.expect(warning_level != null);
    try std.testing.expect(info_level != null);

    // Only one level should match (whichever is found first in HashMap iteration)
    const total_matches = error_level.?.count + warning_level.?.count + info_level.?.count;
    try std.testing.expect(total_matches == 1);
}

test "processLine pattern priority" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var test_config = config.UserConfig.init(allocator);
    defer test_config.deinit();

    // Add levels in specific order
    try test_config.addLevel("specific", "specific_error", "specific.log");
    try test_config.addLevel("general", "error", "general.log");

    var log_files = LogFiles.init(allocator);
    defer log_files.deinit();

    // Test with message that could match either
    processLine(&test_config, "This is a specific_error message", &log_files, true);

    const specific_level = test_config.getLevel("specific");
    const general_level = test_config.getLevel("general");

    try std.testing.expect(specific_level != null);
    try std.testing.expect(general_level != null);

    // One of them should match (the exact behavior depends on iteration order)
    try std.testing.expect(specific_level.?.count + general_level.?.count == 1);
}

test "closeLogFiles with empty map" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var log_files = LogFiles.init(allocator);

    // Should not crash with empty map
    closeLogFiles(&log_files, allocator);
}

test "LogFiles type definition" {
    // Test that LogFiles is properly defined as a HashMap
    const allocator = std.testing.allocator;
    var log_files = LogFiles.init(allocator);
    defer log_files.deinit();

    try std.testing.expect(log_files.count() == 0);
}
