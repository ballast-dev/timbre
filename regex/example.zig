const std = @import("std");
const regex = @import("root.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Timbre Regex Library Demo ===\n\n", .{});

    // Example 1: Simple pattern matching
    std.debug.print("1. Simple pattern matching:\n", .{});
    const simple_pattern = "error|fail";
    const test_text = "This is an error message";

    const is_match = try regex.isMatch(allocator, simple_pattern, test_text);
    std.debug.print("   Pattern: '{s}'\n", .{simple_pattern});
    std.debug.print("   Text: '{s}'\n", .{test_text});
    std.debug.print("   Match: {}\n\n", .{is_match});

    // Example 2: Character classes and quantifiers
    std.debug.print("2. Character classes and quantifiers:\n", .{});
    const email_pattern = "\\w+@\\w+\\.\\w+";
    const email_text = "Contact us at support@example.com";

    const email_match = try regex.findMatch(allocator, email_pattern, email_text);
    std.debug.print("   Pattern: '{s}'\n", .{email_pattern});
    std.debug.print("   Text: '{s}'\n", .{email_text});
    if (email_match) |match| {
        std.debug.print("   Found match at positions {d}-{d}: '{s}'\n\n", .{ match.start, match.end, email_text[match.start..match.end] });
    } else {
        std.debug.print("   No match found\n\n", .{});
    }

    // Example 3: Compiled regex for repeated use
    std.debug.print("3. Compiled regex for performance:\n", .{});
    var log_regex = try regex.Regex.compile(allocator, "\\[(ERROR|WARN|INFO)\\]");
    defer log_regex.deinit();

    const log_lines = [_][]const u8{
        "[ERROR] Database connection failed",
        "[WARN] High memory usage detected",
        "[INFO] System started successfully",
        "[DEBUG] Verbose debugging info",
        "Regular message without log level",
    };

    for (log_lines) |line| {
        const matches = log_regex.isMatch(line);
        std.debug.print("   '{s}' -> {s}\n", .{ line, if (matches) "MATCH" else "no match" });
    }

    std.debug.print("\n=== Demo Complete ===\n", .{});
}
