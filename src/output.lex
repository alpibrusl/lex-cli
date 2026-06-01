# lex-cli — ACLI output envelope
#
# Implements the ACLI standard for agent-friendly CLI output:
#   - JSON envelope: { ok: Bool, command: Str, data: Json, meta: { duration_ms: Int } }
#   - OutputMode: text (human-readable) or json (ACLI envelope)
#   - Exit code conventions for script consumers
#
# Effects: io (for print_ok / print_err only). All JSON builders are pure.

import "std.str"  as str
import "std.list" as list

import "lex-schema/json_value" as jv
import "./arg" as arg

# ---- Exit code conventions -------------------------------------------

fn exit_ok()            -> Int { 0 }
fn exit_invalid_args()  -> Int { 2 }
fn exit_not_found()     -> Int { 3 }
fn exit_conflict()      -> Int { 5 }
fn exit_dry_run()       -> Int { 9 }

# ---- Output mode -----------------------------------------------------

type OutputMode =
    OutputText
  | OutputJson

# Detect output mode from parsed args. Returns OutputJson if the
# `--output` flag is set to "json", otherwise OutputText.
fn detect_mode(parsed :: arg.ParsedArgs) -> OutputMode {
  let val := arg.get_flag_str(parsed, "output", "text")
  if val == "json" { OutputJson } else { OutputText }
}

# ---- ACLI envelope builders (pure) -----------------------------------

# Build a successful ACLI JSON envelope string.
fn ok_json(command :: Str, data :: jv.Json) -> Str {
  let obj := jv.JObj([
    ("ok",      jv.JBool(true)),
    ("command", jv.JStr(command)),
    ("data",    data),
    ("meta",    jv.JObj([("duration_ms", jv.JInt(0))])),
  ])
  jv.stringify(obj)
}

# Build an error ACLI JSON envelope string.
fn err_json(command :: Str, message :: Str) -> Str {
  let obj := jv.JObj([
    ("ok",      jv.JBool(false)),
    ("command", jv.JStr(command)),
    ("error",   jv.JStr(message)),
    ("meta",    jv.JObj([("duration_ms", jv.JInt(0))])),
  ])
  jv.stringify(obj)
}

# ---- Effectful printers ----------------------------------------------

# Print a successful result. In text mode, prints `text`. In json mode,
# prints the ACLI envelope wrapping `data`.
fn print_ok(
  mode    :: OutputMode,
  command :: Str,
  text    :: Str,
  data    :: jv.Json
) -> [io] Nil {
  match mode {
    OutputText => io.print(text),
    OutputJson => io.print(ok_json(command, data)),
  }
}

# Print an error result. In text mode, prints `text`. In json mode,
# prints the ACLI error envelope.
fn print_err(
  mode    :: OutputMode,
  command :: Str,
  text    :: Str
) -> [io] Nil {
  match mode {
    OutputText => io.print(text),
    OutputJson => io.print(err_json(command, text)),
  }
}
