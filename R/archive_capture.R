# SPDX-License-Identifier: AGPL-3.0-or-later
#
# When a server refuses the Internet Archive's crawler (Statistics Canada does),
# Save Page Now cannot capture its files. arccap() captures them from here
# instead: the bytes as served, their SHA-256, a manifest with an RFC 3161
# timestamp, and, with archive.org keys, an archive.org item that holds them all
# publicly. fetchvrf() then serves the same bytes from that item.

#' Capture files the Internet Archive cannot reach, and publish them as an
#' archive.org item
#'
#' Downloads each URL from here, records its SHA-256, size and time in a
#' manifest, timestamps the manifest with an RFC 3161 time-stamping authority,
#' and, with archive.org keys, uploads the files, the manifest and its timestamp
#' as one public archive.org item. The item is the mirror that
#' \code{\link{fetchvrf}} falls back to, and the timestamp shows that these were
#' the bytes on that date.
#'
#' @details Some servers refuse the Internet Archive's crawler while serving
#' everyone else: Save Page Now then reports that the target \dQuote{cannot
#' find} the page, or \dQuote{blocks access} to it, although the page is there.
#' Those URLs cannot be put in the Wayback Machine, but they can be captured by
#' anyone who can reach them, and the capture can be published. Pass a
#' \code{\link{wbsave}} result as \code{urls} to capture just the URLs it failed
#' on with such a refusal.
#'
#' The manifest (\code{manifest.json}) lists, for each URL, the file, its
#' SHA-256, its size and the time it was fetched. The timestamp
#' (\code{manifest.tsr}) is the authority's signed statement that the manifest's
#' SHA-256 existed at its time; \code{\link{tsvrf}} checks it, as does
#' \code{openssl ts -verify}. Each file's digest in the manifest ties the file
#' to that time.
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
#' @param item Optional archive.org item identifier (5 to 100 letters, digits,
#'   dots, hyphens, underscores) to upload to; \code{NULL} (default) captures
#'   without uploading.
#' @param meta Named metadata for a new item (\code{title}, \code{creator},
#'   \code{licenseurl}, \code{description}, \code{subject}, ...);
#'   \code{mediatype} defaults to \code{"data"}.
#' @param tsa The time-stamping authority. \code{"https://freetsa.org/tsr"} is
#'   the default; \code{NULL} means no timestamp.
#' @param ak,sk archive.org keys; default from the environment as
#'   \code{\link{wbsave}} reads them.
#' @param tmout Seconds allowed for each download and each upload (default 600).
#' @param upload Where else to keep the captures: \code{"rmorie"}
#'   (archive.rmorie.com, from this connection, with your key; see
#'   \code{\link{dlogin}}), \code{"wayback"} (ask the Wayback Machine to save
#'   the same addresses, with archive.org keys as for \code{\link{wbsave}}),
#'   both, or \code{NULL} (default: only the local folder and, with \code{item},
#'   archive.org).
#' @param reason Why the files are kept, one sentence of 20 characters or more;
#'   needed with \code{upload = "rmorie"}, and written into each WARC file.
#' @param visibility \code{"public"} (default: listed in the archive's search;
#'   anyone can download and check it) or \code{"private"} (only you, with your
#'   key).
#' @param warc Write each capture as a WARC/1.1 file with a CDXJ index
#'   (\code{dir/archive/}, \code{dir/indexes/index.cdxj}), the layout pywb and
#'   warcio read and \code{\link{fetchvrf}} falls back to (default \code{TRUE}).
#' @return A data frame of class \code{rmbl_archive_capture}, one row per URL:
#'   \code{url}, \code{file}, \code{sha256}, \code{bytes}, \code{fetched_utc},
#'   \code{status} (\code{"captured"}, \code{"uploaded"}, \code{"archived"} or
#'   \code{"failed: ..."}), \code{mirror} (the archive.org download address, for
#'   \code{\link{fetchvrf}}), \code{warc} (the local WARC file),
#'   \code{capture_id} and \code{archive} (its page at archive.rmorie.com) and
#'   \code{wayback} (the Wayback Machine's answer); attributes \code{manifest},
#'   \code{timestamp} (a \code{\link{tsvrf}} result, or \code{NULL}) and
#'   \code{item}.
#' @references Adams C, Cain P, Pinkas D, Zuccherato R (2001). Internet X.509
#'   Public Key Infrastructure Time-Stamp Protocol (TSP). RFC 3161.
#'   \doi{10.17487/RFC3161}
#'
#' Internet Archive. ias3: the Internet Archive's S3-like API.
#' archive.org/developers/ias3.html
#' @seealso \code{\link{fetchvrf}}, \code{\link{wbsave}},
#'   \code{\link{tsvrf}}.
#' @examplesIf interactive()
#' # save from your own connection to archive.rmorie.com and the Wayback Machine
#' # at once
#' src <- "https://www150.statcan.gc.ca/n1/tbl/csv/35100177-eng.zip"
#' cap <- arccap(
#'   src,
#'   file.path(tempdir(), "cap"),
#'   upload = c("rmorie", "wayback"),
#'   reason = "Custody table cited in chapter 3"
#' )
#' cap$archive
#' w <- wbsave(urls)
#' lic <- "https://www.statcan.gc.ca/en/terms-conditions/open-licence"
#' meta <- list(
#'   title = "Statistics Canada tables (captures)",
#'   creator = "Statistics Canada",
#'   licenseurl = lic
#' )
#' cap <- arccap(
#'   w,
#'   file.path(tempdir(), "capture"),
#'   item = "my-statcan-tables-2026",
#'   meta = meta
#' )
#' fetchvrf(
#'   cap$url[1],
#'   tempfile(),
#'   sha256 = cap$sha256[1],
#'   mirrors = cap$mirror[1]
#' )
#' @export
arccap <- function(
  urls,
  dir,
  item = NULL,
  meta = list(),
  tsa = "https://freetsa.org/tsr",
  ak = NULL,
  sk = NULL,
  tmout = 600L,
  upload = NULL,
  reason = NULL,
  visibility = c("public", "private"),
  warc = TRUE
) {
  visibility <- .rmbl_arg(visibility)
  up <- .bl_cap_upload_arg(upload, reason)
  upload <- up$upload
  reason <- up$reason
  a <- .bl_cap_args(warc, urls, dir, item, meta, tsa, tmout)
  urls <- a$urls
  dir <- a$dir
  tsa <- a$tsa
  tmout <- a$tmout
  keys <- .bl_cap_ia_keys(item, ak, sk)
  if (!dir.exists(dir) && !dir.create(dir, recursive = TRUE)) {
    stop(sprintf("cannot create %s", dir), call. = FALSE)
  }
  out <- .bl_cap_fetch(urls, dir, tmout)
  ok <- out$status == "captured"
  if (!any(ok)) {
    stop("no URL could be fetched from here", call. = FALSE)
  }
  mpath <- .bl_cap_manifest(out, ok, item, dir)
  ts <- if (!is.null(tsa)) .bl_cap_timestamp(tsa, mpath, dir)
  if (!is.null(item)) {
    out <- .bl_cap_ia_upload(out, ok, item, meta, dir, keys, tmout)
  }
  ok <- out$status %in% c("captured", "uploaded")
  if (any(ok)) {
    out <- .bl_cap_publish(
      out,
      ok,
      dir,
      warc,
      upload,
      reason,
      visibility,
      tmout
    )
    if ("wayback" %in% upload) {
      out <- .bl_cap_wayback(out, ok, ak, sk)
    }
  }
  attr(out, "manifest") <- mpath
  attr(out, "timestamp") <- ts
  attr(out, "item") <- item
  class(out) <- c("rmbl_archive_capture", "data.frame")
  out
}

#' @export
format.rmbl_archive_capture <- function(x, ...) {
  d <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  if (!"status" %in% names(d)) {
    return(utils::capture.output(print(d)))
  }
  st <- sub(":.*$", "", d$status)
  item <- attr(x, "item")
  .rmbl_stat_block(
    "Archive capture",
    facts = list(
      Captured = sprintf(
        "%d of %d URLs",
        sum(d$status %in% c("captured", "uploaded", "archived")),
        nrow(d)
      ),
      `archive.org item` = if (!is.null(item)) {
        sprintf("%s: %d uploaded", item, sum(d$status == "uploaded"))
      },
      `archive.rmorie.com` = if (!all(is.na(d$archive))) {
        sprintf("%d saved", sum(!is.na(d$archive)))
      },
      Manifest = attr(x, "manifest"),
      `Manifest timestamp` = .bl_cap_ts_text(attr(x, "timestamp"))
    ),
    table = utils::head(
      d[intersect(c("file", "bytes", "status"), names(d))],
      10L
    ),
    reading = paste(
      "Each file is kept with its SHA-256, so a later copy can be checked",
      "against what was fetched here."
    ),
    notes = c(
      if (nrow(d) > 10L) sprintf("... and %d more", nrow(d) - 10L),
      if (any(st == "failed")) {
        sprintf("%d failed: see the status column", sum(st == "failed"))
      }
    )
  )
}

#' The manifest timestamp of a capture, in words.
#' @param ts A tsvrf() result, or NULL.
#' @return One string, or NULL.
#' @noRd
.bl_cap_ts_text <- function(ts) {
  if (is.null(ts)) {
    return(NULL)
  }
  # the rows must be there and pass: all() of none is TRUE, which printed a
  # junk token as verified (recheck of a8cdaf9)
  core <- .bl_ts_core(ts)
  sprintf(
    "%s (%s)",
    format(ts$time, tz = "UTC"),
    if (isTRUE(ts$ok)) {
      "verified, with the authority's chain"
    } else if (core) {
      paste0(
        "imprint and signature verified; give tsvrf() a trust anchor to ",
        "check the chain"
      )
    } else {
      "NOT verified"
    }
  )
}

#' Whether a tsvrf() result shows a token for these bytes, signed: its
#' structure, imprint, signature and attribute digest rows present and
#' passing, and the nonce row, when there is one.
#' @param ts A tsvrf() result.
#' @return TRUE or FALSE.
#' @noRd
.bl_ts_core <- function(ts) {
  ck <- ts$checks
  need <- c(
    "token_structure", "message_imprint", "signature", "attribute_digest"
  )
  got <- ck$ok[match(need, ck$check)]
  nonce <- ck$ok[ck$check == "nonce"]
  !anyNA(got) && all(got) && (!length(nonce) || all(nonce))
}

#' The checks a tsvrf() result failed, or did not reach, in words.
#' @param ts A tsvrf() result.
#' @return One string.
#' @noRd
.bl_ts_failed <- function(ts) {
  ck <- ts$checks
  need <- c(
    "token_structure", "message_imprint", "signature", "attribute_digest"
  )
  bad <- c(ck$check[!ck$ok], setdiff(need, ck$check))
  bad <- intersect(c("token_parses", need, "signer_id", "nonce"), bad)
  if (length(bad)) paste("failed:", toString(bad)) else "not verified"
}

# The transport seams, one place for tests to stand in a server.
#' Posts a timestamp query to a time-stamping authority.
#' @param url The authority's URL.
#' @param body The query, as raw DER.
#' @param timeout Seconds before the request gives up.
#' @return The reply from the native transport.
#' @noRd
.bl_tsa_post <- function(url, body, timeout) {
  .bl_net(
    url,
    .Call(
      C_rmbl_http_post,
      url,
      body,
      "application/timestamp-query",
      as.integer(timeout),
      character(),
      .bl_loopback_url(url)
    )
  )
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
  .bl_net(
    url,
    .Call(
      C_rmbl_http_put,
      url,
      path,
      content_type,
      as.integer(timeout),
      headers,
      .bl_loopback_url(url)
    )
  )
}

#' Returns the Internet Archive's S3 endpoint.
#' @return One URL.
#' @noRd
.bl_ia_s3 <- function() "https://s3.us.archive.org"

#' Encodes one DER element.
#'
#' DER: a tag, its length, its content
#' @param tag The DER tag byte, such as 0x30 for a SEQUENCE.
#' @param content The content, as raw.
#' @return A raw vector.
#' @noRd
.bl_der <- function(tag, content) {
  n <- length(content)
  len <- if (n < 128L) {
    as.raw(n)
  } else if (n < 256L) {
    as.raw(c(0x81, n))
  } else {
    as.raw(c(0x82, n %/% 256L, n %% 256L))
  }
  c(as.raw(tag), len, content)
}

#' An RFC 3161 TimeStampReq for a SHA-256 digest (raw, 32 bytes), with a nonce
#' and certReq TRUE
#' @param digest The SHA-256 digest, 32 raw bytes.
#' @param nonce The nonce, as raw.
#' @return The request, as raw DER.
#' @noRd
.bl_tsq <- function(digest, nonce) {
  sha256_oid <- as.raw(c(
    0x06,
    0x09,
    0x60,
    0x86,
    0x48,
    0x01,
    0x65,
    0x03,
    0x04,
    0x02,
    0x01
  ))
  alg <- .bl_der(0x30, c(sha256_oid, as.raw(c(0x05, 0x00))))
  imprint <- .bl_der(0x30, c(alg, .bl_der(0x04, digest)))
  .bl_der(
    0x30,
    c(
      .bl_der(0x02, as.raw(1L)),
      imprint,
      .bl_der(0x02, nonce),
      as.raw(c(0x01, 0x01, 0xff))
    )
  )
}

#' Turns hex text into raw bytes.
#' @param h One string of hex digits.
#' @return A raw vector.
#' @noRd
.bl_hex_raw <- function(h) {
  as.raw(strtoi(
    substring(h, seq(1L, nchar(h), 2L), seq(2L, nchar(h), 2L)),
    16L
  ))
}

#' Makes a file name from a URL.
#'
#' A file name from a URL: its last path segment (or \code{"index"}), safe
#' characters only, and the start of the URL's own digest when the URL has a
#' query (tv.action?pid=... pages share one name otherwise)
#' @param u The URL whose last path part becomes the file name.
#' @return One string.
#' @noRd
.bl_capture_name <- function(u) {
  path <- sub("[?#].*$", "", sub("^https?://[^/]+", "", u))
  base <- utils::tail(strsplit(path, "/", fixed = TRUE)[[1L]], 1L)
  if (!length(base) || !nzchar(base)) {
    base <- "index"
  }
  base <- gsub("[^A-Za-z0-9._-]", "_", base)
  # "." and ".." would name the folder or its parent
  if (base %in% c(".", "..")) {
    base <- "index"
  }
  if (grepl("?", u, fixed = TRUE)) {
    h <- substr(csha256(charToRaw(u)), 1L, 10L)
    base <- if (grepl(".", base, fixed = TRUE)) {
      sub("(\\.[^.]*)$", paste0("_", h, "\\1"), base)
    } else {
      paste0(base, "_", h)
    }
  }
  base
}

#' arccap()'s `item` and `meta`, checked.
#' @param item,meta As for arccap().
#' @noRd
.bl_cap_item_meta <- function(item, meta) {
  if (
    !is.null(item) &&
      (!is.character(item) ||
        length(item) != 1L ||
        !grepl("^[A-Za-z0-9][A-Za-z0-9._-]{4,99}$", item))
  ) {
    stop(
      "`item` must be 5 to 100 letters, digits, dots, hyphens or underscores",
      call. = FALSE
    )
  }
  if (!is.list(meta) || (length(meta) && is.null(names(meta)))) {
    stop("`meta` must be a named list", call. = FALSE)
  }
  invisible(NULL)
}

#' arccap()'s `upload`, checked, and the reason archive.rmorie.com needs.
#' @param upload,reason As for arccap().
#' @return A list: upload and reason.
#' @noRd
.bl_cap_upload_arg <- function(upload, reason) {
  if (!is.null(upload)) {
    if (
      !is.character(upload) ||
        anyNA(upload) ||
        !length(upload) ||
        !all(upload %in% c("rmorie", "wayback"))
    ) {
      stop('`upload` must be "rmorie", "wayback", both, or NULL', call. = FALSE)
    }
    upload <- unique(upload)
  }
  if ("rmorie" %in% upload) {
    reason <- if (is.null(reason)) "" else .rmbl_string1(reason, "reason")
    if (nchar(trimws(reason)) < 20L) {
      stop(
        "`reason` is needed with upload = \"rmorie\": ",
        "one sentence (20 characters or more) on why you keep the files",
        call. = FALSE
      )
    }
  }
  list(upload = upload, reason = reason)
}

#' The URLs to capture: given, or the ones the Wayback Machine refused in a
#' wbsave() result.
#' @param urls As for arccap().
#' @return The URLs, without duplicates.
#' @noRd
.bl_cap_urls <- function(urls) {
  if (inherits(urls, "rmbl_wayback_save")) {
    refused <- urls$status == "failed" &
      grepl(
        "cannot find|blocks access|HTTP status=40[134]",
        ifelse(is.na(urls$message), "", urls$message)
      )
    urls <- urls$url[refused]
  }
  if (!is.character(urls) || anyNA(urls) || !length(urls)) {
    stop("`urls` must be URLs", call. = FALSE)
  }
  unique(urls)
}

#' The archive.org keys an upload to an item needs.
#' @param item,ak,sk As for arccap().
#' @return A list: ak and sk ("" when there is no item).
#' @noRd
.bl_cap_ia_keys <- function(item, ak, sk) {
  if (is.null(item)) {
    return(list(ak = "", sk = ""))
  }
  .ak <- if (is.null(ak)) .bl_ia_key("IA_S3_ACCESS_KEY") else ak
  .sk <- if (is.null(sk)) .bl_ia_key("IA_S3_SECRET_KEY") else sk
  if (!nzchar(.ak) || !nzchar(.sk) || grepl("[^A-Za-z0-9]", paste0(.ak, .sk))) {
    stop(
      "archive.org keys are needed to upload: set IA_S3_ACCESS_KEY ",
      "and IA_S3_SECRET_KEY",
      call. = FALSE
    )
  }
  list(ak = .ak, sk = .sk)
}

# The names arccap() writes in a capture folder itself.
.bl_cap_own <- c(
  "manifest.json", "manifest.tsr", "manifest.tsr.rejected", "push.json",
  "archive", "indexes"
)

#' Fetches every URL into `dir`.
#' @param urls The URLs to capture, one row of the result each.
#' @param dir The folder.
#' @param tmout Seconds per download.
#' @return The capture table, one row per URL.
#' @noRd
.bl_cap_fetch <- function(urls, dir, tmout) {
  out <- data.frame(
    url = urls,
    file = NA_character_,
    sha256 = NA_character_,
    bytes = NA_real_,
    fetched_utc = NA_character_,
    status = NA_character_,
    mirror = NA_character_,
    warc = NA_character_,
    capture_id = NA_character_,
    archive = NA_character_,
    wayback = NA_character_,
    stringsAsFactors = FALSE
  )
  used <- character()
  for (i in seq_along(urls)) {
    f <- .bl_capture_name(urls[[i]])
    # a URL ending in /manifest.json must not be overwritten by the manifest
    if (f %in% c(used, .bl_cap_own)) {
      f <- sprintf("%03d_%s", i, f)
    }
    path <- file.path(dir, f)
    got <- tryCatch(
      blfetch(urls[[i]], path, wb = urls[[i]], tmout = tmout),
      error = function(e) structure(conditionMessage(e), class = "rmbl_fail")
    )
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
  out
}

#' Asks a time-stamping authority to stamp the manifest.
#' @param tsa The authority's address.
#' @param mpath The manifest.
#' @param dir The folder (manifest.tsr is written there).
#' @return The verified timestamp, or NULL (with a warning) when there is none.
#' @noRd
.bl_cap_timestamp <- function(tsa, mpath, dir) {
  nonce <- c(as.raw(0x01), rndbytes(7L))
  res <- .bl_tsa_post(
    tsa,
    .bl_tsq(.bl_hex_raw(sha256file(mpath)), nonce),
    60L
  )
  if (identical(res$status, 200L) && length(res$body)) {
    # checked before it is kept: a 200 with a junk body (a captive portal,
    # an error page) or another request's token is never saved or sent
    ts <- tsvrf(res$body, mpath, nonce = nonce)
    if (.bl_ts_core(ts)) {
      writeBin(res$body, file.path(dir, "manifest.tsr"))
      return(ts)
    }
    warning(
      sprintf(
        paste0(
          "the time-stamping authority's reply is not a valid timestamp ",
          "of the manifest (%s): it is not kept, and the manifest has no ",
          "timestamp"
        ),
        .bl_ts_failed(ts)
      ),
      call. = FALSE
    )
    return(NULL)
  }
  warning(
    sprintf(
      paste0(
        "the time-stamping authority did not answer (%s): the ",
        "manifest has no timestamp"
      ),
      if (nzchar(res$error)) res$error else paste("HTTP", res$status)
    ),
    call. = FALSE
  )
  NULL
}

#' Uploads the manifest, its timestamp and the captured files to an
#' archive.org item.
#' @param out The capture table.
#' @param ok The rows captured.
#' @param item,meta,dir,tmout As for arccap().
#' @param keys The archive.org S3 keys (`ak`, `sk`) for the upload.
#' @return The capture table.
#' @noRd
.bl_cap_ia_upload <- function(out, ok, item, meta, dir, keys, tmout) {
  .meta <- utils::modifyList(list(mediatype = "data"), meta)
  meta_h <- sprintf(
    "x-archive-meta-%s:%s",
    names(.meta),
    gsub("[\r\n]", " ", vapply(.meta, as.character, ""))
  )
  files <- c(
    "manifest.json",
    if (file.exists(file.path(dir, "manifest.tsr"))) "manifest.tsr",
    out$file[ok]
  )
  for (k in seq_along(files)) {
    res <- .bl_cap_ia_put1(files[k], k == 1L, item, dir, keys, meta_h, tmout)
    out <- .bl_cap_ia_mark(out, files[k], res, item)
  }
  out
}

#' Writes a WARC/1.1 file per capture and adds them to the CDXJ index.
#' @param out The capture table.
#' @param ok The rows kept.
#' @param dir,reason As for arccap().
#' @return The capture table, with each row's WARC file.
#' @noRd
.bl_cap_warc <- function(out, ok, dir, reason) {
  dir.create(file.path(dir, "archive"), showWarnings = FALSE)
  dir.create(file.path(dir, "indexes"), showWarnings = FALSE)
  meta <- if (!is.null(reason) && nzchar(reason)) {
    c(reason = gsub("[\r\n]", " ", reason))
  } else {
    character()
  }
  lines <- character()
  for (i in which(ok)) {
    t <- as.POSIXct(
      out$fetched_utc[i],
      format = "%Y-%m-%dT%H:%M:%SZ",
      tz = "UTC"
    )
    id <- paste0(
      format(t, "%Y%m%d%H%M%S", tz = "UTC"),
      "-",
      substr(out$sha256[i], 1L, 8L)
    )
    wf <- file.path(dir, "archive", paste0(id, ".warc"))
    lines <- c(
      lines,
      .bl_warc_write(
        wf,
        out$url[i],
        file.path(dir, out$file[i]),
        t,
        id,
        mime = .bl_arc_mime(out$file[i]),
        meta = meta
      )
    )
    out$warc[i] <- wf
  }
  .bl_cdxj_add(file.path(dir, "indexes", "index.cdxj"), lines)
  out
}

#' Keeps each capture at archive.rmorie.com.
#' @param out The capture table.
#' @param ok The rows kept.
#' @param dir,reason,visibility,tmout As for arccap().
#' @return The capture table, with each row's capture id and address.
#' @noRd
.bl_cap_rmorie <- function(out, ok, dir, reason, visibility, tmout) {
  base <- .bl_arc_base()
  key <- .bl_arc_key(base)
  if (is.null(key)) {
    stop(
      sprintf(
        paste0(
          "archive.rmorie.com needs your key: run dlogin() (or `%s ",
          "login`) once, or in GitHub ",
          "Actions allow the job `id-token: write`; the files are kept in %s"
        ),
        .bl_prog(),
        dir
      ),
      call. = FALSE
    )
  }
  for (i in which(ok)) {
    r <- .bl_cap_rmorie1(out, i, dir, reason, visibility, base, key, tmout)
    if (inherits(r, "rmbl_fail")) {
      out$status[i] <- paste("failed:", r, "(the file is kept locally)")
    } else {
      out$capture_id[i] <- r$capture_id
      out$archive[i] <- r$capture
      if (out$status[i] == "captured") out$status[i] <- "archived"
    }
  }
  out
}

#' Asks the Wayback Machine to save the captured addresses too.
#'
#' One address wbsave() refuses (on your own network, or resolving to it)
#' is "not asked" alone: the others are still asked (recheck of a8cdaf9).
#' @param out The capture table.
#' @param ok The rows kept.
#' @param ak,sk As for arccap().
#' @return The capture table, with each row's Wayback status.
#' @noRd
.bl_cap_wayback <- function(out, ok, ak, sk) {
  # what can be refused without the network, refused row by row
  why <- rep("", nrow(out))
  why[ok] <- vapply(out$url[ok], .bl_cap_wb_why, "", USE.NAMES = FALSE)
  bad <- ok & nzchar(why)
  out$wayback[bad] <- paste("not asked:", why[bad])
  ok <- ok & !bad
  if (!any(ok)) {
    return(out)
  }
  w <- .bl_cap_wb_ask(out$url[ok], ak, sk)
  if (inherits(w, "rmbl_fail") && sum(ok) > 1L &&
        grepl("not a public address", w, fixed = TRUE)) {
    # an address that resolves to a private one: each asked alone
    for (i in which(ok)) {
      out <- .bl_cap_wb_fill(out, i, .bl_cap_wb_ask(out$url[i], ak, sk))
    }
    return(out)
  }
  .bl_cap_wb_fill(out, which(ok), w)
}

#' wbsave() for some addresses, its error kept as a value.
#' @param urls The addresses.
#' @param ak,sk As for arccap().
#' @return The wbsave() result, or an `rmbl_fail` string.
#' @noRd
.bl_cap_wb_ask <- function(urls, ak, sk) {
  tryCatch(
    wbsave(urls, ak = ak, sk = sk, quiet = TRUE),
    error = function(e) {
      .bl_unless_interrupted(
        e,
        structure(conditionMessage(e), class = "rmbl_fail")
      )
    }
  )
}

#' The Wayback Machine's answer, written into the rows asked.
#' @param out The capture table.
#' @param i The rows asked (indices).
#' @param w The wbsave() result, or an `rmbl_fail` string.
#' @return The capture table.
#' @noRd
.bl_cap_wb_fill <- function(out, i, w) {
  if (inherits(w, "rmbl_fail")) {
    out$wayback[i] <- paste("not asked:", w)
    return(out)
  }
  wd <- as.data.frame(unclass(w))
  j <- match(out$url[i], wd$url)
  said <- ifelse(
    is.na(wd$timestamp[j]),
    wd$status[j],
    paste(wd$status[j], wd$timestamp[j])
  )
  said[is.na(j)] <- NA_character_
  out$wayback[i] <- said
  out
}

#' Why wbsave() would refuse one address without looking it up, or "".
#' @param u The URL.
#' @return One string.
#' @noRd
.bl_cap_wb_why <- function(u) {
  tryCatch(
    {
      .bl_wb_check_urls(u)
      ""
    },
    error = function(e) {
      .bl_unless_interrupted(e, sub("^[^ :]+: ", "", conditionMessage(e)))
    }
  )
}

#' arccap()'s WARC flag, URLs, folder, item, timestamp authority and
#' timeout, checked.
#' @param warc,urls,dir,item,meta,tsa,tmout As for arccap().
#' @return A list with the checked `urls`, `dir`, `tsa` and `tmout`.
#' @noRd
.bl_cap_args <- function(warc, urls, dir, item, meta, tsa, tmout) {
  if (!is.logical(warc) || length(warc) != 1L || is.na(warc)) {
    stop("`warc` must be TRUE or FALSE", call. = FALSE)
  }
  urls <- .bl_cap_urls(urls)
  dir <- .rmbl_string1(dir, "dir")
  .bl_cap_item_meta(item, meta)
  if (!is.null(tsa)) {
    tsa <- .rmbl_string1(tsa, "tsa")
  }
  tmout <- .rmbl_scalar(tmout, "tmout", 1, 86400, integer = TRUE)
  list(urls = urls, dir = dir, tsa = tsa, tmout = tmout)
}

#' Writes arccap()'s manifest of the captured files.
#' @param out The capture table.
#' @param ok Which rows were captured.
#' @param item The Internet Archive item, or `NULL`.
#' @param dir The capture folder manifest.json is written to.
#' @return The manifest's path.
#' @noRd
.bl_cap_manifest <- function(out, ok, item, dir) {
  man <- list(
    created_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    item = item %||% NA_character_,
    files = lapply(which(ok), function(i) {
      as.list(out[i, c("url", "file", "sha256", "bytes", "fetched_utc")])
    })
  )
  mpath <- file.path(dir, "manifest.json")
  writeLines(tojs(man), mpath)
  mpath
}

#' arccap()'s WARC files and archive.rmorie.com upload, as asked for.
#'
#' WARC/1.1 files and a CDXJ index make a pywb collection, and fetchvrf()'s
#' last fallback.
#' @param out The capture table.
#' @param ok Which rows were captured or uploaded.
#' @param dir The capture folder holding the files to publish.
#' @param warc,upload,reason,visibility,tmout As for arccap() (checked).
#' @return `out`, with the WARC and archive columns filled in.
#' @noRd
.bl_cap_publish <- function(
  out,
  ok,
  dir,
  warc,
  upload,
  reason,
  visibility,
  tmout
) {
  if (isTRUE(warc)) {
    out <- .bl_cap_warc(out, ok, dir, reason)
  }
  if ("rmorie" %in% upload) {
    out <- .bl_cap_rmorie(out, ok, dir, reason, visibility, tmout)
  }
  out
}

#' Sends one file of an arccap() capture to its Internet Archive item.
#' @param file The file name, relative to `dir`.
#' @param first Whether this is the first file, which makes the item.
#' @param item The item.
#' @param dir The capture folder `file` is read from.
#' @param keys The S3 keys (`ak`, `sk`).
#' @param meta_h The item metadata headers.
#' @param tmout Seconds the upload of this one file may take.
#' @return The reply of `.bl_ia_put()`.
#' @noRd
.bl_cap_ia_put1 <- function(file, first, item, dir, keys, meta_h, tmout) {
  h <- c(
    sprintf("authorization: LOW %s:%s", keys$ak, keys$sk),
    "x-archive-queue-derive:0",
    if (first) c("x-amz-auto-make-bucket:1", meta_h)
  )
  ctype <- if (grepl("\\.json$", file)) {
    "application/json"
  } else {
    "application/octet-stream"
  }
  .bl_ia_put(
    sprintf("%s/%s/%s", .bl_ia_s3(), item, .bl_ia_key_path(file)),
    file.path(dir, file),
    ctype,
    h,
    tmout
  )
}

#' A file's name as the path of its key in the item: each part
#' percent-encoded, so no name reaches another item or a query.
#' @param file The file name, relative to the capture folder (checked).
#' @return One string.
#' @noRd
.bl_ia_key_path <- function(file) {
  parts <- strsplit(file, "/", fixed = TRUE)[[1L]]
  if (!length(parts) || any(parts %in% c("", ".", ".."))) {
    stop(
      sprintf(
        "not a file name inside the capture: %s",
        .rmbl_printable(file)
      ),
      call. = FALSE
    )
  }
  paste(
    vapply(parts, utils::URLencode, "", reserved = TRUE, USE.NAMES = FALSE),
    collapse = "/"
  )
}

#' Records one Internet Archive upload in the capture table; a refused
#' manifest stops the upload.
#' @param out The capture table.
#' @param file The file name.
#' @param res The reply of `.bl_ia_put()`.
#' @param item The item.
#' @return `out`, with the file's status and mirror filled in.
#' @noRd
.bl_cap_ia_mark <- function(out, file, res, item) {
  good <- isTRUE(res$status >= 200L && res$status < 300L)
  j <- match(file, out$file)
  if (!is.na(j)) {
    out$status[j] <- if (good) {
      "uploaded"
    } else {
      paste("failed: upload answered", res$status, res$error)
    }
    if (good) {
      out$mirror[j] <- sprintf(
        "https://archive.org/download/%s/%s",
        item,
        .bl_ia_key_path(file)
      )
    }
  } else if (!good) {
    stop(
      sprintf(
        "archive.org refused %s (HTTP %s %s): nothing more was sent",
        file,
        res$status,
        res$error
      ),
      call. = FALSE
    )
  }
  out
}

#' Uploads one captured file to archive.rmorie.com.
#' @param out The capture table.
#' @param i The row of the capture table whose file is uploaded.
#' @param dir The capture folder the row's file is read from.
#' @param reason,visibility As for arccap().
#' @param base,key The archive's base URL and key.
#' @param tmout Seconds the upload to archive.rmorie.com may take.
#' @return The archive's reply, or an `rmbl_fail` string with the error.
#' @noRd
.bl_cap_rmorie1 <- function(out, i, dir, reason, visibility, base, key, tmout) {
  tryCatch(
    .bl_arc_upload(
      file.path(dir, out$file[i]),
      out$url[i],
      as.POSIXct(
        out$fetched_utc[i],
        format = "%Y-%m-%dT%H:%M:%SZ",
        tz = "UTC"
      ),
      reason,
      visibility,
      .bl_arc_mime(out$file[i]),
      base,
      key,
      tmout
    ),
    error = function(e) {
      .bl_unless_interrupted(
        e,
        structure(conditionMessage(e), class = "rmbl_fail")
      )
    }
  )
}
