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

// Tests
test "LogLevel fromVerbosity" {
    try std.testing.expect(LogLevel.fromVerbosity(0) == .err);
    try std.testing.expect(LogLevel.fromVerbosity(1) == .warning);
    try std.testing.expect(LogLevel.fromVerbosity(2) == .info);
    try std.testing.expect(LogLevel.fromVerbosity(3) == .debug);
    try std.testing.expect(LogLevel.fromVerbosity(10) == .debug); // Should cap at debug
}

test "LogLevel prefix" {
    try std.testing.expectEqualStrings("[ERROR] ", LogLevel.err.prefix());
    try std.testing.expectEqualStrings("[WARNING] ", LogLevel.warning.prefix());
    try std.testing.expectEqualStrings("[INFO] ", LogLevel.info.prefix());
    try std.testing.expectEqualStrings("[DEBUG] ", LogLevel.debug.prefix());
}

test "Logger initialization" {
    const logger = Logger.init(.info);
    try std.testing.expect(logger.level == .info);
}

test "Logger setLevel" {
    var logger = Logger.init(.err);
    try std.testing.expect(logger.level == .err);

    logger.setLevel(2); // Should set to info
    try std.testing.expect(logger.level == .info);

    logger.setLevel(0); // Should set to err
    try std.testing.expect(logger.level == .err);
}

test "Logger level filtering" {
    const logger = Logger.init(.warning);

    // Test that the logger respects its level setting
    // We can't easily test the actual output, but we can test the level comparison logic
    try std.testing.expect(@intFromEnum(LogLevel.err) <= @intFromEnum(logger.level)); // Should log
    try std.testing.expect(@intFromEnum(LogLevel.warning) <= @intFromEnum(logger.level)); // Should log
    try std.testing.expect(@intFromEnum(LogLevel.info) > @intFromEnum(logger.level)); // Should not log
    try std.testing.expect(@intFromEnum(LogLevel.debug) > @intFromEnum(logger.level)); // Should not log
}

test "Global logger operations" {
    // Test that we can set the global log level
    setLogLevel(2); // Info level
    try std.testing.expect(global_logger.level == .info);

    setLogLevel(0); // Error level
    try std.testing.expect(global_logger.level == .err);

    setLogLevel(3); // Debug level
    try std.testing.expect(global_logger.level == .debug);
}

test "LogLevel enum values" {
    // Test that enum values are in the expected order for comparison
    try std.testing.expect(@intFromEnum(LogLevel.err) < @intFromEnum(LogLevel.warning));
    try std.testing.expect(@intFromEnum(LogLevel.warning) < @intFromEnum(LogLevel.info));
    try std.testing.expect(@intFromEnum(LogLevel.info) < @intFromEnum(LogLevel.debug));
}
