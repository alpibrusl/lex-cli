# lex-cli — facade re-export
#
# One-stop import for consumers: `import "lex-cli/cli" as cli` gives
# access to every public type and module in the package.
#
# Type aliases here let callers write `cli.CliDef` instead of
# `arg.CliDef`, keeping the public surface clean.

import "./arg"    as arg
import "./parser" as parser
import "./help"   as help
import "./output" as output
import "./acli"   as acli

# ---- Type re-exports -------------------------------------------------

type FlagValue     = arg.FlagValue
type FlagDef       = arg.FlagDef
type PositionalDef = arg.PositionalDef
type SubcommandDef = arg.SubcommandDef
type CliDef        = arg.CliDef
type ParsedArgs    = arg.ParsedArgs
type ParseError    = arg.ParseError
type OutputMode    = output.OutputMode
