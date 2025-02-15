const std = @import("std");
const Chunk = @import("chunk.zig");
const debug = @import("debug.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const v = gpa.deinit();
        if (v == .leak) {
            std.debug.print("Memory leak detected\n", .{});
        }
    }
    var chunk = Chunk.init(allocator);
    defer chunk.deinit();
    try chunk.writeConstant(1.2, 123);

    try chunk.writeChunk(@intFromEnum(Chunk.Op_Code.OP_RETURN), 124);
    try debug.disassembleChunk(chunk, "Test Chunk");
}
