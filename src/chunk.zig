const std = @import("std");
const Self = @This();

pub const Op_Code = enum(u8) {
    OP_RETURN,
};

code: std.ArrayList(u8),
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) Self {
    const chunk = Self{ .code = std.ArrayList(u8).init(allocator), .allocator = allocator };
    return chunk;
}
pub fn writeChunk(self: *Self, byte: u8) !void {
    try self.code.append(byte);
}
pub fn deinit(self: *Self) void {
    self.code.deinit();
}
