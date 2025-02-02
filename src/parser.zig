const std = @import("std");
const Token = @import("token.zig");
const Expr = @import("expression.zig");
const Stmt = @import("statement.zig");

const ParserError = error{
    Unexpected_Token,
    Allocation_Failed,
};

pub const Parser = struct {
    const Self = @This();
    tokens: std.ArrayList(Token.Token),
    alloc: *std.mem.Allocator,
    current: usize = 0,

    pub fn init(allocator: *std.mem.Allocator, toks: std.ArrayList(Token.Token)) Parser {
        return .{ .alloc = allocator, .tokens = toks};
    }

    pub fn deinit(self: *Self) void { self.tokens.deinit(); }

    // pub fn parse(self: *Self) anyerror![]const Stmt.Statement {
    //     var statements = std.ArrayList(Stmt.Statement).init(self.alloc.*);
    //     while (!self.is_at_end()) {
    //         try statements.append(try self.declaration());
    //     }
    //     return statements.items;
    // }


    pub fn parse(self: *Self) anyerror![]const Stmt.Statement {
        var statements = std.ArrayList(Stmt.Statement).init(self.alloc.*);
        while (!self.is_at_end()) {
        const stmt = declaration(self) catch |err| switch (err) {
                ParserError.Unexpected_Token => {
                    continue;
                },
                else => return err,
            };
            try statements.append(stmt);
        }
        return statements.items;
    }

    fn peek(self: *Self) Token.Token { return self.tokens.items[self.current]; }
    fn previous(self: *Self) Token.Token { return self.tokens.items[self.current - 1]; }
    fn advance(self: *Self) Token.Token {
        if(!self.is_at_end()) {
            self.current += 1;
            return self.previous();
        } else {
            return self.peek();
        }
    }

    pub fn match(self: *Self, types: []const Token.Token_Type) bool {
        for(types) |t| {
            if(self.check(t)) {
                _ = self.advance();
                return true;
            }
        }
        return false;
    }

    pub fn check(self: *Self, t: Token.Token_Type) bool {
        if(self.is_at_end()) { return false; }
        return self.peek().type == t;
    }

    fn consume(self: *Self, t: Token.Token_Type) !Token.Token {
        if(self.check(t)) {
            return self.advance();
        } else {
            return ParserError.Unexpected_Token;
        }
    }

    fn declaration(self: *Self) anyerror!Stmt.Statement {
        var stmt_result: Stmt.Statement = undefined;
        if (self.match(&[_]Token.Token_Type{ .VAR })) {
            stmt_result = try self.var_declaration();
        } else {
            stmt_result = try self.statement();
        }
        return stmt_result;
    }


    fn var_declaration(self: *Self) anyerror!Stmt.Statement {
        const name_token = try self.consume(Token.Token_Type.IDENTIFIER);
        var initializer: ?*Expr.Expression = null;
        if (self.match(&[_]Token.Token_Type{ .EQUAL })) {
            initializer = try self.expression();
        }

        _ = try self.consume(Token.Token_Type.SEMICOLON);
        return Stmt.Statement {
            .variable_declaration = Stmt.Variable_Declaration {
                .name = name_token,
                .initializer = initializer,
            },
        };
    }

    fn statement(self: *Self) anyerror!Stmt.Statement {
        if (self.match(&[_]Token.Token_Type{Token.Token_Type.PRINT})) {
            const expr = try self.expression();
            _ = try self.consume(Token.Token_Type.SEMICOLON);

            return Stmt.Statement{
                .print_statement = Stmt.Print_Statement{
                    .expr = expr,
                },
            };
        } else {
            const expr = try self.expression();
            _ = try self.consume(Token.Token_Type.SEMICOLON);
            return Stmt.Statement{
                .expression_statement = Stmt.Expression_Statement{
                    .expr = expr,
                },
            };
        }
    }

    fn print_statement(self: *Self) Stmt.Statement {
        const expr = expression();
        try self.consume(Token.Token_Type.SEMICOLON);
        return expr;
    }

    fn expression(self: *Self) anyerror!*Expr.Expression { return self.equality(); }

    fn equality(self: *Self) anyerror!*Expr.Expression {
        var expr = try self.comparison();
        while(self.match(&[_]Token.Token_Type{.BANG_EQUAL, .EQUAL_EQUAL})) {
            const op = self.previous();
            const right = try self.comparison();
            const binary_expr = try self.alloc.create(Expr.Expression);

            binary_expr.* = Expr.Expression{
                .binary = Expr.Binary_Node {
                    .left = expr,
                    .op = op,
                    .right = right
                 }
            };
            expr = binary_expr;
        }
        return expr;
    }

    fn comparison(self: *Self) anyerror!*Expr.Expression {
        var expr = try self.term();
        while(self.match(&[_]Token.Token_Type{.GREATER, .GREATER_EQUAL, .LESS, .LESS_EQUAL})) {
            const op = self.previous();
            const right = try self.term();
            const binary_expr = try self.alloc.create(Expr.Expression);

            binary_expr.* = Expr.Expression {
                .binary = Expr.Binary_Node {
                    .left = expr,
                    .op = op,
                    .right = right,
                }
            };
            expr = binary_expr;
        }
        return expr;
    }

    fn term(self: *Self) anyerror!*Expr.Expression {
        var expr = try self.factor();
        while(self.match(&[_]Token.Token_Type{.PLUS, .MINUS})) {
            const op = self.previous();
            const right = try self.factor();
            const binary_expr = try self.alloc.create(Expr.Expression);

            binary_expr.* = Expr.Expression {
                .binary = Expr.Binary_Node {
                    .left = expr,
                    .op = op,
                    .right = right,
                }
            };
            expr = binary_expr;
        }
        return expr;
    }

    fn factor(self: *Self) anyerror!*Expr.Expression {
        var expr = try self.unary();
        while(self.match(&[_]Token.Token_Type{.STAR, .SLASH})) {
            const op = self.previous();
            const right = try self.factor();
            const binary_expr = try self.alloc.create(Expr.Expression);

            binary_expr.* = Expr.Expression {
                .binary = Expr.Binary_Node {
                    .left = expr,
                    .op = op,
                    .right = right,
                }
            };
            expr = binary_expr;
        }
        return expr;
    }

    fn unary(self: *Self) anyerror!*Expr.Expression {
        if(self.match(&[_]Token.Token_Type{.BANG, .MINUS})) {
            const op = self.previous();
            const right = try self.unary();
            const unary_expr = try self.alloc.create(Expr.Expression);

            unary_expr.* = Expr.Expression {
                .unary = Expr.Unary_Node {
                    .op = op,
                    .right = right,
                }
            };
            return unary_expr;
        }
        return try self.primary();
    }

    fn primary(self: *Self) anyerror!*Expr.Expression {
        if(self.match(&[_]Token.Token_Type{.NUMBER})) {
            const literal = self.previous().literal;
            const  literal_expr = try self.alloc.create(Expr.Expression);

            literal_expr.* = Expr.Expression {
                .literal = literal
            };
            return literal_expr;
        } else if(self.match(&[_]Token.Token_Type{.STRING})) {
            const literal = self.previous().literal;
            const  literal_expr = try self.alloc.create(Expr.Expression);

            literal_expr.* = Expr.Expression {
                .literal = literal
            };
            return literal_expr;
        } else if(self.match(&[_]Token.Token_Type{.LEFT_PAREN})) {
            const expr = try self.expression();
            _ = try self.consume(Token.Token_Type.RIGHT_PAREN);
            const grouping_expr = try self.alloc.create(Expr.Expression);

            grouping_expr.* = Expr.Expression {
                .group = Expr.Grouping_Node {
                    .expression = expr,
                }
            };
            return grouping_expr;
        }
        return ParserError.Unexpected_Token;
    }

    pub fn is_at_end(self: *Self) bool { return self.tokens.items[self.current].type == Token.Token_Type.EOF; }

    pub fn synchronize(self: *Self) void {
        self.advance();
        while(!self.is_at_end()) {
            if(self.previous().type == Token.Token_Type.SEMICOLON) { return; }
            switch (self.peek().type) {
                .CLASS, .FUN, .FOR, .IF, .PRINT, .RETURN, .VAR, .WHILE => {
                    return;
                },
                else => {
                    break;
                }
            }
            self.advance();
        }
    }
};