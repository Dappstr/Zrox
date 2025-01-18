const std = @import("std");
const Token = @import("token.zig");
const Expr = @import("expression.zig");
const Value = @import("value.zig");
const Stmt = @import("statement.zig");

pub const Interpreter = struct {
    pub const Error = error{
        Invalid_Operation,
        Unsupported_Unary_Operator,
        Unsupported_Binary_Operator,
        Invalid_Unary_Operation,
        Invalid_Binary_Operation,
        Invalid_Comparison,
        Division_By_Zero,
        Uninitialized_AST,
        Allocation_Failed,
        Out_Of_Memory,
    };

    statements: std.ArrayList(Stmt.Statement),
    allocator: ?*std.mem.Allocator = null,

    pub fn init(statements: std.ArrayList(Stmt.Statement), alloc: *std.mem.Allocator) Interpreter {
        return .{
            .statements = statements,
            .allocator = alloc,
        };
    }

    pub fn deinit(interpreter: *Interpreter) void {
        for(interpreter.statements.items) |*stmt| {
            stmt.deinit(interpreter.allocator.?);
        }
    }

    pub fn interpret(interpreter: *Interpreter) !Value.Value {
        if (interpreter.statements.capacity < 1) {
            return Error.Uninitialized_AST;
        } else {
            var last_value: ?Value.Value = null;

            for (interpreter.statements.items) |stmt| {
                last_value = (try eval_statement(interpreter, &stmt));
            }
            if (last_value) |value| {
                return value;
            } else {
                return Value.Value.nil();
            }
        }
    }

    fn eval_statement(interpreter: *Interpreter, stmt: *const Stmt.Statement) !Value.Value {
        switch (stmt.*) {
            .expression_statement => |expr| {
            return try eval_expression(interpreter, expr.expr);
            },
            .print_statement => |prnt| {
            const val = try eval_expression(interpreter, prnt.expr);
                std.debug.print("{d}\n", .{val.Float});
                return val;
            }
        }
    }

    fn eval_expression(interpreter: *Interpreter, expr: *Expr.Expression) !Value.Value {
        switch (expr.*) {
            .literal => |lit| {
                return eval_literal(interpreter, lit);
            },
            .unary => |unary| {
                const right = try eval_expression(interpreter, unary.right);
                return eval_unary(unary.op, right);
            },
            .binary => |binary| {
                const left = try eval_expression(interpreter, binary.left);
                const right = try eval_expression(interpreter, binary.right);
                return eval_binary(binary.op, left, right);
            },
            .group => |group| {
                return eval_expression(interpreter, group.expression);
            }
        }
    }

    fn eval_unary(op: Token.Token, right: Value.Value) !Value.Value {
        switch (op.type) {
            .MINUS => switch (right) {
                .Float => return Value.Value.from_f64(-right.Float),
                else => return Error.Invalid_Unary_Operation, // Only Float is valid with MINUS
            },
            .BANG => switch (right) {
                .Bool => return Value.Value.from_bool(!right.Bool),
                else => return Error.Invalid_Unary_Operation, // Only Bool is valid with BANG
            },
            else => return Error.Unsupported_Unary_Operator,
        }
    }

    fn eval_binary(op: Token.Token, left: Value.Value, right: Value.Value) !Value.Value {
        switch (op.type) {
            .PLUS => switch (left) {
                .Float => switch (right) {
                    .Float => return Value.Value.from_f64(left.Float + right.Float),
                    else => return Error.Invalid_Binary_Operation,
                },
                else => return Error.Invalid_Binary_Operation,
            },
            .MINUS => switch (left) {
                .Float => switch (right) {
                    .Float => return Value.Value.from_f64(left.Float - right.Float),
                    else => return Error.Invalid_Binary_Operation,
                },
                else => return Error.Invalid_Binary_Operation,
            },
            .STAR => switch (left) {
                .Float => switch (right) {
                    .Float => return Value.Value.from_f64(left.Float * right.Float),
                    else => return Error.Invalid_Binary_Operation,
                },
                else => return Error.Invalid_Binary_Operation,
            },
            .SLASH => switch (left) {
                .Float => switch (right) {
                    .Float => {
                        if (right.Float == 0.0) {
                            return Error.Division_By_Zero;
                        } else {
                            return Value.Value.from_f64(left.Float / right.Float);
                        }
                    },
                    else => return Error.Invalid_Binary_Operation,
                },
                else => return Error.Invalid_Binary_Operation,
            },
            .EQUAL_EQUAL => switch (left) {
                .Float => switch (right) {
                    .Float => return Value.Value.from_bool(left.Float == right.Float),
                    else => return Error.Invalid_Comparison,
                },
                .Bool => switch (right) {
                    .Bool => return Value.Value.from_bool(left.Bool == right.Bool),
                    else => return Error.Invalid_Comparison,
                },
                .String => switch (right) {
                    .String => return Value.Value.from_bool(std.mem.eql(u8, left.String, right.String)),
                    else => return Error.Invalid_Comparison,
                },
                else => return Error.Invalid_Comparison,
            },
            .BANG_EQUAL => switch (left) {
                .Float => switch (right) {
                    .Float => return Value.Value.from_bool(left.Float != right.Float),
                    else => return Error.Invalid_Comparison,
                },
                .Bool => switch (right) {
                    .Bool => return Value.Value.from_bool(left.Bool != right.Bool),
                    else => return Error.Invalid_Comparison,
                },
                .String => switch (right) {
                    .String => return Value.Value.from_bool(!std.mem.eql(u8, left.String, right.String)),
                    else => return Error.Invalid_Comparison,
                },
                else => return Error.Invalid_Comparison,
            },
            .GREATER => switch (left) {
                .Float => switch (right) {
                    .Float => return Value.Value.from_bool(left.Float > right.Float),
                    else => return Error.Invalid_Comparison,
                },
                else => return Error.Invalid_Comparison,
            },
            .GREATER_EQUAL => switch (left) {
                .Float => switch (right) {
                    .Float => return Value.Value.from_bool(left.Float >= right.Float),
                    else => return Error.Invalid_Comparison,
                },
                else => return Error.Invalid_Comparison,
            },
            .LESS => switch (left) {
                .Float => switch (right) {
                    .Float => return Value.Value.from_bool(left.Float < right.Float),
                    else => return Error.Invalid_Comparison,
                },
                else => return Error.Invalid_Comparison,
            },
            .LESS_EQUAL => switch (left) {
                .Float => switch (right) {
                    .Float => return Value.Value.from_bool(left.Float <= right.Float),
                    else => return Error.Invalid_Comparison,
                },
                else => return Error.Invalid_Comparison,
            },
            else => return Error.Unsupported_Binary_Operator,
        }
    }

    fn eval_literal(interpreter: *Interpreter, lit: Token.Literal) !Value.Value {
        switch (lit) {
            .Float => |f| return Value.Value.from_f64(f),
            .String => |str| return Value.Value.from_slice(interpreter.allocator.?, str),
            .Bool => |b| return Value.Value.from_bool(b),
            .None => return Value.Value.nil(),
        }
    }
};