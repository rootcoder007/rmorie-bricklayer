# SPDX-License-Identifier: AGPL-3.0-or-later
#
# arcpush(): a capture kept on this computer, sent on to the archives later.

#' Send a capture kept on this computer to the archives later
#'
#' @description
#' [arccap()] keeps every capture on this computer first: the files,
#' their SHA-256, a manifest and, by default, a WARC copy. When the Wayback
#' Machine, archive.rmorie.com or archive.org is down, or there is no
#' network but the source's, the capture is still complete there.
#' \code{arcpush()} sends that same capture on later: the very files that
#' were fetched, each checked first against the SHA-256 the manifest
#' recorded, so an archive keeps what you captured, not a new download. Run
#' it again to retry what failed; what an archive already took is not sent
#' twice.
#'
#' The Wayback Machine takes no uploads: with \code{upload = "wayback"} it
#' is asked to capture each address itself, as the page is then. If the
#' page has changed since, its copy differs from yours, and your copy, with
#' the manifest's timestamp, remains the record of what you had.
#'
#' A manifest with no timestamp yet (the authority was unreachable, or
#' \code{tsa = NULL} at capture) is stamped now when \code{tsa} is given;
#' that timestamp shows the files existed by now, not by the time they were
#' fetched.
#'
#' Errors: \code{dir} without the \file{manifest.json} that [arccap()]
#' writes, or a manifest that lists no files; nowhere to send (neither
#' \code{item} nor \code{upload}); as for [arccap()] for \code{item},
#' \code{meta}, \code{upload}, \code{reason}, \code{tmout} and the keys.
#'
#' @param dir The folder of an [arccap()] capture.
#' @param item,meta,ak,sk,upload,reason,visibility,tmout As for
#'   [arccap()].
#' @param tsa A time-stamping authority, asked only when the manifest has
#'   no timestamp yet (default as for [arccap()]); \code{NULL} asks none.
#' @return An object of class \code{rmbl_archive_capture}, as [arccap()]
#'   returns: one row per file of the capture, with what each archive
#'   answered, this time or an earlier one. A file that is missing, or whose
#'   bytes no longer match the manifest, is \code{"failed: ..."} and is not
#'   sent. What each archive took is also kept in \file{push.json} in
#'   \code{dir}, which the next run reads.
#' @seealso [arccap()] makes the capture;
#'   [wbsave()] and
#'   [wbrtry()] for the Wayback Machine alone;
#'   [fetchvrf()] falls back to the copies.
#' @examplesIf interactive()
#' # capture now, on this computer only
#' src <- "https://www150.statcan.gc.ca/n1/tbl/csv/35100177-eng.zip"
#' d <- file.path(tempdir(), "cap")
#' arccap(src, d, tsa = NULL)
#' # later, when the archives answer: the same bytes, sent on
#' arcpush(
#'   d,
#'   upload = c("rmorie", "wayback"),
#'   reason = "Custody table cited in chapter 3"
#' )
#' @export
arcpush <- function(
  dir,
  item = NULL,
  meta = list(),
  ak = NULL,
  sk = NULL,
  upload = NULL,
  reason = NULL,
  visibility = c("public", "private"),
  tsa = "https://freetsa.org/tsr",
  tmout = 600L
) {
  visibility <- .rmbl_arg(visibility)
  up <- .bl_cap_upload_arg(upload, reason)
  dir <- .rmbl_string1(dir, "dir")
  .bl_cap_item_meta(item, meta)
  if (is.null(item) && is.null(up$upload)) {
    stop("give `item`, `upload` or both: where the capture goes",
         call. = FALSE)
  }
  if (!is.null(tsa)) {
    tsa <- .rmbl_string1(tsa, "tsa")
  }
  tmout <- .rmbl_scalar(tmout, "tmout", 1, 86400, integer = TRUE)
  keys <- .bl_cap_ia_keys(item, ak, sk)
  mpath <- file.path(dir, "manifest.json")
  out <- .bl_push_merge(.bl_push_table(dir, mpath), dir)
  ts <- .bl_push_stamp(tsa, mpath, dir)
  ok <- out$status == "captured"
  out <- .bl_push_ia(out, ok, item, meta, dir, keys, tmout)
  if ("rmorie" %in% up$upload) {
    todo <- ok & is.na(out$capture_id)
    if (any(todo)) {
      out <- .bl_cap_rmorie(out, todo, dir, up$reason, visibility, tmout)
    }
  }
  if ("wayback" %in% up$upload) {
    todo <- ok & !grepl("^(saved|existing)", .bl_push_na(out$wayback))
    if (any(todo)) {
      out <- .bl_cap_wayback(out, todo, ak, sk)
    }
  }
  .bl_push_save(out, dir)
  out <- .bl_push_status(out)
  attr(out, "manifest") <- mpath
  attr(out, "timestamp") <- ts
  attr(out, "item") <- item
  class(out) <- c("rmbl_archive_capture", "data.frame")
  out
}

#' The capture table of an arccap() folder, each file checked against the
#' SHA-256 its manifest recorded.
#' @param dir The arccap() folder being sent.
#' @param mpath Its manifest.
#' @return The capture table, as arccap() builds it.
#' @noRd
.bl_push_table <- function(dir, mpath) {
  if (!file.exists(mpath)) {
    stop(sprintf("no arccap() capture in %s: manifest.json is missing", dir),
         call. = FALSE)
  }
  f <- fromjs(mpath, simplifyVector = FALSE)$files
  if (!length(f)) {
    stop("the capture's manifest lists no files", call. = FALSE)
  }
  col <- function(k) .bl_push_field(f, k)
  out <- data.frame(
    url = col("url"), file = col("file"), sha256 = col("sha256"),
    bytes = as.numeric(col("bytes")), fetched_utc = col("fetched_utc"),
    status = "captured", mirror = NA_character_, warc = NA_character_,
    capture_id = NA_character_, archive = NA_character_,
    wayback = NA_character_, stringsAsFactors = FALSE
  )
  # the manifest is input: a name that leaves the folder ("../x", "/etc/x",
  # a symlink out) is never read, hashed or sent (recheck of a8cdaf9)
  path <- lapply(out$file, .bl_push_path, dir = dir)
  now <- vapply(path, function(p) {
    if (!is.null(p) && file.exists(p)) sha256file(p) else ""
  }, "", USE.NAMES = FALSE)
  out$status[now == ""] <- "failed: the file is missing"
  changed <- nzchar(now) & now != out$sha256
  out$status[changed] <- paste(
    "failed: the file no longer matches its SHA-256 in the manifest"
  )
  out$status[vapply(path, is.null, NA)] <- paste(
    "failed: the manifest's file name is not a plain relative path inside",
    "the capture folder, so it is not sent"
  )
  out
}

#' A manifest's file name joined under the capture folder, or NULL when it
#' is not a plain relative path inside it.
#'
#' Refused: no name, "..", ".", an absolute path, a drive letter, a home
#' prefix, a backslash, a control character, a symlink out
#' (.rmbl_safe_rel()), or a folder.
#' @param f The file name from the manifest.
#' @param dir The capture folder.
#' @return The path, or NULL.
#' @noRd
.bl_push_path <- function(f, dir) {
  cp <- if (is.na(f)) NA else utf8ToInt(enc2utf8(f))
  if (anyNA(cp) || any(cp < 32L | (cp >= 127L & cp <= 159L)) ||
        grepl("\\", f, fixed = TRUE)) {
    return(NULL)
  }
  p <- .rmbl_safe_rel(f, dir)
  if (is.null(p) || dir.exists(p)) NULL else p
}

#' One field of each record of a JSON array, as text.
#' @param recs The records, lists.
#' @param k The field's name.
#' @return A character vector, NA where a record lacks it.
#' @noRd
.bl_push_field <- function(recs, k) {
  vapply(recs, function(e) {
    # a JSON null comes back as NULL, alone or inside a list
    v <- unlist(e[[k]], use.names = FALSE)
    if (length(v)) as.character(v[[1L]]) else NA_character_
  }, "")
}

#' Text with NA as "".
#' @param x Text, with NA where a field was empty.
#' @return `x` with NA replaced by "".
#' @noRd
.bl_push_na <- function(x) {
  x[is.na(x)] <- ""
  x
}

#' What the archives took in earlier runs (push.json), added to the table.
#' @param out The capture table of arcpush().
#' @param dir The arccap() folder being sent.
#' @return The table, with each archive's earlier answer.
#' @noRd
.bl_push_merge <- function(out, dir) {
  p <- file.path(dir, "push.json")
  if (!file.exists(p)) {
    return(out)
  }
  prev <- fromjs(p, simplifyVector = FALSE)
  j <- match(out$url, .bl_push_field(prev, "url"))
  for (k in c("mirror", "capture_id", "archive", "wayback")) {
    v <- .bl_push_field(prev, k)[j]
    out[[k]] <- ifelse(is.na(v), out[[k]], v)
  }
  out
}

#' Keeps what each archive took, for the next run.
#' @param out The capture table of arcpush().
#' @param dir The arccap() folder being sent.
#' @return The path of push.json, invisibly.
#' @noRd
.bl_push_save <- function(out, dir) {
  recs <- lapply(seq_len(nrow(out)), function(i) {
    as.list(out[i, c("url", "mirror", "capture_id", "archive", "wayback")])
  })
  p <- file.path(dir, "push.json")
  writeLines(tojs(recs), p)
  invisible(p)
}

#' The manifest's timestamp: the one kept, or a new one when there is none.
#' @param tsa The authority, or NULL.
#' @param mpath The capture's manifest.json.
#' @param dir The arccap() folder being sent.
#' @return A tsvrf() result, or NULL.
#' @noRd
.bl_push_stamp <- function(tsa, mpath, dir) {
  tsr <- file.path(dir, "manifest.tsr")
  if (file.exists(tsr)) {
    ts <- tsvrf(readBin(tsr, "raw", file.size(tsr)), mpath)
    if (.bl_ts_core(ts)) {
      return(ts)
    }
    # a token that does not verify for this manifest (a junk reply an
    # earlier version kept) is set aside, not sent or reused
    bad <- paste0(tsr, ".rejected")
    file.rename(tsr, bad)
    warning(
      sprintf(
        paste0(
          "the kept manifest.tsr is not a valid timestamp of the ",
          "manifest (%s): it is set aside as %s and not sent"
        ),
        .bl_ts_failed(ts),
        basename(bad)
      ),
      call. = FALSE
    )
  }
  if (is.null(tsa)) {
    return(NULL)
  }
  .bl_cap_timestamp(tsa, mpath, dir)
}

#' Uploads to the archive.org item the files it does not have yet; a
#' refusal is recorded on those files, so the next run tries again.
#' @param out The capture table of arcpush().
#' @param ok The files that may be sent.
#' @param item,meta,dir,tmout As for arcpush().
#' @param keys The archive.org keys.
#' @return The capture table.
#' @noRd
.bl_push_ia <- function(out, ok, item, meta, dir, keys, tmout) {
  todo <- ok & is.na(out$mirror)
  if (is.null(item) || !any(todo)) {
    return(out)
  }
  tryCatch(
    .bl_cap_ia_upload(out, todo, item, meta, dir, keys, tmout),
    error = function(e) {
      e <- .bl_unless_interrupted(e, e)
      out$status[todo] <- paste("failed:", conditionMessage(e))
      out
    }
  )
}

#' Each file's status from what the archives hold: archived, uploaded,
#' captured, or the failure.
#' @param out The capture table of arcpush().
#' @return The table.
#' @noRd
.bl_push_status <- function(out) {
  kept <- out$status %in% c("captured", "uploaded")
  out$status[kept & !is.na(out$mirror)] <- "uploaded"
  out$status[kept & !is.na(out$capture_id)] <- "archived"
  out
}
