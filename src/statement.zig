const std = @import("std");
const Token = @import("token.zig");
const Expression = @import("expression.zig");
//
// const Statement = struct {
//
// };

const Expression_Statement = struct {
    expr: *Expression,

    pub fn expression(self: *Print_Statement) *Expression {
        return self.expr;
    }
};

const Print_Statement = struct {
    expr: *Expression,

    pub fn expression(self: *Print_Statement) *Expression {
        return self.expr;
    }
};