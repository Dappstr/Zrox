const std = @import("std");
const Token = @import("token.zig");

pub const Unary_Node = struct {
    op: Token.Token,
    right: *Expression,
};

pub const Binary_Node = struct {
    left: *Expression,
    op: Token.Token,
    right: *Expression,
};

pub const Grouping_Node = struct {
    expression: *Expression,
};

pub const Expression = union(enum) {
    literal: Token.Literal,
    unary: Unary_Node,
    binary: Binary_Node,
    group: Grouping_Node,

    pub fn deinit(self: *Expression, allocator: *std.mem.Allocator) void {
        switch (self.*) {
            .literal => |lit| {
                _ = lit;
            },
            .Unary => |u| {
                u.right.deinit(allocator);
            },
            .Binary => |b| {
                b.left.deinit(allocator);
                b.right.deinit(allocator);
            },
            .group => |g| {
                g.expression.deinit(allocator);
            },
        }
        allocator.destroy(self);
    }
};