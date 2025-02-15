const std = @import("std");
const Chunk = @import("chunk.zig");
const debug = @import("debug.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();
    var chunk = Chunk.init(allocator);
    defer chunk.deinit();
    try chunk.writeConstant(1.2, 123);

    try chunk.writeChunk(@intFromEnum(Chunk.Op_Code.OP_RETURN), 124);
    try debug.disassembleChunk(chunk, "Test Chunk");
}

// pub fn print(format: u8) !void{
//     const stdout_file = std.io.getStdOut().writer();
//     var bw = std.io.bufferedWriter(stdout_file);
//     const stdout = bw.writer();
//
//     try stdout.print("Hello world\n", .{});
//
//     try bw.flush(); // don't forget to flush!
// }
