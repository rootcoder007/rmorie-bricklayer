# Clean-user smoke for rmoriebricklayer: every `rmoriebricklayer` verb and the data
# client run for real in an empty HOME. Rscript inst/smoke/smoke.R (package installed).
tree <- Sys.getenv("MORIE_SMOKE_TREE", "")
if (nzchar(tree)) suppressPackageStartupMessages(pkgload::load_all(tree, quiet = TRUE)) else suppressPackageStartupMessages(library(rmoriebricklayer))
home <- tempfile("bl-smoke-"); dir.create(home); setwd(home)
Sys.setenv(HOME = home, XDG_CONFIG_HOME = file.path(home, "cfg"))
key <- Sys.getenv("MORIE_SMOKE_KEY", "")
if (nzchar(key)) Sys.setenv(MORIE_HOSTED_KEY = key) else Sys.unsetenv("MORIE_HOSTED_KEY")
options(timeout = 600)
run <- function(...) { buf <- character(); st <- bricklayer_cli(c(...), out = function(s) buf <<- c(buf, s)); list(status = st, text = paste(buf, collapse = "")) }
check <- function(cond, what) if (!isTRUE(cond)) stop(what, call. = FALSE)
# the hosted tier answers 429 when every runner of every package asks at once on the shared key: wait and ask once more
run_llm <- function(...) {
  r <- run(...)
  if (r$status != 0 && grepl("429", r$text, fixed = TRUE)) { Sys.sleep(45); r <- run(...) }
  r
}
cases <- list(
  version = function() { r <- run("version"); check(r$status == 0 && grepl("rmoriebricklayer", r$text), r$text) },
  doctor = function() { r <- run("doctor"); check(r$status == 0 && nzchar(r$text), r$text) },
  models = function() {
    r <- run("models"); check(r$status == 0, r$text)
    # the gateway serves additional AI models (suffix :cf) beside the ollama.com ones
    if (nzchar(Sys.getenv("MORIE_SMOKE_KEY"))) check(grepl(":cf", r$text, fixed = TRUE), paste("no additional AI model (:cf) listed:", r$text))
  },
  ask = function() {
    r <- run_llm("ask", "hello"); check(r$status == 0, r$text)
    # one of the additional models, named per call
    r <- run_llm("ask", "--model", "gpt-oss-120b:cf", "Reply with the single word pong.")
    check(r$status == 0 && nzchar(trimws(r$text)), r$text)
  },
  launcher = function() {
    # what inst/bin/rmoriebricklayer does under R 4.6 (which keeps "--args" in commandArgs)
    load <- if (nzchar(tree)) sprintf("pkgload::load_all(%s, quiet = TRUE)", shQuote(tree)) else "library(rmoriebricklayer)"
    r <- suppressWarnings(system2("Rscript", c("--vanilla", "-e",
      shQuote(sprintf("suppressMessages(%s); q <- bricklayer_cli(); quit(status = as.integer(q))", load)),
      "--args", "version"), stdout = TRUE, stderr = TRUE))
    check(is.null(attr(r, "status")) && any(grepl("rmoriebricklayer 0\\.", r)), paste("launcher:", paste(r, collapse = " | ")))
  },
  login = function() { if (!nzchar(key)) return(message("  login: SKIP")); r <- run("login", "--token", key); check(r$status == 0, r$text) },
  logout = function() { check(run("logout")$status == 0, "logout") },
  functions = function() { r <- run("functions", "capsule"); check(r$status == 0 && grepl("capsule_sign", r$text), substr(r$text, 1, 200)) },
  describe = function() { r <- run("describe", "make_manifest"); check(r$status == 0 && grepl("manifest", r$text, ignore.case = TRUE), substr(r$text, 1, 200)) },
  examples = function() { r <- run("examples", "capsule_bundle"); check(r$status == 0 && nzchar(r$text), r$text) },
  bundle = function() { r <- run("bundle", "validate a csv schema"); check(r$status %in% c(0L, 1L), r$text) },
  data = function() {
    r <- run("data"); check(r$status %in% c(0L, 1L), r$text)
    if (!nzchar(key)) return(message("  data list/pull: SKIP (MORIE_SMOKE_KEY not set)"))
    r <- run("data", "list"); check(r$status == 0 && grepl("chicago_crime", r$text), substr(r$text, 1, 300))
    r <- run("data", "pull", "fec_cm_2020/fec_cm_2020", "--out", "fec.csv"); check(r$status == 0 && nrow(utils::read.csv("fec.csv")) > 1000, r$text)
    df <- bricklayer_data_load("fec_cm_2020/fec_cm_2020"); check(nrow(df) > 1000, "bricklayer_data_load")
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
  help = function() {
    for (p in c("start", "llm", "config", "r")) { r <- run("help", p); check(r$status == 0 && nzchar(r$text), paste("help", p)) }
  },
  capsule = function() {
    dir <- file.path(home, "cap"); dir.create(dir)
    utils::write.csv(data.frame(x = 1:3), file.path(dir, "data.csv"), row.names = FALSE)
    m <- make_manifest(list(dataset = "smoke"), environment = FALSE)
    keyp <- fips_keygen("ML-DSA-44")
    b <- capsule_bundle(dir, m, keyp)
    check(isTRUE(capsule_bundle_verify(attr(b, "path"), dir, manifest = m)$ok), "bundle does not verify")
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
