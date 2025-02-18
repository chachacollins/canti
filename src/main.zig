const std = @import("std");
const Chunk = @import("chunk.zig");
const vm = @import("vm.zig");
const debug = @import("debug.zig");

const stdout_file = std.io.getStdOut().writer();
var bw = std.io.bufferedWriter(stdout_file);
const stdout = bw.writer();

const stdin_file = std.io.getStdIn();
var reader = std.io.bufferedReader(stdin_file.reader());
const stdin = reader.reader();

fn repl(allocator: std.mem.Allocator) !void {
    while (true) {
        try stdout.print(">>  ", .{});
        try bw.flush();
        const line = try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', 1024);
        std.debug.print("{s}\n", .{line.?});
    }
}
fn runFile(file: []const u8) void {
    _ = file;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const v = gpa.deinit();
        if (v == .leak) {
            std.debug.print("Memory leak detected\n", .{});
        }
    }
    try vm.init(allocator, true);
    defer vm.deinit();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len == 1) {
        try repl(allocator);
    } else if (args.len == 2) {
        runFile(args[1]);
    } else {
        std.debug.print("Usage: canti [path]\n", .{});
        std.process.exit(69);
    }
}
