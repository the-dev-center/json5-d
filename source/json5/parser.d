module json5.parser;

import json5.lexer;
import std.json;
import std.conv;
import std.array;
import std.exception;
import std.algorithm;
import std.string;
import std.format;

class JSON5ParseException : Exception
{
    this(string msg, size_t line = 0, size_t col = 0, string file = __FILE__, size_t lineNo = __LINE__)
    {
        super(format("%s at line %d, col %d", msg, line, col), file, lineNo);
    }
}

class Parser
{
    private Lexer lexer;
    private Token currentToken;

    this(string source)
    {
        lexer = Lexer(source);
        advance(); // Load first token
    }

    private void advance()
    {
        currentToken = lexer.nextToken();
    }

    private void ensure(TokenType type)
    {
        if (currentToken.type != type)
        {
            throw new JSON5ParseException(format("Expected %s, but got %s", type, currentToken.type), 
                currentToken.line, currentToken.column);
        }
    }

    private void consume(TokenType type)
    {
        ensure(type);
        advance();
    }

    public JSONValue parse()
    {
        JSONValue val = parseValue();
        if (currentToken.type != TokenType.EOF)
        {
            throw new JSON5ParseException("Expected EOF after JSON5 value", currentToken.line, currentToken.column);
        }
        return val;
    }

    private JSONValue parseValue()
    {
        switch (currentToken.type)
        {
            case TokenType.ObjectStart: return parseObject();
            case TokenType.ArrayStart: return parseArray();
            case TokenType.String: 
                string val = currentToken.value;
                advance();
                return JSONValue(val);
            case TokenType.Number:
                string text = currentToken.value;
                advance();
                // Try Integer
                try {
                    if (text.length > 2 && text[0..2] == "0x") { // Hex
                         return JSONValue(to!long(text[2..$], 16));
                    }
                    if (text == "NaN" || text == "+NaN" || text == "-NaN") {
                        return JSONValue(double.nan);
                    }
                    if (text == "Infinity" || text == "+Infinity") {
                        return JSONValue(double.infinity);
                    }
                    if (text == "-Infinity") {
                        return JSONValue(-double.infinity);
                    }
                    
                    if (text.canFind('.') || text.canFind('e') || text.canFind('E')) {
                        return JSONValue(to!double(text));
                    }
                    return JSONValue(to!long(text));
                } catch (Exception e) {
                    // Fallback to double if integer fails
                    return JSONValue(to!double(text));
                }
            case TokenType.Boolean:
                bool b = currentToken.value == "true";
                advance();
                return JSONValue(b);
            case TokenType.Null:
                advance();
                return JSONValue(null);
            default:
                throw new JSON5ParseException(format("Unexpected token %s", currentToken.type), 
                    currentToken.line, currentToken.column);
        }
    }

    private JSONValue parseObject()
    {
        consume(TokenType.ObjectStart);
        JSONValue[string] obj;

        while (currentToken.type != TokenType.ObjectEnd && currentToken.type != TokenType.EOF)
        {
            // Key (String or Identifier)
            string key;
            if (currentToken.type == TokenType.String || currentToken.type == TokenType.Identifier)
            {
                key = currentToken.value;
                advance();
            }
            else
            {
                throw new JSON5ParseException(format("Expected String or Identifier as Object Key, got %s", 
                    currentToken.type), currentToken.line, currentToken.column);
            }

            consume(TokenType.Colon);
            obj[key] = parseValue();

            if (currentToken.type == TokenType.Comma)
            {
                advance();
            }
            else
            {
                break;
            }
        }

        consume(TokenType.ObjectEnd);
        return JSONValue(obj);
    }
    
    // ... parseArray ... same logic, skipping diff ...
    private JSONValue parseArray()
    {
        consume(TokenType.ArrayStart);
        JSONValue[] arr;

        while (currentToken.type != TokenType.ArrayEnd && currentToken.type != TokenType.EOF)
        {
            if (currentToken.type == TokenType.ArrayEnd) break;

            arr ~= parseValue();

            if (currentToken.type == TokenType.Comma)
            {
                advance();
            }
            else
            {
                break;
            }
        }

        consume(TokenType.ArrayEnd);
        return JSONValue(arr);
    }
}

unittest
{
    import std.stdio;
    writeln("Running Parser Tests...");

    void test(string input, JSONType expectedType) {
        Parser p = new Parser(input);
        JSONValue v = p.parse();
        assert(v.type == expectedType, format("Expected %s, got %s", expectedType, v.type));
    }
    
    // Basic
    test(`{"a": 1}`, JSONType.object);
    test(`[1, 2]`, JSONType.array);
    test(`true`, JSONType.true_);
    test(`null`, JSONType.null_);
    test(`"str"`, JSONType.string);
    test(`123`, JSONType.integer);
    
    // JSON5
    Parser p;
    JSONValue v;

    // Unquoted keys and Single Quotes
    p = new Parser(`{unquoted: 'single'}`);
    v = p.parse();
    assert(v["unquoted"].str == "single");

    // Trailing comma array
    p = new Parser(`[1, ]`);
    v = p.parse();
    assert(v.array.length == 1);
    assert(v[0].integer == 1);

    // Initial failure point: trailing comma in object + comments + hex + infinity
    string complex = `{
        unquoted: 'single',
        trail: [1, 2, ], 
        hex: 0x10,
        // comment
        inf: +Infinity,
        nan: NaN,
    }`;
    p = new Parser(complex);
    v = p.parse();
    
    assert(v["unquoted"].str == "single");
    assert(v["trail"].array.length == 2);
    assert(v["hex"].integer == 16);
    assert(v["inf"].floating == double.infinity);
    import std.math : isNaN;
    assert(v["nan"].floating.isNaN);

    writeln("Parser Tests Passed.");
}
