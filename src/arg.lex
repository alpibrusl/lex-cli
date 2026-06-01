# lex-cli — CLI type definitions
#
# Core ADTs for describing CLI interfaces: flags, positionals,
# subcommands, and the top-level CLI definition. Also contains
# the parsed result type and builder helpers.
#
# Effects: none. All types and builders are pure.

import "std.str" as str

import "std.list" as list

# ---- Flag values ------------------------------------------------------
# A parsed flag value — either a boolean switch or a string option.
type FlagValue = FlagBool(Bool) | FlagStr(Str)

type FlagDef = { name :: Str, short :: Str, description :: Str, default :: FlagValue }

# A positional argument definition.
type PositionalDef = { name :: Str, description :: Str, required :: Bool }

# A subcommand definition. Subcommands may have their own flags and
# positionals but do not recurse further (no nested sub-subcommands).
type SubcommandDef = { name :: Str, description :: Str, flags :: List[FlagDef], positionals :: List[PositionalDef] }

# The top-level CLI definition — the root of the command tree.
type CliDef = { name :: Str, version :: Str, description :: Str, flags :: List[FlagDef], positionals :: List[PositionalDef], subcommands :: List[SubcommandDef] }

# ---- Parsed result ---------------------------------------------------
# The result of parsing an argv list.
# `subcommand` is empty string if the root command is active.
# `flags` is a list of (name, value) pairs for every flag encountered.
# `positionals` are the non-flag, non-subcommand arguments in order.
# `remaining` is reserved for future use (always [] for now).
type ParsedArgs = { subcommand :: Str, flags :: List[(Str, FlagValue)], positionals :: List[Str], remaining :: List[Str] }

# ---- Parse errors ----------------------------------------------------
type ParseError = UnknownFlag(Str) | MissingPositional(Str) | UnknownSubcommand(Str)

fn flag_bool(name :: Str, short :: Str, description :: Str) -> FlagDef {
  { name: name, short: short, description: description, default: FlagBool(false) }
}

# Create a string flag with a given default value.
fn flag_str(name :: Str, short :: Str, description :: Str, default :: Str) -> FlagDef {
  { name: name, short: short, description: description, default: FlagStr(default) }
}

# Create a positional argument definition.
fn positional(name :: Str, description :: Str, required :: Bool) -> PositionalDef {
  { name: name, description: description, required: required }
}

# Create a subcommand definition.
fn subcommand(name :: Str, description :: Str, flags :: List[FlagDef], positionals :: List[PositionalDef]) -> SubcommandDef {
  { name: name, description: description, flags: flags, positionals: positionals }
}

# ---- Flag lookup helpers ---------------------------------------------
# Look up a bool flag by name. Returns false if the flag is not present
# in the parsed result or if the value is not a FlagBool.
fn get_flag_bool(parsed :: ParsedArgs, name :: Str) -> Bool {
  list.fold(parsed.flags, false, fn (acc :: Bool, pair :: (Str, FlagValue)) -> Bool {
    match pair {
      (k, v) => if k == name {
        match v {
          FlagBool(b) => b,
          FlagStr(_) => acc,
        }
      } else {
        acc
      },
    }
  })
}

# Look up a string flag by name. Returns `default` if not present or
# if the stored value is a FlagBool.
fn get_flag_str(parsed :: ParsedArgs, name :: Str, default :: Str) -> Str {
  list.fold(parsed.flags, default, fn (acc :: Str, pair :: (Str, FlagValue)) -> Str {
    match pair {
      (k, v) => if k == name {
        match v {
          FlagStr(s) => s,
          FlagBool(_) => acc,
        }
      } else {
        acc
      },
    }
  })
}

