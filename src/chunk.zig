const std = @import("std");
const V = @import("value.zig");
const Self = @This();

pub const Op_Code = enum(u8) {
    OP_CONSTANT,
    OP_CONSTANT_LONG,
    OP_ADD,
    OP_SUBTRACT,
    OP_MULTIPLY,
    OP_DIVIDE,
    OP_NEGATE,
    OP_RETURN,
};

code: std.ArrayList(u8),
constants: V.ValueArray,
lines: std.ArrayList(usize),
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) Self {
    const chunk = Self{
        //xls
        .code = std.ArrayList(u8).init(allocator),
        .constants = V.ValueArray.init(allocator),
        .lines = std.ArrayList(usize).init(allocator),
        .allocator = allocator,
    };
    return chunk;
}
pub fn addConstant(self: *Self, value: V.Value) !usize {
    try self.constants.writeValue(value);
    return self.constants.values.items.len - 1;
}
pub fn writeChunk(self: *Self, byte: u8, line: usize) !void {
    try self.lines.append(line);
    try self.code.append(byte);
}
pub fn writeConstant(self: *Self, value: V.Value, line: usize) !void {
    const constant = try self.addConstant(value);
    if (constant <= 255) {
        try self.writeChunk(@intFromEnum(Op_Code.OP_CONSTANT), line);
        try self.writeChunk(@intCast(constant), line);
    } else {
        const largest = 0;
        std.debug.assert(constant <= ~largest);
        const high_byte = constant >> 16 & 0xFF;
        const mid_byte = constant >> 8 & 0xFF;
        const low_byte = constant & 0xFF;
        try self.writeChunk(@intFromEnum(Op_Code.OP_CONSTANT_LONG), line);
        try self.writeChunk(@intCast(high_byte), line);
        try self.writeChunk(@intCast(mid_byte), line);
        try self.writeChunk(@intCast(low_byte), line);
    }
}
pub fn deinit(self: *Self) void {
    self.lines.deinit();
    self.constants.deinit();
    self.code.deinit();
}
