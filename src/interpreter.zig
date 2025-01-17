const std = @import("std");
const Token = @import("token.zig");
const Expr = @import("expression.zig");
const Value = @import("value.zig");

pub const Interpreter = struct {
    root_ast: ?*Expr.Expression = null,
    allocator: ?*std.mem.Alllocator = null,

    pub fn init(root: *Expr.Expression, alloc: *std.mem.Allocator) Interpreter {
        return .{
            .root_ast = root,
            .allocator = alloc,
        };
    }

    pub fn deinit(interpreter: *Interpreter) void {
        if(interpreter.root_ast) |ast_ptr| {
            ast_ptr.deinit(interpreter.allocator.?);
            interpreter.root_ast = null;
        }
    }
};