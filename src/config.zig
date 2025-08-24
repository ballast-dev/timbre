const std = @import("std");
const log = @import("log.zig");

pub const UserLevel = struct {
    patterns: [][]const u8, // Array of patterns to match (simple string matching)
    path: []const u8,
    count: usize = 0,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, pattern_str: []const u8, path: []const u8) !Self {
        // Parse pattern string - split on | for OR patterns
        var pattern_list = std.ArrayList([]const u8){};
        defer pattern_list.deinit(allocator);

        // Simple pattern parsing - split on | and handle some basic regex-like patterns
        var pattern_iter = std.mem.splitScalar(u8, pattern_str, '|');
        while (pattern_iter.next()) |pattern| {
            var clean_pattern = std.mem.trim(u8, pattern, " \t()");

            // Handle some common regex patterns by converting to simple strings
            if (std.mem.endsWith(u8, clean_pattern, "?")) {
                // Optional character - add both with and without
                const base = clean_pattern[0 .. clean_pattern.len - 1];
                try pattern_list.append(allocator, try allocator.dupe(u8, base));
                if (base.len > 0) {
                    const without_last = base[0 .. base.len - 1];
                    try pattern_list.append(allocator, try allocator.dupe(u8, without_last));
                }
            } else {
                try pattern_list.append(allocator, try allocator.dupe(u8, clean_pattern));
            }
        }

        const patterns = try pattern_list.toOwnedSlice(allocator);

        return Self{
            .patterns = patterns,
            .path = try allocator.dupe(u8, path),
            .count = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.patterns) |pattern| {
            self.allocator.free(pattern);
        }
        self.allocator.free(self.patterns);
        self.allocator.free(self.path);
    }

    pub fn matches(self: *const Self, line: []const u8) bool {
        const lower_line = std.ascii.allocLowerString(self.allocator, line) catch return false;
        defer self.allocator.free(lower_line);

        for (self.patterns) |pattern| {
            const lower_pattern = std.ascii.allocLowerString(self.allocator, pattern) catch continue;
            defer self.allocator.free(lower_pattern);

            if (std.mem.indexOf(u8, lower_line, lower_pattern) != null) {
                return true;
            }
        }
        return false;
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

        // Add default log levels with simplified patterns
        try config.addLevel("error", "error|exception|fail|failed|failure|critical", "error.log");
        try config.addLevel("warn", "warn|warning", "warn.log");
        try config.addLevel("info", "info", "info.log");
        try config.addLevel("debug", "debug", "debug.log");

        return config;
    }

    pub fn addLevel(self: *Self, name: []const u8, pattern_str: []const u8, path: []const u8) !void {
        const level = UserLevel.init(self.allocator, pattern_str, path) catch {
            log.log(.err, "Failed to create pattern for level");
            return error.PatternError;
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

    // Simple TOML-like configuration loader
    pub fn loadFromFile(self: *Self, file_path: []const u8) !bool {
        const file = std.fs.cwd().openFile(file_path, .{}) catch {
            log.log(.err, "Failed to open configuration file");
            return false;
        };
        defer file.close();

        const content = file.readToEndAlloc(self.allocator, 1024 * 1024) catch {
            log.log(.err, "Failed to read configuration file");
            return false;
        };
        defer self.allocator.free(content);

        return self.parseToml(content);
    }

    fn parseToml(self: *Self, content: []const u8) !bool {
        var lines = std.mem.splitScalar(u8, content, '\n');
        var current_section: ?[]const u8 = null;

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            // Section headers
            if (trimmed[0] == '[' and trimmed[trimmed.len - 1] == ']') {
                current_section = trimmed[1 .. trimmed.len - 1];
                continue;
            }

            // Key-value pairs
            if (std.mem.indexOf(u8, trimmed, " = ")) |eq_pos| {
                const key = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
                var value = std.mem.trim(u8, trimmed[eq_pos + 3 ..], " \t");

                // Remove quotes if present
                if (value.len >= 2 and value[0] == '"' and value[value.len - 1] == '"') {
                    value = value[1 .. value.len - 1];
                }

                if (current_section) |section| {
                    if (std.mem.eql(u8, section, "timbre")) {
                        if (std.mem.eql(u8, key, "log_dir")) {
                            try self.setLogDir(value);
                            log.log(.info, "Config: timbre.log_dir set");
                        }
                    } else if (std.mem.eql(u8, section, "log_level")) {
                        const path = try std.fmt.allocPrint(self.allocator, "{s}.log", .{key});
                        defer self.allocator.free(path);

                        try self.addLevel(key, value, path);
                        log.log(.info, "Config: added log level");
                    }
                }
            }
        }

        return true;
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
};
