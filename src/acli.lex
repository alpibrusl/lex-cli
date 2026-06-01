# lex-cli — ACLI introspection
#
# Converts a CliDef into the ACLI introspect JSON tree. The `introspect`
# subcommand in an ACLI-compliant CLI returns this structure so that
# agent callers can discover the full command surface programmatically.
#
# Output shape:
#   {
#     "name":        "cli-name",
#     "version":     "1.0.0",
#     "description": "...",
#     "flags":       [ { "name": "...", "short": "...", "description": "...",
#                        "type": "bool|str", "default": ... } ],
#     "subcommands": [ { "name": "...", "description": "...",
#                        "flags": [...], "positionals": [...] } ]
#   }
#
# Effects: none.

import "std.str"  as str
import "std.list" as list

import "lex-schema/json_value" as jv
import "./arg" as arg

# ---- Public entry point ----------------------------------------------

# Return the full introspection tree for the given CLI definition.
fn introspect(cli :: arg.CliDef) -> jv.Json {
  let flags_json    := list.map(cli.flags, fn (f :: arg.FlagDef) -> jv.Json {
    flag_to_json(f)
  })
  let subs_json     := list.map(cli.subcommands, fn (s :: arg.SubcommandDef) -> jv.Json {
    subcommand_to_json(s)
  })
  jv.JObj([
    ("name",        jv.JStr(cli.name)),
    ("version",     jv.JStr(cli.version)),
    ("description", jv.JStr(cli.description)),
    ("flags",       jv.JList(flags_json)),
    ("subcommands", jv.JList(subs_json)),
  ])
}

# ---- Converters ------------------------------------------------------

# Convert a FlagDef to its JSON representation.
fn flag_to_json(f :: arg.FlagDef) -> jv.Json {
  let type_str := match f.default {
    arg.FlagBool(_) => "bool",
    arg.FlagStr(_)  => "str",
  }
  let default_json := match f.default {
    arg.FlagBool(b) => jv.JBool(b),
    arg.FlagStr(s)  => jv.JStr(s),
  }
  jv.JObj([
    ("name",        jv.JStr(f.name)),
    ("short",       jv.JStr(f.short)),
    ("description", jv.JStr(f.description)),
    ("type",        jv.JStr(type_str)),
    ("default",     default_json),
  ])
}

# Convert a PositionalDef to its JSON representation.
fn positional_to_json(p :: arg.PositionalDef) -> jv.Json {
  jv.JObj([
    ("name",        jv.JStr(p.name)),
    ("description", jv.JStr(p.description)),
    ("required",    jv.JBool(p.required)),
  ])
}

# Convert a SubcommandDef to its JSON representation.
fn subcommand_to_json(s :: arg.SubcommandDef) -> jv.Json {
  let flags_json := list.map(s.flags, fn (f :: arg.FlagDef) -> jv.Json {
    flag_to_json(f)
  })
  let pos_json := list.map(s.positionals, fn (p :: arg.PositionalDef) -> jv.Json {
    positional_to_json(p)
  })
  jv.JObj([
    ("name",        jv.JStr(s.name)),
    ("description", jv.JStr(s.description)),
    ("flags",       jv.JList(flags_json)),
    ("positionals", jv.JList(pos_json)),
  ])
}
