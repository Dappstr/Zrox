const std = @import("std");

pub const Value = union(enum) {
    Float: f64,
    String: []const u8,
    Bool: bool,
    None: void,

    pub fn deinit(self: *Value, allocator: *std.mem.Allocator) void {
        switch (self.*) {
            .Float => |n| {
                _ = n;
            },
            .String => |slice| {
                allocator.free(slice);
            },
            .Bool => |b| {
                _ = b;
            },
            .None => {}
        }
    }

    pub fn from_slice(allocator: *std.mem.Allocator, contents: []const u8) !Value {
        const new_mem = try allocator.alloc(u8, contents.len);
        std.mem.copyForwards(u8, new_mem[0..contents.len], contents);
        return Value{.String = new_mem};
    }

    pub fn from_f64(f: f64) Value { return Value{.Float = f}; }
    pub fn from_bool(b: bool) Value { return Value{.Bool = b}; }
    pub fn nil() Value { return Value{.None = {} } }
};