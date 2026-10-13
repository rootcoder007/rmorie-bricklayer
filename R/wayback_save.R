# Bulk archiving to the Wayback Machine with Save Page Now 2 (SPN2), the API archive.org offers
# to account holders: a POST to /save starts a capture and returns a job id, /save/status/<id>
# says when it is done. Captures run on archive.org's side, so the speed comes from keeping
# several jobs in flight while polling them, not from parallel connections: one native
# connection at a time (src/rmbl_fetch.cpp, the package's only network code) is enough to drive
# as many jobs as an account may run.

.bl_wb_base <- function() "https://web.archive.org"

# The transport seams (the package's checked libcurl calls), one place for tests to stand in a
# server.
.bl_wb_post <- function(body, headers) {
  .Call(C_rmbl_http_post, paste0(.bl_wb_base(), "/save"), charToRaw(body),
        "application/x-www-form-urlencoded", 60L, headers, FALSE)
}
.bl_wb_get <- function(path, headers) {
  .Call(C_rmbl_http_get, paste0(.bl_wb_base(), path), 60L, headers, FALSE)
}
.bl_wb_lookup <- function(url) tryCatch(wayback_snapshot_url_native(url, timeout = 30L), error = function(e) NULL)
.bl_wb_now <- function() proc.time()[["elapsed"]]

# a reply's JSON, or NULL (an HTML error page, an empty body)
.bl_wb_json <- function(res) {
  if (!length(res$body)) return(NULL)
  j <- tryCatch(.rmbl_json_parse(rawToChar(res$body)), error = function(e) NULL)
  if (is.list(j)) j else NULL
}

# An archive.org key: the variable, or the file its _FILE twin names (the convention for keys
# kept on disk, as Docker secrets are). Never printed.
.bl_ia_key <- function(var) {
  v <- Sys.getenv(var)
  if (nzchar(v)) return(trimws(v))
  f <- Sys.getenv(paste0(var, "_FILE"))
  if (!nzchar(f)) return("")
  if (!file.exists(f)) stop(sprintf("%s_FILE names %s, which does not exist", var, f), call. = FALSE)
  trimws(readLines(f, n = 1L, warn = FALSE))
}

.bl_wb_snapshot <- function(ts, url) sprintf("https://web.archive.org/web/%s/%s", ts, url)

# archive.org's own words for "captured already today"
.bl_wb_daily_limit <- function(j) {
  grepl("already captured", j$message %||% "", fixed = TRUE) ||
    identical(j$status_ext, "error:too-many-daily-captures")
}

#' Archive many pages in the Wayback Machine
#'
#' Saves every URL in the Internet Archive's Wayback Machine
#' with Save Page Now 2, the API archive.org offers to account
#' holders, keeping several captures in flight at once. A page
#' archived recently is kept as it is (\code{within}); a page
#' archive.org has already captured today (its daily limit) is
#' recorded with that capture. Each result is written to
#' \code{output} as it arrives, so an interrupted run started
#' again with the same \code{output} carries on where it
#' stopped. A live progress bar shows the run while a person is
#' watching.
#'
#' @param urls Character vector of \code{http} or \code{https}
#'   URLs. Duplicates, \code{NA} and empty strings are dropped.
#' @param access_key,secret_key Your archive.org S3-like API
#'   keys (\url{https://archive.org/account/s3.php}). By default
#'   they are read from the environment variables
#'   \code{IA_S3_ACCESS_KEY} and \code{IA_S3_SECRET_KEY}, or from
#'   the files named by \code{IA_S3_ACCESS_KEY_FILE} and
#'   \code{IA_S3_SECRET_KEY_FILE}. They are sent to
#'   web.archive.org only and never printed.
#' @param within Keep a capture made within this long instead of
#'   making a new one: a number followed by \code{s}, \code{m},
#'   \code{h} or \code{d} (default \code{"30d"}); \code{"0"}
#'   always captures.
#' @param jobs Captures in flight at once, 1 to 12. Default 4.
#' @param output Optional path of a JSON Lines file: one line
#'   per URL, written as each finishes, and read at the start so a
#'   run can be resumed.
#' @param poll Seconds between status checks of a capture.
#'   Default 10.
#' @param max_wait Seconds a capture may take before it is given
#'   up as failed. Default 600.
#' @param capture_all Also capture error pages (4xx and 5xx);
#'   default \code{FALSE}.
#' @param quiet \code{TRUE} for no progress output; the default
#'   shows it while a person is watching.
#'
#' @return A data frame of class \code{rmbl_wayback_save}, one
#'   row per URL: \code{url}, \code{status} (\code{"saved"}, a new
#'   capture; \code{"existing"}, a capture already there; or
#'   \code{"failed"}), \code{timestamp} (\code{YYYYMMDDhhmmss}),
#'   \code{snapshot} (the archived copy's address) and
#'   \code{message} (archive.org's reason, for a failure).
#'
#' @details A rate limit (HTTP 429) or a server error is retried
#'   with exponential back-off, up to six times per URL; a refused
#'   key (HTTP 401 or 403) stops the run. The archive's own limits
#'   apply: an account may run a limited number of captures at
#'   once and capture a URL a limited number of times a day, so
#'   more \code{jobs} than the account allows only adds retries.
#'
#' @references Internet Archive. Save Page Now 2 (SPN2) public
#'   API.
#'   \url{https://archive.org/details/spn-2-public-api-page-docs}.
#' @seealso \code{\link{wayback_snapshot_url_native}} to look up an existing
#'   capture; \code{rmbl wayback FILE} runs this from the
#'   command line.
#' @examples
#' \dontrun{
#' Sys.setenv(IA_S3_ACCESS_KEY_FILE = "~/.config/ia/s3_access_key.txt",
#'            IA_S3_SECRET_KEY_FILE = "~/.config/ia/s3_secret_key.txt")
#' res <- wayback_save(c("https://www.ontariocourts.ca/ocj/statistics/",
#'                       "https://www150.statcan.gc.ca/n1/tbl/csv/35100177-eng.zip"),
#'                     output = "snapshots.jsonl")
#' res
#' }
#' @export
wayback_save <- function(urls, access_key = NULL, secret_key = NULL, within = "30d", jobs = 4L,
                         output = NULL, poll = 10, max_wait = 600, capture_all = FALSE, quiet = NULL) {
  urls <- .rmbl_text_input(urls, "urls", allow_raw = FALSE)
  urls <- unique(trimws(urls[!is.na(urls) & nzchar(trimws(urls))]))
  if (!length(urls)) stop("`urls` has no URLs", call. = FALSE)
  bad <- urls[!grepl("^https?://[^[:space:]]+$", urls, ignore.case = TRUE)]
  if (length(bad)) stop(sprintf("not an http(s) URL: %s", bad[[1L]]), call. = FALSE)
  ak <- if (is.null(access_key)) .bl_ia_key("IA_S3_ACCESS_KEY") else access_key
  sk <- if (is.null(secret_key)) .bl_ia_key("IA_S3_SECRET_KEY") else secret_key
  if (!is.character(ak) || !is.character(sk) || length(ak) != 1L || length(sk) != 1L || is.na(ak) || is.na(sk) ||
        !nzchar(ak) || !nzchar(sk)) {
    stop(paste("wayback_save() needs your archive.org keys (https://archive.org/account/s3.php):",
               "set IA_S3_ACCESS_KEY and IA_S3_SECRET_KEY, or IA_S3_ACCESS_KEY_FILE and",
               "IA_S3_SECRET_KEY_FILE naming files that hold them"), call. = FALSE)
  }
  # a key goes into a request header: anything but its own alphabet would end the header
  if (!grepl("^[A-Za-z0-9]+$", ak) || !grepl("^[A-Za-z0-9]+$", sk)) {
    stop("the archive.org keys should be letters and digits only; check the values (they are not shown)",
         call. = FALSE)
  }
  within <- .rmbl_string1(as.character(within), "within")
  if (!grepl("^[0-9]+[smhd]?$", within)) {
    stop("`within` must look like \"30d\", \"12h\", \"90m\" or \"0\"", call. = FALSE)
  }
  jobs <- .rmbl_num(jobs, "jobs", integer = TRUE)
  if (length(jobs) != 1L || is.na(jobs) || jobs < 1L || jobs > 12L) {
    stop("`jobs` must be a whole number from 1 to 12", call. = FALSE)
  }
  poll <- .rmbl_num(poll, "poll")
  max_wait <- .rmbl_num(max_wait, "max_wait")
  if (length(poll) != 1L || is.na(poll) || poll < 1) stop("`poll` must be at least 1 second", call. = FALSE)
  if (length(max_wait) != 1L || is.na(max_wait) || max_wait < poll) {
    stop("`max_wait` must be at least `poll` seconds", call. = FALSE)
  }
  if (!is.logical(capture_all) || length(capture_all) != 1L || is.na(capture_all)) {
    stop("`capture_all` must be TRUE or FALSE", call. = FALSE)
  }
  # results already in `output`: a finished URL is not sent again
  prior <- list()
  if (!is.null(output)) {
    output <- .rmbl_string1(output, "output")
    if (file.exists(output)) {
      for (l in readLines(output, warn = FALSE)) {
        r <- tryCatch(.rmbl_json_parse(l), error = function(e) NULL)
        if (is.list(r) && is.character(r$url) && identical(length(r$url), 1L)) prior[[r$url]] <- r
      }
    }
  }
  kept <- names(prior)[vapply(prior, function(r) isTRUE(r$status %in% c("saved", "existing")), logical(1))]
  todo <- setdiff(urls, kept)
  hdr <- c(sprintf("Authorization: LOW %s:%s", ak, sk), "Accept: application/json")
  results <- prior[intersect(kept, urls)]
  counts <- c(saved = 0L, existing = 0L, failed = 0L)
  anim <- .bl_anim_new("Wayback", length(todo), color = "blue", quiet = quiet)
  info <- function(inflight) {
    sprintf("%d saved, %d existing, %d failed, %d in flight", counts[["saved"]], counts[["existing"]],
            counts[["failed"]], length(inflight))
  }
  finish <- function(u, status, ts = NA_character_, snap = NA_character_, msg = "") {
    rec <- list(url = u, status = status, timestamp = ts, snapshot = snap, message = msg)
    results[[u]] <<- rec
    counts[[status]] <<- counts[[status]] + 1L
    if (!is.null(output)) {
      cat(bricklayer_json_to_json(rec, auto_unbox = TRUE), "\n", sep = "", file = output, append = TRUE)
    }
  }
  existing_or_failed <- function(u, msg) {
    s <- .bl_wb_lookup(u)
    if (is.null(s)) {
      finish(u, "failed", msg = msg)
    } else {
      finish(u, "existing", sub("^.*/web/([0-9]{14})[^/]*/.*$", "\\1", s), s, msg)
    }
  }
  form <- function(u) {
    paste0("url=", utils::URLencode(u, reserved = TRUE), "&skip_first_archive=1",
           if (within != "0") paste0("&if_not_archived_within=", within) else "",
           if (capture_all) "&capture_all=1" else "")
  }
  refused <- function(res) {
    if (res$status %in% c(401L, 403L)) {
      stop(sprintf("archive.org refused the keys (HTTP %d): check them at https://archive.org/account/s3.php",
                   res$status), call. = FALSE)
    }
  }
  queue <- todo
  inflight <- list()
  attempts <- stats::setNames(integer(length(todo)), todo)
  while (length(queue) || length(inflight)) {
    waited <- FALSE
    # start captures while there is room
    while (length(inflight) < jobs && length(queue)) {
      u <- queue[[1L]]
      queue <- queue[-1L]
      res <- .bl_wb_post(form(u), hdr)
      refused(res)
      j <- .bl_wb_json(res)
      if (!is.null(j$job_id)) {
        inflight[[j$job_id]] <- list(url = u, start = .bl_wb_now(), due = .bl_wb_now() + poll)
      } else if (res$status < 0 || res$status == 429L || res$status >= 500L || is.null(j)) {
        attempts[[u]] <- attempts[[u]] + 1L
        why <- if (res$status < 0) res$error else sprintf("HTTP %d", res$status)
        if (attempts[[u]] >= 6L) {
          finish(u, "failed", msg = paste("gave up after six tries:", why))
        } else {
          queue <- c(u, queue)
          .bl_anim_update(anim, sum(counts), info(inflight))
          .bl_anim_wait(anim, min(300, 15 * 2^(attempts[[u]] - 1L)))
          waited <- TRUE
          break
        }
      } else if (.bl_wb_daily_limit(j)) {
        existing_or_failed(u, j$message %||% "captured already today")
      } else if (!is.null(j$timestamp)) {
        finish(u, "existing", j$timestamp, .bl_wb_snapshot(j$timestamp, u))
      } else {
        finish(u, "failed", msg = j$message %||% sprintf("HTTP %d", res$status))
      }
      .bl_anim_update(anim, sum(counts), info(inflight))
    }
    # check the captures that are due
    now <- .bl_wb_now()
    for (id in names(inflight)) {
      job <- inflight[[id]]
      if (job$due > now) next
      res <- .bl_wb_get(paste0("/save/status/", utils::URLencode(id, reserved = TRUE)), hdr)
      refused(res)
      j <- .bl_wb_json(res)
      st <- j$status %||% ""
      if (identical(st, "success")) {
        ts <- j$timestamp %||% NA_character_
        finish(job$url, "saved", ts, .bl_wb_snapshot(ts, j$original_url %||% job$url))
        inflight[[id]] <- NULL
      } else if (identical(st, "error")) {
        if (.bl_wb_daily_limit(j)) existing_or_failed(job$url, j$message %||% "") else
          finish(job$url, "failed", msg = j$message %||% (j$status_ext %||% "error"))
        inflight[[id]] <- NULL
      } else if (now - job$start > max_wait) {
        finish(job$url, "failed", msg = sprintf("no answer from archive.org in %g seconds", max_wait))
        inflight[[id]] <- NULL
      } else {
        inflight[[id]]$due <- now + poll
      }
      .bl_anim_update(anim, sum(counts), info(inflight))
    }
    # nothing more to start: wait for the next capture that is due
    if (!waited && length(inflight) && (length(inflight) >= jobs || !length(queue))) {
      nxt <- min(vapply(inflight, function(x) x$due, numeric(1)))
      .bl_anim_wait(anim, max(0.2, nxt - .bl_wb_now()))
    }
  }
  .bl_anim_update(anim, sum(counts), info(inflight), force = TRUE)
  earlier <- length(intersect(kept, urls))
  .bl_anim_done(anim, sprintf("Wayback: %d saved, %d existing, %d failed (of %d)%s", counts[["saved"]],
                              counts[["existing"]], counts[["failed"]], length(todo),
                              if (earlier) sprintf("; %d done in an earlier run", earlier) else ""))
  rows <- results[intersect(urls, names(results))]
  out <- data.frame(url = vapply(rows, function(r) r$url, ""),
                    status = vapply(rows, function(r) r$status, ""),
                    timestamp = vapply(rows, function(r) as.character(r$timestamp %||% NA_character_), ""),
                    snapshot = vapply(rows, function(r) as.character(r$snapshot %||% NA_character_), ""),
                    message = vapply(rows, function(r) as.character(r$message %||% ""), ""),
                    stringsAsFactors = FALSE, row.names = NULL)
  class(out) <- c("rmbl_wayback_save", "data.frame")
  out
}

#' @export
print.rmbl_wayback_save <- function(x, ...) {
  tab <- table(factor(x$status, levels = c("saved", "existing", "failed")))
  notes <- sprintf("%d URLs: %d saved, %d existing, %d failed", nrow(x), tab[["saved"]], tab[["existing"]],
                   tab[["failed"]])
  show <- as.data.frame(unclass(x))[, c("status", "timestamp", "url")]
  show$url <- ifelse(nchar(show$url) > 70, paste0(substr(show$url, 1, 67), "..."), show$url)
  .rmbl_print_table("Wayback Machine captures", utils::head(show, 20L), notes = notes,
                    footer = if (nrow(x) > 20L) sprintf("... and %d more rows", nrow(x) - 20L), ...)
  invisible(x)
}

# The results of a run as they stand on disk: the last line written for each URL wins (a retry
# appends, so a later "saved" replaces an earlier "failed").
.bl_wb_read <- function(output) {
  rows <- list()
  for (l in readLines(output, warn = FALSE)) {
    r <- tryCatch(.rmbl_json_parse(l), error = function(e) NULL)
    if (is.list(r) && is.character(r$url) && identical(length(r$url), 1L)) rows[[r$url]] <- r
  }
  out <- data.frame(url = vapply(rows, function(r) r$url, ""),
                    status = vapply(rows, function(r) as.character(r$status %||% NA_character_), ""),
                    timestamp = vapply(rows, function(r) as.character(r$timestamp %||% NA_character_), ""),
                    snapshot = vapply(rows, function(r) as.character(r$snapshot %||% NA_character_), ""),
                    message = vapply(rows, function(r) as.character(r$message %||% ""), ""),
                    stringsAsFactors = FALSE, row.names = NULL)
  class(out) <- c("rmbl_wayback_save", "data.frame")
  out
}

# a failure that a new capture cannot fix: the page is gone from its source
.bl_wb_gone <- function(msg) {
  grepl("HTTP 404|HTTP 410|returned 404|returned 410|cannot find|not found|error:not-found", msg, ignore.case = TRUE)
}

#' Retry the failures of a bulk Wayback run
#'
#' Reads the results file a \code{\link{wayback_save}} run wrote
#' and tries again every URL whose latest result is
#' \code{"failed"}, so nobody has to dig the failures out by
#' hand. Each failed URL is first looked up in the Wayback
#' Machine: a capture made at any time (an earlier one of a page
#' that has since gone, or one made today by another run when
#' the daily limit refused this one) is recorded as
#' \code{"existing"} without capturing again. What is left is
#' captured again with \code{wayback_save()}, appending to the
#' same file. A page its source no longer has (HTTP 404 or 410,
#' "cannot find") is not sent again unless \code{include_gone =
#' TRUE}: a new capture would only archive the error.
#'
#' @param output The JSON Lines results file of an earlier
#'   \code{wayback_save()} run (or of \code{rmbl wayback});
#'   results of the retry are appended to it.
#' @param include_gone Also capture again the pages whose
#'   failure says the page is gone.
#' @param lookup Look each failure up in the Wayback Machine
#'   before capturing again.
#' @param ... Passed to \code{wayback_save()}: \code{jobs},
#'   \code{within}, the keys, \code{quiet}.
#' @return The whole run as it now stands, one row per URL (a
#'   data frame of class \code{rmbl_wayback_save}), with the
#'   attribute \code{retry}: how many failures there were, how
#'   many a lookup found, how many were captured again, and how
#'   many were left as gone.
#' @seealso \code{\link{wayback_save}}; \code{rmbl wayback
#'   --retry FILE.jsonl} from the command line.
#' @examples
#' \dontrun{
#' res <- wayback_save(urls, output = "snapshots.jsonl")
#' # later, or the next day once the daily capture limits have reset:
#' res <- wayback_retry("snapshots.jsonl")
#' attr(res, "retry")
#' }
#' @export
wayback_retry <- function(output, include_gone = FALSE, lookup = TRUE, ...) {
  output <- .rmbl_string1(output, "output")
  if (!file.exists(output)) stop(sprintf("no results file at %s", output), call. = FALSE)
  for (a in c("include_gone", "lookup")) {
    v <- get(a)
    if (!is.logical(v) || length(v) != 1L || is.na(v)) stop(sprintf("`%s` must be TRUE or FALSE", a), call. = FALSE)
  }
  now <- .bl_wb_read(output)
  failed <- now[now$status == "failed", , drop = FALSE]
  found <- 0L
  if (lookup && nrow(failed)) {
    for (i in seq_len(nrow(failed))) {
      s <- .bl_wb_lookup(failed$url[i])
      if (is.null(s)) next
      rec <- list(url = failed$url[i], status = "existing",
                  timestamp = sub("^.*/web/([0-9]{14})[^/]*/.*$", "\\1", s), snapshot = s,
                  message = paste("found on retry;", failed$message[i]))
      cat(bricklayer_json_to_json(rec, auto_unbox = TRUE), "\n", sep = "", file = output, append = TRUE)
      found <- found + 1L
      failed$status[i] <- "existing"
    }
  }
  left <- failed[failed$status == "failed", , drop = FALSE]
  gone <- if (include_gone) rep(FALSE, nrow(left)) else .bl_wb_gone(left$message)
  todo <- left$url[!gone]
  if (length(todo)) wayback_save(todo, output = output, ...)
  out <- .bl_wb_read(output)
  attr(out, "retry") <- data.frame(failed = nrow(failed), found_by_lookup = found, captured_again = length(todo),
                                   left_as_gone = sum(gone))
  out
}
