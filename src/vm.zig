const std = @import("std");
const Chunk = @import("chunk.zig");
const V = @import("value.zig");
const Self = @This();

const stdout_file = std.io.getStdOut().writer();
var bw = std.io.bufferedWriter(stdout_file);
const stdout = bw.writer();

const InterpretResult = enum {
    INTERPRET_OK,
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
};

chunk: *Chunk,
stream: std.ArrayList(u8),
ip: usize,
allocator: std.mem.Allocator,

var vm: Self = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    vm.allocator = allocator;
}
pub fn deinit() void {}

pub fn interpret(chunk: *Chunk) !InterpretResult {
    vm.chunk = chunk;
    vm.stream = chunk.code;
    vm.ip = 0;
    return run();
}
fn run() !InterpretResult {
    while (true) {
        const instruction = readByte();
        switch (instruction) {
            @intFromEnum(Chunk.Op_Code.OP_CONSTANT) => {
                const constant = readConstant();
                try V.printValue(constant);
                try stdout.print("\n", .{});
                try bw.flush();
                break;
            },
            @intFromEnum(Chunk.Op_Code.OP_RETURN) => {
                return InterpretResult.INTERPRET_OK;
            },
            else => {
                return InterpretResult.INTERPRET_COMPILE_ERROR;
            },
        }
    }
    return InterpretResult.INTERPRET_COMPILE_ERROR;
}
fn readByte() u8 {
    const byte = vm.stream.items[vm.ip];
    vm.ip += 1;
    return byte;
}

fn readConstant() V.Value {
    const const_index = readByte();
    return vm.chunk.constants.values.items[const_index];
}
