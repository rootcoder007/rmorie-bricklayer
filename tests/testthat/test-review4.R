# Fourth review (network / service discovery, 2026-10-06). Each finding is fixed at
# every site of its kind; the live cases stand up throwaway loopback servers.

r4 <- function(nm) get(nm, envir = asNamespace("rmoriebricklayer"))
# the package sources, when the tests run from a checkout (covr and R CMD check have none)
pkg_root_r4 <- function() {
  for (d in c(testthat::test_path("..", ".."), getwd(), file.path(getwd(), "..", ".."))) {
    if (file.exists(file.path(d, "DESCRIPTION")) && dir.exists(file.path(d, "src"))) return(normalizePath(d))
  }
  NA_character_
}

# A tiny loopback HTTP server (python3) with the behaviours the findings need:
#   /echo        -> JSON of the request headers
#   /go/<port>   -> 302 to http://127.0.0.1:<port>/echo (another origin: same host, other port)
#   /self        -> 302 to /echo on the same origin
#   /drip        -> headers, then one byte every 2 s
#   /endless     -> an unbounded chunked body
#   /url-body    -> a body that is a bare URL
#   /missing     -> 404 with an empty body
r4_server <- function(env = parent.frame()) {
  skip_on_cran()
  skip_on_os("windows")
  py <- Sys.which("python3")
  skip_if(!nzchar(py), "no python3")
  port <- 19000L + sample.int(900L, 1L)
  script <- tempfile(fileext = ".py")
  writeLines(c(
    "import json, sys, time",
    "from http.server import BaseHTTPRequestHandler, HTTPServer",
    "PORT = int(sys.argv[1])",
    "class H(BaseHTTPRequestHandler):",
    "    def log_message(self, *a): pass",
    "    def do_GET(self):",
    "        p = self.path",
    "        if p.startswith('/go/'):",
    "            self.send_response(302)",
    "            self.send_header('Location', 'http://127.0.0.1:%s/echo' % p[4:])",
    "            self.end_headers(); return",
    "        if p == '/self':",
    "            self.send_response(302); self.send_header('Location', '/echo'); self.end_headers(); return",
    "        if p == '/drip':",
    "            self.send_response(200); self.send_header('Content-Type', 'text/plain'); self.end_headers()",
    "            for i in range(40):",
    "                try: self.wfile.write(b'x'); self.wfile.flush(); time.sleep(2)",
    "                except Exception: return",
    "            return",
    "        if p == '/endless':",
    "            self.send_response(200); self.send_header('Transfer-Encoding', 'chunked'); self.end_headers()",
    "            chunk = b'A' * 65536",
    "            try:",
    "                while True: self.wfile.write(b'%x\\r\\n' % len(chunk) + chunk + b'\\r\\n')",
    "            except Exception: return",
    "        if p == '/missing':",
    "            self.send_response(404); self.send_header('Content-Length', '0'); self.end_headers(); return",
    "        if p == '/url-body':",
    "            body = ('http://127.0.0.1:%d/second' % PORT).encode()",
    "        elif p == '/second':",
    "            body = b'{\"swapped\": true}'",
    "        else:",
    "            body = json.dumps({k.lower(): v for k, v in self.headers.items()}).encode()",
    "        self.send_response(200); self.send_header('Content-Type', 'application/json')",
    "        self.send_header('Content-Length', str(len(body))); self.end_headers(); self.wfile.write(body)",
    "    do_POST = do_GET",
    "HTTPServer(('127.0.0.1', PORT), H).serve_forever()"
  ), script)
  system2(py, c(shQuote(script), port), wait = FALSE, stdout = FALSE, stderr = FALSE)
  withr::defer(suppressWarnings(system2("pkill", c("-f", shQuote(basename(script))), stdout = FALSE, stderr = FALSE)),
               envir = env)
  base <- sprintf("http://127.0.0.1:%d", port)
  up <- FALSE
  for (i in 1:40) {
    up <- isTRUE(r4(".bl_http_get_local")(paste0(base, "/echo"), 2, NULL)$status == 200L)
    if (up) break
    Sys.sleep(0.25)
  }
  skip_if(!up, "the loopback server did not come up")
  list(base = base, port = port)
}
r4_json <- function(res) r4(".rmbl_json_text")(res$body, simplifyVector = FALSE)

test_that("F1: the loopback relaxation is an argument of one call, never a process-wide switch", {
  withr::local_options(rmoriebricklayer.allow_loopback = TRUE)
  # every public-facing entry refuses loopback regardless of the old option
  expect_error(bricklayer_download("http://127.0.0.1:18081/x", tempfile(), quiet = TRUE), "https://")
  expect_error(bricklayer_json_from_json("http://127.0.0.1:18084/x"), "https://")
  expect_error(download_data("https://127.0.0.1/x", tempfile()), "local or private")
  withr::local_options(rmoriebricklayer.allow_http = TRUE)
  expect_error(bricklayer_download("http://127.0.0.1:18081/x", tempfile(), quiet = TRUE), "local or private")
  res <- .Call(r4("C_rmbl_http_download"), "http://127.0.0.1:18081/x", tempfile(), 5L, NULL, NULL, NULL, FALSE)
  expect_identical(res$status, -1L)
  expect_match(res$error, "refused")
  # and the own-endpoint route relaxes nothing for a remote address
  rt_remote <- withr::with_envvar(c(MORIE_LLM_BASE_URL = "https://api.example.org", MORIE_LLM_MODEL = "m"),
                                  r4(".bl_llm_route")("own"))
  expect_false(r4(".bl_loopback_url")(rt_remote$base))
  expect_true(r4(".bl_loopback_url")("http://localhost:11434"))
  expect_true(r4(".bl_loopback_url")("http://127.0.0.1:11434/v1"))
  expect_true(r4(".bl_loopback_url")("http://[::1]:11434"))
  expect_false(r4(".bl_loopback_url")("http://127.0.0.1.evil.example.org/"))
  expect_false(r4(".bl_loopback_url")("https://localhost.example.org/"))
  # a LITERAL private LAN address is local too (diff review D4); link-local, CGNAT,
  # public and named hosts are not
  for (u in c("http://192.168.1.50:1234/v1", "http://10.0.0.5", "http://172.31.9.9:8000/", "http://[fd00::1]:8000")) {
    expect_true(r4(".bl_loopback_url")(u), info = u)
  }
  for (u in c("http://169.254.169.254/", "http://100.64.0.1/", "http://8.8.8.8/", "http://172.32.0.1/",
              "http://192.168.1.50.evil.example.org/", "http://lmstudio.lan:1234/")) {
    expect_false(r4(".bl_loopback_url")(u), info = u)
  }
  # and the compiled policy agrees, under the per-call flag only
  chk <- r4(".rmbl_check_public_url")
  expect_silent(chk("http://192.168.1.50:1234/v1", "x", allow_loopback = TRUE))
  expect_silent(chk("http://[fd12::9]:1234/", "x", allow_loopback = TRUE))
  expect_error(chk("http://192.168.1.50:1234/v1", "x"))
  expect_error(chk("http://169.254.169.254/latest", "x", allow_loopback = TRUE))
  expect_error(chk("http://100.64.0.1/", "x", allow_loopback = TRUE))
  expect_error(chk("http://lmstudio.lan:1234/", "x", allow_http = FALSE, allow_loopback = TRUE), "https://")
})

test_that("F4: 'another origin' compares scheme, host and effective port", {
  rc <- function(from, to) .Call(r4("C_rmbl_redirect_check"), from, to, FALSE, FALSE)
  expect_true(rc("https://a.example.org/x", "https://a.example.org:8443/y")$drop_auth)
  expect_false(rc("https://a.example.org/x", "https://a.example.org:443/y")$drop_auth)
  expect_false(rc("https://a.example.org:443/x", "https://A.example.org/y")$drop_auth)
  expect_true(rc("https://a.example.org/x", "https://b.example.org/y")$drop_auth)
  rcl <- function(from, to) .Call(r4("C_rmbl_redirect_check"), from, to, TRUE, TRUE)
  expect_true(rcl("http://127.0.0.1:18081/x", "http://127.0.0.1:18082/y")$drop_auth)
  expect_false(rcl("http://127.0.0.1:18081/x", "http://127.0.0.1:18081/y")$drop_auth)
})

test_that("F3/F4 live: only content-negotiation headers follow a redirect to another origin", {
  srv <- r4_server()
  hdrs <- c("Authorization: Bearer SECRET-A", "X-Api-Key: SECRET-X", "Cookie: s=SECRET-C",
            "Private-Token: SECRET-P", "Accept: application/json", "Accept-Language: en")
  # same origin: everything travels
  same <- r4_json(r4(".bl_http_get_local")(paste0(srv$base, "/self"), 10, hdrs))
  expect_identical(same[["authorization"]], "Bearer SECRET-A")
  expect_identical(same[["x-api-key"]], "SECRET-X")
  expect_identical(same[["private-token"]], "SECRET-P")
  # another port on the same host is another origin: nothing but negotiation travels
  srv2 <- r4_server()
  other <- r4_json(r4(".bl_http_get_local")(sprintf("%s/go/%d", srv$base, srv2$port), 10, hdrs))
  expect_null(other[["authorization"]])
  expect_null(other[["x-api-key"]])
  expect_null(other[["cookie"]])
  expect_null(other[["private-token"]])
  expect_identical(other[["accept"]], "application/json")
  expect_identical(other[["accept-language"]], "en")
  # the POST seam does the same, and the key never reaches the second origin
  res <- r4(".bl_http_post_local")(sprintf("%s/go/%d", srv$base, srv2$port), charToRaw("{}"), "application/json", 10,
                                   c("Authorization: Bearer SECRET-A", "X-Api-Key: SECRET-X"))
  expect_identical(as.integer(res$status), 200L)
  echoed <- r4_json(res)
  expect_null(echoed[["authorization"]])
  expect_null(echoed[["x-api-key"]])
})

test_that("F2/F6: bytes a server sent are parsed as text, never fetched or opened", {
  jt <- r4(".rmbl_json_text")
  # the URL branch of the public parser would fetch these; the text parser refuses
  testthat::local_mocked_bindings(.rmbl_check_public_url = function(...) stop("must not go near the network"),
                                  .package = "rmoriebricklayer")
  expect_error(jt("http://127.0.0.1:18084/SECOND"), "not JSON")
  expect_error(jt("https://example.org/x.json"), "not JSON")
  expect_error(jt(charToRaw("http://127.0.0.1:1/x")), "not JSON")
  f <- tempfile(fileext = ".json")
  writeLines("{\"a\":1}", f)
  expect_error(jt(f), "not JSON")   # a path is not parsed either
  expect_identical(jt('{"a":1}', simplifyVector = FALSE)$a, 1L)
  expect_identical(jt(charToRaw("[1,2]"), simplifyVector = TRUE), 1:2)
  # a .sig that is a bare URL is "not a signature", and nothing is fetched
  expect_false(r4(".rmbl_services_verify")(charToRaw("{}"), "http://127.0.0.1:18081/SIG-AS-URL"))
  expect_false(r4(".rmbl_services_verify")(charToRaw("{}"), f))
  # every parse of a network body, cached manifest or signature goes through the text parser
  root <- pkg_root_r4()
  if (!is.na(root)) {
    files <- list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE)
    code <- unlist(lapply(files, function(f) paste0(basename(f), ": ", readLines(f, warn = FALSE))))
    code <- sub("#.*$", "", code)   # code, not comments
    expect_identical(grep("bricklayer_json_from_json(rawToChar", code, fixed = TRUE, value = TRUE), character(0))
    expect_identical(grep("bricklayer_json_from_json(paste(readLines(p", code, fixed = TRUE, value = TRUE),
                     character(0))
    expect_identical(grep("bricklayer_json_from_json(paste(", code, fixed = TRUE, value = TRUE), character(0))
  }
})

test_that("F2 live: a body that is a bare URL is returned as text, not followed", {
  srv <- r4_server()
  res <- r4(".bl_http_get_local")(paste0(srv$base, "/url-body"), 10, NULL)
  expect_identical(as.integer(res$status), 200L)
  expect_error(r4(".rmbl_json_text")(res$body), "not JSON")
  # the public parser given the same text as a USER argument would fetch it: that is the
  # documented behaviour for an argument, and it still goes through the validator
  expect_error(bricklayer_json_from_json(rawToChar(res$body)), "https://")
})

test_that("F5: a signed document older than the bundled one is refused, cached or live", {
  td <- withr::local_tempdir()
  testthat::local_mocked_bindings(.rmbl_services_cache_path = function() file.path(td, "morie-services.json"),
                                  .package = "rmoriebricklayer")
  r4(".rmbl_services_forget")()
  withr::defer(r4(".rmbl_services_forget")())
  bundled <- system.file("services", "morie-services.json", package = "rmoriebricklayer")
  b <- r4(".rmbl_services_read")(bundled)
  expect_type(b$issued, "character")
  # stand in for a historical real signature: a test key, and the bundled document re-signed
  # under it with an older issue date, with the pinned key re-bound to that test key
  key <- fips_keygen("ML-DSA-44")
  old_doc <- sub(b$issued, "2020-01-01T00:00:00Z", rawToChar(readBin(bundled, "raw", file.size(bundled))), fixed = TRUE)
  old_doc <- sub("https://llm.rmorie.com", "https://retired-gw.example.net", old_doc, fixed = TRUE)
  sig <- function(doc, k = key) {
    s <- capsule_sign(charToRaw(doc), k, context = "morie-services", deterministic = TRUE)
    sprintf('{"scheme":"ML-DSA-44","context":"morie-services","signature":"%s"}', s$signature)
  }
  # the bundled copy must verify under the test key too, else the floor cannot be read
  bund_doc <- rawToChar(readBin(bundled, "raw", file.size(bundled)))
  bdir <- file.path(td, "bundled")
  dir.create(bdir)
  writeBin(charToRaw(bund_doc), file.path(bdir, "morie-services.json"))  # exact bytes: Windows text mode would add CR
  writeLines(sig(bund_doc), file.path(bdir, "morie-services.sig"))
  testthat::local_mocked_bindings(
    .rmbl_services_pubkey = function() key$public,
    .rmbl_services_bundled_path = function() file.path(bdir, "morie-services.json"),
    .package = "rmoriebricklayer")
  r4(".rmbl_services_write")(file.path(td, "morie-services.json"), charToRaw(old_doc), sig(old_doc))
  Sys.setFileTime(file.path(td, "morie-services.json"), Sys.time() - 1e7)
  s <- bricklayer_services(offline = TRUE)
  expect_identical(attr(s, "source"), "bundled")
  expect_identical(s$llm$base_url, "https://llm.rmorie.com")
  expect_false(file.exists(file.path(td, "morie-services.json")))  # the stale cache is gone
  expect_false(file.exists(file.path(td, "morie-services.sig")))
  # the same date as the bundled copy: the bundled copy serves and the cache stays (a
  # cache earns its place only by being NEWER than what the package ships)
  r4(".rmbl_services_write")(file.path(td, "morie-services.json"), charToRaw(bund_doc), sig(bund_doc))
  r4(".rmbl_services_forget")()
  s <- bricklayer_services(offline = TRUE)
  expect_identical(attr(s, "source"), "bundled")
  expect_true(file.exists(file.path(td, "morie-services.json")))
  unlink(file.path(td, c("morie-services.json", "morie-services.sig")))
  # served live, the same old document is a rollback below the floor
  r4(".rmbl_services_forget")()
  testthat::local_mocked_bindings(.rmbl_net_download = function(url, tmp, timeout) {
    writeBin(charToRaw(if (grepl("[.]sig$", url)) sig(old_doc) else old_doc), tmp)
    200L
  }, .package = "rmoriebricklayer")
  s <- bricklayer_services(refresh = TRUE)
  expect_identical(attr(s, "source"), "bundled")
  expect_false(file.exists(file.path(td, "morie-services.json")))
  # a newer live document still wins
  new_doc <- sub(b$issued, "2099-01-01T00:00:00Z", bund_doc, fixed = TRUE)
  testthat::local_mocked_bindings(.rmbl_net_download = function(url, tmp, timeout) {
    writeBin(charToRaw(if (grepl("[.]sig$", url)) sig(new_doc) else new_doc), tmp)
    200L
  }, .package = "rmoriebricklayer")
  s <- bricklayer_services(refresh = TRUE)
  expect_identical(attr(s, "source"), "live")
  expect_identical(s$issued, "2099-01-01T00:00:00Z")
})

test_that("F7: a key is redacted by value, and by shape, from a gateway's error text", {
  err <- function(text, secret = NULL) {
    tryCatch(r4(".bl_reply_error")(list(status = 400L, json = list(error = text)), "the gateway", secret = secret),
             error = conditionMessage)
  }
  expect_false(grepl("sk-LEAK123456", err("token sk-LEAK123456 rejected", "sk-LEAK123456")))
  expect_false(grepl("sk-LEAK123456", err("token sk-LEAK123456 rejected")))      # the sk- shape alone
  expect_false(grepl("ODD-KEY-9", err("header was Authorization: Bearer ODD-KEY-9", "ODD-KEY-9")))
  expect_false(grepl("ODD-KEY-9", err("header was Authorization: Bearer ODD-KEY-9")))  # the bearer shape alone
  expect_match(err("Rate limit exceeded"), "the gateway answered 400: Rate limit exceeded")
  expect_match(err("Authentication Error, Received API Key = sk-...abcd"), "answered 400: Authentication Error$")
  expect_match(err(list(message = "nested sk-ABCDEFGH gone")), "nested <key> gone")
})

test_that("F8: the sign-in address is validated, and only a public https page is opened", {
  withr::local_envvar(c(MORIE_HOSTED_AUTH_URL = "http://127.0.0.1:18081/auth"))
  expect_error(r4(".bl_hosted_auth")(), "https://")
  withr::local_envvar(c(MORIE_HOSTED_AUTH_URL = "https://169.254.169.254/auth"))
  expect_error(r4(".bl_hosted_auth")(), "local or private")
  withr::local_envvar(c(MORIE_HOSTED_AUTH_URL = "https://auth.example.org/x/"))
  expect_identical(r4(".bl_hosted_auth")(), "https://auth.example.org/x")
  b <- r4(".bl_browsable")
  expect_true(b("https://github.com/login/device"))
  expect_false(b("http://github.com/login/device"))
  expect_false(b("file:///etc/passwd"))
  expect_false(b("javascript:alert(1)"))
  expect_false(b("https://127.0.0.1/"))
  expect_false(b(NULL))
  # the device flow does not hand an odd URI to the browser
  withr::local_envvar(c(XDG_CONFIG_HOME = withr::local_tempdir(), MORIE_HOSTED_KEY = NA, MORIE_HOSTED_AUTH_URL = NA))
  opened <- NULL
  testthat::local_mocked_bindings(browseURL = function(url, ...) {
    opened <<- url
    invisible(NULL)
  }, .package = "utils")
  testthat::local_mocked_bindings(.bl_check_token = function(token) invisible(TRUE), .package = "rmoriebricklayer")
  testthat::local_mocked_bindings(.bl_http_post = function(url, ...) {
    if (grepl("/device/code$", url)) {
      return(list(status = 200L, body = charToRaw(paste0(
        '{"device_code":"d","user_code":"AAAA-1111","verification_uri":"file:///etc/passwd","interval":0}'))))
    }
    list(status = 200L, body = charToRaw('{"api_key":"sk-dev","user":"vee"}'))
  }, .package = "rmoriebricklayer")
  suppressMessages(bricklayer_llm_login(open_browser = TRUE, poll_max_seconds = 5))
  expect_null(opened)
})

test_that("limits live: a trickle is cut off, an endless reply is dropped, a cap holds and leaves no file", {
  srv <- r4_server()
  # a server under 64 bytes/s for 30 s ends the transfer well inside a long timeout
  t0 <- Sys.time()
  res <- r4(".bl_http_get_local")(paste0(srv$base, "/drip"), 120, NULL)
  expect_identical(as.integer(res$status), -1L)
  expect_match(res$error, "too slow|slow")
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 90)
  # an unbounded in-memory reply: status -1 and NO body, with the limit named
  res <- r4(".bl_http_get_local")(paste0(srv$base, "/endless"), 60, NULL)
  expect_identical(as.integer(res$status), -1L)
  expect_identical(length(res$body), 0L)
  expect_match(res$error, "16 MiB")
  # a capped file download: nothing left behind, a sibling part file untouched
  dest <- tempfile()
  writeLines("someone's", paste0(dest, ".rmbl-part"))
  res <- .Call(r4("C_rmbl_http_download"), paste0(srv$base, "/endless"), dest, 60L, NULL, NULL, 1e6, TRUE)
  expect_identical(res$status, -1L)
  expect_match(res$error, "larger than the 1000000-byte limit")
  expect_false(file.exists(dest))
  expect_identical(readLines(paste0(dest, ".rmbl-part")), "someone's")
  expect_length(list.files(dirname(dest), pattern = paste0("^", basename(dest), "\\.rmbl-part\\.")), 0L)
  # and a 2xx body is the only one moved into place
  ok <- .Call(r4("C_rmbl_http_download"), paste0(srv$base, "/echo"), dest, 10L, NULL, NULL, NULL, TRUE)
  expect_identical(ok$status, 200L)
  expect_true(file.exists(dest))
})

test_that("limits: bricklayer_download() exposes max_bytes and checks it", {
  expect_error(bricklayer_download("https://example.org/x", tempfile(), max_bytes = 0, quiet = TRUE),
               "`max_bytes` must be")
  expect_error(bricklayer_download("https://example.org/x", tempfile(), max_bytes = "many", quiet = TRUE),
               "`max_bytes` must be")
  src <- tempfile()
  writeLines("abc", src)
  dest <- tempfile()
  bricklayer_download(paste0("file://", src), dest, quiet = TRUE, allow_file = TRUE, max_bytes = 10)
  expect_identical(readLines(dest), "abc")
})

test_that("the file sink: a chunked body past max_bytes ends the transfer, a non-2xx answer leaves nothing", {
  srv <- r4_server()
  dl <- r4("C_rmbl_http_download")
  dest <- tempfile()
  # no Content-Length: only the sink's own count can stop it (codecov: FileSink overflow)
  r <- .Call(dl, paste0(srv$base, "/endless"), dest, 20L, NULL, NULL, 100000, TRUE)
  expect_false(file.exists(dest))
  expect_match(r$error, "larger than the 100000-byte limit", fixed = TRUE)
  # this destination's own scratch file is gone (an earlier test leaves a foreign .rmbl-part on purpose)
  expect_length(list.files(dirname(dest), pattern = paste0("^", basename(dest), "\\.rmbl-part")), 0L)
  # a 404 is a final answer with nothing to keep: the part file goes, the status comes back
  r <- .Call(dl, paste0(srv$base, "/missing"), dest, 20L, NULL, NULL, NULL, TRUE)
  expect_identical(as.integer(r$status), 404L)
  expect_match(r$error, "HTTP 404", fixed = TRUE)
  expect_false(file.exists(dest))
  # the two one-line network seams run for real against a refused address: a status, never a crash
  expect_false(identical(r4(".rmbl_net_download")("https://127.0.0.1:1/x.json", tempfile(), 2), 200L))
  post <- r4(".rmbl_net_post")("https://127.0.0.1:1/ocsp", raw(0), "application/ocsp-request", 2)
  expect_true(is.null(post) || !identical(as.integer(post$status), 200L))
})
