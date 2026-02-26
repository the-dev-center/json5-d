module json5;

public import std.json;
import json5.parser;

/++
 + Parses a JSON5 string into a JSONValue.
 +/
JSONValue parseJSON5(string content) {
    auto parser = new Parser(content);
    return parser.parse();
}

/++
 + Serializes a JSONValue into a JSON5 string.
 +/
string toJSON5(JSONValue value, bool pretty = true) {
    // For now, strict JSON is valid JSON5.
    // TODO: Implement cleaner JSON5 serialization (unquoted keys, etc.)
    return value.toJSON(pretty);
}
