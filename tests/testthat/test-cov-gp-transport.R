# SPDX-License-Identifier: AGPL-3.0-or-later
# The native transport's redirect and progress paths (src/rmbl_fetch.cpp)
# against a loopback server: a redirect loop, a hop to another origin that
# must leave the caller's own headers behind, a progress callback that fails.

gp_serve <- function(env = parent.frame()) {
  py <- Sys.which("python3")
  testthat::skip_if(!nzchar(py), "no python3 to serve loopback pages")
  testthat::skip_on_os("windows")
  script <- tempfile(fileext = ".py")
  writeLines(
    c(
      "import http.server, threading, sys, os, signal",
      "signal.alarm(30)",
      "p1, p2, ready = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]",
      "class H(http.server.BaseHTTPRequestHandler):",
      "    def log_message(self, *a): pass",
      "    def reply(self, code, body=b'', loc=None):",
      "        self.send_response(code)",
      "        if loc: self.send_header('Location', loc)",
      "        self.send_header('Content-Length', str(len(body)))",
      "        self.end_headers()",
      "        self.wfile.write(body)",
      "    def do_GET(self):",
      "        if self.path.startswith('/loop/'):",
      "            n = int(self.path.split('/')[2])",
      "            self.reply(302, loc='/loop/%d' % (n + 1))",
      "        elif self.path == '/hop':",
      "            self.reply(302, loc='http://127.0.0.1:%d/echo' % p2)",
      "        elif self.path == '/echo':",
      "            ks = (k.lower() for k in self.headers.keys())",
      "            self.reply(200, '\\n'.join(ks).encode())",
      "        elif self.path == '/data':",
      "            self.reply(200, b'x' * 200000)",
      "        else:",
      "            self.reply(404)",
      "s1 = http.server.ThreadingHTTPServer(('127.0.0.1', p1), H)",
      "s2 = http.server.ThreadingHTTPServer(('127.0.0.1', p2), H)",
      "threading.Thread(target=s2.serve_forever, daemon=True).start()",
      "open(ready + '.tmp', 'w').write(str(os.getpid()))",
      "os.rename(ready + '.tmp', ready)",
      "s1.serve_forever()"
    ),
    script
  )
  p1 <- 21000L + sample.int(20000L, 1L)
  p2 <- p1 + 1L
  ready <- tempfile("gp-ready-")
  system2(
    py,
    c(shQuote(script), p1, p2, shQuote(ready)),
    wait = FALSE,
    stdout = FALSE,
    stderr = FALSE
  )
  for (i in 1:50) {
    if (file.exists(ready)) {
      break
    }
    Sys.sleep(0.1)
  }
  testthat::skip_if(!file.exists(ready), "the loopback server did not come up")
  pid <- as.integer(readLines(ready, warn = FALSE))
  withr::defer(
    {
      tools::pskill(pid)
      unlink(c(script, ready))
    },
    envir = env
  )
  sprintf("http://127.0.0.1:%d", p1)
}

test_that("a redirect loop stops after five hops", {
  base <- gp_serve()
  r <- .Call(C_rmbl_http_get, file.path(base, "loop", "0"), 10L, NULL, TRUE)
  expect_identical(r$status, -1L)
  expect_match(r$error, "too many redirects", fixed = TRUE)
})

test_that("a hop to another origin leaves the caller's own headers behind", {
  base <- gp_serve()
  dest <- tempfile()
  withr::defer(unlink(dest))
  # a download, not an API call: it may follow a hop to another origin
  r <- .Call(
    C_rmbl_http_download,
    file.path(base, "hop"),
    dest,
    10L,
    c("X-Api-Key: secret", "Accept: text/plain", "Accept-Language: en"),
    NULL,
    NULL,
    TRUE
  )
  expect_identical(r[[1L]], 200L, info = r[[3L]])
  got <- trimws(readLines(dest, warn = FALSE))
  expect_false("x-api-key" %in% got)
  expect_true("accept" %in% got)
  expect_true("accept-language" %in% got)
})

test_that("a progress callback that fails ends the download", {
  base <- gp_serve()
  dest <- tempfile()
  withr::defer(unlink(dest))
  r <- .Call(
    C_rmbl_http_download,
    file.path(base, "data"),
    dest,
    10L,
    NULL,
    function(now, total) stop("the bar broke"),
    NULL,
    TRUE
  )
  expect_lt(r[[1L]], 0L)
  expect_false(file.exists(dest))
})
