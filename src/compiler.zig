const std = @import("std");
const Scanner = @import("scanner.zig");

const stdout_file = std.io.getStdOut().writer();
var bw = std.io.bufferedWriter(stdout_file);
const stdout = bw.writer();

pub fn compile(source: []const u8, allocator: std.mem.Allocator) !void {
    Scanner.initScanner(source, allocator);
    var line: i32 = -1;

    while (true) {
        const token = Scanner.Token.scanToken();
        if (token.line != line) {
            try stdout.print("{d:>4}", .{token.line});
            try bw.flush();
            line = token.line;
        } else {
            try stdout.print("     | ", .{});
            try bw.flush();
        }
        try stdout.print("{:>2} {s}\n", .{ token.type, token.literal });
        try bw.flush();

        if (token.type == .TOKEN_EOF) break;
    }
}
