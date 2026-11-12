# SPDX-License-Identifier: AGPL-3.0-or-later
#
# archive.rmorie.com from R: find saved copies of an address, fetch one's exact
# bytes, and upload a capture made from your own connection. The same key as
# data.rmorie.com (rmbl login, dlogin()) signs the requests. A self-hosted
# archive is named by MORIE_ARCHIVE_URL and given its own key in
# MORIE_ARCHIVE_KEY: the stored rmorie key goes only to archive.rmorie.com.

#' Find saved copies of an address in archive.rmorie.com
#'
#' Lists the captures the archive holds of a web address, oldest first: when
#' each was taken, its HTTP status, media type, size and SHA-256, and the
#' addresses to open or download it. An address ending in \code{*} lists every
#' address that starts with it. Public captures are listed for anyone; with your
#' key (see \code{\link{dlogin}}) your private ones are listed too.
#'
#' @details The archive answers the same CDX query as the Wayback Machine
#'   (\code{/cdx/search/cdx?url=...&output=json}), so tools written for it can
#'   read it as well. Set \code{MORIE_ARCHIVE_URL} to query another archive that
#'   speaks the same protocol, with its key in \code{MORIE_ARCHIVE_KEY}.
#' @param url A web address, or the start of one followed by \code{*}.
#' @param from,to Optional limits on the capture time, as \code{"YYYY"},
#'   \code{"YYYYMM"} ... up to \code{"YYYYMMDDhhmmss"} (UTC).
#' @param limit The most captures to list (default 1000).
#' @return A data frame of class \code{rmbl_archive_find}: \code{capture_id},
#'   \code{captured} (UTC time), \code{url}, \code{status}, \code{mime},
#'   \code{bytes}, \code{sha256}, \code{mode} (\code{"client"}: saved from the
#'   capturer's connection; \code{"worker"}: saved by the archive),
#'   \code{visibility}, \code{capture} (its page) and \code{replay} (its exact
#'   bytes).
#' @seealso \code{\link{arcget}}, \code{\link{arccap}}, \code{\link{fetchvrf}}.
#' @examplesIf interactive()
#' caps <- arcfind("https://www150.statcan.gc.ca/n1/tbl/csv/35100177-eng.zip")
#' caps
#' arcfind("www150.statcan.gc.ca/n1/tbl/*")
#' @export
arcfind <- function(url, from = NULL, to = NULL, limit = 1000L) {
  url <- .rmbl_string1(url, "url")
  limit <- .rmbl_scalar(limit, "limit", 1, 10000, integer = TRUE)
  base <- .bl_arc_base()
  q <- paste0(
    "/cdx/search/cdx?output=json&limit=",
    limit,
    "&url=",
    .rmbl_pct(url),
    if (!is.null(from)) paste0("&from=", .bl_arc_stamp(from, "from")),
    if (!is.null(to)) paste0("&to=", .bl_arc_stamp(to, "to"))
  )
  res <- .bl_arc_req(
    "GET",
    q,
    key = .bl_arc_key(base),
    base = base,
    timeout = 60L
  )
  if (res$status == 200L && !is.list(res$json)) {
    stop(
      sprintf(
        paste0(
          "finding captures: %s answered HTTP 200 with something that is no ",
          "list of captures (a sign-in page or a proxy's error page looks ",
          "like this)"
        ),
        .bl_arc_host(base)
      ),
      call. = FALSE
    )
  }
  if (res$status != 200L) {
    stop(.bl_arc_why(res, "finding captures"), call. = FALSE)
  }
  out <- .bl_arc_rows(res$json[-1L], base)
  attr(out, "archive") <- base
  class(out) <- c("rmbl_archive_find", "data.frame")
  out
}

#' @export
format.rmbl_archive_find <- function(x, ...) {
  d <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  base <- attr(x, "archive") %||% "the archive"
  if (!nrow(d) || !all(c("sha256", "captured") %in% names(d))) {
    return(.rmbl_stat_block(
      "Saved copies",
      facts = list(Archive = base),
      reading = sprintf("No capture in %s.", base)
    ))
  }
  k <- length(unique(d$sha256))
  d$sha256 <- paste0(substr(d$sha256, 1L, 12L), "...")
  d$captured <- format(d$captured, "%Y-%m-%d %H:%M")
  top <- utils::head(d, 20L)
  cols <- intersect(
    c(
      "captured", "status", "bytes", "mime", "mode", "visibility",
      "withdrawn", "sha256"
    ),
    names(d)
  )
  .rmbl_res_block(
    "Saved copies",
    facts = list(Archive = base, Captures = nrow(d), `Distinct bytes` = k),
    tables = list(Captures = cbind(top["capture_id"], top[cols])),
    reading = sprintf(
      "%d capture%s in %s, %d distinct cop%s of the bytes.",
      nrow(d),
      if (nrow(d) == 1L) "" else "s",
      base,
      k,
      if (k == 1L) "y" else "ies"
    ),
    notes = c(
      .bl_arc_find_links(top),
      if (nrow(d) > 20L) sprintf("... and %d more", nrow(d) - 20L)
    )
  )
}

#' Fetch the exact bytes of a saved copy from archive.rmorie.com
#'
#' Downloads a capture's bytes and checks their SHA-256: against the archive's
#' record, and against \code{sha256} when you give one (the pin from your
#' analysis). A file that does not match is deleted.
#'
#' @param x A capture id (\code{"20261021133005-1a2b3c4d"}, from
#'   \code{\link{arcfind}} or a capture page) or a web address; for an address,
#'   the capture closest to \code{at} (default: the latest) is taken.
#' @param dest The file the fetched bytes are written to.
#' @param sha256 Optional SHA-256 the bytes must have.
#' @param at For an address, the time to be closest to, \code{"YYYY..."} up to
#'   14 digits (UTC).
#' @param tmout Seconds allowed for the download.
#' @return \code{dest}, invisibly, with attributes \code{capture_id},
#'   \code{url}, \code{captured} and \code{sha256}.
#' @seealso \code{\link{arcfind}}, \code{\link{fetchvrf}} (which falls back to
#'   the archive on its own).
#' @examplesIf interactive()
#' src <- "https://www150.statcan.gc.ca/n1/tbl/csv/35100177-eng.zip"
#' f <- arcget(src, tempfile(fileext = ".zip"))
#' attr(f, "sha256")
#' @export
arcget <- function(x, dest, sha256 = NULL, at = NULL, tmout = 600L) {
  x <- .rmbl_string1(x, "x")
  dest <- .rmbl_out_file(dest, "dest", connection = FALSE)
  tmout <- .rmbl_scalar(tmout, "tmout", 1, 86400, integer = TRUE)
  if (!is.null(sha256)) {
    sha256 <- tolower(.rmbl_string1(sha256, "sha256"))
    if (!grepl("^[0-9a-f]{64}$", sha256)) {
      stop("`sha256` must be 64 hexadecimal characters", call. = FALSE)
    }
  }
  base <- .bl_arc_base()
  key <- .bl_arc_key(base)
  cap <- .bl_arc_capture(x, at, sha256, key, base)
  if (!is.null(sha256) && !identical(cap$sha, sha256)) {
    stop(
      sprintf(
        "capture %s has SHA-256 %s, not the one asked for",
        cap$id,
        cap$sha
      ),
      call. = FALSE
    )
  }
  got <- .bl_arc_fetch(cap, dest, key, base, tmout)
  invisible(structure(
    dest,
    capture_id = cap$id,
    url = cap$url,
    sha256 = got,
    captured = as.POSIXct(cap$ts, format = "%Y%m%d%H%M%S", tz = "UTC")
  ))
}

#' List, hide or withdraw your captures in archive.rmorie.com
#'
#' \code{arcmine()} lists the captures saved with your key, newest first,
#' the withdrawn ones included. \code{arcvis()} makes one of them private or
#' public. \code{arcwd()} withdraws one for good.
#'
#' @details Only the account that saved a capture can change or withdraw it,
#'   so all three need your key (see \code{\link{dlogin}}).
#'
#'   A private capture is listed and served to you alone; a public one to
#'   anyone. A withdrawn capture leaves search, its page and every download,
#'   for everyone including you, and cannot be brought back. Its record stays
#'   as a mark that the id existed and was withdrawn by its saver. What
#'   happens to the stored bytes depends on who could have seen them: a
#'   capture that is private when withdrawn loses its search text, and its
#'   bytes are deleted unless another capture holds the same bytes; a public
#'   capture's bytes are kept, since others may have cited their SHA-256.
#'   \code{bytes_removed} in the result says what was done.
#' @param limit The most captures to list (default 100, at most 1000).
#' @param id A capture id, as \code{arcmine()} and \code{\link{arcfind}} give
#'   it (\code{"20260101120000-0123abcd"}).
#' @param to \code{"private"} or \code{"public"}.
#' @param confirm Must be \code{TRUE} for \code{arcwd()} to withdraw: a
#'   withdrawal cannot be undone, so the default \code{FALSE} stops with a
#'   message and changes nothing.
#' @return \code{arcmine()}: a data frame of class \code{rmbl_archive_find}
#'   with the columns of \code{\link{arcfind}} that the archive lists
#'   (\code{capture_id}, \code{captured}, \code{url}, \code{status},
#'   \code{mime}, \code{bytes}, \code{sha256}, \code{mode},
#'   \code{visibility}) and \code{withdrawn} (logical).
#'   \code{arcvis()}: a list with \code{capture_id} and \code{visibility},
#'   invisibly. \code{arcwd()}: a list with \code{capture_id}, \code{url},
#'   \code{withdrawn} (\code{TRUE}), \code{was} (its visibility when
#'   withdrawn) and \code{bytes_removed}, invisibly.
#' @seealso \code{\link{arcfind}}, \code{\link{arccap}}, \code{\link{arcget}}.
#' @examplesIf interactive()
#' mine <- arcmine()
#' mine
#' # hide the newest from everyone else, then show it again
#' arcvis(mine$capture_id[1], "private")
#' arcvis(mine$capture_id[1], "public")
#' # without confirm = TRUE nothing is withdrawn
#' try(arcwd(mine$capture_id[1]))
#' @export
arcmine <- function(limit = 100L) {
  limit <- .rmbl_scalar(limit, "limit", 1, 1000, integer = TRUE)
  base <- .bl_arc_base()
  key <- .bl_arc_mykey(base)
  res <- .bl_arc_req(
    "GET",
    paste0("/v1/captures?limit=", limit),
    key = key,
    base = base
  )
  if (res$status != 200L) {
    stop(.bl_arc_why(res, "listing your captures"), call. = FALSE)
  }
  if (!is.list(res$json) || !is.list(res$json$captures)) {
    stop(
      sprintf(
        paste0(
          "listing your captures: %s answered HTTP 200 with something ",
          "that is no list of captures"
        ),
        .bl_arc_host(base)
      ),
      call. = FALSE
    )
  }
  rows <- .rmbl_recs(res$json$captures)
  col <- function(k) {
    vapply(
      rows,
      function(r) {
        v <- r[[k]]
        if (length(v) == 1L && is.atomic(v)) as.character(v) else NA_character_
      },
      ""
    )
  }
  num <- function(k) suppressWarnings(as.numeric(col(k)))
  out <- data.frame(
    capture_id = col("capture_id"),
    captured = as.POSIXct(
      col("timestamp"),
      format = "%Y%m%d%H%M%S",
      tz = "UTC"
    ),
    url = col("url"),
    status = as.integer(num("status")),
    mime = col("mime"),
    bytes = num("length"),
    sha256 = col("sha256"),
    mode = col("mode"),
    visibility = col("visibility"),
    withdrawn = !is.na(col("withdrawn_at")),
    stringsAsFactors = FALSE
  )
  attr(out, "archive") <- base
  class(out) <- c("rmbl_archive_find", "data.frame")
  out
}

#' @rdname arcmine
#' @export
arcvis <- function(id, to) {
  id <- .bl_arc_id(id)
  to <- .rmbl_string1(to, "to")
  if (!to %in% c("private", "public")) {
    stop("`to` must be \"private\" or \"public\"", call. = FALSE)
  }
  base <- .bl_arc_base()
  key <- .bl_arc_mykey(base)
  res <- .bl_arc_req(
    "POST",
    sprintf("/v1/captures/%s/visibility", id),
    body = list(visibility = to),
    key = key,
    base = base
  )
  if (res$status != 200L) {
    stop(.bl_arc_why(res, sprintf("capture %s", id)), call. = FALSE)
  }
  if (!is.list(res$json) || !identical(res$json$visibility, to)) {
    .bl_arc_unsure(id, base)
  }
  message(sprintf("Capture %s is now %s.", id, to))
  invisible(list(capture_id = id, visibility = to))
}

#' @rdname arcmine
#' @export
arcwd <- function(id, confirm = FALSE) {
  id <- .bl_arc_id(id)
  confirm <- .rmbl_flag1(confirm, "confirm")
  if (!confirm) {
    stop(
      "arcwd: a withdrawal cannot be undone; nothing was changed. To ",
      "withdraw capture ",
      id,
      ", call arcwd(id, confirm = TRUE)",
      call. = FALSE
    )
  }
  base <- .bl_arc_base()
  key <- .bl_arc_mykey(base)
  res <- .bl_arc_req(
    "POST",
    sprintf("/v1/captures/%s/withdraw", id),
    body = list(confirm = TRUE),
    key = key,
    base = base
  )
  if (res$status != 200L) {
    stop(.bl_arc_why(res, sprintf("capture %s", id)), call. = FALSE)
  }
  if (!is.list(res$json) || !isTRUE(res$json$withdrawn)) {
    .bl_arc_unsure(id, base)
  }
  gone <- isTRUE(res$json$bytes_removed)
  message(sprintf(
    "Capture %s is withdrawn; its stored bytes were %s.",
    id,
    if (gone) "deleted" else "kept"
  ))
  one <- function(v) {
    if (length(v) == 1L && is.atomic(v)) as.character(v) else NA_character_
  }
  was <- one(res$json$was)
  invisible(list(
    capture_id = id,
    url = one(res$json$url),
    withdrawn = TRUE,
    was = if (was %in% c("private", "public")) was else NA_character_,
    bytes_removed = gone
  ))
}

#' Checks a capture id.
#' @param id The id the user passed.
#' @return The id.
#' @noRd
.bl_arc_id <- function(id) {
  id <- .rmbl_string1(id, "id")
  if (!grepl("^[0-9]{14}-[0-9a-f]{8}$", id)) {
    stop(
      "`id` must be a capture id such as \"20260101120000-0123abcd\"",
      call. = FALSE
    )
  }
  id
}

#' The caller's archive key, required: who saved a capture decides who may
#' change it.
#' @param base The archive's base address.
#' @return The key.
#' @noRd
.bl_arc_mykey <- function(base) {
  key <- .bl_arc_key(base)
  if (is.null(key)) {
    stop(
      sprintf(
        "%s needs your key: %s",
        .bl_arc_host(base),
        .bl_arc_keyhow(base)
      ),
      call. = FALSE
    )
  }
  key
}

#' How to give the archive a key: sign in for archive.rmorie.com, the
#' environment variable for another archive.
#' @param base The archive's base address.
#' @return One sentence fragment.
#' @noRd
.bl_arc_keyhow <- function(base) {
  if (identical(base, "https://archive.rmorie.com")) {
    sprintf("run dlogin() (or `%s login`) once", .bl_prog())
  } else {
    "set MORIE_ARCHIVE_KEY to your key for that archive"
  }
}

#' The archive's host name, for a message.
#' @param base The archive's base address.
#' @return One string.
#' @noRd
.bl_arc_host <- function(base = .bl_arc_base()) sub("^https?://", "", base)

#' The archive's address: MORIE_ARCHIVE_URL, else archive.rmorie.com.
#' @return One address without a trailing slash.
#' @noRd
.bl_arc_base <- function() {
  v <- sub("/+$", "", trimws(Sys.getenv("MORIE_ARCHIVE_URL", unset = "")))
  if (!nzchar(v)) {
    return("https://archive.rmorie.com")
  }
  if (!grepl("^https?://[^/[:space:]]+$", v)) {
    stop(
      "MORIE_ARCHIVE_URL must be an http(s) address with no path (an ",
      "archive's base address)",
      call. = FALSE
    )
  }
  # plain http only for an archive on your own machine or network (a test copy);
  # anything else https and public
  if (!.bl_loopback_url(v)) {
    .rmbl_check_public_url(v, "MORIE_ARCHIVE_URL")
  }
  v
}

#' The key to send to an archive, or NULL: the stored rmorie key for
#' archive.rmorie.com (else, in a GitHub Actions job allowed `id-token: write`,
#' the job's OIDC token for that address), else MORIE_ARCHIVE_KEY (a key belongs
#' to one service and does not follow an address).
#' @param base The archive's address.
#' @return One string, or NULL.
#' @noRd
.bl_arc_key <- function(base) {
  if (identical(base, "https://archive.rmorie.com")) {
    return(.bl_hosted_key() %||% .bl_gh_oidc(base))
  }
  k <- trimws(Sys.getenv("MORIE_ARCHIVE_KEY", unset = ""))
  if (nzchar(k)) k else NULL
}

.bl_oidc_cache <- new.env(parent = emptyenv())

#' A GitHub Actions OIDC token for an audience, or NULL outside such a job.
#' GitHub signs it; it names the repository and lives a few minutes, so a
#' workflow saves to the archive without a stored key. Kept for four minutes.
#' @param audience The address the token is for.
#' @return One string, or NULL.
#' @noRd
.bl_gh_oidc <- function(audience) {
  u <- Sys.getenv("ACTIONS_ID_TOKEN_REQUEST_URL", unset = "")
  t <- Sys.getenv("ACTIONS_ID_TOKEN_REQUEST_TOKEN", unset = "")
  if (!nzchar(u) || !nzchar(t) || !grepl("^https://", u)) {
    return(NULL)
  }
  hit <- .bl_oidc_cache[[audience]]
  if (!is.null(hit) && hit$until > Sys.time()) {
    return(hit$token)
  }
  url <- paste0(
    u,
    if (grepl("?", u, fixed = TRUE)) "&" else "?",
    "audience=",
    .rmbl_pct(audience)
  )
  res <- tryCatch(
    .bl_net(
      url,
      .Call(
        C_rmbl_http_get,
        url,
        30L,
        c(
          "User-Agent: rmoriebricklayer",
          "Accept: application/json",
          paste("Authorization: Bearer", t)
        ),
        FALSE
      )
    ),
    error = function(e) .bl_unless_interrupted(e, NULL)
  )
  if (is.null(res) || !identical(as.integer(res$status %||% -1L), 200L)) {
    return(NULL)
  }
  v <- tryCatch(
    .rmbl_json_text(res$body, simplifyVector = FALSE)$value,
    error = function(e) NULL
  )
  if (!is.character(v) || length(v) != 1L || !nzchar(v)) {
    return(NULL)
  }
  .bl_oidc_cache[[audience]] <- list(token = v, until = Sys.time() + 240)
  v
}

#' The largest file sent in one upload; a larger one goes as parts.
#'
#' archive.rmorie.com takes up to 95 MB in one request (Cloudflare's limit
#' is 100 MB); option rmoriebricklayer.arcpartbytes (default 90 MB) sets the
#' part size.
#' @return Bytes.
#' @noRd
.bl_arc_part_bytes <- function() {
  b <- .rmbl_getopt("arcpartbytes", 90e6)
  if (!is.numeric(b) || length(b) != 1L || is.na(b) || b < 1 || b > 95e6) {
    stop(
      "option rmoriebricklayer.arcpartbytes must be a number of bytes ",
      "from 1 to 95e6",
      call. = FALSE
    )
  }
  floor(b)
}

#' Uploads a file in one request unless the archive already holds it.
#' @param path The file to send in one request.
#' @param sha The SHA-256 of that file.
#' @param mime Its media type.
#' @param key,base The archive's key and address.
#' @param tmout Seconds.
#' @return NULL, invisibly.
#' @noRd
.bl_arc_put_blob <- function(path, sha, mime, key, base, tmout) {
  have <- .bl_arc_req(
    "GET",
    sprintf("/v1/blob/%s", sha),
    key = key,
    base = base
  )
  if (have$status == 404L) {
    put <- .bl_arc_req(
      "PUT",
      sprintf("/v1/blob/%s", sha),
      file = path,
      ctype = mime,
      key = key,
      base = base,
      timeout = tmout
    )
    if (!put$status %in% c(200L, 201L)) {
      stop(.bl_arc_why(put, "uploading the bytes"), call. = FALSE)
    }
  } else if (have$status != 200L) {
    stop(.bl_arc_why(have, "checking the archive"), call. = FALSE)
  }
  invisible(NULL)
}

#' Uploads a file too large for one request as parts, then lists them.
#'
#' Each part is a blob of its own, which the archive checks against its
#' SHA-256; the list names them in order under the whole file's SHA-256. A
#' part already there is not sent again, so a stopped upload resumes.
#' @param path The file to send in parts.
#' @param sha The SHA-256 of the whole file.
#' @param key,base The archive's key and address.
#' @param tmout Seconds, for each part.
#' @return NULL, invisibly.
#' @noRd
.bl_arc_put_parts <- function(path, sha, key, base, tmout) {
  have <- .bl_arc_req(
    "GET",
    sprintf("/v1/blob/%s", sha),
    key = key,
    base = base
  )
  if (have$status == 200L) {
    return(invisible(NULL))
  }
  if (have$status != 404L) {
    stop(.bl_arc_why(have, "checking the archive"), call. = FALSE)
  }
  size <- file.size(path)
  step <- .bl_arc_part_bytes()
  n <- ceiling(size / step)
  con <- file(path, "rb")
  on.exit(close(con), add = TRUE)
  part <- tempfile("rmbl-part-")
  on.exit(unlink(part), add = TRUE)
  shas <- character(n)
  for (i in seq_len(n)) {
    writeBin(readBin(con, "raw", step), part)
    shas[[i]] <- sha256file(part)
    .bl_arc_put_blob(
      part, shas[[i]], "application/octet-stream", key, base, tmout
    )
  }
  res <- .bl_arc_req(
    "POST",
    sprintf("/v1/blob/%s/parts", sha),
    body = list(length = size, parts = as.list(shas)),
    key = key,
    base = base
  )
  if (res$status == 404L) {
    stop(
      sprintf(
        "uploading the bytes: %s takes files of up to %s bytes only",
        sub("^https?://", "", base),
        format(step, big.mark = ",", scientific = FALSE)
      ),
      call. = FALSE
    )
  }
  if (!res$status %in% c(200L, 201L)) {
    stop(.bl_arc_why(res, "listing the parts"), call. = FALSE)
  }
  invisible(NULL)
}

#' One request to the archive.
#' @param method "GET", "POST" or "PUT".
#' @param path The path on the archive, with any query.
#' @param body For POST, a list sent as JSON.
#' @param file For PUT, the file to send.
#' @param ctype For PUT, the file's media type.
#' @param key The archive key sent with the request, or NULL for none.
#' @param base The archive's address.
#' @param timeout Seconds.
#' @return A list: status, json (parsed reply or NULL), body, error.
#' @noRd
.bl_arc_req <- function(
  method,
  path,
  body = NULL,
  file = NULL,
  ctype = "application/octet-stream",
  key = NULL,
  base = .bl_arc_base(),
  timeout = 60L
) {
  url <- paste0(base, path)
  local <- .bl_loopback_url(base)
  hdr <- c(
    "User-Agent: rmoriebricklayer (+https://archive.rmorie.com)",
    if (!is.null(key)) paste("Authorization: Bearer", key)
  )
  if (!method %in% c("GET", "POST", "PUT")) {
    stop("unknown method", call. = FALSE)
  }
  res <- switch(
    method,
    GET = .bl_net(
      url,
      .Call(C_rmbl_http_get, url, as.integer(timeout), hdr, local)
    ),
    POST = .bl_net(
      url,
      .Call(
        C_rmbl_http_post,
        url,
        charToRaw(enc2utf8(tojs(body, auto_unbox = TRUE))),
        "application/json",
        as.integer(timeout),
        hdr,
        local
      )
    ),
    PUT = .bl_net(
      url,
      .Call(C_rmbl_http_put, url, file, ctype, as.integer(timeout), hdr, local)
    )
  )
  json <- if (length(res$body)) {
    tryCatch(
      .rmbl_json_text(res$body, simplifyVector = FALSE),
      error = function(e) NULL
    )
  }
  # the archive's own error text goes into messages: one printable string,
  # with the key taken out should the archive have repeated it
  if (is.list(json) && !is.null(json$error)) {
    e <- json$error
    json$error <- if (is.character(e) && length(e) == 1L && !is.na(e)) {
      .rmbl_printable(.bl_redact(e, key))
    }
  }
  list(
    status = as.integer(res$status %||% -1L),
    json = json,
    body = res$body,
    error = res$error %||% ""
  )
}

#' Says that the archive answered 200 without confirming a change.
#' @param id The capture id.
#' @param base The archive's base address.
#' @return Never: stops.
#' @noRd
.bl_arc_unsure <- function(id, base) {
  stop(
    sprintf(
      paste0(
        "capture %s: %s answered HTTP 200 without confirming the change (a ",
        "sign-in page or a proxy's page looks like this); whether it was ",
        "made is not known: see arcmine()"
      ),
      id,
      .bl_arc_host(base)
    ),
    call. = FALSE
  )
}

#' Says why a reply from the archive is not a success.
#' @param res A .bl_arc_req() result.
#' @param what What was asked, for the message.
#' @return One string.
#' @noRd
.bl_arc_why <- function(res, what) {
  if (res$status <= 0L) {
    why <- if (nzchar(res$error)) res$error else "no reply"
    return(sprintf("%s: %s did not answer (%s)", what, .bl_arc_host(), why))
  }
  sprintf(
    "%s: the archive answered HTTP %d%s",
    what,
    res$status,
    if (is.list(res$json) && !is.null(res$json$error)) {
      paste0(" (", res$json$error, ")")
    } else {
      ""
    }
  )
}

#' Uploads one captured file to the archive and records the capture.
#' @param path The captured file to upload.
#' @param url The address it came from.
#' @param fetched The capture time (POSIXct).
#' @param reason Why it is kept.
#' @param visibility "public" or "private".
#' @param mime Media type.
#' @param base,key The archive and its key.
#' @param tmout Seconds.
#' @return The archive's reply (capture_id, capture, replay, ...).
#' @noRd
.bl_arc_upload <- function(
  path,
  url,
  fetched,
  reason,
  visibility,
  mime,
  base,
  key,
  tmout
) {
  sha <- sha256file(path)
  if (file.size(path) > .bl_arc_part_bytes()) {
    .bl_arc_put_parts(path, sha, key, base, tmout)
  } else {
    .bl_arc_put_blob(path, sha, mime, key, base, tmout)
  }
  rec <- .bl_arc_req(
    "POST",
    "/v1/captures",
    key = key,
    base = base,
    body = list(
      url = url,
      sha256 = sha,
      length = file.size(path),
      mime = mime,
      status = 200L,
      timestamp = format(fetched, "%Y%m%d%H%M%S", tz = "UTC"),
      reason = reason,
      visibility = visibility,
      software = sprintf(
        "rmoriebricklayer/%s",
        utils::packageVersion("rmoriebricklayer")
      )
    )
  )
  if (rec$status != 201L) {
    stop(.bl_arc_why(rec, "recording the capture"), call. = FALSE)
  }
  rec$json
}

#' A media type from a file name, for the WARC record and the upload.
#' @param f A file name.
#' @return One media type.
#' @noRd
.bl_arc_mime <- function(f) {
  ext <- tolower(sub("^.*\\.", "", basename(f)))
  m <- c(
    csv = "text/csv",
    tsv = "text/tab-separated-values",
    txt = "text/plain",
    json = "application/json",
    html = "text/html",
    htm = "text/html",
    xml = "application/xml",
    zip = "application/zip",
    gz = "application/gzip",
    pdf = "application/pdf",
    xlsx = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    xls = "application/vnd.ms-excel",
    parquet = "application/vnd.apache.parquet",
    png = "image/png",
    jpg = "image/jpeg",
    jpeg = "image/jpeg",
    svg = "image/svg+xml",
    css = "text/css",
    js = "text/javascript"
  )
  if (ext %in% names(m)) m[[ext]] else "application/octet-stream"
}

#' Moves a finished download into place: a rename, else a copy (another file
#' system).
#' @param from The temporary file.
#' @param to The destination.
#' @return TRUE when the file is in place.
#' @noRd
.bl_move <- function(from, to) {
  suppressWarnings(file.rename(from, to)) ||
    isTRUE(file.copy(from, to, overwrite = TRUE))
}

#' A UTC time bound of arcfind(), checked.
#' @param x The value passed as `from` or `to`.
#' @param nm The argument name, used in the error message.
#' @return The bound as a string of 4 to 14 digits.
#' @noRd
.bl_arc_stamp <- function(x, nm) {
  x <- .rmbl_string1(as.character(x), nm)
  if (!grepl("^[0-9]{4,14}$", x)) {
    stop(
      sprintf(
        "`%s` must be 4 to 14 digits of a UTC time, YYYYMMDDhhmmss",
        nm
      ),
      call. = FALSE
    )
  }
  x
}

#' arcfind()'s table from the CDX rows.
#' @param rows The CDX rows after the header row.
#' @param base The archive's base URL.
#' @return A data frame, one row per capture.
#' @noRd
.bl_arc_rows <- function(rows, base) {
  col <- function(k) {
    vapply(
      rows,
      function(r) {
        if (length(r) < k) NA_character_ else as.character(r[[k]])[1L]
      },
      ""
    )
  }
  ts <- col(2L)
  out <- data.frame(
    capture_id = col(8L),
    captured = as.POSIXct(ts, format = "%Y%m%d%H%M%S", tz = "UTC"),
    url = col(3L),
    status = as.integer(col(5L)),
    mime = col(4L),
    bytes = as.numeric(col(7L)),
    sha256 = col(9L),
    mode = col(10L),
    visibility = col(11L),
    stringsAsFactors = FALSE
  )
  out$capture <- if (nrow(out)) {
    file.path(base, "capture", out$capture_id)
  } else {
    character()
  }
  out$replay <- if (nrow(out)) {
    paste0(base, "/c/", ts, "id_/", out$url)
  } else {
    character()
  }
  out
}

#' The capture arcget() asked for: by its id, or the latest (or nearest to
#' `at`, or with hash `sha256`) capture of a URL.
#' @param x,at,sha256 As for arcget() (`sha256` checked).
#' @param key,base The archive key and base URL.
#' @return A list with the capture's `id`, `url`, `ts` and `sha`.
#' @noRd
.bl_arc_capture <- function(x, at, sha256, key, base) {
  if (grepl("^[0-9]{14}-[0-9a-f]{8}$", x)) {
    return(.bl_arc_by_id(x, key, base))
  }
  .bl_arc_by_url(x, at, sha256)
}

#' One capture's record, by its id.
#' @param x The capture id.
#' @param key,base The archive key and base URL.
#' @return As for `.bl_arc_capture()`.
#' @noRd
.bl_arc_by_id <- function(x, key, base) {
  res <- .bl_arc_req(
    "GET",
    sprintf("/v1/captures/%s", x),
    key = key,
    base = base
  )
  if (res$status != 200L) {
    stop(.bl_arc_why(res, sprintf("capture %s", x)), call. = FALSE)
  }
  one <- function(v) is.character(v) && length(v) == 1L && !is.na(v)
  if (!is.list(res$json) || !one(res$json$url) || !one(res$json$sha256)) {
    stop(
      sprintf(
        paste0(
          "capture %s: %s answered HTTP 200 with something that is no ",
          "capture record (a sign-in page or a proxy's error page looks ",
          "like this)"
        ),
        x,
        .bl_arc_host(base)
      ),
      call. = FALSE
    )
  }
  list(
    id = x,
    url = res$json$url,
    ts = res$json$ts,
    sha = res$json$sha256
  )
}

#' The capture of a URL that arcget() picks.
#' @param x The URL.
#' @param at,sha256 As for arcget() (`sha256` checked).
#' @return As for `.bl_arc_capture()`.
#' @noRd
.bl_arc_by_url <- function(x, at, sha256) {
  found <- arcfind(x)
  if (!nrow(found)) {
    stop(sprintf("%s has no capture of %s", .bl_arc_host(), x), call. = FALSE)
  }
  i <- nrow(found)
  if (!is.null(at)) {
    at <- .rmbl_string1(as.character(at), "at")
    if (!grepl("^[0-9]{4,14}$", at)) {
      stop(
        "`at` must be 4 to 14 digits of a UTC time, YYYYMMDDhhmmss",
        call. = FALSE
      )
    }
    # a partial time is its first moment: 2025 is 2025-01-01 00:00:00
    at <- paste0(at, substr("20000101000000", nchar(at) + 1L, 14L))
    want <- as.POSIXct(at, format = "%Y%m%d%H%M%S", tz = "UTC")
    i <- which.min(abs(as.numeric(found$captured) - as.numeric(want)))
  }
  if (!is.null(sha256)) {
    if (!any(found$sha256 == sha256)) {
      stop(
        sprintf(
          "no capture of %s has SHA-256 %s; the archive holds %s",
          x,
          sha256,
          toString(unique(found$sha256))
        ),
        call. = FALSE
      )
    }
    i <- utils::tail(which(found$sha256 == sha256), 1L)
  }
  if (is.na(found$capture_id[i]) || is.na(found$sha256[i])) {
    stop(
      sprintf(
        paste0(
          "%s lists a capture of %s without a capture id or a SHA-256, so ",
          "its bytes could not be checked: nothing was fetched"
        ),
        .bl_arc_host(),
        x
      ),
      call. = FALSE
    )
  }
  list(
    id = found$capture_id[i],
    url = found$url[i],
    ts = format(found$captured[i], "%Y%m%d%H%M%S"),
    sha = found$sha256[i]
  )
}

#' Downloads a capture's bytes to `dest`, checking them against its hash
#' before anything is written there.
#' @param cap The capture, as from `.bl_arc_capture()`.
#' @param dest The destination path.
#' @param key,base The archive key and base URL.
#' @param tmout Seconds.
#' @return The SHA-256 of the bytes written.
#' @noRd
.bl_arc_fetch <- function(cap, dest, key, base, tmout) {
  tmp <- paste0(dest, ".part")
  on.exit(unlink(tmp), add = TRUE)
  res <- .bl_arc_req(
    "GET",
    sprintf("/b/%s", cap$sha %||% ""),
    key = key,
    base = base,
    timeout = tmout
  )
  if (res$status != 200L) {
    stop(
      .bl_arc_why(res, sprintf("the bytes of capture %s", cap$id)),
      call. = FALSE
    )
  }
  writeBin(res$body, tmp)
  got <- sha256file(tmp)
  if (!identical(got, cap$sha)) {
    stop(
      sprintf(
        paste0(
          "the bytes received hash to %s, not to the capture's %s: ",
          "nothing was written"
        ),
        got,
        cap$sha
      ),
      call. = FALSE
    )
  }
  if (!.bl_move(tmp, dest)) {
    stop(sprintf("cannot write %s", dest), call. = FALSE)
  }
  got
}

#' Each capture's address and replay link, for the printed list.
#' @param d The captures shown.
#' @return Lines: capture id, then the address and the replay link indented.
#' @noRd
.bl_arc_find_links <- function(d) {
  if (!"url" %in% names(d)) {
    return(NULL)
  }
  rp <- if ("replay" %in% names(d)) d$replay else rep(NA_character_, nrow(d))
  unlist(lapply(seq_len(nrow(d)), function(i) {
    c(
      paste0(d$capture_id[i], ":"),
      paste0("  address  ", d$url[i]),
      if (!is.na(rp[i]) && nzchar(rp[i])) paste0("  replay   ", rp[i])
    )
  }))
}
