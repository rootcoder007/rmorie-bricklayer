# The signed service document: what the packages trust about the hosted tier
# and how they fall back when the site cannot be reached or does not verify.

svc_ns <- function(nm) get(nm, envir = asNamespace("rmoriebricklayer"))

# A key of the tests' own, and a document signed with it.
svc_key <- fips_keygen("ML-DSA-44")
svc_doc <- function(issued = "2026-10-06T12:00:00Z", llm_mode = "key", data_mode = "key",
                    base = "https://gw.example.org", version = 1L, data_base = "https://tables.example.org") {
  auth <- if (nzchar(base)) paste0(base, "/auth") else ""
  sprintf(paste0(
    '{"version":%d,"issued":"%s","notice":"test notice",',
    '"llm":{"mode":"%s","base_url":"%s","auth_url":"%s","default_model":"test-model:cloud",',
    '"models":["test-model:cloud","other:cloud"],"request_access":"https://rmorie.com/access"},',
    '"data":{"mode":"%s","base_url":"%s","license":"https://rmorie.com/data-license",',
    '"request_access":"https://rmorie.com/access"}}'),
    version, issued, llm_mode, base, auth, data_mode, data_base)
}
svc_sign <- function(doc, key = svc_key, context = "morie-services", scheme = "ML-DSA-44") {
  sig <- capsule_sign(charToRaw(doc), key, context = context, deterministic = TRUE)
  sprintf('{"scheme":"%s","context":"%s","signature":"%s"}', scheme, context, sig$signature)
}
# Serve `pairs` (url -> file content) through the download seam; anything else is a 404.
svc_server <- function(pairs) {
  function(url, tmp, timeout) {
    if (!url %in% names(pairs)) return(404L)
    writeBin(charToRaw(pairs[[url]]), tmp)
    200L
  }
}
svc_url <- svc_ns(".rmbl_services_url")
svc_sig_url <- sub("[.]json$", ".sig", svc_url)
# every test starts from an empty cache, its own key and no memo
svc_setup <- function(env = parent.frame(), key = svc_key$public) {
  force(key)  # evaluated before the mock below, else the pinned-key test calls its own mock
  td <- withr::local_tempdir(.local_envir = env)
  withr::local_envvar(c(MORIE_SERVICES_URL = NA, MORIE_HOSTED_BASE_URL = NA, MORIE_HOSTED_KEY = NA,
                        MORIE_HOSTED_AUTH_URL = NA, MORIE_HOSTED_MODEL = NA, MORIE_DATA_URL = NA,
                        MORIE_LLM_BASE_URL = NA, OLLAMA_HOST = "off",
                        XDG_CONFIG_HOME = withr::local_tempdir(.local_envir = env)),
                      .local_envir = env)
  testthat::local_mocked_bindings(
    .rmbl_services_pubkey = function() key,
    .rmbl_services_cache_path = function() file.path(td, "morie-services.json"),
    .package = "rmoriebricklayer", .env = env)
  svc_ns(".rmbl_services_forget")()
  withr::defer(svc_ns(".rmbl_services_forget")(), envir = env)
  td
}

test_that("the bundled document verifies with the pinned key and names the hosted services", {
  td <- svc_setup(key = svc_ns(".rmbl_services_pubkey")())
  s <- bricklayer_services(offline = TRUE)
  expect_identical(attr(s, "source"), "bundled")
  expect_identical(s$version, 1L)
  expect_identical(s$llm$mode, "key")
  expect_identical(s$llm$base_url, "https://llm.rmorie.com")
  expect_identical(s$llm$auth_url, "https://llm.rmorie.com/auth")
  expect_identical(s$llm$default_model, "minimax-m3:cloud")
  expect_true(s$llm$default_model %in% s$llm$models)
  expect_identical(s$data$mode, "key")
  expect_identical(s$data$base_url, "https://data.rmorie.com")
  expect_match(s$notice, "last resort")
  expect_match(s$llm$request_access, "^https://rmorie.com/")
  # the bundled signature is over exactly these bytes: one changed byte fails
  p <- system.file("services", "morie-services.json", package = "rmoriebricklayer")
  bytes <- readBin(p, "raw", file.size(p))
  sig <- paste(readLines(sub("[.]json$", ".sig", p), warn = FALSE), collapse = "\n")
  expect_true(svc_ns(".rmbl_services_verify")(bytes, sig))
  bytes[length(bytes) - 1L] <- as.raw(0x20)
  expect_false(svc_ns(".rmbl_services_verify")(bytes, sig))
  # and the hosted helpers read this document
  expect_identical(svc_ns(".bl_hosted_base")(), "https://llm.rmorie.com")
  expect_identical(svc_ns(".bl_hosted_auth")(), "https://llm.rmorie.com/auth")
  expect_identical(svc_ns(".bl_hosted_model")(), "minimax-m3:cloud")
  expect_identical(svc_ns(".bl_data_url")(), "https://data.rmorie.com")
})

test_that("a live document is verified, cached, and then served from the cache", {
  td <- svc_setup()
  doc <- svc_doc()
  testthat::local_mocked_bindings(
    .rmbl_net_download = svc_server(stats::setNames(list(doc, svc_sign(doc)), c(svc_url, svc_sig_url))),
    .package = "rmoriebricklayer")
  s <- bricklayer_services()
  expect_identical(attr(s, "source"), "live")
  expect_identical(s$llm$base_url, "https://gw.example.org")
  expect_identical(s$llm$models, c("test-model:cloud", "other:cloud"))
  expect_true(file.exists(file.path(td, "morie-services.json")))
  expect_true(file.exists(file.path(td, "morie-services.sig")))
  expect_identical(readBin(file.path(td, "morie-services.json"), "raw", 1e6), charToRaw(doc))
  # fresh cache: no fetch at all
  testthat::local_mocked_bindings(.rmbl_net_download = function(...) stop("must not fetch"),
                                  .package = "rmoriebricklayer")
  s2 <- bricklayer_services()
  expect_identical(attr(s2, "source"), "cache")
  expect_identical(s2$llm, s$llm)
  # the hosted helpers follow the document, not the old constants
  expect_identical(svc_ns(".bl_hosted_base")(), "https://gw.example.org")
  expect_identical(svc_ns(".bl_hosted_auth")(), "https://gw.example.org/auth")
  expect_identical(svc_ns(".bl_hosted_model")(), "test-model:cloud")
  expect_identical(svc_ns(".bl_data_url")(), "https://tables.example.org")
  # env overrides still win over the document
  withr::local_envvar(c(MORIE_HOSTED_BASE_URL = "https://mine.example.org/",
                        MORIE_HOSTED_MODEL = "local:latest", MORIE_DATA_URL = "https://d.example.org"))
  expect_identical(svc_ns(".bl_hosted_base")(), "https://mine.example.org")
  expect_identical(svc_ns(".bl_hosted_model")(), "local:latest")
  expect_identical(svc_ns(".bl_data_url")(), "https://d.example.org")
  withr::local_envvar(c(MORIE_HOSTED_BASE_URL = "off"))
  expect_null(svc_ns(".bl_hosted_base")())
})

test_that("a stale cache is refreshed; an older live document is a rollback and is ignored", {
  td <- svc_setup()
  old <- svc_doc(issued = "2026-10-01T00:00:00Z", base = "https://old.example.org")
  svc_ns(".rmbl_services_write")(file.path(td, "morie-services.json"), charToRaw(old), svc_sign(old))
  Sys.setFileTime(file.path(td, "morie-services.json"), Sys.time() - 3 * 86400)
  newer <- svc_doc(issued = "2026-10-05T00:00:00Z", base = "https://new.example.org")
  testthat::local_mocked_bindings(
    .rmbl_net_download = svc_server(stats::setNames(list(newer, svc_sign(newer)), c(svc_url, svc_sig_url))),
    .package = "rmoriebricklayer")
  s <- bricklayer_services()
  expect_identical(attr(s, "source"), "live")
  expect_identical(s$llm$base_url, "https://new.example.org")
  # now an "update" that is older than what is held
  older <- svc_doc(issued = "2026-09-01T00:00:00Z", base = "https://rollback.example.org")
  testthat::local_mocked_bindings(
    .rmbl_net_download = svc_server(stats::setNames(list(older, svc_sign(older)), c(svc_url, svc_sig_url))),
    .package = "rmoriebricklayer")
  s <- bricklayer_services(refresh = TRUE)
  expect_identical(attr(s, "source"), "cache")
  expect_identical(s$llm$base_url, "https://new.example.org")
  expect_identical(svc_ns(".rmbl_services_read")(file.path(td, "morie-services.json"))$llm$base_url,
                   "https://new.example.org")
})

test_that("a document that does not verify is ignored at every step", {
  td <- svc_setup()
  doc <- svc_doc()
  bad <- list(
    other_key = svc_sign(doc, key = fips_keygen("ML-DSA-44")),
    other_context = svc_sign(doc, context = "morie-services-v2"),
    other_scheme = sub("ML-DSA-44", "ML-DSA-65", svc_sign(doc), fixed = TRUE),
    tampered = svc_sign(sub("gw.example.org", "evil.example.org", doc, fixed = TRUE)),
    not_json = "not a signature",
    empty = ""
  )
  for (nm in names(bad)) {
    expect_false(svc_ns(".rmbl_services_verify")(charToRaw(doc), bad[[nm]]), info = nm)
    testthat::local_mocked_bindings(
      .rmbl_net_download = svc_server(stats::setNames(list(doc, bad[[nm]]), c(svc_url, svc_sig_url))),
      .package = "rmoriebricklayer")
    svc_ns(".rmbl_services_forget")()
    s <- bricklayer_services(refresh = TRUE)
    # the bundled copy is signed with the real key, not this test's: nothing is left but "off"
    expect_identical(attr(s, "source"), "off", info = nm)
    expect_identical(s$llm$mode, "off", info = nm)
    expect_false(file.exists(file.path(td, "morie-services.json")), info = nm)
  }
  # with every service off the hosted helpers say so and nothing is called
  expect_null(svc_ns(".bl_hosted_base")())
  expect_error(svc_ns(".bl_data_url")(), "not available right now.*rmorie.com/access")
  expect_match(agent_bundle("x"), "hosted MORIE tier: disabled (switched off in the services document", fixed = TRUE)
  expect_match(agent_bundle("x"), "rmorie.com/access")
  expect_match(svc_ns(".bl_hosted_off_reason")(), "^switched off in the services document")
  # the fetch itself: a 404, a missing signature, an empty body
  for (pairs in list(list(), stats::setNames(list(doc), svc_url),
                     stats::setNames(list("", svc_sign(doc)), c(svc_url, svc_sig_url)))) {
    testthat::local_mocked_bindings(.rmbl_net_download = svc_server(pairs), .package = "rmoriebricklayer")
    expect_null(svc_ns(".rmbl_services_fetch")(5))
  }
  # a mirror URL that is not a public https address is refused before any fetch
  withr::local_envvar(c(MORIE_SERVICES_URL = "http://127.0.0.1/morie-services.json"))
  testthat::local_mocked_bindings(.rmbl_net_download = function(...) stop("must not fetch"),
                                  .package = "rmoriebricklayer")
  expect_null(svc_ns(".rmbl_services_fetch")(5))
})

test_that("the parser accepts only a v1 document with sane modes, dates and URLs", {
  parse <- function(txt) svc_ns(".rmbl_services_parse")(charToRaw(txt))
  expect_type(parse(svc_doc()), "list")
  expect_null(parse(svc_doc(version = 2L)))
  expect_null(parse(svc_doc(llm_mode = "anonymous")))
  expect_null(parse(svc_doc(data_mode = "open")))
  expect_null(parse(svc_doc(issued = "yesterday")))
  expect_null(parse(svc_doc(base = "http://gw.example.org")))
  expect_null(parse(svc_doc(base = "https://10.0.0.1")))
  expect_null(parse(svc_doc(data_base = "https://user:pw@tables.example.org")))
  expect_null(parse("[]"))
  expect_null(parse("{\"version\":1}"))
  expect_null(parse("{not json"))
  # "off" with empty URLs is a complete, valid document
  off <- parse(svc_doc(llm_mode = "off", data_mode = "off", base = "", data_base = ""))
  expect_identical(off$llm$mode, "off")
  expect_identical(off$llm$models, c("test-model:cloud", "other:cloud"))
})

test_that("the offline memo is per session and a refresh replaces it", {
  td <- svc_setup()
  doc <- svc_doc()
  testthat::local_mocked_bindings(
    .rmbl_net_download = svc_server(stats::setNames(list(doc, svc_sign(doc)), c(svc_url, svc_sig_url))),
    .package = "rmoriebricklayer")
  expect_identical(attr(bricklayer_services(offline = TRUE), "source"), "off")
  # memoised: still "off" without a refresh ...
  expect_identical(attr(bricklayer_services(offline = TRUE), "source"), "off")
  # ... until something asks the site
  expect_identical(attr(bricklayer_services(), "source"), "live")
  expect_identical(attr(bricklayer_services(offline = TRUE), "source"), "live")
  expect_identical(svc_ns(".bl_hosted_base")(), "https://gw.example.org")
})

test_that("bricklayer_services() argument checks", {
  expect_error(bricklayer_services(max_age = -1), "`max_age` must be")
  expect_error(bricklayer_services(timeout = 0), "`timeout` must be")
  expect_error(bricklayer_services(refresh = NA), "`refresh` must be TRUE or FALSE")
  expect_error(bricklayer_services(offline = "yes"), "`offline` must be TRUE or FALSE")
})
