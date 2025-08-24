const std = @import("std");

pub const Args = struct {
    quiet: bool = false,
    append: bool = false,
    verbose: u8 = 0,
    version: bool = false,
    log_dir: ?[]const u8 = null,
    config_file: ?[]const u8 = null,
    help: bool = false,

    pub fn parse(allocator: std.mem.Allocator, args: [][:0]u8) !Args {
        var result = Args{};

        var i: usize = 1; // Skip program name
        while (i < args.len) {
            const arg = args[i];

            if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                result.help = true;
            } else if (std.mem.eql(u8, arg, "-q") or std.mem.eql(u8, arg, "--quiet")) {
                result.quiet = true;
            } else if (std.mem.eql(u8, arg, "-a") or std.mem.eql(u8, arg, "--append")) {
                result.append = true;
            } else if (std.mem.eql(u8, arg, "-V") or std.mem.eql(u8, arg, "--version")) {
                result.version = true;
            } else if (std.mem.startsWith(u8, arg, "-v") and !std.mem.eql(u8, arg, "-V")) {
                // Count verbosity levels (-v, -vv, -vvv, etc.)
                result.verbose = @intCast(arg.len - 1);
            } else if (std.mem.eql(u8, arg, "--verbose")) {
                result.verbose = 1;
            } else if (std.mem.eql(u8, arg, "-d") or std.mem.eql(u8, arg, "--log-dir")) {
                i += 1;
                if (i >= args.len) {
                    return error.MissingArgument;
                }
                result.log_dir = try allocator.dupe(u8, args[i]);
            } else if (std.mem.eql(u8, arg, "-c") or std.mem.eql(u8, arg, "--config")) {
                i += 1;
                if (i >= args.len) {
                    return error.MissingArgument;
                }
                result.config_file = try allocator.dupe(u8, args[i]);
            } else if (std.mem.startsWith(u8, arg, "--log-dir=")) {
                result.log_dir = try allocator.dupe(u8, arg[10..]);
            } else if (std.mem.startsWith(u8, arg, "--config=")) {
                result.config_file = try allocator.dupe(u8, arg[9..]);
            } else if (arg.len > 1 and arg[0] == '-' and arg[1] != '-') {
                // Handle combined short flags like -qa
                for (arg[1..]) |flag_char| {
                    switch (flag_char) {
                        'h' => result.help = true,
                        'q' => result.quiet = true,
                        'a' => result.append = true,
                        'V' => result.version = true,
                        'v' => result.verbose += 1,
                        'd', 'c' => {
                            // These flags require arguments, so we can't handle them in combined form
                            // They must be specified separately
                        },
                        else => {
                            // Unknown flag - ignore for now
                        },
                    }
                }
            } else {
                // Unknown argument - ignore for now
            }

            i += 1;
        }

        return result;
    }

    pub fn printHelp() void {
        std.debug.print(
            \\::timbre:: structured, quality logging
            \\
            \\USAGE:
            \\    timbre [OPTIONS]
            \\
            \\OPTIONS:
            \\    -q, --quiet              Suppress terminal output
            \\    -a, --append             Append to log files instead of overwriting
            \\    -v, --verbose            Enable verbose logging (can be used multiple times)
            \\    -V, --version            Print version
            \\    -d, --log-dir <DIR>      Directory for log files
            \\    -c, --config <FILE>      Path to TOML configuration file
            \\    -h, --help               Print this help message
            \\
        , .{});
    }
};

// Tests
test "cli args parsing - help flags" {
    const allocator = std.testing.allocator;

    // Test short help flag
    var args1 = [_][:0]u8{ @constCast("timbre"), @constCast("-h") };
    const parsed1 = try Args.parse(allocator, &args1);
    try std.testing.expect(parsed1.help == true);

    // Test long help flag
    var args2 = [_][:0]u8{ @constCast("timbre"), @constCast("--help") };
    const parsed2 = try Args.parse(allocator, &args2);
    try std.testing.expect(parsed2.help == true);
}

test "cli args parsing - quiet flags" {
    const allocator = std.testing.allocator;

    // Test short quiet flag
    var args1 = [_][:0]u8{ @constCast("timbre"), @constCast("-q") };
    const parsed1 = try Args.parse(allocator, &args1);
    try std.testing.expect(parsed1.quiet == true);

    // Test long quiet flag
    var args2 = [_][:0]u8{ @constCast("timbre"), @constCast("--quiet") };
    const parsed2 = try Args.parse(allocator, &args2);
    try std.testing.expect(parsed2.quiet == true);
}

test "cli args parsing - append flags" {
    const allocator = std.testing.allocator;

    // Test short append flag
    var args1 = [_][:0]u8{ @constCast("timbre"), @constCast("-a") };
    const parsed1 = try Args.parse(allocator, &args1);
    try std.testing.expect(parsed1.append == true);

    // Test long append flag
    var args2 = [_][:0]u8{ @constCast("timbre"), @constCast("--append") };
    const parsed2 = try Args.parse(allocator, &args2);
    try std.testing.expect(parsed2.append == true);
}

test "cli args parsing - version flags" {
    const allocator = std.testing.allocator;

    // Test short version flag
    var args1 = [_][:0]u8{ @constCast("timbre"), @constCast("-V") };
    const parsed1 = try Args.parse(allocator, &args1);
    try std.testing.expect(parsed1.version == true);

    // Test long version flag
    var args2 = [_][:0]u8{ @constCast("timbre"), @constCast("--version") };
    const parsed2 = try Args.parse(allocator, &args2);
    try std.testing.expect(parsed2.version == true);
}

test "cli args parsing - verbosity levels" {
    const allocator = std.testing.allocator;

    // Test single -v
    var args1 = [_][:0]u8{ @constCast("timbre"), @constCast("-v") };
    const parsed1 = try Args.parse(allocator, &args1);
    try std.testing.expect(parsed1.verbose == 1);

    // Test multiple -v flags
    var args2 = [_][:0]u8{ @constCast("timbre"), @constCast("-vv") };
    const parsed2 = try Args.parse(allocator, &args2);
    try std.testing.expect(parsed2.verbose == 2);

    var args3 = [_][:0]u8{ @constCast("timbre"), @constCast("-vvv") };
    const parsed3 = try Args.parse(allocator, &args3);
    try std.testing.expect(parsed3.verbose == 3);

    // Test long verbose flag
    var args4 = [_][:0]u8{ @constCast("timbre"), @constCast("--verbose") };
    const parsed4 = try Args.parse(allocator, &args4);
    try std.testing.expect(parsed4.verbose == 1);
}

test "cli args parsing - log directory" {
    const allocator = std.testing.allocator;

    // Test short flag with separate argument
    var args1 = [_][:0]u8{ @constCast("timbre"), @constCast("-d"), @constCast("/tmp/logs") };
    const parsed1 = try Args.parse(allocator, &args1);
    try std.testing.expect(parsed1.log_dir != null);
    try std.testing.expectEqualStrings("/tmp/logs", parsed1.log_dir.?);
    if (parsed1.log_dir) |dir| allocator.free(dir);

    // Test long flag with separate argument
    var args2 = [_][:0]u8{ @constCast("timbre"), @constCast("--log-dir"), @constCast("/var/log") };
    const parsed2 = try Args.parse(allocator, &args2);
    try std.testing.expect(parsed2.log_dir != null);
    try std.testing.expectEqualStrings("/var/log", parsed2.log_dir.?);
    if (parsed2.log_dir) |dir| allocator.free(dir);

    // Test long flag with equals syntax
    var args3 = [_][:0]u8{ @constCast("timbre"), @constCast("--log-dir=/home/user/logs") };
    const parsed3 = try Args.parse(allocator, &args3);
    try std.testing.expect(parsed3.log_dir != null);
    try std.testing.expectEqualStrings("/home/user/logs", parsed3.log_dir.?);
    if (parsed3.log_dir) |dir| allocator.free(dir);
}

test "cli args parsing - config file" {
    const allocator = std.testing.allocator;

    // Test short flag with separate argument
    var args1 = [_][:0]u8{ @constCast("timbre"), @constCast("-c"), @constCast("config.toml") };
    const parsed1 = try Args.parse(allocator, &args1);
    try std.testing.expect(parsed1.config_file != null);
    try std.testing.expectEqualStrings("config.toml", parsed1.config_file.?);
    if (parsed1.config_file) |file| allocator.free(file);

    // Test long flag with separate argument
    var args2 = [_][:0]u8{ @constCast("timbre"), @constCast("--config"), @constCast("/etc/timbre.toml") };
    const parsed2 = try Args.parse(allocator, &args2);
    try std.testing.expect(parsed2.config_file != null);
    try std.testing.expectEqualStrings("/etc/timbre.toml", parsed2.config_file.?);
    if (parsed2.config_file) |file| allocator.free(file);

    // Test long flag with equals syntax
    var args3 = [_][:0]u8{ @constCast("timbre"), @constCast("--config=./my_config.toml") };
    const parsed3 = try Args.parse(allocator, &args3);
    try std.testing.expect(parsed3.config_file != null);
    try std.testing.expectEqualStrings("./my_config.toml", parsed3.config_file.?);
    if (parsed3.config_file) |file| allocator.free(file);
}

test "cli args parsing - missing arguments" {
    const allocator = std.testing.allocator;

    // Test missing log dir argument
    var args1 = [_][:0]u8{ @constCast("timbre"), @constCast("-d") };
    const result1 = Args.parse(allocator, &args1);
    try std.testing.expectError(error.MissingArgument, result1);

    // Test missing config file argument
    var args2 = [_][:0]u8{ @constCast("timbre"), @constCast("--config") };
    const result2 = Args.parse(allocator, &args2);
    try std.testing.expectError(error.MissingArgument, result2);
}

test "cli args parsing - combined flags" {
    const allocator = std.testing.allocator;

    var args = [_][:0]u8{ @constCast("timbre"), @constCast("-qa"), @constCast("-vv"), @constCast("--log-dir=/tmp"), @constCast("--config=test.toml") };
    const parsed = try Args.parse(allocator, &args);

    try std.testing.expect(parsed.quiet == true);
    try std.testing.expect(parsed.append == true);
    try std.testing.expect(parsed.verbose == 2);
    try std.testing.expect(parsed.log_dir != null);
    try std.testing.expectEqualStrings("/tmp", parsed.log_dir.?);
    try std.testing.expect(parsed.config_file != null);
    try std.testing.expectEqualStrings("test.toml", parsed.config_file.?);

    if (parsed.log_dir) |dir| allocator.free(dir);
    if (parsed.config_file) |file| allocator.free(file);
}

test "cli args parsing - defaults" {
    const allocator = std.testing.allocator;

    var args = [_][:0]u8{@constCast("timbre")};
    const parsed = try Args.parse(allocator, &args);

    try std.testing.expect(parsed.quiet == false);
    try std.testing.expect(parsed.append == false);
    try std.testing.expect(parsed.verbose == 0);
    try std.testing.expect(parsed.version == false);
    try std.testing.expect(parsed.help == false);
    try std.testing.expect(parsed.log_dir == null);
    try std.testing.expect(parsed.config_file == null);
}
