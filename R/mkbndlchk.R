# SPDX-License-Identifier: AGPL-3.0-or-later
#
# mkbndlchk(): the check an author runs on a bundle before shipping it.

#' Check a reproducibility bundle before shipping it
#'
#' Unzips a bundle built by [mkbndl()] into a new
#' folder, runs it the way a recipient would
#' (\code{Rscript setup_and_run.R --quick}) and reads the
#' \file{manifest.json} the run writes. The bundle passes when the run
#' finishes, writes its manifest, no cross-check is DIFFER and, on real
#' data, the number of checks and of passes is the one the \code{expected}
#' block of its \file{config.json} gives (\code{pass_csv} for a CSV input,
#' \code{pass_real} for the \file{.RData}). A run on synthetic data marks
#' every check INFO, so it is not compared with \code{expected}. A launcher
#' (\file{start_here.sh}, \file{START_HERE.command}) the zip does not mark
#' executable is reported as a warning: it still runs as
#' \code{bash start_here.sh}.
#'
#' \strong{Warning: this runs the bundle's code on your machine}, with your
#' user's rights: its \file{setup_and_run.R}, its analysis script and
#' anything they start. Check only bundles you built or whose author you
#' trust. To limit what a hostile bundle can reach, the run gets a minimal
#' environment: \env{PATH}, the locale variables (\env{LANG},
#' \env{LANGUAGE}, \env{LC_ALL} and the \env{LC_} categories such as
#' \env{LC_CTYPE}, no other \env{LC_} name; \env{TZ}), the library paths
#' of this session (\env{R_LIBS}), a fresh temporary \env{HOME} and
#' \env{TMPDIR}, and no other variable, so API keys, tokens and passwords
#' in the environment (or in \file{~/.Renviron}) do not reach it. On
#' Windows the variables that look like credentials are removed instead (a
#' best effort): names holding \code{KEY}, \code{TOKEN}, \code{SECRET},
#' \code{PASS}, \code{CREDENTIAL}, \code{AUTH}, \code{COOKIE} or
#' \code{SESSION}, a service's prefix (\env{GITHUB_}, \env{AWS_}, ...),
#' connection strings (\env{DATABASE_URL}, \env{*_DATABASE_URL},
#' \env{*_WEBHOOK_URL}, \env{SENTRY_DSN}, \env{*_DSN}), \env{*_PWD},
#' \env{*_SK}, other
#' \env{LC_} names, and any value that is a URL with a password in it.
#' This is not a sandbox: the files your user can read stay readable.
#'
#' The run is stopped after \code{getOption("rmbl.bundle.timeout")}
#' seconds (default 1800, 30 minutes; the exit status is then 124). How
#' the processes it starts are contained (the \code{isolation} of the
#' result, and a row of the checks):
#' \describe{
#' \item{container}{with \code{container = TRUE} (podman, else docker) or
#'   a runtime named: the run in a container, removed afterwards, with the
#'   unzipped bundle mounted read-only and copied into a writable folder,
#'   no network unless the real data is to be downloaded (no \code{data},
#'   not synthetic), 4 GB of memory, 2 CPUs, 512 processes, a read-only
#'   root file system, no capabilities and your user id. The image is
#'   \code{getOption("rmbl.bundle.image")}, default R 4.6.1 from the
#'   Rocker project pinned by digest; it holds base R only, so a bundle
#'   that lists packages in \code{r_packages} (or downloads its data, which
#'   needs rmoriebricklayer) needs an image that has them. Without the
#'   runtime the check falls back to the next mode and says so.}
#' \item{pid namespace}{Linux, when \command{unshare} can make an
#'   unprivileged user and PID namespace: every process the run started,
#'   also one that started its own session or forked twice, is killed when
#'   the run ends or times out.}
#' \item{job object}{Windows: the run is started inside a job object that
#'   kills every process in it when the run ends or times out.}
#' \item{process group}{Linux without user namespaces, and macOS: the
#'   run leads a process group, killed when it ends, times out or is
#'   interrupted. A process can leave the group (setsid, a double fork) and
#'   clear its environment. On Linux this R session is made the run's child
#'   subreaper, so such a process is re-parented to it rather than to
#'   init: every process the run left behind is found by the process tree,
#'   killed by its PID and fails the check (the isolation row is an error).
#'   Where that cannot be done (macOS, or a Linux kernel older than 3.4)
#'   escaped processes cannot be detected, and the isolation row fails:
#'   use \code{container = TRUE} there.}
#' }
#'
#' Only a \file{results_*} folder the run itself created counts: one the
#' zip already carries (which [mkbndl()] never packs) is not read, and
#' fails the check. A run that writes no manifest, or whose runner reports
#' \dQuote{NOT completed}, fails.
#'
#' Errors: \code{bundle} that is not an existing \file{.zip} file, or not
#' a zip this function reads (more than 65535 entries, an entry name with a
#' NUL byte, one too long, absolute or leaving the folder, or an entry
#' given twice); a zip without \file{setup_and_run.R}; \code{data} that is
#' not an existing file; \code{dir} that already exists.
#'
#' @param bundle Path to the bundle zip.
#' @param data Optional path to the data file, passed to the run as
#'   \code{--data}. \code{NULL} (default): the bundle finds the file,
#'   downloads it or, with \code{synthetic = TRUE}, generates data.
#' @param synthetic Run on synthetic data (\code{--synthetic}), default
#'   \code{FALSE}; needs no data file and no network.
#' @param dir A folder to unzip into, which must not exist yet. Default: a
#'   new folder under \code{tempdir()}.
#' @param keep Keep that folder after the check, default \code{FALSE}.
#' @param container Run the bundle in a container: \code{NULL} or
#'   \code{FALSE} (default) do not, \code{TRUE} uses podman, else docker,
#'   and \code{"podman"} or \code{"docker"} names the runtime. See Details.
#' @return An object of class \code{rmbl_bundle_audit}: a list with
#'   \code{ok}, \code{checks} (a data frame of \code{check}, \code{ok},
#'   \code{detail} and \code{severity}), \code{mode} (the input the run
#'   used, from its manifest: \code{synthetic} when it is marked
#'   synthetic, else its \code{meta$input_mode} when it records one, such
#'   as \code{csv}, else \code{real}), \code{counts} (\code{total}, \code{pass},
#'   \code{differ}, \code{info}), \code{log} (the last 30 lines the run
#'   printed), \code{isolation} (how the run was contained: see Details),
#'   \code{bundle} and \code{dir} (the unzipped bundle, or for a container
#'   run the folder it wrote into; \code{NA} once removed). It prints as a
#'   box.
#' @seealso [mkbndl()] builds the bundle;
#'   [mkbndlproj()] starts a project.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' proj <- file.path(tempdir(), "audit-demo")
#' mkbndlproj(proj, title = "Demo analysis")
#' b <- mkbndl(proj, dest = tempdir(), overwrite = TRUE)
#' a <- mkbndlchk(b$path, synthetic = TRUE)
#' a
#' a$counts
#' @export
mkbndlchk <- function(bundle, data = NULL, synthetic = FALSE, dir = NULL,
                      keep = FALSE, container = NULL) {
  a <- .bndlchk_args(bundle, data, synthetic, dir, keep)
  ctr <- .bndlchk_ctrarg(container)
  # the zip's directory is read and checked before anything is unzipped
  cd <- .bndlchk_cd(a$bundle)
  dir.create(a$dir, recursive = TRUE)
  if (!a$keep) {
    on.exit(unlink(a$dir, recursive = TRUE), add = TRUE)
  }
  root <- .bndlchk_unzip(a$bundle, a$dir)
  # results folders the zip carries are not this run's
  before <- .bndlchk_results(root)
  # a container writes its results into a folder of its own
  out <- if (!is.null(ctr)) tempfile("bndlout")
  if (!is.null(out) && !a$keep) {
    on.exit(unlink(out, recursive = TRUE, force = TRUE), add = TRUE)
  }
  run <- .bndlchk_run(root, a$data, a$synthetic, ctr = ctr, out = out)
  man <- .bndlchk_manifest(run$root, before, run$log)
  checks <- .bndlchk_checks(run, man, before, root, cd)
  hard <- checks$severity == "error"
  .rmbl_cls(list(
    ok = all(checks$ok[hard]),
    checks = checks,
    mode = man$mode %||% NA_character_,
    counts = man$counts %||% c(total = NA, pass = NA, differ = NA, info = NA),
    log = utils::tail(run$log, 30L),
    isolation = run$isolation,
    bundle = normalizePath(a$bundle, winslash = "/"),
    dir = if (a$keep) {
      normalizePath(run$root, winslash = "/")
    } else {
      NA_character_
    }
  ), "rmbl_bundle_audit")
}

#' @export
format.rmbl_bundle_audit <- function(x, ...) {
  n <- x$counts
  .rmbl_stat_block(
    sprintf(
      "Bundle audit: %s", if (isTRUE(x$ok)) "VERIFIED" else "NOT VERIFIED"
    ),
    facts = list(
      Bundle = basename(x$bundle),
      `Input mode` = x$mode,
      Isolation = x$isolation %||% NA_character_,
      Checks = n[["total"]],
      PASS = n[["pass"]],
      DIFFER = n[["differ"]],
      INFO = n[["info"]]
    ),
    reading = .rmbl_check_reading(
      x$ok,
      "the bundle runs as a recipient's copy will and is safe to ship",
      "do not ship it yet: fix what failed and build it again"
    ),
    notes = c(
      .rmbl_check_lines(x$checks),
      if (!isTRUE(x$ok) && length(x$log)) {
        c("", "The run's last lines:", x$log)
      }
    )
  )
}

#' The checks of a bundle's run, one row each.
#' @param run The run, from .bndlchk_run().
#' @param man The manifest the run wrote, or NULL.
#' @param before The results folders the zip carried.
#' @param root The unzipped bundle's folder.
#' @param cd The zip's central directory, from .bndlchk_cd().
#' @return A data frame.
#' @noRd
.bndlchk_checks <- function(run, man, before, root, cd) {
  nc <- any(grepl("NOT completed", run$log, fixed = TRUE))
  rbind(
    .bndlchk_row(
      "run finished", run$status == 0L && !nc,
      paste0(sprintf("exit status %d", run$status),
             if (nc) "; the runner says NOT completed")
    ),
    .bndlchk_row(
      "manifest written", !is.null(man),
      if (is.null(man)) {
        "no manifest.json in a results_* folder this run created"
      } else {
        man$path
      }
    ),
    .bndlchk_differ(man),
    .bndlchk_expected(root, man),
    .bndlchk_launchers(cd$modes),
    .bndlchk_row(
      "no results packed in the zip", !length(before),
      if (length(before)) {
        paste("the zip carries", toString(basename(before)))
      } else {
        "none"
      }
    ),
    .bndlchk_iso(run$isolation, run$left, run$blind)
  )
}

#' mkbndlchk()'s `container`, checked.
#' @param x NULL, TRUE, FALSE, "podman" or "docker".
#' @return NULL, TRUE or the runtime's name.
#' @noRd
.bndlchk_ctrarg <- function(x) {
  if (is.null(x) || isFALSE(x)) {
    return(NULL)
  }
  if (isTRUE(x) || (is.character(x) && length(x) == 1L &&
                      x %in% c("podman", "docker"))) {
    return(x)
  }
  stop("`container` must be NULL, TRUE, FALSE, \"podman\" or \"docker\"",
       call. = FALSE)
}

#' The row that says how the run was isolated: an error when a process
#' outlived the run (only a process group held it, and a process left it).
#' @param iso The isolation, from .bndlchk_run().
#' @param left The processes that outlived the run (killed since).
#' @param blind Whether escaped processes could not be looked for.
#' @return A one-row data frame.
#' @noRd
.bndlchk_iso <- function(iso, left = integer(), blind = FALSE) {
  if (length(left)) {
    return(.bndlchk_row(
      "isolation", FALSE,
      sprintf("%s: %d process(es) outlived the run and were killed (%s)",
              iso, length(left), toString(utils::head(left, 5L)))
    ))
  }
  if (isTRUE(blind)) {
    return(.bndlchk_row(
      "isolation", FALSE,
      paste0(iso, ": cannot detect escaped processes on this system ",
             "(a process that left the group would go unseen): check it ",
             "with container = TRUE")
    ))
  }
  .bndlchk_row(
    "isolation", TRUE,
    if (startsWith(iso, "process group")) {
      paste0(iso, ": no process outlived the run")
    } else {
      iso
    },
    severity = "warn"
  )
}

#' mkbndlchk()'s arguments, checked.
#' @param bundle,data,synthetic,dir,keep As for mkbndlchk().
#' @return A list of the five.
#' @noRd
.bndlchk_args <- function(bundle, data, synthetic, dir, keep) {
  bundle <- .rmbl_string1(bundle, "bundle")
  if (!file.exists(bundle) || dir.exists(bundle) ||
        !grepl("[.]zip$", bundle, ignore.case = TRUE)) {
    stop(sprintf("`bundle` is not an existing .zip file: %s", bundle),
         call. = FALSE)
  }
  if (!is.null(data)) {
    data <- .rmbl_string1(data, "data")
    if (!file.exists(data) || dir.exists(data)) {
      stop(sprintf("`data` is not an existing file: %s", data), call. = FALSE)
    }
    data <- normalizePath(data, winslash = "/")
  }
  dir <- if (is.null(dir)) tempfile("bndlchk") else .rmbl_string1(dir, "dir")
  if (file.exists(dir)) {
    stop(sprintf("`dir` already exists: %s", dir), call. = FALSE)
  }
  list(
    bundle = bundle,
    data = data,
    synthetic = .rmbl_flag1(synthetic, "synthetic"),
    dir = dir,
    keep = .rmbl_flag1(keep, "keep")
  )
}

#' Unzips a bundle and finds its runner.
#' @param bundle The zip.
#' @param dir The folder to unzip into.
#' @return The folder holding setup_and_run.R.
#' @noRd
.bndlchk_unzip <- function(bundle, dir) {
  ok <- tryCatch(
    {
      utils::unzip(bundle, exdir = dir)
      TRUE
    },
    warning = function(w) conditionMessage(w),
    error = function(e) conditionMessage(e)
  )
  if (!isTRUE(ok)) {
    stop(sprintf("mkbndlchk: %s could not be unzipped: %s",
                 basename(bundle), ok), call. = FALSE)
  }
  cand <- c(dir, list.dirs(dir, recursive = FALSE))
  root <- cand[file.exists(file.path(cand, "setup_and_run.R"))][1L]
  if (is.na(root)) {
    stop("the bundle has no setup_and_run.R", call. = FALSE)
  }
  root
}

#' Runs the bundle as a recipient would, in a child R.
#' @param root The unzipped bundle.
#' @param data The data file to pass as --data, or NULL.
#' @param synthetic Whether to run on synthetic data.
#' @param win Whether to run it the Windows way.
#' @param ctr The container runtime asked for (see .bndlchk_rt()), or NULL.
#' @param out The folder a container run writes into, or NULL.
#' @return A list: the exit status, the lines the run printed, the
#'   isolation it ran under and the folder its results are in.
#' @noRd
.bndlchk_run <- function(root, data, synthetic,
                         win = .Platform$OS.type == "windows",
                         ctr = NULL, out = NULL) {
  args <- c(
    "setup_and_run.R", "--quick",
    if (synthetic) "--synthetic",
    if (!is.null(data)) c("--data", data)
  )
  log <- tempfile("bndlchk", fileext = ".log")
  file.create(log)
  on.exit(unlink(log), add = TRUE)
  # the run's own HOME and TMPDIR, removed afterwards
  home <- tempfile("bndlhome")
  dir.create(file.path(home, "tmp"), recursive = TRUE)
  on.exit(unlink(home, recursive = TRUE, force = TRUE), add = TRUE)
  # a check run inside R CMD check would hand the child its test startup
  withr::local_envvar(R_TESTS = NA)
  withr::local_dir(root)
  exe <- if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
  rscript <- file.path(R.home("bin"), exe)
  tmout <- .bndlchk_tmout()
  rt <- .bndlchk_rt(ctr)
  r <- if (length(rt$path)) {
    .bndlchk_ctr(rt, root, args, data, !synthetic && is.null(data), tmout,
                 log, out %||% file.path(home, "out"))
  } else if (isTRUE(win)) {
    .bndlchk_win(rscript, args, home, tmout, log)
  } else {
    .bndlchk_posix(rscript, args, home, tmout, log)
  }
  if (identical(as.integer(r$status), 124L)) {
    cat(sprintf("\nstopped: the run took longer than %d seconds\n", tmout),
        file = log, append = TRUE)
  }
  list(
    status = as.integer(r$status),
    log = readLines(log, warn = FALSE),
    isolation = paste0(r$mode, if (length(rt) && !length(rt$path)) {
      sprintf(" (no %s found for a container)", rt$kind)
    }),
    root = r$root %||% root,
    left = r$left %||% integer(),
    blind = isTRUE(r$blind)
  )
}

#' Seconds a bundle run may take: option rmbl.bundle.timeout, default 1800.
#' @return One integer.
#' @noRd
.bndlchk_tmout <- function() {
  t <- suppressWarnings(as.integer(getOption("rmbl.bundle.timeout", 1800L)))
  if (length(t) != 1L || is.na(t) || t < 1L) 1800L else t
}

#' Runs the bundle on macOS or Linux: `env -i` with the minimal
#' environment, through a shell that puts the run in a process group of its
#' own and kills that whole group when the run ends, times out or is
#' interrupted; on Linux inside a PID namespace too, when unshare can make
#' one, so a process that left the group (setsid, a double fork) dies with
#' the run as well.
#' @param rscript The Rscript program.
#' @inheritParams .rmbl_fipsmod_run
#' @param home The run's HOME.
#' @param tmout Seconds before the run is stopped.
#' @param log The file the output goes to.
#' @return A list: the exit status (124 when the run was stopped) and the
#'   isolation used.
#' @noRd
.bndlchk_posix <- function(rscript, args, home, tmout, log) {
  # job control (set -m) gives the run its own group; bash keeps it without
  # a terminal, where dash turns it off
  sh <- Sys.which("bash")
  if (!nzchar(sh)) sh <- "/bin/sh"
  envp <- Sys.which("env")
  if (!nzchar(envp)) envp <- "/usr/bin/env"
  wrap <- file.path(home, "run.sh")
  writeLines(.bndlchk_wrap(), wrap)
  # the run's mark: what still carries it afterwards outlived the run
  tag <- basename(tempfile("rmblchk"))
  env <- c(.rmbl_envmin(home), RMBL_CHKRUN = tag)
  pidns <- .bndlchk_unshare()
  cmd <- c(
    "-i", paste0(names(env), "=", env), pidns, sh, wrap, tmout,
    file.path(home, "timed_out"), rscript, args
  )
  # this session the run's subreaper: what leaves the run stays below it
  reap <- .bndlchk_reaper(TRUE)
  if (reap) {
    on.exit(.bndlchk_reaper(FALSE), add = TRUE)
  }
  before <- .bndlchk_procs()
  # system2()'s own limit is a backstop: the shell stops the run first
  st <- suppressWarnings(system2(
    envp, shQuote(cmd), stdout = log, stderr = log, timeout = tmout + 60L
  ))
  left <- union(.bndlchk_left(tag), .bndlchk_desc(before))
  .bndlchk_kill(left)
  list(
    status = st,
    mode = if (length(pidns)) "pid namespace" else "process group",
    left = left,
    blind = !reap && !length(pidns)
  )
}

#' Makes this R session the child subreaper of what it starts, or stops it
#' being one (Linux; rmbl_reap.c).
#' @param on TRUE to set, FALSE to clear.
#' @return TRUE when it is now as asked (always FALSE off Linux).
#' @noRd
.bndlchk_reaper <- function(on) {
  isTRUE(.Call(C_rmbl_subreap, on))
}

#' The processes of this machine as /proc lists them (Linux), each with its
#' parent, state and start time; NULL elsewhere.
#' @return A data frame (pid, ppid, state, key), or NULL.
#' @noRd
.bndlchk_procs <- function() {
  if (!identical(Sys.info()[["sysname"]], "Linux") || !dir.exists("/proc")) {
    return(NULL)
  }
  p <- list.files("/proc", pattern = "^[0-9]+$")
  # a process can end while it is read: its line is then ""
  st <- vapply(p, function(k) {
    c(tryCatch(readLines(file.path("/proc", k, "stat"), n = 1L, warn = FALSE),
               error = function(e) "", warning = function(w) ""), "")[1L]
  }, "", USE.NAMES = FALSE)
  # the fields after the name in parentheses (which may hold spaces)
  f <- strsplit(sub("^.*\\) ", "", st), " ", fixed = TRUE)
  ok <- nzchar(st) & lengths(f) >= 20L
  f <- f[ok]
  data.frame(
    pid = as.integer(p[ok]),
    ppid = as.integer(vapply(f, `[`, "", 2L)),
    state = vapply(f, `[`, "", 1L),
    key = paste(p[ok], vapply(f, `[`, "", 20L)),
    stringsAsFactors = FALSE
  )
}

#' The processes below this session that were not there before the run:
#' what the run left behind. A zombie (one that already ended) does not
#' count, and is reaped.
#' @param before The processes before the run, from .bndlchk_procs().
#' @param me This session's process id.
#' @return Process ids.
#' @noRd
.bndlchk_desc <- function(before, me = Sys.getpid()) {
  now <- .bndlchk_procs()
  if (is.null(before) || is.null(now)) {
    return(integer())
  }
  below <- integer()
  up <- me
  while (length(up)) {
    up <- setdiff(now$pid[now$ppid %in% up], c(below, me))
    below <- c(below, up)
  }
  new <- now[now$pid %in% below & !now$key %in% before$key, ]
  z <- new$pid[new$state == "Z"]
  if (length(z)) {
    .Call(C_rmbl_reap, z)
  }
  new$pid[new$state != "Z"]
}

#' Kills processes by their exact ids and reaps those that were this
#' session's children.
#' @param pids Process ids.
#' @return NULL, invisibly.
#' @noRd
.bndlchk_kill <- function(pids) {
  if (length(pids)) {
    tools::pskill(pids, tools::SIGKILL)
    Sys.sleep(0.2)
    .Call(C_rmbl_reap, as.integer(pids))
  }
  invisible(NULL)
}

#' The processes that still carry a run's mark (RMBL_CHKRUN) in their
#' environment: on Linux read from /proc, on macOS from ps -E; elsewhere
#' none are seen.
#' @param tag The run's mark.
#' @inheritParams .rmbl_ossha
#' @return Process ids.
#' @noRd
.bndlchk_left <- function(tag, sys = Sys.info()[["sysname"]]) {
  mark <- paste0("RMBL_CHKRUN=", tag)
  pids <- if (identical(sys, "Linux") && dir.exists("/proc")) {
    p <- list.files("/proc", pattern = "^[0-9]+$")
    p[vapply(p, function(k) {
      b <- tryCatch(
        readBin(file.path("/proc", k, "environ"), "raw", 1048576L),
        error = function(e) raw(), warning = function(w) raw()
      )
      length(grepRaw(mark, b, fixed = TRUE)) > 0L
    }, NA)]
  } else if (identical(sys, "Darwin")) {
    out <- tryCatch(suppressWarnings(system2(
      "ps", c("-E", "-ww", "-ax", "-o", "pid=,command="),
      stdout = TRUE, stderr = FALSE
    )), error = function(e) character())
    sub("^ *([0-9]+).*$", "\\1", grep(mark, out, fixed = TRUE, value = TRUE))
  }
  setdiff(as.integer(pids), Sys.getpid())
}

#' The unshare command that runs a bundle in a PID namespace of its own,
#' or nothing where there is none (not Linux, no unshare, or unprivileged
#' user namespaces switched off). The namespace's first process is the
#' run's shell: when it exits the kernel kills every process left in the
#' namespace, including one that started its own session.
#' @param us The unshare program ("" when there is none).
#' @return The command words to put in front of the run, or NULL.
#' @noRd
.bndlchk_unshare <- function(us = .bndlchk_which("unshare")) {
  if (!nzchar(us) || !identical(Sys.info()[["sysname"]], "Linux")) {
    return(NULL)
  }
  flags <- c("--user", "--pid", "--fork", "--kill-child", "--mount-proc")
  st <- suppressWarnings(system2(us, c(flags, "true"), stdout = FALSE,
                                 stderr = FALSE))
  if (identical(as.integer(st), 0L)) c(us, flags) else NULL
}

#' A program's path on the PATH, or "".
#' @param x The program.
#' @return One string.
#' @noRd
.bndlchk_which <- function(x) unname(Sys.which(x))

#' The shell that runs a bundle in its own process group.
#'
#' Arguments: the time limit, the file that marks a timeout, then the
#' command. The run is started with job control on, so it leads a process
#' group of its own; a watchdog stops that group at the limit; when the run
#' ends, whatever is left in the group (a process it put in the background)
#' is killed; an interrupt or TERM kills the group too.
#' @return The lines of the script.
#' @noRd
.bndlchk_wrap <- function() {
  c(
    "t=$1; m=$2; shift 2",
    "set -m",
    "\"$@\" < /dev/null &",
    "p=$!",
    paste(
      "( sleep \"$t\"; : > \"$m\"; kill -TERM -\"$p\" 2>/dev/null;",
      "sleep 5; kill -KILL -\"$p\" 2>/dev/null ) &"
    ),
    "w=$!",
    "set +m",
    paste(
      "trap 'kill -TERM -\"$p\" 2>/dev/null; kill -TERM -\"$w\"",
      "2>/dev/null; exit 130' INT TERM HUP"
    ),
    "wait \"$p\"",
    "rc=$?",
    "trap - INT TERM HUP",
    "{ kill -TERM -\"$w\"; wait \"$w\"; } 2>/dev/null",
    "if kill -0 -\"$p\" 2>/dev/null; then",
    "  kill -TERM -\"$p\" 2>/dev/null",
    "  sleep 1",
    "  kill -KILL -\"$p\" 2>/dev/null",
    "fi",
    "if [ -f \"$m\" ]; then rc=124; fi",
    "exit $rc"
  )
}

#' Runs the bundle on Windows: the variables whose names look like
#' credentials removed and HOME a temporary folder, for the run only, and
#' the run started inside a job object that kills every process in it when
#' the run ends or times out.
#' @param rscript,args,home,tmout,log As for .bndlchk_posix().
#' @return A list: the exit status (124 when the run was stopped) and the
#'   isolation used.
#' @noRd
.bndlchk_win <- function(rscript, args, home, tmout, log) {
  e <- unclass(Sys.getenv())
  drop <- .rmbl_envdrop(names(e), unname(e))
  tmp <- file.path(home, "tmp")
  withr::local_envvar(c(
    stats::setNames(rep(NA_character_, length(drop)), drop),
    HOME = home, R_USER = home, TMPDIR = tmp, TMP = tmp, TEMP = tmp
  ))
  cmd <- paste(shQuote(c(rscript, args), type = "cmd"), collapse = " ")
  list(status = .rmbl_wjob(cmd, log, tmout), mode = "job object")
}

#' Runs a command line inside a Windows job object (rmbl_winjob.c).
#' @param cmd The command line.
#' @param log The file its output goes to.
#' @param tmout Seconds before the job is killed.
#' @return The exit status, 124 when the job was killed at the limit.
#' @noRd
.rmbl_wjob <- function(cmd, log, tmout) {
  .Call(C_rmbl_winjob, cmd, normalizePath(log, mustWork = FALSE),
        as.numeric(tmout))
}

#' The container runtime a check asked for.
#' @param ctr NULL or FALSE (none), TRUE (podman, else docker), or
#'   "podman" or "docker".
#' @return NULL when none was asked for, else a list: path (NULL when it is
#'   not installed) and kind.
#' @noRd
.bndlchk_rt <- function(ctr) {
  if (is.null(ctr) || isFALSE(ctr)) {
    return(NULL)
  }
  kinds <- if (isTRUE(ctr)) c("podman", "docker") else ctr
  for (k in kinds) {
    p <- .bndlchk_which(k)
    if (nzchar(p)) return(list(path = p, kind = k))
  }
  list(path = NULL, kind = paste(kinds, collapse = " or "))
}

#' The default image a container check runs in: R 4.6.1 from the Rocker
#' project, pinned by digest (option rmbl.bundle.image overrides it).
#' @return One image reference.
#' @noRd
.bndlchk_image <- function() {
  getOption(
    "rmbl.bundle.image",
    paste0(
      "docker.io/rocker/r-ver:4.6.1@sha256:",
      "e8732fa6afb69b43ec7f22cb801f59e89e2a84c6a6b043537e7a46314770ac16"
    )
  )
}

#' Runs the bundle in a container: the unzipped bundle mounted read-only
#' and copied into a writable folder the results are written to, no network
#' unless the run needs the real data, memory, CPU and process limits, a
#' read-only root file system, no capabilities, this user's id, and the
#' container removed afterwards (also when it times out).
#' @param rt The runtime, from .bndlchk_rt().
#' @param root The unzipped bundle.
#' @param args The runner's arguments.
#' @inheritParams .bndl_pages
#' @param net Whether the run may use the network.
#' @param tmout Seconds before the run is stopped.
#' @param log The file the output goes to.
#' @param out The writable folder, created if needed.
#' @return A list: the exit status, the isolation and the results folder.
#' @noRd
.bndlchk_ctr <- function(rt, root, args, data, net, tmout, log, out) {
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  dd <- NULL
  if (!is.null(data)) {
    # a copy is mounted (and relabelled for SELinux), never the user's file
    dd <- tempfile("bndldata")
    dir.create(dd)
    on.exit(unlink(dd, recursive = TRUE, force = TRUE), add = TRUE)
    file.copy(data, file.path(dd, basename(data)))
    args[args == data] <- file.path("/data", basename(data))
  }
  name <- paste0("rmblchk-", sub("^file", "", basename(tempfile())))
  on.exit(suppressWarnings(system2(rt$path, c("rm", "-f", name),
                                   stdout = FALSE, stderr = FALSE)),
          add = TRUE)
  cmd <- c(
    .bndlchk_ctrargs(rt$kind, name, net, root, out, dd), .bndlchk_image(),
    "sh", "-c", "cp -R /bundle/. /out/ && exec Rscript \"$@\"", "sh", args
  )
  st <- suppressWarnings(system2(
    rt$path, shQuote(cmd), stdout = log, stderr = log, timeout = tmout
  ))
  list(status = st, mode = sprintf("container (%s)", rt$kind), root = out)
}

#' The `run` arguments of a container check, before the image.
#' @param kind "podman" or "docker".
#' @param name The container's name.
#' @param net Whether the run may use the network.
#' @param root,out,dd The bundle, the writable folder and the data folder
#'   (or NULL), mounted at /bundle (read-only), /out and /data (read-only).
#' @return Character.
#' @noRd
.bndlchk_ctrargs <- function(kind, name, net, root, out, dd) {
  bad <- grepl("[:,]", c(root, out, dd))
  if (any(bad)) {
    stop("mkbndlchk: a container check needs folders without ':' or ','",
         call. = FALSE)
  }
  c(
    "run", "--rm", "--name", name,
    if (!isTRUE(net)) c("--network", "none"),
    "--memory", "4g", "--cpus", "2", "--pids-limit", "512",
    "--read-only", "--tmpfs", "/tmp", "--cap-drop", "ALL",
    "--security-opt", "no-new-privileges",
    "-e", "HOME=/tmp", "-e", "TMPDIR=/tmp",
    if (identical(kind, "podman")) "--userns=keep-id",
    "--user", .bndlchk_uid(),
    "-v", paste0(root, ":/bundle:ro,z"), "-v", paste0(out, ":/out:z"),
    if (length(dd)) c("-v", paste0(dd, ":/data:ro,z")),
    "-w", "/out"
  )
}

#' This user's uid:gid, for a container to run as (1000:1000 on Windows).
#' @param unix Whether this is a Unix system, where `id` tells.
#' @return One string.
#' @noRd
.bndlchk_uid <- function(unix = .Platform$OS.type == "unix") {
  if (!isTRUE(unix)) {
    return("1000:1000")
  }
  ids <- vapply(c("-u", "-g"), function(f) {
    suppressWarnings(system2("id", f, stdout = TRUE))[1L]
  }, "")
  paste(ids, collapse = ":")
}

#' The environment a bundle check runs in: PATH, the locale, the library
#' search paths and a fresh HOME and TMPDIR; nothing else, so no key,
#' token or password reaches the bundle's code.
#' @param home The run's HOME (its tmp folder is TMPDIR).
#' @return A named character vector.
#' @noRd
.rmbl_envmin <- function(home) {
  e <- unclass(Sys.getenv())
  n <- names(e)
  # what R itself needs to start (a module system's library path), the
  # certificate bundle a download checks against, and a proxy only when it
  # carries no user name or password
  # the locale: the variables POSIX and glibc define, no other LC_* name
  # (LC_FAKE_SECRET reached the run)
  keep <- n %in% c(
    "PATH", "TZ", "LD_LIBRARY_PATH", "DYLD_LIBRARY_PATH",
    "DYLD_FALLBACK_LIBRARY_PATH", "SSL_CERT_FILE", "SSL_CERT_DIR",
    "CURL_CA_BUNDLE", .rmbl_lcvars()
  ) |
    (tolower(n) %in% c("http_proxy", "https_proxy", "no_proxy") &
       !grepl("@", e, fixed = TRUE))
  keep <- keep & !grepl("[^A-Za-z0-9_]", n)
  c(
    e[keep],
    HOME = home,
    TMPDIR = file.path(home, "tmp"),
    R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep)
  )
}

#' The locale variables a run keeps: LANG, LANGUAGE, LC_ALL and the
#' categories POSIX and glibc define.
#' @return Variable names.
#' @noRd
.rmbl_lcvars <- function() {
  c("LANG", "LANGUAGE", "LC_ALL", paste0("LC_", c(
    "CTYPE", "COLLATE", "TIME", "NUMERIC", "MONETARY", "MESSAGES", "PAPER",
    "NAME", "ADDRESS", "TELEPHONE", "MEASUREMENT", "IDENTIFICATION"
  )))
}

#' The names of environment variables that look like credentials (the
#' Windows run removes them; elsewhere only an allowed few are passed).
#'
#' Removed: a service's prefix (GITHUB_, AWS_, ...); a name holding KEY,
#' TOKEN, SECRET, PASS (PASSWORD), CREDENTIAL, AUTH, COOKIE or SESSION; a
#' connection string (DATABASE_URL, *_DATABASE_URL, *_WEBHOOK_URL,
#' SENTRY_DSN, *_DSN), a *_PWD or *_SK (STRIPE_SK); an LC_* name that is
#' not a locale category; and a value that is a URL with a password in it
#' (with or without a user name).
#' @param n Variable names.
#' @param v Their values, or NULL.
#' @return The ones to remove.
#' @noRd
.rmbl_envdrop <- function(n, v = NULL) {
  pre <- paste0(
    "^(RMBL|RMORIE|MORIE|IA|GITHUB|GH|OPENAI|ANTHROPIC|AWS|AZURE|GOOGLE|",
    "GCP|GEMINI|MISTRAL|COHERE|GROQ|HF|HUGGINGFACE|CODECOV|CLOUDFLARE|CF|",
    "R2|OLLAMA)_"
  )
  bad <- grepl(pre, n, ignore.case = TRUE) |
    grepl("KEY|TOKEN|SECRET|PASS|CREDENTIAL|AUTH|COOKIE|SESSION", n,
          ignore.case = TRUE) |
    grepl("(^|_)(DATABASE_URL|WEBHOOK_URL|DSN|SK)$|_PWD$", n,
          ignore.case = TRUE) |
    (startsWith(toupper(n), "LC_") & !toupper(n) %in% .rmbl_lcvars())
  if (!is.null(v)) {
    # a password with or without a user name: redis://:pw@host
    bad <- bad | grepl("://[^/@[:space:]]*:[^/@[:space:]]*@", v)
  }
  n[bad]
}

#' The results folders in an unzipped bundle.
#' @param root The unzipped bundle.
#' @return Normalised paths.
#' @noRd
.bndlchk_results <- function(root) {
  res <- list.files(root, pattern = "^results_", full.names = TRUE)
  normalizePath(res[dir.exists(res)], winslash = "/")
}

#' The manifest of the results folder this run created, counted.
#'
#' Only a folder that was not there before the run counts (a zip can carry
#' a results folder with any name and date); when the run created several,
#' the one the runner names (\dQuote{Results folder: ...}) is read.
#' @param root The unzipped bundle.
#' @param before The results folders there before the run.
#' @param log The lines the run printed.
#' @return NULL when there is none, else a list: path, mode, counts.
#' @noRd
.bndlchk_manifest <- function(root, before = character(),
                              log = character()) {
  # by name: a container's results folder is a copy of the bundle
  res <- .bndlchk_results(root)
  res <- res[!basename(res) %in% basename(before)]
  res <- res[file.exists(file.path(res, "manifest.json"))]
  if (length(res) > 1L) {
    said <- trimws(sub(".*Results folder: ", "",
                       grep("Results folder: ", log, fixed = TRUE,
                            value = TRUE)))
    said <- normalizePath(said, winslash = "/", mustWork = FALSE)
    res <- res[res %in% said]
  }
  if (length(res) != 1L) {
    return(NULL)
  }
  path <- file.path(res, "manifest.json")
  m <- tryCatch(fromjs(path, simplifyVector = FALSE),
                error = function(e) NULL)
  if (!is.list(m)) {
    return(NULL)
  }
  st <- vapply(m$results, function(r) {
    if (is.list(r)) as.character(r$status %||% "")[1L] else ""
  }, "")
  list(
    path = normalizePath(path, winslash = "/"),
    mode = if (isTRUE(m$meta$synthetic)) {
      "synthetic"
    } else {
      as.character(m$meta$input_mode %||% "real")
    },
    counts = c(
      total = length(st),
      pass = sum(st == "PASS"),
      differ = sum(st == "DIFFER"),
      info = sum(st == "INFO")
    )
  )
}

#' One row of the checks table.
#' @param check Its name.
#' @param ok Whether the check passed.
#' @param detail What the check found.
#' @param severity "error" (fails the audit) or "warn".
#' @return A one-row data frame.
#' @noRd
.bndlchk_row <- function(check, ok, detail, severity = "error") {
  data.frame(
    check = check, ok = isTRUE(ok), detail = detail, severity = severity,
    stringsAsFactors = FALSE
  )
}

#' The check that no cross-check differs.
#' @param man The manifest, from .bndlchk_manifest().
#' @return A one-row data frame.
#' @noRd
.bndlchk_differ <- function(man) {
  if (is.null(man)) {
    return(.bndlchk_row("no cross-check differs", FALSE, "no manifest"))
  }
  d <- man$counts[["differ"]]
  .bndlchk_row("no cross-check differs", d == 0L, sprintf("%d DIFFER", d))
}

#' The check that a real-data run gives the counts config.json expects.
#' @param root The unzipped bundle.
#' @param man The manifest, from .bndlchk_manifest().
#' @return A one-row data frame.
#' @noRd
.bndlchk_expected <- function(root, man) {
  nm <- "counts match config.json"
  if (is.null(man)) {
    return(.bndlchk_row(nm, FALSE, "no manifest"))
  }
  if (identical(man$mode, "synthetic")) {
    return(.bndlchk_row(nm, TRUE, "not compared: a synthetic run"))
  }
  cfg <- file.path(root, "config.json")
  ex <- if (file.exists(cfg)) fromjs(cfg, simplifyVector = FALSE)$expected
  key <- if (identical(man$mode, "csv")) "pass_csv" else "pass_real"
  tot <- ex$total_checks
  pass <- ex[[key]]
  if (is.null(tot) || is.null(pass)) {
    return(.bndlchk_row(nm, TRUE, "not compared: config.json expects none"))
  }
  n <- man$counts
  .bndlchk_row(
    nm, n[["total"]] == tot && n[["pass"]] == pass,
    sprintf("%s expects %s/%s PASS; the %s run gave %d/%d",
            key, pass, tot, man$mode, n[["pass"]], n[["total"]])
  )
}

#' The check that the launchers are executable inside the zip.
#' @param modes The Unix modes of the zip's entries, named by path.
#' @return A one-row data frame (a warning, not an error).
#' @noRd
.bndlchk_launchers <- function(modes) {
  l <- modes[grepl("[.](sh|command)$", names(modes))]
  bad <- names(l)[bitwAnd(as.integer(l), 64L) == 0L]
  .bndlchk_row(
    "launchers executable", !length(bad),
    if (length(bad)) {
      paste("not executable in the zip:", toString(bad))
    } else {
      sprintf("%d launcher(s)", length(l))
    },
    severity = "warn"
  )
}

#' The central directory of a zip and the entry count its end record gives.
#' @param zip The bundle zip.
#' @return A list: cd (raw, empty when none is found) and n (the count, NA
#'   when there is no end record).
#' @noRd
.bndlchk_cd_raw <- function(zip) {
  none <- list(cd = raw(), n = NA_real_)
  sz <- file.size(zip)
  con <- file(zip, "rb")
  on.exit(close(con), add = TRUE)
  n <- min(sz, 65557)
  seek(con, sz - n)
  tl <- readBin(con, "raw", n)
  at <- grepRaw(as.raw(c(0x50, 0x4b, 0x05, 0x06)), tl, all = TRUE)
  at <- at[at + 21L <= length(tl)]
  if (!length(at)) {
    return(none)
  }
  e <- tl[at[length(at)] + 0:21]
  off <- .bndlchk_u32(e, 17L)
  len <- .bndlchk_u32(e, 13L)
  # a directory claimed beyond the file's end (a damaged or hostile zip)
  # is not read: readBin() would allocate the size it is given
  if (off + len > sz) {
    return(none)
  }
  seek(con, off)
  list(cd = readBin(con, "raw", len), n = .bndlchk_u16(e, 11L))
}

#' Walks a central directory: each entry's name (raw) and Unix mode.
#'
#' The vectors are filled in place, in one pass: growing a named vector
#' one entry at a time took 51 s on 70,000 entries.
#' @param cd The central directory's bytes.
#' @return A list: names (a list of raw vectors) and modes (numeric).
#' @noRd
.bndlchk_cd_walk <- function(cd) {
  cap <- max(1L, length(cd) %/% 46L)
  names <- vector("list", cap)
  modes <- numeric(cap)
  k <- 0L
  i <- 1L
  while (i + 45L <= length(cd)) {
    ln <- .bndlchk_u16(cd, i + 28L)
    skip <- ln + .bndlchk_u16(cd, i + 30L) + .bndlchk_u16(cd, i + 32L)
    k <- k + 1L
    names[[k]] <- cd[i + 46L + seq_len(min(ln, length(cd) - i - 45L)) - 1L]
    modes[k] <- .bndlchk_u32(cd, i + 38L) %/% 65536
    i <- i + 46L + skip
  }
  list(names = names[seq_len(k)], modes = modes[seq_len(k)])
}

#' Reads a bundle zip's central directory and refuses what it cannot
#' safely unzip: no directory, more entries than a plain zip holds, an
#' entry name with a NUL byte, one that is too long, absolute or leaves the
#' folder, and an entry given twice (the second would silently replace the
#' first, and could hold a second runner).
#' @param zip The bundle zip.
#' @return A list: names (character) and modes (numeric, named by path).
#' @noRd
.bndlchk_cd <- function(zip) {
  bad <- function(why) {
    stop(sprintf("mkbndlchk: %s %s", basename(zip), why), call. = FALSE)
  }
  r <- .bndlchk_cd_raw(zip)
  if (is.na(r$n)) {
    bad("is not a readable zip (no central directory)")
  }
  w <- .bndlchk_cd_walk(r$cd)
  k <- length(w$names)
  if (r$n == 65535 || k > 65535L) {
    bad("has more than 65535 entries (a zip64 archive), more than a bundle")
  }
  if (k != r$n) {
    bad(sprintf("is damaged: its end record counts %d entries, not %d",
                as.integer(r$n), k))
  }
  nul <- vapply(w$names, function(b) any(b == as.raw(0L)), NA)
  if (any(nul)) {
    bad(sprintf("has %d entry name(s) holding a NUL byte", sum(nul)))
  }
  nm <- vapply(w$names, rawToChar, "", USE.NAMES = FALSE)
  .bndlchk_names(nm, bad)
  list(names = nm, modes = stats::setNames(w$modes, nm))
}

#' Refuses entry names a bundle may not hold.
#' @param nm The entry names.
#' @param bad Raises the error, given its reason.
#' @return Nothing useful.
#' @noRd
.bndlchk_names <- function(nm, bad) {
  # names are bytes: invalid UTF-8 is shown as <xx>, never an error
  nm <- iconv(nm, "UTF-8", "UTF-8", sub = "byte")
  shown <- function(x) toString(.rmbl_printable(utils::head(x, 3L)))
  parts <- strsplit(nm, "[/\\\\]")
  long <- nchar(nm, type = "bytes") > 1024L |
    vapply(parts, function(p) any(nchar(p, type = "bytes") > 255L), NA)
  if (any(long)) {
    bad(sprintf(
      "has entry names too long to unzip (over 255 bytes a part): %s",
      shown(substr(nm[long], 1L, 60L))
    ))
  }
  out <- grepl("^([/\\\\]|[A-Za-z]:)", nm) |
    vapply(parts, function(p) any(p == ".."), NA)
  if (any(out)) {
    bad(sprintf("has entries that leave its folder: %s", shown(nm[out])))
  }
  # empty and "." parts name the same file: a//b and a/./b are a/b
  key <- tolower(vapply(parts, function(p) {
    paste(p[!p %in% c("", ".")], collapse = "/")
  }, ""))
  dup <- duplicated(key)
  if (any(dup)) {
    bad(sprintf("holds the same entry twice: %s", shown(nm[dup])))
  }
  invisible(NULL)
}

#' A little-endian unsigned 16-bit integer from raw bytes.
#' @param b The bytes.
#' @param i The 1-based position of its first byte.
#' @return A number.
#' @noRd
.bndlchk_u16 <- function(b, i) {
  as.numeric(b[i]) + 256 * as.numeric(b[i + 1L])
}

#' A little-endian unsigned 32-bit integer from raw bytes.
#' @param b The bytes.
#' @param i The 1-based position of its first byte.
#' @return A number.
#' @noRd
.bndlchk_u32 <- function(b, i) {
  .bndlchk_u16(b, i) + 65536 * .bndlchk_u16(b, i + 2L)
}
