# SPDX-License-Identifier: AGPL-3.0-or-later
#
# archive.rmorie.com from R: find saved copies of an address, fetch one's exact
# bytes, and upload a capture made from your own connection. The same key as
# data.rmorie.com (rmbl login, dlogin()) signs the requests. A self-hosted
# archive is named by MORIE_ARCHIVE_URL and given its own key in
# MORIE_ARCHIVE_KEY: the stored rmorie key goes only to archive.rmorie.com.

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
    utils::URLencode(audience, reserved = TRUE)
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

#' One request to the archive.
#' @param method "GET", "POST" or "PUT".
#' @param path The path on the archive, with any query.
#' @param body For POST, a list sent as JSON.
#' @param file For PUT, the file to send.
#' @param ctype For PUT, the file's media type.
#' @param key The key, or NULL.
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
    ),
    stop("unknown method", call. = FALSE)
  )
  json <- if (length(res$body)) {
    tryCatch(
      .rmbl_json_text(res$body, simplifyVector = FALSE),
      error = function(e) NULL
    )
  }
  list(
    status = as.integer(res$status %||% -1L),
    json = json,
    body = res$body,
    error = res$error %||% ""
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
    return(sprintf("%s: archive.rmorie.com did not answer (%s)", what, why))
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
  stamp <- function(x, nm) {
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
  base <- .bl_arc_base()
  q <- paste0(
    "/cdx/search/cdx?output=json&limit=",
    limit,
    "&url=",
    utils::URLencode(url, reserved = TRUE),
    if (!is.null(from)) paste0("&from=", stamp(from, "from")),
    if (!is.null(to)) paste0("&to=", stamp(to, "to"))
  )
  res <- .bl_arc_req(
    "GET",
    q,
    key = .bl_arc_key(base),
    base = base,
    timeout = 60L
  )
  if (res$status != 200L || !is.list(res$json)) {
    stop(.bl_arc_why(res, "finding captures"), call. = FALSE)
  }
  rows <- res$json[-1L]
  col <- function(k) {
    vapply(rows, function(r) as.character(r[[k]] %||% NA_character_), "")
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
    paste0(base, "/capture/", out$capture_id)
  } else {
    character()
  }
  out$replay <- if (nrow(out)) {
    paste0(base, "/c/", ts, "id_/", out$url)
  } else {
    character()
  }
  attr(out, "archive") <- base
  class(out) <- c("rmbl_archive_find", "data.frame")
  out
}

#' @export
print.rmbl_archive_find <- function(x, ...) {
  d <- as.data.frame(unclass(x))
  if (!nrow(d)) {
    cat(sprintf("No capture in %s\n", attr(x, "archive")))
    return(invisible(x))
  }
  cat(sprintf(
    "%d capture%s in %s, %d distinct cop%s of the bytes\n",
    nrow(d),
    if (nrow(d) == 1L) "" else "s",
    attr(x, "archive"),
    length(unique(d$sha256)),
    if (length(unique(d$sha256)) == 1L) "y" else "ies"
  ))
  d$sha256 <- paste0(substr(d$sha256, 1L, 12L), "...")
  d$captured <- format(d$captured, "%Y-%m-%d %H:%M")
  print(
    utils::head(
      d[c("captured", "status", "mime", "bytes", "sha256", "capture_id")],
      20L
    ),
    row.names = FALSE
  )
  if (nrow(d) > 20L) {
    cat(sprintf("... and %d more\n", nrow(d) - 20L))
  }
  invisible(x)
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
#' @param dest The file to write.
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
  dest <- .rmbl_string1(dest, "dest")
  tmout <- .rmbl_scalar(tmout, "tmout", 1, 86400, integer = TRUE)
  if (!is.null(sha256)) {
    sha256 <- tolower(.rmbl_string1(sha256, "sha256"))
    if (!grepl("^[0-9a-f]{64}$", sha256)) {
      stop("`sha256` must be 64 hexadecimal characters", call. = FALSE)
    }
  }
  base <- .bl_arc_base()
  key <- .bl_arc_key(base)
  if (grepl("^[0-9]{14}-[0-9a-f]{8}$", x)) {
    res <- .bl_arc_req(
      "GET",
      paste0("/v1/captures/", x),
      key = key,
      base = base
    )
    if (res$status != 200L) {
      stop(.bl_arc_why(res, sprintf("capture %s", x)), call. = FALSE)
    }
    cap <- list(
      id = x,
      url = res$json$url,
      ts = res$json$ts,
      sha = res$json$sha256
    )
  } else {
    found <- arcfind(x)
    if (!nrow(found)) {
      stop(sprintf("archive.rmorie.com has no capture of %s", x), call. = FALSE)
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
            paste(unique(found$sha256), collapse = ", ")
          ),
          call. = FALSE
        )
      }
      i <- utils::tail(which(found$sha256 == sha256), 1L)
    }
    cap <- list(
      id = found$capture_id[i],
      url = found$url[i],
      ts = format(found$captured[i], "%Y%m%d%H%M%S"),
      sha = found$sha256[i]
    )
  }
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
  tmp <- paste0(dest, ".part")
  on.exit(unlink(tmp), add = TRUE)
  res <- .bl_arc_req(
    "GET",
    paste0("/b/", cap$sha),
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
  invisible(structure(
    dest,
    capture_id = cap$id,
    url = cap$url,
    sha256 = got,
    captured = as.POSIXct(cap$ts, format = "%Y%m%d%H%M%S", tz = "UTC")
  ))
}

#' Uploads one captured file to the archive and records the capture.
#' @param path The file.
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
  have <- .bl_arc_req("GET", paste0("/v1/blob/", sha), key = key, base = base)
  if (have$status == 404L) {
    put <- .bl_arc_req(
      "PUT",
      paste0("/v1/blob/", sha),
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
      software = paste0(
        "rmoriebricklayer/",
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
