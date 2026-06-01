# lex-cli — help text renderer
#
# Renders human-readable `--help` output for a CliDef or a specific
# SubcommandDef. Output format:
#
#   cli-name v1.0.0 — description
#
#   USAGE:
#     cli-name [flags] [subcommand] [args]
#
#   FLAGS:
#     --name, -s    description (default: value)
#
#   SUBCOMMANDS:
#     name    description
#
#   Run 'cli-name <subcommand> --help' for subcommand help.
#
# Effects: none.

import "std.str"  as str
import "std.list" as list

import "./arg" as arg

# ---- Top-level help --------------------------------------------------

fn render(cli :: arg.CliDef) -> Str {
  let header := str.concat(cli.name,
    str.concat(" v", str.concat(cli.version,
      str.concat(" — ", cli.description))))

  let usage := str.concat("USAGE:\n  ",
    str.concat(cli.name, " [flags] [subcommand] [args]"))

  let flags_section := if list.is_empty(cli.flags) {
    ""
  } else {
    str.concat("FLAGS:\n", render_flags(cli.flags))
  }

  let subs_section := if list.is_empty(cli.subcommands) {
    ""
  } else {
    str.concat("SUBCOMMANDS:\n", render_subcommands(cli.subcommands))
  }

  let footer := if list.is_empty(cli.subcommands) {
    ""
  } else {
    str.concat("Run '", str.concat(cli.name, " <subcommand> --help' for subcommand help."))
  }

  join_non_empty([header, "", usage, "", flags_section, subs_section, footer], "\n")
}

# ---- Subcommand help -------------------------------------------------

fn render_subcommand(cli_name :: Str, sub :: arg.SubcommandDef) -> Str {
  let header := str.concat(cli_name,
    str.concat(" ", str.concat(sub.name,
      str.concat(" — ", sub.description))))

  let usage := str.concat("USAGE:\n  ",
    str.concat(cli_name, str.concat(" ", str.concat(sub.name, " [flags] [args]"))))

  let flags_section := if list.is_empty(sub.flags) {
    ""
  } else {
    str.concat("FLAGS:\n", render_flags(sub.flags))
  }

  let pos_section := if list.is_empty(sub.positionals) {
    ""
  } else {
    str.concat("ARGUMENTS:\n", render_positionals(sub.positionals))
  }

  join_non_empty([header, "", usage, "", flags_section, pos_section], "\n")
}

# ---- Internal renderers ----------------------------------------------

fn render_flags(flags :: List[arg.FlagDef]) -> Str {
  let lines := list.map(flags, fn (fd :: arg.FlagDef) -> Str {
    let short_part := if str.is_empty(fd.short) {
      ""
    } else {
      str.concat(", -", fd.short)
    }
    let lhs := str.concat("  --", str.concat(fd.name, short_part))
    let default_part := match fd.default {
      arg.FlagBool(b) => if b { " (default: true)" } else { " (default: false)" },
      arg.FlagStr(s)  => if str.is_empty(s) {
        ""
      } else {
        str.concat(" (default: ", str.concat(s, ")"))
      },
    }
    str.concat(pad_right(lhs, 24), str.concat(fd.description, default_part))
  })
  str.join(lines, "\n")
}

fn render_subcommands(subs :: List[arg.SubcommandDef]) -> Str {
  let lines := list.map(subs, fn (sd :: arg.SubcommandDef) -> Str {
    let lhs := str.concat("  ", sd.name)
    str.concat(pad_right(lhs, 16), sd.description)
  })
  str.join(lines, "\n")
}

fn render_positionals(positionals :: List[arg.PositionalDef]) -> Str {
  let lines := list.map(positionals, fn (pd :: arg.PositionalDef) -> Str {
    let req := if pd.required { " (required)" } else { " (optional)" }
    let lhs := str.concat("  <", str.concat(pd.name, ">"))
    str.concat(pad_right(lhs, 16), str.concat(pd.description, req))
  })
  str.join(lines, "\n")
}

# ---- String utilities ------------------------------------------------

# Right-pad a string with spaces to at least `width` characters.
fn pad_right(s :: Str, width :: Int) -> Str {
  let n := str.len(s)
  if n >= width { str.concat(s, "  ") }
  else { str.concat(s, spaces(width - n)) }
}

fn spaces(n :: Int) -> Str {
  if n <= 0 { "" }
  else { str.concat(" ", spaces(n - 1)) }
}

# Join a list of strings with a separator, skipping empty entries.
fn join_non_empty(parts :: List[Str], sep :: Str) -> Str {
  let non_empty := list.filter(parts, fn (s :: Str) -> Bool {
    not str.is_empty(s)
  })
  str.join(non_empty, sep)
}
