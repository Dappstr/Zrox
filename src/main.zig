const std = @import("std");
const Scanner = @import("scanner.zig");
const Token = @import("token.zig");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

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
    const stdout = std.io.getStdOut().writer();

    var scanner = Scanner.Scanner.init(allocator, source);
    defer scanner.deinit();

    const tokens = try scanner.scan_tokens();
    //defer tokens.deinit();
    //const token_slice = try tokens.toOwnedSlice();

    for (tokens) |token| {
        const token_str = try token.to_string(allocator);
        defer allocator.free(token_str);
        try stdout.print("{s}\n", .{token_str});
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

    while (true) {
        try stdout.print("> ", .{});
        var buffer: [1024]u8 = undefined;

        const result = try stdin.readUntilDelimiter(&buffer, '\n');
        try run(result);
        had_error = false;
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
