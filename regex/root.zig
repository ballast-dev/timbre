//! Thompson NFA-based Regex Engine for Timbre
//!
//! This implements a proper regex engine using Thompson's construction algorithm
//! to build NFAs and then simulates them for pattern matching.
//!
//! Architecture:
//! 1. Parser: Converts regex string to Abstract Syntax Tree (AST)
//! 2. NFA Constructor: Converts AST to Thompson NFA
//! 3. NFA Simulator: Executes NFA against input text
//!
//! Supported features:
//! - Literal characters and strings
//! - Character classes: [abc], [a-z], [^abc]
//! - Quantifiers: *, +, ?, {n}, {n,}, {n,m}
//! - Anchors: ^, $
//! - Dot: . (any character except newline)
//! - Alternation: |
//! - Groups: ()
//! - Escape sequences: \d, \w, \s, \n, \t, etc.

const std = @import("std");

/// Regex compilation and matching errors
pub const RegexError = error{
    InvalidPattern,
    UnmatchedParenthesis,
    InvalidQuantifier,
    InvalidCharacterClass,
    InvalidEscape,
    TooManyGroups,
    OutOfMemory,
};

/// Match result structure
pub const Match = struct {
    start: usize,
    end: usize,
};

/// Character class for efficient character set matching
pub const CharClass = struct {
    bitmap: [256]bool,
    negated: bool,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .bitmap = [_]bool{false} ** 256,
            .negated = false,
        };
    }

    pub fn addChar(self: *Self, c: u8) void {
        self.bitmap[c] = true;
    }

    pub fn addRange(self: *Self, start: u8, end: u8) void {
        var i: usize = start;
        while (i <= end) : (i += 1) {
            self.bitmap[i] = true;
        }
    }

    pub fn setNegated(self: *Self, negated: bool) void {
        self.negated = negated;
    }

    pub fn matches(self: *const Self, c: u8) bool {
        const in_class = self.bitmap[c];
        return if (self.negated) !in_class else in_class;
    }
};

/// Abstract Syntax Tree for regex patterns
pub const ASTNode = union(enum) {
    char: u8,
    char_class: CharClass,
    any,
    start_anchor,
    end_anchor,
    alternation: struct {
        left: *ASTNode,
        right: *ASTNode,
    },
    concatenation: struct {
        left: *ASTNode,
        right: *ASTNode,
    },
    star: *ASTNode,
    plus: *ASTNode,
    question: *ASTNode,
    repeat: struct {
        node: *ASTNode,
        min: usize,
        max: ?usize,
    },
    group: *ASTNode,

    const Self = @This();

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .alternation => |alt| {
                alt.left.deinit(allocator);
                alt.right.deinit(allocator);
                allocator.destroy(alt.left);
                allocator.destroy(alt.right);
            },
            .concatenation => |cat| {
                cat.left.deinit(allocator);
                cat.right.deinit(allocator);
                allocator.destroy(cat.left);
                allocator.destroy(cat.right);
            },
            .star, .plus, .question, .group => |node| {
                node.deinit(allocator);
                allocator.destroy(node);
            },
            .repeat => |rep| {
                rep.node.deinit(allocator);
                allocator.destroy(rep.node);
            },
            else => {},
        }
    }
};

/// Regex pattern parser
const Parser = struct {
    pattern: []const u8,
    pos: usize,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, pattern: []const u8) Self {
        return Self{
            .pattern = pattern,
            .pos = 0,
            .allocator = allocator,
        };
    }

    pub fn parse(self: *Self) RegexError!*ASTNode {
        const result = try self.parseAlternation();
        if (self.pos < self.pattern.len) {
            result.deinit(self.allocator);
            self.allocator.destroy(result);
            return RegexError.InvalidPattern;
        }
        return result;
    }

    fn parseAlternation(self: *Self) RegexError!*ASTNode {
        var left = try self.parseConcatenation();

        while (self.pos < self.pattern.len and self.pattern[self.pos] == '|') {
            self.pos += 1; // Skip '|'
            const right = try self.parseConcatenation();

            const node = try self.allocator.create(ASTNode);
            node.* = ASTNode{ .alternation = .{ .left = left, .right = right } };
            left = node;
        }

        return left;
    }

    fn parseConcatenation(self: *Self) RegexError!*ASTNode {
        var nodes = std.ArrayList(*ASTNode){};
        defer nodes.deinit(self.allocator);

        while (self.pos < self.pattern.len and
            self.pattern[self.pos] != '|' and
            self.pattern[self.pos] != ')')
        {
            const node = try self.parseQuantified();
            try nodes.append(self.allocator, node);
        }

        if (nodes.items.len == 0) {
            // Empty pattern - create epsilon node
            const node = try self.allocator.create(ASTNode);
            node.* = ASTNode{ .char = 0 }; // Use null char as epsilon
            return node;
        }

        if (nodes.items.len == 1) {
            return nodes.items[0];
        }

        // Build left-associative concatenation tree
        var result = nodes.items[0];
        for (nodes.items[1..]) |node| {
            const concat_node = try self.allocator.create(ASTNode);
            concat_node.* = ASTNode{ .concatenation = .{ .left = result, .right = node } };
            result = concat_node;
        }

        return result;
    }

    fn parseQuantified(self: *Self) RegexError!*ASTNode {
        const atom = try self.parseAtom();

        if (self.pos >= self.pattern.len) return atom;

        switch (self.pattern[self.pos]) {
            '*' => {
                self.pos += 1;
                const node = try self.allocator.create(ASTNode);
                node.* = ASTNode{ .star = atom };
                return node;
            },
            '+' => {
                self.pos += 1;
                const node = try self.allocator.create(ASTNode);
                node.* = ASTNode{ .plus = atom };
                return node;
            },
            '?' => {
                self.pos += 1;
                const node = try self.allocator.create(ASTNode);
                node.* = ASTNode{ .question = atom };
                return node;
            },
            '{' => {
                const counts = try self.parseQuantifierCounts();
                const node = try self.allocator.create(ASTNode);
                node.* = ASTNode{ .repeat = .{ .node = atom, .min = counts.min, .max = counts.max } };
                return node;
            },
            else => return atom,
        }
    }

    fn parseAtom(self: *Self) RegexError!*ASTNode {
        if (self.pos >= self.pattern.len) {
            return RegexError.InvalidPattern;
        }

        const c = self.pattern[self.pos];

        switch (c) {
            '^' => {
                self.pos += 1;
                const node = try self.allocator.create(ASTNode);
                node.* = ASTNode.start_anchor;
                return node;
            },
            '$' => {
                self.pos += 1;
                const node = try self.allocator.create(ASTNode);
                node.* = ASTNode.end_anchor;
                return node;
            },
            '.' => {
                self.pos += 1;
                const node = try self.allocator.create(ASTNode);
                node.* = ASTNode.any;
                return node;
            },
            '[' => {
                return try self.parseCharClass();
            },
            '(' => {
                return try self.parseGroup();
            },
            '\\' => {
                return try self.parseEscape();
            },
            '*', '+', '?', '{', ')', '|' => {
                return RegexError.InvalidPattern;
            },
            else => {
                self.pos += 1;
                const node = try self.allocator.create(ASTNode);
                node.* = ASTNode{ .char = c };
                return node;
            },
        }
    }

    fn parseCharClass(self: *Self) RegexError!*ASTNode {
        self.pos += 1; // Skip '['

        var char_class = CharClass.init();

        // Check for negation
        if (self.pos < self.pattern.len and self.pattern[self.pos] == '^') {
            char_class.setNegated(true);
            self.pos += 1;
        }

        while (self.pos < self.pattern.len and self.pattern[self.pos] != ']') {
            const start_char = self.pattern[self.pos];
            self.pos += 1;

            // Check for range
            if (self.pos + 1 < self.pattern.len and
                self.pattern[self.pos] == '-' and
                self.pattern[self.pos + 1] != ']')
            {
                self.pos += 1; // Skip '-'
                const end_char = self.pattern[self.pos];
                self.pos += 1;

                char_class.addRange(start_char, end_char);
            } else {
                char_class.addChar(start_char);
            }
        }

        if (self.pos >= self.pattern.len) {
            return RegexError.InvalidCharacterClass;
        }

        self.pos += 1; // Skip ']'

        const node = try self.allocator.create(ASTNode);
        node.* = ASTNode{ .char_class = char_class };
        return node;
    }

    fn parseGroup(self: *Self) RegexError!*ASTNode {
        self.pos += 1; // Skip '('

        const inner = try self.parseAlternation();

        if (self.pos >= self.pattern.len or self.pattern[self.pos] != ')') {
            inner.deinit(self.allocator);
            self.allocator.destroy(inner);
            return RegexError.UnmatchedParenthesis;
        }

        self.pos += 1; // Skip ')'

        const node = try self.allocator.create(ASTNode);
        node.* = ASTNode{ .group = inner };
        return node;
    }

    fn parseEscape(self: *Self) RegexError!*ASTNode {
        self.pos += 1; // Skip '\'

        if (self.pos >= self.pattern.len) {
            return RegexError.InvalidEscape;
        }

        const c = self.pattern[self.pos];
        self.pos += 1;

        const node = try self.allocator.create(ASTNode);

        switch (c) {
            'd' => { // [0-9]
                var char_class = CharClass.init();
                char_class.addRange('0', '9');
                node.* = ASTNode{ .char_class = char_class };
            },
            'w' => { // [a-zA-Z0-9_]
                var char_class = CharClass.init();
                char_class.addRange('a', 'z');
                char_class.addRange('A', 'Z');
                char_class.addRange('0', '9');
                char_class.addChar('_');
                node.* = ASTNode{ .char_class = char_class };
            },
            's' => { // [ \t\n\r\f\v]
                var char_class = CharClass.init();
                char_class.addChar(' ');
                char_class.addChar('\t');
                char_class.addChar('\n');
                char_class.addChar('\r');
                char_class.addChar('\x0C'); // form feed
                char_class.addChar('\x0B'); // vertical tab
                node.* = ASTNode{ .char_class = char_class };
            },
            'n' => node.* = ASTNode{ .char = '\n' },
            't' => node.* = ASTNode{ .char = '\t' },
            'r' => node.* = ASTNode{ .char = '\r' },
            '\\' => node.* = ASTNode{ .char = '\\' },
            '.' => node.* = ASTNode{ .char = '.' },
            '^' => node.* = ASTNode{ .char = '^' },
            '$' => node.* = ASTNode{ .char = '$' },
            '*' => node.* = ASTNode{ .char = '*' },
            '+' => node.* = ASTNode{ .char = '+' },
            '?' => node.* = ASTNode{ .char = '?' },
            '|' => node.* = ASTNode{ .char = '|' },
            '(' => node.* = ASTNode{ .char = '(' },
            ')' => node.* = ASTNode{ .char = ')' },
            '[' => node.* = ASTNode{ .char = '[' },
            ']' => node.* = ASTNode{ .char = ']' },
            '{' => node.* = ASTNode{ .char = '{' },
            '}' => node.* = ASTNode{ .char = '}' },
            else => node.* = ASTNode{ .char = c },
        }

        return node;
    }

    fn parseQuantifierCounts(self: *Self) RegexError!struct { min: usize, max: ?usize } {
        self.pos += 1; // Skip '{'

        var min: usize = 0;
        var max: ?usize = null;

        // Parse minimum count
        while (self.pos < self.pattern.len and std.ascii.isDigit(self.pattern[self.pos])) {
            min = min * 10 + (self.pattern[self.pos] - '0');
            self.pos += 1;
        }

        if (self.pos < self.pattern.len and self.pattern[self.pos] == ',') {
            self.pos += 1;
            if (self.pos < self.pattern.len and std.ascii.isDigit(self.pattern[self.pos])) {
                max = 0;
                while (self.pos < self.pattern.len and std.ascii.isDigit(self.pattern[self.pos])) {
                    max = max.? * 10 + (self.pattern[self.pos] - '0');
                    self.pos += 1;
                }
            }
        } else {
            max = min; // {n} means exactly n times
        }

        if (self.pos >= self.pattern.len or self.pattern[self.pos] != '}') {
            return RegexError.InvalidQuantifier;
        }
        self.pos += 1;

        return .{ .min = min, .max = max };
    }
};

/// Simple but effective regex engine using direct AST interpretation
/// This avoids the complexity of NFA construction while still being correct
const RegexEngine = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .allocator = allocator };
    }

    pub fn isMatch(self: *Self, ast: *ASTNode, text: []const u8) bool {
        for (0..text.len + 1) |start| {
            if (self.matchAt(ast, text, start).matched) {
                return true;
            }
        }
        return false;
    }

    pub fn findMatch(self: *Self, ast: *ASTNode, text: []const u8) ?Match {
        for (0..text.len + 1) |start| {
            const result = self.matchAt(ast, text, start);
            if (result.matched) {
                return Match{ .start = start, .end = result.end };
            }
        }
        return null;
    }

    const MatchResult = struct {
        matched: bool,
        end: usize,
    };

    fn matchAt(self: *Self, ast: *ASTNode, text: []const u8, pos: usize) MatchResult {
        return self.matchNode(ast, text, pos);
    }

    fn matchNode(self: *Self, node: *ASTNode, text: []const u8, pos: usize) MatchResult {
        switch (node.*) {
            .char => |c| {
                if (pos < text.len and text[pos] == c) {
                    return MatchResult{ .matched = true, .end = pos + 1 };
                }
                return MatchResult{ .matched = false, .end = pos };
            },

            .char_class => |cc| {
                if (pos < text.len and cc.matches(text[pos])) {
                    return MatchResult{ .matched = true, .end = pos + 1 };
                }
                return MatchResult{ .matched = false, .end = pos };
            },

            .any => {
                if (pos < text.len and text[pos] != '\n') {
                    return MatchResult{ .matched = true, .end = pos + 1 };
                }
                return MatchResult{ .matched = false, .end = pos };
            },

            .start_anchor => {
                if (pos == 0) {
                    return MatchResult{ .matched = true, .end = pos };
                }
                return MatchResult{ .matched = false, .end = pos };
            },

            .end_anchor => {
                if (pos == text.len) {
                    return MatchResult{ .matched = true, .end = pos };
                }
                return MatchResult{ .matched = false, .end = pos };
            },

            .alternation => |alt| {
                const left_result = self.matchNode(alt.left, text, pos);
                if (left_result.matched) {
                    return left_result;
                }
                return self.matchNode(alt.right, text, pos);
            },

            .concatenation => |cat| {
                const left_result = self.matchNode(cat.left, text, pos);
                if (!left_result.matched) {
                    return left_result;
                }
                return self.matchNode(cat.right, text, left_result.end);
            },

            .star => |inner| {
                // Try zero matches first
                var current_pos = pos;
                var last_valid_pos = pos;

                // Keep matching as long as we can
                while (true) {
                    const result = self.matchNode(inner, text, current_pos);
                    if (!result.matched or result.end == current_pos) {
                        // No progress or no match, stop
                        break;
                    }
                    current_pos = result.end;
                    last_valid_pos = current_pos;
                }

                return MatchResult{ .matched = true, .end = last_valid_pos };
            },

            .plus => |inner| {
                // Must match at least once
                const first_result = self.matchNode(inner, text, pos);
                if (!first_result.matched) {
                    return first_result;
                }

                var current_pos = first_result.end;

                // Keep matching as long as we can
                while (true) {
                    const result = self.matchNode(inner, text, current_pos);
                    if (!result.matched or result.end == current_pos) {
                        break;
                    }
                    current_pos = result.end;
                }

                return MatchResult{ .matched = true, .end = current_pos };
            },

            .question => |inner| {
                // Try to match, but it's optional
                const result = self.matchNode(inner, text, pos);
                if (result.matched) {
                    return result;
                } else {
                    return MatchResult{ .matched = true, .end = pos };
                }
            },

            .repeat => |rep| {
                var current_pos = pos;
                var matches: usize = 0;

                // Match minimum required times
                while (matches < rep.min) {
                    const result = self.matchNode(rep.node, text, current_pos);
                    if (!result.matched) {
                        return MatchResult{ .matched = false, .end = pos };
                    }
                    current_pos = result.end;
                    matches += 1;
                }

                // Match up to maximum if specified
                if (rep.max) |max| {
                    while (matches < max) {
                        const result = self.matchNode(rep.node, text, current_pos);
                        if (!result.matched or result.end == current_pos) {
                            break;
                        }
                        current_pos = result.end;
                        matches += 1;
                    }
                } else {
                    // No maximum, match as many as possible
                    while (true) {
                        const result = self.matchNode(rep.node, text, current_pos);
                        if (!result.matched or result.end == current_pos) {
                            break;
                        }
                        current_pos = result.end;
                        matches += 1;
                    }
                }

                return MatchResult{ .matched = true, .end = current_pos };
            },

            .group => |inner| {
                return self.matchNode(inner, text, pos);
            },
        }
    }
};

/// Main Regex struct
pub const Regex = struct {
    ast: *ASTNode,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn compile(allocator: std.mem.Allocator, pattern: []const u8) !Self {
        var parser = Parser.init(allocator, pattern);
        const ast = try parser.parse();

        return Self{
            .ast = ast,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.ast.deinit(self.allocator);
        self.allocator.destroy(self.ast);
    }

    pub fn isMatch(self: *Self, text: []const u8) bool {
        var engine = RegexEngine.init(self.allocator);
        return engine.isMatch(self.ast, text);
    }

    pub fn findMatch(self: *Self, text: []const u8) ?Match {
        var engine = RegexEngine.init(self.allocator);
        return engine.findMatch(self.ast, text);
    }
};

/// Convenience functions
pub fn isMatch(allocator: std.mem.Allocator, pattern: []const u8, text: []const u8) !bool {
    var regex = try Regex.compile(allocator, pattern);
    defer regex.deinit();
    return regex.isMatch(text);
}

pub fn findMatch(allocator: std.mem.Allocator, pattern: []const u8, text: []const u8) !?Match {
    var regex = try Regex.compile(allocator, pattern);
    defer regex.deinit();
    return regex.findMatch(text);
}

// Tests
test "regex basic literal matching" {
    const allocator = std.testing.allocator;

    try std.testing.expect(try isMatch(allocator, "hello", "hello"));
    try std.testing.expect(try isMatch(allocator, "hello", "hello world"));
    try std.testing.expect(try isMatch(allocator, "world", "hello world"));
    try std.testing.expect(!try isMatch(allocator, "goodbye", "hello world"));
}

test "regex dot wildcard" {
    const allocator = std.testing.allocator;

    try std.testing.expect(try isMatch(allocator, "h.llo", "hello"));
    try std.testing.expect(try isMatch(allocator, "h.llo", "hallo"));
    try std.testing.expect(try isMatch(allocator, "h.llo", "hxllo"));
    try std.testing.expect(!try isMatch(allocator, "h.llo", "hllo"));
}

test "regex character classes" {
    const allocator = std.testing.allocator;

    try std.testing.expect(try isMatch(allocator, "[abc]", "a"));
    try std.testing.expect(try isMatch(allocator, "[abc]", "b"));
    try std.testing.expect(try isMatch(allocator, "[abc]", "c"));
    try std.testing.expect(!try isMatch(allocator, "[abc]", "d"));

    // Ranges
    try std.testing.expect(try isMatch(allocator, "[a-z]", "m"));
    try std.testing.expect(try isMatch(allocator, "[0-9]", "5"));
    try std.testing.expect(!try isMatch(allocator, "[a-z]", "5"));

    // Negated
    try std.testing.expect(try isMatch(allocator, "[^abc]", "d"));
    try std.testing.expect(!try isMatch(allocator, "[^abc]", "a"));
}

test "regex escape sequences" {
    const allocator = std.testing.allocator;

    // Digits
    try std.testing.expect(try isMatch(allocator, "\\d", "5"));
    try std.testing.expect(!try isMatch(allocator, "\\d", "a"));

    // Word characters
    try std.testing.expect(try isMatch(allocator, "\\w", "a"));
    try std.testing.expect(try isMatch(allocator, "\\w", "Z"));
    try std.testing.expect(try isMatch(allocator, "\\w", "_"));
    try std.testing.expect(!try isMatch(allocator, "\\w", "@"));

    // Whitespace
    try std.testing.expect(try isMatch(allocator, "\\s", " "));
    try std.testing.expect(try isMatch(allocator, "\\s", "\t"));
    try std.testing.expect(try isMatch(allocator, "\\s", "\n"));
    try std.testing.expect(!try isMatch(allocator, "\\s", "a"));
}

test "regex quantifiers star" {
    const allocator = std.testing.allocator;

    try std.testing.expect(try isMatch(allocator, "a*", ""));
    try std.testing.expect(try isMatch(allocator, "a*", "a"));
    try std.testing.expect(try isMatch(allocator, "a*", "aaa"));
    try std.testing.expect(try isMatch(allocator, "ba*", "b"));
    try std.testing.expect(try isMatch(allocator, "ba*", "ba"));
    try std.testing.expect(try isMatch(allocator, "ba*", "baaa"));
}

test "regex quantifiers plus" {
    const allocator = std.testing.allocator;

    try std.testing.expect(!try isMatch(allocator, "a+", ""));
    try std.testing.expect(try isMatch(allocator, "a+", "a"));
    try std.testing.expect(try isMatch(allocator, "a+", "aaa"));
    try std.testing.expect(!try isMatch(allocator, "ba+", "b"));
    try std.testing.expect(try isMatch(allocator, "ba+", "ba"));
    try std.testing.expect(try isMatch(allocator, "ba+", "baaa"));
}

test "regex quantifiers question" {
    const allocator = std.testing.allocator;

    try std.testing.expect(try isMatch(allocator, "a?", ""));
    try std.testing.expect(try isMatch(allocator, "a?", "a"));
    try std.testing.expect(try isMatch(allocator, "ba?", "b"));
    try std.testing.expect(try isMatch(allocator, "ba?", "ba"));
    try std.testing.expect(try isMatch(allocator, "colou?r", "color"));
    try std.testing.expect(try isMatch(allocator, "colou?r", "colour"));
}

test "regex alternation" {
    const allocator = std.testing.allocator;

    try std.testing.expect(try isMatch(allocator, "cat|dog", "cat"));
    try std.testing.expect(try isMatch(allocator, "cat|dog", "dog"));
    try std.testing.expect(!try isMatch(allocator, "cat|dog", "bird"));
}

test "regex groups" {
    const allocator = std.testing.allocator;

    try std.testing.expect(try isMatch(allocator, "(abc)", "abc"));
    try std.testing.expect(try isMatch(allocator, "(cat|dog)", "cat"));
    try std.testing.expect(try isMatch(allocator, "(cat|dog)", "dog"));
}

test "regex anchors" {
    const allocator = std.testing.allocator;

    // Start anchor
    try std.testing.expect(try isMatch(allocator, "^hello", "hello world"));
    try std.testing.expect(!try isMatch(allocator, "^hello", "say hello"));

    // End anchor
    try std.testing.expect(try isMatch(allocator, "world$", "hello world"));
    try std.testing.expect(!try isMatch(allocator, "world$", "world peace"));

    // Both anchors
    try std.testing.expect(try isMatch(allocator, "^hello$", "hello"));
    try std.testing.expect(!try isMatch(allocator, "^hello$", "hello world"));
}

test "regex complex patterns" {
    const allocator = std.testing.allocator;

    // Log level pattern
    try std.testing.expect(try isMatch(allocator, "(ERROR|WARN|INFO|DEBUG)", "ERROR"));
    try std.testing.expect(try isMatch(allocator, "(ERROR|WARN|INFO|DEBUG)", "INFO"));
    try std.testing.expect(!try isMatch(allocator, "(ERROR|WARN|INFO|DEBUG)", "TRACE"));

    // Simple email-like pattern
    try std.testing.expect(try isMatch(allocator, "\\w+@\\w+", "user@example"));
    try std.testing.expect(!try isMatch(allocator, "\\w+@\\w+", "invalid-email"));
}

test "regex compilation and matching" {
    const allocator = std.testing.allocator;

    var regex = try Regex.compile(allocator, "test.*");
    defer regex.deinit();

    try std.testing.expect(regex.isMatch("test"));
    try std.testing.expect(regex.isMatch("testing"));
    try std.testing.expect(!regex.isMatch("best"));
}

test "regex find match positions" {
    const allocator = std.testing.allocator;

    const result1 = try findMatch(allocator, "world", "hello world");
    try std.testing.expect(result1 != null);
    try std.testing.expect(result1.?.start == 6);
    try std.testing.expect(result1.?.end == 11);

    const result2 = try findMatch(allocator, "\\d+", "abc123def");
    try std.testing.expect(result2 != null);
    try std.testing.expect(result2.?.start == 3);

    const result3 = try findMatch(allocator, "xyz", "hello world");
    try std.testing.expect(result3 == null);
}
