# lex-cli — persistent CLI config + credential resolution
#
# Networked CLIs (API clients) need three things the parsing layer doesn't
# provide: a place to persist a token, a precedence rule for credentials,
# and a path convention. This module supplies all three.
#
#   Config file:  ~/.config/<tool>/config.json   { "api": "...", "token": "..." }
#   Precedence:   flag  >  env  >  config file  >  default
#
# Effects:
#   load        — [fs_read, env]
#   save        — [fs_write, env]
#   resolve     — [env]
#   *_path      — [env]

import "std.str" as str
import "std.io" as io
import "std.fs" as fs
import "std.env" as env
import "std.json" as json

# The persisted config. Kept deliberately small; tools that need more can
# store it alongside and merge.
type Config = { api :: Str, token :: Str }

fn empty() -> Config {
  { api: "", token: "" }
}

# ---- Paths -----------------------------------------------------------

fn getenv(key :: Str) -> [env] Str {
  match env.get(key) {
    Some(v) => v,
    None => "",
  }
}

fn config_dir(tool :: Str) -> [env] Str {
  getenv("HOME") + "/.config/" + tool
}

fn config_path(tool :: Str) -> [env] Str {
  config_dir(tool) + "/config.json"
}

# ---- Load / save -----------------------------------------------------

# Load the tool's config, or an empty config if absent/unreadable/malformed.
fn load(tool :: Str) -> [io, env] Config {
  match io.read(config_path(tool)) {
    Err(_) => empty(),
    Ok(content) => {
      let parsed :: Result[Config, Str] := json.parse(content)
      match parsed {
        Err(_) => empty(),
        Ok(c) => c,
      }
    },
  }
}

# Persist config (creates ~/.config/<tool>/ if needed).
fn save(tool :: Str, cfg :: Config) -> [io, fs_write, env] Result[Unit, Str] {
  let __d := fs.mkdir_p(config_dir(tool))
  let body := "{\"api\":\"" + esc(cfg.api) + "\",\"token\":\"" + esc(cfg.token) + "\"}"
  match io.write(config_path(tool), body) {
    Err(e) => Err(e),
    Ok(_) => Ok(()),
  }
}

# ---- Credential / setting resolution ---------------------------------

# Resolve a setting by precedence: flag (if non-empty) > env var > config
# value (if non-empty) > default. The empty string means "unset" at each
# layer, so a caller passes "" for an absent flag.
fn resolve(flag :: Str, env_name :: Str, cfg_val :: Str, dflt :: Str) -> [env] Str {
  if not str.is_empty(flag) {
    flag
  } else {
    let e := getenv(env_name)
    if not str.is_empty(e) {
      e
    } else {
      if not str.is_empty(cfg_val) {
        cfg_val
      } else {
        dflt
      }
    }
  }
}

# ---- Internal --------------------------------------------------------

fn esc(s :: Str) -> Str {
  str.replace(str.replace(s, "\\", "\\\\"), "\"", "\\\"")
}
