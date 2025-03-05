const std = @import("std");
const Scanner = @import("scanner.zig");
const Chunk = @import("chunk.zig");
const Value = @import("value.zig");
const Debug = @import("debug.zig");

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
    map.set(.TOKEN_LEFT_PAREN, .{ .prefix = grouping });
    map.set(.TOKEN_MINUS, .{ .prefix = unary, .infix = binary, .precedence = .PREC_TERM });
    map.set(.TOKEN_PLUS, .{ .infix = binary, .precedence = .PREC_TERM });
    map.set(.TOKEN_STAR, .{ .infix = binary, .precedence = .PREC_FACTOR });
    map.set(.TOKEN_SLASH, .{ .infix = binary, .precedence = .PREC_FACTOR });
    map.set(.TOKEN_NUMBER, .{ .prefix = number });
    map.set(.TOKEN_FALSE, .{ .prefix = literal });
    map.set(.TOKEN_TRUE, .{ .prefix = literal });
    map.set(.TOKEN_NIL, .{ .prefix = literal });
    map.set(.TOKEN_BANG, .{ .prefix = unary });
    map.set(.TOKEN_BANG_EQUAL, .{ .infix = binary, .precedence = .PREC_EQUALITY });
    map.set(.TOKEN_EQUAL_EQUAL, .{ .infix = binary, .precedence = .PREC_EQUALITY });
    map.set(.TOKEN_GREATER, .{ .infix = binary, .precedence = .PREC_COMPARISON });
    map.set(.TOKEN_GREATER_EQUAL, .{ .infix = binary, .precedence = .PREC_COMPARISON });
    map.set(.TOKEN_LESS_EQUAL, .{ .infix = binary, .precedence = .PREC_COMPARISON });
    map.set(.TOKEN_LESS, .{ .infix = binary, .precedence = .PREC_COMPARISON });

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
    std.debug.print("[line: {d}] Error", .{token.line});
    if (token.type == .TOKEN_EOF) {
        std.debug.print("  at end", .{});
    } else if (token.type == .TOKEN_ERROR) {} else {
        std.debug.print(" at {s}", .{token.literal});
    }
    std.debug.print(": {s}\n", .{message});
    parser.had_error = true;
}

fn advance() void {
    parser.previous = parser.current;

    while (true) {
        parser.current = parser.scanner.nextToken();
        if (parser.current.?.type != .TOKEN_ERROR) break;
        errorAtCurrent(parser.current.?.literal);
    }
}

fn consume(type_: Scanner.TokenType, message: []const u8) void {
    if (parser.current.?.type == type_) {
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
fn endCompiler() !void {
    if (parser.had_error) {
        _ = try Debug.disassembleChunk(compiling_chunk, "chunk");
    }

    emitReturn();
}

fn makeConstant(value: Value.Value) !void {
    try compiling_chunk.writeConstant(value, parser.previous.?.line);
}

fn emitConstant(value: Value.Value) !void {
    try makeConstant(value);
}

fn number() !void {
    const value = std.fmt.parseFloat(f64, parser.previous.?.literal) catch unreachable;
    try emitConstant(Value.number_value(value));
}

fn parsePrecedence(precedence: Precedence) !void {
    advance();
    const prefix_rule = getRule(parser.previous.?.type).prefix;
    if (prefix_rule == null) {
        error_("Expected expression");
        return;
    }

    const prefix = prefix_rule.?;
    try prefix();
    while (@intFromEnum(precedence) < @intFromEnum(getRule(parser.current.?.type).precedence)) {
        advance();
        const infix_rule = getRule(parser.previous.?.type).infix.?;
        try infix_rule();
    }
}

fn expression() !void {
    try parsePrecedence(.PREC_ASSIGNMENT);
}

fn grouping() !void {
    try expression();
    consume(.TOKEN_RIGHT_PAREN, "Expected ')' after the expression.");
}

fn unary() !void {
    const operator_type = parser.previous.?.type;
    try parsePrecedence(.PREC_UNARY);

    switch (operator_type) {
        .TOKEN_MINUS => emitByte(@intFromEnum(Chunk.Op_Code.OP_NEGATE)),
        .TOKEN_BANG => emitByte(@intFromEnum(Chunk.Op_Code.OP_NOT)),
        else => unreachable,
    }
}

fn binary() !void {
    const operator_type = parser.previous.?.type;

    const rule = getRule(operator_type);

    try parsePrecedence(rule.precedence.increment());

    switch (operator_type) {
        .TOKEN_PLUS => emitByte(@intFromEnum(Chunk.Op_Code.OP_ADD)),
        .TOKEN_MINUS => emitByte(@intFromEnum(Chunk.Op_Code.OP_SUBTRACT)),
        .TOKEN_STAR => emitByte(@intFromEnum(Chunk.Op_Code.OP_MULTIPLY)),
        .TOKEN_SLASH => emitByte(@intFromEnum(Chunk.Op_Code.OP_DIVIDE)),
        .TOKEN_BANG_EQUAL => emitBytes(@intFromEnum(Chunk.Op_Code.OP_EQUAL), @intFromEnum(Chunk.Op_Code.OP_NOT)),
        .TOKEN_GREATER => emitByte(@intFromEnum(Chunk.Op_Code.OP_GREATER)),
        .TOKEN_GREATER_EQUAL => emitBytes(@intFromEnum(Chunk.Op_Code.OP_LESS), @intFromEnum(Chunk.Op_Code.OP_NOT)),
        .TOKEN_LESS => emitByte(@intFromEnum(Chunk.Op_Code.OP_LESS)),
        .TOKEN_LESS_EQUAL => emitBytes(@intFromEnum(Chunk.Op_Code.OP_GREATER), @intFromEnum(Chunk.Op_Code.OP_NOT)),
        .TOKEN_EQUAL_EQUAL => emitByte(@intFromEnum(Chunk.Op_Code.OP_EQUAL)),
        else => unreachable,
    }
}

fn literal() !void {
    switch (parser.previous.?.type) {
        .TOKEN_FALSE => emitByte(@intFromEnum(Chunk.Op_Code.OP_FALSE)),
        .TOKEN_TRUE => emitByte(@intFromEnum(Chunk.Op_Code.OP_TRUE)),
        .TOKEN_NIL => emitByte(@intFromEnum(Chunk.Op_Code.OP_NIL)),
        else => unreachable,
    }
}

pub fn compile(source: []const u8, allocator: std.mem.Allocator) !CompilerReturns {
    var comp_ret = CompilerReturns.init(allocator);
    compiling_chunk = comp_ret.chunk;

    parser.had_error = false;
    parser.panic_mode = false;
    parser.scanner = Scanner.init(source);
    advance();

    try expression();

    consume(.TOKEN_EOF, "Expected end of expression");
    try endCompiler();
    comp_ret.success = !parser.had_error;
    comp_ret.chunk = compiling_chunk;
    return comp_ret;
}
