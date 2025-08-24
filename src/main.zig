const std = @import("std");
const config = @import("config.zig");
const log = @import("log.zig");
const timbre = @import("timbre.zig");
const cli = @import("cli.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const parsed_args = cli.Args.parse(allocator, args) catch |err| switch (err) {
        error.MissingArgument => {
            std.debug.print("Error: Missing argument for option\n", .{});
            cli.Args.printHelp();
            return;
        },
        else => return err,
    };

    if (parsed_args.help) {
        cli.Args.printHelp();
        return;
    }

    if (parsed_args.version) {
        timbre.printVersion();
        return;
    }

    // Set log level based on verbosity
    log.setLogLevel(parsed_args.verbose);

    // Initialize configuration
    var user_config = config.UserConfig.initWithDefaults(allocator) catch |err| {
        log.log(.err, "Failed to initialize configuration");
        return err;
    };
    defer user_config.deinit();

    // Load configuration file if specified
    if (parsed_args.config_file) |config_file| {
        log.log(.info, "Loading configuration file");
        if (!(user_config.loadFromFile(config_file) catch false)) {
            log.log(.err, "Failed to load configuration file");
            return;
        }
    }

    // Override log directory from command line if specified
    if (parsed_args.log_dir) |log_dir| {
        user_config.setLogDir(log_dir) catch |err| {
            log.log(.err, "Failed to set log directory");
            return err;
        };
        log.log(.info, "Using log directory from command line");
    }

    // Open log files based on configuration
    var log_files = timbre.openLogFiles(&user_config, parsed_args.append) catch |err| {
        log.log(.err, "Failed to open log files");
        return err;
    };
    defer timbre.closeLogFiles(&log_files, allocator);

    if (log_files.count() == 0) {
        log.log(.err, "No log files opened successfully");
        return;
    }

    log.log(.info, "Timbre started. Processing input...");

    // Read from stdin line by line
    var line_buffer: [4096]u8 = undefined;
    var line_count: usize = 0;

    const stdin = std.fs.File.stdin();

    while (true) {
        // Read a line from stdin
        var line_len: usize = 0;
        while (line_len < line_buffer.len - 1) {
            const bytes_read = stdin.read(line_buffer[line_len .. line_len + 1]) catch break;
            if (bytes_read == 0) break; // EOF

            if (line_buffer[line_len] == '\n') {
                break; // End of line
            }
            line_len += 1;
        }

        if (line_len == 0) break; // EOF with no data

        const line = line_buffer[0..line_len];
        timbre.processLine(&user_config, line, &log_files, parsed_args.quiet);
        line_count += 1;
    }

    // Print summary
    const summary = try std.fmt.allocPrint(allocator, "Processing complete. Total lines processed: {d}", .{line_count});
    defer allocator.free(summary);
    log.log(.info, summary);

    // Log counts for each level
    var level_iter = user_config.getLevels().iterator();
    while (level_iter.next()) |entry| {
        const level_name = entry.key_ptr.*;
        const level_config = entry.value_ptr;

        if (level_config.count > 0) {
            const count_msg = try std.fmt.allocPrint(allocator, "{s} lines logged: {d}", .{ level_name, level_config.count });
            defer allocator.free(count_msg);
            log.log(.info, count_msg);
        }
    }
}
