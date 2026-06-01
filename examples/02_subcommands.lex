# subcommands — git-style subcommand routing example.
#
# Demonstrates a multi-subcommand CLI with ACLI introspection support.
# Subcommands:
#   status      — show current status
#   list        — list items (with optional --verbose flag)
#   introspect  — print the ACLI command tree as JSON
#
# NOTE: Lex does not yet expose env.args(). argv is hardcoded below
# for demonstration. Change the `let argv` binding to try different
# subcommands. Replace with env.args() once available.

import "std.str" as str

import "std.list" as list

import "lex-cli/arg" as arg

import "lex-cli/parser" as parser

import "lex-cli/output" as output

import "lex-cli/acli" as acli

import "lex-schema/json_value" as jv

# ---- CLI definition --------------------------------------------------
fn make_cli() -> arg.CliDef {
  { name: "mytool", version: "0.1.0", description: "Example multi-subcommand tool.", flags: [arg.flag_str("output", "o", "Output format: text or json", "text")], positionals: [], subcommands: [arg.subcommand("status", "Show current status.", [], []), arg.subcommand("list", "List items.", [arg.flag_bool("verbose", "v", "Show detailed output")], [arg.positional("filter", "Optional filter string", false)]), arg.subcommand("introspect", "Print the ACLI command tree as JSON.", [], [])] }
}

# ---- Subcommand handlers ---------------------------------------------
fn handle_status(mode :: output.OutputMode) -> [io] Nil {
  let text := "Status: all systems operational."
  let data := JObj([("status", JStr("ok"))])
  output.print_ok(mode, "status", text, data)
}

fn handle_list(parsed :: arg.ParsedArgs, mode :: output.OutputMode) -> [io] Nil {
  let verbose := arg.get_flag_bool(parsed, "verbose")
  let items := ["alpha", "beta", "gamma"]
  let text := if verbose {
    "Items (verbose):\n  - alpha\n  - beta\n  - gamma"
  } else {
    "Items: alpha, beta, gamma"
  }
  let data := JObj([("items", JList(list.map(items, fn (s :: Str) -> jv.Json {
    JStr(s)
  }))), ("verbose", JBool(verbose))])
  output.print_ok(mode, "list", text, data)
}

fn handle_introspect(cli :: arg.CliDef) -> [io] Nil {
  let tree := acli.introspect(cli)
  io.print(jv.stringify(tree))
}

# ---- Entry point ------------------------------------------------------
fn main() -> [io] Nil {
  let cli := make_cli()
  let argv := ["list", "--verbose"]
  match parser.parse(cli, argv) {
    Err(e1) => {
      match e1 {
        UnknownFlag(f) => io.print(str.concat("error: unknown flag ", f)),
        MissingPositional(p) => io.print(str.concat("error: missing argument ", p)),
        UnknownSubcommand(s) => io.print(str.concat("error: unknown subcommand ", s)),
      }
    },
    Ok(parsed) => {
      let mode := output.detect_mode(parsed)
      match parsed.subcommand {
        "status" => handle_status(mode),
        "list" => handle_list(parsed, mode),
        "introspect" => handle_introspect(cli),
        _ => io.print(str.concat("Unknown subcommand: ", parsed.subcommand)),
      }
    },
  }
}

