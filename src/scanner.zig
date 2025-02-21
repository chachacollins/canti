const std = @import("std");
const Self = @This();

ch: u8,
pos: usize,
readPos: usize,
line: i32,
source: []const u8,
allocator: std.mem.Allocator,

var scanner: Self = undefined;

var keywords = std.StaticStringMap(TokenType).initComptime(
    .{
        .{ "fn", TokenType.TOKEN_FUN },
        .{ "var", TokenType.TOKEN_VAR },
        .{ "class", TokenType.TOKEN_CLASS },
        .{ "super", TokenType.TOKEN_SUPER },
        .{ "if", TokenType.TOKEN_IF },
        .{ "else", TokenType.TOKEN_ELSE },
        .{ "and", TokenType.TOKEN_AND },
        .{ "while", TokenType.TOKEN_WHILE },
        .{ "or", TokenType.TOKEN_OR },
        .{ "nil", TokenType.TOKEN_NIL },
        .{ "print", TokenType.TOKEN_PRINT },
        .{ "for", TokenType.TOKEN_FOR },
        .{ "true", TokenType.TOKEN_TRUE },
        .{ "false", TokenType.TOKEN_FALSE },
        .{ "return", TokenType.TOKEN_RETURN },
    },
);

pub fn initScanner(source: []const u8, allocator: std.mem.Allocator) void {
    scanner.source = source;
    scanner.pos = 0;
    scanner.readPos = 0;
    scanner.line = 1;
    scanner.allocator = allocator;
}

pub const Token = struct {
    type: TokenType,
    literal: []const u8,
    line: i32,
    fn readChar() void {
        if (scanner.readPos >= scanner.source.len) {
            scanner.ch = '\x00';
        } else {
            scanner.ch = scanner.source[scanner.readPos];
        }
        scanner.pos = scanner.readPos;
        scanner.readPos += 1;
    }
    fn makeToken(type_: TokenType, literal: []const u8) Token {
        const token = Token{
            .type = type_,
            .literal = literal,
            .line = scanner.line,
            //TODO: fix this line stuff
        };
        return token;
    }
    fn isLetter(c: u8) bool {
        if (std.ascii.isAlphabetic(c) or c == '_') {
            return true;
        }
        return false;
    }
    fn readIdent() []const u8 {
        const start = scanner.pos;
        while (isLetter(peekChar())) {
            readChar();
        }
        const end = scanner.readPos;
        return scanner.source[start..end];
    }
    fn getKeyword(literal: []const u8) TokenType {
        return keywords.get(literal) orelse TokenType.TOKEN_IDENTIFIER;
    }

    fn skipWhiteSpace() void {
        while (scanner.ch == ' ' or scanner.ch == '\r' or scanner.ch == '\t' or scanner.ch == '\n') {
            if (scanner.ch == '\n') {
                scanner.line += 1;
            }
            readChar();
        }
    }
    fn peekChar() u8 {
        if (scanner.readPos >= scanner.source.len) {
            return '\x00';
        }
        return scanner.source[scanner.readPos];
    }
    fn dropLine() void {
        while (scanner.ch != '\n' and scanner.ch != '\x00') {
            readChar();
        }
    }
    fn readString() []const u8 {
        const start = scanner.pos;
        while (true) {
            readChar();
            if (scanner.ch == '"' or scanner.ch == '\x00') {
                break;
            }
            if (scanner.ch == '\n') {
                scanner.line += 1;
            }
        }
        return scanner.source[start..scanner.pos];
    }
    fn readNumber() []const u8 {
        const start = scanner.pos;
        while (std.ascii.isDigit(scanner.ch)) {
            readChar();
        }
        if (scanner.ch == '.' and std.ascii.isDigit(peekChar())) {
            readChar();
            while (std.ascii.isDigit(scanner.ch)) {
                readChar();
            }
        }
        const end = scanner.pos;
        return scanner.source[start..end];
    }
    fn errorToken(ch: u8) Token {
        const str = std.fmt.allocPrint(scanner.allocator, "Error could not identify the token {c}", .{ch}) catch unreachable;
        return makeToken(.TOKEN_ERROR, str);
    }
    pub fn scanToken() Token {
        readChar();
        skipWhiteSpace();
        switch (scanner.ch) {
            '+' => return makeToken(.TOKEN_PLUS, "+"),
            '-' => return makeToken(.TOKEN_MINUS, "-"),
            '/' => {
                if (peekChar() == '/') {
                    dropLine();
                    return makeToken(.TOKEN_COMMENT, "comment");
                }
                return makeToken(.TOKEN_SLASH, "/");
            },
            '!' => {
                if (peekChar() == '=') {
                    readChar();
                    return makeToken(.TOKEN_BANG_EQUAL, "!=");
                }
                return makeToken(.TOKEN_BANG, "!");
            },
            '*' => return makeToken(.TOKEN_STAR, "*"),
            '=' => {
                if (peekChar() == '=') {
                    readChar();
                    return makeToken(.TOKEN_EQUAL_EQUAL, "==");
                }
                return makeToken(.TOKEN_EQUAL, "=");
            },
            '>' => {
                if (peekChar() == '=') {
                    readChar();
                    return makeToken(.TOKEN_GREATER_EQUAL, ">=");
                }
                return makeToken(.TOKEN_GREATER, ">");
            },
            '<' => {
                if (peekChar() == '=') {
                    readChar();
                    return makeToken(.TOKEN_LESS_EQUAL, "<=");
                }
                return makeToken(.TOKEN_LESS, "<");
            },
            '{' => return makeToken(.TOKEN_LEFT_BRACE, "{"),
            '}' => return makeToken(.TOKEN_RIGHT_BRACE, "}"),
            '(' => return makeToken(.TOKEN_LEFT_PAREN, "("),
            ')' => return makeToken(.TOKEN_RIGHT_PAREN, ")"),
            ';' => return makeToken(.TOKEN_SEMICOLON, ";"),
            ',' => return makeToken(.TOKEN_COMMA, ","),
            '.' => return makeToken(.TOKEN_DOT, "."),
            '"' => {
                readChar();
                const literal = readString();
                return makeToken(.TOKEN_STRING, literal);
            },
            '\x00' => return makeToken(.TOKEN_EOF, ""),
            else => {
                if (isLetter(scanner.ch)) {
                    const literal = readIdent();
                    const ident = getKeyword(literal);
                    return makeToken(ident, literal);
                }
                if (std.ascii.isDigit(scanner.ch)) {
                    const literal = readNumber();
                    return makeToken(.TOKEN_NUMBER, literal);
                }
                return errorToken(scanner.ch);
            },
        }
    }
};

const TokenType = enum {
    // Single-character tokens.
    TOKEN_LEFT_PAREN,
    TOKEN_RIGHT_PAREN,
    TOKEN_LEFT_BRACE,
    TOKEN_RIGHT_BRACE,
    TOKEN_COMMA,
    TOKEN_DOT,
    TOKEN_MINUS,
    TOKEN_PLUS,
    TOKEN_SEMICOLON,
    TOKEN_SLASH,
    TOKEN_STAR,
    // One or two character tokens.
    TOKEN_BANG,
    TOKEN_BANG_EQUAL,
    TOKEN_EQUAL,
    TOKEN_EQUAL_EQUAL,
    TOKEN_GREATER,
    TOKEN_GREATER_EQUAL,
    TOKEN_LESS,
    TOKEN_LESS_EQUAL,
    TOKEN_COMMENT,
    // Literals.
    TOKEN_IDENTIFIER,
    TOKEN_STRING,
    TOKEN_NUMBER,
    // Keywords.
    TOKEN_AND,
    TOKEN_CLASS,
    TOKEN_ELSE,
    TOKEN_FALSE,
    TOKEN_FOR,
    TOKEN_FUN,
    TOKEN_IF,
    TOKEN_NIL,
    TOKEN_OR,
    TOKEN_PRINT,
    TOKEN_RETURN,
    TOKEN_SUPER,
    TOKEN_THIS,
    TOKEN_TRUE,
    TOKEN_VAR,
    TOKEN_WHILE,

    TOKEN_ERROR,
    TOKEN_EOF,
};
