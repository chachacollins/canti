const std = @import("std");
const Chunk = @import("chunk.zig");
const V = @import("value.zig");

const stdout_file = std.io.getStdOut().writer();
var bw = std.io.bufferedWriter(stdout_file);
const stdout = bw.writer();

pub fn disassembleChunk(chunk: Chunk, name: []const u8) !void {
    try stdout.print("=={s}== \n", .{name});
    try bw.flush();
    var offset: usize = 0;
    while (offset < chunk.code.items.len) {
        offset = try disassembleInstruction(chunk, offset);
    }
}

pub fn disassembleInstruction(chunk: Chunk, offset: usize) !usize {
    try stdout.print("{d:0>4} ", .{offset});
    if (offset > 0 and chunk.lines.items[offset] == chunk.lines.items[offset - 1]) {
        try stdout.print("    | ", .{});
        try bw.flush();
    } else {
        try stdout.print("{d:0>4} ", .{chunk.lines.items[offset]});
        try bw.flush();
    }

    const instruction = chunk.code.items[offset];
    switch (instruction) {
        @intFromEnum(Chunk.Op_Code.OP_CONSTANT) => {
            return constantInstruction("0P_CONSTANT", chunk, offset);
        },
        @intFromEnum(Chunk.Op_Code.OP_CONSTANT_LONG) => {
            return constantLongInstruction("OP_CONSTANT_LONG", chunk, offset);
        },
        @intFromEnum(Chunk.Op_Code.OP_ADD) => {
            return simpleInstruction("OP_ADD", offset);
        },
        @intFromEnum(Chunk.Op_Code.OP_MULTIPLY) => {
            return simpleInstruction("OP_MULTIPLY", offset);
        },
        @intFromEnum(Chunk.Op_Code.OP_DIVIDE) => {
            return simpleInstruction("OP_DIVIDE", offset);
        },
        @intFromEnum(Chunk.Op_Code.OP_SUBTRACT) => {
            return simpleInstruction("OP_SUBTRACT", offset);
        },
        @intFromEnum(Chunk.Op_Code.OP_NEGATE) => {
            return simpleInstruction("OP_NEGATE", offset);
        },
        @intFromEnum(Chunk.Op_Code.OP_RETURN) => {
            return simpleInstruction("OP_RETURN", offset);
        },
        else => {
            std.debug.print("Unknown Instruction\n", .{});
            return offset + 1;
        },
    }
}

fn constantInstruction(name: []const u8, chunk: Chunk, offset: usize) !usize {
    const constant = chunk.code.items[offset + 1];
    try stdout.print("{s:>4} {d:>4} '", .{ name, constant });
    try V.printValue(chunk.constants.values.items[constant], stdout);
    try stdout.print("'\n", .{});
    try bw.flush();
    return offset + 2;
}
fn constantLongInstruction(name: []const u8, chunk: Chunk, offset: usize) !usize {
    const high_byte: u24 = chunk.code.items[offset + 1];
    const mid_byte: u24 = chunk.code.items[offset + 2];
    const low_byte: u24 = chunk.code.items[offset + 3];

    const constant = (high_byte << 16) | (mid_byte << 8) | low_byte;
    try stdout.print("{s:>4} {d:>4} '", .{ name, constant });
    try V.printValue(chunk.constants.values.items[constant], stdout);
    try stdout.print("'\n", .{});
    try bw.flush();
    return offset + 4;
}

fn simpleInstruction(name: []const u8, offset: usize) !usize {
    try stdout.print("{s}\n", .{name});
    try bw.flush();
    return offset + 1;
}
