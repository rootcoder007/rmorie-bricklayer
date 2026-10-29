## =====================================================================
## setup_and_run.R
##
## Brick-proof, cross-platform (macOS / Windows / Linux) entrypoint for
## any rmorie-bricklayer bundle. Driven entirely by config.json and
## data_provenance.json — knows nothing about specific datasets.
##
## What it does:
##   1. Detects OS, loads project config + provenance, sources libs.
##   2. Checks required R packages (never installs; prints the exact
##      install command for anything missing).
##   3. Locates the input data file (probe defaults → menu of options:
##      already have it / manual download / auto-download / synthetic).
##   4. Runs the project's analysis script as a subprocess.
##   5. Writes manifest.json + SUMMARY.txt with full provenance.
##
## Only external requirement: R 4.0+. No bash, zsh, python, curl, jq,
## brew, apt, dnf, or winget required.
##
## USAGE:
##   Rscript setup_and_run.R              # interactive
##   Rscript setup_and_run.R --quick      # non-interactive (defaults)
##   Rscript setup_and_run.R --synthetic  # offline, fake data, no prompts
##   Rscript setup_and_run.R --data PATH  # explicit data path
##   Rscript setup_and_run.R --allow-digest-drift  # analyse bytes whose
##                                        # SHA-256 differs from the pinned
##                                        # provenance (recorded in manifest)
##   Rscript setup_and_run.R --help
##
## Licence: AGPL-3.0-or-later
## Part of rmorie-bricklayer.
## =====================================================================

## ---------- Locate script directory + parse CLI ----------
script_dir <- (function() {
  fa <- commandArgs(trailingOnly = FALSE)
  fp <- sub("^--file=", "", fa[grep("^--file=", fa)])
  if (length(fp) > 0L) normalizePath(dirname(fp[1])) else getwd()
})()
## No setwd(): the user's working directory is never changed. Every path
## below is anchored on script_dir explicitly (CRAN: do not change the
## user's working directory / options / par without restoring them).

args <- commandArgs(trailingOnly = TRUE)
QUICK_MODE <- any(args %in% c("-q", "--quick"))
HELP_MODE  <- any(args %in% c("-h", "--help"))
## --synthetic (or BRICKLAYER_SYNTHETIC=1, or the variable config.json
## names in synthetic_env): take the synthetic-data route without a prompt,
## so an offline or unattended run can exercise it. Set once config.json
## is read, below.
SYNTH_ARG  <- any(args %in% "--synthetic")
## The pinned digest is the capsule's guarantee. A mismatch stops the run
## (exit 7) unless this flag is given, and then the override is recorded
## in the manifest rather than printed once and forgotten.
ALLOW_DRIFT <- any(args %in% "--allow-digest-drift")
DIGEST_OVERRIDE <- FALSE
digest_mismatch <- function(v) {
  say("  ! SHA256 differs from the pinned provenance:")
  say("      expected ", v$expected)
  say("      got      ", v$actual)
  if (!ALLOW_DRIFT) {
    say("  Refusing to analyse bytes the capsule did not pin.")
    say("  Re-run with --allow-digest-drift to proceed anyway; the override")
    say("  is then recorded in manifest.json.")
    quit(status = 7)
  }
  say("  --allow-digest-drift given: continuing; recorded in the manifest.")
  DIGEST_OVERRIDE <<- TRUE
}
## No terminal on stdin (CI, reviewer harness, piped run): prompts would
## silently take their defaults anyway, so make that explicit and honest.
AUTO_QUICK <- FALSE
if (!QUICK_MODE && !isatty(stdin())) {
  QUICK_MODE <- TRUE
  AUTO_QUICK <- TRUE
}
DATA_ARG   <- NULL
usage_stop <- function(...) {
  cat("ERROR: ", ..., "\n", sep = "")
  cat("Usage: Rscript setup_and_run.R [--quick] [--synthetic] ",
      "[--data PATH] [--allow-digest-drift] [--help]\n", sep = "")
  quit(status = 2)
}
if (any(args == "--data")) {
  i <- which(args == "--data")[1]
  if (length(args) < i + 1 || startsWith(args[i + 1], "-")) {
    usage_stop("--data needs a file path after it")
  }
  DATA_ARG <- args[i + 1]
}
known <- c("-q", "--quick", "-h", "--help", "--synthetic",
           "--allow-digest-drift", "--data")
rest <- args
if (!is.null(DATA_ARG)) rest <- rest[-(which(args == "--data")[1] + 0:1)]
odd <- rest[!rest %in% known]
if (length(odd)) {
  usage_stop("unknown argument(s): ", paste(odd, collapse = " "))
}

if (HELP_MODE) {
  self <- file.path(script_dir, "setup_and_run.R")
  lines <- readLines(self)
  cat(lines[grep("^## USAGE", lines)[1] + 0:5], sep = "\n")
  quit(status = 0)
}

## ---------- Source libraries ----------
LIB_DIR <- script_dir  # libs may be next to setup_and_run.R after bundle build
for (lib in c("aaa_input_guards.R", "aaa_local_seed.R",
              "json_native.R", "sha256_native.R",
              "lib_interactive.R", "lib_helpers.R",
              # the boxed print-out every result carries: its frame, the
              # readings and the block layout (custody.R) the boxes draw with
              "print_methods.R", "box_readings.R", "custody.R",
              "lib_data_loader.R",
              "lib_synthetic.R", "lib_manifest.R",
              "yoy.R", "rate.R")) {
  lib_path <- file.path(LIB_DIR, lib)
  if (!file.exists(lib_path))
    stop("Required library not found: ", lib_path)
  source(lib_path)
}

## ---------- Load project config + provenance ----------
CONFIG_PATH     <- file.path(script_dir, "config.json")
PROVENANCE_PATH <- file.path(script_dir, "data_provenance.json")
if (!file.exists(CONFIG_PATH))
  stop("config.json not found at ", CONFIG_PATH)
# the bundled native codec (json_native.R): no jsonlite needed. A file
# that is not valid JSON (or repeats a key) stops the run in words, with
# exit status 2, not with an R traceback
read_or_stop <- function(what, expr) {
  tryCatch(expr, error = function(e) {
    cat("ERROR: ", what, " could not be read: ", conditionMessage(e), "\n",
        sep = "")
    cat("  Fix the file (or ask the bundle's author for a fixed copy)",
        " and run this again.\n", sep = "")
    quit(status = 2)
  })
}
cfg <- read_or_stop("config.json",
                    fromjs(CONFIG_PATH, simplifyVector = FALSE))
if (!is.list(cfg)) {
  cat("ERROR: config.json could not be read: it is not a JSON object\n")
  quit(status = 2)
}
prov <- read_or_stop("data_provenance.json", loadprov(PROVENANCE_PATH))

PROJECT_NAME    <- cfg$project$name         %||% "bricklayer-project"
PROJECT_AUTHOR  <- cfg$project$author       %||% "(unknown author)"
PROJECT_CONTACT <- cfg$project$contact      %||% ""
PROJECT_LICENCE <- cfg$project$licence      %||% "AGPL-3.0-or-later"
ANALYSIS_R      <- file.path(script_dir,
                             cfg$analysis$r_script %||% "analysis.R")
REQ_PKGS        <- unlist(cfg$r_packages) %||% c()
## one variable at a time: Sys.getenv() of no names returns the whole
## environment, which would turn every run synthetic
SYNTH_VARS <- c("BRICKLAYER_SYNTHETIC", unlist(cfg$synthetic_env))
SYNTH_ARG <- SYNTH_ARG ||
  any(vapply(SYNTH_VARS, function(v) nzchar(Sys.getenv(v, "")), logical(1)))
## Packages a project needs only when an environment variable is set
## (config.json env_packages: {"VARIABLE": ["pkg", ...]}).
for (ev in names(cfg$env_packages)) {
  if (nzchar(Sys.getenv(ev, "")))
    REQ_PKGS <- unique(c(REQ_PKGS, unlist(cfg$env_packages[[ev]])))
}
## Opt-in stages have their own dependencies; probe them up front when the
## stage is switched on, so a missing package is reported here and not
## thirty seconds into the run.
env_on <- function(ev) {
  tolower(Sys.getenv(ev, "")) %in% c("1", "yes", "true", "y")
}

## ---------- Banner + OS detection ----------
OS_KIND <- detect_os()

cat("==========================================================\n")
cat("  rmorie-bricklayer Reproducibility Runner\n")
cat("  Project: ", PROJECT_NAME, "\n", sep = "")
cat("  Author:  ", PROJECT_AUTHOR, "\n", sep = "")
cat("==========================================================\n")
say("OS detected:    ", OS_KIND)
say("R version:      ", R.version.string)
say("Mode:           ", if (QUICK_MODE) "quick (non-interactive)" else "interactive")
if (AUTO_QUICK)
  say("                (no terminal detected on stdin -- defaults applied automatically;",
      " pass --data PATH or run from a terminal for the interactive menus)")
cat("\n")

## ---------- WHERE EVERYTHING WILL GO panel ----------
home_dir       <- normalizePath(Sys.getenv("HOME", path.expand("~")),
                                winslash = "/", mustWork = FALSE)
default_result <- file.path(script_dir,
                            paste0("results_",
                                   format(Sys.time(), "%Y%m%d-%H%M%S")))
r_user_data    <- tryCatch(tools::R_user_dir(PROJECT_NAME, which = "data"),
                           error = function(e) "(R 4.0+ required)")

cat("----------------------------------------------------------\n")
cat("  WHERE EVERYTHING WILL GO\n")
cat("----------------------------------------------------------\n")
cat("  This script writes ONLY to the locations below. It never\n")
cat("  touches system files and never requires admin/sudo rights.\n\n")
cat("  Bundle folder (where setup_and_run.R lives — DEFAULT):\n")
cat("    ", script_dir, "\n", sep = "")
cat("  Results subfolder (created fresh on each run):\n")
cat("    ", default_result, "\n", sep = "")
cat("  Your home directory:\n")
cat("    ", home_dir, "\n", sep = "")
cat("  R's OS-canonical data folder (R-policy location):\n")
cat("    ", r_user_data, "\n", sep = "")
cat("\n  Internet endpoints the script may contact:\n")
for (url in unlist(cfg$network$endpoints %||% c())) {
  cat("    - ", url, "\n", sep = "")
}
if (length(prov$wayback))
  cat("    - https://web.archive.org/web/...       (Wayback fallback, if needed)\n")
cat("  No telemetry. No third-party services. No personal data leaves your machine.\n")
cat("----------------------------------------------------------\n\n")

## ---------- 1. Sanity-check companion files ----------
if (!file.exists(ANALYSIS_R)) {
  say("ERROR: analysis script not found: ", ANALYSIS_R)
  say("  Set cfg$analysis$r_script in config.json correctly.")
  quit(status = 2)
}

## ---------- 2. Check required R packages (this script never installs) ----------
say("Step 1/5: Checking R packages...")
if (length(REQ_PKGS) > 0L) {
  ## CRAN policy: scripts must not call install.packages() or
  ## installed.packages(). Availability is probed per package with
  ## requireNamespace(); anything missing is reported with the exact
  ## copy-paste install command for the user to run themselves.
  missing_pkgs <- REQ_PKGS[!vapply(REQ_PKGS, requireNamespace,
                                   logical(1), quietly = TRUE)]
  if (length(missing_pkgs) > 0L) {
    say("  Missing: ", paste(missing_pkgs, collapse = ", "))
    say("  This script does not install packages itself. Install them in R,")
    say("  then re-run this script:")
    say("    install.packages(c(",
        paste0('"', missing_pkgs, '"', collapse = ", "), "))")
    say("  Tip (Linux): pre-built binaries from Posit Package Manager")
    say("  (https://packagemanager.posit.co/) are much faster than source.")
    quit(status = 3)
  }
  say("  \u2713 All required packages present.")
} else {
  say("  (No packages declared in config$r_packages.)")
}
## Opt-in stages (config.json optional_stages): each names the variable
## that switches it on, the packages it needs, and optionally an
## alternative package that does the same work.
for (st in cfg$optional_stages) {
  if (!env_on(st$env)) next
  need <- unlist(st$packages)
  gone <- need[!vapply(need, requireNamespace, logical(1), quietly = TRUE)]
  alt <- st$alternative %||% ""
  if (length(gone) == 0L) {
    say("  \u2713 ", st$env, ": ", paste(need, collapse = ", "), " present",
        if (!is.null(st$note)) paste0(" (", st$note, ")"), ".")
  } else if (nzchar(alt) && requireNamespace(alt, quietly = TRUE)) {
    say("  ", st$env, ": missing ", paste(gone, collapse = ", "),
        "; ", alt, " is installed and does the same work instead.")
    say("  For the reference route:")
    say("    install.packages(c(", paste0(', need, ', collapse = ", "), "))")
  } else {
    say("  Missing for ", st$env, "=1: ", paste(gone, collapse = ", "))
    say("  This script does not install packages itself. Install them in R,")
    say("  then re-run this script:")
    say("    install.packages(c(", paste0(', need, ', collapse = ", "), "))")
    if (!is.null(st$alternative_install))
      say("  Alternative: ", st$alternative_install)
    say("  Or unset ", st$env, if (!is.null(st$skip_note))
      paste0(": ", st$skip_note) else ".")
    quit(status = 3)
  }
}
hr()

## ---------- 3. Locate input data ----------
say("Step 2/5: Locating the input data...")
input_path <- NULL
SYNTHETIC_MODE <- FALSE

dataset_url     <- prov$dataset$catalogue_page %||% "(no catalogue page in provenance)"
resource_name   <- prov$resource$name          %||% "(no resource name in provenance)"
licence_label   <- prov$dataset$licence_short  %||% prov$dataset$licence_name %||% ""

## Default candidates (probe before asking)
default_candidates <- function() {
  home <- Sys.getenv("HOME", path.expand("~"))
  fn   <- prov$resource$filename %||% "input.csv"
  cands <- c(
    file.path(script_dir, fn),
    file.path(script_dir, "data", fn),
    file.path(home, "Desktop", fn),
    file.path(home, "Downloads", fn),
    file.path(home, "Documents", fn),
    file.path(script_dir, "input.csv"),
    file.path(script_dir, "data.csv")
  )
  unlist(c(cands, cfg$data$default_candidates %||% c()))
}

## A file the reviewer supplies (--data, one found beside the bundle or in
## its data/ folder, one named at the prompt) is checked against the pinned
## SHA-256 like a downloaded one: the digest is the capsule's guarantee
check_pinned <- function(path) {
  if (nzchar(unlist(prov$resource$sha256 %||% "")[1L])) {
    v <- vrfsha256(path, prov$resource$sha256)
    if (v$match) say("  SHA256 matches the pinned provenance.")
    else digest_mismatch(v)
  }
  invisible(path)
}

if (!is.null(DATA_ARG)) {
  if (!file.exists(DATA_ARG)) {
    say("ERROR: --data path does not exist: ", DATA_ARG)
    quit(status = 4)
  }
  if (dir.exists(DATA_ARG)) {
    say("ERROR: --data is a folder, not a data file: ", DATA_ARG)
    quit(status = 4)
  }
  input_path <- DATA_ARG
  say("  Using --data: ", input_path)
  check_pinned(input_path)
} else {
  ## --synthetic asks for generated data: a real file lying beside the
  ## script is not picked up in its place
  cands <- if (SYNTH_ARG) character() else default_candidates()
  hits  <- cands[file.exists(cands)]
  if (length(hits) > 0L) {
    say("  Found a candidate file at:")
    say("    ", hits[1])
    if (ask_yn("  Use this file?", "Y", QUICK_MODE)) {
      input_path <- hits[1]
      check_pinned(input_path)
    }
  }

  if (is.null(input_path)) {
    say("")
    say("  This project uses the following dataset:")
    say("    Resource: ", resource_name)
    say("    Source:   ", dataset_url)
    if (nzchar(licence_label)) say("    Licence:  ", licence_label)
    say("")
    menu_options <- c(
      "I already have the file on this computer — I'll tell you where",
      "Open the link and download it myself in a browser",
      "Have this script download it for me (needs internet)",
      "Run on SYNTHETIC fake data (no internet, no real data — testing only)",
      "Cancel and exit"
    )
    choice <- ask_menu("  How would you like to proceed?",
                       menu_options, if (SYNTH_ARG) 4L else 3L,
                       QUICK_MODE || SYNTH_ARG)

    if (choice == 1L) {
      hint_dir <- ask_save_location(
        "  Pick the folder it's in:",
        default_key  = "downloads",
        script_dir   = script_dir,
        project_name = PROJECT_NAME,
        quick        = QUICK_MODE)
      default_name <- prov$resource$filename %||% "input.csv"
      typed <- ask_path("  Enter the file name (just the name, not full path):",
                        default_name, QUICK_MODE)
      candidate <- file.path(hint_dir, typed)
      if (!file.exists(candidate))
        candidate <- ask_path("  Enter the FULL path to the file:",
                              candidate, QUICK_MODE)
      if (!file.exists(candidate)) {
        say("ERROR: file does not exist: ", candidate); quit(status = 4)
      }
      input_path <- normalizePath(candidate)
      check_pinned(input_path)
    }

    else if (choice == 2L) {
      say("")
      say("  Open this URL in any browser:")
      say("    ", dataset_url)
      say("  Find the resource: '", resource_name, "' and download it.")
      save_dir <- ask_save_location(
        "  Where will the file end up after you download it?",
        default_key  = "downloads",
        script_dir   = script_dir,
        project_name = PROJECT_NAME,
        quick        = QUICK_MODE)
      say("  Press Enter when the download is complete.")
      if (!QUICK_MODE) invisible(readLines(con = "stdin", n = 1, warn = FALSE))
      default_name <- prov$resource$filename %||% "input.csv"
      typed <- ask_path("  What is the downloaded file's name?",
                        default_name, QUICK_MODE)
      candidate <- file.path(save_dir, typed)
      if (!file.exists(candidate))
        candidate <- ask_path("  Enter the FULL path to the file:",
                              candidate, QUICK_MODE)
      if (!file.exists(candidate)) {
        say("ERROR: file does not exist: ", candidate); quit(status = 4)
      }
      input_path <- normalizePath(candidate)
      if (nzchar(prov$resource$sha256 %||% "")) {
        v <- vrfsha256(input_path, prov$resource$sha256)
        if (v$match) say("  ✓ SHA256 matches pinned provenance.")
        else digest_mismatch(v)
      }
    }

    else if (choice == 3L) {
      ## no download without the package's own downloader: base R cannot
      ## pin addresses or re-check every redirect (fail closed)
      if (is.null(.rmbl_bdl())) {
        say("ERROR: ", .rmbl_nodl(), ".")
        say("  Or run on synthetic data: --synthetic.")
        quit(status = 5)
      }
      save_dir <- ask_save_location(
        "  Where should I save the downloaded file?",
        default_key  = "bundle",
        script_dir   = script_dir,
        project_name = PROJECT_NAME,
        quick        = QUICK_MODE)
      url <- rslvckan(prov)
      if (is.null(url)) url <- rslvckns(prov)
      if (is.null(url)) url <- prov$resource$direct_url
      if (is.null(url)) {
        say("ERROR: no download URL available — provenance missing.")
        quit(status = 5)
      }
      # the provenance's filename is a NAME, never a path
      fn <- basename(prov$resource$filename %||% basename(url))
      target <- file.path(save_dir, fn)
      say("  Downloading: ", url)
      say("  → ", target)
      wb_url <- prov$wayback$csv_snapshot %||% ""
      if (!fdl(url, target,
                              attwb = if (nzchar(wb_url)) wb_url else NULL)) {
        say("  All download paths exhausted. Options:")
        say("    1) Re-run after disabling your VPN")
        say("    2) Download manually from: ", prov$dataset$catalogue_page)
        say("    4) Run on SYNTHETIC fake data (menu option 4, or --synthetic)")
        quit(status = 5)
      }
      input_path <- target
      if (nzchar(prov$resource$sha256 %||% "")) {
        v <- vrfsha256(target, prov$resource$sha256)
        if (v$match) say("  ✓ SHA256 byte-for-byte match.")
        else digest_mismatch(v)
      }
    }

    else if (choice == 4L) {
      say("")
      say("  *** SYNTHETIC DATA MODE ***")
      say("  Generates random fake data that matches the schema.")
      say("  Pipeline will run end-to-end but results are NOT real and")
      say("  CANNOT verify any claim in the paper.")
      say("")
      if (!ask_yn("  Confirm — generate synthetic data and run on it?",
                  if (SYNTH_ARG) "Y" else "N", QUICK_MODE || SYNTH_ARG)) {
        say("  Cancelled."); quit(status = 0)
      }
      save_dir <- ask_save_location(
        "  Where should I save the synthetic CSV?",
        default_key  = "bundle",
        script_dir   = script_dir,
        project_name = PROJECT_NAME,
        quick        = QUICK_MODE)
      synth_schema <- prov$schema$synthetic_recipe
      if (is.null(synth_schema)) {
        say("ERROR: data_provenance.json has no schema.synthetic_recipe block.")
        say("  Synthetic mode requires the project author to define a recipe.")
        quit(status = 6)
      }
      target <- file.path(save_dir, "SYNTHETIC_data.csv")
      say("  Generating synthetic dataset...")
      info <- mksyncsv(synth_schema, target)
      say("  Wrote ", info$rows, " rows (seed = ", info$seed, ") to: ", target)
      input_path <- target
      SYNTHETIC_MODE <- TRUE
    }

    else {
      say("  Exiting at user request."); quit(status = 0)
    }
  }
}
hr()

## ---------- 4. Run the project's analysis script ----------
say("Step 3/5: Running ", basename(ANALYSIS_R), "...")
output_dir <- default_result
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
say("  Input:   ", input_path)
say("  Output:  ", output_dir)
say("")
if (!ask_yn("  Start the analysis now?", "Y", QUICK_MODE)) {
  say("OK — exiting without running."); quit(status = 0)
}
hr()

log_path <- file.path(output_dir, "run.log")
rscript_bin <- file.path(R.home("bin"),
                         if (OS_KIND == "windows") "Rscript.exe" else "Rscript")

if (isTRUE(SYNTHETIC_MODE)) {
  cat("\n##########################################################\n")
  cat("#   ⚠  SYNTHETIC DATA MODE — RESULTS ARE NOT REAL  ⚠     #\n")
  cat("##########################################################\n\n")
}

## every ARGUMENT quoted: a bundle directory with a space broke the command
## line system2() composes. The command itself is not quoted here: system2()
## quotes it (shQuote on Unix, the Windows rules on Windows), and a second
## layer made the shell look for a program literally named '/opt/R/.../Rscript'.
sh_type <- if (OS_KIND == "windows") "cmd" else "sh"
run_args <- c(shQuote(ANALYSIS_R, type = sh_type), shQuote(input_path, type = sh_type),
              shQuote(output_dir, type = sh_type))
## The child inherits this process's environment. system2(env = ) is not
## used: on Windows it puts NAME=value in front of the command, which cmd
## cannot run, so analysis.R never started there.
old_synth <- Sys.getenv("BRICKLAYER_SYNTHETIC", unset = NA)
if (isTRUE(SYNTHETIC_MODE)) Sys.setenv(BRICKLAYER_SYNTHETIC = "1")
exit_code <- system2(rscript_bin, run_args,
                     stdout = log_path, stderr = log_path)
if (is.na(old_synth)) {
  Sys.unsetenv("BRICKLAYER_SYNTHETIC")
} else {
  Sys.setenv(BRICKLAYER_SYNTHETIC = old_synth)
}
cat(readLines(log_path, warn = FALSE), sep = "\n")
hr()

## ---------- 5. Results summary + SUMMARY.txt ----------
say("Step 4/5: Results summary")
manifest_path <- file.path(output_dir, "manifest.json")
if (file.exists(manifest_path)) {
  m <- fromjs(manifest_path, simplifyVector = FALSE)
  counts <- summarise_counts(m)
  say(sprintf("  Total:  %d", counts$total))
  say(sprintf("  PASS:   %d", counts$pass))
  say(sprintf("  DIFFER: %d", counts$differ))
  if (!is.null(counts$warn) && counts$warn > 0L)
    say(sprintf("  WARN:   %d  (see manifest.json notes -- often package-version drift)",
                counts$warn))
  say(sprintf("  INFO:   %d", counts$info))
  ## Version-drift note: if the provenance pins the versions the reference
  ## numbers were produced on, compare against what this run actually used.
  pinned <- prov$pinned_r_package_versions
  used <- m$meta$r_package_versions
  if (!is.null(pinned) && !is.null(used)) {
    drift <- character()
    for (p in names(pinned)) {
      u <- used[[p]]
      if (!is.null(u) && !is.na(u) && !identical(as.character(u),
                                                 as.character(pinned[[p]]))) {
        drift <- c(drift, sprintf("%s: pinned %s, this run %s",
                                  p, pinned[[p]], u))
      }
    }
    if (length(drift) > 0L) {
      say("  NOTE -- R package version drift vs the reference run:")
      for (d in drift) say("    ", d)
      say("  Small numeric differences and convergence WARNs are expected under drift.")
    }
  }
  ## Drop a SUMMARY.txt
  m$meta$project   <- PROJECT_NAME
  m$meta$author    <- PROJECT_AUTHOR
  m$meta$os        <- OS_KIND
  m$meta$synthetic <- SYNTHETIC_MODE
  m$meta$digest_override <- DIGEST_OVERRIDE
  wrsmrytxt(
    m, output_dir,
    paths = list(
      bundle         = script_dir,
      input          = input_path,
      results        = output_dir,
      analysis_script = ANALYSIS_R,
      provenance     = PROVENANCE_PATH
    ),
    whatwasdone = unlist(cfg$summary$what_was_done %||%
                            list("Ran the project's analysis script.",
                                 "Wrote CSV outputs and manifest.json.")),
    contact = PROJECT_CONTACT,
    lic = paste0(PROJECT_LICENCE,
                     if (!is.null(prov$dataset$licence_short))
                       paste0(" (scripts); ",
                              prov$dataset$licence_short, " (data)")
                     else "")
  )
} else {
  say("  WARNING: manifest.json not produced. Check run.log.")
}
hr()

if (exit_code != 0L || !file.exists(manifest_path)) {
  say("Step 5/5: NOT completed (analysis exit code ", exit_code,
      if (!file.exists(manifest_path)) "; no manifest.json written" else "",
      "). See run.log in the results folder.")
} else {
  say("Step 5/5: Done.")
}
say("  Results folder: ", output_dir)
say("  Plain-language summary: SUMMARY.txt in that folder.")

## A run that wrote no manifest did not complete, whatever the analysis
## script's own exit status: exit 8, so a harness (mkbndlchk) sees it
if (exit_code == 0L && !file.exists(manifest_path)) exit_code <- 8L

## Never in quick mode: unattended runs have no desktop to open, and a
## headless xdg-open blocks forever, keeping this process alive.
if (!QUICK_MODE && ask_yn("  Open the results folder now?", "Y")) {
  if (OS_KIND == "macos") system2("open", shQuote(output_dir), wait = FALSE)
  else if (OS_KIND == "windows") shell.exec(output_dir)
  else tryCatch(system2("xdg-open", shQuote(output_dir), wait = FALSE),
                error = function(e) invisible(NULL))
}

quit(status = exit_code)
