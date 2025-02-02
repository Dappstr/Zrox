const std = @import("std");
const Token = @import("token.zig");
const Expr = @import("expression.zig");

pub const Statement = union(enum) {
    expression_statement: Expression_Statement,
    print_statement: Print_Statement,

    pub fn deinit(self: *Statement, allocator: *std.mem.Allocator) void {
        switch (self.*) {
            .expression_statement => |*expr_stmt| {
                expr_stmt.deinit(allocator);
            },
            .print_statement => |*print_stmt| {
                print_stmt.expr.deinit(allocator);
            },
        }
    }
};

pub const Expression_Statement = struct {
    expr: *Expr.Expression,
    pub fn deinit(self: *Expression_Statement, allocator: *std.mem.Allocator) void {
        self.expr.deinit(allocator);
    }
};

pub const Print_Statement = struct {
    expr: *Expr.Expression,
    pub fn expression(self: *Print_Statement) *Expr.Expression {
        return self.expr;
    }
};
