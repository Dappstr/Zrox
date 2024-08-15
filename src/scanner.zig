const std = @import("std");
const Token = @import("token.zig");
const main = @import("main.zig");

pub const Scanner = struct {
    const Self = @This();
    start: usize = 0,
    current: usize = 0,
    line: usize = 1,

    source: []u8,
    tokens: std.ArrayList(Token.Token),
    const keywords = std.StaticStringMap(Token.Token_Type).initComptime(.{
        .{ "and", Token.Token_Type.AND },
        .{ "class", Token.Token_Type.CLASS },
        .{ "else", Token.Token_Type.ELSE },
        .{ "false", Token.Token_Type.FALSE },
        .{ "for", Token.Token_Type.FOR },
        .{ "fun", Token.Token_Type.FUN },
        .{ "if", Token.Token_Type.IF },
        .{ "nil", Token.Token_Type.NIL },
        .{ "or", Token.Token_Type.OR },
        .{ "print", Token.Token_Type.PRINT },
        .{ "return", Token.Token_Type.RETURN },
        .{ "super", Token.Token_Type.SUPER },
        .{ "this", Token.Token_Type.THIS },
        .{ "true", Token.Token_Type.TRUE },
        .{ "var", Token.Token_Type.VAR },
        .{ "while", Token.Token_Type.WHILE },
    });

    pub fn init(allocator: std.mem.Allocator, src: []u8) Scanner {
        return .{
            .source = src,
            .tokens = std.ArrayList(Token.Token).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.tokens.deinit();
        //keywords.deinit(allocator);
    }

    fn is_at_end(self: *Self) bool {
        return self.current >= self.source.len;
    }

    fn advance(self: *Self) u8 {
        self.current += 1;
        return self.source[self.current - 1];
    }

    fn match_next(self: *Self, expected: u8) bool {
        if (self.is_at_end()) {
            return false;
        } else if (self.source[self.current] != expected) {
            return false;
        }
        self.current += 1;
        return true;
    }

    fn add_token(self: *Self, ttype: Token.Token_Type) !void {
        try self.add_token_with_literal(ttype, Token.Literal.None);
    }

    fn add_token_with_literal(self: *Self, ttype: Token.Token_Type, literal: Token.Literal) !void {
        const text = self.source[self.start..self.current];
        std.debug.print("TEXT: {s}, TEXT LEN: {}\n", .{ text, text.len });
        const token = Token.Token{ .type = ttype, .lexeme = text, .literal = literal, .line = self.line };
        try self.tokens.append(token);
    }

    fn peek(self: *Self) ?u8 {
        if (self.is_at_end()) return null;
        return self.source[self.current];
    }

    fn peek_next(self: *Self) ?u8 {
        if (self.current + 1 >= self.source.len) return null;
        return self.source[self.current + 1];
    }

    fn string(self: *Self) !void {
        var c: u8 = self.peek().?;
        while (c != '\"' and !self.is_at_end()) {
            if (c == '\n') {
                self.line += 1;
            }
            c = self.advance();
        }
        if (self.is_at_end()) {
            try main.base_error(self.line, "Unterminated string.");
            return;
        }
        //_ = self.advance();
        const value: []const u8 = self.source[self.start + 1 .. self.current - 1];
        const literal = Token.Literal{ .String = value };
        try self.add_token_with_literal(Token.Token_Type.STRING, literal);
    }

    fn number(self: *Self) !void {
        var c: u8 = self.peek().?;
        while (std.ascii.isDigit(c)) {
            c = self.advance();
        }
        if (c == '.' and std.ascii.isDigit(self.peek().?)) {
            c = self.advance();
            while (std.ascii.isDigit(c)) {
                c = self.advance();
            }
        }

        self.current -= 1;

        const flt_lit = self.source[self.start..self.current];
        std.debug.print("FOUND FLOAT LITERAL: {s}, and LENGTH: {}\n", .{ flt_lit, flt_lit.len });

        const flt: f64 = try std.fmt.parseFloat(f64, self.source[self.start..self.current]);
        const literal = Token.Literal{ .Float = flt };
        //_ = literal;
        std.debug.print("PARSED FLOAT: {d}\n", .{flt});
        try self.add_token_with_literal(Token.Token_Type.NUMBER, literal);
    }

    fn identifier(self: *Self) !void {
        var c: u8 = self.peek().?;
        while (std.ascii.isAlphabetic(c) or c == '_') {
            c = self.advance();
        }
        self.current -= 1;

        const text: []u8 = self.source[self.start..self.current];
        //std.debug.print("TEXT LEN: {}\n", .{text.len});
        const ttype_opt = keywords.get(text);
        const ttype: Token.Token_Type = if (ttype_opt == null) Token.Token_Type.IDENTIFIER else ttype_opt.?;
        try self.add_token(ttype);
    }

    fn scan_token(self: *Self) !void {
        const c: u8 = self.advance();
        switch (c) {
            '(' => try self.add_token(Token.Token_Type.LEFT_PAREN),
            ')' => try self.add_token(Token.Token_Type.RIGHT_PAREN),
            '{' => try self.add_token(Token.Token_Type.LEFT_BRACE),
            '}' => try self.add_token(Token.Token_Type.RIGHT_BRACE),
            ',' => try self.add_token(Token.Token_Type.COMMA),
            '.' => try self.add_token(Token.Token_Type.DOT),
            '-' => try self.add_token(Token.Token_Type.MINUS),
            '+' => try self.add_token(Token.Token_Type.PLUS),
            ';' => try self.add_token(Token.Token_Type.SEMICOLON),
            '*' => try self.add_token(Token.Token_Type.STAR),
            '!' => {
                if (self.match_next('=')) {
                    try self.add_token(Token.Token_Type.BANG_EQUAL);
                } else {
                    try self.add_token(Token.Token_Type.BANG);
                }
            },
            '=' => {
                if (self.match_next('=')) {
                    try self.add_token(Token.Token_Type.EQUAL_EQUAL);
                } else {
                    try self.add_token(Token.Token_Type.EQUAL);
                }
            },
            '<' => {
                if (self.match_next('=')) {
                    try self.add_token(Token.Token_Type.LESS_EQUAL);
                } else {
                    try self.add_token(Token.Token_Type.LESS);
                }
            },
            '>' => {
                if (self.match_next('=')) {
                    try self.add_token(Token.Token_Type.GREATER_EQUAL);
                } else {
                    try self.add_token(Token.Token_Type.GREATER);
                }
            },
            '/' => {
                if (self.match_next('/')) {
                    while (true) {
                        _ = self.advance();
                        if (self.peek() == null or self.peek() == '\n' or self.is_at_end()) {
                            break;
                        }
                    } else if (self.match_next('*')) {
                        while (true) {
                            _ = self.advance();
                            if (self.peek() == '*' and self.peek_next() == '/') {
                                _ = self.advance();
                                _ = self.advance();
                                break;
                            } else if (self.peek() == '\n') {
                                self.line += 1;
                            } else if (is_at_end()) {
                                main.base_error(self.line, "Error unterminated multiline comment.");
                            }
                        }
                    }
                } else {
                    try self.add_token(Token.Token_Type.SLASH);
                }
            },
            ' ' => {},
            '\r' => {},
            '\t' => {},

            '\n' => {
                self.line += 1;
            },
            '\"' => {
                try self.string();
            },
            else => {
                if (std.ascii.isDigit(c)) {
                    try self.number();
                } else if (std.ascii.isAlphabetic(c)) {
                    try self.identifier();
                } else {
                    try main.base_error(self.line, "Unexpected character.");
                    //return;
                }
            },
        }
    }

    pub fn scan_tokens(self: *Self) ![]const Token.Token {
        while (!self.is_at_end()) {
            self.start = self.current;
            try self.scan_token();
        }
        return self.tokens.items;
    }
};
