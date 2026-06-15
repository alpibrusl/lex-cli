# lex-cli example — config + authenticated API client
#
# Demonstrates the API-client layer: resolve a base URL + token by
# precedence, persist them, and make a JSON request. Run live:
#
#   lex run --allow-effects net,io,fs_write,env examples/03_api_client.lex seasons
#
# `seasons` hits a public endpoint (no token needed); `whoami_demo`
# shows the authenticated shape.

import "std.io" as io

import "std.int" as int

import "../src/config" as config

import "../src/api" as api

# Resolve the API base the way a real CLI would: flag > env > config > default.
fn resolved_base() -> [io, env] Str {
  let cfg := config.load("lex-arena")
  config.resolve("", "ARENA_API", cfg.api, "https://loom.alpibru.com")
}

# GET the public seasons list and print the HTTP status + raw JSON.
fn seasons() -> [net, io, env] Int {
  let base := resolved_base()
  let res := api.get_json(base, "/api/arena/seasons", "")
  let __p := io.print("GET " + base + "/api/arena/seasons -> " + int.to_str(res.status))
  if res.ok {
    let __b := io.print(res.body)
    0
  } else {
    let __e := io.print("error: " + res.error)
    1
  }
}

# Persist a token, then read it back — proves the config round-trip.
fn save_token_demo(tok :: Str) -> [io, fs_write, env] Int {
  match config.save("lex-arena", { api: "https://loom.alpibru.com", token: tok }) {
    Err(e) => {
      let __e := io.print("save failed: " + e)
      1
    },
    Ok(_) => {
      let back := config.load("lex-arena")
      let __p := io.print("saved + reloaded token: " + back.token)
      0
    },
  }
}

