const std = @import("std");
const Token = @import("token.zig");
const Expr = @import("expression.zig");
const Value = @import("value.zig");
const Stmt = @import("statement.zig");
const Environment = @import("environment.zig");

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
        Undefined_Variable,
    };

    environment: Environment.Environment,
    //statements: std.ArrayList(Stmt.Statement),
    allocator: ?*std.mem.Allocator = null,

    pub fn init(alloc: *std.mem.Allocator) Interpreter {
    const env = Environment.Environment.init(alloc);

    return .{
            .environment = env,
            .allocator = alloc,
        };
    }

    // pub fn deinit(interpreter: *Interpreter) void {
    //     for(interpreter.statements.items) |*stmt| {
    //         stmt.deinit(interpreter.allocator.?);
    //     }
    //     interpreter.environment.deinit();
    // }
    //
    pub fn deinit(interpreter: *Interpreter) void { interpreter.environment.deinit(); }

    // pub fn interpret(interpreter: *Interpreter) !Value.Value {
    //     if (interpreter.statements.capacity == 0) {
    //         return Error.Uninitialized_AST;
    //     } else {
    //         var last_value: ?Value.Value = null;
    //
    //         for (interpreter.statements.items) |stmt| {
    //             last_value = (try eval_statement(interpreter, &stmt));
    //         }
    //         if (last_value) |value| {
    //             return value;
    //         } else {
    //             return Value.Value.nil();
    //         }
    //     }
    // }

    pub fn interpret_statements(interpreter: *Interpreter, statements: []const Stmt.Statement) !Value.Value {
        var last_val: ?Value.Value = null;
        for(statements) |stmt| {
            last_val = try eval_statement(interpreter, &stmt);
        }
        return last_val orelse Value.Value.nil();
    }

    fn eval_statement(interpreter: *Interpreter, stmt: *const Stmt.Statement) !Value.Value {
        switch (stmt.*) {
            .expression_statement => |expr| {
                return try eval_expression(interpreter, expr.expr);
            },
            .print_statement => |prnt| {
                const val = try eval_expression(interpreter, prnt.expr);
                switch (val) {
                    .Float => std.debug.print("{d}\n", .{val.Float}),
                    .String => std.debug.print("{s}\n", .{val.String}),
                    .Bool => std.debug.print("{s}\n", .{if (val.Bool) "true" else "false"}),
                    .None => std.debug.print("null\n", .{}),
                }
                return val;
            },
            .variable_declaration => |var_decl| {
                // std.debug.print("FOUND VAR DECL FOR: {s}\n", .{var_decl.name.lexeme});
                // return Value.Value.nil();
                var value = Value.Value.nil();
                if(var_decl.initializer) |init_expr| {
                    value = try eval_expression(interpreter, init_expr);
                }

                try interpreter.environment.define(var_decl.name.lexeme, value);
                return Value.Value.nil();
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
                return eval_binary(interpreter,binary.op, left, right);
            },
            .group => |group| {
                return eval_expression(interpreter, group.expression);
            },
            .variable => |var_node| {
                return interpreter.environment.get(var_node.name.lexeme)
                    catch |err| switch (err) {
                        Environment.Env_Error.Variable_Not_Defined => {
                            return Interpreter.Error.Undefined_Variable;
                        },
                        else => return err,
                    };
            },
            .assign => |a| {
                const rhs_value = try eval_expression(interpreter, a.value);
                try interpreter.environment.assign(a.name.lexeme, rhs_value);
                return rhs_value;
            },
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

    fn eval_binary(interpreter: *Interpreter, op: Token.Token, left: Value.Value, right: Value.Value) !Value.Value {
        switch (op.type) {
            .PLUS => switch (left) {
                .Float => switch (right) {
                    .Float => return Value.Value.from_f64(left.Float + right.Float),
                    else => return Error.Invalid_Binary_Operation,
                },
                .String => switch (left) {
                    .String => switch (right) {
                        .String =>  {
                            const allocator = interpreter.allocator orelse return Error.Allocation_Failed;
                            const combined_len = left.String.len + right.String.len;
                            const new_str = try allocator.alloc(u8, combined_len);
                            std.mem.copyForwards(u8, new_str[0..left.String.len], left.String);
                            std.mem.copyForwards(u8, new_str[left.String.len..], right.String);

                            return Value.Value { .String = new_str };
                        },
                        else => return Error.Invalid_Binary_Operation,
                    },
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
                .String => switch (right) {
                    .Float => {
                        if (right.Float < 1 or @mod(right.Float, 1.0) != 0) {
                            return Error.Invalid_Binary_Operation;
                        }

                        const repeat_count = @as(usize, @intFromFloat(right.Float));
                        const allocator = interpreter.allocator orelse return Error.Allocation_Failed;
                        const total_len = left.String.len * repeat_count;
                        const new_mem = try allocator.alloc(u8, total_len);

                        var i: usize = 0;
                        while (i < repeat_count) : (i += 1) {
                            std.mem.copyForwards(u8, new_mem[i * left.String.len .. (i + 1) * left.String.len], left.String);
                        }

                        return Value.Value{ .String = new_mem };
                    },
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