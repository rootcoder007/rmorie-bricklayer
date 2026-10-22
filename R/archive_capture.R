# SPDX-License-Identifier: AGPL-3.0-or-later
#
# When a server refuses the Internet Archive's crawler (Statistics Canada does), Save Page Now cannot
# capture its files. arccap() captures them from here instead: the bytes as served, their
# SHA-256, a manifest with an RFC 3161 timestamp, and, with archive.org keys, an archive.org item that
# holds them all publicly. fetchvrf() then serves the same bytes from that item.

# The transport seams, one place for tests to stand in a server.
#' Posts a timestamp query to a time-stamping authority.
#' @param url The authority's URL.
#' @param body The query, as raw DER.
#' @param timeout Seconds before the request gives up.
#' @return The reply from the native transport.
#' @noRd
.bl_tsa_post <- function(url, body, timeout) {
  .bl_net(url, .Call(C_rmbl_http_post, url, body, "application/timestamp-query", as.integer(timeout),
                     character(), .bl_loopback_url(url)))
}
#' Uploads a file to the Internet Archive with a PUT request.
#' @param url The item's URL.
#' @param path The file to upload.
#' @param content_type The file's media type.
#' @param headers Further request headers.
#' @param timeout Seconds before the request gives up.
#' @return The reply from the native transport.
#' @noRd
.bl_ia_put <- function(url, path, content_type, headers, timeout) {
  .bl_net(url, .Call(C_rmbl_http_put, url, path, content_type, as.integer(timeout), headers,
                     .bl_loopback_url(url)))
}
#' Returns the Internet Archive's S3 endpoint.
#' @return One URL.
#' @noRd
.bl_ia_s3 <- function() "https://s3.us.archive.org"

#' Encodes one DER element.
#'
#' DER: a tag, its length, its content
#' @param tag The tag byte.
#' @param content The content, as raw.
#' @return A raw vector.
#' @noRd
.bl_der <- function(tag, content) {
  n <- length(content)
  len <- if (n < 128L) as.raw(n) else if (n < 256L) as.raw(c(0x81, n)) else as.raw(c(0x82, n %/% 256L, n %% 256L))
  c(as.raw(tag), len, content)
}

#' An RFC 3161 TimeStampReq for a SHA-256 digest (raw, 32 bytes), with a nonce and certReq TRUE
#' @param digest The SHA-256 digest, 32 raw bytes.
#' @param nonce The nonce, as raw.
#' @return The request, as raw DER.
#' @noRd
.bl_tsq <- function(digest, nonce) {
  sha256_oid <- as.raw(c(0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01))
  alg <- .bl_der(0x30, c(sha256_oid, as.raw(c(0x05, 0x00))))
  imprint <- .bl_der(0x30, c(alg, .bl_der(0x04, digest)))
  .bl_der(0x30, c(.bl_der(0x02, as.raw(1L)), imprint, .bl_der(0x02, nonce), as.raw(c(0x01, 0x01, 0xff))))
}

#' Turns hex text into raw bytes.
#' @param h One string of hex digits.
#' @return A raw vector.
#' @noRd
.bl_hex_raw <- function(h) as.raw(strtoi(substring(h, seq(1L, nchar(h), 2L), seq(2L, nchar(h), 2L)), 16L))

#' Makes a file name from a URL.
#'
#' A file name from a URL: its last path segment (or \code{"index"}), safe characters
#' only, and the start of
#' the URL's own digest when the URL has a query (tv.action?pid=... pages share one name otherwise)
#' @param u The URL.
#' @return One string.
#' @noRd
.bl_capture_name <- function(u) {
  path <- sub("[?#].*$", "", sub("^https?://[^/]+", "", u))
  base <- utils::tail(strsplit(path, "/", fixed = TRUE)[[1L]], 1L)
  if (!length(base) || !nzchar(base)) base <- "index"
  base <- gsub("[^A-Za-z0-9._-]", "_", base)
  if (grepl("?", u, fixed = TRUE)) {
    h <- substr(csha256(charToRaw(u)), 1L, 10L)
    base <- if (grepl("\\.", base)) sub("(\\.[^.]*)$", paste0("_", h, "\\1"), base) else paste0(base, "_", h)
  }
  base
}

#' Capture files the Internet Archive cannot reach, and publish them as an archive.org
#' item
#'
#' Downloads each URL from here, records its SHA-256, size and time in a manifest,
#' timestamps the manifest with an RFC 3161 time-stamping authority, and, with
#' archive.org keys, uploads the files, the manifest and its timestamp as one public
#' archive.org item. The item is the mirror that \code{\link{fetchvrf}} falls
#' back to, and the timestamp shows that these were the bytes on that date.
#'
#' @details Some servers refuse the Internet Archive's crawler while serving everyone
#' else: Save Page Now then reports that the target \dQuote{cannot find} the page, or
#' \dQuote{blocks
#' access} to it, although the page is there. Those URLs cannot be put in the Wayback
#' Machine, but they can be captured by anyone who can reach them, and the capture can
#' be published. Pass a \code{\link{wbsave}} result as \code{urls} to capture
#' just the URLs it failed on with such a refusal.
#'
#' The manifest (\code{manifest.json}) lists, for each URL, the file, its SHA-256, its
#' size and the time it was fetched. The timestamp (\code{manifest.tsr}) is the
#' authority's signed statement that the manifest's SHA-256 existed at its time;
#' \code{\link{tsvrf}} checks it, as does \code{openssl ts -verify}. Each
#' file's digest in the manifest ties the file to that time.
#'
#' The upload uses the Internet Archive's S3-like API: each file is sent
#' with a PUT, streamed from disk, to\cr
#' \code{https://s3.us.archive.org/<item>/<file>}.\cr The first
#' request creates the item with the metadata given. The keys are the same as
#' for \code{\link{wbsave}}, so they are read from \code{IA_S3_ACCESS_KEY} and
#' \code{IA_S3_SECRET_KEY}, or their \code{_FILE} twins. They travel only in the
#' \code{authorization} header and
#' are never written or printed. Publish only what the source's licence lets you
#' redistribute.
#'
#' @param urls URLs to capture, or a \code{\link{wbsave}} result (its refused
#'   URLs are taken).
#' @param dir A folder for the files and the manifest (created if needed).
#' @param item Optional archive.org item identifier (5 to 100 letters, digits, dots,
#'   hyphens, underscores) to upload to; \code{NULL} (default) captures without
#'   uploading.
#' @param meta Named metadata for a new item (\code{title}, \code{creator},
#'   \code{licenseurl}, \code{description}, \code{subject}, ...); \code{mediatype}
#'   defaults to \code{"data"}.
#' @param tsa The time-stamping authority. \code{"https://freetsa.org/tsr"} is the
#'   default; \code{NULL} means no timestamp.
#' @param ak,sk archive.org keys; default from the environment as
#'   \code{\link{wbsave}} reads them.
#' @param tmout Seconds allowed for each download and each upload (default 600).
#' @param upload Where else to keep the captures: \code{"rmorie"} (archive.rmorie.com, from this
#'   connection, with your key; see \code{\link{dlogin}}), \code{"wayback"} (ask the Wayback Machine to
#'   save the same addresses, with archive.org keys as for \code{\link{wbsave}}), both, or \code{NULL}
#'   (default: only the local folder and, with \code{item}, archive.org).
#' @param reason Why the files are kept, one sentence of 20 characters or more; needed with
#'   \code{upload = "rmorie"}, and written into each WARC file.
#' @param visibility \code{"public"} (default: listed in the archive's search; anyone can download and
#'   check it) or \code{"private"} (only you, with your key).
#' @param warc Write each capture as a WARC/1.1 file with a CDXJ index (\code{dir/archive/},
#'   \code{dir/indexes/index.cdxj}), the layout pywb and warcio read and \code{\link{fetchvrf}} falls
#'   back to (default \code{TRUE}).
#' @return A data frame of class \code{rmbl_archive_capture}, one row per URL:
#'   \code{url}, \code{file}, \code{sha256}, \code{bytes}, \code{fetched_utc},
#'   \code{status} (\code{"captured"}, \code{"uploaded"}, \code{"archived"} or \code{"failed: ..."}),
#'   \code{mirror} (the archive.org download address, for
#'   \code{\link{fetchvrf}}), \code{warc} (the local WARC file), \code{capture_id} and \code{archive}
#'   (its page at archive.rmorie.com) and \code{wayback} (the Wayback Machine's answer);
#'   attributes \code{manifest}, \code{timestamp} (a
#'   \code{\link{tsvrf}} result, or \code{NULL}) and \code{item}.
#' @references Adams C, Cain P, Pinkas D, Zuccherato R (2001). Internet X.509 Public
#'   Key Infrastructure Time-Stamp Protocol (TSP). RFC 3161. \doi{10.17487/RFC3161}
#'
#' Internet Archive. ias3: the Internet Archive's S3-like API.
#' archive.org/developers/ias3.html
#' @seealso \code{\link{fetchvrf}}, \code{\link{wbsave}},
#'   \code{\link{tsvrf}}.
#' @examplesIf interactive()
#' # save from your own connection to archive.rmorie.com and the Wayback Machine at once
#' src <- "https://www150.statcan.gc.ca/n1/tbl/csv/35100177-eng.zip"
#' cap <- arccap(src, file.path(tempdir(), "cap"),
#'               upload = c("rmorie", "wayback"), reason = "Custody table cited in chapter 3")
#' cap$archive
#' w <- wbsave(urls)
#' lic <- "https://www.statcan.gc.ca/en/terms-conditions/open-licence"
#' meta <- list(title = "Statistics Canada tables (captures)",
#'              creator = "Statistics Canada", licenseurl = lic)
#' cap <- arccap(w, file.path(tempdir(), "capture"),
#'                        item = "my-statcan-tables-2026", meta = meta)
#' fetchvrf(cap$url[1], tempfile(), sha256 = cap$sha256[1],
#'                mirrors = cap$mirror[1])
#' @export
arccap <- function(urls, dir, item = NULL, meta = list(), tsa = "https://freetsa.org/tsr",
                            ak = NULL, sk = NULL, tmout = 600L, upload = NULL, reason = NULL,
                            visibility = c("public", "private"), warc = TRUE) {
  visibility <- match.arg(visibility)
  if (!is.null(upload)) {
    if (!is.character(upload) || anyNA(upload) || !length(upload) || !all(upload %in% c("rmorie", "wayback"))) {
      stop('`upload` must be "rmorie", "wayback", both, or NULL', call. = FALSE)
    }
    upload <- unique(upload)
  }
  if ("rmorie" %in% upload) {
    reason <- if (is.null(reason)) "" else .rmbl_string1(reason, "reason")
    if (nchar(trimws(reason)) < 20L) {
      stop("`reason` is needed with upload = \"rmorie\": one sentence (20 characters or more) on why you keep the files",
           call. = FALSE)
    }
  }
  if (!is.logical(warc) || length(warc) != 1L || is.na(warc)) stop("`warc` must be TRUE or FALSE", call. = FALSE)
  if (inherits(urls, "rmbl_wayback_save")) {
    refused <- urls$status == "failed" &
      grepl("cannot find|blocks access|HTTP status=40[134]", ifelse(is.na(urls$message), "", urls$message))
    urls <- urls$url[refused]
  }
  if (!is.character(urls) || anyNA(urls) || !length(urls)) stop("`urls` must be URLs", call. = FALSE)
  urls <- unique(urls)
  dir <- .rmbl_string1(dir, "dir")
  if (!is.null(item) && (!is.character(item) || length(item) != 1L ||
                         !grepl("^[A-Za-z0-9][A-Za-z0-9._-]{4,99}$", item))) {
    stop("`item` must be 5 to 100 letters, digits, dots, hyphens or underscores", call. = FALSE)
  }
  if (!is.list(meta) || (length(meta) && is.null(names(meta)))) {
    stop("`meta` must be a named list", call. = FALSE)
  }
  if (!is.null(tsa)) tsa <- .rmbl_string1(tsa, "tsa")
  tmout <- .rmbl_scalar(tmout, "tmout", 1, 86400, integer = TRUE)
  .ak <- .sk <- ""
  if (!is.null(item)) {
    .ak <- if (is.null(ak)) .bl_ia_key("IA_S3_ACCESS_KEY") else ak
    .sk <- if (is.null(sk)) .bl_ia_key("IA_S3_SECRET_KEY") else sk
    if (!nzchar(.ak) || !nzchar(.sk) || grepl("[^A-Za-z0-9]", paste0(.ak, .sk))) {
      stop("archive.org keys are needed to upload: set IA_S3_ACCESS_KEY and IA_S3_SECRET_KEY", call. = FALSE)
    }
  }
  if (!dir.exists(dir) && !dir.create(dir, recursive = TRUE)) stop(sprintf("cannot create %s", dir), call. = FALSE)
  out <- data.frame(url = urls, file = NA_character_, sha256 = NA_character_, bytes = NA_real_,
                    fetched_utc = NA_character_, status = NA_character_, mirror = NA_character_,
                    warc = NA_character_, capture_id = NA_character_, archive = NA_character_,
                    wayback = NA_character_, stringsAsFactors = FALSE)
  used <- character()
  for (i in seq_along(urls)) {
    f <- .bl_capture_name(urls[[i]])
    if (f %in% used) f <- sprintf("%03d_%s", i, f)
    path <- file.path(dir, f)
    got <- tryCatch(blfetch(urls[[i]], path, wb = urls[[i]], tmout = tmout),
                    error = function(e) structure(conditionMessage(e), class = "rmbl_fail"))
    if (inherits(got, "rmbl_fail")) {
      out$status[i] <- paste("failed:", got)
      next
    }
    used <- c(used, f)
    out$file[i] <- f
    out$sha256[i] <- sha256file(path)
    out$bytes[i] <- file.size(path)
    out$fetched_utc[i] <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    out$status[i] <- "captured"
  }
  ok <- out$status == "captured"
  if (!any(ok)) stop("no URL could be fetched from here", call. = FALSE)
  man <- list(created_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
              item = item %||% NA_character_,
              files = lapply(which(ok), function(i) {
                as.list(out[i, c("url", "file", "sha256", "bytes", "fetched_utc")])
              }))
  mpath <- file.path(dir, "manifest.json")
  writeLines(tojs(man), mpath)
  ts <- NULL
  if (!is.null(tsa)) {
    nonce <- as.raw(c(0x01, sample.int(256L, 7L, replace = TRUE) - 1L))
    res <- .bl_tsa_post(tsa, .bl_tsq(.bl_hex_raw(sha256file(mpath)), nonce), 60L)
    if (identical(res$status, 200L) && length(res$body)) {
      writeBin(res$body, file.path(dir, "manifest.tsr"))
      ts <- tsvrf(res$body, mpath)
    } else {
      warning(sprintf("the time-stamping authority did not answer (%s): the manifest has no timestamp",
                      if (nzchar(res$error)) res$error else paste("HTTP", res$status)), call. = FALSE)
    }
  }
  if (!is.null(item)) {
    .meta <- utils::modifyList(list(mediatype = "data"), meta)
    meta_h <- sprintf("x-archive-meta-%s:%s", names(.meta), gsub("[\r\n]", " ", vapply(.meta, as.character, "")))
    files <- c("manifest.json", if (file.exists(file.path(dir, "manifest.tsr"))) "manifest.tsr", out$file[ok])
    for (k in seq_along(files)) {
      h <- c(sprintf("authorization: LOW %s:%s", .ak, .sk), "x-archive-queue-derive:0",
             if (k == 1L) c("x-amz-auto-make-bucket:1", meta_h))
      ctype <- if (grepl("\\.json$", files[k])) "application/json" else "application/octet-stream"
      res <- .bl_ia_put(sprintf("%s/%s/%s", .bl_ia_s3(), item, files[k]), file.path(dir, files[k]), ctype, h,
                        tmout)
      good <- isTRUE(res$status >= 200L && res$status < 300L)
      j <- match(files[k], out$file)
      if (!is.na(j)) {
        out$status[j] <- if (good) "uploaded" else paste("failed: upload answered", res$status, res$error)
        if (good) out$mirror[j] <- sprintf("https://archive.org/download/%s/%s", item, files[k])
      } else if (!good) {
        stop(sprintf("archive.org refused %s (HTTP %s %s): nothing more was sent", files[k], res$status, res$error),
             call. = FALSE)
      }
    }
  }
  ok <- out$status %in% c("captured", "uploaded")
  # WARC/1.1 files and a CDXJ index: a pywb collection, and fetchvrf()'s last fallback
  if (isTRUE(warc) && any(ok)) {
    dir.create(file.path(dir, "archive"), showWarnings = FALSE)
    dir.create(file.path(dir, "indexes"), showWarnings = FALSE)
    lines <- character()
    for (i in which(ok)) {
      t <- as.POSIXct(out$fetched_utc[i], format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      id <- paste0(format(t, "%Y%m%d%H%M%S", tz = "UTC"), "-", substr(out$sha256[i], 1L, 8L))
      wf <- file.path(dir, "archive", paste0(id, ".warc"))
      lines <- c(lines, .bl_warc_write(wf, out$url[i], file.path(dir, out$file[i]), t, id, mime = .bl_arc_mime(out$file[i]),
                                       meta = if (!is.null(reason) && nzchar(reason)) c(reason = gsub("[\r\n]", " ", reason)) else character()))
      out$warc[i] <- wf
    }
    .bl_cdxj_add(file.path(dir, "indexes", "index.cdxj"), lines)
  }
  if ("rmorie" %in% upload && any(ok)) {
    base <- .bl_arc_base()
    key <- .bl_arc_key(base)
    if (is.null(key)) {
      stop(sprintf("archive.rmorie.com needs your key: run dlogin() (or `%s login`) once; the files are kept in %s",
                   .bl_prog(), dir), call. = FALSE)
    }
    for (i in which(ok)) {
      r <- tryCatch(.bl_arc_upload(file.path(dir, out$file[i]), out$url[i],
                                   as.POSIXct(out$fetched_utc[i], format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
                                   reason, visibility, .bl_arc_mime(out$file[i]), base, key, tmout),
                    error = function(e) .bl_unless_interrupted(e, structure(conditionMessage(e), class = "rmbl_fail")))
      if (inherits(r, "rmbl_fail")) {
        out$status[i] <- paste("failed:", r, "(the file is kept locally)")
      } else {
        out$capture_id[i] <- r$capture_id
        out$archive[i] <- r$capture
        if (out$status[i] == "captured") out$status[i] <- "archived"
      }
    }
  }
  if ("wayback" %in% upload && any(ok)) {
    w <- tryCatch(wbsave(out$url[ok], ak = ak, sk = sk, quiet = TRUE),
                  error = function(e) .bl_unless_interrupted(e, structure(conditionMessage(e), class = "rmbl_fail")))
    if (inherits(w, "rmbl_fail")) {
      out$wayback[ok] <- paste("not asked:", w)
    } else {
      wd <- as.data.frame(unclass(w))
      j <- match(out$url[ok], wd$url)
      out$wayback[ok] <- ifelse(is.na(j), NA_character_,
                                ifelse(is.na(wd$timestamp[j]), wd$status[j], paste(wd$status[j], wd$timestamp[j])))
    }
  }
  attr(out, "manifest") <- mpath
  attr(out, "timestamp") <- ts
  attr(out, "item") <- item
  class(out) <- c("rmbl_archive_capture", "data.frame")
  out
}

#' @export
print.rmbl_archive_capture <- function(x, ...) {
  d <- as.data.frame(x)
  n <- table(sub(":.*$", "", d$status))
  cat(sprintf("Captured %d of %d URLs%s\n", sum(d$status %in% c("captured", "uploaded", "archived")), nrow(d),
              if (!is.null(attr(x, "item"))) sprintf(" (archive.org item %s: %d uploaded)", attr(x, "item"),
                                                     sum(d$status == "uploaded")) else ""))
  ts <- attr(x, "timestamp")
  if (!is.null(ts)) {
    ck <- ts$checks
    core <- all(ck$ok[ck$check %in% c("message_imprint", "signature")])
    cat(sprintf("Manifest timestamp: %s (%s)\n", format(ts$time, tz = "UTC"),
                if (isTRUE(ts$ok)) "verified, with the authority's chain" else if (core)
                  "imprint and signature verified; give tsvrf() a trust anchor to check the chain"
                else "NOT verified"))
  }
  if (any(!is.na(d$archive))) cat(sprintf("archive.rmorie.com: %d saved\n", sum(!is.na(d$archive))))
  print(utils::head(d[intersect(c("file", "bytes", "status"), names(d))], 10L), row.names = FALSE)
  if (any(names(n) == "failed")) cat(sprintf("%d failed: see the status column\n", n[["failed"]]))
  invisible(x)
}
