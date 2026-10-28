# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Capsule checks for CI and the shell: the JSON Schemas of the capsule files, a
# resource diff between two manifests, re-pinning a capsule to its source, and
# the rows behind the verbs `rmbl verify`, `drift`, `refresh` and `report` (the
# checks the rmbl GitHub Action runs).

#' Path of a JSON Schema shipped with the package
#'
#' @description
#' The capsule files are described by JSON Schema (draft 2020-12)
#' documents in the package's \code{schemas} folder, the same files as the
#' \code{spec} folder of the rmbl GitHub Action: \code{capsule} for
#' \code{data_provenance.json}, \code{bundle} for \code{capsule_bundle.json}
#' and \code{manifest} for a results manifest. \code{rmbl verify} checks
#' each capsule file against its schema before the package's own checks.
#'
#' @param name Character scalar: \code{"capsule"}, \code{"bundle"} or
#'   \code{"manifest"}, with or without the \code{.schema.json} ending.
#' @return The path of the installed schema file, a character scalar.
#'   Error: any other name.
#' @seealso \code{\link{blcli}} (the verify verb), \code{\link{vrfcps}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' schemapath("capsule")
#' s <- fromjs(paste(readLines(schemapath("bundle")), collapse = "\n"))
#' s$required
#'
#' # only the four schemas exist
#' try(schemapath("nope"))
#' @export
schemapath <- function(name) {
  name <- .rmbl_string1(name, "name")
  base <- sub("\\.schema\\.json$", "", name)
  if (!base %in% c("capsule", "bundle", "manifest", "ledger")) {
    stop(
      .rmbl_fn(),
      sprintf(
        "`name` must be capsule, bundle, manifest or ledger, not '%s'",
        .rmbl_printable(name)
      ),
      call. = FALSE
    )
  }
  system.file(
    "schemas",
    paste0(base, ".schema.json"),
    package = "rmoriebricklayer",
    mustWork = TRUE
  )
}

#' Compare the resources of two manifests
#'
#' @description
#' Lists the resources (data files) of two manifests side by side and says
#' which were added, removed or changed: a different SHA-256, or a
#' different size where both sizes are recorded. A manifest is a provenance
#' record (its \code{resource}), a capsule bundle (its \code{files}), a
#' data frame with the columns \code{path} and \code{sha256} (and
#' optionally \code{size_bytes}), or the path of a JSON file holding one of
#' the first two. \code{\link{cpsrfrsh}} and \code{rmbl drift} report
#' what a fetched source changed with it.
#'
#' @param old,new The two manifests, as described above. A list with
#'   neither \code{resource} nor \code{files} has no resources.
#' @param x An \code{rmbl_mnfdiff} result.
#' @param ... Further arguments, ignored when printing the comparison.
#' @return A data frame of class \code{rmbl_mnfdiff}, one row per resource
#'   in either manifest, with the columns \code{resource} (the file name),
#'   \code{change} (\code{"added"}, \code{"removed"}, \code{"changed"} or
#'   \code{"unchanged"}), \code{old_sha256}, \code{new_sha256},
#'   \code{old_size} and \code{new_size} (\code{NA} where not recorded).
#'   It prints the counts and one line per change. Errors: a manifest that
#'   is not a list, a data frame or a file; a data frame without
#'   \code{path} and \code{sha256}.
#' @seealso \code{\link{cpsrfrsh}}, \code{\link{cpsbndl}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' a <- data.frame(
#'   path = c("a.csv", "b.csv"),
#'   sha256 = c("01", "02"),
#'   size_bytes = c(10, 20)
#' )
#' b <- data.frame(
#'   path = c("a.csv", "c.csv"),
#'   sha256 = c("09", "03"),
#'   size_bytes = c(12, 30)
#' )
#' d <- mnfdiff(a, b)
#' d
#' d$change
#'
#' # a provenance record and its re-pinned copy
#' p <- list(
#'   resource = list(filename = "a.csv", sha256 = "01", size_bytes = 10)
#' )
#' q <- p
#' q$resource$sha256 <- "09"
#' mnfdiff(p, q)$change
#'
#' try(mnfdiff(1, b))
#' @srrstats {G2.1} `old` and `new` are checked for type: a data frame must
#'   carry path and sha256, and anything but a list, a data frame or a file name
#'   is refused (test-capsule_cli.R).
#' @export
mnfdiff <- function(old, new) {
  a <- .bl_mnf_resources(old, "old")
  b <- .bl_mnf_resources(new, "new")
  keys <- union(a$resource, b$resource)
  ia <- match(keys, a$resource)
  ib <- match(keys, b$resource)
  sa <- tolower(a$sha256[ia])
  sb <- tolower(b$sha256[ib])
  za <- a$size_bytes[ia]
  zb <- b$size_bytes[ib]
  eq <- sa == sb
  same <- (!is.na(eq) & eq) | (is.na(sa) & is.na(sb))
  same_size <- is.na(za) | is.na(zb) | za == zb
  change <- ifelse(same & same_size, "unchanged", "changed")
  change[is.na(ib)] <- "removed"
  change[is.na(ia)] <- "added"
  out <- data.frame(
    resource = keys,
    change = change,
    old_sha256 = sa,
    new_sha256 = sb,
    old_size = za,
    new_size = zb,
    stringsAsFactors = FALSE
  )
  class(out) <- c("rmbl_mnfdiff", "data.frame")
  out
}

#' @rdname mnfdiff
#' @export
format.rmbl_mnfdiff <- function(x, ...) {
  if (!all(c("resource", "change") %in% names(x))) {
    return(utils::capture.output(print(as.data.frame(unclass(x)))))
  }
  n <- table(factor(x$change, c("changed", "added", "removed", "unchanged")))
  lines <- .bl_mnfdiff_text(x)[-1L]
  .rmbl_stat_block(
    "Manifest diff",
    facts = list(
      Resources = sprintf(
        "%d changed, %d added, %d removed, %d unchanged",
        n[["changed"]],
        n[["added"]],
        n[["removed"]],
        n[["unchanged"]]
      )
    ),
    reading = if (length(lines)) {
      "Files below differ between the two manifests (old -> new)."
    } else {
      "Both manifests pin the same bytes for every resource."
    },
    notes = trimws(lines, "left")
  )
}

#' Fetch a capsule's source again and pin the new bytes
#'
#' @description
#' Downloads the source named in a capsule's \code{data_provenance.json}
#' (\code{resource$direct_url}, else \code{source$url}; an \code{https://}
#' URL, or a local file inside the capsule), and when its bytes differ from
#' the pin writes them as the
#' capsule's data file and pins them in the provenance, in the form the
#' \code{analysis.R} of \code{\link{usecpstmpl}} writes on its first run:
#' \code{source$sha256}, and \code{resource$filename}, \code{sha256},
#' \code{size_bytes} and \code{retrieved_utc} (\code{row_count_data_rows}
#' too when it was recorded).
#' \code{\link{vrfcps}} then verifies the capsule against the new data.
#' From the shell: \code{rmbl refresh PATH}.
#'
#' @details
#' Nothing is written when the bytes are unchanged. A download goes through
#' \code{\link{fdl}}, with the provenance's \code{wayback$csv_snapshot}
#' as its fallback (no other Wayback copy is looked up). A source is fetched
#' over \code{https://} only. A local path (relative to the capsule) or a
#' \code{file://} URL is read only when it resolves, symbolic links followed,
#' to a file inside the capsule, inside the \code{allowfile} folder, or in the
#' package's \code{extdata}; never under \code{/proc}, \code{/sys} or
#' \code{/dev}. A gzip source may inflate to at most the option
#' \code{rmoriebricklayer.maxcsvbytes} (1 GiB by default) when it is read.
#' A capsule bundle is not signed again: that needs your
#' key (\code{\link{cpsbndl}}). Side effects: writes the data file and
#' \code{data_provenance.json} in \code{dir}. Errors: \code{dir} is not a
#' directory or holds no provenance; the provenance names no source, or a
#' \code{TODO} one, or a \code{file://} one without \code{allowfile}; a
#' URL that is not \code{https://}; a local source outside those folders;
#' the source cannot be fetched, or inflates past the limit;
#' \code{resource$filename} is not a plain relative path inside \code{dir};
#' \code{data_provenance.json} is a link out of \code{dir}; the new data
#' fail the schema the provenance pins (\code{\link{valsch}}).
#'
#' @param dir Character scalar, the capsule directory.
#' @param allowfile \code{FALSE} (the default), \code{TRUE} to accept a
#'   \code{file://} source inside \code{dir}, or an existing folder whose
#'   files may also be read as a source (a local path or a \code{file://}
#'   URL).
#' @return The \code{\link{mnfdiff}} of the provenance before and after:
#'   all \code{"unchanged"} when the source still matches its pin.
#' @seealso \code{\link{mnfdiff}}, \code{\link{vrfcps}},
#'   \code{\link{usecpstmpl}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' d <- usecpstmpl(tempfile("capsule-"), ex = TRUE)
#' cpsrfrsh(d)            # the first pin: the data file is added
#' vrfcps(d)$ok
#' cpsrfrsh(d)$change     # the source has not changed since
#'
#' try(cpsrfrsh(tempfile()))
#' @srrstats {G2.0} `dir` must be one existing directory, and the provenance's
#'   filename one plain relative path inside it (test-capsule_cli.R).
#' @export
cpsrfrsh <- function(dir, allowfile = FALSE) {
  dir <- .rmbl_string1(dir, "dir")
  allowfile <- .bl_allowfile_arg(allowfile)
  if (!dir.exists(dir)) {
    stop(.rmbl_fn(), "`dir` is not an existing directory: ", dir, call. = FALSE)
  }
  f <- .bl_fetch_pin(dir, allowfile)
  on.exit(.bl_fetch_cleanup(f), add = TRUE)
  diff <- mnfdiff(f$old, f$new)
  if (all(diff$change == "unchanged")) {
    return(diff)
  }
  .bl_write_pin(dir, f)
  diff
}

#' The plain lines of a manifest diff: the counts, then one line per change.
#' @param x An rmbl_mnfdiff result.
#' @return Lines.
#' @noRd
.bl_mnfdiff_text <- function(x) {
  n <- table(factor(x$change, c("changed", "added", "removed", "unchanged")))
  ch <- x[x$change != "unchanged", , drop = FALSE]
  short <- function(s) ifelse(is.na(s), "-", substr(s, 1L, 12L))
  size <- function(z) {
    ifelse(
      is.na(z),
      "-",
      format(z, big.mark = ",", scientific = FALSE, trim = TRUE)
    )
  }
  c(
    sprintf(
      "Manifest diff: %d changed, %d added, %d removed, %d unchanged",
      n[["changed"]],
      n[["added"]],
      n[["removed"]],
      n[["unchanged"]]
    ),
    if (nrow(ch)) {
      sprintf(
        "  %-9s %s  sha256 %s -> %s, %s -> %s bytes",
        ch$change,
        ch$resource,
        short(ch$old_sha256),
        short(ch$new_sha256),
        size(ch$old_size),
        size(ch$new_size)
      )
    }
  )
}

#' The resources of one manifest, as a data frame of resource, sha256 and
#' size_bytes.
#' @param x A provenance record, a bundle, a data frame or a JSON file's path.
#' @param what The argument's name, for the error message.
#' @return A data frame.
#' @noRd
.bl_mnf_resources <- function(x, what) {
  if (is.character(x)) {
    x <- .rmbl_read_json(.rmbl_file1(x, what), simplify = FALSE)
  }
  if (is.data.frame(x)) {
    return(.bl_mnf_from_frame(x, what))
  }
  if (!is.list(x)) {
    stop(
      .rmbl_fn(),
      sprintf(
        paste(
          "`%s` must be a provenance record, a capsule bundle, a data",
          "frame of path",
          "and sha256, or the path of a JSON file"
        ),
        what
      ),
      call. = FALSE
    )
  }
  .bl_mnf_from_list(x)
}

#' A manifest given as a data frame of path, sha256 and size_bytes.
#' @param x The manifest data frame, with columns `path` and `sha256`.
#' @param what The manifest's argument name, quoted when a column is missing.
#' @return A data frame: resource, sha256 and size_bytes.
#' @noRd
.bl_mnf_from_frame <- function(x, what) {
  if (!all(c("path", "sha256") %in% names(x))) {
    stop(
      .rmbl_fn(),
      sprintf("`%s`: a data frame needs the columns path and sha256", what),
      call. = FALSE
    )
  }
  size <- if ("size_bytes" %in% names(x)) {
    as.numeric(x[["size_bytes"]])
  } else {
    rep(NA_real_, nrow(x))
  }
  data.frame(
    resource = as.character(x[["path"]]),
    sha256 = as.character(x[["sha256"]]),
    size_bytes = size,
    stringsAsFactors = FALSE
  )
}

#' A manifest given as a provenance record or a capsule bundle.
#' @param x The record, as a list.
#' @return A data frame: resource, sha256 and size_bytes.
#' @noRd
.bl_mnf_from_list <- function(x) {
  ents <- if (!is.null(x[["files"]])) {
    x[["files"]]
  } else if (is.list(x[["resource"]])) {
    list(x[["resource"]])
  }
  s1 <- function(v) {
    v <- unlist(v)
    if (length(v) && !is.na(v[[1L]])) as.character(v[[1L]]) else NA_character_
  }
  data.frame(
    resource = vapply(
      ents,
      function(e) {
        if (is.na(s1(e[["path"]]))) s1(e[["filename"]]) else s1(e[["path"]])
      },
      ""
    ),
    sha256 = vapply(ents, function(e) s1(e[["sha256"]]), ""),
    size_bytes = as.numeric(vapply(
      ents,
      function(e) s1(e[["size_bytes"]]),
      ""
    )),
    stringsAsFactors = FALSE
  )
}

#' Writes the fetched bytes as the capsule's data file and the provenance that
#' pins them.
#'
#' Refused when the data file is not a plain relative path inside the capsule,
#' or when the new data (a CSV) fail the schema the old provenance pins
#' (valsch(), a fatal issue).
#' @param dir The capsule directory the data file and provenance are written in.
#' @param f The fetch result of .bl_fetch_pin(): the bytes and new provenance.
#' @return The data file's path, invisibly.
#' @noRd
.bl_write_pin <- function(dir, f) {
  dest <- .rmbl_safe_rel(f$new[["resource"]][["filename"]], dir)
  if (is.null(dest)) {
    stop(
      .rmbl_fn(),
      "resource$filename is not a plain relative path inside the capsule: ",
      .rmbl_printable(f$new[["resource"]][["filename"]]),
      call. = FALSE
    )
  }
  # the provenance is written in place: a link to a file outside the capsule was
  # written through (audit of 30bed8e, #8)
  pf <- .rmbl_safe_rel("data_provenance.json", dir)
  if (is.null(pf)) {
    stop(
      .rmbl_fn(),
      "data_provenance.json is a link out of the capsule: not written",
      call. = FALSE
    )
  }
  cur <- if (grepl("\\.csv$", dest, ignore.case = TRUE)) {
    .bl_read_csv_capped(f$path)
  }
  issues <- if (is.data.frame(cur)) valsch(cur, f$old)
  fatal <- vapply(issues, function(i) identical(i$severity, "fatal"), NA)
  if (any(fatal)) {
    stop(
      .rmbl_fn(),
      "the new data fail the pinned schema: ",
      paste(vapply(issues[fatal], `[[`, "", "message"), collapse = "; "),
      call. = FALSE
    )
  }
  # serialised first: nothing is written unless both can be
  js <- tojs(
    f$new,
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null",
    digits = NA
  )
  if (!identical(.rmbl_realpath(f$path), .rmbl_realpath(dest))) {
    file.copy(f$path, dest, overwrite = TRUE)
  }
  writeLines(js, pf)
  invisible(dest)
}

#' A capsule's remote source, fetched: live or its pinned Wayback copy, then
#' the archive's copy of the pinned bytes, then an earlier run's cache.
#' @param src The https:// source URL to fetch.
#' @param prov The capsule's provenance, which may pin a Wayback copy.
#' @param cache,archive As for .bl_fetch_pin().
#' @return A list: got, cached, archived and tmp.
#' @noRd
.bl_fetch_remote <- function(src, prov, cache, archive) {
  s1 <- .bl_s1
  archived <- FALSE
  # a source in a capsule (a pull request's, in the action) is fetched over
  # https only (audit of 30bed8e, #6)
  if (!grepl("^https://", src, ignore.case = TRUE)) {
    stop(
      .rmbl_fn(),
      "a source to fetch must be an https:// URL: ",
      .rmbl_printable(src),
      call. = FALSE
    )
  }
  got <- tempfile(fileext = paste0(".", tools::file_ext(src)))
  # the Wayback copy the provenance pins, and no other: an unpinned source
  # that answered 404 was looked up in the archive without being asked (audit
  # of 30bed8e, #17)
  ok <- tryCatch(
    fdl(src, got, attwb = s1(prov[["wayback"]][["csv_snapshot"]]) %||% ""),
    error = function(e) e
  )
  # then the copy kept on archive.rmorie.com with the pinned bytes, before an
  # earlier run's cache
  pin <- s1(prov[["resource"]][["sha256"]]) %||% ""
  if (!isTRUE(ok) && isTRUE(archive) && nzchar(pin)) {
    archived <- .bl_fetch_archived(src, got, pin)
    if (archived) {
      ok <- TRUE
    }
  }
  keep <- if (!is.null(cache)) {
    file.path(
      cache,
      paste0("source-", substr(csha256(charToRaw(src)), 1L, 16L))
    )
  }
  if (isTRUE(ok) && !is.null(keep)) {
    file.copy(got, keep, overwrite = TRUE)
  }
  if (!isTRUE(ok)) {
    unlink(got)
    .bl_fetch_unfetched(ok, keep, src)
    # an earlier run's copy, kept in the cache: not a temporary file
    return(list(got = keep, cached = TRUE, archived = archived, tmp = FALSE))
  }
  list(got = got, cached = FALSE, archived = archived, tmp = TRUE)
}

#' Fetches a source's copy kept on archive.rmorie.com with the pinned bytes.
#' @param src The source URL whose archive.rmorie.com copy is fetched.
#' @param got The file to write.
#' @param pin The pinned SHA-256.
#' @return TRUE when the copy was fetched.
#' @noRd
.bl_fetch_archived <- function(src, got, pin) {
  unlink(got)
  a <- tryCatch(arcget(src, got, sha256 = pin), error = function(e) {
    .bl_unless_interrupted(e, NULL)
  })
  !is.null(a) && file.exists(got)
}

#' Stops when a source could not be fetched and no earlier copy is cached.
#' @param ok The fetch's result: an error, or another value that is not TRUE.
#' @param keep The cached copy's path, or NULL.
#' @param src The source URL, shown when it could not be fetched.
#' @return NULL, invisibly, when the cached copy can stand in.
#' @noRd
.bl_fetch_unfetched <- function(ok, keep, src) {
  if (is.null(keep) || !file.exists(keep)) {
    if (inherits(ok, "error")) {
      stop(ok)
    }
    stop(
      .rmbl_fn(),
      "the source could not be fetched: ",
      .rmbl_printable(src),
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' Fetches a capsule's source and builds the provenance that pins it, without
#' writing anything.
#'
#' An https:// source is downloaded; a local path or a file:// URL is read where
#' it is, when .bl_local_source() admits it. A failed download falls back on the
#' provenance's own Wayback snapshot, else on the copy kept in `cache` by an
#' earlier fetch.
#' @param dir The capsule directory holding data_provenance.json.
#' @param allowfile FALSE, TRUE or a folder, from .bl_allowfile_arg().
#' @param cache The cache folder, or NULL.
#' @param root The folder `allowfile = TRUE` admits (the folder checked; the
#'   capsule by default).
#' @return A list: `old` and `new` provenance, `path` (the fetched file),
#'   `src` (the source), `cached` (whether the cached copy stood in) and
#'   `tmp` (whether `path` is a download to delete).
#' @noRd
.bl_fetch_pin <- function(
  dir,
  allowfile = FALSE,
  cache = NULL,
  root = dir,
  archive = FALSE
) {
  prov <- loadprov(file.path(dir, "data_provenance.json"))
  if (is.null(prov)) {
    stop(.rmbl_fn(), "no data_provenance.json in ", dir, call. = FALSE)
  }
  s1 <- .bl_s1
  src <- s1(prov[["resource"]][["direct_url"]]) %||%
    s1(prov[["source"]][["url"]]) %||%
    ""
  if (!nzchar(src) || startsWith(src, "TODO")) {
    stop(
      .rmbl_fn(),
      "the provenance names no source to fetch (resource$direct_url or ",
      "source$url)",
      call. = FALSE
    )
  }
  cached <- FALSE
  archived <- FALSE
  tmp <- FALSE
  if (
    grepl("^file://", src, ignore.case = TRUE) ||
      !grepl("^[A-Za-z][A-Za-z0-9+.-]*://", src)
  ) {
    got <- .bl_local_source(src, dir, allowfile, root)
  } else {
    r <- .bl_fetch_remote(src, prov, cache, archive)
    got <- r$got
    cached <- r$cached
    archived <- r$archived
    tmp <- r$tmp
  }
  f <- list(
    old = prov,
    path = got,
    src = src,
    cached = cached,
    archived = archived,
    tmp = tmp
  )
  f$new <- tryCatch(
    .bl_pin(prov, got, s1(prov[["resource"]][["filename"]]) %||% basename(src)),
    error = function(e) {
      .bl_fetch_cleanup(f)
      stop(e)
    }
  )
  f
}

#' Deletes the download behind a .bl_fetch_pin() result, when it was one.
#' @param f A .bl_fetch_pin() result; its `path` is deleted when `tmp`.
#' @return NULL, invisibly.
#' @noRd
.bl_fetch_cleanup <- function(f) {
  if (isTRUE(f$tmp)) {
    unlink(f$path)
  }
  invisible(NULL)
}

#' The `allowfile` argument: FALSE, TRUE, or an existing folder (its real path).
#' @param allowfile The value.
#' @return FALSE, TRUE or the folder.
#' @noRd
.bl_allowfile_arg <- function(allowfile) {
  if (is.logical(allowfile) && length(allowfile) == 1L && !is.na(allowfile)) {
    return(allowfile)
  }
  if (
    !is.character(allowfile) ||
      length(allowfile) != 1L ||
      is.na(allowfile) ||
      !dir.exists(allowfile)
  ) {
    stop(
      .rmbl_fn(),
      "`allowfile` must be TRUE or FALSE, or an existing folder",
      call. = FALSE
    )
  }
  real <- normalizePath(allowfile, winslash = "/", mustWork = TRUE)
  if (grepl("^([A-Za-z]:)?/*$", real)) {
    stop(
      .rmbl_fn(),
      "`allowfile` must not be the root of the file system",
      call. = FALSE
    )
  }
  real
}

#' The file a local capsule source names, when it may be read: its real path.
#'
#' A source is attacker-authored input (a capsule in a pull request): a bare
#' path read any file the job could, /proc/self/environ and its secrets
#' included, into the report (audit of 30bed8e, #6). The path, relative to the
#' capsule unless absolute, is resolved with its symbolic links, and must be a
#' file inside the capsule, inside the `allowfile` folder (the folder checked,
#' for TRUE) or in the package's extdata (the template's example source); never
#' under /proc, /sys or /dev. ponytail: resolved once and read after; a link
#' swapped in between is not looked at again.
#' @param src The source as the provenance names it.
#' @param dir The capsule directory, always an allowed folder for the source.
#' @param allowfile FALSE, TRUE or a folder.
#' @param root The folder `allowfile = TRUE` admits.
#' @return The file's real path.
#' @noRd
.bl_local_source <- function(src, dir, allowfile, root) {
  is_file <- grepl("^file://", src, ignore.case = TRUE)
  if (is_file && isFALSE(allowfile)) {
    stop(
      .rmbl_fn(),
      "the source is a file:// URL and `allowfile` is FALSE: ",
      .rmbl_printable(src),
      call. = FALSE
    )
  }
  p <- .bl_local_path(src, is_file, dir)
  real <- if (file.exists(p) && !dir.exists(p)) {
    tryCatch(
      normalizePath(p, winslash = "/", mustWork = TRUE),
      error = function(e) NULL
    )
  }
  roots <- .bl_local_roots(dir, allowfile, root)
  if (
    is.null(real) ||
      !any(startsWith(real, paste0(roots, "/"))) ||
      grepl("^/(proc|sys|dev)(/|$)", real)
  ) {
    stop(
      .rmbl_fn(),
      "a local source must be a file inside the capsule",
      if (!isFALSE(allowfile)) " or the `allowfile` folder",
      ": ",
      .rmbl_printable(src),
      call. = FALSE
    )
  }
  real
}

#' The path a local source names, relative paths taken from the capsule.
#' @param src The source.
#' @param is_file Whether it is a file:// URL.
#' @param dir The capsule directory a relative source path is taken from.
#' @return The expanded path.
#' @noRd
.bl_local_path <- function(src, is_file, dir) {
  p <- src
  if (is_file) {
    p <- utils::URLdecode(sub(
      "^file://(localhost)?",
      "",
      src,
      ignore.case = TRUE
    ))
    p <- sub("^/([A-Za-z]:)", "\\1", p)
  }
  if (!grepl("^([/\\\\]|~|[A-Za-z]:)", p)) {
    p <- file.path(dir, p)
  }
  path.expand(p)
}

#' The folders a local source may lie in.
#' @param dir The capsule directory, the first allowed folder.
#' @param allowfile,root As for .bl_local_source().
#' @return The folders, normalised, without a trailing slash.
#' @noRd
.bl_local_roots <- function(dir, allowfile, root) {
  roots <- c(
    dir,
    if (isTRUE(allowfile)) {
      root
    } else if (is.character(allowfile)) {
      allowfile
    },
    system.file("extdata", package = "rmoriebricklayer")
  )
  sub(
    "/+$",
    "",
    normalizePath(roots[nzchar(roots)], winslash = "/", mustWork = FALSE)
  )
}

#' Reads a capsule's CSV, inflating a gzip file no further than the option
#' rmoriebricklayer.maxcsvbytes.
#'
#' read.csv() inflates gzip itself, with no limit: a 388 KB gzip of 400 MB of
#' zeros ran for more than 400 s at 1.3 GB (audit of 30bed8e, #9). Only reading
#' errors give NULL; the limit is an error.
#' @param p The CSV file to read, plain or gzip-compressed.
#' @return A data frame, or NULL when the file does not read as a CSV.
#' @noRd
.bl_read_csv_capped <- function(p) {
  plain <- .bl_gunzip_capped(p)
  if (!identical(plain, p)) {
    on.exit(unlink(plain), add = TRUE)
  }
  tryCatch(
    utils::read.csv(plain, check.names = FALSE, stringsAsFactors = FALSE),
    error = function(e) NULL
  )
}

#' A gzip file inflated into a temporary file of at most the option
#' rmoriebricklayer.maxcsvbytes, or the file itself when it is not gzip.
#'
#' The trailer's ISIZE is checked first (free, but it can lie), then the bytes
#' are counted as they are inflated, 4 MiB at a time.
#' @param p The file to inflate when it starts with the gzip magic bytes.
#' @return The path of the plain bytes.
#' @noRd
.bl_gunzip_capped <- function(p) {
  head <- readBin(p, "raw", 2L)
  if (
    length(head) < 2L ||
      head[[1L]] != as.raw(0x1f) ||
      head[[2L]] != as.raw(0x8b)
  ) {
    return(p)
  }
  n <- file.size(p)
  lim <- .rmbl_max_csv_bytes(n)
  if (n >= 18) {
    con <- file(p, "rb")
    seek(con, n - 4)
    isize <- sum(as.numeric(as.integer(readBin(con, "raw", 4L))) * 256^(0:3))
    close(con)
    if (isize > lim) .bl_gunzip_over(p, lim)
  }
  out <- tempfile(fileext = ".csv")
  ok <- FALSE
  on.exit(if (!ok) unlink(out), add = TRUE)
  .bl_gunzip_copy(p, out, lim)
  ok <- TRUE
  out
}

#' Stops: a gzip file inflates past the byte cap.
#' @param p The gzip file, named by its base name in the error.
#' @param lim The cap.
#' @return Does not return.
#' @noRd
.bl_gunzip_over <- function(p, lim) {
  stop(
    .rmbl_fn(),
    sprintf(
      paste0(
        "%s inflates to more than %s bytes (options ",
        "rmoriebricklayer.maxcsvbytes and rmoriebricklayer.maxgzratio)"
      ),
      basename(p),
      format(lim, big.mark = ",", scientific = FALSE)
    ),
    call. = FALSE
  )
}

#' Inflates a gzip file into another, stopping past the byte cap.
#' @param p The gzip file.
#' @param out The file to write.
#' @param lim The cap.
#' @return NULL, invisibly.
#' @noRd
.bl_gunzip_copy <- function(p, out, lim) {
  # a directory is refused by name: gzfile() on one hung (1.0.3)
  p <- .rmbl_file1(p, "path")
  inp <- gzfile(p, "rb")
  dst <- file(out, "wb")
  total <- 0
  tryCatch(
    repeat {
      b <- readBin(inp, "raw", 4194304L)
      if (!length(b)) {
        break
      }
      total <- total + length(b)
      if (total > lim) {
        .bl_gunzip_over(p, lim)
      }
      writeBin(b, dst)
    },
    finally = {
      close(inp)
      close(dst)
    }
  )
  invisible(NULL)
}

#' A provenance record pinned to a data file's bytes, in the fields
#' usecpstmpl()'s analysis.R writes.
#'
#' source$sha256 (when there is a source block), resource$filename, sha256,
#' size_bytes and retrieved_utc, and row_count_data_rows when it was recorded.
#' @param prov The provenance record.
#' @param got The data file.
#' @param filename The name the capsule keeps it under.
#' @return The pinned record.
#' @noRd
.bl_pin <- function(prov, got, filename) {
  digest <- sha256file(got)
  if (is.list(prov[["source"]])) {
    prov[["source"]][["sha256"]] <- digest
  }
  had_rows <- !is.null(prov[["resource"]][["row_count_data_rows"]])
  prov$resource$filename <- filename
  prov$resource$sha256 <- digest
  prov$resource$size_bytes <- file.size(got)
  prov$resource$retrieved_utc <- format(
    Sys.time(),
    "%Y-%m-%dT%H:%M:%SZ",
    tz = "UTC"
  )
  if (had_rows) {
    d <- .bl_read_csv_capped(got)
    if (is.null(d)) {
      stop(
        .rmbl_fn(),
        "the source does not read as a CSV, so its rows cannot be counted",
        call. = FALSE
      )
    }
    prov$resource$row_count_data_rows <- nrow(d)
  }
  prov
}

# ---- the rows of rmbl verify / drift / report --------------------------------

#' The JSON type of a value as fromjs(simplifyVector = FALSE) returns it.
#' @param x The parsed JSON value whose type is named.
#' @return One string: null, empty, object, array, boolean, string, integer,
#'   number or unknown.
#' @noRd
.bl_json_type <- function(x) {
  if (is.null(x)) {
    return("null")
  }
  if (is.list(x)) {
    if (!length(x)) {
      return("empty")
    }
    return(
      if (!is.null(names(x)) && all(nzchar(names(x)))) "object" else "array"
    )
  }
  if (length(x) != 1L) {
    return("array")
  }
  if (is.logical(x)) {
    return("boolean")
  }
  if (is.character(x)) {
    return("string")
  }
  if (is.numeric(x)) {
    return(if (is.finite(x) && x == round(x)) "integer" else "number")
  }
  "unknown"
}

#' A JSON value's type against its schema's `type`.
#' @param t The value's JSON type.
#' @param s The schema.
#' @param at Where the value is.
#' @return The error, or NULL.
#' @noRd
.bl_schema_type_error <- function(t, s, at) {
  if (!is.null(s$type)) {
    want <- unlist(s$type)
    if (
      !any(
        want == t |
          (want == "number" & t == "integer") |
          (t == "empty" & want %in% c("object", "array"))
      )
    ) {
      return(sprintf(
        "%s: expected %s, got %s",
        at,
        paste(want, collapse = " or "),
        t
      ))
    }
  }
  NULL
}

#' A JSON scalar's errors against its schema: enum, pattern, minLength and
#' minimum.
#' @param x The JSON scalar checked against the schema's constraints.
#' @param t Its JSON type.
#' @param s The schema.
#' @param at Where the value is.
#' @return The errors.
#' @noRd
.bl_schema_scalar_errors <- function(x, t, s, at) {
  err <- character()
  if (!is.null(s$enum) && !(length(x) == 1L && x %in% unlist(s$enum))) {
    err <- c(
      err,
      sprintf(
        "%s: must be one of %s",
        at,
        toString(unlist(s$enum))
      )
    )
  }
  if (t == "string") {
    if (!is.null(s$pattern) && !grepl(s$pattern, x, perl = TRUE)) {
      err <- c(err, sprintf("%s: does not match %s", at, s$pattern))
    }
    if (!is.null(s$minLength) && nchar(x) < s$minLength) {
      err <- c(err, sprintf("%s: shorter than %d", at, s$minLength))
    }
  }
  if (t %in% c("integer", "number") && !is.null(s$minimum) && x < s$minimum) {
    err <- c(err, sprintf("%s: below %s", at, s$minimum))
  }
  err
}

#' Validates a parsed JSON value against a schema.
#'
#' The JSON Schema 2020-12 subset the shipped schemas use: type, enum, required,
#' properties, additionalProperties, items, pattern, minLength, minimum (as the
#' rmbl action's check.R).
#' @param x The value, from fromjs(simplifyVector = FALSE).
#' @param s The schema, parsed the same way.
#' @param at Where `x` sits in the document, for the messages.
#' @return A character vector of problems, empty when `x` is valid.
#' @noRd
.bl_schema_errors <- function(x, s, at = "$") {
  t <- .bl_json_type(x)
  bad <- .bl_schema_type_error(t, s, at)
  if (!is.null(bad)) {
    return(bad)
  }
  err <- .bl_schema_scalar_errors(x, t, s, at)
  if (t %in% c("object", "empty")) {
    miss <- setdiff(unlist(s$required), names(x))
    if (length(miss)) {
      err <- c(
        err,
        sprintf("%s: missing required %s", at, toString(miss))
      )
    }
  }
  if (t == "object") {
    for (nm in names(x)) {
      sub <- s$properties[[nm]] %||%
        (if (is.list(s$additionalProperties)) s$additionalProperties)
      if (!is.null(sub)) {
        err <- c(err, .bl_schema_errors(x[[nm]], sub, paste0(at, ".", nm)))
      }
    }
  }
  if (t == "array" && is.list(s$items)) {
    for (i in seq_along(x)) {
      err <- c(
        err,
        .bl_schema_errors(x[[i]], s$items, sprintf("%s[%d]", at, i - 1L))
      )
    }
  }
  err
}

#' Reads a JSON file for the schema check, keeping objects and arrays as lists.
#' @param path The JSON file to read for the schema check.
#' @return The parsed value.
#' @noRd
.bl_read_json_list <- function(path) .rmbl_read_json(path, simplify = FALSE)

#' One check row of the capsule verbs.
#' @param capsule The capsule directory.
#' @param part provenance, bundle, spec or drift.
#' @param file The file checked.
#' @param check The check's name, shown in the row's `check` column.
#' @param ok Whether the check passed, the row's `ok` column.
#' @param detail What was found, the row's `detail` column.
#' @param severity What a failure of the row is: error, drift, warn or note (a
#'   note changes no result).
#' @param line The line of `file` the row points at, or NA.
#' @return A data frame of one row (or as many as `check` has).
#' @noRd
.bl_check_row <- function(
  capsule,
  part,
  file,
  check,
  ok,
  detail,
  severity = "error",
  line = NA_integer_
) {
  data.frame(
    capsule = capsule,
    part = part,
    file = file,
    check = check,
    ok = ok,
    detail = detail,
    severity = severity,
    line = rep_len(as.integer(line), length(check)),
    stringsAsFactors = FALSE
  )
}

#' The schema row of one capsule file.
#' @param capsule The capsule directory.
#' @param path The capsule JSON file checked against `schema`.
#' @param schema The schema's name, for schemapath().
#' @return One check row.
#' @noRd
.bl_schema_row <- function(capsule, path, schema) {
  x <- tryCatch(.bl_read_json_list(path), error = function(e) e)
  err <- if (inherits(x, "error")) {
    paste("not valid JSON:", conditionMessage(x))
  } else {
    .bl_schema_errors(x, .bl_read_json_list(schemapath(schema)))
  }
  .bl_check_row(
    capsule,
    "spec",
    path,
    paste0("schema: ", basename(path)),
    !length(err),
    if (length(err)) {
      paste(utils::head(err, 5L), collapse = "; ")
    } else {
      paste0("valid against ", schema, ".schema.json")
    },
    line = if (length(err)) .bl_json_line(path, err[[1L]]) else NA_integer_
  )
}

#' The line of a JSON file a schema problem points at: the first line holding
#' its last key.
#'
#' ponytail: the first line with that key, not a JSON-pointer walk; a key
#' repeated earlier in the file points there. NA when the problem names no key
#' (a top-level one) or no line holds it.
#' @param path The JSON file whose lines are searched for the problem's key.
#' @param err One problem, such as `$.a.b[2].c: does not match`.
#' @return An integer.
#' @noRd
.bl_json_line <- function(path, err) {
  at <- gsub("\\[[0-9]+\\]", "", sub(":.*$", "", err))
  if (!grepl(".", at, fixed = TRUE)) {
    return(NA_integer_)
  }
  key <- sub("^.*\\.", "", at)
  hit <- grep(
    paste0("\"", key, "\"[[:space:]]*:"),
    readLines(path, warn = FALSE)
  )
  if (length(hit)) hit[[1L]] else NA_integer_
}

#' The rows of a vrfcps() or cpsbndlvrf() result, a required check never made
#' among them.
#' @param chk The result.
#' @param capsule The capsule directory.
#' @param part provenance or bundle.
#' @param file The file checked.
#' @return Check rows.
#' @noRd
.bl_result_rows <- function(chk, capsule, part, file) {
  ck <- chk$checks
  miss <- chk$missing %||% character()
  .bl_check_row(
    capsule,
    part,
    file,
    c(ck$check, miss),
    c(ck$ok, rep(FALSE, length(miss))),
    c(ck$detail, rep("required check was never made", length(miss)))
  )
}

#' The directories under a path that hold a capsule (a provenance or a bundle).
#' @param root The directory searched.
#' @param glob Only capsule files whose path matches this glob (its `*` also
#' matches \code{"/"}), or \code{""}.
#' @return Sorted directory paths.
#' @noRd
.bl_capsule_dirs <- function(root, glob = "") {
  f <- list.files(
    root,
    pattern = "^(data_provenance|capsule_bundle)\\.json$",
    recursive = TRUE,
    full.names = TRUE
  )
  f <- sub("^\\./", "", f)
  f <- f[!grepl("(^|/)(\\.git|\\.rmbl-cache)/", f)]
  if (nzchar(glob)) {
    f <- f[grepl(utils::glob2rx(glob), f)]
  }
  d <- sort(unique(dirname(f)))
  # one capsule once: list.files() follows a link back up the tree, and a loop
  # listed the same capsule under every depth the system allowed, a 209 KB
  # report (audit of 30bed8e, #17)
  d[!duplicated(normalizePath(d, winslash = "/", mustWork = FALSE))]
}

#' The verify rows of one capsule: every file against its schema, vrfcps(),
#' cpsbndlvrf().
#' @param d The capsule directory whose files are verified.
#' @param key The shared secret of an HMAC bundle, or \code{""}.
#' @param pubkey The public key (or HMAC key id) the bundle must be signed with,
#' or \code{""}.
#' @param pkgs The packages whose functions a ledger's checks may run, or NULL
#'   for all (ldgrchk()).
#' @param seen The XMSS signatures seen (xmssidxseen()), or NULL.
#' @return Check rows.
#' @noRd
.bl_verify_capsule <- function(
  d,
  key = "",
  pubkey = "",
  pkgs = NULL,
  seen = NULL
) {
  prov_file <- file.path(d, "data_provenance.json")
  bundle_file <- file.path(d, "capsule_bundle.json")
  rows <- list()
  for (sp in list(
    c(prov_file, "capsule"),
    c(bundle_file, "bundle"),
    c(file.path(d, "manifest.json"), "manifest"),
    c(file.path(d, "results", "manifest.json"), "manifest")
  )) {
    if (file.exists(sp[[1L]])) {
      rows[[length(rows) + 1L]] <- .bl_schema_row(d, sp[[1L]], sp[[2L]])
    }
  }
  if (file.exists(prov_file)) {
    rows[[length(rows) + 1L]] <- .bl_result_rows(
      vrfcps(d),
      d,
      "provenance",
      prov_file
    )
    # a proof ledger pinned in a capsule: its theorem rows and the pins of its
    # commit and build
    prov <- tryCatch(.bl_read_json_list(prov_file), error = function(e) NULL)
    if (identical(prov$kind, "ledger")) {
      rows[[length(rows) + 1L]] <- .bl_ldgr_capsule_rows(d, prov, pkgs)
    }
  }
  if (file.exists(bundle_file)) {
    bnd <- cpsbndlrd(bundle_file)
    # the secret goes to an hmac bundle only; the key id or public key is
    # checked for any scheme
    hmac <- identical(as.character(unlist(bnd$attestation$scheme))[1L], "hmac")
    chk <- cpsbndlvrf(
      bnd,
      d,
      keyexp = if (nzchar(pubkey)) pubkey,
      key = if (hmac && nzchar(key)) key,
      seen = seen
    )
    rows[[length(rows) + 1L]] <- .bl_result_rows(chk, d, "bundle", bundle_file)
  }
  do.call(rbind, rows)
}

#' The worst severity among failed rows.
#' @param sev The severities of the failed rows (or the results of capsules); a
#'   note counts as ok.
#' @return ok, warn, drift or error.
#' @noRd
.bl_worst <- function(sev) {
  r <- c("ok", "warn", "drift", "error")
  sev <- sev[sev != "note"]
  if (length(sev)) r[max(match(sev, r))] else "ok"
}

#' The summary-table cells of one capsule: source host, pinned digest, size,
#' rows, bounds.
#' @param d The capsule directory whose provenance and data file are read.
#' @return A list of strings.
#' @noRd
.bl_capsule_info <- function(d) {
  p <- tryCatch(
    loadprov(file.path(d, "data_provenance.json")),
    error = function(e) NULL
  )
  s1 <- function(v) {
    v <- unlist(v)
    if (length(v) && !is.na(v[[1L]])) as.character(v[[1L]])
  }
  res <- p[["resource"]]
  src <- s1(res[["direct_url"]]) %||% s1(p[["source"]][["url"]]) %||% ""
  host <- .bl_capsule_host(src)
  f <- .rmbl_safe_rel(s1(res[["filename"]]), d) %||% ""
  b <- if (file.exists(f) && !dir.exists(f)) file.size(f) else NA
  n <- suppressWarnings(as.numeric(s1(res[["row_count_data_rows"]]) %||% NA))
  rnd <- s1(p[["table"]][["rounding"]])
  sup <- s1(p[["table"]][["suppression_limit"]]) %||%
    s1(p[["table"]][["suplim"]])
  list(
    host = host,
    sha = if (is.null(s1(res[["sha256"]]))) {
      "-"
    } else {
      substr(s1(res[["sha256"]]), 1L, 12L)
    },
    size = .bl_capsule_size(b),
    rows = if (is.na(n)) "-" else format(n, big.mark = ","),
    bounds = .bl_capsule_bounds(rnd, sup)
  )
}

#' The host of a capsule's source, for the summary table.
#' @param src The source URL, or "".
#' @return One string.
#' @noRd
.bl_capsule_host <- function(src) {
  if (!nzchar(src)) {
    "-"
  } else if (startsWith(src, "file://")) {
    "local file"
  } else {
    sub("^[a-z]+://([^/:]+).*$", "\\1", src)
  }
}

#' A data file's size, for the summary table.
#' @param b The size in bytes, or NA.
#' @return One string.
#' @noRd
.bl_capsule_size <- function(b) {
  if (is.na(b)) {
    "-"
  } else if (b < 1024^2) {
    sprintf("%.1f KB", b / 1024)
  } else {
    sprintf("%.1f MB", b / 1024^2)
  }
}

#' A table's rounding and suppression, for the summary table.
#' @param rnd,sup The rounding base and suppression limit, or NULL.
#' @return One string.
#' @noRd
.bl_capsule_bounds <- function(rnd, sup) {
  if (is.null(rnd) && is.null(sup)) {
    "-"
  } else {
    paste(
      c(
        if (!is.null(rnd)) paste("round", rnd),
        if (!is.null(sup)) paste("supp", sup)
      ),
      collapse = " \u00b7 "
    )
  }
}

#' A capsule verb's directory, and its options' values, checked.
#' @param verb,rest,flag,usage_error As for .bl_cli_capsule().
#' @return The directory.
#' @noRd
.bl_capsule_root <- function(verb, rest, flag, usage_error) {
  pos <- rest
  for (f in c(.bl_capsule_valued, "--html")) {
    i <- match(f, pos)
    if (!is.na(i)) pos <- pos[-c(i, i + 1L)]
  }
  pos <- pos[
    !pos %in%
      c(
        "--json",
        "--allow-file",
        "--snapshot",
        "--no-footprint",
        "--overwrite",
        "--app"
      )
  ]
  if (length(pos) != 1L) {
    usage_error(sub("\n$", "", .bl_verb_usage(verb, .bl_prog())))
  }
  root <- pos[[1L]]
  if (!dir.exists(root)) {
    usage_error(sprintf("%s is not a directory", .rmbl_printable(root)))
  }
  # an option given an empty value is a mistake, not the option left out:
  # `--public-key ""` (an unset CI variable) verified a self-signed bundle as if
  # no key were pinned (audit of 30bed8e, #10)
  for (f in c(.bl_capsule_valued, "--html")) {
    if (identical(flag(f), "")) {
      usage_error(sprintf("%s was given an empty value", f))
    }
  }
  root
}

#' A capsule verb's --fail-on and --format, checked.
#' @param rest,flag,usage_error As for .bl_cli_capsule().
#' @return A list: fail_on and fmt.
#' @noRd
.bl_capsule_output <- function(rest, flag, usage_error) {
  fail_on <- flag("--fail-on") %||% "error"
  if (!fail_on %in% c("error", "drift", "warn")) {
    usage_error(sprintf(
      "--fail-on takes error, drift or warn, not '%s'",
      .rmbl_printable(fail_on)
    ))
  }
  fmt <- flag("--format") %||% (if ("--json" %in% rest) "json" else "md")
  if (!fmt %in% c("md", "json")) {
    usage_error(sprintf(
      "--format takes md or json, not '%s'",
      .rmbl_printable(fmt)
    ))
  }
  list(fail_on = fail_on, fmt = fmt)
}

#' Runs the capsule verbs: verify, drift, report and refresh.
#'
#' The HMAC secret of a bundle is read from RMBL_KEY and removed from the
#' environment at once, so no child process inherits it. Exit status: 0, or 1
#' when the worst failed row is at or above --fail-on (report never fails); a
#' usage error is raised for blcli() to turn into 2.
#' @param verb The capsule verb: verify, drift, report, refresh or sign.
#' @param rest The command-line arguments after the verb.
#' @param flag A function that returns a command-line option's value, or NULL.
#' @param out The function that prints the capsule verb's output.
#' @param usage_error A function that raises a usage error for a bad option.
#' @return The exit status.
#' @noRd
.bl_cli_capsule <- function(verb, rest, flag, out, usage_error) {
  # the secret is taken out of the process first, before any usage error can
  # return with it still set: its bytes are wiped, then the name unset (audit of
  # 30bed8e, #17)
  key <- Sys.getenv("RMBL_KEY")
  .Call(C_rmbl_env_wipe, "RMBL_KEY")
  Sys.unsetenv("RMBL_KEY")
  root <- .bl_capsule_root(verb, rest, flag, usage_error)
  o <- .bl_capsule_output(rest, flag, usage_error)
  fail_on <- o$fail_on
  fmt <- o$fmt
  if (verb == "refresh") {
    return(.bl_cli_refresh(root, out))
  }
  if (verb == "sign") {
    return(.bl_cli_sign(root, key, flag, rest, fmt, fail_on, out, usage_error))
  }
  res <- .bl_cli_check(root, verb, key, flag, rest, usage_error)
  out(format(res, fmt = fmt, failon = if (verb != "report") fail_on))
  html <- flag("--html")
  drifts <- attr(res, "drifts")
  if (verb == "drift" && !is.null(html)) {
    .bl_cli_drift_html(drifts, html, if (fmt == "md") out else function(s) NULL)
  }
  if (verb == "drift" && "--app" %in% rest) {
    .bl_cli_drift_app(drifts, out)
  }
  rank <- c(ok = 0L, warn = 1L, drift = 2L, error = 3L)
  if (verb != "report" && rank[[res$status]] >= rank[[fail_on]]) 1L else 0L
}

#' Runs the checks behind rmbl verify, drift and report.
#' @param root The capsule root.
#' @param verb The check verb passed to cpschk(): verify, drift or report.
#' @param key The secret key, or "".
#' @param flag The command line's flag reader.
#' @param rest The command line's arguments.
#' @param usage_error The usage-error function.
#' @return cpschk()'s result.
#' @noRd
.bl_cli_check <- function(root, verb, key, flag, rest, usage_error) {
  num <- function(f, default) {
    v <- flag(f)
    if (is.null(v)) default else suppressWarnings(as.numeric(v))
  }
  # a refused argument (a PSI band that is not a number, a --base that does not
  # exist) is a usage error
  tryCatch(
    cpschk(
      root,
      verb,
      key = key,
      pubkey = flag("--public-key") %||% "",
      psiwarn = num("--psi-warn", 0.1),
      psifail = num("--psi-fail", 0.25),
      base = flag("--base"),
      cache = flag("--cache") %||% FALSE,
      allowfile = "--allow-file" %in% rest,
      snapshot = "--snapshot" %in% rest,
      glob = flag("--manifests") %||% "",
      fp = !"--no-footprint" %in% rest,
      seenlog = flag("--seen-log") %||% ""
    ),
    error = function(e) usage_error(sub("^cpschk: ", "", conditionMessage(e)))
  )
}

#' The options of the capsule verbs that take a value.
#' @noRd
.bl_capsule_valued <- c(
  "--fail-on",
  "--format",
  "--public-key",
  "--psi-warn",
  "--psi-fail",
  "--base",
  "--cache",
  "--manifests",
  "--scheme",
  "--key-file",
  "--seen-log",
  "--state-file",
  "--sectors",
  "--sector",
  "--sector-index",
  "--reserve",
  "--warn-left"
)

#' The options verify, drift and report share (the first take a value).
#' @noRd
.bl_capsule_opts <- c(
  "--public-key",
  "--psi-warn",
  "--psi-fail",
  "--base",
  "--cache",
  "--manifests",
  "--allow-file",
  "--snapshot",
  "--no-footprint",
  "--seen-log"
)

#' The sign verb: cpsseal() on every capsule under a path, then the verify
#' report.
#'
#' The key is RMBL_KEY (already read and removed from the environment) or the
#' contents of --key-file, never printed: for HMAC the shared secret; for a
#' standardised scheme the JSON fipskg() writes (scheme, public, secret) or the
#' secret key's hex with --public-key; for xmss-sha256 the JSON of a pqckg()
#' key, whose state is reserved in the key file (or --state-file) before
#' anything is signed.
#' @param root The directory searched.
#' @param key The value of RMBL_KEY, or \code{""}.
#' @param flag,usage_error,out As for .bl_cli_capsule().
#' @param rest The arguments after the sign verb, read for `--overwrite`.
#' @param fmt md or json, for the verify report.
#' @param fail_on The fail-on level of the verify that follows.
#' @return The exit status.
#' @noRd
.bl_cli_sign <- function(
  root,
  key,
  flag,
  rest,
  fmt,
  fail_on,
  out,
  usage_error
) {
  scheme <- flag("--scheme") %||% "hmac"
  kf <- flag("--key-file")
  key <- .bl_cli_sign_key(key, kf, usage_error)
  glob <- flag("--manifests") %||% ""
  overwrite <- "--overwrite" %in% rest
  pub <- flag("--public-key") %||% ""
  xs <- NULL
  if (identical(scheme, "xmss-sha256")) {
    xs <- .bl_cli_xmss_reserve(
      root,
      key,
      kf,
      flag,
      overwrite,
      glob,
      usage_error
    )
    if (inherits(xs, "error")) {
      return(.bl_cli_sign_fail(xs, out))
    }
    sk <- xs$key
    sk$next_index <- xs$from
    pub <- paste0(sk$root, .rmbl_xkey(sk, "pubseed"))
    # the block is this run's to sign from; the configuration directory is not
    # used
    assign(xs$id, c(xs$from, xs$to), envir = .rmbl_xmss_block)
    on.exit(rm(list = xs$id, envir = .rmbl_xmss_block), add = TRUE)
  } else {
    sp <- .bl_cli_sign_plain(scheme, key, pub, rest, usage_error)
    sk <- sp$sk
    pub <- sp$pub
  }
  res <- tryCatch(
    cpsseal(root, sk, overwrite = overwrite, glob = glob),
    error = function(e) e
  )
  if (inherits(res, "error")) {
    return(.bl_cli_sign_fail(res, out))
  }
  .bl_cli_sign_said(res, scheme, out)
  if (!is.null(xs)) {
    .bl_cli_xmss_report(xs, root, flag("--seen-log"), out)
  }
  .bl_cli_sign_check(root, scheme, key, pub, glob, flag, fmt, fail_on, out)
}

#' rmbl sign's key: from the environment, or from --key-file.
#' @param key The key from RMBL_KEY, or "".
#' @param kf The --key-file path, or NULL.
#' @param usage_error The usage-error function.
#' @return The key.
#' @noRd
.bl_cli_sign_key <- function(key, kf, usage_error) {
  if (!is.null(kf)) {
    if (!file.exists(kf) || dir.exists(kf)) {
      usage_error(sprintf("--key-file: no such file: %s", .rmbl_printable(kf)))
    }
    key <- sub(
      "[\r\n]+$",
      "",
      paste(readLines(kf, warn = FALSE), collapse = "\n")
    )
  }
  if (!nzchar(key)) {
    usage_error(
      "sign needs a key: RMBL_KEY in the environment, or --key-file FILE"
    )
  }
  key
}

#' Writes rmbl sign's error and returns its exit status.
#' @param e The error rmbl sign raised; its message is printed.
#' @param out The output function.
#' @return 1L.
#' @noRd
.bl_cli_sign_fail <- function(e, out) {
  out(sprintf(
    "%s: %s\n",
    .bl_prog(),
    sub("^(blcli|xmssidxseen): ", "", conditionMessage(e))
  ))
  1L
}

#' rmbl sign's key for a scheme other than XMSS.
#' @param scheme The --scheme.
#' @param key The HMAC secret or private key for the non-XMSS scheme.
#' @param pub The --public-key, or "".
#' @param rest The command line's arguments.
#' @param usage_error The usage-error function.
#' @return A list: sk (the signing key) and pub (the public key, or "").
#' @noRd
.bl_cli_sign_plain <- function(scheme, key, pub, rest, usage_error) {
  xo <- intersect(
    c(
      "--state-file",
      "--sectors",
      "--sector",
      "--sector-index",
      "--reserve",
      "--warn-left"
    ),
    rest
  )
  if (length(xo)) {
    usage_error(sprintf("%s is for --scheme xmss-sha256 only", xo[[1L]]))
  }
  sk <- if (scheme == "hmac") {
    key
  } else {
    tryCatch(
      {
        if (startsWith(trimws(key), "{")) {
          j <- fromjs(key)
          fipskey(j$scheme %||% scheme, j$public, j$secret)
        } else {
          if (!nzchar(pub)) {
            usage_error(sprintf(
              "--scheme %s with a bare secret key needs --public-key HEX",
              scheme
            ))
          }
          fipskey(scheme, pub, key)
        }
      },
      bl_usage = function(e) stop(e),
      error = function(e) usage_error(paste("the key:", conditionMessage(e)))
    )
  }
  if (scheme != "hmac" && !nzchar(pub)) {
    pub <- sk$public
  }
  list(sk = sk, pub = pub)
}

#' Writes the line that says what rmbl sign signed.
#' @param res cpsseal()'s result.
#' @param scheme The --scheme.
#' @param out The output function.
#' @return NULL, invisibly.
#' @noRd
.bl_cli_sign_said <- function(res, scheme, out) {
  out(sprintf(
    "signed %s: %d files, %s %s%s\n",
    res$capsule,
    res$files,
    if (scheme == "hmac") {
      "hmac key id"
    } else {
      "public key"
    },
    substr(res$public, 1L, 16L),
    ifelse(res$pinned, " (provenance pinned)", "")
  ))
  invisible(NULL)
}

#' The XMSS state's file, checked: an absolute path to a writable regular
#' file (or a new one), or a key file that can be rewritten.
#' @param sf The --state-file, or NULL.
#' @param kf The --key-file, or NULL.
#' @param usage_error Raises a usage error.
#' @noRd
.bl_xmss_check_state_file <- function(sf, kf, usage_error) {
  writable <- function(f) {
    (!file.exists(f) || file.access(f, 2L) == 0L) &&
      file.access(dirname(f), 2L) == 0L
  }
  if (!is.null(sf)) {
    kind <- .Call(C_rmbl_path_kind, sf)
    why <- if (!grepl("^(/|[A-Za-z]:[/\\\\])", sf)) {
      "a relative path"
    } else if (kind == "directory") {
      "a directory"
    } else if (!kind %in% c("missing", "regular")) {
      "a device or other special file"
    } else if (!writable(sf)) {
      "not writable"
    }
    if (!is.null(why)) {
      usage_error(sprintf(
        paste(
          "--state-file must be an absolute path to a writable regular",
          "file, or to a new file",
          "in a writable directory: %s is %s"
        ),
        .rmbl_printable(sf),
        why
      ))
    }
  } else if (is.null(kf)) {
    usage_error(paste(
      "an xmss-sha256 key in RMBL_KEY needs --state-file FILE: the",
      "environment cannot keep the key's",
      "state, and a key signing from a fixed copy reuses its indices.",
      "Use ML-DSA in CI unless the",
      "state is kept in a file that persists"
    ))
  } else if (!writable(kf)) {
    usage_error(sprintf(
      paste(
        "--key-file %s cannot be rewritten (it, or its directory, is",
        "not writable, or the file",
        "system is read-only): an XMSS key file is the key's state and",
        "is rewritten before every",
        "signature (RFC 10033, section 4). Keep the state elsewhere",
        "with --state-file FILE"
      ),
      .rmbl_printable(kf)
    ))
  }
  invisible(NULL)
}

#' rmbl sign's sector, reserve and warning arguments for an XMSS key, checked.
#' @param flag The flag reader.
#' @param usage_error Raises a usage error.
#' @return A list: sec, reserve and warn.
#' @noRd
.bl_xmss_sector_args <- function(flag, usage_error) {
  int <- function(f, lo) {
    v <- flag(f)
    if (is.null(v)) {
      return(NULL)
    }
    x <- suppressWarnings(as.numeric(v))
    if (is.na(x) || x != floor(x) || x < lo || x >= 2^31) {
      usage_error(sprintf(
        "%s takes a whole number from %d, not '%s'",
        f,
        lo,
        .rmbl_printable(v)
      ))
    }
    as.integer(x)
  }
  sec <- list(
    count = int("--sectors", 2L),
    index = int("--sector-index", 0L),
    name = flag("--sector")
  )
  if (!is.null(sec$index) && !is.null(sec$name)) {
    usage_error("give --sector NAME or --sector-index I, not both")
  }
  if (!is.null(sec$count) && is.null(sec$index) && is.null(sec$name)) {
    usage_error(
      paste0(
        "--sectors K needs --sector NAME or --sector-index I: the sector ",
        "this run signs in"
      )
    )
  }
  reserve <- int("--reserve", 1L) %||% 1L
  warn <- int("--warn-left", 0L)
  list(sec = sec, reserve = reserve, warn = warn)
}

#' rmbl sign with an XMSS key: check the options, then reserve this run's
#' indices in the key's state.
#'
#' The state is the key file (rewritten atomically, under a lock) or
#' --state-file; RMBL_XMSS_INDEX_FILE is read and updated only when it is set.
#' Nothing is signed here: the reservation is durable before the first signature
#' exists (RFC 10033 section 4), and a refusal leaves the capsules as they were.
#' @param root The directory searched.
#' @param key The key's JSON text.
#' @param kf The key file, or NULL (the key came from RMBL_KEY).
#' @param flag,usage_error As for .bl_cli_capsule().
#' @param overwrite,glob As for cpsseal().
#' @return The reservation (.rmbl_xmss_state_commit() with `id` and `warn`), or
#'   the error that refused it.
#' @noRd
.bl_cli_xmss_reserve <- function(
  root,
  key,
  kf,
  flag,
  overwrite,
  glob,
  usage_error
) {
  sf <- flag("--state-file")
  .bl_xmss_check_state_file(sf, kf, usage_error)
  a <- .bl_xmss_sector_args(flag, usage_error)
  sec <- a$sec
  reserve <- a$reserve
  warn <- a$warn
  seenlog <- flag("--seen-log")
  tryCatch(
    {
      dirs <- .bl_seal_dirs(root, overwrite, glob)
      # every signature of this key seen under the path and in the log: a state
      # below them is a stale copy
      seen <- xmssidxseen(root, seenlog)
      ids <- .rmbl_xmss_ids(.rmbl_xmss_key_json(key, "the key")$key)
      p <- .rmbl_xmss_index_file(cli = TRUE)
      rec_hi <- if (is.null(p)) {
        -1L
      } else {
        .rmbl_xmss_highest(ids, .rmbl_xmss_record_read(p))
      }
      st <- .rmbl_xmss_state_commit(
        kf,
        sf,
        key,
        sec,
        max(reserve, length(dirs)),
        seen,
        rec_hi
      )
      if (!is.null(p)) {
        .rmbl_xmss_with_lock(p, function() {
          rec <- .rmbl_xmss_record_read(p)
          rec[ids$id] <- max(c(rec[ids$id], st$to), na.rm = TRUE)
          .rmbl_xmss_record_write(p, rec)
        })
      }
      c(st, list(id = ids$id, warn = warn %||% (st$size %/% 10L)))
    },
    error = function(e) e
  )
}

#' The lines rmbl sign prints about an XMSS key's state, and the seen-log it
#' appends to.
#' @param xs The reservation from .bl_cli_xmss_reserve().
#' @param root The directory signed.
#' @param seenlog The seen-log, or NULL.
#' @param out As for .bl_cli_capsule().
#' @return NULL, invisibly.
#' @noRd
.bl_cli_xmss_report <- function(xs, root, seenlog, out) {
  out(sprintf(
    paste0(
      "xmss state in %s: indices %d to %d reserved in sector %d of %d, ",
      "generation %d; %d left in the sector\n"
    ),
    xs$where,
    xs$from,
    xs$to,
    xs$sector,
    xs$count,
    xs$generation,
    xs$left
  ))
  if (nzchar(xs$prev) && xs$prev != xs$writer) {
    out(sprintf(
      paste(
        "note: the state was last written on another host (%s; this",
        "host is %s): copies of one",
        "key share one index space, so let one copy sign, or give each",
        "its own sector\n"
      ),
      xs$prev,
      xs$writer
    ))
  }
  if (xs$left <= xs$warn) {
    m <- sprintf(
      paste(
        "warning: signatures nearing exhaustion: %d left in sector %d",
        "of %d (--warn-left %d).",
        "Generate a new key before they run out\n"
      ),
      xs$left,
      xs$sector,
      xs$count,
      xs$warn
    )
    out(m)
    message(sub("\n$", "", m))
  }
  if (!is.null(seenlog)) {
    s <- xmssidxseen(root)
    .rmbl_xmss_seen_append(
      seenlog,
      s[s$key == xs$fpr & s$index >= xs$from & s$index <= xs$to, , drop = FALSE]
    )
  }
  invisible(NULL)
}

#' Writes the drift HTML report of every capsule whose columns were compared
#' (rmbl drift --html).
#'
#' One capsule writes `file`; several write `file` with each capsule's directory
#' name before the extension.
#' @param drifts The cpsdrft() results, named by capsule directory.
#' @param file The path given to --html.
#' @param out The function that prints a line (a no-op under --json, which must
#'   stay JSON).
#' @return The paths written, invisibly.
#' @noRd
.bl_cli_drift_html <- function(drifts, file, out) {
  if (!length(drifts)) {
    out(
      paste0(
        "\nNo columns were compared (every source matches its pin, or is ",
        "not a CSV): no HTML report written.\n"
      )
    )
    return(invisible(character()))
  }
  paths <- if (length(drifts) == 1L) {
    file
  } else {
    paste0(
      sub("\\.html?$", "", file, ignore.case = TRUE),
      "-",
      basename(names(drifts)),
      ".html"
    )
  }
  for (i in seq_along(drifts)) {
    drfthtml(
      drifts[[i]],
      paths[i],
      title = sprintf("Drift report: %s", basename(names(drifts)[i]))
    )
    out(sprintf("\nHTML report: %s\n", paths[i]))
  }
  invisible(paths)
}

#' Opens drftapp() on the first capsule whose columns were compared (rmbl drift
#' --app).
#' @param drifts The cpsdrft() results, named by capsule directory.
#' @param out The function that prints a line.
#' @return NULL, invisibly.
#' @noRd
.bl_cli_drift_app <- function(drifts, out) {
  if (!length(drifts)) {
    out(
      paste0(
        "\nNo columns were compared (every source matches its pin, or is ",
        "not a CSV): no app to open.\n"
      )
    )
    return(invisible(NULL))
  }
  dr <- drifts[[1L]]
  tabs <- attr(dr, "data")
  app <- drftapp(dr, ref = tabs$ref, cur = tabs$cur)
  out(sprintf("\nOpening the drift app on %s\n", names(drifts)[1L]))
  .bl_run_app(app)
  invisible(NULL)
}

#' The refresh verb: cpsrfrsh() on every capsule under a path that has a
#' provenance.
#' @param root The directory searched.
#' @param out The function that prints each capsule's refresh result.
#' @return The exit status: 1 when a capsule could not be refreshed.
#' @noRd
.bl_cli_refresh <- function(root, out) {
  dirs <- .bl_capsule_dirs(root)
  dirs <- dirs[file.exists(file.path(dirs, "data_provenance.json"))]
  if (!length(dirs)) {
    out(sprintf("no data_provenance.json under %s: nothing to refresh\n", root))
  }
  status <- 0L
  for (d in dirs) {
    r <- tryCatch(cpsrfrsh(d), error = function(e) e)
    if (inherits(r, "error")) {
      out(sprintf("%s: %s\n", d, conditionMessage(r)))
      status <- 1L
      next
    }
    out(sprintf("%s: %s\n", d, paste(.bl_mnfdiff_text(r), collapse = "\n")))
    if (
      any(r$change != "unchanged") &&
        file.exists(file.path(d, "capsule_bundle.json"))
    ) {
      out(sprintf(
        paste0(
          "%s: capsule_bundle.json no longer matches the data: sign it ",
          "again with cpsbndl()\n"
        ),
        d
      ))
    }
  }
  status
}

#' What a failed check row means and what to do, by the check's name.
#' @param check The check's name, as the capsule verbs report it.
#' @return One string.
#' @noRd
.bl_check_meaning <- function(check) {
  m <- c(.bl_check_meanings_data(), .bl_check_meanings_signed())
  if (check %in% names(m)) {
    return(m[[check]])
  }
  if (startsWith(check, "file:")) {
    return(
      paste0(
        "a bundled file is missing or its digest differs: restore it or ",
        "sign again"
      )
    )
  }
  if (startsWith(check, "schema: ")) {
    return(
      "the file does not follow its JSON Schema (schemapath()): see the detail"
    )
  }
  "a failed check: see the detail"
}

#' The meanings of the failed checks of a capsule's data and provenance.
#' @return A named character vector: check name to meaning.
#' @noRd
.bl_check_meanings_data <- function() {
  c(
    provenance_readable = paste0(
      "data_provenance.json is missing, outside the capsule or not valid ",
      "JSON"
    ),
    data_present = paste0(
      "the data file the provenance names (resource$filename) is not in ",
      "the capsule"
    ),
    data_sha256 = paste(
      "the data file's bytes differ from the pinned SHA-256: restore",
      "the file, or pin the",
      "new bytes with cpsrfrsh() (rmbl refresh)"
    ),
    data_size_bytes = paste0(
      "the data file's size differs from resource$size_bytes: its bytes ",
      "changed"
    ),
    data_readable = paste0(
      "the data file cannot be read as a CSV, so its row count and schema ",
      "cannot be checked"
    ),
    data_row_count = paste0(
      "the CSV has another number of rows than ",
      "resource$row_count_data_rows records"
    ),
    schema_valid = paste0(
      "the data fail the schema pinned in the provenance (valsch()): a ",
      "column renamed, gone or retyped"
    ),
    manifest_consistent = paste0(
      "a result in manifest.json no longer ",
      "gets its recorded PASS or DIFFER"
    ),
    script_sha256 = paste0(
      "the analysis script differs from its pinned digest: the code ",
      "changed since the results"
    ),
    data_not_synthetic = paste0(
      "the data are marked synthetic: a ",
      "capsule holds the real data"
    ),
    no_unlisted_files = paste0(
      "the capsule holds files the bundle does not cover: remove them or ",
      "sign again (cpsbndl())"
    )
  )
}

#' The meanings of the failed checks of a capsule's signature and source.
#' @return A named character vector: check name to meaning.
#' @noRd
.bl_check_meanings_signed <- function() {
  c(
    `attestation:signature` = paste(
      "the bundle's signature does not verify: the bundle was altered,",
      "or (hmac)",
      "the secret in RMBL_KEY is missing or wrong"
    ),
    `attestation:key_as_expected` = paste0(
      "the bundle was signed with another key than the one given ",
      "(--public-key)"
    ),
    `attestation:manifest_digest` = paste0(
      "the bundle's file list is not the ",
      "one the attestation signed"
    ),
    `attestation:attestation_complete` = paste0(
      "the attestation lacks a ",
      "field it needs"
    ),
    xmss_index = paste(
      "the key signed this XMSS index twice, with different signatures",
      "(xmssidxseen()): its state",
      "was copied or rolled back, so anyone can forge with it. Generate",
      "a new key"
    ),
    check_stopped = paste0(
      "the checks of this capsule stopped ",
      "with the error in the detail"
    ),
    source_fetched = "the source named in the provenance could not be fetched",
    source_digest = paste0(
      "the source serves other bytes than the pin: rmbl refresh pins them ",
      "(cpsrfrsh())"
    ),
    source_columns = paste(
      "the new source's columns drift from the pinned data (cpsdrft(),",
      "past the PSI bands):",
      "look before pinning it"
    ),
    refreshed = paste(
      "the new bytes were not pinned: the detail says why (a schema",
      "they fail, a data file",
      "outside the capsule)"
    )
  )
}

#' explerr() on check rows: each failed row, what it means and where its message
#' is raised.
#' @param rows A data frame with the columns check, ok and detail.
#' @param pkgs The packages to search for the messages, or NULL.
#' @return A data frame with the columns check, detail, explanation and
#'   raised_by.
#' @noRd
.bl_explain_rows <- function(rows, pkgs) {
  if (!all(c("check", "ok", "detail") %in% names(rows))) {
    stop(
      .rmbl_fn(),
      "a data frame of check rows needs the columns check, ok and ",
      "detail (as rmbl verify --json)",
      call. = FALSE
    )
  }
  ok <- as.logical(rows$ok)
  bad <- rows[is.na(ok) | !ok, , drop = FALSE]
  detail <- as.character(bad$detail)
  raised <- vapply(
    detail,
    function(m) {
      e <- if (nzchar(trimws(m))) explerr(m, pkgs = pkgs, n = 1L)
      if (NROW(e)) paste0(e$package, "::", e$raised_by) else NA_character_
    },
    "",
    USE.NAMES = FALSE
  )
  data.frame(
    check = as.character(bad$check),
    detail = detail,
    explanation = vapply(
      as.character(bad$check),
      .bl_check_meaning,
      "",
      USE.NAMES = FALSE
    ),
    raised_by = raised,
    stringsAsFactors = FALSE
  )
}

#' Checks the capsule rmbl sign just signed, and returns the exit status.
#' @param root The capsule root.
#' @param scheme The --scheme.
#' @param key,pub The secret and the public key.
#' @param glob The --manifests glob.
#' @param flag The command line's flag reader.
#' @param fmt,fail_on The output format and the failing severity.
#' @param out The output function.
#' @return 1L when the check fails at `fail_on` or worse, else 0L.
#' @noRd
.bl_cli_sign_check <- function(
  root,
  scheme,
  key,
  pub,
  glob,
  flag,
  fmt,
  fail_on,
  out
) {
  x <- cpschk(
    root,
    key = if (scheme == "hmac") key else "",
    pubkey = pub,
    glob = glob,
    fp = FALSE,
    seenlog = flag("--seen-log") %||% ""
  )
  out(format(x, fmt = fmt, failon = fail_on))
  rank <- c(ok = 0L, warn = 1L, drift = 2L, error = 3L)
  if (rank[[x$status]] >= rank[[fail_on]]) 1L else 0L
}
