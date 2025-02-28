const std = @import("std");
const Self = @This();

input: []const u8,
position: usize,
readPosition: usize,
ch: u8,
line: usize,

pub const Token = struct {
    literal: []const u8,
    type: TokenType,
    line: usize,
};

fn getKeyword(literal: []const u8) TokenType {
    return keywords.get(literal) orelse TokenType.TOKEN_IDENTIFIER;
}

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

pub const TokenType = enum {
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
    TOKEN_FLOAT, // Added float token type
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

pub fn init(input: []const u8) Self {
    var lexer = Self{
        .input = input,
        .position = 0,
        .readPosition = 0,
        .ch = undefined,
        .line = 1,
    };
    lexer.readChar();
    return lexer;
}

fn peekChar(self: *Self) u8 {
    if (self.readPosition >= self.input.len) {
        return 0;
    } else {
        return self.input[self.readPosition];
    }
}

fn readChar(self: *Self) void {
    if (self.readPosition >= self.input.len) {
        self.ch = 0;
    } else {
        self.ch = self.input[self.readPosition];
    }
    self.position = self.readPosition;
    self.readPosition += 1;
}

fn readIdentifier(self: *Self) []const u8 {
    const position = self.position;
    while (isLetter(self.ch)) {
        self.readChar();
    }
    return self.input[position..self.position];
}

fn readString(self: *Self) []const u8 {
    const position = self.position + 1;
    while (true) {
        self.readChar();
        if (self.ch == '"' or self.ch == 0) {
            break;
        }
        if (self.ch == '\\' and self.peekChar() == '"') {
            self.readChar();
        }
        if (self.ch == '\n') {
            self.line += 1;
        }
    }
    const str = self.input[position..self.position];
    if (self.ch != 0) {
        self.readChar();
    }
    return str;
}

fn readNumber(self: *Self) Token {
    const position = self.position;
    while (std.ascii.isDigit(self.ch) or self.ch == '.') {
        if (self.ch == '.') {
            if (!std.ascii.isDigit(self.peekChar())) break;
        }
        self.readChar();
    }

    return Token{
        .type = .TOKEN_NUMBER,
        .literal = self.input[position..self.position],
        .line = self.line,
    };
}

fn isLetter(ch: u8) bool {
    return std.ascii.isAlphabetic(ch) or ch == '_';
}

fn skipWhiteSpace(self: *Self) void {
    while (std.ascii.isWhitespace(self.ch)) {
        if (self.ch == '\n') {
            self.line += 1;
        }
        self.readChar();
    }
}

pub fn nextToken(self: *Self) Token {
    var tok = Token{
        .literal = undefined,
        .type = undefined,
        .line = self.line,
    };

    self.skipWhiteSpace();

    switch (self.ch) {
        '=' => {
            if (self.peekChar() == '=') {
                self.readChar();
                tok.type = .TOKEN_EQUAL_EQUAL;
                tok.literal = "==";
            } else {
                tok.type = .TOKEN_EQUAL;
                tok.literal = "=";
            }
        },
        '"' => {
            tok.type = .TOKEN_STRING;
            tok.literal = self.readString();
        },
        ';' => {
            tok.type = .TOKEN_SEMICOLON;
            tok.literal = ";";
        },
        '(' => {
            tok.type = .TOKEN_LEFT_PAREN;
            tok.literal = "(";
        },
        ')' => {
            tok.type = .TOKEN_RIGHT_PAREN;
            tok.literal = ")";
        },
        ',' => {
            tok.type = .TOKEN_COMMA;
            tok.literal = ",";
        },
        '+' => {
            tok.type = .TOKEN_PLUS;
            tok.literal = "+";
        },
        '{' => {
            tok.type = .TOKEN_LEFT_BRACE;
            tok.literal = "{";
        },
        '}' => {
            tok.type = .TOKEN_RIGHT_BRACE;
            tok.literal = "}";
        },
        '-' => {
            tok.type = .TOKEN_MINUS;
            tok.literal = "-";
        },
        '!' => {
            if (self.peekChar() == '=') {
                self.readChar();
                tok.type = .TOKEN_BANG_EQUAL;
                tok.literal = "!=";
            } else {
                tok.type = .TOKEN_BANG;
                tok.literal = "!";
            }
        },
        '/' => {
            if (self.peekChar() == '/') {
                self.readChar();
                const position = self.position + 1;
                while (self.ch != '\n' and self.ch != 0) {
                    self.readChar();
                }
                tok.type = .TOKEN_COMMENT;
                tok.literal = self.input[position..self.position];
                return tok;
            } else {
                tok.type = .TOKEN_SLASH;
                tok.literal = "/";
            }
        },
        '*' => {
            tok.type = .TOKEN_STAR;
            tok.literal = "*";
        },
        '<' => {
            if (self.peekChar() == '=') {
                self.readChar();
                tok.type = .TOKEN_LESS_EQUAL;
                tok.literal = "<=";
            } else {
                tok.type = .TOKEN_LESS;
                tok.literal = "<";
            }
        },
        '>' => {
            if (self.peekChar() == '=') {
                self.readChar();
                tok.type = .TOKEN_GREATER_EQUAL;
                tok.literal = ">=";
            } else {
                tok.type = .TOKEN_GREATER;
                tok.literal = ">";
            }
        },
        0 => {
            tok.literal = "";
            tok.type = .TOKEN_EOF;
        },
        else => {
            if (isLetter(self.ch)) {
                tok.literal = self.readIdentifier();
                tok.type = getKeyword(tok.literal);
                return tok;
            } else if (std.ascii.isDigit(self.ch)) {
                return self.readNumber();
            } else {
                tok.type = .TOKEN_ERROR;
                tok.literal = &[_]u8{self.ch};
            }
        },
    }
    self.readChar();
    return tok;
}
