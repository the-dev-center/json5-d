import json5.parser;
import json5.lexer;
import std.stdio;
import std.json;
import std.math;

void main()
{
    writeln("Running Manual Test...");
    try {
        string complex = `{
            unquoted: 'single',
            trail: [1, 2, ], 
            hex: 0x10,
            // comment
            inf: +Infinity,
            nan: NaN,
        }`;
        auto p = new Parser(complex);
        auto v = p.parse();
        
        writeln("Parsed: ", v.toPrettyString(JSONOptions.specialFloatLiterals));
    } catch (Throwable e) {
        writeln("Error: ", e);
    }
}
