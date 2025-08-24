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
