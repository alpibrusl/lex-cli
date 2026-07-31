# lex-cli — parser.lex tests
#
# Covers effective_flags and the subcommand-scoped-flag regression: a
# flag declared only on a SubcommandDef used to be unparseable
# (parse_long_flag/find_flag_by_short only ever consulted the top-level
# CliDef.flags — a subcommand's own `flags` list was read only by
# help.lex's renderer). See test_subcommand_flag_parses_when_active.

import "std.str" as str

import "std.list" as list

import "../src/arg" as arg

import "../src/parser" as parser

# ---- Test scaffolding -----------------------------------------------
fn pass() -> Result[Unit, Str] {
  Ok(())
}

fn fail(why :: Str) -> Result[Unit, Str] {
  Err(why)
}

fn assert_true(cond :: Bool, label :: Str) -> Result[Unit, Str] {
  if cond {
    pass()
  } else {
    fail(label)
  }
}

# ---- Fixtures -----------------------------------------------------
fn cli_with_subcommand_flag() -> arg.CliDef {
  { name: "t", version: "0.1.0", description: "test cli", flags: [arg.flag_str("output", "o", "output format", "text")], positionals: [], subcommands: [arg.subcommand("reset", "Reset.", [arg.flag_bool("hard", "x", "Hard reset")], [arg.positional("id", "id", true)])] }
}

# ---- Regression: subcommand-scoped flags must actually parse ---------
fn test_subcommand_flag_parses_when_active() -> Result[Unit, Str] {
  let cli := cli_with_subcommand_flag()
  match parser.parse(cli, ["reset", "some-id", "--hard"]) {
    Err(_) => fail("--hard is declared on the active `reset` subcommand and must parse, not error"),
    Ok(parsed) => assert_true(arg.get_flag_bool(parsed, "hard"), "--hard must be recorded as true after a successful parse"),
  }
}

fn test_subcommand_short_flag_parses_when_active() -> Result[Unit, Str] {
  let cli := cli_with_subcommand_flag()
  match parser.parse(cli, ["reset", "some-id", "-x"]) {
    Err(_) => fail("-x (reset's short flag for hard) must parse while reset is active"),
    Ok(parsed) => assert_true(arg.get_flag_bool(parsed, "hard"), "-x must be recorded as true after a successful parse"),
  }
}

# ---- Top-level flags still work, before and after the subcommand -----
fn test_top_level_flag_before_subcommand() -> Result[Unit, Str] {
  let cli := cli_with_subcommand_flag()
  match parser.parse(cli, ["--output=json", "reset", "some-id", "--hard"]) {
    Err(_) => fail("a top-level flag before the subcommand token must still parse"),
    Ok(parsed) => assert_true(arg.get_flag_str(parsed, "output", "text") == "json", "--output=json must be recorded"),
  }
}

# ---- A flag scoped to a DIFFERENT subcommand must still be unknown ---
fn test_flag_from_other_subcommand_is_unknown() -> Result[Unit, Str] {
  let cli := { name: "t", version: "0.1.0", description: "test cli", flags: [], positionals: [], subcommands: [arg.subcommand("a", "A.", [arg.flag_bool("only-a", "", "only on a")], []), arg.subcommand("b", "B.", [], [])] }
  match parser.parse(cli, ["b", "--only-a"]) {
    Err(UnknownFlag(name)) => assert_true(name == "--only-a", "the flag name in the error must match the unrecognized token"),
    Err(_) => fail("expected UnknownFlag specifically"),
    Ok(_) => fail("--only-a is scoped to subcommand `a`, not `b`, and must not parse while `b` is active"),
  }
}

fn test_unknown_flag_still_errors() -> Result[Unit, Str] {
  let cli := cli_with_subcommand_flag()
  match parser.parse(cli, ["reset", "some-id", "--nonexistent"]) {
    Err(UnknownFlag(_)) => pass(),
    Err(_) => fail("expected UnknownFlag"),
    Ok(_) => fail("a flag declared nowhere must still be rejected"),
  }
}

# ---- Suite + runner ---------------------------------------------------
fn suite() -> List[Result[Unit, Str]] {
  [test_subcommand_flag_parses_when_active(), test_subcommand_short_flag_parses_when_active(), test_top_level_flag_before_subcommand(), test_flag_from_other_subcommand_is_unknown(), test_unknown_flag_still_errors()]
}

fn count_failures(rs :: List[Result[Unit, Str]]) -> Int {
  list.fold(rs, 0, fn (n :: Int, r :: Result[Unit, Str]) -> Int {
    match r {
      Ok(_) => n,
      Err(_) => n + 1,
    }
  })
}

fn run_all() -> Int {
  count_failures(suite())
}

