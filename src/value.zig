const std = @import("std");

pub const Value = f64;

pub const ValueArray = struct {
    values: std.ArrayList(Value),
    pub fn init(allocator: std.mem.Allocator) ValueArray {
        return ValueArray{
            .values = std.ArrayList(Value).init(allocator),
        };
    }
    pub fn writeValue(self: *ValueArray, value: Value) !void {
        try self.values.append(value);
    }
    pub fn deinit(self: *ValueArray) void {
        self.values.deinit();
    }
};

pub fn printValue(value: Value) !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("{d}", .{value});
    try bw.flush();
}
