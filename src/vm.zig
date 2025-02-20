const std = @import("std");
const Chunk = @import("chunk.zig");
const V = @import("value.zig");
const Debug = @import("debug.zig");
const Compiler = @import("compiler.zig");
const Self = @This();

const stdout_file = std.io.getStdOut().writer();
var bw = std.io.bufferedWriter(stdout_file);
const stdout = bw.writer();

const InterpretResult = enum {
    INTERPRET_OK,
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
};

const STACK_MAX = 65000;

chunk: *Chunk,
stream: std.ArrayList(u8),
ip: usize,
debug: bool,
allocator: std.mem.Allocator,
stack: [STACK_MAX]V.Value,
stack_top: usize,

var vm: Self = undefined;

pub fn init(allocator: std.mem.Allocator, debug: bool) !void {
    vm.allocator = allocator;
    vm.debug = debug;
    vm.stack_top = 0;
}
pub fn deinit() void {}

pub fn interpret(source: []const u8) !InterpretResult {
    try Compiler.compile(source);
    return InterpretResult.INTERPRET_OK;
}
fn run() !InterpretResult {
    while (true) {
        if (vm.debug) {
            try stdout.print("          ", .{});
            if (vm.stack_top == 0) {
                try stdout.print("[ empty ]\n", .{});
            } else {
                for (0..vm.stack_top) |i| {
                    try stdout.print("[ ", .{});
                    try V.printValue(vm.stack[i], stdout);
                    try stdout.print(" ]", .{});
                }
                try stdout.print("\n", .{});
            }
            _ = try Debug.disassembleInstruction(vm.chunk.*, vm.ip);
            try bw.flush();
        }
        const instruction = readByte();
        switch (instruction) {
            @intFromEnum(Chunk.Op_Code.OP_CONSTANT) => {
                const constant = readConstant();
                stackPush(constant);
            },
            @intFromEnum(Chunk.Op_Code.OP_CONSTANT_LONG) => {
                const constant = readLongConstant();
                stackPush(constant);
            },
            @intFromEnum(Chunk.Op_Code.OP_ADD) => {
                binaryOp('+');
            },
            @intFromEnum(Chunk.Op_Code.OP_SUBTRACT) => {
                binaryOp('-');
            },
            @intFromEnum(Chunk.Op_Code.OP_DIVIDE) => {
                binaryOp('/');
            },
            @intFromEnum(Chunk.Op_Code.OP_MULTIPLY) => {
                binaryOp('*');
            },
            @intFromEnum(Chunk.Op_Code.OP_NEGATE) => {
                stackPush(-stackPop());
            },
            @intFromEnum(Chunk.Op_Code.OP_RETURN) => {
                try V.printValue(stackPop(), stdout);
                try stdout.print("\n", .{});
                try bw.flush();
                return InterpretResult.INTERPRET_OK;
            },
            else => {
                return InterpretResult.INTERPRET_COMPILE_ERROR;
            },
        }
    }
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

fn readLongConstant() V.Value {
    const high_index: u24 = readByte();
    const mid_index: u24 = readByte();
    const low_index: u24 = readByte();
    const index = (high_index << 16) | (mid_index << 8) | low_index;
    return vm.chunk.constants.values.items[index];
}

fn stackPush(value: V.Value) void {
    vm.stack[vm.stack_top] = value;
    vm.stack_top += 1;
}
fn stackPop() V.Value {
    vm.stack_top -= 1;
    return vm.stack[vm.stack_top];
}

fn binaryOp(op: u8) void {
    const b = stackPop();
    const a = stackPop();
    switch (op) {
        '-' => stackPush(a - b),
        '+' => stackPush(a + b),
        '/' => stackPush(a / b),
        '*' => stackPush(a * b),
        else => {},
    }
}
