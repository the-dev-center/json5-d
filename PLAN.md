# Implementation Plan: JSON5-D

## Phase 1: Lexer (Tokenizer)

- [x] Define `TokenType` enum (String, Number, Boolean, Null, BraceOpen, BraceClose, BracketOpen, BracketClose, Colon, Comma, Comment).
- [x] Create `Token` struct.
- [x] Implement `Lexer` class/struct.
  - [x] Handle Single/Double quoted strings.
  - [x] Handle Integers, Floats, Hex, Infinity, NaN.
  - [x] Handle Comments (Line `//` and Block `/* */`).
  - [x] Handle Identifiers (Unquoted keys).

## Phase 2: DOM & Parser

- [x] Define `JSON5Value` tagged union / variant type. (Using `std.json.JSONValue`. for compatibility)
- [x] Implement `Parser` class.
  - [x] Recursive descent parsing for Objects and Arrays.
  - [x] Handle trailing commas.
  - [x] Error reporting with line/column numbers.

## Phase 3: Serialization (Stringify)

- [ ] Implement `stringify` function.
  - [ ] Support options for indentation.
  - [x] Start by outputting valid JSON (double quotes). (Using `std.json.toJSON`)
  - [ ] Add option to output JSON5 (unquoted keys where possibilities, single quotes, etc.). (Using `std.json` default behavior currently produces "Infinite", which needs fixing for strict compliance)

## Phase 4: Deserialization to D Types

- [ ] Implement `deserialize!T(string json5)`.
  - [ ] Map `JSON5Value` to D structs/classes.
