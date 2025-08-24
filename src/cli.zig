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
            } else if (std.mem.startsWith(u8, arg, "-v")) {
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
