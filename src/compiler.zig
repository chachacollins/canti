const std = @import("std");
const Scanner = @import("scanner.zig");
const Chunk = @import("chunk.zig");
const Value = @import("value.zig");

const stdout_file = std.io.getStdOut().writer();
var bw = std.io.bufferedWriter(stdout_file);
const stdout = bw.writer();

const CompilerReturns = struct {
    chunk: Chunk,
    success: bool,
    fn init(allocator: std.mem.Allocator) CompilerReturns {
        const chunk = Chunk.init(allocator);
        const comp_ret = CompilerReturns{
            .chunk = chunk,
            .success = false,
        };
        return comp_ret;
    }
};

const Parser = struct {
    //zls
    previous: ?Scanner.Token,
    current: ?Scanner.Token,
    had_error: bool,
    panic_mode: bool,
    scanner: Scanner,
};

const Precedence = enum {
    PREC_NONE,
    PREC_ASSIGNMENT, // =
    PREC_OR, // or
    PREC_AND, // and
    PREC_EQUALITY, // == !=
    PREC_COMPARISON, // < > <= >=
    PREC_TERM, // + -
    PREC_FACTOR, // * /
    PREC_UNARY, // ! -
    PREC_CALL, // . ()
    PREC_PRIMARY,
    pub fn increment(tag: Precedence) Precedence {
        return @enumFromInt(@intFromEnum(tag) + 1);
    }
};

var parser: Parser = undefined;

var compiling_chunk: Chunk = undefined;

const parseFn = *const fn () anyerror!void;

const ParseRule = struct {
    prefix: ?parseFn = null,
    infix: ?parseFn = null,
    precedence: Precedence = .PREC_NONE,
};

const rules = blk: {
    var map = std.EnumArray(Scanner.TokenType, ParseRule).initFill(.{});
    map.set(.left_paren, .{ .prefix = grouping });
    map.set(.minus, .{ .prefix = unary, .infix = binary, .precedence = .PREC_TERM });
    map.set(.plus, .{ .infix = binary, .precedence = .PREC_TERM });
    map.set(.star, .{ .infix = binary, .precedence = .PREC_FACTOR });
    map.set(.slash, .{ .infix = binary, .precedence = .PREC_FACTOR });
    map.set(.number, ParseRule{ .prefix = number });
    break :blk map;
};

fn getRule(tag: Scanner.TokenType) ParseRule {
    return rules.get(tag);
}

fn errorAtCurrent(message: []const u8) void {
    errorAt(&parser.current.?, message);
}
fn error_(message: []const u8) void {
    errorAt(&parser.previous.?, message);
}

fn errorAt(token: *Scanner.Token, message: []const u8) void {
    if (parser.panic_mode) return;
    parser.panic_mode = true;
    std.debug.print("[lined {d}] Error", .{token.line});
    if (token.tag == .eof) {
        std.debug.print("  at end", .{});
    } else if (token.tag == .@"error") {} else {
        std.debug.print(" at {s}", .{token.raw});
    }
    std.debug.print(": {s}\n", .{message});
    parser.had_error = true;
}

fn advance() void {
    parser.previous = parser.current;

    while (true) {
        parser.current = parser.scanner.next();
        if (parser.current.?.tag != .@"error") break;
        errorAtCurrent(parser.current.?.raw);
    }
}

fn consume(type_: Scanner.TokenType, message: []const u8) void {
    if (parser.current.?.tag == type_) {
        advance();
        return;
    }
    errorAtCurrent(message);
}

fn emitByte(byte: u8) void {
    compiling_chunk.writeChunk(byte, parser.previous.?.line) catch unreachable;
}
fn emitBytes(byte1: u8, byte2: u8) void {
    emitByte(byte1);
    emitByte(byte2);
}

fn emitReturn() void {
    emitByte(@intFromEnum(Chunk.Op_Code.OP_RETURN));
}
fn endCompiler() void {
    emitReturn();
}

fn makeConstant(value: Value.Value) !void {
    try compiling_chunk.writeConstant(value, parser.previous.?.line);
}

fn emitConstant(value: Value.Value) !void {
    try makeConstant(value);
}

fn number() !void {
    const value = std.fmt.parseFloat(Value.Value, parser.previous.?.raw) catch unreachable;
    try emitConstant(value);
}

fn parsePrecedence(precedence: Precedence) !void {
    advance();
    const prefix_rule = getRule(parser.previous.?.tag).prefix;
    if (prefix_rule == null) {
        error_("Expected expression");
        return;
    }

    const prefix = prefix_rule.?;
    try prefix();
    while (@intFromEnum(precedence) < @intFromEnum(getRule(parser.current.?.tag).precedence)) {
        advance();
        const infix_rule = getRule(parser.previous.?.tag).infix.?;
        try infix_rule();
    }
}

fn expression() !void {
    try parsePrecedence(.PREC_ASSIGNMENT);
}

fn grouping() !void {
    try expression();
    consume(.right_paren, "Expected ')' after the expression.");
}

fn unary() !void {
    const operator_type = parser.previous.?.tag;
    try parsePrecedence(.PREC_UNARY);

    switch (operator_type) {
        .minus => emitByte(@intFromEnum(Chunk.Op_Code.OP_NEGATE)),
        else => unreachable,
    }
}

fn binary() !void {
    const operator_type = parser.previous.?.tag;

    const rule = getRule(operator_type);

    try parsePrecedence(rule.precedence.increment());

    switch (operator_type) {
        .plus => emitByte(@intFromEnum(Chunk.Op_Code.OP_ADD)),
        .minus => emitByte(@intFromEnum(Chunk.Op_Code.OP_SUBTRACT)),
        .star => emitByte(@intFromEnum(Chunk.Op_Code.OP_MULTIPLY)),
        .slash => emitByte(@intFromEnum(Chunk.Op_Code.OP_DIVIDE)),
        else => unreachable,
    }
}

pub fn compile(source: []const u8, allocator: std.mem.Allocator) !CompilerReturns {
    var comp_ret = CompilerReturns.init(allocator);
    const scanner = Scanner{
        .source = source,
    };
    parser.scanner = scanner;

    compiling_chunk = comp_ret.chunk;

    parser.had_error = false;
    parser.panic_mode = false;
    advance();

    try expression();

    consume(.eof, "Expected end of expression");
    endCompiler();
    comp_ret.success = !parser.had_error;
    comp_ret.chunk = compiling_chunk;
    return comp_ret;
}
