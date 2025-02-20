const Self = @This();

ch: u8,
pos: usize,
readPos: usize,
line: i32,
source: []const u8,

var scanner: Self = undefined;

pub fn initScanner(source: []const u8) void {
    scanner.source = source;
    scanner.pos = 0;
    scanner.readPos = 0;
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
        };
        return token;
    }
    fn skipWhiteSpace() void {
        while (scanner.ch == ' ' or scanner.ch == '\r' or scanner.ch == '\t') {
            readChar();
        }
    }
    pub fn scanToken() Token {
        readChar();
        switch (scanner.ch) {
            '+' => return makeToken(.TOKEN_PLUS, "+"),
            '-' => return makeToken(.TOKEN_MINUS, "-"),
            '/' => return makeToken(.TOKEN_SLASH, "/"),
            '{' => return makeToken(.TOKEN_LEFT_BRACE, "{"),
            '}' => return makeToken(.TOKEN_RIGHT_BRACE, "}"),
            '\x00' => return makeToken(.TOKEN_EOF, ""),
            else => {
                return makeToken(.TOKEN_ERROR, "");
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
