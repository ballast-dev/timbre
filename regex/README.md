# Timbre Regex Library

A high-performance, feature-rich regular expression engine written in Zig.

## Features

- **Thompson NFA-inspired architecture** using direct AST interpretation
- **Comprehensive regex support**:
  - Literal characters and `.` (any character)
  - Character classes `[abc]`, `[a-z]`, `[^abc]`
  - Escape sequences `\d`, `\w`, `\s`, `\n`, `\t`, `\r`, etc.
  - Quantifiers `*`, `+`, `?`, `{n,m}`
  - Alternation `|` and grouping `()`
  - Anchors `^` (start) and `$` (end)
- **Memory safe** with proper allocator usage
- **Performance optimized** for speed
- **Comprehensive error handling**
- **Match position tracking**

## Quick Start

### Building

```bash
# Build the library
zig build

# Run tests
zig build test

# Build and run example
zig build run-example
```

### Basic Usage

```zig
const std = @import("std");
const regex = @import("regex.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Simple pattern matching
    const is_match = try regex.isMatch(allocator, "error|fail", "This is an error");
    std.debug.print("Match: {}\n", .{is_match}); // true

    // Find match positions
    const match = try regex.findMatch(allocator, "\\d+", "Price: $42.99");
    if (match) |m| {
        std.debug.print("Found number at {d}-{d}\n", .{m.start, m.end});
    }

    // Compiled regex for repeated use
    var compiled = try regex.Regex.compile(allocator, "\\w+@\\w+\\.\\w+");
    defer compiled.deinit();
    
    const has_email = compiled.isMatch("Contact us at support@example.com");
    std.debug.print("Has email: {}\n", .{has_email}); // true
}
```

## API Reference

### Convenience Functions

- `isMatch(allocator, pattern, text)` - Test if pattern matches text
- `findMatch(allocator, pattern, text)` - Find first match and return positions

### Regex Struct

- `Regex.compile(allocator, pattern)` - Compile a pattern for repeated use
- `regex.isMatch(text)` - Test if compiled pattern matches text
- `regex.findMatch(text)` - Find first match with compiled pattern
- `regex.deinit()` - Clean up compiled regex

### Types

- `Match` - Contains `start` and `end` positions of a match
- `RegexError` - Comprehensive error types for parsing and matching

## Pattern Syntax

| Pattern | Description | Example |
|---------|-------------|---------|
| `abc` | Literal characters | Matches "abc" |
| `.` | Any character except newline | `a.c` matches "abc", "a1c" |
| `[abc]` | Character class | Matches 'a', 'b', or 'c' |
| `[a-z]` | Character range | Matches any lowercase letter |
| `[^abc]` | Negated character class | Matches anything except 'a', 'b', 'c' |
| `\d` | Digit | Matches 0-9 |
| `\w` | Word character | Matches a-z, A-Z, 0-9, _ |
| `\s` | Whitespace | Matches space, tab, newline |
| `*` | Zero or more | `a*` matches "", "a", "aa", "aaa" |
| `+` | One or more | `a+` matches "a", "aa", "aaa" but not "" |
| `?` | Zero or one | `a?` matches "" or "a" |
| `{n,m}` | Between n and m | `a{2,4}` matches "aa", "aaa", "aaaa" |
| `|` | Alternation | `cat|dog` matches "cat" or "dog" |
| `()` | Grouping | `(ab)+` matches "ab", "abab", "ababab" |
| `^` | Start anchor | `^hello` matches "hello" at start of string |
| `$` | End anchor | `world$` matches "world" at end of string |

## Integration

### As a Library

Copy `regex.zig` to your project and import it:

```zig
const regex = @import("regex.zig");
```

### Link with Static Library

1. Build the library: `zig build`
2. Copy `zig-out/lib/libtimbre-regex.a` to your project
3. Link against it in your build.zig

## Performance

This regex engine uses direct AST interpretation instead of traditional NFA construction, providing:

- **Fast compilation** - No NFA state explosion
- **Predictable performance** - O(n*m) worst case where n=text length, m=pattern complexity
- **Low memory usage** - No large state machines to store

## Testing

The library includes comprehensive tests covering all regex features:

```bash
zig build test
```

Total: 13 regex-specific tests plus integration tests.

## License

Part of the Timbre project. See main project license.
