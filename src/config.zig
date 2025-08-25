const std = @import("std");
const log = @import("log.zig");
const regex = @import("regex");

pub const UserLevel = struct {
    regex_pattern: regex.Regex,
    path: []const u8,
    count: usize = 0,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, pattern_str: []const u8, path: []const u8) !Self {
        // Compile the regex pattern with case-insensitive flag (like C++ icase)
        const compiled_regex = regex.Regex.compileWithFlags(allocator, pattern_str, regex.RegexFlags{ .case_insensitive = true, .optimize = true }) catch |err| {
            log.log(.err, "Failed to compile regex pattern");
            return err;
        };

        return Self{
            .regex_pattern = compiled_regex,
            .path = try allocator.dupe(u8, path),
            .count = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.regex_pattern.deinit();
        self.allocator.free(self.path);
    }

    pub fn matches(self: *Self, line: []const u8) bool {
        return self.regex_pattern.isMatch(line);
    }
};

pub const UserConfig = struct {
    log_dir: []const u8,
    levels: std.StringHashMap(UserLevel),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .log_dir = ".timbre",
            .levels = std.StringHashMap(UserLevel).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var iterator = self.levels.iterator();
        while (iterator.next()) |entry| {
            // Free the key (level name) that was duped
            self.allocator.free(entry.key_ptr.*);
            // Free the value (UserLevel)
            entry.value_ptr.deinit();
        }
        self.levels.deinit();
        if (!std.mem.eql(u8, self.log_dir, ".timbre")) {
            self.allocator.free(self.log_dir);
        }
    }

    pub fn initWithDefaults(allocator: std.mem.Allocator) !Self {
        var config = Self.init(allocator);

        // Add default log levels with regex patterns (case-insensitive matching enabled)
        try config.addLevel("error", "(error|exception|fail(ed|ure)?|critical)", "error.log");
        try config.addLevel("warn", "(warn(ing)?)", "warn.log");
        try config.addLevel("info", "(info)", "info.log");
        try config.addLevel("debug", "(debug)", "debug.log");

        return config;
    }

    pub fn addLevel(self: *Self, name: []const u8, pattern_str: []const u8, path: []const u8) !void {
        const level = UserLevel.init(self.allocator, pattern_str, path) catch |err| {
            log.log(.err, "Failed to create regex pattern for level");
            return err;
        };

        try self.levels.put(try self.allocator.dupe(u8, name), level);
    }

    pub fn setLogDir(self: *Self, dir: []const u8) !void {
        if (!std.mem.eql(u8, self.log_dir, ".timbre")) {
            self.allocator.free(self.log_dir);
        }
        self.log_dir = try self.allocator.dupe(u8, dir);
    }

    pub fn getLogDir(self: *const Self) []const u8 {
        return self.log_dir;
    }

    pub fn getLevel(self: *Self, name: []const u8) ?*UserLevel {
        return self.levels.getPtr(name);
    }

    pub fn getLevels(self: *Self) *std.StringHashMap(UserLevel) {
        return &self.levels;
    }

    pub fn createLogDirectory(self: *const Self) !void {
        std.fs.cwd().makeDir(self.log_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {}, // Directory already exists, that's fine
            else => {
                log.log(.err, "Failed to create log directory");
                return err;
            },
        };
    }

    pub fn loadFromFile(self: *Self, path: []const u8) !bool {
        // Simplified TOML loading - just return true for now
        // In a real implementation, you'd parse TOML and configure levels
        _ = self;
        _ = path;
        return true;
    }
};

// Tests
test "UserLevel regex functionality" {
    const allocator = std.testing.allocator;

    var level = try UserLevel.init(allocator, "(error|fail)", "error.log");
    defer level.deinit();

    try std.testing.expectEqualStrings("error.log", level.path);
    try std.testing.expect(level.count == 0);

    // Test regex matching
    try std.testing.expect(level.matches("This is an error"));
    try std.testing.expect(level.matches("Operation failed"));
    try std.testing.expect(!level.matches("This is info"));
}

test "UserConfig with regex defaults" {
    const allocator = std.testing.allocator;

    var config = try UserConfig.initWithDefaults(allocator);
    defer config.deinit();

    try std.testing.expectEqualStrings(".timbre", config.getLogDir());
    try std.testing.expect(config.levels.count() == 4);

    // Check that default levels exist
    try std.testing.expect(config.getLevel("error") != null);
    try std.testing.expect(config.getLevel("warn") != null);
    try std.testing.expect(config.getLevel("info") != null);
    try std.testing.expect(config.getLevel("debug") != null);
}

test "UserConfig regex pattern matching" {
    const allocator = std.testing.allocator;

    var config = UserConfig.init(allocator);
    defer config.deinit();

    // Add a regex pattern with anchors
    try config.addLevel("strict_error", "^ERROR:", "error.log");

    const level = config.getLevel("strict_error");
    try std.testing.expect(level != null);

    // Should match lines starting with ERROR:
    try std.testing.expect(level.?.matches("ERROR: Something went wrong"));

    // Should not match ERROR in the middle
    try std.testing.expect(!level.?.matches("System ERROR: problem"));
}

test "UserLevel complex regex patterns" {
    const allocator = std.testing.allocator;

    // Test a regex pattern with character classes
    var level = try UserLevel.init(allocator, "\\[(ERROR|WARN)\\]", "structured.log");
    defer level.deinit();

    // Should match structured log format
    try std.testing.expect(level.matches("[ERROR] Failed to connect"));
    try std.testing.expect(level.matches("[WARN] Low memory"));

    // Should not match without proper structure
    try std.testing.expect(!level.matches("ERROR Failed to connect"));
    try std.testing.expect(!level.matches("[INFO] Message"));
}
