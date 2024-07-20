const std = @import("std");

pub const Token_Type = enum {
    // Single-character tokens
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,
    COMMA,
    DOT,
    MINUS,
    PLUS,
    SEMICOLON,
    SLASH,
    STAR,

    // One or two character tokens
    BANG,
    BANG_EQUAL,
    EQUAL,
    EQUAL_EQUAL,
    GREATER,
    GREATER_EQUAL,
    LESS,
    LESS_EQUAL,

    // Literals
    IDENTIFIER,
    STRING,
    NUMBER,

    // Keywords
    AND,
    CLASS,
    ELSE,
    FALSE,
    FUN,
    FOR,
    IF,
    NIL,
    OR,
    PRINT,
    RETURN,
    SUPER,
    THIS,
    TRUE,
    VAR,
    WHILE,

    EOF,
};

pub const Literal = union(enum) { Float: f64, String: []const u8, None: void };

pub const Token = struct {
    const Self = @This();
    type: Token_Type,
    lexeme: []u8,
    literal: Literal,
    line: usize,

    pub fn init(self: *Self, token_type: Token_Type, lexeme: []const u8, lit: Literal, line: usize) void {
        self.type = token_type;
        self.lexeme = lexeme;
        self.literal = lit;
        self.line = line;
    }

    fn append_literal(buffer: *std.ArrayList(u8), lit: Literal) !void {
        switch (lit) {
            //Literal.Int => |value| try std.fmt.formatInt(value, 10, .lower, {}, &buffer.writer()),
            Literal.Float => |value| {
                var float_val: [40]u8 = undefined;
                const float_str = try std.fmt.formatFloat(&float_val, value, .{});
                _ = float_str;
                try buffer.appendSlice(&float_val);
            },
            Literal.String => |value| try buffer.appendSlice(value),
            Literal.None => try buffer.appendSlice("null"),
        }
    }

    pub fn to_string(self: *const Self, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();

        try buffer.appendSlice("Token { type: ");
        try buffer.appendSlice(@tagName(self.type));
        try buffer.appendSlice(", lexeme: ");
        try buffer.appendSlice(self.lexeme);
        try buffer.appendSlice(", Literal: ");
        try append_literal(&buffer, self.literal);
        try buffer.appendSlice(", line: ");
        try std.fmt.formatInt(self.line, 10, .lower, .{ .precision = 10 }, &buffer.writer());
        try buffer.appendSlice(" }");
        return try buffer.toOwnedSlice();
    }
};
