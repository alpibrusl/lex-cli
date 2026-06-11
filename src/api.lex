# lex-cli — minimal authenticated JSON HTTP client for API-client CLIs
#
# Thin ergonomic layer over std.http for the common CLI shape: GET/POST
# JSON against a base URL with an optional Bearer token. Pass token="" for
# unauthenticated (public) endpoints.
#
# std.http already supports everything needed (with_auth, with_header,
# send, json_body) — this module just removes the request-record
# boilerplate so a CLI command is one line.
#
# Effects: get_json / post_json — [net]

import "std.str" as str
import "std.map" as map
import "std.bytes" as bytes
import "std.http" as http

# Outcome of an API call: the HTTP status and the raw JSON body string.
# Callers decode it with a typed `json.parse` (the idiomatic Lex pattern),
# so this module stays agnostic about response shapes. status 0 means the
# request never completed (network error).
type ApiResult = { ok :: Bool, status :: Int, body :: Str, error :: Str }

fn err_result(msg :: Str) -> ApiResult {
  { ok: false, status: 0, body: "", error: msg }
}

# ---- Request builders ------------------------------------------------

fn base_req(method :: Str, url :: Str) -> { method :: Str, url :: Str, headers :: Map[Str, Str], body :: Option[Bytes], timeout_ms :: Option[Int] } {
  { method: method, url: url, headers: map.new(), body: None, timeout_ms: Some(30000) }
}

fn maybe_auth[R](req :: R, token :: Str) -> R {
  if str.is_empty(token) {
    req
  } else {
    http.with_auth(req, "Bearer", token)
  }
}

# ---- Public API ------------------------------------------------------

# GET <base><path> with optional Bearer token; decode the JSON body.
fn get_json(base :: Str, path :: Str, token :: Str) -> [net] ApiResult {
  let req := maybe_auth(base_req("GET", base + path), token)
  finish(http.send(req))
}

# POST <base><path> with a JSON string body and optional Bearer token.
fn post_json(base :: Str, path :: Str, body_json :: Str, token :: Str) -> [net] ApiResult {
  let req0 := base_req("POST", base + path)
  let req1 := { method: req0.method, url: req0.url, headers: req0.headers, body: Some(bytes.from_str(body_json)), timeout_ms: req0.timeout_ms }
  let req2 := http.with_header(req1, "Content-Type", "application/json")
  finish(http.send(maybe_auth(req2, token)))
}

# ---- Response handling -----------------------------------------------

fn finish(sent :: Result[HttpResponse, HttpError]) -> ApiResult {
  match sent {
    Err(_) => err_result("request failed"),
    Ok(resp) => {
      let ok := resp.status >= 200 and resp.status < 300
      match http.text_body(resp) {
        Err(_) => { ok: ok, status: resp.status, body: "", error: if ok { "" } else { "could not read response body" } },
        Ok(s) => { ok: ok, status: resp.status, body: s, error: "" },
      }
    },
  }
}
