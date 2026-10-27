# battery: runs in CI and locally; CRAN runs the correctness core
testthat::skip_on_cran()
# Lines of 1.0.0 in src/ the suite had not reached (codecov of 65de2c41), each
# through the entry point it sits behind: escapes in a Wayback answer, a PUT
# replayed on a fresh connection, the C API's snapshot lookup, interrupts
# landing in the bootstrap, Moran's I and the snapshot lookup, the rejection
# step of the bounded draw, and the failures of the operating system a test
# cannot provoke otherwise (no entropy syscall, no IPv6 socket, no libcurl
# handle, an unseekable upload, a scratch file that cannot be reopened): those
# run in a child R with a small LD_PRELOAD library that makes the one call fail
# when RMBL_SHIM names it. Each test names the lines it reaches.

gap_port <- function() 20000L + sample.int(20000L, 1L)

# a child R listening on `port` that runs `body` with `srv` open; helpers there:
# req(con) reads one request's head, with the body its Content-Length gives as
# attribute "body"; say(con, x) writes raw text; acc() accepts
gap_serve <- function(port, body) {
  ready <- tempfile("listening-")
  code <- paste0(
    sprintf(
      "srv <- serverSocket(%dL); on.exit(close(srv)); writeLines('ok', '%s');",
      port,
      ready
    ),
    "req <- function(con) { h <- character(); repeat { l <- ",
    "readLines(con, n = 1L, warn = FALSE);",
    " if (!length(l) || !nzchar(sub('\\\\r$', '', l))) break; h <- c(h, l) };",
    " n <- grep('^content-length:', tolower(h), value = TRUE);",
    " b <- if (length(n)) readChar(con, ",
    "as.integer(sub('^content-length: *', '', n)), useBytes = TRUE) ",
    "else '';",
    " structure(h, body = b) };",
    "say <- function(con, x) { writeChar(x, con, eos = NULL); flush(con) };",
    "acc <- function() socketAccept(srv, blocking = TRUE, open = 'r+b', ",
    "timeout = 30);",
    body
  )
  rscript_bg(code)
  # the child loads the package first: slow on a loaded runner
  wait_files(ready, 120)
}

# a full HTTP/1.1 answer with a JSON body
gap_reply <- function(
  body,
  status = "200 OK",
  extra = character(),
  close = TRUE
) {
  paste0(
    "HTTP/1.1 ",
    status,
    "\r\n",
    if (length(extra)) paste0(extra, "\r\n", collapse = ""),
    "Content-Type: application/json\r\nContent-Length: ",
    nchar(body, "bytes"),
    "\r\n",
    if (close) "Connection: close\r\n",
    "\r\n",
    body
  )
}

# the LD_PRELOAD library, built once per session
gap_shim <- local({
  rec <- new.env()
  rec$so <- NULL
  function() {
    if (!is.null(rec$so)) {
      return(rec$so)
    }
    testthat::skip_on_os(c("windows", "mac"))
    cc <- tryCatch(
      system2(
        file.path(R.home("bin"), "R"),
        c("CMD", "config", "CC"),
        stdout = TRUE,
        stderr = FALSE
      ),
      error = function(e) ""
    )
    cc <- strsplit(trimws(cc[1L]), "[[:space:]]+")[[1L]]
    testthat::skip_if(
      !length(cc) || !nzchar(Sys.which(cc[1L])),
      "no C compiler"
    )
    src <- tempfile(fileext = ".c")
    out <- tempfile(fileext = ".so")
    writeLines(
      c(
        "#define _GNU_SOURCE",
        "#include <dlfcn.h>",
        "#include <errno.h>",
        "#include <stdio.h>",
        "#include <stdlib.h>",
        "#include <string.h>",
        "#include <sys/socket.h>",
        "#include <sys/types.h>",
        paste0(
          "static int on(const char *k) { const char *m = ",
          "getenv(\"RMBL_SHIM\"); return m && strstr(m, k) != NULL; }"
        ),
        "ssize_t getrandom(void *b, size_t n, unsigned int f) {",
        "    static int intr = 0;",
        "    if (on(\"rand_enosys\")) { errno = ENOSYS; return -1; }",
        "    if (on(\"rand_eio\")) { errno = EIO; return -1; }",
        paste0(
          "    if (on(\"rand_eintr\") && !intr) { intr = 1; errno = EINTR; ",
          "return -1; }"
        ),
        "    typedef ssize_t (*fn)(void *, size_t, unsigned int);",
        "    fn real = (fn) dlsym(RTLD_NEXT, \"getrandom\");",
        "    return real(b, n, f);",
        "}",
        "int socket(int d, int t, int p) {",
        paste0(
          "    if (on(\"no_inet6\") && d == AF_INET6) { errno = ",
          "EAFNOSUPPORT; return -1; }"
        ),
        paste0(
          "    int (*real)(int, int, int) = (int (*)(int, int, int)) ",
          "dlsym(RTLD_NEXT, \"socket\");"
        ),
        "    return real(d, t, p);",
        "}",
        "void *curl_easy_init(void) {",
        "    if (on(\"curl_null\")) return NULL;",
        paste0(
          "    /* libcurl came in with the package's DLL, loaded ",
          "RTLD_LOCAL: RTLD_NEXT does not see it */"
        ),
        "    void *lib = dlopen(\"libcurl.so.4\", RTLD_LAZY | RTLD_NOLOAD);",
        paste0(
          "    void *(*real)(void) = lib ? (void *(*)(void)) dlsym(lib, ",
          "\"curl_easy_init\") : NULL;"
        ),
        "    return real ? real() : NULL;",
        "}",
        "int fseeko(FILE *f, off_t o, int w) {",
        paste0(
          "    if (on(\"seek_end\") && w == SEEK_END) { errno = ESPIPE; ",
          "return -1; }"
        ),
        paste0(
          "    int (*real)(FILE *, off_t, int) = (int (*)(FILE *, off_t, ",
          "int)) dlsym(RTLD_NEXT, \"fseeko\");"
        ),
        "    return real(f, o, w);",
        "}",
        "FILE *freopen(const char *p, const char *m, FILE *f) {",
        "    if (on(\"freopen\")) { fclose(f); errno = EACCES; return NULL; }",
        "    typedef FILE *(*fn)(const char *, const char *, FILE *);",
        "    fn real = (fn) dlsym(RTLD_NEXT, \"freopen\");",
        "    return real(p, m, f);",
        "}"
      ),
      src
    )
    res <- suppressWarnings(system2(
      cc[1L],
      c(cc[-1L], "-shared", "-fPIC", "-o", shQuote(out), shQuote(src), "-ldl"),
      stdout = TRUE,
      stderr = TRUE
    ))
    testthat::skip_if(
      !file.exists(out),
      paste("the shim did not build:", paste(res, collapse = " "))
    )
    rec$so <- out
    rec$so
  }
})

# run `code` in a child R with the shim preloaded and RMBL_SHIM = `mode` set
# around `call` only; the child prints `call`'s value with dput()
gap_child <- function(mode, call, setup = "") {
  so <- gap_shim()
  f <- tempfile("shim-", fileext = ".R")
  writeLines(
    c(
      sprintf(
        ".libPaths(strsplit('%s', '%s', fixed = TRUE)[[1]])",
        paste(.libPaths(), collapse = .Platform$path.sep),
        .Platform$path.sep
      ),
      "ns <- asNamespace('rmoriebricklayer')",
      setup,
      sprintf("Sys.setenv(RMBL_SHIM = '%s')", mode),
      sprintf(
        paste(
          "r <- tryCatch(eval(parse(text = %s), new.env(parent = ns)),",
          "error = function(e) paste('ERROR', conditionMessage(e)))"
        ),
        deparse(call)
      ),
      "Sys.unsetenv('RMBL_SHIM')",
      "cat('RESULT', paste(deparse(r), collapse = ' '), '\\n')"
    ),
    f
  )
  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    shQuote(f),
    stdout = TRUE,
    stderr = TRUE,
    env = paste0("LD_PRELOAD=", shQuote(so))
  ))
  got <- grep("^RESULT ", out, value = TRUE)
  if (!length(got)) {
    stop(
      "the child gave no result: ",
      paste(utils::tail(out, 5), collapse = " | ")
    )
  }
  eval(parse(text = sub("^RESULT ", "", got[[1L]])))
}

# ---- rmbl_fetch.cpp: the Wayback snapshot lookup -----------------------------

test_that(
  paste0(
    "a Wayback answer's \\u escapes are decoded, and a malformed one is no ",
    "snapshot"
  ),
  {
    skip_on_os("windows")
    # reaches the \u branch of wayback_snapshot(): one, two and three UTF-8
    # bytes, an uppercase hex digit, and the refusals of a bad digit, a control
    # character, a surrogate and an escape cut off at the end
    pre <- paste0(
      "http:\\/\\/web.archive.org\\/web\\/2024\\/htt",
      "ps:\\/\\/example.org\\/"
    )
    head <- '{"archived_snapshots":{"closest":{"available": true,"url":"'
    bodies <- c(
      paste0(head, pre, '\\u0041\\u00E9\\u20ac"}}}'),
      paste0(head, pre, '\\u00zz"}}}'),
      paste0(head, pre, '\\u0001"}}}'),
      paste0(head, pre, '\\ud800"}}}'),
      paste0(head, pre, "\\u00")
    )
    port <- gap_port()
    skip_if_not(
      gap_serve(
        port,
        paste0(
          "for (x in ",
          paste(deparse(unname(vapply(bodies, gap_reply, ""))), collapse = ""),
          ") { con <- acc(); req(con); say(con, x); close(con) }"
        )
      ),
      "no local server"
    )
    api <- sprintf("http://127.0.0.1:%d", port)
    got <- .Call(C_rmbl_wayback, "https://example.org/", 10L, api)
    expect_identical(
      charToRaw(got),
      c(
        charToRaw("https://web.archive.org/web/2024/https://example.org/A"),
        as.raw(c(0xc3, 0xa9, 0xe2, 0x82, 0xac))
      )
    )
    for (i in 2:5) {
      expect_identical(
        .Call(C_rmbl_wayback, "https://example.org/", 10L, api),
        "",
        info = i
      )
    }
  }
)

test_that(
  paste0(
    "the C API's snapshot lookup fills the ",
    "caller's buffer, cut to its size"
  ),
  {
    skip_on_os("windows")
    # reaches wayback_into() and wayback_raise() (src/rmbl_fetch.cpp), the body
    # of the C API's rmbl_wayback_snapshot(), through C_rmbl_wayback_into: the
    # snapshot whole, cut to `cap` - 1 bytes, and none
    body <- paste0(
      '{"archived_snapshots":{"closest":{"available": ',
      'true,"url":"https://web.archive.org/web/1/x"}}}'
    )
    port <- gap_port()
    answers <- c(gap_reply(body), gap_reply(body), gap_reply("{}"))
    skip_if_not(
      gap_serve(
        port,
        paste0(
          "for (x in ",
          paste(deparse(answers), collapse = ""),
          ") { con <- acc(); req(con); say(con, x); close(con) }"
        )
      ),
      "no local server"
    )
    api <- sprintf("http://127.0.0.1:%d", port)
    whole <- .Call(C_rmbl_wayback_into, "https://example.org/", 10L, api, 256L)
    expect_identical(as.character(whole), "https://web.archive.org/web/1/x")
    expect_identical(attr(whole, "n"), 31L)
    cut <- .Call(C_rmbl_wayback_into, "https://example.org/", 10L, api, 16L)
    expect_identical(as.character(cut), "https://web.arc")
    expect_identical(attr(cut, "n"), 15L)
    none <- .Call(C_rmbl_wayback_into, "https://example.org/", 10L, api, 16L)
    expect_identical(as.character(none), "")
    expect_identical(attr(none, "n"), 0L)
    expect_error(
      .Call(C_rmbl_wayback_into, "https://example.org/", 10L, api, 0L),
      "`cap` must be"
    )
  }
)

test_that("a Ctrl-C during the C API's snapshot lookup is R's interrupt", {
  skip_on_os("windows")
  skip_if(
    !nzchar(Sys.which("python3")) || !nzchar(Sys.which("timeout")),
    "no python3/timeout"
  )
  # reaches wayback_raise()'s interrupt (src/rmbl_fetch.cpp): the availability
  # API listens and never answers, and the lookup would wait its 60 s
  port <- gap_port()
  srv <- tryCatch(serverSocket(port), error = function(e) NULL)
  skip_if(is.null(srv), "no local port")
  on.exit(close(srv), add = TRUE)
  got <- interrupt_probe(sprintf(
    paste0(
      ".Call(rmoriebricklayer:::C_rmbl_wayback_into, ",
      "'https://example.org/', 60L,",
      " 'http://127.0.0.1:%d', 64L)"
    ),
    port
  ))
  skip_if(startsWith(got, "inconclusive"), got)
  expect_identical(got, "interrupt")
})

# ---- rmbl_fetch.cpp: the PUT transport ---------------------------------------

test_that(
  paste0(
    "a PUT replayed on a fresh connection ",
    "sends the file again from its start"
  ),
  {
    skip_on_os("windows")
    # reaches put_seek() (src/rmbl_fetch.cpp): the 307 keeps the connection
    # open, the server drops the second request unanswered, and libcurl replays
    # it on a new connection after rewinding the upload
    f <- tempfile()
    writeLines("the upload, sent three times", f)
    got <- tempfile()
    port <- gap_port()
    redirect <- paste0(
      "HTTP/1.1 307 Temporary Redirect\r\nLocation: http://127.0.0.1:",
      port,
      "/again\r\nContent-Length: 0\r\n\r\n"
    )
    skip_if_not(
      gap_serve(
        port,
        paste0(
          "con <- acc(); req(con); say(con, ",
          deparse(redirect),
          "); req(con); close(con);",
          "con <- acc(); h <- req(con); writeLines(attr(h, 'body'), '",
          got,
          "', sep = '');",
          "say(con, ",
          deparse(gap_reply('{"ok":1}')),
          "); close(con)"
        )
      ),
      "no local server"
    )
    r <- .Call(
      C_rmbl_http_put,
      sprintf("http://127.0.0.1:%d/first", port),
      f,
      "text/plain",
      10L,
      character(),
      TRUE
    )
    expect_identical(r$status, 200L)
    expect_identical(rawToChar(r$body), '{"ok":1}')
    expect_true(wait_files(got, 10))
    expect_identical(readLines(got), "the upload, sent three times")
  }
)

# ---- the operating system's failures, under the LD_PRELOAD shim --------------

test_that(
  paste0(
    "operating-system entropy falls back to /dev/urandom, retries EINTR, ",
    "and reports a failure"
  ),
  {
    # reaches rmbl_os_random()'s ENOSYS fallback to the device, its EINTR retry
    # and its other errors, and C_rmbl_os_random_impl's NULL (src/rmbl_kdf.cpp)
    for (m in c("rand_enosys", "rand_eintr")) {
      r <- gap_child(
        m,
        "{ x <- .Call(C_rmbl_os_random, 64L); c(length(x), length(unique(x))) }"
      )
      expect_identical(r[[1L]], 64L, info = m)
      expect_gt(r[[2L]], 16L)
    }
    expect_null(gap_child("rand_eio", ".Call(C_rmbl_os_random, 16L)"))
  }
)

test_that(
  paste0(
    "an IPv6 address on a host without IPv6 sockets is NA to the connect ",
    "probe"
  ),
  {
    # reaches C_rmbl_net_probe_impl's NA for EAFNOSUPPORT (src/rmbl_fetch.cpp):
    # the probe cannot say whether the policy admits the address
    probe <- paste0(
      ".Call(C_rmbl_net_probe, 'https://example.com/', '%s', FALSE, ",
      "NA)$connect"
    )
    expect_identical(
      gap_child("no_inet6", sprintf(probe, "2001:4860:4860::8888")),
      NA
    )
    expect_true(gap_child("no_inet6", sprintf(probe, "8.8.8.8")))
  }
)

test_that(
  paste0(
    "the PUT transport fails cleanly when the upload's size cannot be read ",
    "or libcurl gives no handle"
  ),
  {
    # reaches http_put_file()'s two early returns after
    # the file is open (src/rmbl_fetch.cpp)
    f <- tempfile()
    writeLines("x", f)
    call <- sprintf(
      paste0(
        ".Call(C_rmbl_http_put, 'https://example.org/x', '%s', ",
        "'text/plain', 5L, character(),",
        " FALSE)[c('status', 'error')]"
      ),
      f
    )
    expect_identical(
      gap_child("seek_end", call),
      list(status = -1L, error = "cannot read the size of the file to upload")
    )
    expect_identical(
      gap_child("curl_null", call),
      list(status = -1L, error = "")
    )
  }
)

test_that(
  paste0(
    "a download whose scratch file cannot be reopened after a redirect is a ",
    "local failure"
  ),
  {
    # reaches http_get_file()'s lost stream (src/rmbl_fetch.cpp): freopen()
    # fails at the redirect, the transfer ends with no sink, and the scratch
    # file is gone
    port <- gap_port()
    redirect <- paste0(
      "HTTP/1.1 302 Found\r\nLocation: http://127.0.0.1:",
      port,
      "/b\r\nContent-Length: 0\r\n",
      "Connection: close\r\n\r\n"
    )
    skip_if_not(
      gap_serve(
        port,
        paste0(
          "con <- acc(); req(con); say(con, ",
          deparse(redirect),
          "); close(con);",
          "con <- acc(); req(con); say(con, ",
          deparse(gap_reply("{}")),
          "); close(con)"
        )
      ),
      "no local server"
    )
    d <- withr::local_tempdir()
    dest <- file.path(d, "out.json")
    r <- gap_child(
      "freopen",
      sprintf(
        paste0(
          ".Call(C_rmbl_http_download, 'http://127.0.0.1:%d/a', '%s', ",
          "10L, NULL,",
          " NULL, NULL, TRUE)"
        ),
        port,
        dest
      )
    )
    expect_identical(r$status, -1L)
    expect_match(r$error, "^cannot write ")
    expect_identical(list.files(d), character())
  }
)

# ---- interrupts that land in a kernel ----------------------------------------

test_that(
  paste0(
    "a Ctrl-C during the bootstrap and during Moran's I permutations is R's ",
    "interrupt"
  ),
  {
    skip_on_os("windows")
    skip_if(
      !nzchar(Sys.which("python3")) || !nzchar(Sys.which("timeout")),
      "no python3/timeout"
    )
    # reaches rmbl_bootstrap_mean()'s stop (src/rmbl_core.cpp: the replicates
    # not drawn are NaN) and the permutation
    # loop's stop in C_rmbl_morans_i_impl (src/rmbl_series.cpp)
    got <- interrupt_probe(
      paste0(
        ".Call(rmoriebricklayer:::C_rmbl_bootstrap_mean, ",
        "as.numeric(1:200000), 1e6, 1)"
      )
    )
    skip_if(startsWith(got, "inconclusive"), got)
    expect_identical(got, "interrupt")
    ring <- paste0(
      "n <- 4000L; x <- sin(seq_len(n));",
      " idx <- as.integer(rbind(seq_len(n) %% n, (seq_len(n) - 2L) %% n));",
      " .Call(rmoriebricklayer:::C_rmbl_morans_i, x, idx, ",
      "as.integer(seq(0L, 2L * n - 2L, 2L)),",
      " rep(2L, n), rep(1, 2L * n), 100000000L, NULL)"
    )
    got <- interrupt_probe(ring)
    skip_if(startsWith(got, "inconclusive"), got)
    expect_identical(got, "interrupt")
  }
)

# ---- morie_core.h: the bounded draw ------------------------------------------

test_that("the bounded draw rejects the products that would bias it", {
  # reaches bounded_draw()'s rejection step (src/morie_core.h), which an index
  # bound below 2^40 meets once in 2^24 draws or less. For s = 3 * 2^62 the
  # plain multiply-shift hits each value divisible by 3 twice as often as the
  # rest (a share of 1/2, not 1/3); the rejection removes exactly the extra
  # preimage. The draws come back as 8 little-endian bytes; 256 = 1 (mod 3), so
  # a value mod 3 is the sum of its bytes mod 3.
  s <- 3 * 2^62
  k <- 30000L
  b <- .Call(C_rmbl_bounded_draw, 7, s, k)
  expect_length(b, 8L * k)
  m <- matrix(as.integer(b), nrow = 8L)
  expect_true(all(m[8L, ] < 0xC0)) # every draw is below s = 0xC000000000000000
  share0 <- mean(colSums(m) %% 3L == 0L)
  expect_lt(abs(share0 - 1 / 3), 0.02)
  expect_identical(.Call(C_rmbl_bounded_draw, 7, s, 5L), b[seq_len(40L)])
  # [0, 1) has one value
  expect_identical(.Call(C_rmbl_bounded_draw, 7, 1, 3L), raw(24))
  expect_error(.Call(C_rmbl_bounded_draw, 7, 2^64, 1L), "`s` must be")
  expect_error(.Call(C_rmbl_bounded_draw, -1, 2, 1L), "`seed` must be")
  expect_error(.Call(C_rmbl_bounded_draw, 1, 2, 1.5), "`n` must be")
})

# ---- rmbl_pqc.cpp ------------------------------------------------------------

test_that(
  paste0(
    "an XMSS authentication path of the wrong length for the tree is a ",
    "refusal"
  ),
  {
    # reaches C_rmbl_xmss_verify_impl's check of the path against the height
    # (src/rmbl_pqc.cpp): a well-formed one-time signature with three nodes
    # where a height-4 tree needs four
    wots <- strrep("00", 67L * 32L)
    expect_false(.Call(
      C_rmbl_xmss_verify,
      strrep("00", 32),
      strrep("00", 32),
      4L,
      0L,
      as.raw(1),
      wots,
      strrep("00", 3L * 32L),
      strrep("00", 32)
    ))
  }
)

# ---- R/policy_plots.R --------------------------------------------------------

test_that(
  paste0(
    "plotevgrid() draws a panel whose plot method returns no table, and ",
    "leaves it out"
  ),
  {
    # reaches plotevgrid()'s NULL for a panel whose plot() gives no data frame:
    # a subclass of an event study with its own plot method
    registerS3method(
      "plot",
      "rmbl_gap_study",
      function(x, ...) {
        graphics::plot.new()
        invisible(NULL)
      },
      envir = asNamespace("graphics")
    )
    p <- polex()
    es <- evstudy(
      p,
      "district",
      "month",
      "crmrate",
      "refmonth",
      leads = 2,
      lags = 2
    )
    sub <- structure(es, class = c("rmbl_gap_study", class(es)))
    grDevices::pdf(NULL)
    on.exit(grDevices::dev.off(), add = TRUE)
    out <- plotevgrid(list(a = es, b = sub))
    expect_identical(unique(out$panel), "a")
    expect_identical(nrow(out), nrow(plot(es)))
  }
)
