const std = @import("std");
const V = @import("value.zig");
const Self = @This();

pub const Op_Code = enum(u8) {
    OP_CONSTANT,
    OP_RETURN,
};

code: std.ArrayList(u8),
constants: V.ValueArray,
lines: std.ArrayList(i32),
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) Self {
    const chunk = Self{
        //xls
        .code = std.ArrayList(u8).init(allocator),
        .constants = V.ValueArray.init(allocator),
        .lines = std.ArrayList(i32).init(allocator),
        .allocator = allocator,
    };
    return chunk;
}
pub fn addConstant(self: *Self, value: V.Value) !usize {
    try self.constants.writeValue(value);
    return self.constants.values.items.len - 1;
}
pub fn writeChunk(self: *Self, byte: u8, line: i32) !void {
    try self.lines.append(line);
    try self.code.append(byte);
}
pub fn deinit(self: *Self) void {
    self.lines.deinit();
    self.constants.deinit();
    self.code.deinit();
}
