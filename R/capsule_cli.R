# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Capsule checks for CI and the shell: the JSON Schemas of the capsule files, a resource diff
# between two manifests, re-pinning a capsule to its source, and the rows behind the verbs
# `rmbl verify`, `drift`, `refresh` and `report` (the checks the rmbl GitHub Action runs).

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
#' @examples
#' schemapath("capsule")
#' s <- fromjs(paste(readLines(schemapath("bundle")), collapse = "\n"))
#' s$required
#'
#' # only the three schemas exist
#' try(schemapath("nope"))
#' @export
schemapath <- function(name) {
  name <- .rmbl_string1(name, "name")
  base <- sub("\\.schema\\.json$", "", name)
  if (!base %in% c("capsule", "bundle", "manifest")) {
    stop(.rmbl_fn(), sprintf("`name` must be capsule, bundle or manifest, not '%s'", .rmbl_printable(name)),
         call. = FALSE)
  }
  system.file("schemas", paste0(base, ".schema.json"), package = "rmoriebricklayer", mustWork = TRUE)
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
#' @param ... Not used.
#' @return A data frame of class \code{rmbl_mnfdiff}, one row per resource
#'   in either manifest, with the columns \code{resource} (the file name),
#'   \code{change} (\code{"added"}, \code{"removed"}, \code{"changed"} or
#'   \code{"unchanged"}), \code{old_sha256}, \code{new_sha256},
#'   \code{old_size} and \code{new_size} (\code{NA} where not recorded).
#'   It prints the counts and one line per change. Errors: a manifest that
#'   is not a list, a data frame or a file; a data frame without
#'   \code{path} and \code{sha256}.
#' @seealso \code{\link{cpsrfrsh}}, \code{\link{cpsbndl}}.
#' @examples
#' a <- data.frame(path = c("a.csv", "b.csv"), sha256 = c("01", "02"),
#'                 size_bytes = c(10, 20))
#' b <- data.frame(path = c("a.csv", "c.csv"), sha256 = c("09", "03"),
#'                 size_bytes = c(12, 30))
#' d <- mnfdiff(a, b)
#' d
#' d$change
#'
#' # a provenance record and its re-pinned copy
#' p <- list(resource = list(filename = "a.csv", sha256 = "01", size_bytes = 10))
#' q <- p
#' q$resource$sha256 <- "09"
#' mnfdiff(p, q)$change
#'
#' try(mnfdiff(1, b))
#' @srrstats {G2.1} `old` and `new` are checked for type: a data frame must carry path and sha256, and
#'   anything but a list, a data frame or a file name is refused (test-capsule-cli.R).
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
  same <- (sa == sb) %in% TRUE | (is.na(sa) & is.na(sb))
  same_size <- is.na(za) | is.na(zb) | za == zb
  change <- ifelse(is.na(ia), "added", ifelse(is.na(ib), "removed",
                                              ifelse(same & same_size, "unchanged", "changed")))
  out <- data.frame(resource = keys, change = change, old_sha256 = sa, new_sha256 = sb,
                    old_size = za, new_size = zb, stringsAsFactors = FALSE)
  class(out) <- c("rmbl_mnfdiff", "data.frame")
  out
}

#' The resources of one manifest, as a data frame of resource, sha256 and size_bytes.
#' @param x A provenance record, a bundle, a data frame or a JSON file's path.
#' @param what The argument's name, for the error message.
#' @return A data frame.
#' @noRd
.bl_mnf_resources <- function(x, what) {
  if (is.character(x)) x <- .rmbl_read_json(.rmbl_file1(x, what), simplify = FALSE)
  if (is.data.frame(x)) {
    if (!all(c("path", "sha256") %in% names(x))) {
      stop(.rmbl_fn(), sprintf("`%s`: a data frame needs the columns path and sha256", what), call. = FALSE)
    }
    size <- if ("size_bytes" %in% names(x)) as.numeric(x[["size_bytes"]]) else rep(NA_real_, nrow(x))
    return(data.frame(resource = as.character(x[["path"]]), sha256 = as.character(x[["sha256"]]),
                      size_bytes = size, stringsAsFactors = FALSE))
  }
  if (!is.list(x)) {
    stop(.rmbl_fn(), sprintf(paste("`%s` must be a provenance record, a capsule bundle, a data frame of path",
                                   "and sha256, or the path of a JSON file"), what), call. = FALSE)
  }
  ents <- if (!is.null(x[["files"]])) x[["files"]] else if (is.list(x[["resource"]])) list(x[["resource"]])
  s1 <- function(v) {
    v <- unlist(v)
    if (length(v) && !is.na(v[[1L]])) as.character(v[[1L]]) else NA_character_
  }
  data.frame(resource = vapply(ents, function(e) if (is.na(s1(e[["path"]]))) s1(e[["filename"]]) else s1(e[["path"]]),
                               ""),
             sha256 = vapply(ents, function(e) s1(e[["sha256"]]), ""),
             size_bytes = as.numeric(vapply(ents, function(e) s1(e[["size_bytes"]]), "")),
             stringsAsFactors = FALSE)
}

#' @rdname mnfdiff
#' @export
format.rmbl_mnfdiff <- function(x, ...) {
  n <- table(factor(x$change, c("changed", "added", "removed", "unchanged")))
  ch <- x[x$change != "unchanged", , drop = FALSE]
  short <- function(s) ifelse(is.na(s), "-", substr(s, 1L, 12L))
  size <- function(z) ifelse(is.na(z), "-", format(z, big.mark = ",", scientific = FALSE, trim = TRUE))
  c(sprintf("Manifest diff: %d changed, %d added, %d removed, %d unchanged", n[["changed"]], n[["added"]],
            n[["removed"]], n[["unchanged"]]),
    if (nrow(ch)) sprintf("  %-9s %s  sha256 %s -> %s, %s -> %s bytes", ch$change, ch$resource, short(ch$old_sha256),
                          short(ch$new_sha256), size(ch$old_size), size(ch$new_size)))
}

#' @rdname mnfdiff
#' @export
print.rmbl_mnfdiff <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' Fetch a capsule's source again and pin the new bytes
#'
#' @description
#' Downloads the source named in a capsule's \code{data_provenance.json}
#' (\code{resource$direct_url}, else \code{source$url}; a local path is
#' read directly), and when its bytes differ from the pin writes them as the
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
#' as its fallback. A capsule bundle is not signed again: that needs your
#' key (\code{\link{cpsbndl}}). Side effects: writes the data file and
#' \code{data_provenance.json} in \code{dir}. Errors: \code{dir} is not a
#' directory or holds no provenance; the provenance names no source, or a
#' \code{TODO} one, or a \code{file://} one without \code{allowfile}; the
#' source cannot be fetched; \code{resource$filename} is not a plain
#' relative path inside \code{dir}; the new data fail the schema the
#' provenance pins (\code{\link{valsch}}).
#'
#' @param dir Character scalar, the capsule directory.
#' @param allowfile Logical: accept a \code{file://} source URL (a local
#'   path is always read).
#' @return The \code{\link{mnfdiff}} of the provenance before and after:
#'   all \code{"unchanged"} when the source still matches its pin.
#' @seealso \code{\link{mnfdiff}}, \code{\link{vrfcps}},
#'   \code{\link{usecpstmpl}}.
#' @examples
#' d <- usecpstmpl(tempfile("capsule-"), ex = TRUE)
#' cpsrfrsh(d)            # the first pin: the data file is added
#' vrfcps(d)$ok
#' cpsrfrsh(d)$change     # the source has not changed since
#'
#' try(cpsrfrsh(tempfile()))
#' @srrstats {G2.0} `dir` must be one existing directory, and the provenance's filename one plain relative path
#'   inside it (test-capsule-cli.R).
#' @export
cpsrfrsh <- function(dir, allowfile = FALSE) {
  dir <- .rmbl_string1(dir, "dir")
  allowfile <- .rmbl_flag1(allowfile, "allowfile")
  if (!dir.exists(dir)) stop(.rmbl_fn(), "`dir` is not an existing directory: ", dir, call. = FALSE)
  f <- .bl_fetch_pin(dir, allowfile)
  diff <- mnfdiff(f$old, f$new)
  if (all(diff$change == "unchanged")) return(diff)
  .bl_write_pin(dir, f)
  diff
}

#' Writes the fetched bytes as the capsule's data file and the provenance that pins them.
#'
#' Refused when the data file is not a plain relative path inside the capsule, or when the new data
#' (a CSV) fail the schema the old provenance pins (valsch(), a fatal issue).
#' @param dir The capsule directory.
#' @param f From .bl_fetch_pin().
#' @return The data file's path, invisibly.
#' @noRd
.bl_write_pin <- function(dir, f) {
  dest <- .rmbl_safe_rel(f$new[["resource"]][["filename"]], dir)
  if (is.null(dest)) {
    stop(.rmbl_fn(), "resource$filename is not a plain relative path inside the capsule: ",
         .rmbl_printable(f$new[["resource"]][["filename"]]), call. = FALSE)
  }
  cur <- if (grepl("\\.csv$", dest, ignore.case = TRUE)) {
    tryCatch(utils::read.csv(f$path, check.names = FALSE, stringsAsFactors = FALSE), error = function(e) NULL)
  }
  issues <- if (is.data.frame(cur)) valsch(cur, f$old)
  fatal <- vapply(issues, function(i) identical(i$severity, "fatal"), NA)
  if (any(fatal)) {
    stop(.rmbl_fn(), "the new data fail the pinned schema: ",
         paste(vapply(issues[fatal], `[[`, "", "message"), collapse = "; "), call. = FALSE)
  }
  # serialised first: nothing is written unless both can be
  js <- tojs(f$new, auto_unbox = TRUE, pretty = TRUE, null = "null", digits = NA)
  if (!identical(.rmbl_realpath(f$path), .rmbl_realpath(dest))) file.copy(f$path, dest, overwrite = TRUE)
  writeLines(js, file.path(dir, "data_provenance.json"))
  invisible(dest)
}

#' Fetches a capsule's source and builds the provenance that pins it, without writing anything.
#'
#' A failed fetch falls back on the copy kept in `cache` by an earlier fetch, when there is one.
#' @param dir The capsule directory.
#' @param allowfile Whether a file:// source URL is fetched.
#' @param cache The cache folder, or NULL.
#' @return A list: `old` and `new` provenance, `path` (the fetched file), `src` (the source) and
#'   `cached` (whether the cached copy stood in).
#' @noRd
.bl_fetch_pin <- function(dir, allowfile = FALSE, cache = NULL) {
  prov <- loadprov(file.path(dir, "data_provenance.json"))
  if (is.null(prov)) stop(.rmbl_fn(), "no data_provenance.json in ", dir, call. = FALSE)
  s1 <- function(v) {
    v <- unlist(v)
    if (length(v) && !is.na(v[[1L]])) as.character(v[[1L]])
  }
  src <- s1(prov[["resource"]][["direct_url"]]) %||% s1(prov[["source"]][["url"]]) %||% ""
  if (!nzchar(src) || startsWith(src, "TODO")) {
    stop(.rmbl_fn(), "the provenance names no source to fetch (resource$direct_url or source$url)", call. = FALSE)
  }
  got <- src
  cached <- FALSE
  if (!file.exists(src)) {
    is_file <- startsWith(src, "file://")
    if (is_file && !allowfile) {
      stop(.rmbl_fn(), "the source is a file:// URL and `allowfile` is FALSE: ", .rmbl_printable(src), call. = FALSE)
    }
    got <- tempfile(fileext = paste0(".", tools::file_ext(src)))
    ok <- tryCatch(fdl(src, got, attwb = if (is_file) "" else s1(prov[["wayback"]][["csv_snapshot"]]),
                       allowfile = is_file), error = function(e) e)
    keep <- if (!is.null(cache)) file.path(cache, paste0("source-", substr(csha256(charToRaw(src)), 1L, 16L)))
    if (isTRUE(ok) && !is.null(keep)) file.copy(got, keep, overwrite = TRUE)
    if (!isTRUE(ok)) {
      if (is.null(keep) || !file.exists(keep)) {
        if (inherits(ok, "error")) stop(ok)
        stop(.rmbl_fn(), "the source could not be fetched: ", .rmbl_printable(src), call. = FALSE)
      }
      got <- keep
      cached <- TRUE
    }
  }
  new <- prov
  digest <- sha256file(got)
  if (is.list(new[["source"]])) new[["source"]][["sha256"]] <- digest
  new$resource$filename <- s1(prov[["resource"]][["filename"]]) %||% basename(src)
  new$resource$sha256 <- digest
  new$resource$size_bytes <- file.size(got)
  new$resource$retrieved_utc <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (!is.null(prov[["resource"]][["row_count_data_rows"]])) {
    new$resource$row_count_data_rows <- nrow(utils::read.csv(got, check.names = FALSE))
  }
  list(old = prov, new = new, path = got, src = src, cached = cached)
}

# ---- the rows of rmbl verify / drift / report ---------------------------------------------

#' The JSON type of a value as fromjs(simplifyVector = FALSE) returns it.
#' @param x The value.
#' @return One string: null, empty, object, array, boolean, string, integer, number or unknown.
#' @noRd
.bl_json_type <- function(x) {
  if (is.null(x)) return("null")
  if (is.list(x)) {
    if (!length(x)) return("empty")
    return(if (!is.null(names(x)) && all(nzchar(names(x)))) "object" else "array")
  }
  if (length(x) != 1L) return("array")
  if (is.logical(x)) return("boolean")
  if (is.character(x)) return("string")
  if (is.numeric(x)) return(if (is.finite(x) && x == round(x)) "integer" else "number")
  "unknown"
}

#' Validates a parsed JSON value against a schema.
#'
#' The JSON Schema 2020-12 subset the shipped schemas use: type, enum, required, properties,
#' additionalProperties, items, pattern, minLength, minimum (as the rmbl action's check.R).
#' @param x The value, from fromjs(simplifyVector = FALSE).
#' @param s The schema, parsed the same way.
#' @param at Where `x` sits in the document, for the messages.
#' @return A character vector of problems, empty when `x` is valid.
#' @noRd
.bl_schema_errors <- function(x, s, at = "$") {
  t <- .bl_json_type(x)
  if (!is.null(s$type)) {
    want <- unlist(s$type)
    if (!any(want == t | (want == "number" & t == "integer") | (t == "empty" & want %in% c("object", "array")))) {
      return(sprintf("%s: expected %s, got %s", at, paste(want, collapse = " or "), t))
    }
  }
  err <- character()
  if (!is.null(s$enum) && !(length(x) == 1L && x %in% unlist(s$enum))) {
    err <- c(err, sprintf("%s: must be one of %s", at, paste(unlist(s$enum), collapse = ", ")))
  }
  if (t == "string") {
    if (!is.null(s$pattern) && !grepl(s$pattern, x, perl = TRUE)) {
      err <- c(err, sprintf("%s: does not match %s", at, s$pattern))
    }
    if (!is.null(s$minLength) && nchar(x) < s$minLength) err <- c(err, sprintf("%s: shorter than %d", at, s$minLength))
  }
  if (t %in% c("integer", "number") && !is.null(s$minimum) && x < s$minimum) {
    err <- c(err, sprintf("%s: below %s", at, s$minimum))
  }
  if (t %in% c("object", "empty")) {
    miss <- setdiff(unlist(s$required), names(x))
    if (length(miss)) err <- c(err, sprintf("%s: missing required %s", at, paste(miss, collapse = ", ")))
  }
  if (t == "object") {
    for (nm in names(x)) {
      sub <- s$properties[[nm]] %||% (if (is.list(s$additionalProperties)) s$additionalProperties)
      if (!is.null(sub)) err <- c(err, .bl_schema_errors(x[[nm]], sub, paste0(at, ".", nm)))
    }
  }
  if (t == "array" && is.list(s$items)) {
    for (i in seq_along(x)) err <- c(err, .bl_schema_errors(x[[i]], s$items, sprintf("%s[%d]", at, i - 1L)))
  }
  err
}

#' Reads a JSON file for the schema check, keeping objects and arrays as lists.
#' @param path The file.
#' @return The parsed value.
#' @noRd
.bl_read_json_list <- function(path) .rmbl_read_json(path, simplify = FALSE)

#' One check row of the capsule verbs.
#' @param capsule The capsule directory.
#' @param part provenance, bundle, spec or drift.
#' @param file The file checked.
#' @param check The check's name.
#' @param ok Whether it passed.
#' @param detail What was found.
#' @param severity What a failure of the row is: error, drift, warn or note (a note changes no result).
#' @param line The line of `file` the row points at, or NA.
#' @return A data frame of one row (or as many as `check` has).
#' @noRd
.bl_check_row <- function(capsule, part, file, check, ok, detail, severity = "error", line = NA_integer_) {
  data.frame(capsule = capsule, part = part, file = file, check = check, ok = ok, detail = detail,
             severity = severity, line = rep_len(as.integer(line), length(check)), stringsAsFactors = FALSE)
}

#' The schema row of one capsule file.
#' @param capsule The capsule directory.
#' @param path The file.
#' @param schema The schema's name, for schemapath().
#' @return One check row.
#' @noRd
.bl_schema_row <- function(capsule, path, schema) {
  x <- tryCatch(.bl_read_json_list(path), error = function(e) e)
  err <- if (inherits(x, "error")) paste("not valid JSON:", conditionMessage(x)) else
    .bl_schema_errors(x, .bl_read_json_list(schemapath(schema)))
  .bl_check_row(capsule, "spec", path, paste0("schema: ", basename(path)), !length(err),
                if (length(err)) paste(utils::head(err, 5L), collapse = "; ") else
                  paste0("valid against ", schema, ".schema.json"),
                line = if (length(err)) .bl_json_line(path, err[[1L]]) else NA_integer_)
}

#' The line of a JSON file a schema problem points at: the first line holding its last key.
#'
#' ponytail: the first line with that key, not a JSON-pointer walk; a key repeated earlier in the file
#' points there. NA when the problem names no key (a top-level one) or no line holds it.
#' @param path The file.
#' @param err One problem, such as `$.a.b[2].c: does not match`.
#' @return An integer.
#' @noRd
.bl_json_line <- function(path, err) {
  at <- gsub("\\[[0-9]+\\]", "", sub(":.*$", "", err))
  if (!grepl("\\.", at)) return(NA_integer_)
  key <- sub("^.*\\.", "", at)
  hit <- grep(paste0("\"", key, "\"[[:space:]]*:"), readLines(path, warn = FALSE))
  if (length(hit)) hit[[1L]] else NA_integer_
}

#' The rows of a vrfcps() or cpsbndlvrf() result, a required check never made among them.
#' @param chk The result.
#' @param capsule The capsule directory.
#' @param part provenance or bundle.
#' @param file The file checked.
#' @return Check rows.
#' @noRd
.bl_result_rows <- function(chk, capsule, part, file) {
  ck <- chk$checks
  miss <- chk$missing %||% character()
  .bl_check_row(capsule, part, file, c(ck$check, miss), c(ck$ok, rep(FALSE, length(miss))),
                c(ck$detail, rep("required check was never made", length(miss))))
}

#' The directories under a path that hold a capsule (a provenance or a bundle).
#' @param root The directory searched.
#' @param glob Only capsule files whose path matches this glob (its `*` also matches "/"), or "".
#' @return Sorted directory paths.
#' @noRd
.bl_capsule_dirs <- function(root, glob = "") {
  f <- list.files(root, pattern = "^(data_provenance|capsule_bundle)\\.json$", recursive = TRUE, full.names = TRUE)
  f <- sub("^\\./", "", f)
  f <- f[!grepl("(^|/)(\\.git|\\.rmbl-cache)/", f)]
  if (nzchar(glob)) f <- f[grepl(utils::glob2rx(glob), f)]
  sort(unique(dirname(f)))
}

#' The verify rows of one capsule: every file against its schema, vrfcps(), cpsbndlvrf().
#' @param d The capsule directory.
#' @param key The shared secret of an hmac bundle, or "".
#' @param pubkey The public key (or hmac key id) the bundle must be signed with, or "".
#' @return Check rows.
#' @noRd
.bl_verify_capsule <- function(d, key = "", pubkey = "") {
  prov_file <- file.path(d, "data_provenance.json")
  bundle_file <- file.path(d, "capsule_bundle.json")
  rows <- list()
  for (sp in list(c(prov_file, "capsule"), c(bundle_file, "bundle"), c(file.path(d, "manifest.json"), "manifest"),
                  c(file.path(d, "results", "manifest.json"), "manifest"))) {
    if (file.exists(sp[[1L]])) rows[[length(rows) + 1L]] <- .bl_schema_row(d, sp[[1L]], sp[[2L]])
  }
  if (file.exists(prov_file)) rows[[length(rows) + 1L]] <- .bl_result_rows(vrfcps(d), d, "provenance", prov_file)
  if (file.exists(bundle_file)) {
    bnd <- cpsbndlrd(bundle_file)
    # the secret goes to an hmac bundle only; the key id or public key is checked for any scheme
    hmac <- identical(as.character(unlist(bnd$attestation$scheme))[1L], "hmac")
    chk <- cpsbndlvrf(bnd, d, keyexp = if (nzchar(pubkey)) pubkey, key = if (hmac && nzchar(key)) key)
    rows[[length(rows) + 1L]] <- .bl_result_rows(chk, d, "bundle", bundle_file)
  }
  do.call(rbind, rows)
}

#' The worst severity among failed rows.
#' @param sev The severities of the failed rows (or the results of capsules); a note counts as ok.
#' @return ok, warn, drift or error.
#' @noRd
.bl_worst <- function(sev) {
  r <- c("ok", "warn", "drift", "error")
  sev <- sev[sev != "note"]
  if (!length(sev)) "ok" else r[max(match(sev, r))]
}

#' The summary-table cells of one capsule: source host, pinned digest, size, rows, bounds.
#' @param d The capsule directory.
#' @return A list of strings.
#' @noRd
.bl_capsule_info <- function(d) {
  p <- tryCatch(loadprov(file.path(d, "data_provenance.json")), error = function(e) NULL)
  s1 <- function(v) {
    v <- unlist(v)
    if (length(v) && !is.na(v[[1L]])) as.character(v[[1L]])
  }
  res <- p[["resource"]]
  src <- s1(res[["direct_url"]]) %||% s1(p[["source"]][["url"]]) %||% ""
  host <- if (!nzchar(src)) "-" else if (startsWith(src, "file://")) "local file" else
    sub("^[a-z]+://([^/:]+).*$", "\\1", src)
  f <- file.path(d, s1(res[["filename"]]) %||% "")
  b <- if (file.exists(f) && !dir.exists(f)) file.size(f) else NA
  n <- suppressWarnings(as.numeric(s1(res[["row_count_data_rows"]]) %||% NA))
  rnd <- s1(p[["table"]][["rounding"]])
  sup <- s1(p[["table"]][["suppression_limit"]]) %||% s1(p[["table"]][["suplim"]])
  list(host = host, sha = if (is.null(s1(res[["sha256"]]))) "-" else substr(s1(res[["sha256"]]), 1L, 12L),
       size = if (is.na(b)) "-" else if (b < 1024^2) sprintf("%.1f KB", b / 1024) else sprintf("%.1f MB", b / 1024^2),
       rows = if (is.na(n)) "-" else format(n, big.mark = ","),
       bounds = if (is.null(rnd) && is.null(sup)) "-" else
         paste(c(if (!is.null(rnd)) paste("round", rnd), if (!is.null(sup)) paste("supp", sup)), collapse = " \u00b7 "))
}

#' Runs the capsule verbs: verify, drift, report and refresh.
#'
#' The hmac secret of a bundle is read from RMBL_KEY and removed from the environment at once, so
#' no child process inherits it. Exit status: 0, or 1 when the worst failed row is at or above
#' --fail-on (report never fails); a usage error is raised for blcli() to turn into 2.
#' @param verb The verb.
#' @param rest The arguments after the verb.
#' @param flag A function that returns the value of an option, or NULL.
#' @param out The function that prints the verb's output.
#' @param usage_error A function that raises a usage error.
#' @return The exit status.
#' @noRd
.bl_cli_capsule <- function(verb, rest, flag, out, usage_error) {
  pos <- rest
  for (f in .bl_capsule_valued) {
    i <- match(f, pos)
    if (!is.na(i)) pos <- pos[-c(i, i + 1L)]
  }
  pos <- pos[!pos %in% c("--json", "--allow-file", "--snapshot", "--no-footprint")]
  if (length(pos) != 1L) usage_error(sub("\n$", "", .bl_verb_usage(verb, .bl_prog())))
  root <- pos[[1L]]
  if (!dir.exists(root)) usage_error(sprintf("%s is not a directory", .rmbl_printable(root)))
  fail_on <- flag("--fail-on") %||% "error"
  if (!fail_on %in% c("error", "drift", "warn")) {
    usage_error(sprintf("--fail-on takes error, drift or warn, not '%s'", .rmbl_printable(fail_on)))
  }
  fmt <- flag("--format") %||% (if ("--json" %in% rest) "json" else "md")
  if (!fmt %in% c("md", "json")) usage_error(sprintf("--format takes md or json, not '%s'", .rmbl_printable(fmt)))
  key <- Sys.getenv("RMBL_KEY")
  Sys.unsetenv("RMBL_KEY")
  if (verb == "refresh") return(.bl_cli_refresh(root, out))
  num <- function(f, default) {
    v <- flag(f)
    if (is.null(v)) default else suppressWarnings(as.numeric(v))
  }
  # a refused argument (a PSI band that is not a number, a --base that does not exist) is a usage error
  res <- tryCatch(cpschk(root, verb, key = key, pubkey = flag("--public-key") %||% "",
                         psiwarn = num("--psi-warn", 0.1), psifail = num("--psi-fail", 0.25), base = flag("--base"),
                         cache = flag("--cache") %||% FALSE, allowfile = "--allow-file" %in% rest,
                         snapshot = "--snapshot" %in% rest, glob = flag("--manifests") %||% "",
                         fp = !"--no-footprint" %in% rest),
                  error = function(e) usage_error(sub("^cpschk: ", "", conditionMessage(e))))
  out(format(res, fmt = fmt, failon = if (verb != "report") fail_on))
  rank <- c(ok = 0L, warn = 1L, drift = 2L, error = 3L)
  if (verb != "report" && rank[[res$status]] >= rank[[fail_on]]) 1L else 0L
}

#' The options of the capsule verbs that take a value.
#' @noRd
.bl_capsule_valued <- c("--fail-on", "--format", "--public-key", "--psi-warn", "--psi-fail", "--base", "--cache",
                        "--manifests")

#' The options verify, drift and report share (the first take a value).
#' @noRd
.bl_capsule_opts <- c("--public-key", "--psi-warn", "--psi-fail", "--base", "--cache", "--manifests", "--allow-file",
                      "--snapshot", "--no-footprint")

#' The refresh verb: cpsrfrsh() on every capsule under a path that has a provenance.
#' @param root The directory searched.
#' @param out The function that prints the verb's output.
#' @return The exit status: 1 when a capsule could not be refreshed.
#' @noRd
.bl_cli_refresh <- function(root, out) {
  dirs <- .bl_capsule_dirs(root)
  dirs <- dirs[file.exists(file.path(dirs, "data_provenance.json"))]
  if (!length(dirs)) out(sprintf("no data_provenance.json under %s: nothing to refresh\n", root))
  status <- 0L
  for (d in dirs) {
    r <- tryCatch(cpsrfrsh(d), error = function(e) e)
    if (inherits(r, "error")) {
      out(sprintf("%s: %s\n", d, conditionMessage(r)))
      status <- 1L
      next
    }
    out(sprintf("%s: %s\n", d, paste(format(r), collapse = "\n")))
    if (any(r$change != "unchanged") && file.exists(file.path(d, "capsule_bundle.json"))) {
      out(sprintf("%s: capsule_bundle.json no longer matches the data: sign it again with cpsbndl()\n", d))
    }
  }
  status
}

#' What a failed check row means and what to do, by the check's name.
#' @param check The check's name, as the capsule verbs report it.
#' @return One string.
#' @noRd
.bl_check_meaning <- function(check) {
  m <- c(
    provenance_readable = "data_provenance.json is missing, outside the capsule or not valid JSON",
    data_present = "the data file the provenance names (resource$filename) is not in the capsule",
    data_sha256 = paste("the data file's bytes differ from the pinned SHA-256: restore the file, or pin the",
                        "new bytes with cpsrfrsh() (rmbl refresh)"),
    data_size_bytes = "the data file's size differs from resource$size_bytes: its bytes changed",
    data_readable = "the data file cannot be read as a CSV, so its row count and schema cannot be checked",
    data_row_count = "the CSV has another number of rows than resource$row_count_data_rows records",
    schema_valid = "the data fail the schema pinned in the provenance (valsch()): a column renamed, gone or retyped",
    manifest_consistent = "a result in manifest.json no longer gets its recorded PASS or DIFFER",
    script_sha256 = "the analysis script differs from its pinned digest: the code changed since the results",
    data_not_synthetic = "the data are marked synthetic: a capsule holds the real data",
    no_unlisted_files = "the capsule holds files the bundle does not cover: remove them or sign again (cpsbndl())",
    `attestation:signature` = paste("the bundle's signature does not verify: the bundle was altered, or (hmac)",
                                    "the secret in RMBL_KEY is missing or wrong"),
    `attestation:key_as_expected` = "the bundle was signed with another key than the one given (--public-key)",
    `attestation:manifest_digest` = "the bundle's file list is not the one the attestation signed",
    `attestation:attestation_complete` = "the attestation lacks a field it needs",
    check_stopped = "the checks of this capsule stopped with the error in the detail",
    source_fetched = "the source named in the provenance could not be fetched",
    source_digest = "the source serves other bytes than the pin: rmbl refresh pins them (cpsrfrsh())",
    source_columns = paste("the new source's columns drift from the pinned data (cpsdrft(), past the PSI bands):",
                           "look before pinning it"),
    refreshed = paste("the new bytes were not pinned: the detail says why (a schema they fail, a data file",
                      "outside the capsule)")
  )
  if (check %in% names(m)) return(m[[check]])
  if (startsWith(check, "file:")) return("a bundled file is missing or its digest differs: restore it or sign again")
  if (startsWith(check, "schema: ")) return("the file does not follow its JSON Schema (schemapath()): see the detail")
  "a failed check: see the detail"
}

#' explerr() on check rows: each failed row, what it means and where its message is raised.
#' @param rows A data frame with the columns check, ok and detail.
#' @param pkgs The packages to search for the messages, or NULL.
#' @return A data frame with the columns check, detail, explanation and raised_by.
#' @noRd
.bl_explain_rows <- function(rows, pkgs) {
  if (!all(c("check", "ok", "detail") %in% names(rows))) {
    stop(.rmbl_fn(), "a data frame of check rows needs the columns check, ok and detail (as rmbl verify --json)",
         call. = FALSE)
  }
  bad <- rows[!(as.logical(rows$ok) %in% TRUE), , drop = FALSE]
  detail <- as.character(bad$detail)
  raised <- vapply(detail, function(m) {
    e <- if (nzchar(trimws(m))) explerr(m, pkgs = pkgs, n = 1L)
    if (NROW(e)) paste0(e$package, "::", e$raised_by) else NA_character_
  }, "", USE.NAMES = FALSE)
  data.frame(check = as.character(bad$check), detail = detail,
             explanation = vapply(as.character(bad$check), .bl_check_meaning, "", USE.NAMES = FALSE),
             raised_by = raised, stringsAsFactors = FALSE)
}
