# The terms and profile step before a new key: the terms are accepted (y/N or
# accept_terms = TRUE), a name and a reason are given. Schedule B (the
# restricted tables, with a supervisor) is no longer offered: no table is
# served under further terms.

answers <- function(...) {
  a <- c(...)
  cnt <- new.env(parent = emptyenv())
  cnt$i <- 0L
  function(prompt, ...) {
    cnt$i <- cnt$i + 1L
    if (cnt$i <= length(a)) a[[cnt$i]] else ""
  }
}
terms_reply <- function(json, status = 200L) {
  function(url, timeout, headers) list(status = status, body = charToRaw(json))
}

test_that("the terms version and address come from the sign-in service", {
  box <- new.env(parent = emptyenv())
  box$seen <- NULL
  local_mocked_bindings(.bl_http_get = function(url, timeout, headers) {
    box$seen <- url
    list(
      status = 200L,
      body = charToRaw(
        '{"version":"2026-10-16","url":"https://data.example/terms"}'
      )
    )
  })
  t <- .bl_terms_info("https://data.example/auth")
  expect_identical(box$seen, "https://data.example/terms.json")
  expect_identical(
    t,
    list(version = "2026-10-16", url = "https://data.example/terms")
  )
  # no url in the reply: the terms page next to the service
  local_mocked_bindings(.bl_http_get = terms_reply('{"version":"2026-10-16"}'))
  expect_identical(
    .bl_terms_info("https://data.example/auth")$url,
    "https://data.example/terms"
  )
})

test_that("terms that cannot be read stop the sign-in", {
  local_mocked_bindings(.bl_http_get = terms_reply("{}", 503L))
  expect_error(
    .bl_terms_info("https://data.example/auth"),
    "could not read the data access terms"
  )
  local_mocked_bindings(.bl_http_get = terms_reply('{"version":"latest"}'))
  expect_error(
    .bl_terms_info("https://data.example/auth"),
    "could not read the data access terms"
  )
  local_mocked_bindings(.bl_http_get = function(...) stop("no network"))
  expect_error(
    .bl_terms_info("https://data.example/auth"),
    "https://data.example/terms.json"
  )
})

test_that("an email address is checked before anything is asked", {
  expect_error(.bl_check_email(""), "an email address is required")
  expect_error(.bl_check_email(NA_character_), "an email address is required")
  expect_error(.bl_check_email("nope"), "'nope' is not an email address")
  expect_identical(.bl_check_email(" Ada@Example.org "), "ada@example.org")
})

test_that("terms not accepted at the prompt: no key, and how to accept", {
  local_mocked_bindings(
    .bl_terms_info = function(...) {
      list(version = "2026-10-16", url = "https://data.example/terms")
    },
    .bl_readline = answers("n")
  )
  expect_message(
    expect_error(
      .bl_signin_profile(),
      "were not accepted, so no key was issued.*--accept-terms"
    ),
    "Data access terms, version 2026-10-16"
  )
})

test_that(
  paste0(
    "an accepted sign-in asks for name, ",
    "organisation and reason, and not for Schedule B"
  ),
  {
    box <- new.env(parent = emptyenv())
    box$seen <- character()
    local_mocked_bindings(
      .bl_terms_info = function(...) list(version = "2026-10-16", url = "u")
    )
    local_mocked_bindings(.bl_readline = function(prompt, ...) {
      box$seen <- c(box$seen, prompt)
      c(
        "YES",
        "Ada Lovelace",
        "",
        "Course project on court delays in Ontario."
      )[[length(box$seen)]]
    })
    p <- suppressMessages(.bl_signin_profile())
    expect_length(box$seen, 4L)
    expect_false(any(grepl("Schedule B|restricted", box$seen)))
    expect_identical(p$accept_terms, "2026-10-16")
    expect_identical(p$name, "Ada Lovelace")
    expect_null(p$affiliation)
    expect_identical(p$purpose, "Course project on court delays in Ontario.")
    expect_false(p$accept_restricted)
    expect_match(p$client, "^rmoriebricklayer/")
    expect_null(p$supervisor_name)
  }
)

test_that("a name and a reason are required", {
  local_mocked_bindings(
    .bl_terms_info = function(...) list(version = "2026-10-16", url = "u"),
    .bl_readline = answers("")
  )
  expect_error(
    .bl_signin_profile(accept_terms = TRUE),
    "your name is needed for a key: pass --name"
  )
  expect_error(
    .bl_signin_profile(
      accept_terms = TRUE,
      name = "Ada",
      purpose = "too short"
    ),
    "the reason you need the data.*--reason"
  )
})

test_that(
  paste0(
    "the Schedule B arguments of older releases warn and are ignored: ",
    "no supervisor is asked for or sent"
  ),
  {
    local_mocked_bindings(
      .bl_terms_info = function(...) list(version = "2026-10-16", url = "u"),
      .bl_readline = answers("")
    )
    base <- list(
      accept_terms = TRUE,
      name = "Ada",
      affiliation = "Uni",
      purpose = "Thesis chapter on court delays in Ontario.",
      restricted = TRUE
    )
    nb <- "no table is opened by accepting more terms any more"
    expect_warning(p <- do.call(.bl_signin_profile, base), nb)
    expect_false(p$accept_restricted)
    expect_warning(
      p <- do.call(
        .bl_signin_profile,
        c(
          base[-5L],
          supervisor_name = "Dr B",
          supervisor_role = "Chair",
          supervisor_email = "B@Uni.example"
        )
      ),
      nb
    )
    expect_false(p$accept_restricted)
    expect_identical(p$affiliation, "Uni")
    expect_false(any(grepl("^supervisor", names(p))))
    expect_no_warning(
      do.call(.bl_signin_profile, c(base[-5L], restricted = FALSE))
    )
  }
)

test_that(
  paste0(
    "Schedule B is not offered at the prompt any more, nor a supervisor ",
    "asked for"
  ),
  {
    local_mocked_bindings(
      .bl_terms_info = function(...) list(version = "2026-10-16", url = "u"),
      .bl_readline = answers(
        "Ada",
        "Uni",
        "Thesis chapter on court delays in Ontario.",
        "y",
        "Dr B",
        "director",
        "b@uni.example"
      )
    )
    p <- .bl_signin_profile(accept_terms = TRUE)
    expect_false(p$accept_restricted)
    expect_null(p$supervisor_role)
    expect_identical(p$purpose, "Thesis chapter on court delays in Ontario.")
  }
)

test_that(
  paste0(
    "the profile goes with the sign-in request, and a bad address stops ",
    "before it is asked"
  ),
  {
    box <- new.env(parent = emptyenv())
    box$posted <- list()
    local_mocked_bindings(
      .bl_signin_profile = function(...) {
        list(accept_terms = "2026-10-16", name = "Ada")
      },
      .bl_post_json = function(url, payload, ...) {
        box$posted[[length(box$posted) + 1L]] <- list(
          url = url,
          payload = payload
        )
        list(status = 503L, json = list(error = "down"), error = "")
      }
    )
    expect_error(dlogin(email = "not-an-address"), "is not an email address")
    expect_length(box$posted, 0L)
    expect_error(dlogin(email = "ada@example.org"), "503")
    expect_identical(
      box$posted[[1L]]$payload,
      list(email = "ada@example.org", accept_terms = "2026-10-16", name = "Ada")
    )
    expect_error(dlogin(openbro = FALSE), "503")
    expect_match(box$posted[[2L]]$url, "/device/code$")
    expect_identical(
      box$posted[[2L]]$payload,
      list(accept_terms = "2026-10-16", name = "Ada")
    )
  }
)

test_that("rmbl login passes the terms and profile flags through", {
  box <- new.env(parent = emptyenv())
  box$got <- NULL
  local_mocked_bindings(dlogin = function(...) {
    box$got <- list(...)
    invisible("k")
  })
  box2 <- new.env(parent = emptyenv())
  box2$buf <- character()
  st <- blcli(
    c(
      "login",
      "--accept-terms",
      "--name",
      "Ada Lovelace",
      "--affiliation",
      "Uni",
      "--reason",
      "Thesis chapter on court delays."
    ),
    out = function(x) box2$buf <- c(box2$buf, x)
  )
  expect_identical(st, 0L)
  expect_true(box$got$accter)
  expect_identical(
    box$got[c("name", "affil", "purp")],
    list(
      name = "Ada Lovelace",
      affil = "Uni",
      purp = "Thesis chapter on court delays."
    )
  )
  expect_null(box$got$restr)
  # --restricted and the supervisor flags are no longer options
  for (f in c("--restricted", "--supervisor-name")) {
    expect_identical(
      blcli(c("login", f, "x"), out = function(x) NULL),
      2L
    )
  }
  blcli(c("login", "--no-browser"), out = function(x) NULL)
  expect_false(box$got$accter)
  expect_null(box$got$restr)
  box3 <- new.env(parent = emptyenv())
  box3$usage <- character()
  blcli(c("login", "--help"), out = function(x) box3$usage <- c(box3$usage, x))
  expect_match(paste(box3$usage, collapse = ""), "--accept-terms")
  expect_false(grepl("restricted|supervisor", paste(box3$usage, collapse = "")))
})
