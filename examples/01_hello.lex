# hello — simplest lex-cli example.
#
# Demonstrates a single-command CLI with two flags:
#   --name   (str)  — who to greet (default: "World")
#   --output (str)  — output format: "text" or "json" (default: "text")
#
# Usage (conceptual, when Lex gains env.args()):
#   hello --name Alice
#   hello --name Alice --output json
#
# NOTE: Lex does not yet expose env.args(). argv is hardcoded below
# for demonstration. Replace the `let argv` binding with an env.args()
# call once that stdlib function is available.

import "std.str" as str

import "lex-cli/arg"    as arg
import "lex-cli/parser" as parser
import "lex-cli/output" as output
import "lex-schema/json_value" as jv

# ---- CLI definition --------------------------------------------------

fn make_cli() -> arg.CliDef {
  {
    name:        "hello",
    version:     "0.1.0",
    description: "Greet someone from the command line.",
    flags: [
      arg.flag_str("name",   "n", "Name of the person to greet", "World"),
      arg.flag_str("output", "o", "Output format: text or json",  "text"),
    ],
    positionals: [],
    subcommands: [],
  }
}

# ---- Entry point ------------------------------------------------------

fn main() -> [io] Nil {
  let cli := make_cli()

  # Hardcoded argv for demonstration — replace with env.args() when available.
  let argv := ["--name", "Alice"]

  match parser.parse(cli, argv) {
    Err(e1) => {
      match e1 {
        arg.UnknownFlag(f)       => io.print(str.concat("error: unknown flag ", f)),
        arg.MissingPositional(p) => io.print(str.concat("error: missing argument ", p)),
        arg.UnknownSubcommand(s) => io.print(str.concat("error: unknown subcommand ", s)),
      }
    },
    Ok(parsed) => {
      let name := arg.get_flag_str(parsed, "name", "World")
      let mode := output.detect_mode(parsed)
      let text := str.concat("Hello, ", str.concat(name, "!"))
      let data := jv.JObj([("greeting", jv.JStr(text)), ("name", jv.JStr(name))])
      output.print_ok(mode, "hello", text, data)
    },
  }
}
