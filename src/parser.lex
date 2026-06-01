# lex-cli — argv parser
#
# Parses a `List[Str]` argv into a `ParsedArgs` value.
#
# Rules:
#   - Items starting with `--` are long flags.
#     `--name=value` sets a string flag.
#     `--name` alone sets a boolean flag to true.
#   - Items starting with `-` followed by a single character are short flags.
#     They set the corresponding boolean flag to true.
#   - The first non-flag item that matches a known subcommand name becomes
#     the active subcommand.
#   - Remaining non-flag, non-subcommand items are positionals.
#   - An unknown `--flag` produces `Err(UnknownFlag(name))`.
#   - An unknown first-positional when subcommands are defined produces
#     `Err(UnknownSubcommand(name))`.
#
# Effects: none.

import "std.str" as str

import "std.list" as list

import "./arg" as arg

# ---- Public entry point ----------------------------------------------
fn parse(cli :: arg.CliDef, argv :: List[Str]) -> Result[arg.ParsedArgs, arg.ParseError] {
  let init := { subcommand: "", flags: [], positionals: [], remaining: [] }
  parse_loop(cli, argv, init)
}

# ---- Recursive loop --------------------------------------------------
# Accumulator record mirrors ParsedArgs so we can build it up token by token.
fn parse_loop(cli :: arg.CliDef, argv :: List[Str], acc :: arg.ParsedArgs) -> Result[arg.ParsedArgs, arg.ParseError] {
  match list.head(argv) {
    None => Ok(acc),
    Some(token) => {
      let rest := list.tail(argv)
      if str.starts_with(token, "--") {
        let body := str.slice(token, 2, str.len(token))
        match parse_long_flag(cli, body, rest, acc) {
          Err(e1) => Err(e1),
          Ok(state) => parse_loop(cli, state.remaining_argv, state.acc),
        }
      } else {
        if str.starts_with(token, "-") and str.len(token) == 2 {
          let short := str.slice(token, 1, 2)
          match find_flag_by_short(cli.flags, short) {
            None => Err(arg.UnknownFlag(str.concat("-", short))),
            Some(fd) => {
              let new_flags := list.concat(acc.flags, [(fd.name, arg.FlagBool(true))])
              let acc2 := { subcommand: acc.subcommand, flags: new_flags, positionals: acc.positionals, remaining: acc.remaining }
              parse_loop(cli, rest, acc2)
            },
          }
        } else {
          if str.is_empty(acc.subcommand) and not list.is_empty(cli.subcommands) {
            match find_subcommand(cli.subcommands, token) {
              Some(_) => {
                let acc2 := { subcommand: token, flags: acc.flags, positionals: acc.positionals, remaining: acc.remaining }
                parse_loop(cli, rest, acc2)
              },
              None => Err(arg.UnknownSubcommand(token)),
            }
          } else {
            let new_pos := list.concat(acc.positionals, [token])
            let acc2 := { subcommand: acc.subcommand, flags: acc.flags, positionals: new_pos, remaining: acc.remaining }
            parse_loop(cli, rest, acc2)
          }
        }
      }
    },
  }
}

# ---- Long flag parsing -----------------------------------------------
# Intermediate state returned by `parse_long_flag` so it can consume
# the next token when handling `--output json` (space-separated value).
type LongFlagState = { acc :: arg.ParsedArgs, remaining_argv :: List[Str] }

fn parse_long_flag(cli :: arg.CliDef, body :: Str, rest :: List[Str], acc :: arg.ParsedArgs) -> Result[LongFlagState, arg.ParseError] {
  match find_eq(body, 0) {
    Some(eq_pos) => {
      let name := str.slice(body, 0, eq_pos)
      let value := str.slice(body, eq_pos + 1, str.len(body))
      match find_flag_by_name(cli.flags, name) {
        None => Err(arg.UnknownFlag(str.concat("--", name))),
        Some(_) => {
          let new_flags := list.concat(acc.flags, [(name, arg.FlagStr(value))])
          let acc2 := { subcommand: acc.subcommand, flags: new_flags, positionals: acc.positionals, remaining: acc.remaining }
          Ok({ acc: acc2, remaining_argv: rest })
        },
      }
    },
    None => {
      match find_flag_by_name(cli.flags, body) {
        None => Err(arg.UnknownFlag(str.concat("--", body))),
        Some(fd) => {
          match fd.default {
            FlagBool(_) => {
              let new_flags := list.concat(acc.flags, [(body, arg.FlagBool(true))])
              let acc2 := { subcommand: acc.subcommand, flags: new_flags, positionals: acc.positionals, remaining: acc.remaining }
              Ok({ acc: acc2, remaining_argv: rest })
            },
            FlagStr(_) => {
              match list.head(rest) {
                None => {
                  let new_flags := list.concat(acc.flags, [(body, arg.FlagStr(""))])
                  let acc2 := { subcommand: acc.subcommand, flags: new_flags, positionals: acc.positionals, remaining: acc.remaining }
                  Ok({ acc: acc2, remaining_argv: rest })
                },
                Some(value) => {
                  let rest2 := list.tail(rest)
                  let new_flags := list.concat(acc.flags, [(body, arg.FlagStr(value))])
                  let acc2 := { subcommand: acc.subcommand, flags: new_flags, positionals: acc.positionals, remaining: acc.remaining }
                  Ok({ acc: acc2, remaining_argv: rest2 })
                },
              }
            },
          }
        },
      }
    },
  }
}

# ---- Helpers ---------------------------------------------------------
# Find the position of `=` in a string, scanning left to right.
# Returns None if not found.
fn find_eq(s :: Str, pos :: Int) -> Option[Int] {
  if pos >= str.len(s) {
    None
  } else {
    if str.slice(s, pos, pos + 1) == "=" {
      Some(pos)
    } else {
      find_eq(s, pos + 1)
    }
  }
}

# Find a flag definition by long name.
fn find_flag_by_name(flags :: List[arg.FlagDef], name :: Str) -> Option[arg.FlagDef] {
  list.fold(flags, None, fn (acc :: Option[arg.FlagDef], fd :: arg.FlagDef) -> Option[arg.FlagDef] {
    match acc {
      Some(_) => acc,
      None => if fd.name == name {
        Some(fd)
      } else {
        None
      },
    }
  })
}

# Find a flag definition by short name.
fn find_flag_by_short(flags :: List[arg.FlagDef], short :: Str) -> Option[arg.FlagDef] {
  list.fold(flags, None, fn (acc :: Option[arg.FlagDef], fd :: arg.FlagDef) -> Option[arg.FlagDef] {
    match acc {
      Some(_) => acc,
      None => if fd.short == short {
        Some(fd)
      } else {
        None
      },
    }
  })
}

# Find a subcommand definition by name.
fn find_subcommand(subs :: List[arg.SubcommandDef], name :: Str) -> Option[arg.SubcommandDef] {
  list.fold(subs, None, fn (acc :: Option[arg.SubcommandDef], sd :: arg.SubcommandDef) -> Option[arg.SubcommandDef] {
    match acc {
      Some(_) => acc,
      None => if sd.name == name {
        Some(sd)
      } else {
        None
      },
    }
  })
}

