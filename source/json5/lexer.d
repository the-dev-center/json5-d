module json5.lexer;

import std.array;
import std.ascii : isDigit, isAlpha, isAlphaNum, isHexDigit;
import std.uni : isWhite;
import std.utf;
import std.string;
import std.exception;
import std.conv;
import std.algorithm : canFind;

enum TokenType
{
    EOF,
    ObjectStart, // {
    ObjectEnd,   // }
    ArrayStart,  // [
    ArrayEnd,    // ]
    Comma,       // ,
    Colon,       // :
    String,      // "foo", 'bar'
    Number,      // 123, 0x1A, +Infinity, .5, 1.e5
    Boolean,     // true, false
    Null,        // null
    Identifier   // key (unquoted)
}

struct Token
{
    TokenType type;
    string value;
    size_t line;
    size_t column;
    size_t offset;
    
    string toString() const {
        return format("Token(%s, '%s', line:%d, col:%d)", type, value, line, column);
    }
}

class LexerException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

struct Lexer
{
    private string source;
    private size_t index;
    private size_t line = 1;
    private size_t lineStart = 0;

    this(string source)
    {
        this.source = source;
        this.index = 0;
    }

    private char peek(size_t offset = 0)
    {
        if (index + offset >= source.length) return '\0';
        return source[index + offset];
    }

    private char advance()
    {
        if (index >= source.length) return '\0';
        char c = source[index++];
        if (c == '\n')
        {
            line++;
            lineStart = index;
        }
        return c;
    }

    private void skipWhitespaceAndComments()
    {
        while (index < source.length)
        {
            char c = peek();
            if (isWhite(c))
            {
                advance();
            }
            else if (c == '/')
            {
                char next = peek(1);
                if (next == '/')
                {
                    // Single line comment
                    advance(); advance(); // //
                    while (index < source.length && !isLineTerminator(peek()))
                    {
                        advance();
                    }
                }
                else if (next == '*')
                {
                    // Multi line comment
                    advance(); advance(); // /*
                    while (index < source.length)
                    {
                        if (peek() == '*' && peek(1) == '/')
                        {
                            advance(); advance(); // */
                            break;
                        }
                        advance();
                    }
                }
                else
                {
                    // Just a slash, not a comment start.
                    // This might be invalid in JSON5 context unless inside string/regex?
                    // But Lexer should just return what it sees or error if invalid char.
                    // "/" is not a valid JSON5 token on its own.
                    break; 
                }
            }
            else
            {
                break;
            }
        }
    }

    private bool isLineTerminator(char c)
    {
        return c == '\n' || c == '\r' || c == '\u2028' || c == '\u2029';
    }

    Token nextToken()
    {
        skipWhitespaceAndComments();

        if (index >= source.length)
        {
            return Token(TokenType.EOF, null, line, index - lineStart, index);
        }

        size_t startLine = line;
        size_t startCol = index - lineStart + 1; // 1-based column
        size_t startOffset = index;

        char c = peek();

        // Punctuation
        if (c == '{') { advance(); return Token(TokenType.ObjectStart, "{", startLine, startCol, startOffset); }
        if (c == '}') { advance(); return Token(TokenType.ObjectEnd, "}", startLine, startCol, startOffset); }
        if (c == '[') { advance(); return Token(TokenType.ArrayStart, "[", startLine, startCol, startOffset); }
        if (c == ']') { advance(); return Token(TokenType.ArrayEnd, "]", startLine, startCol, startOffset); }
        if (c == ',') { advance(); return Token(TokenType.Comma, ",", startLine, startCol, startOffset); }
        if (c == ':') { advance(); return Token(TokenType.Colon, ":", startLine, startCol, startOffset); }
        
        // String
        if (c == '"' || c == '\'')
        {
            return readString(startLine, startCol, startOffset);
        }

        // Identifier or Boolean/Null or Infinity/NaN
        // Identifiers start with $, _, or letter.
        // Numbers start with +, -, ., or digit.
        
        bool isNumberStart = isDigit(c) || c == '.' || c == '+' || c == '-';
        
        // Special case: `Infinity` and `NaN` are numbers but start with letters.
        // We handle them in readNumber or readIdentifier?
        // JSON5 Spec:
        // Number includes "Infinity", "-Infinity", "+Infinity", "NaN", "-NaN", "+NaN".
        // If it starts with +, -, ., digit -> readNumber.
        // If it starts with 'I' or 'N', check if it's Infinity or NaN.
        
        if (isNumberStart)
        {
            return readNumber(startLine, startCol, startOffset);
        }
        
        if (c == 'I') { // Potential Infinity
             if (peekMatch("Infinity")) return readNumber(startLine, startCol, startOffset);
        }
        if (c == 'N') { // Potential NaN
             if (peekMatch("NaN")) return readNumber(startLine, startCol, startOffset);
        }

        // Identifiers
        if (isIdentifierStart(c))
        {
             return readIdentifier(startLine, startCol, startOffset);
        }

        throw new LexerException(format("Unexpected character '%s' at line %d col %d", c, line, index - lineStart));
    }

    private bool peekMatch(string target)
    {
        if (index + target.length > source.length) return false;
        return source[index .. index + target.length] == target;
    }

    private Token readString(size_t l, size_t c, size_t off)
    {
        char quote = advance(); // " or '
        string buffer; // TODO: Optimization, use Appender
        
        while (index < source.length)
        {
            char ch = peek();
            if (ch == quote)
            {
                advance();
                return Token(TokenType.String, buffer, l, c, off);
            }
            if (ch == '\\')
            {
                advance();
                if (index >= source.length) throw new LexerException("Unexpected EOF in string escape");
                char esc = advance();
                
                if (isLineTerminator(esc)) {
                    // Line continuation
                    // TODO: Handle CR LF correctly if split across?
                } else {
                    switch(esc) {
                        case '"': buffer ~= '"'; break;
                        case '\'': buffer ~= '\''; break;
                        case '\\': buffer ~= '\\'; break;
                        case '/': buffer ~= '/'; break;
                        case 'b': buffer ~= '\b'; break;
                        case 'f': buffer ~= '\f'; break;
                        case 'n': buffer ~= '\n'; break;
                        case 'r': buffer ~= '\r'; break;
                        case 't': buffer ~= '\t'; break;
                        case 'v': buffer ~= '\v'; break;
                        case '0': buffer ~= '\0'; break; // Null char
                        case 'x':
                             // Hex escape \xHH
                             string hex = "" ~ advance() ~ advance();
                             // check if hex digits?
                             try {
                                 buffer ~= cast(char)parse!int(hex, 16);
                             } catch(Exception e) {
                                 throw new LexerException("Invalid hex escape sequence");
                             }
                             break;
                        case 'u':
                             // Unicode escape \uHHHH
                             string hex = "" ~ advance() ~ advance() ~ advance() ~ advance();
                             try {
                                 buffer ~= cast(dchar)parse!int(hex, 16);
                             } catch (Exception e) {
                                 throw new LexerException("Invalid unicode escape sequence");
                             }
                             break;
                        default:
                            // JSON5 allows escaping any char? "non-escape characters ... are ignored"
                            buffer ~= esc; 
                            break;
                    }
                }
            }
            else if (isLineTerminator(ch))
            {
                throw new LexerException("Unescaped newline in string literal");
            }
            else
            {
                buffer ~= advance();
            }
        }
        throw new LexerException("Unterminated string literal");
    }

    private Token readNumber(size_t l, size_t c, size_t off)
    {
        size_t start = index;
        
        // Optional Sign
        if (peek() == '+' || peek() == '-') advance();
        
        // Check for Infinity / NaN (after optional sign)
        if (peek() == 'I')
        {
             string inf = "Infinity";
             for(size_t i=0; i<inf.length; ++i) {
                 if (advance() != inf[i]) throw new LexerException("Invalid number literal, expected Infinity");
             }
             return Token(TokenType.Number, source[start .. index], l, c, off);
        }
        if (peek() == 'N')
        {
             string nan = "NaN";
             for(size_t i=0; i<nan.length; ++i) {
                 if (advance() != nan[i]) throw new LexerException("Invalid number literal, expected NaN");
             }
             return Token(TokenType.Number, source[start .. index], l, c, off);
        }

        // Hex
        if (peek() == '0' && (peek(1) == 'x' || peek(1) == 'X'))
        {
            advance(); advance();
            while (isHexDigit(peek())) advance();
            return Token(TokenType.Number, source[start .. index], l, c, off);
        }

        // Decimal
        while (isDigit(peek())) advance();
        
        if (peek() == '.')
        {
            advance();
            while (isDigit(peek())) advance();
        }

        if (peek() == 'e' || peek() == 'E')
        {
            advance();
            if (peek() == '+' || peek() == '-') advance();
            while (isDigit(peek())) advance();
        }
        
        return Token(TokenType.Number, source[start .. index], l, c, off);
    }

    private Token readIdentifier(size_t l, size_t c, size_t off)
    {
        size_t start = index;
        advance(); // First char
        
        while(index < source.length)
        {
            char ch = peek();
            if (isIdentifierPart(ch))
                advance();
            else
                break;
        }

        string val = source[start .. index];
        
        if (val == "true" || val == "false") return Token(TokenType.Boolean, val, l, c, off);
        if (val == "null") return Token(TokenType.Null, val, l, c, off);
        if (val == "Infinity") return Token(TokenType.Number, val, l, c, off);
        if (val == "NaN") return Token(TokenType.Number, val, l, c, off);

        return Token(TokenType.Identifier, val, l, c, off);   
    }
    
    // Simplistic identifier checks (ASCII only for now, should use std.uni)
    private bool isIdentifierStart(char c)
    {
        return isAlpha(c) || c == '$' || c == '_'; 
        // TODO: Unicode ID_Start
    }
    
    private bool isIdentifierPart(char c)
    {
        return isAlphaNum(c) || c == '$' || c == '_'; // TODO: Unicode ID_Continue
    }
}

unittest
{
    import std.stdio;
    
    void test(string input, TokenType[] expectedTypes, string[] expectedValues) {
        Lexer lexer = Lexer(input);
        foreach(i, type; expectedTypes) {
            Token t = lexer.nextToken();
            assert(t.type == type, format("Expected %s, got %s at index %d", type, t.type, i));
            assert(t.value == expectedValues[i], format("Expected '%s', got '%s' at index %d", expectedValues[i], t.value, i));
        }
        assert(lexer.nextToken().type == TokenType.EOF);
    }

    writeln("Running Lexer Tests...");

    // Basic JSON
    test(`{"foo": "bar", "num": 123}`, 
         [TokenType.ObjectStart, TokenType.String, TokenType.Colon, TokenType.String, TokenType.Comma, TokenType.String, TokenType.Colon, TokenType.Number, TokenType.ObjectEnd],
         ["{", "foo", ":", "bar", ",", "num", ":", "123", "}"]);

    // JSON5 Features
    test(`{unquoted: 'single', trail: [1,], // comment
           /* block */ infinity: +Infinity, nan: NaN}`,
         [TokenType.ObjectStart, TokenType.Identifier, TokenType.Colon, TokenType.String, TokenType.Comma, 
          TokenType.Identifier, TokenType.Colon, TokenType.ArrayStart, TokenType.Number, TokenType.Comma, TokenType.ArrayEnd, TokenType.Comma,
          TokenType.Identifier, TokenType.Colon, TokenType.Number, TokenType.Comma, TokenType.Identifier, TokenType.Colon, TokenType.Number, TokenType.ObjectEnd],
         ["{", "unquoted", ":", "single", ",", 
          "trail", ":", "[", "1", ",", "]", ",",
          "infinity", ":", "+Infinity", ",", "nan", ":", "NaN", "}"]);

    writeln("Lexer Tests Passed.");
}
