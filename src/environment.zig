const std = @import("std");
const Value = @import("value.zig");

pub const Env_Error = error {
    Variable_Not_Defined,
};

pub const Environment = struct {
    map: std.StringHashMap(Value.Value),

    pub fn init(allocator: *std.mem.Allocator) Environment {
        return . {
            .map = std.StringHashMap(Value.Value).init(allocator.*),
        };
    }

    pub fn deinit(self: *Environment) void { self.map.deinit(); }

    pub fn define(self: *Environment, name: []const u8, value: Value.Value) anyerror!void {
        const name_copy = try self.map.allocator.alloc(u8, name.len);
        std.mem.copyForwards(u8, name_copy, name);
        try self.map.put(name_copy, value);
    }

    pub fn assign(self: *Environment, name: []const u8, value: Value.Value) anyerror!void {
        if(self.map.get(name) == null) {
            return Env_Error.Variable_Not_Defined;
        }
        try self.map.put(name, value);
    }

    pub fn get(self: *Environment, name: []const u8) !Value.Value {
        if(self.map.get(name)) |found| {
            return found;
        } else {
            return Env_Error.Variable_Not_Defined;
        }
    }
};