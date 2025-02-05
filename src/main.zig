const std = @import("std");
const Scanner = @import("scanner.zig");
const Token = @import("token.zig");
const Parser = @import("parser.zig");
const Stmt = @import("statement.zig");
const Interpreter = @import("interpreter.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

const Err_Parsing = error{
    General_Error,
};

var had_error: bool = false;

fn report(line: usize, where: []const u8, msg: []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("[line {}] Error {s}: {s}\n", .{ line, where, msg });
    had_error = true;
}

pub fn base_error(line: usize, msg: []const u8) !void {
    try report(line, "", msg);
}

fn run(source: []u8) !void {
    var scanner = Scanner.Scanner.init(allocator, source);
    defer scanner.deinit();

    const tokens = try scanner.scan_tokens();

    var tokens_list = std.ArrayList(Token.Token).init(allocator);
    defer tokens_list.deinit();

    for(tokens) |token| {
        try tokens_list.append(token);
    }

    var parser = Parser.Parser.init(&allocator, tokens_list.items);
    const statements = try parser.parse();

    var interpreter = Interpreter.Interpreter.init(&allocator);
    defer interpreter.deinit();

    _ = try interpreter.interpret_statements(statements);
    for(statements) |*stmt| {
        stmt.deinit(&allocator);
    }
}

fn run_file(path: []const u8) !void {
    const file = try std.fs.openFileAbsolute(path, .{ .mode = .read_only });
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer: []u8 = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);

    const bytes_read = try file.read(buffer);
    _ = bytes_read;
    try run(buffer);
    if (had_error) return Err_Parsing.General_Error;
}

fn run_prompt() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var interpreter = Interpreter.Interpreter.init(&allocator);
    defer interpreter.deinit();

    while (true) {
        try stdout.print("> ", .{});
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const result = stdin.streamUntilDelimiter(buffer.writer(), '\n', null) catch |err| switch (err) {
            error.StreamTooLong => return std.debug.print("Stream too long\n", .{}),
            error.EndOfStream => return,
            else => return err,
        };
        _ = result;
        had_error = false;

        var scanner = Scanner.Scanner.init(allocator, buffer.items);
        defer scanner.deinit();
        const tokens = try scanner.scan_tokens();

        var tokens_list = std.ArrayList(Token.Token).init(allocator);
        defer tokens_list.deinit();
        for(tokens) |token| {
            try tokens_list.append(token);
        }

        var parser = Parser.Parser.init(&allocator, tokens_list.items);
        const line_statements = try parser.parse();

        _ = try interpreter.interpret_statements(line_statements);
    }
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len > 2) {
        try stdout.print("Usage: {s} [path_to_script_file]", .{args[0]});
    } else if (args.len == 2) {
        try run_file(args[1]);
    } else {
        try run_prompt();
    }
}
