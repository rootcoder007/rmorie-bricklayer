# Clean-user smoke for rmoriebricklayer: every `rmoriebricklayer` verb and the data
# client run for real in an empty HOME. Rscript inst/smoke/smoke.R (package installed).
tree <- Sys.getenv("MORIE_SMOKE_TREE", "")
if (nzchar(tree)) suppressPackageStartupMessages(pkgload::load_all(tree, quiet = TRUE)) else suppressPackageStartupMessages(library(rmoriebricklayer))
home <- tempfile("bl-smoke-"); dir.create(home); setwd(home)
Sys.setenv(HOME = home, XDG_CONFIG_HOME = file.path(home, "cfg"))
key <- Sys.getenv("MORIE_SMOKE_KEY", "")
if (nzchar(key)) Sys.setenv(MORIE_HOSTED_KEY = key) else Sys.unsetenv("MORIE_HOSTED_KEY")
options(timeout = 600)
run <- function(...) { buf <- character(); st <- blcli(c(...), out = function(s) buf <<- c(buf, s)); list(status = st, text = paste(buf, collapse = "")) }
check <- function(cond, what) if (!isTRUE(cond)) stop(what, call. = FALSE)
# a runner has no language model of its own: with none set up, models and ask must say how to bring one
no_route <- function(r) r$status == 1L && grepl("bring your own key", r$text, fixed = TRUE)
cases <- list(
  version = function() { r <- run("version"); check(r$status == 0 && grepl("rmoriebricklayer", r$text), r$text) },
  # NA or a function as the command line is refused by name, not failed in R's words
  args = function() {
    for (a in list(NA_character_, function() 1)) {
      e <- tryCatch(blcli(a), error = conditionMessage)
      check(is.character(e) && startsWith(e, "blcli: "), paste("args:", e))
    }
  },
  doctor = function() { r <- run("doctor"); check(r$status == 0 && nzchar(r$text), r$text) },
  models = function() {
    r <- run("models"); check(r$status == 0 || no_route(r), r$text)
  },
  ask = function() {
    r <- run("ask", "Reply with the single word pong."); check((r$status == 0 && nzchar(trimws(r$text))) || no_route(r), r$text)
  },
  # the help lists "aye, tellme" as ask under other names: both are run as ask is
  aye = function() {
    for (v in c("aye", "tellme")) {
      r <- run(v, "Reply with the single word pong.")
      check((r$status == 0 && nzchar(trimws(r$text))) || no_route(r), paste(v, r$text))
    }
  },
  launcher = function() {
    # what inst/bin/rmoriebricklayer does under R 4.6 (which keeps "--args" in commandArgs)
    load <- if (nzchar(tree)) sprintf("pkgload::load_all(%s, quiet = TRUE)", shQuote(tree)) else "library(rmoriebricklayer)"
    r <- suppressWarnings(system2("Rscript", c("--vanilla", "-e",
      shQuote(sprintf("suppressMessages(%s); q <- blcli(); quit(status = as.integer(q))", load)),
      "--args", "version"), stdout = TRUE, stderr = TRUE))
    check(is.null(attr(r, "status")) && any(grepl("rmoriebricklayer [0-9]+\\.", r)), paste("launcher:", paste(r, collapse = " | ")))
  },
  login = function() { if (!nzchar(key)) return(message("  login: SKIP")); r <- run("login", "--token", key); check(r$status == 0, r$text) },
  logout = function() { check(run("logout")$status == 0, "logout") },
  functions = function() { r <- run("functions", "cps"); check(r$status == 0 && grepl("cpssign", r$text), substr(r$text, 1, 200)) },
  describe = function() { r <- run("describe", "mkmnf"); check(r$status == 0 && grepl("manifest", r$text, ignore.case = TRUE), substr(r$text, 1, 200)) },
  examples = function() { r <- run("examples", "cpsbndl"); check(r$status == 0 && nzchar(r$text), r$text) },
  bundle = function() { r <- run("bundle", "validate a csv schema"); check(r$status %in% c(0L, 1L), r$text) },
  data = function() {
    r <- run("data"); check(r$status %in% c(0L, 1L), r$text)
    if (!nzchar(key)) return(message("  data list/pull: SKIP (MORIE_SMOKE_KEY not set)"))
    r <- run("data", "list"); check(r$status == 0 && grepl("chicago_crime", r$text), substr(r$text, 1, 300))
    r <- run("data", "pull", "fec_cm_2020/fec_cm_2020", "--out", "fec.csv"); check(r$status == 0 && nrow(utils::read.csv("fec.csv")) > 1000, r$text)
    df <- dload("fec_cm_2020/fec_cm_2020"); check(nrow(df) > 1000, "dload")
  },
  `explain-error` = function() {
    r <- run("explain-error", "`prompt` must be a single non-empty string")
    check(r$status == 0L && grepl("raised in rmoriebricklayer::", r$text, fixed = TRUE), r$text)
    r <- run("explain-error", "object 'zz' not found"); check(r$status == 1L && grepl("Not a message", r$text), r$text)
  },
  wayback = function() {
    # no archive.org keys on a runner: usage, a missing file and a missing results file, nothing sent
    r <- run("wayback"); check(r$status == 2L && grepl("wayback FILE", r$text, fixed = TRUE), r$text)
    r <- run("wayback", "help"); check(r$status == 0L && grepl("--retry", r$text, fixed = TRUE), r$text)
    r <- run("wayback", "no-such-urls.txt"); check(r$status == 1L && grepl("no such file", r$text, fixed = TRUE), r$text)
    r <- run("wayback", "--retry", "no-such.jsonl"); check(r$status == 1L && grepl("no such file", r$text, fixed = TRUE), r$text)
  },
  config = function() {
    r <- run("config"); check(r$status == 0 && grepl("route", r$text, fixed = TRUE), r$text)
    check(run("config", "help")$status == 0, "config help")
    r <- run("config", "set", "ollama.model", "smoke-model:1"); check(r$status == 0, r$text)
    r <- run("config", "get", "ollama.model"); check(r$status == 0 && grepl("smoke-model:1", r$text, fixed = TRUE), r$text)
    r <- run("config", "unset", "ollama.model"); check(r$status == 0, r$text)
    check(run("config", "set", "route", "nowhere")$status != 0L, "config set accepted a bad route")
    # a stored key is shown only as set / (not set), never any of its characters
    if (nzchar(key)) check(!grepl(substr(key, nchar(key) - 5L, nchar(key)), run("config")$text, fixed = TRUE), "config printed part of the key")
  },
  # the capsule verbs, on a capsule whose source is a local CSV: refresh pins it, then the rest read it
  verify = function() {
    d <- tempfile("smoke-capsule"); dir.create(d)
    src <- file.path(d, "source.csv")
    utils::write.csv(data.frame(id = 1:40, v = rep(c("a", "b"), 20)), src, row.names = FALSE)
    prov <- list(name = "smoke", source = list(url = src, sha256 = "TODO: pinned later"),
                 resource = list(filename = "data.csv", row_count_data_rows = 0),
                 table = list(rounding = 5, suppression_limit = 10))
    writeLines(tojs(prov, auto_unbox = TRUE), file.path(d, "data_provenance.json"))
    r <- run("refresh", d); check(r$status == 0, paste("refresh:", substr(r$text, 1, 300)))
    r <- run("verify", d); check(r$status == 0 && grepl("ok", r$text, fixed = TRUE), paste("verify:", substr(r$text, 1, 300)))
    r <- run("verify", d, "--json"); check(r$status == 0 && grepl("\"status\"", r$text, fixed = TRUE), paste("verify --json:", substr(r$text, 1, 300)))
    smoke_capsule <<- d
  },
  drift = function() {
    r <- run("drift", smoke_capsule); check(r$status == 0, paste("drift:", substr(r$text, 1, 300)))
    # the options of the rmbl action: PSI bands, the column table, cache, file:// sources, snapshot, footprint
    utils::write.csv(data.frame(id = 1:40 * 9, v = rep(c("a", "b"), 20)), file.path(smoke_capsule, "source.csv"), row.names = FALSE)
    r <- run("drift", smoke_capsule, "--psi-warn", "0.1", "--psi-fail", "0.25", "--cache", file.path(home, "cache"), "--snapshot")
    check(r$status == 0 && grepl("| Verdict | Column |", r$text, fixed = TRUE) && grepl("Footprint of these checks", r$text, fixed = TRUE), paste("drift bands:", substr(r$text, 1, 300)))
    r <- run("drift", smoke_capsule, "--fail-on", "drift", "--no-footprint"); check(r$status == 1L && !grepl("Footprint", r$text, fixed = TRUE), paste("drift fail-on:", substr(r$text, 1, 300)))
    # the moved source: --html writes the interactive report, --json carries the columns, --app builds the app
    h <- file.path(home, "drift.html")
    r <- run("drift", smoke_capsule, "--html", h); check(r$status == 0 && file.exists(h) && grepl("HTML report", r$text, fixed = TRUE), paste("drift --html:", substr(r$text, 1, 300)))
    check(any(grepl("id=\"drift-data\"", readLines(h, warn = FALSE), fixed = TRUE)), "drift --html: no data in the page")
    # --app with the launcher replaced, so no server starts: the app is built, or shiny's absence is said
    ns <- asNamespace("rmoriebricklayer"); real <- get(".bl_run_app", ns); got <- NULL
    utils::assignInNamespace(".bl_run_app", function(app) got <<- app, ns = ns); on.exit(utils::assignInNamespace(".bl_run_app", real, ns = ns), add = TRUE)
    r <- run("drift", smoke_capsule, "--app")
    check((r$status == 0 && inherits(got, "shiny.appobj")) || (r$status == 1 && grepl("drftapp: the app needs the shiny package", r$text, fixed = TRUE)), paste("drift --app:", substr(r$text, 1, 300)))
    pf <- file.path(smoke_capsule, "data_provenance.json"); p0 <- readLines(pf)
    on.exit(writeLines(p0, pf), add = TRUE)  # refresh (cpsrfrsh() without allowfile) reads the plain path again
    p <- loadprov(pf); p$source$url <- paste0("file://", normalizePath(file.path(smoke_capsule, "source.csv"), winslash = "/"))
    writeLines(tojs(p, auto_unbox = TRUE), file.path(smoke_capsule, "data_provenance.json"))
    r <- run("drift", smoke_capsule, "--json", "--allow-file"); check(r$status == 0 && grepl("\"benford_ref\"", r$text, fixed = TRUE), paste("drift --allow-file:", substr(r$text, 1, 300)))
    x <- cpschk(smoke_capsule, "drift", allowfile = TRUE, fp = FALSE)
    same <- function(a, b) identical(normalizePath(a, winslash = "/"), normalizePath(b, winslash = "/"))
    check(x$status == "drift" && length(ghann(x)) == 1L && same(ghout(x)$changed, smoke_capsule),
          paste("cpschk/ghann/ghout:", x$status, paste(ghann(x), collapse = " | "), ghout(x)$changed))
    check(startsWith(ghcmt(x), "<!-- rmbl-action -->"), "ghcmt")
  },
  sign = function() {
    d <- file.path(home, "sign", "one"); dir.create(d, recursive = TRUE)
    utils::write.csv(data.frame(x = 1:3), file.path(d, "data.csv"), row.names = FALSE)
    writeLines('{"resource": {"filename": "data.csv"}}', file.path(d, "data_provenance.json"))
    Sys.setenv(RMBL_KEY = "smoke secret")
    r <- run("sign", dirname(d)); check(r$status == 0 && grepl("hmac key id", r$text, fixed = TRUE) && !grepl("smoke secret", r$text, fixed = TRUE), paste("sign:", substr(r$text, 1, 300)))
    Sys.setenv(RMBL_KEY = "smoke secret")  # each run removes it from the environment
    r <- run("sign", dirname(d)); check(r$status == 1L && grepl("already exists", r$text, fixed = TRUE), paste("sign again:", substr(r$text, 1, 300)))
    kf <- file.path(home, "pq.key"); writeLines(tojs(unclass(fipskg("ML-DSA-44")), auto_unbox = TRUE), kf)
    r <- run("sign", dirname(d), "--scheme", "ML-DSA-44", "--key-file", kf, "--overwrite", "--json"); check(r$status == 0 && grepl("\"status\": \"ok\"", r$text, fixed = TRUE), paste("sign ML-DSA-44:", substr(r$text, 1, 300)))
  },
  refresh = function() { r <- run("refresh", smoke_capsule); check(r$status == 0, paste("refresh:", substr(r$text, 1, 300))) },
  report = function() {
    r <- run("report", smoke_capsule); check(r$status == 0 && grepl("rmbl", r$text, fixed = TRUE), substr(r$text, 1, 300))
    r <- run("report", smoke_capsule, "--format", "json"); check(r$status == 0 && grepl("\"status\"", r$text, fixed = TRUE), substr(r$text, 1, 300))
    m <- file.path(home, "base-manifest.json"); writeLines('{"resource": {"filename": "data.csv", "sha256": "01"}}', m)
    file.copy(m, file.path(smoke_capsule, "manifest.json"), overwrite = TRUE)
    r <- run("report", smoke_capsule, "--base", m, "--manifests", "*"); check(r$status == 0 && grepl("### Manifests against", r$text, fixed = TRUE), paste("report --base:", substr(r$text, 1, 300)))
  },
  help = function() {
    for (p in c("start", "llm", "config", "r")) { r <- run("help", p); check(r$status == 0 && nzchar(r$text), paste("help", p)) }
  },
  capsule = function() {
    dir <- file.path(home, "cap"); dir.create(dir)
    utils::write.csv(data.frame(x = 1:3), file.path(dir, "data.csv"), row.names = FALSE)
    m <- mkmnf(list(dataset = "smoke"), env = FALSE)
    keyp <- fipskg("ML-DSA-44")
    b <- cpsbndl(dir, m, keyp)
    check(isTRUE(cpsbndlvrf(attr(b, "path"), dir, man = m)$ok), "bundle does not verify")
  }
)
help_text <- run("help")$text
verbs <- trimws(unique(regmatches(help_text, gregexpr("(?m)^  ([a-z][a-z-]*)", help_text, perl = TRUE))[[1]]))
# "rmoriebricklayer help start" and friends are help pages (the help case), not verbs
missing <- setdiff(verbs, c(names(cases), "rmoriebricklayer"))
if (length(missing)) { cat("VERBS WITHOUT A SMOKE CASE:", paste(missing, collapse = ", "), "\n"); quit(status = 2) }
failed <- 0L
for (n in names(cases)) {
  out <- tryCatch({ cases[[n]](); "OK" }, error = function(e) { failed <<- failed + 1L; paste("FAIL", conditionMessage(e)) })
  cat(sprintf("[%s] %s\n", substr(out, 1, 4), n)); if (startsWith(out, "FAIL")) cat("      ", out, "\n")
}
cat(sprintf("\nsmoke (rmoriebricklayer): %d ok, %d failed\n", length(cases) - failed, failed))
quit(status = if (failed) 1L else 0L)
