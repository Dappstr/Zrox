const std = @import("std");
const Token = @import("token.zig");
const Expression = @import("expression.zig");

pub const Statement = union(enum) {
    expression_statement: Expression_Statement,
    Print_Statement: Print_Statement,

    pub fn deinit(self: *Statement, allocator: *std.mem.Allocator) void {
        switch (self.*) {
            .expression_statement => |expr_stmt| {
                expr_stmt.deinit(allocator);
                allocator.destroy(expr_stmt);
            },
            .print_statement => |print_stmt| {
                print_stmt.expr.deinit(allocator);
                allocator.destroy(print_stmt);
            }
        }
        allocator.destroy(self);
    }
};

pub const Expression_Statement = struct {
    expr: *Expression,

    pub fn expression(self: *Print_Statement) *Expression {
        return self.expr;
    }
};

pub const Print_Statement = struct {
    expr: *Expression,

    pub fn expression(self: *Print_Statement) *Expression {
        return self.expr;
    }
};