const std = @import("std");
const Chunk = @import("chunk.zig");

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

fn disassembleInstruction(chunk: Chunk, offset: usize) !usize {
    try stdout.print("{d:0>4} ", .{offset});
    try bw.flush();

    const instruction = chunk.code.items[offset];
    switch (instruction) {
        @intFromEnum(Chunk.Op_Code.OP_RETURN) => {
            return simpleInstruction("OP_RETURN", offset);
        },
        else => {
            std.debug.print("Unknown Instruction\n", .{});
            return offset + 1;
        },
    }
}

fn simpleInstruction(name: []const u8, offset: usize) !usize {
    try stdout.print("{s}\n", .{name});
    try bw.flush();
    return offset + 1;
}
