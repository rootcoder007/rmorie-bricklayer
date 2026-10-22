# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Captures written as WARC/1.1 files with a CDXJ index, in the layout of a pywb collection
# (<dir>/archive/<capture_id>.warc, <dir>/indexes/index.cdxj). pywb and warcio read it as is,
# archive.rmorie.com stores the same records, and fetchvrf() reads a capture back from it when
# the source, the Wayback Machine and the archive are all out of reach. Written from the WARC 1.1
# specification and pywb's documented CDXJ format; no code is copied from either.

#' Encodes bytes as RFC 4648 Base32 with padding.
#'
#' WARC payload digests are written in Base32, as the Internet Archive and warcio write theirs.
#' @param x A raw vector.
#' @return One string of A-Z and 2-7, padded with "=" to a multiple of 8 characters.
#' @noRd
.bl_base32 <- function(x) {
  if (!length(x)) return("")
  bits <- as.integer(matrix(as.integer(rawToBits(x)), 8L)[8:1, ])  # most significant bit first
  bits <- c(bits, integer((5L - length(bits) %% 5L) %% 5L))
  idx <- colSums(matrix(bits, 5L) * c(16L, 8L, 4L, 2L, 1L)) + 1L
  out <- paste(strsplit("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567", "")[[1L]][idx], collapse = "")
  paste0(out, strrep("=", (8L - nchar(out) %% 8L) %% 8L))
}

#' The SURT form of a URL, the sort key of a CDXJ line.
#'
#' Lower case, no scheme, no userinfo or fragment, no leading www., no default port, query
#' arguments sorted, host labels reversed: https://www.Example.com:443/A?z=1&a=2 becomes
#' com,example)/a?a=2&z=1. Because the path is lower-cased the key only sorts captures;
#' matching a capture compares the stored URL.
#' @param url One URL.
#' @return One string.
#' @noRd
.bl_surt <- function(url) {
  u <- sub("#.*$", "", tolower(url))
  m <- regmatches(u, regexec("^([a-z][a-z0-9+.-]*)://([^/?]*)([^?]*)(\\?(.*))?$", u))[[1L]]
  if (!length(m)) return(u)
  host <- sub("^www[0-9]*\\.", "", sub("^[^@]*@", "", m[3L]))
  port <- ""
  if (grepl(":[0-9]+$", host)) {
    port <- sub("^.*(:[0-9]+)$", "\\1", host)
    host <- sub(":[0-9]+$", "", host)
    if ((m[2L] == "http" && port == ":80") || (m[2L] == "https" && port == ":443")) port <- ""
  }
  q <- m[6L]
  if (nzchar(q)) q <- paste0("?", paste(sort(strsplit(q, "&", fixed = TRUE)[[1L]]), collapse = "&"))
  paste0(paste(rev(strsplit(host, ".", fixed = TRUE)[[1L]]), collapse = ","), port, ")",
         if (nzchar(m[4L])) m[4L] else "/", q)
}

#' A random (version 4) UUID as a WARC record id.
#' @return One string, "<urn:uuid:...>".
#' @noRd
.bl_uuid <- function() {
  b <- rndbytes(16L)
  b[7L] <- as.raw(bitwOr(bitwAnd(as.integer(b[7L]), 0x0f), 0x40))
  b[9L] <- as.raw(bitwOr(bitwAnd(as.integer(b[9L]), 0x3f), 0x80))
  h <- paste(format(b), collapse = "")
  sprintf("<urn:uuid:%s-%s-%s-%s-%s>", substr(h, 1L, 8L), substr(h, 9L, 12L), substr(h, 13L, 16L),
          substr(h, 17L, 20L), substr(h, 21L, 32L))
}

#' One WARC/1.1 record: the version line, its named fields, Content-Length, a blank line,
#' the block and two CRLF.
#' @param type The WARC-Type.
#' @param fields A named character vector of further WARC fields.
#' @param block The record block, as raw.
#' @return A raw vector.
#' @noRd
.bl_warc_record <- function(type, fields, block) {
  head <- paste0("WARC/1.1\r\nWARC-Type: ", type, "\r\n",
                 paste0(names(fields), ": ", fields, "\r\n", collapse = ""),
                 "Content-Length: ", length(block), "\r\n\r\n")
  c(charToRaw(head), block, charToRaw("\r\n\r\n"))
}

#' Writes one capture as a WARC/1.1 file and returns its CDXJ line.
#'
#' Three records: warcinfo (who captured and how), response (the HTTP status line, the
#' headers and the payload bytes as received) and metadata (capture id, reason, the file's
#' SHA-256). Transfer-Encoding is dropped and Content-Length set to the payload's length,
#' since the transport has already de-chunked the body; the metadata record says so.
#' @param warc Path of the .warc file to write.
#' @param url The URL captured.
#' @param payload Path of the payload file (the bytes received).
#' @param ts Capture time (POSIXct).
#' @param capture_id The capture id (also the WARC file name without .warc).
#' @param status HTTP status code.
#' @param headers Named character vector of response headers, or empty (then Content-Type
#'   from `mime` and Content-Length are written).
#' @param mime The payload's media type for the index.
#' @param ip The server's address, or NA.
#' @param info Named character vector of extra warcinfo fields.
#' @param meta Named character vector of extra metadata fields (reason, rfc3161-token, ...).
#' @return One CDXJ line (string).
#' @noRd
.bl_warc_write <- function(warc, url, payload, ts, capture_id, status = 200L, headers = character(),
                           mime = "application/octet-stream", ip = NA_character_,
                           info = character(), meta = character()) {
  # ponytail: payload read whole into memory; stream it if captures over a few hundred MB matter
  body <- readBin(payload, "raw", file.size(payload))
  sha_hex <- sha256file(payload)
  digest <- paste0("sha256:", .bl_base32(.bl_hex_raw(sha_hex)))
  wdate <- format(ts, "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC")
  headers <- headers[!tolower(names(headers)) %in% c("transfer-encoding", "content-length")]
  if (!any(tolower(names(headers)) == "content-type")) headers <- c(headers, "Content-Type" = mime)
  headers <- c(headers, "Content-Length" = as.character(length(body)))
  reason <- c(`200` = "OK", `201` = "Created", `203` = "Non-Authoritative Information", `204` = "No Content",
              `206` = "Partial Content")[as.character(status)]
  http <- c(charToRaw(sprintf("HTTP/1.1 %d %s\r\n%s\r\n", as.integer(status), if (is.na(reason)) "" else reason,
                              paste0(names(headers), ": ", headers, "\r\n", collapse = ""))), body)
  info_id <- .bl_uuid()
  resp_id <- .bl_uuid()
  fields <- function(x) charToRaw(paste0(names(x), ": ", x, "\r\n", collapse = ""))
  warcinfo <- .bl_warc_record("warcinfo", c("WARC-Record-ID" = info_id, "WARC-Date" = wdate,
                                            "WARC-Filename" = basename(warc),
                                            "Content-Type" = "application/warc-fields"),
                              fields(c(software = paste0("rmoriebricklayer/", utils::packageVersion(.packageName)),
                                       format = "WARC File Format 1.1", info)))
  response <- .bl_warc_record("response", c("WARC-Record-ID" = resp_id, "WARC-Warcinfo-ID" = info_id,
                                            "WARC-Date" = wdate, "WARC-Target-URI" = url,
                                            if (!is.na(ip)) c("WARC-IP-Address" = ip),
                                            "WARC-Payload-Digest" = digest,
                                            "Content-Type" = "application/http;msgtype=response"), http)
  metadata <- .bl_warc_record("metadata", c("WARC-Record-ID" = .bl_uuid(), "WARC-Concurrent-To" = resp_id,
                                            "WARC-Target-URI" = url, "WARC-Date" = wdate,
                                            "Content-Type" = "application/warc-fields"),
                              fields(c("capture-id" = capture_id, "file-sha256" = sha_hex,
                                       "headers-normalised" = "Transfer-Encoding removed; Content-Length set",
                                       meta)))
  con <- file(warc, "wb")
  on.exit(close(con))
  writeBin(c(warcinfo, response, metadata), con)
  rec <- list(url = url, mime = mime, status = as.character(status), digest = digest,
              length = as.character(length(response)), offset = as.character(length(warcinfo)),
              filename = basename(warc), sha256 = sha_hex, capture_id = capture_id)
  paste(.bl_surt(url), format(ts, "%Y%m%d%H%M%S", tz = "UTC"), tojs(rec, auto_unbox = TRUE))
}

#' Adds CDXJ lines to a collection's index, kept sorted by SURT key and timestamp.
#' @param index Path of index.cdxj.
#' @param lines New CDXJ lines.
#' @return The index path, invisibly.
#' @noRd
.bl_cdxj_add <- function(index, lines) {
  old <- if (file.exists(index)) readLines(index, warn = FALSE) else character()
  all <- unique(c(old, lines))
  keys <- sub("^(\\S+ \\S+) .*$", "\\1", all)
  writeLines(all[order(keys, method = "radix")], index, useBytes = TRUE)
  invisible(index)
}
