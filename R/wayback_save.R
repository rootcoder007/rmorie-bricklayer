# Bulk archiving to the Wayback Machine with Save Page Now 2 (SPN2), the API
# archive.org offers to account holders: a POST to /save starts a capture and
# returns a job id, /save/status/<id> says when it is done. Captures run on
# archive.org's side, so the speed comes from keeping several jobs in flight
# while polling them, not from parallel connections: one native connection at a
# time (src/rmbl_fetch.cpp, the package's only network code) is enough to drive
# as many jobs as an account may run.
#
# The run keeps to archive.org's published limits (SPN2 API docs: at most 7
# captures a minute for an account, a limit on concurrent sessions, a daily cap)
# and slows down when told to: before 0.5.12 a throttle reply that came inside
# an HTTP 200 (status_ext "error:user-session-limit") marked the URL failed and
# the next POST went straight out, 300 URLs in 32 seconds, the behaviour that
# gets an account suspended (review of e57fed5, E7).

#' Archive many pages in the Wayback Machine
#'
#' @description
#' Asks the Internet Archive to take a dated copy of each web page or file
#' in a list, so that the exact source an analysis used (a statistics page,
#' a data download, a policy document) can be cited and checked later even
#' if the original changes or disappears. It needs a free archive.org
#' account and its API keys.
#'
#' Saves every URL in the Internet Archive's Wayback Machine
#' with Save Page Now 2, the API archive.org offers to account
#' holders, keeping several captures in flight at once while
#' keeping to archive.org's rate limits. A page archived
#' recently is kept as it is (\code{within}); a page archive.org
#' has already captured today (its daily limit) is recorded with
#' that capture. Each result is written to \code{output} as it
#' arrives, so an interrupted run started again with the same
#' \code{output} carries on where it stopped. A live progress
#' bar shows the run while a person is watching.
#'
#' @param urls Character vector of \code{http} or \code{https}
#'   URLs. Duplicates, \code{NA} and empty strings are dropped. An address
#'   on your own network (a private or loopback IP, a \code{.local} or
#'   one-label name) is refused: the archive cannot reach it, and the
#'   request would tell it where your intranet is.
#' @param ak,sk Your archive.org S3-like API
#'   keys (archive.org/account/s3.php). By default
#'   they are read from the environment variables
#'   \code{IA_S3_ACCESS_KEY} and \code{IA_S3_SECRET_KEY}, or from
#'   the files named by \code{IA_S3_ACCESS_KEY_FILE} and
#'   \code{IA_S3_SECRET_KEY_FILE} (a key file other users can
#'   read is warned about). They are sent to web.archive.org only
#'   and never printed.
#' @param within Keep a capture made within this long instead of
#'   making a new one: a number followed by \code{s}, \code{m},
#'   \code{h} or \code{d} (default \code{"30d"}); \code{"0"}
#'   always captures.
#' @param jobs Captures in flight at once, 1 to 12. Default 4.
#' @param output Optional path of a JSON Lines file: one line
#'   per URL, written as each finishes, and read at the start so a
#'   run can be resumed. Its folder must exist; this is checked
#'   before anything is sent.
#' @param poll Seconds between status checks of a capture.
#'   Default 10.
#' @param maxwait Seconds a capture may take before it is given
#'   up as failed. Default 600.
#' @param capall Also capture error pages (4xx and 5xx);
#'   default \code{FALSE}.
#' @param quiet \code{TRUE} for no progress output; the default
#'   shows it while a person is watching.
#' @param permin Captures started per minute, at most; default
#'   6 (archive.org allows an account 7).
#' @param maxcap The most captures this run starts; default
#'   1000. The rest are left for the next run (with the same
#'   \code{output}, it carries on from them).
#' @param fallback \code{"rmorie"} saves what the Wayback Machine refused (a
#'   server that refuses its crawler, Statistics Canada among them) from this
#'   connection to archive.rmorie.com, with \code{\link{arccap}}; the result is
#'   attribute \code{archive}. \code{NULL} (default) does not.
#' @param reason With \code{fallback = "rmorie"}: why the files are kept (20
#'   characters or more).
#'
#' @return A data frame of class \code{rmbl_wayback_save}, one
#'   row per URL with a result: \code{url}, \code{status}
#'   (\code{"saved"}, a new capture; \code{"existing"}, a capture
#'   already there; \code{"failed"}; or \code{"submitted"}, a
#'   capture started when the run was stopped, polled again by the
#'   next run), \code{timestamp} (\code{YYYYMMDDhhmmss}),
#'   \code{snapshot} (the archived copy's address) and
#'   \code{message} (archive.org's reason, for a failure). The
#'   attribute \code{not_sent} lists the URLs this run did not
#'   start (\code{maxcap}, or archive.org's daily cap for the
#'   account).
#'
#' @details Captures start no faster than \code{permin}. When
#'   archive.org asks the run to slow down (HTTP 429, or a reply
#'   saying the account has too many captures running, inside an
#'   HTTP 200 as SPN2 sends it), nothing more is submitted until
#'   the wait is over: as long as its \code{Retry-After} says, or
#'   15 seconds doubling to 10 minutes; eight such replies in a row
#'   stop the run. A reply saying the account's daily cap is
#'   reached stops submitting for the day. A server error or a lost
#'   connection is retried with back-off, up to six times per URL;
#'   status checks that fail back off the same way. A refused key
#'   (HTTP 401 or 403) stops the run.
#'
#'   A run of many URLs is slow by design: at the default 6 captures a
#'   minute, 1,000 URLs take close to three hours. URLs already finished in
#'   \code{output} are skipped, so a run can be stopped and restarted.
#'
#'   Network: every request goes to web.archive.org; the
#'   keys travel in the \code{Authorization} header and are never written
#'   to \code{output} or printed.
#'
#'   Errors, all raised before anything is sent: no usable URL; a URL with
#'   an invisible or control character, or not starting with
#'   \code{http://} or \code{https://}; missing keys, or keys that are not
#'   letters and digits; \code{within} not of the form \code{"30d"};
#'   \code{jobs} outside 1 to 12; \code{poll} below 1; \code{maxwait}
#'   below \code{poll}; \code{permin} outside (0, 60];
#'   \code{maxcap} below 1; \code{capall} not \code{TRUE} or
#'   \code{FALSE}; an \code{output} whose folder does not exist or that
#'   cannot be written.
#'
#' @references Internet Archive. Save Page Now 2 (SPN2) public API.\cr
#'   archive.org/details/spn-2-public-api-page-docs
#' @seealso \code{\link{wbsnpnat}} to look up an existing capture;
#'   \code{\link{wbrtry}}; \code{\link{arccap}} for URLs whose server refuses
#'   the Internet Archive (\code{"cannot find"} although the page is there);
#'   \code{rmbl wayback FILE} runs this from the command line.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # The checks run before any request, so these need no network or keys:
#' try(wbsave("ftp://example.org/report.pdf"))
#' try(wbsave("https://example.org/", ak = "abc", sk = "def", jobs = 20))
#' try(wbsave(
#'   "https://example.org/",
#'   ak = "abc",
#'   sk = "def",
#'   output = file.path(tempdir(), "no-such-folder", "runs.jsonl")
#' ))
#'
#' # A real run needs archive.org keys and the network.
#'
#' @examplesIf interactive()
#' Sys.setenv(
#'   IA_S3_ACCESS_KEY_FILE = "~/.config/ia/s3_access_key.txt",
#'   IA_S3_SECRET_KEY_FILE = "~/.config/ia/s3_secret_key.txt"
#' )
#' res <- wbsave(
#'   c(
#'     "https://www.ontariocourts.ca/ocj/statistics/",
#'     "https://www150.statcan.gc.ca/n1/tbl/csv/35100177-eng.zip"
#'   ),
#'   output = "snapshots.jsonl"
#' )
#' res
#' @export
wbsave <- function(
  urls,
  ak = NULL,
  sk = NULL,
  within = "30d",
  jobs = 4L,
  output = NULL,
  poll = 10,
  maxwait = 600,
  capall = FALSE,
  quiet = NULL,
  permin = 6,
  maxcap = 1000,
  fallback = NULL,
  reason = NULL
) {
  if (!is.null(fallback) && !identical(fallback, "rmorie")) {
    stop('`fallback` must be "rmorie" or NULL', call. = FALSE)
  }
  urls <- .bl_wb_check_urls(urls)
  keys <- .bl_wb_check_keys(ak, sk)
  opt <- .bl_wb_check_opts(
    within,
    jobs,
    poll,
    maxwait,
    permin,
    maxcap,
    capall,
    output
  )
  .bl_wb_check_resolved(urls)
  # results already in `output`: a finished URL is not sent again, a submitted
  # one is polled
  prior <- .bl_wb_records(opt$output)
  sp <- .bl_wb_split_prior(urls, prior)
  kept <- sp$kept
  resumed <- sp$resumed
  todo <- setdiff(urls, c(kept, resumed))
  maxcap <- opt$maxcap
  not_sent <- if (length(todo) > maxcap) todo[-seq_len(maxcap)] else character()
  # the run's state, shared with the helpers below
  w <- .bl_wb_state(opt, keys, prior, kept, utils::head(todo, maxcap))
  w$anim <- .bl_anim_new(
    "Wayback",
    length(w$queue) + length(resumed),
    color = "blue",
    quiet = quiet
  )
  .bl_wb_resume(w, resumed, prior)
  # a run stopped (Ctrl-C, an error) records the captures it had started, so the
  # next run polls them instead of submitting them again
  on.exit(.bl_wb_record_inflight(w), add = TRUE)
  while ((length(w$queue) && is.null(w$stopped)) || length(w$inflight)) {
    .bl_wb_round(w)
  }
  if (!is.null(w$stopped)) {
    not_sent <- c(w$queue, not_sent)
  }
  .bl_anim_update(w$anim, sum(w$counts), .bl_wb_info(w), force = TRUE)
  started <- length(todo) + length(resumed) - length(not_sent)
  .bl_anim_done(w$anim, .bl_wb_summary(w, started, length(kept), not_sent))
  .bl_wb_result(w, urls, not_sent, fallback, reason)
}

#' @export
format.rmbl_wayback_save <- function(x, ...) {
  if (!all(c("status", "timestamp", "url") %in% names(x))) {
    return(utils::capture.output(print(as.data.frame(unclass(x)))))
  }
  tab <- table(factor(
    x$status,
    levels = c("saved", "existing", "failed", "submitted")
  ))
  show <- as.data.frame(unclass(x))[, c("status", "timestamp", "url")]
  # URLs come from a file and from archive.org: printed only as what they show
  show$url <- .rmbl_printable(show$url)
  show$url <- ifelse(
    nchar(show$url) > 48,
    paste0(substr(show$url, 1, 45), "..."),
    show$url
  )
  .rmbl_stat_block(
    "Wayback Machine captures",
    facts = list(
      URLs = sprintf(
        "%d URLs: %d saved, %d existing, %d failed%s",
        nrow(x),
        tab[["saved"]],
        tab[["existing"]],
        tab[["failed"]],
        if (tab[["submitted"]]) {
          sprintf(", %d submitted", tab[["submitted"]])
        } else {
          ""
        }
      ),
      `Not sent` = .bl_wb_not_sent_text(x)
    ),
    table = utils::head(show, 20L),
    reading = paste(
      "Saved and existing URLs have a copy in the Wayback Machine at the",
      "timestamp shown; wbrtry() tries the failed ones again."
    ),
    notes = if (nrow(x) > 20L) sprintf("... and %d more rows", nrow(x) - 20L)
  )
}

#' Retry the failures of a bulk Wayback run
#'
#' @description
#' Picks up where a \code{\link{wbsave}} run left off: it re-tries
#' only the URLs whose captures failed or were still running, after first
#' checking whether the Wayback Machine already holds a copy of each. Use it
#' after a run that hit archive.org's limits, typically the next day.
#'
#' @details Reads the results file a \code{\link{wbsave}} run wrote and tries
#' again every URL whose latest result is \code{"failed"} (or
#' \code{"submitted"}: a capture a stopped run had started, which is polled
#' rather than submitted again), so nobody has to dig the failures out by hand.
#' Each failed URL is first looked up in the Wayback Machine, one lookup a
#' second: a capture made at any time (an earlier one of a page that has since
#' gone, or one made today by another run when the daily limit refused this one)
#' is recorded as \code{"existing"} without capturing again. What is left is
#' captured again with \code{wbsave()}, appending to the same file. A page its
#' source no longer has is not sent again unless \code{incgone = TRUE}: a new
#' capture would only archive the error. \code{"Gone"} means the recorded
#' message contains archive.org's report of the target server's reply
#' (\dQuote{target server cannot find}, \dQuote{returned 404}, \dQuote{returned
#' 410}, \code{"error:not-found"} or \code{"error:gone"}); an HTTP 404 from
#' archive.org's own API does not count. A failure for a daily limit recorded
#' today (UTC) is not sent again until tomorrow.
#'
#' Network: the lookups use the Wayback availability API and the new
#' captures use \code{wbsave()}, which needs the archive.org keys.
#' When there is nothing left to send, no keys and no network are needed.
#' Each lookup that finds a capture is appended to \code{output} as an
#' \code{"existing"} line.
#'
#' Errors: \code{output} not a single path to an existing file;
#' \code{incgone} or \code{lookup} not \code{TRUE} or \code{FALSE};
#' any error from \code{wbsave()}.
#'
#' @param output The JSON Lines results file of an earlier
#'   \code{wbsave()} run (or of \code{rmbl wayback});
#'   results of the retry are appended to it.
#' @param incgone Logical, default \code{FALSE}. Also capture again
#'   the pages whose failure says the page is gone.
#' @param lookup Logical, default \code{TRUE}. Look each failure up in the
#'   Wayback Machine (one lookup a second) before capturing again.
#' @param ... Passed to \code{wbsave()}: \code{jobs},
#'   \code{within}, the keys, \code{quiet}, \code{permin},
#'   \code{maxcap}.
#' @return The whole run as it now stands, one row per URL (a
#'   data frame of class \code{rmbl_wayback_save}), with the
#'   attribute \code{retry}: how many failures there were, how
#'   many a lookup found, how many were captured again, how many
#'   were left as gone, and how many were left for tomorrow (a
#'   daily limit hit today), as a one-row data frame with integer columns
#'   \code{failed}, \code{found_by_lookup}, \code{captured_again},
#'   \code{left_as_gone} and \code{left_for_tomorrow}.
#' @seealso \code{\link{wbsave}}; \code{rmbl wayback
#'   --retry FILE.jsonl} from the command line.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Offline: a results file whose only failure is a page that is gone
#' # has nothing to send again, so no keys or network are used.
#' f <- tempfile(fileext = ".jsonl")
#' writeLines(
#'   c(
#'     paste0(
#'       '{"url":"https://example.org/","status":"saved",',
#'       '"timestamp":"20260101120000",',
#'       '"snapshot":"https://web.archive.org/web/20260101120000/https://',
#'       'example.org/",',
#'       '"message":"","at":"2026-01-01T12:00:00Z"}'
#'     ),
#'     paste0(
#'       '{"url":"https://example.org/old","status":"failed",',
#'       '"message":"target server cannot find the ',
#'       'page","at":"2026-01-01T12:00:00Z"}'
#'     )
#'   ),
#'   f
#' )
#' res <- wbrtry(f, lookup = FALSE)
#' res
#' attr(res, "retry")
#'
#' try(wbrtry(tempfile(fileext = ".jsonl")))
#'
#' # With failures to resend, keys and the network are needed.
#'
#' @examplesIf interactive()
#' res <- wbsave(urls, output = "snapshots.jsonl")
#' # later, or the next day once the daily capture limits have reset:
#' res <- wbrtry("snapshots.jsonl")
#' attr(res, "retry")
#' @export
wbrtry <- function(output, incgone = FALSE, lookup = TRUE, ...) {
  output <- .rmbl_string1(output, "output")
  if (!file.exists(output)) {
    stop(sprintf("no results file at %s", output), call. = FALSE)
  }
  .bl_wb_rtry_flag(incgone, "incgone")
  .bl_wb_rtry_flag(lookup, "lookup")
  recs <- .bl_wb_records(output)
  now <- .bl_wb_frame(recs)
  failed <- now[now$status %in% c("failed", "submitted"), , drop = FALSE]
  found <- 0L
  if (lookup && nrow(failed)) {
    lk <- .bl_wb_rtry_lookup(failed, output)
    failed <- lk$failed
    found <- lk$found
  }
  left <- failed[failed$status %in% c("failed", "submitted"), , drop = FALSE]
  hold <- .bl_wb_rtry_hold(left, recs, incgone)
  gone <- hold$gone
  later <- hold$later
  todo <- left$url[!gone & !later]
  if (length(todo)) {
    wbsave(todo, output = output, ...)
  }
  out <- .bl_wb_read(output)
  attr(out, "retry") <- data.frame(
    failed = nrow(failed),
    found_by_lookup = found,
    captured_again = length(todo),
    left_as_gone = sum(gone),
    left_for_tomorrow = sum(later)
  )
  out
}

#' The URLs a Wayback run did not send, in words.
#' @param x An rmbl_wayback_save result.
#' @return One string, or NULL when every URL was sent.
#' @noRd
.bl_wb_not_sent_text <- function(x) {
  ns <- attr(x, "not_sent")
  if (!length(ns)) {
    return(NULL)
  }
  sprintf(
    "%d not sent this run%s",
    length(ns),
    if (!is.null(attr(x, "stopped"))) {
      paste0(": ", .rmbl_printable(attr(x, "stopped")))
    } else {
      ""
    }
  )
}

#' wbsave()'s URLs already finished, and those still running, in `output`.
#' @param urls The URLs of the run.
#' @param prior The records already in `output`.
#' @return A list: kept (saved or existing) and resumed (submitted, with a
#'   job id).
#' @noRd
.bl_wb_split_prior <- function(urls, prior) {
  kept <- urls[vapply(
    urls,
    function(u) isTRUE(.bl_wb_status_of(prior, u) %in% c("saved", "existing")),
    logical(1)
  )]
  resumed <- urls[vapply(
    urls,
    function(u) {
      identical(.bl_wb_status_of(prior, u), "submitted") &&
        !is.na(prior[[u]]$job_id)
    },
    logical(1)
  )]
  list(kept = kept, resumed = resumed)
}

#' Puts the captures an earlier run had started back in flight.
#' @param w The run's state.
#' @param resumed The URLs whose captures are polled again.
#' @param prior The records already in `output`.
#' @return NULL, invisibly.
#' @noRd
.bl_wb_resume <- function(w, resumed, prior) {
  now0 <- .bl_wb_now()
  for (u in resumed) {
    w$inflight[[u]] <- list(
      id = prior[[u]]$job_id,
      start = now0,
      due = now0,
      fails = 0L
    )
  }
  invisible(NULL)
}

#' Records the captures still in flight when a run stops.
#' @param w The run's state.
#' @return NULL, invisibly.
#' @noRd
.bl_wb_record_inflight <- function(w) {
  if (length(w$inflight)) {
    for (u in names(w$inflight)) {
      .bl_wb_finish(
        w,
        u,
        "submitted",
        msg = "started; the run stopped before it finished",
        job_id = w$inflight[[u]]$id
      )
    }
  }
  invisible(NULL)
}

#' wbsave()'s result: one row per URL, with what was not sent.
#' @param w The run's state.
#' @param urls The URLs of the run.
#' @param not_sent The URLs not sent this run.
#' @param fallback,reason As for wbsave().
#' @return An rmbl_wayback_save data frame.
#' @noRd
.bl_wb_result <- function(w, urls, not_sent, fallback, reason) {
  out <- .bl_wb_frame(w$results[intersect(urls, names(w$results))])
  attr(out, "not_sent") <- not_sent
  if (!is.null(w$stopped)) {
    attr(out, "stopped") <- w$stopped
  }
  if (identical(fallback, "rmorie")) {
    out <- .bl_wb_fallback(out, reason)
  }
  out
}

#' Checks one of wbrtry()'s TRUE-or-FALSE arguments.
#' @param v The retry option's value, one TRUE or FALSE.
#' @param a The argument's name.
#' @return NULL, invisibly.
#' @noRd
.bl_wb_rtry_flag <- function(v, a) {
  if (!is.logical(v) || length(v) != 1L || is.na(v)) {
    stop(sprintf("wbrtry: `%s` must be TRUE or FALSE", a), call. = FALSE)
  }
  invisible(NULL)
}

#' Looks wbrtry()'s failures up in the Wayback Machine, one a second.
#'
#' Each capture found is appended to `output` as an "existing" line.
#' @param failed The failed and submitted rows.
#' @param output The results file.
#' @return A list: failed (with the rows found marked "existing") and found.
#' @noRd
.bl_wb_rtry_lookup <- function(failed, output) {
  found <- 0L
  looked <- 0L
  for (i in which(failed$status == "failed")) {
    # the availability API is archive.org's too: one lookup a second
    if (looked > 0L) {
      .bl_wb_sleep(1)
    }
    looked <- looked + 1L
    s <- .bl_wb_lookup(failed$url[i])
    if (is.null(s)) {
      next
    }
    rec <- list(
      url = failed$url[i],
      status = "existing",
      timestamp = .bl_wb_ts(sub("^.*/web/([0-9]{14})[^/]*/.*$", "\\1", s)),
      snapshot = s,
      message = paste("found on retry;", failed$message[i]),
      at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    )
    cat(
      tojs(rec, auto_unbox = TRUE),
      "\n",
      sep = "",
      file = output,
      append = TRUE
    )
    found <- found + 1L
    failed$status[i] <- "existing"
  }
  list(failed = failed, found = found)
}

#' wbrtry()'s failures held back: pages gone, and daily limits hit today.
#' @param left The rows still failed or submitted.
#' @param recs The records of the results file.
#' @param incgone As for wbrtry().
#' @return A list of logical vectors over `left`: gone and later.
#' @noRd
.bl_wb_rtry_hold <- function(left, recs, incgone) {
  gone <- if (incgone) {
    rep(FALSE, nrow(left))
  } else {
    left$status == "failed" & .bl_wb_gone(left$message)
  }
  today <- format(Sys.time(), "%Y-%m-%d", tz = "UTC")
  at <- vapply(
    left$url,
    function(u) substr(recs[[u]]$at %|NA|% "", 1L, 10L),
    "",
    USE.NAMES = FALSE
  )
  later <- !gone &
    left$status == "failed" &
    .bl_wb_daily_failure(left$message) &
    at == today
  list(gone = gone, later = later)
}

#' Returns the address of the Wayback Machine.
#' @return One URL.
#' @noRd
.bl_wb_base <- function() "https://web.archive.org"

# The transport seams (the package's checked libcurl calls), one place for tests
# to stand in a server. An API call takes its answer only from the host it asked
# (a redirect to another host is refused in the transport), and the reply
# carries Retry-After.
#' Posts a capture request to Save Page Now.
#' @param body The form-encoded request body.
#' @param headers The request headers, the account's key among them.
#' @return The transport's reply: a list with the status, headers and body.
#' @noRd
.bl_wb_post <- function(body, headers) {
  .Call(
    C_rmbl_http_post,
    sprintf("%s/save", .bl_wb_base()),
    charToRaw(body),
    "application/x-www-form-urlencoded",
    60L,
    headers,
    FALSE
  )
}

#' Sends a GET request to a path of the Wayback Machine.
#' @param path The path, starting with \code{"/"}.
#' @param headers The request headers, the account's key among them.
#' @return The transport's reply: a list with the status, headers and body.
#' @noRd
.bl_wb_get <- function(path, headers) {
  .Call(C_rmbl_http_get, paste0(.bl_wb_base(), path), 60L, headers, FALSE)
}

#' Looks up the latest capture of a URL, or NULL when the lookup fails.
#' @param url The URL whose latest snapshot is looked up.
#' @return The value of `wbsnpnat()`, or NULL.
#' @noRd
.bl_wb_lookup <- function(url) {
  tryCatch(wbsnpnat(url, tmout = 30L), error = function(e) NULL)
}

#' Returns the elapsed time of the session, in seconds.
#' @return One number.
#' @noRd
.bl_wb_now <- function() proc.time()[["elapsed"]]

#' Waits for a number of seconds.
#' @param seconds The time to wait.
#' @noRd
.bl_wb_sleep <- function(seconds) Sys.sleep(seconds)

# SPN2 replies are a few hundred bytes: a larger body is not one (a 4 MB reply
# took 443 s to parse)
.bl_wb_body_max <- 65536L

#' A reply's JSON, or NULL (an HTML error page, an empty or oversized body)
#' @param res A transport reply.
#' @return A list, or NULL.
#' @noRd
.bl_wb_json <- function(res) {
  if (!length(res$body) || length(res$body) > .bl_wb_body_max) {
    return(NULL)
  }
  j <- tryCatch(.rmbl_json_parse(rawToChar(res$body)), error = function(e) NULL)
  if (is.list(j)) j else NULL
}

#' Returns a field as one string, or NA.
#'
#' A field of a reply or of a results line as one string, or NA: a list, a
#' number or TRUE where text belongs (a broken or hostile reply, a hand-edited
#' file) is not taken as text. A list timestamp written to the results file had
#' broken every later resume.
#' @param x The field.
#' @return One string, or `NA_character_`.
#' @noRd
.bl_wb_str <- function(x) {
  if (is.character(x) && length(x) == 1L && !is.na(x)) x else NA_character_
}

#' Returns a field as a 14-digit Wayback timestamp, or NA.
#' @param x The field.
#' @return One string, or `NA_character_`.
#' @noRd
.bl_wb_ts <- function(x) {
  x <- .bl_wb_str(x)
  if (!is.na(x) && grepl("^[0-9]{14}$", x)) x else NA_character_
}

#' Returns a field as an SPN2 job id, or NA.
#'
#' SPN2 job ids are \code{"spn2-"} and hex; anything that is not a short token
#' is not a job to poll (TRUE looped forever, 123 stopped the run)
#' @param x The field.
#' @return One string, or `NA_character_`.
#' @noRd
.bl_wb_job_id <- function(x) {
  x <- .bl_wb_str(x)
  # a job id that reads like a status code ("error:not-found") is not one:
  # polling it would turn archive.org's 404 into "gone" for a live page
  if (
    !is.na(x) &&
      grepl("^[A-Za-z0-9._:-]{1,200}$", x) &&
      !grepl("^error", x, ignore.case = TRUE)
  ) {
    x
  } else {
    NA_character_
  }
}

#' Retry-After in seconds (a number, or an HTTP date), capped at an hour; NA
#' when not sent
#' @param res A transport reply.
#' @return The wait in seconds, or `NA_real_`.
#' @noRd
.bl_wb_retry_after <- function(res) {
  v <- .bl_wb_str(res$retry_after)
  if (is.na(v) || !nzchar(v)) {
    return(NA_real_)
  }
  if (grepl("^[0-9]{1,9}$", v)) {
    return(min(3600, as.numeric(v)))
  }
  t <- suppressWarnings(as.POSIXct(
    sub("^[A-Za-z]+, *", "", v),
    format = "%d %b %Y %H:%M:%S",
    tz = "GMT"
  ))
  if (is.na(t)) {
    return(NA_real_)
  }
  min(3600, max(0, as.numeric(difftime(t, Sys.time(), units = "secs"))))
}

#' Reads an archive.org key from the environment or from a key file.
#'
#' An archive.org key: the variable, or the file its _FILE twin names (the
#' convention for keys kept on disk, as Docker secrets are). Never printed. A
#' key file other users can read is said.
#' @param var The environment variable's name.
#' @return The key, or \code{""} when neither is set.
#' @noRd
.bl_ia_key <- function(var) {
  v <- Sys.getenv(var)
  if (nzchar(v)) {
    return(trimws(v))
  }
  f <- Sys.getenv(paste0(var, "_FILE"))
  if (!nzchar(f)) {
    return("")
  }
  if (!file.exists(f)) {
    stop(
      sprintf("%s_FILE names %s, which does not exist", var, f),
      call. = FALSE
    )
  }
  m <- file.info(f)$mode
  if (
    .Platform$OS.type == "unix" &&
      !is.na(m) &&
      bitwAnd(as.integer(m), 63L) != 0L
  ) {
    warning(
      sprintf(
        "%s_FILE names %s, which other users can read: chmod 600 it",
        var,
        f
      ),
      call. = FALSE
    )
  }
  trimws(readLines(f, n = 1L, warn = FALSE))
}

#' Builds the Wayback address of a capture.
#' @param ts The capture's timestamp, or NA for the latest capture.
#' @param url The captured URL.
#' @return One URL.
#' @noRd
.bl_wb_snapshot <- function(ts, url) {
  # without a timestamp, the address of the latest capture
  if (is.na(ts)) {
    return(sprintf("https://web.archive.org/web/%s", url))
  }
  sprintf("https://web.archive.org/web/%s/%s", ts, url)
}

#' archive.org's own words for \dQuote{this URL was captured already today} (a
#' limit on the URL)
#' @param j A parsed SPN2 reply.
#' @return TRUE or FALSE.
#' @noRd
.bl_wb_daily_limit <- function(j) {
  grepl("already captured", .bl_wb_str(j$message) %|NA|% "", fixed = TRUE) ||
    identical(.bl_wb_str(j$status_ext), "error:too-many-daily-captures")
}

# "slow down": the account has too many captures running, or archive.org is
# overloaded. SPN2 says so inside an HTTP 200 (status_ext; the API docs list
# these codes) as well as with a 429. archive.org's own account and capacity
# throttles. error:service-unavailable (the live page's 503) and
# error:bandwidth-limit-exceeded (the target server's) are the page's, not the
# account's: they fail that URL (review of 29a55d8, G5)
.bl_wb_throttle_codes <- c(
  "error:user-session-limit",
  "error:too-many-requests",
  "error:no-browsers-available",
  "error:celery"
)

#' Tells whether an SPN2 reply asks the run to slow down.
#' @param j A parsed SPN2 reply.
#' @return TRUE or FALSE.
#' @noRd
.bl_wb_throttled <- function(j) {
  isTRUE(.bl_wb_str(j$status_ext) %in% .bl_wb_throttle_codes) ||
    grepl(
      paste0(
        "already reached the limit of active sessions|cannot start ",
        "capture|too many requests|try again later"
      ),
      .bl_wb_str(j$message) %|NA|% "",
      ignore.case = TRUE
    )
}

#' The account's own daily cap: nothing more can be captured today, so the run
#' stops submitting
#' @param j A parsed SPN2 reply.
#' @return TRUE or FALSE.
#' @noRd
.bl_wb_account_cap <- function(j) {
  isTRUE(
    .bl_wb_str(j$status_ext) %in%
      c("error:max-daily-bandwidth", "error:max-daily-bandwidth-from-ip")
  ) ||
    grepl(
      paste0(
        "cannot make more than [0-9,]+ captures per day|daily ",
        "(not-logged-in )?captures limit"
      ),
      .bl_wb_str(j$message) %|NA|% "",
      ignore.case = TRUE
    )
}

#' Returns `b` when `a` is NA, else `a`.
#' @param a A value that may be NA.
#' @param b The value used in its place.
#' @return `a` or `b`.
#' @noRd
.bl_na_or <- function(a, b) if (is.na(a)) b else a

`%|NA|%` <- .bl_na_or

#' Reads the results file into one record per URL.
#'
#' The results file as one normalised record per URL (the last line written for
#' a URL wins: a retry appends). Every field is a single string or NA, whatever
#' the file holds.
#' @param output The results file, or NULL.
#' @return A list of records named by URL, empty when there is no file.
#' @noRd
.bl_wb_records <- function(output) {
  rows <- list()
  if (is.null(output) || !file.exists(output)) {
    return(rows)
  }
  for (l in readLines(output, warn = FALSE)) {
    r <- tryCatch(.rmbl_json_parse(l), error = function(e) NULL)
    u <- .bl_wb_str(if (is.list(r)) r$url)
    if (is.na(u)) {
      next
    }
    rows[[u]] <- list(
      url = u,
      status = .bl_wb_str(r$status),
      timestamp = .bl_wb_ts(r$timestamp),
      snapshot = .bl_wb_str(r$snapshot),
      message = .bl_wb_str(r$message) %|NA|% "",
      job_id = .bl_wb_job_id(r$job_id),
      at = .bl_wb_str(r$at)
    )
  }
  rows
}

#' Turns the run's records into the results data frame.
#' @param rows A list of records, as from `.bl_wb_records()`.
#' @return A data frame of class `rmbl_wayback_save`.
#' @noRd
.bl_wb_frame <- function(rows) {
  col <- function(k) {
    vapply(
      rows,
      function(r) as.character(r[[k]] %||% NA_character_),
      "",
      USE.NAMES = FALSE
    )
  }
  out <- data.frame(
    url = col("url"),
    status = col("status"),
    timestamp = col("timestamp"),
    snapshot = col("snapshot"),
    message = col("message"),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
  out$message[is.na(out$message)] <- ""
  class(out) <- c("rmbl_wayback_save", "data.frame")
  out
}

#' Finds a control or invisible formatting character in a URL.
#'
#' A URL that cannot be sent as it is: a control or invisible formatting
#' character (U+202E printed the rest of a line reversed)
#' @param u The URL scanned for a hidden character.
#' @return A description of the first such character, or \code{""}.
#' @noRd
.bl_wb_hidden_char <- function(u) {
  # the bytes as given: under the C locale enc2utf8() rewrote U+202E to
  # "<U+202E>", which passed
  u <- iconv(u, "UTF-8", "UTF-8", sub = NA)
  cp <- if (!is.na(u) && validUTF8(u)) utf8ToInt(u) else NA_integer_
  if (anyNA(cp)) {
    return("a byte that is not UTF-8")
  }
  bad <- cp[
    cp < 32L |
      (cp >= 127L & cp < 160L) |
      cp %in%
        c(0x061CL, 0x200BL:0x200FL, 0x2028L:0x202EL, 0x2060L:0x206FL, 0xFEFFL)
  ]
  if (length(bad)) sprintf("U+%04X", bad[[1L]]) else ""
}

#' The URL check with the host's addresses resolved: why a URL is refused, or
#' \code{""}.
#'
#' A seam of its own, so the tests can stand in for the resolver.
#' @param u The URL resolved and checked.
#' @return The reason, or \code{""}.
#' @noRd
.bl_wb_resolved_why <- function(u) .Call(C_rmbl_url_check, u, TRUE, TRUE, FALSE)

#' One round of a wbsave() run: start the captures there is room for, check
#' the ones that are due, then wait.
#' @param w The run's state.
#' @noRd
.bl_wb_round <- function(w) {
  now <- .bl_wb_now()
  # start captures while there is room, no faster than permin and not while
  # held
  while (
    is.null(w$stopped) &&
      length(w$inflight) < w$jobs &&
      length(w$queue) &&
      now >= max(w$next_post, w$hold_until)
  ) {
    u <- w$queue[[1L]]
    w$queue <- w$queue[-1L]
    w$next_post <- now + w$spacing
    .bl_wb_submit(w, u, now)
    .bl_anim_update(w$anim, sum(w$counts), .bl_wb_info(w))
    now <- .bl_wb_now()
  }
  # check the captures that are due; a failed check backs off instead of
  # asking again at once
  for (u in names(w$inflight)) {
    if (w$inflight[[u]]$due > now) {
      next
    }
    .bl_wb_check_job(w, u, now)
    .bl_anim_update(w$anim, sum(w$counts), .bl_wb_info(w))
  }
  .bl_wb_wait(w)
}

#' A public name that resolves to an address on your own network is refused
#' too, once every argument is checked (audit of 30bed8e, #17); a name this
#' machine cannot resolve is sent, since the archive resolves names itself.
#' @param urls The URLs whose hosts are resolved and checked.
#' @noRd
.bl_wb_check_resolved <- function(urls) {
  for (u in urls) {
    r <- .bl_wb_resolved_why(u)
    if (grepl("resolves to", r, fixed = TRUE)) {
      stop(
        .rmbl_fn(),
        sprintf(
          "not a public address, so it is not sent to archive.org: %s (%s)",
          .rmbl_printable(u),
          r
        ),
        call. = FALSE
      )
    }
  }
  invisible(NULL)
}

#' A URL's status in the results of an earlier run.
#' @param prior The earlier results.
#' @param u The URL whose earlier status is read.
#' @return The status, or NA.
#' @noRd
.bl_wb_status_of <- function(prior, u) prior[[u]]$status %||% NA_character_

#' The URLs given to wbsave(), checked: http(s), nothing that cannot be sent,
#' and public addresses only.
#' @param urls As for wbsave().
#' @return The URLs, trimmed and without duplicates.
#' @noRd
.bl_wb_check_urls <- function(urls) {
  urls <- .rmbl_text_input(urls, "urls", allow_raw = FALSE)
  urls <- unique(trimws(urls[!is.na(urls) & nzchar(trimws(urls))]))
  if (!length(urls)) {
    stop("`urls` has no URLs", call. = FALSE)
  }
  for (u in urls) {
    h <- .bl_wb_hidden_char(u)
    if (nzchar(h)) {
      stop(
        sprintf(
          "a URL has %s in it, which cannot be sent: %s",
          h,
          .rmbl_printable(u)
        ),
        call. = FALSE
      )
    }
  }
  bad <- urls[!grepl("^https?://[^[:space:]]+$", urls, ignore.case = TRUE)]
  if (length(bad)) {
    stop(
      sprintf("not an http(s) URL: %s", .rmbl_printable(bad[[1L]])),
      call. = FALSE
    )
  }
  # an address on your own network (10.0.0.7, a .local or one-label name,
  # 127.0.0.1) is not archive.org's to reach, and the request would tell a
  # public archive where your intranet is (CRAN stress test of 0.5.14).
  why <- vapply(
    urls,
    function(u) .Call(C_rmbl_url_check, u, TRUE, FALSE, FALSE),
    "",
    USE.NAMES = FALSE
  )
  if (any(nzchar(why))) {
    i <- which(nzchar(why))[[1L]]
    stop(
      sprintf(
        "not a public address, so it is not sent to archive.org: %s (%s)",
        .rmbl_printable(urls[[i]]),
        why[[i]]
      ),
      call. = FALSE
    )
  }
  urls
}

#' The archive.org keys: given, or from the environment.
#' @param ak,sk As for wbsave().
#' @return A list: ak and sk.
#' @noRd
.bl_wb_check_keys <- function(ak, sk) {
  .ak <- if (is.null(ak)) .bl_ia_key("IA_S3_ACCESS_KEY") else ak
  .sk <- if (is.null(sk)) .bl_ia_key("IA_S3_SECRET_KEY") else sk
  if (!.rmbl_vrf_one_string(.ak) || !.rmbl_vrf_one_string(.sk)) {
    stop(
      "wbsave() needs your archive.org keys ",
      "(https://archive.org/account/s3.php): ",
      "set IA_S3_ACCESS_KEY and IA_S3_SECRET_KEY, or ",
      "IA_S3_ACCESS_KEY_FILE and ",
      "IA_S3_SECRET_KEY_FILE naming files that hold them",
      call. = FALSE
    )
  }
  # a key goes into a request header: anything but its own alphabet would end
  # the header
  if (!grepl("^[A-Za-z0-9]+$", .ak) || !grepl("^[A-Za-z0-9]+$", .sk)) {
    stop(
      "the archive.org keys should be letters and digits only; check ",
      "the values (they are not shown)",
      call. = FALSE
    )
  }
  list(ak = .ak, sk = .sk)
}

#' wbsave()'s options, checked.
#' @param within,jobs,poll,maxwait,permin,maxcap,capall,output As for
#'   wbsave().
#' @return A list of the checked values.
#' @noRd
.bl_wb_check_opts <- function(
  within,
  jobs,
  poll,
  maxwait,
  permin,
  maxcap,
  capall,
  output
) {
  within <- .rmbl_string1(as.character(within), "within")
  if (!grepl("^[0-9]+[smhd]?$", within)) {
    stop(
      "`within` must look like \"30d\", \"12h\", \"90m\" or \"0\"",
      call. = FALSE
    )
  }
  timing <- .bl_wb_check_timing(jobs, poll, maxwait, permin)
  maxcap <- .rmbl_num(maxcap, "maxcap", integer = TRUE)
  if (length(maxcap) != 1L || is.na(maxcap) || maxcap < 1L) {
    stop("`maxcap` must be a whole number of at least 1", call. = FALSE)
  }
  if (!is.logical(capall) || length(capall) != 1L || is.na(capall)) {
    stop("`capall` must be TRUE or FALSE", call. = FALSE)
  }
  c(
    list(within = within),
    timing,
    list(
      maxcap = maxcap,
      capall = capall,
      output = .bl_wb_check_output(output)
    )
  )
}

#' wbsave()'s jobs, polling interval, longest wait and rate, checked.
#' @param jobs,poll,maxwait,permin As for wbsave().
#' @return A list of the checked values.
#' @noRd
.bl_wb_check_timing <- function(jobs, poll, maxwait, permin) {
  jobs <- .rmbl_num(jobs, "jobs", integer = TRUE)
  if (length(jobs) != 1L || is.na(jobs) || jobs < 1L || jobs > 12L) {
    stop("`jobs` must be a whole number from 1 to 12", call. = FALSE)
  }
  pw <- .bl_wb_check_poll(poll, maxwait)
  permin <- .rmbl_num(permin, "permin")
  if (length(permin) != 1L || is.na(permin) || permin <= 0 || permin > 60) {
    stop("`permin` must be a number above 0 and at most 60", call. = FALSE)
  }
  list(jobs = jobs, poll = pw$poll, maxwait = pw$maxwait, permin = permin)
}

#' wbsave()'s polling interval and longest wait, checked.
#' @param poll,maxwait As for wbsave().
#' @return A list: poll and maxwait.
#' @noRd
.bl_wb_check_poll <- function(poll, maxwait) {
  poll <- .rmbl_num(poll, "poll")
  maxwait <- .rmbl_num(maxwait, "maxwait")
  if (length(poll) != 1L || is.na(poll) || poll < 1) {
    stop("`poll` must be at least 1 second", call. = FALSE)
  }
  if (length(maxwait) != 1L || is.na(maxwait) || maxwait < poll) {
    stop("`maxwait` must be at least `poll` seconds", call. = FALSE)
  }
  list(poll = poll, maxwait = maxwait)
}

#' The results file is checked before anything is sent: a missing folder used
#' to fail only after the first capture had started.
#' @param output As for wbsave().
#' @return The path, or NULL.
#' @noRd
.bl_wb_check_output <- function(output) {
  if (is.null(output)) {
    return(NULL)
  }
  output <- .rmbl_string1(output, "output")
  if (!dir.exists(dirname(output))) {
    stop(
      sprintf("the folder for `output` does not exist: %s", dirname(output)),
      call. = FALSE
    )
  }
  ok <- tryCatch(
    {
      con <- file(output, "a")
      close(con)
      TRUE
    },
    error = function(e) FALSE,
    warning = function(w) FALSE
  )
  if (!ok || dir.exists(output)) {
    stop(sprintf("cannot write the results file %s", output), call. = FALSE)
  }
  output
}

#' The state of one wbsave() run, shared by its helpers.
#'
#' Every resubmission since the last capture that got through counts for the
#' run, and an error for the URL: a throttle in the status reply used to requeue
#' the URL and the job id it got next reset the strikes, so one URL made 174
#' POSTs and never stopped (review of 29a55d8, G5). A URL that errs is sent at
#' most six times (a throttle is the account's state, not the URL's: it counts
#' toward the eight strikes); a run resubmits at most as many times as it has
#' URLs (and 20) between two captures that get through, then stops (a cap over
#' the whole run stopped a slow archive at 27 of 40; review of 46de6a9, H7)
#' @param opt The checked options (.bl_wb_check_opts()).
#' @param keys The archive.org keys for the authorization header.
#' @param prior The results already in the output file.
#' @param kept The URLs finished in an earlier run.
#' @param queue The URLs to submit.
#' @return An environment.
#' @noRd
.bl_wb_state <- function(opt, keys, prior, kept, queue) {
  w <- new.env(parent = emptyenv())
  for (nm in names(opt)) {
    assign(nm, opt[[nm]], envir = w)
  }
  w$queue <- queue
  w$hdr <- c(
    sprintf("Authorization: LOW %s:%s", keys$ak, keys$sk),
    "Accept: application/json"
  )
  w$results <- prior[kept]
  w$counts <- c(saved = 0L, existing = 0L, failed = 0L, submitted = 0L)
  # captures in flight, by URL (two URLs given the same job id each keep their
  # own entry)
  w$inflight <- list()
  w$attempts <- stats::setNames(integer(length(queue)), queue)
  w$spacing <- 60 / opt$permin
  w$next_post <- -Inf
  # nothing is submitted before this (archive.org asked to slow down)
  w$hold_until <- -Inf
  w$throttles <- 0L # slow-down replies since the last capture that got through
  w$stopped <- NULL # why submitting stopped for the rest of the run
  w$requeues <- 0L
  w$requeue_cap <- max(20L, length(queue))
  w
}

#' The progress line of a wbsave() run.
#' @param w The run's state.
#' @return The text.
#' @noRd
.bl_wb_info <- function(w) {
  sprintf(
    "%d saved, %d existing, %d failed, %d in flight",
    w$counts[["saved"]],
    w$counts[["existing"]],
    w$counts[["failed"]],
    length(w$inflight)
  )
}

#' Records one URL's result, and appends it to the output file.
#' @param w The run's state.
#' @param u The URL whose result is recorded.
#' @param status,ts,snap,msg,job_id The result.
#' @noRd
.bl_wb_finish <- function(
  w,
  u,
  status,
  ts = NA_character_,
  snap = NA_character_,
  msg = "",
  job_id = NA_character_
) {
  rec <- list(
    url = u,
    status = status,
    timestamp = ts,
    snapshot = snap,
    message = msg,
    at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
  if (!is.na(job_id)) {
    rec$job_id <- job_id
  }
  w$results[[u]] <- rec
  w$counts[[status]] <- w$counts[[status]] + 1L
  if (!is.null(w$output)) {
    cat(
      tojs(rec, auto_unbox = TRUE),
      "\n",
      sep = "",
      file = w$output,
      append = TRUE
    )
  }
}

#' A URL archive.org will not capture again today: its latest snapshot, if it
#' has one, else a failure.
#' @param w The run's state.
#' @param u The URL looked up after a failed save.
#' @param msg What archive.org said.
#' @noRd
.bl_wb_existing_or_failed <- function(w, u, msg) {
  s <- .bl_wb_lookup(u)
  if (is.null(s)) {
    .bl_wb_finish(w, u, "failed", msg = msg)
  } else {
    .bl_wb_finish(
      w,
      u,
      "existing",
      .bl_wb_ts(sub("^.*/web/([0-9]{14})[^/]*/.*$", "\\1", s)),
      s,
      msg
    )
  }
}

#' The body of a capture request.
#' @param w The run's state.
#' @param u The URL encoded into the save form.
#' @return The form.
#' @noRd
.bl_wb_form <- function(w, u) {
  paste0(
    "url=",
    utils::URLencode(u, reserved = TRUE),
    "&skip_first_archive=1",
    if (w$within != "0") paste0("&if_not_archived_within=", w$within) else "",
    if (w$capall) "&capture_all=1" else ""
  )
}

#' Stops the run when archive.org refuses the keys.
#' @param res A reply.
#' @noRd
.bl_wb_refused <- function(res) {
  if (res$status %in% c(401L, 403L)) {
    stop(
      sprintf(
        paste0(
          "archive.org refused the keys (HTTP %d): check them at ",
          "https://archive.org/account/s3.php"
        ),
        res$status
      ),
      call. = FALSE
    )
  }
}

#' Puts a URL back on the queue (see .bl_wb_state() for the limits).
#' @param w The run's state.
#' @param u The URL put back on the queue.
#' @param why What went wrong.
#' @param err Whether it counts as an error for the URL.
#' @return TRUE when it was requeued.
#' @noRd
.bl_wb_requeue <- function(w, u, why, err = TRUE) {
  w$requeues <- w$requeues + 1L
  if (err) {
    a <- w$attempts[u]
    w$attempts[[u]] <- (if (is.na(a)) 0L else a) + 1L
    if (w$attempts[[u]] >= 6L) {
      .bl_wb_finish(
        w,
        u,
        "failed",
        msg = paste("gave up after six tries:", why)
      )
      return(FALSE)
    }
  }
  if (w$requeues > w$requeue_cap) {
    w$queue <- c(u, w$queue)
    w$stopped <- sprintf(
      "archive.org answered %d resubmissions with errors or slow-downs (%s)",
      w$requeues,
      why
    )
    return(FALSE)
  }
  w$queue <- c(u, w$queue)
  TRUE
}

#' archive.org asked to slow down: hold submissions, and stop after eight in a
#' row.
#' @param w The run's state.
#' @param u The URL the server asked to slow down for.
#' @param res The reply.
#' @param now The time.
#' @param why What it said.
#' @noRd
.bl_wb_slow_down <- function(w, u, res, now, why) {
  w$throttles <- w$throttles + 1L
  if (w$throttles >= 8L) {
    w$queue <- c(u, w$queue)
    w$stopped <- sprintf(
      "archive.org asked to slow down eight times in a row (%s)",
      why
    )
    return(invisible())
  }
  if (!.bl_wb_requeue(w, u, why, err = FALSE)) {
    return(invisible())
  }
  ra <- .bl_wb_retry_after(res)
  w$hold_until <- now +
    if (!is.na(ra)) {
      max(ra, w$spacing)
    } else {
      min(600, 15 * 2^(w$throttles - 1L))
    }
}

#' A message that archive.org left empty is written out, so wbrtry() knows what
#' happened.
#' @param m The server's message, or NA or empty for the default.
#' @param default What to write instead.
#' @return The text.
#' @noRd
.bl_wb_said <- function(m, default) if (is.na(m) || !nzchar(m)) default else m

#' Submits one URL for capture and acts on the reply.
#' @param w The run's state.
#' @param u The URL to submit for saving.
#' @param now The time.
#' @noRd
.bl_wb_submit <- function(w, u, now) {
  res <- .bl_wb_post(.bl_wb_form(w, u), w$hdr)
  .bl_wb_refused(res)
  j <- .bl_wb_json(res)
  id <- .bl_wb_job_id(j$job_id)
  if (!is.na(id)) {
    w$inflight[[u]] <- list(
      id = id,
      start = now,
      due = now + w$poll,
      fails = 0L
    )
  } else if (!is.null(j) && .bl_wb_account_cap(j)) {
    w$queue <- c(u, w$queue)
    w$stopped <- sprintf(
      "the account's daily capture limit is reached (%s)",
      .bl_wb_str(j$message) %|NA|% ""
    )
  } else if (
    identical(res$status, 429L) || (!is.null(j) && .bl_wb_throttled(j))
  ) {
    .bl_wb_slow_down(w, u, res, now, .bl_wb_throttle_why(res, j))
  } else if (
    res$status < 0 ||
      res$status %in% c(404L, 408L) ||
      res$status >= 500L ||
      is.null(j)
  ) {
    .bl_wb_submit_transient(w, u, res, now)
  } else {
    .bl_wb_submit_answer(w, u, res, j)
  }
}

#' Why archive.org asked a capture request to slow down.
#' @param res The reply.
#' @param j Its JSON, or NULL.
#' @return One string.
#' @noRd
.bl_wb_throttle_why <- function(res, j) {
  if (identical(res$status, 429L)) {
    "HTTP 429"
  } else {
    (.bl_wb_str(j$status_ext) %|NA|%
      .bl_wb_str(j$message) %|NA|%
      "slow down")
  }
}

#' A capture request that failed for a reason that passes: queued again, and
#' the run held back for a while.
#' @param w The run's state.
#' @param u The URL whose submission failed transiently.
#' @param res The reply.
#' @param now The time.
#' @noRd
.bl_wb_submit_transient <- function(w, u, res, now) {
  # a 404 or 408 from the capture endpoint itself is archive.org under
  # load, not the page: with many jobs in flight live StatCan tables were
  # answered 404 and captured fine one at a time
  why <- if (res$status < 0) res$error else sprintf("HTTP %d", res$status)
  if (.bl_wb_requeue(w, u, why)) {
    ra <- .bl_wb_retry_after(res)
    w$hold_until <- now +
      if (!is.na(ra)) ra else min(300, 15 * 2^(w$attempts[[u]] - 1L))
  }
}

#' A capture request that got an answer without a job: captured already today,
#' captured already, or failed.
#' @param w The run's state.
#' @param u The URL whose submission was answered.
#' @param res The reply.
#' @param j Its JSON.
#' @noRd
.bl_wb_submit_answer <- function(w, u, res, j) {
  if (.bl_wb_daily_limit(j)) {
    w$throttles <- 0L
    .bl_wb_existing_or_failed(
      w,
      u,
      .bl_wb_said(.bl_wb_str(j$message), "captured already today")
    )
  } else if (!is.na(.bl_wb_ts(j$timestamp))) {
    w$throttles <- 0L
    w$requeues <- 0L
    .bl_wb_finish(
      w,
      u,
      "existing",
      .bl_wb_ts(j$timestamp),
      .bl_wb_snapshot(.bl_wb_ts(j$timestamp), u)
    )
  } else {
    .bl_wb_finish(
      w,
      u,
      "failed",
      msg = .bl_wb_str(j$message) %|NA|%
        if (!is.null(j$job_id)) {
          "archive.org's reply has no usable job id"
        } else {
          sprintf("HTTP %d", res$status)
        }
    )
  }
}

#' Asks archive.org how one capture in flight is going, and acts on the
#' answer.
#' @param w The run's state.
#' @param u The URL whose save job is checked.
#' @param now The time.
#' @noRd
.bl_wb_check_job <- function(w, u, now) {
  job <- w$inflight[[u]]
  res <- .bl_wb_get(
    sprintf("/save/status/%s", utils::URLencode(job$id, reserved = TRUE)),
    w$hdr
  )
  .bl_wb_refused(res)
  j <- .bl_wb_json(res)
  st <- .bl_wb_str(j$status) %|NA|% ""
  if (identical(res$status, 404L) && !identical(st, "error")) {
    .bl_wb_finish(
      w,
      u,
      "failed",
      msg = sprintf("archive.org no longer knows capture %s", job$id)
    )
    w$inflight[[u]] <- NULL
  } else if (
    res$status < 0 ||
      identical(res$status, 429L) ||
      res$status >= 500L ||
      is.null(j)
  ) {
    if (now - job$start > w$maxwait) {
      .bl_wb_job_timeout(w, u)
    } else {
      ra <- .bl_wb_retry_after(res)
      w$inflight[[u]]$fails <- job$fails + 1L
      w$inflight[[u]]$due <- now +
        if (!is.na(ra)) ra else min(300, w$poll * 2^job$fails)
    }
  } else if (identical(st, "success")) {
    .bl_wb_job_saved(w, u, j)
  } else if (identical(st, "error")) {
    .bl_wb_job_error(w, u, res, j, now)
  } else if (now - job$start > w$maxwait) {
    .bl_wb_job_timeout(w, u)
  } else {
    w$inflight[[u]]$fails <- 0L
    w$inflight[[u]]$due <- now + w$poll
  }
}

#' A capture that archive.org did not answer for in time.
#' @param w The run's state.
#' @param u The URL whose save job timed out.
#' @noRd
.bl_wb_job_timeout <- function(w, u) {
  .bl_wb_finish(
    w,
    u,
    "failed",
    msg = sprintf("no answer from archive.org in %g seconds", w$maxwait)
  )
  w$inflight[[u]] <- NULL
}

#' A capture that succeeded.
#' @param w The run's state.
#' @param u The URL whose save job finished.
#' @param j The status reply's JSON.
#' @noRd
.bl_wb_job_saved <- function(w, u, j) {
  w$throttles <- 0L
  w$requeues <- 0L
  ts <- .bl_wb_ts(j$timestamp)
  orig <- .bl_wb_str(j$original_url)
  if (
    is.na(orig) ||
      !grepl("^https?://[^[:space:]]+$", orig, ignore.case = TRUE)
  ) {
    orig <- u
  }
  .bl_wb_finish(w, u, "saved", ts, .bl_wb_snapshot(ts, orig))
  w$inflight[[u]] <- NULL
}

#' A capture that ended in an error: a slow-down, captured already today, or a
#' failure.
#' @param w The run's state.
#' @param u The URL whose save job failed.
#' @param res The status reply.
#' @param j Its JSON.
#' @param now The time.
#' @noRd
.bl_wb_job_error <- function(w, u, res, j, now) {
  w$inflight[[u]] <- NULL
  if (.bl_wb_throttled(j)) {
    .bl_wb_slow_down(
      w,
      u,
      res,
      now,
      .bl_wb_str(j$status_ext) %|NA|% "slow down"
    )
  } else if (.bl_wb_daily_limit(j)) {
    w$throttles <- 0L
    .bl_wb_existing_or_failed(
      w,
      u,
      .bl_wb_said(.bl_wb_str(j$message), "captured already today")
    )
  } else {
    .bl_wb_finish(
      w,
      u,
      "failed",
      msg = .bl_wb_str(j$message) %|NA|%
        (.bl_wb_str(j$status_ext) %|NA|% "error")
    )
  }
}

#' Waits for whichever comes first: a capture to check, or the next
#' submission.
#' @param w The run's state.
#' @noRd
.bl_wb_wait <- function(w) {
  nxt <- c(
    if (length(w$inflight)) {
      min(vapply(w$inflight, function(x) x$due, numeric(1)))
    },
    if (is.null(w$stopped) && length(w$queue) && length(w$inflight) < w$jobs) {
      max(w$next_post, w$hold_until)
    }
  )
  if (length(nxt)) {
    gap <- min(nxt) - .bl_wb_now()
    if (gap > 0) .bl_anim_wait(w$anim, max(0.2, gap))
  }
}

#' The closing line of a wbsave() run.
#' @param w The run's state.
#' @param started The captures this run started.
#' @param earlier The URLs done in an earlier run.
#' @param not_sent The URLs not sent.
#' @return The text.
#' @noRd
.bl_wb_summary <- function(w, started, earlier, not_sent) {
  sprintf(
    "Wayback: %d saved, %d existing, %d failed (of %d)%s%s",
    w$counts[["saved"]],
    w$counts[["existing"]],
    w$counts[["failed"]],
    started,
    if (earlier) sprintf("; %d done in an earlier run", earlier) else "",
    if (length(not_sent)) {
      sprintf(
        "; %d not sent%s, run again to continue",
        length(not_sent),
        if (is.null(w$stopped)) {
          " (max_captures)"
        } else {
          paste0(": ", w$stopped)
        }
      )
    } else {
      ""
    }
  )
}

#' Reads the results of a run as they stand on disk.
#'
#' The results of a run as they stand on disk: the last line written for each
#' URL wins (a retry appends, so a later \code{"saved"} replaces an earlier
#' \code{"failed"}).
#' @param output The results file.
#' @return A data frame of class `rmbl_wayback_save`.
#' @noRd
.bl_wb_read <- function(output) .bl_wb_frame(.bl_wb_records(output))

#' A failure that a new capture cannot fix: the page is gone from its source
#' @param msg The failure message.
#' @return TRUE or FALSE.
#' @noRd
.bl_wb_gone <- function(msg) {
  # only what the target server said: "HTTP 404" in a failure message is the
  # status of archive.org's own API (a capture refused or a job lost), and those
  # pages are live
  grepl(
    paste0(
      "target server cannot find|returned 404|returned ",
      "410|error:not-found|error:gone"
    ),
    msg,
    ignore.case = TRUE
  )
}

#' A failure that a capture today cannot fix: the URL's or the account's daily
#' limit
#' @param msg The failure message.
#' @return TRUE or FALSE.
#' @noRd
.bl_wb_daily_failure <- function(msg) {
  grepl(
    paste0(
      "already captured|captured already today|captured [0-9]+ times ",
      "today|too-many-daily-captures|",
      "daily capture limit|captures per day"
    ),
    msg,
    ignore.case = TRUE
  )
}

#' Saves what the Wayback Machine refused (a server that refuses its crawler)
#' from this connection to archive.rmorie.com instead, as attribute archive of
#' the wbsave() result.
#' @param out A wbsave() result.
#' @param reason Why the files are kept.
#' @return The result, with attribute archive (an arccap() result, or the reason
#'   it failed) when anything was refused.
#' @noRd
.bl_wb_fallback <- function(out, reason) {
  refused <- out$status == "failed" &
    grepl(
      "cannot find|blocks access|HTTP status=40[134]|not reachable",
      ifelse(is.na(out$message), "", out$message)
    )
  if (!any(refused)) {
    return(out)
  }
  attr(out, "archive") <- tryCatch(
    arccap(
      out$url[refused],
      file.path(tempdir(), "rmbl-wayback-fallback"),
      tsa = NULL,
      upload = "rmorie",
      reason = reason %||% ""
    ),
    error = function(e) {
      .bl_unless_interrupted(
        e,
        structure(conditionMessage(e), class = "rmbl_fail")
      )
    }
  )
  out
}
