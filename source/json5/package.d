module json5;

import std.json;

/++
 + Parses a JSON5 string into a JSONValue.
 +/
JSONValue parseJSON5(string content) {
    // TODO: Implement actual JSON5 parsing logic.
    // For now, it might fall back to std.json.parseJSON if it's strict JSON.
    return parseJSON(content);
}

/++
 + Serializes a JSONValue into a JSON5 string.
 +/
string toJSON5(JSONValue value, bool pretty = true) {
    // TODO: Implement JSON5 serialization (e.g., unquoted keys where possible).
    return value.toJSON(pretty);
}
