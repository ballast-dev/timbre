const std = @import("std");

pub const LogLevel = enum(u8) {
    err = 0,
    warning = 1,
    info = 2,
    debug = 3,

    pub fn fromVerbosity(verbosity: u8) LogLevel {
        return switch (verbosity) {
            0 => .err,
            1 => .warning,
            2 => .info,
            else => .debug,
        };
    }

    pub fn prefix(self: LogLevel) []const u8 {
        return switch (self) {
            .err => "[ERROR] ",
            .warning => "[WARNING] ",
            .info => "[INFO] ",
            .debug => "[DEBUG] ",
        };
    }
};

pub const Logger = struct {
    level: LogLevel,
    buffer: [1024]u8,

    pub fn init(level: LogLevel) Logger {
        return Logger{
            .level = level,
            .buffer = [_]u8{0} ** 1024,
        };
    }

    pub fn writer(self: *Logger) std.fs.File.Writer {
        return std.fs.File.stderr().writer(&self.buffer);
    }

    pub fn log(self: *const Logger, level: LogLevel, message: []const u8) void {
        if (@intFromEnum(level) > @intFromEnum(self.level)) return;

        std.debug.print("{s}{s}\n", .{ level.prefix(), message });
    }

    pub fn setLevel(self: *Logger, verbosity: u8) void {
        self.level = LogLevel.fromVerbosity(verbosity);
    }
};

// Global logger instance
var global_logger = Logger.init(.err);

pub fn setLogLevel(verbosity: u8) void {
    global_logger.setLevel(verbosity);
}

pub fn log(level: LogLevel, message: []const u8) void {
    global_logger.log(level, message);
}
