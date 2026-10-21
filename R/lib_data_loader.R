# SPDX-License-Identifier: AGPL-3.0-or-later
## =====================================================================
## lib_data_loader.R -- open-data discovery, download, schema validation
##
## Part of rmorie-bricklayer. Project-agnostic; project specifics live in
## data_provenance.json and config.json.
##
## Provides:
##   loadprov(path)                Read pinned URL + SHA256 + schema
##   rslvckan(provenance)         Try CKAN package_show + name match
##   rslvckns(provenance)  Fall back to CKAN package_search
##   dldata(url, tpath)      utils::download.file() wrapper
##   vrfsha256(path, expected)        Compare to provenance
##   valsch(dfraw, provenance)  Hard fail / warn on schema drift
##
## Licence: AGPL-3.0-or-later
## =====================================================================

#' Load a Pinned Data-Provenance Record
#'
#' Reads a \code{data_provenance.json} file, the record that pins where a
#' project's data came from: the portal endpoint (CKAN, Socrata or ArcGIS),
#' the resource name pattern, the expected SHA-256 of the file, a Wayback
#' Machine snapshot, the schema the data must match and the recipe for a
#' synthetic stand-in. The resolvers
#' ([rslvckan()],
#' [rslvsoc()],
#' [rslvarc()]) and the checks
#' ([vrfsha256()],
#' [valsch()]) all take the list this returns.
#'
#' @details
#' The file is parsed with the package's own JSON codec (see
#' [fromjs()]) without
#' simplification: JSON arrays stay
#' lists, so a pinned digest such as \code{"sha256": "abc"} is a length-1
#' character and an array of column names is a list of strings (use
#' \code{unlist()} where a vector is needed). Nothing is checked about the
#' content here; [valsch()] reads the
#' \code{schema} block.
#'
#' A missing file is not an error: it returns \code{NULL}, so a project can
#' run without a provenance record and every resolver treats \code{NULL} as
#' \dQuote{nothing pinned}.
#'
#' Errors: \code{path} that is not a single non-empty string; \code{path}
#' that is a directory; a file that is not valid JSON.
#'
#' @param path Path to the provenance JSON file, a single string.
#' @return The parsed provenance as a nested named list (JSON objects become
#'   named lists, arrays become unnamed lists, strings, numbers and booleans
#'   become length-1 vectors), or \code{NULL} if the file does not exist.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' provfile <- tempfile(fileext = ".json")
#' writeLines('{"dataset": {"title": "demo"}, "sha256": "abc"}', provfile)
#' prov <- loadprov(provfile)
#' prov$dataset$title
#' loadprov(file.path(tempdir(), "no-such-file.json")) # NULL
#'
#' # arrays stay lists: unlist() them for a vector
#' writeLines('{"schema": {"expected_columns": ["id", "year"]}}', provfile)
#' p <- loadprov(provfile)
#' unlist(p$schema$expected_columns)
#' length(valsch(data.frame(id = 1, year = 2020), p))
#'
#' # a directory is not a provenance file
#' try(loadprov(tempdir()))
#' @export
loadprov <- function(path) {
  path <- .rmbl_string1(path, "path")
  if (!file.exists(path)) {
    return(NULL)
  }
  if (dir.exists(path)) stop(sprintf("`path` is a directory, not a provenance file: %s", path), call. = FALSE)
  .rmbl_read_json(path, simplify = FALSE)
}

## ----- CKAN package_show by slug + name match -----
## CKAN is the API used by data.ontario.ca, data.gov.uk, data.gov, and
## most government open-data portals. Resolves the current download URL
## for a known package even if the resource UUID has been replaced.

#' Resolve a Download URL via CKAN package_show
#'
#' Asks a CKAN open-data portal for the current list of files in a dataset
#' and returns the URL of the first file whose name matches the pattern
#' pinned in the provenance record. CKAN powers data.ontario.ca,
#' data.gov.uk, data.gov and most government open-data portals; when a
#' portal replaces a file (a new resource UUID, a new URL) the dataset page
#' stays the same, so this recovers the current download URL without editing
#' the project.
#'
#' @details
#' The function reads \code{dataset$ckan_api_endpoint}, the full URL, which
#' ends in \code{/api/3/action/} and \code{package_show?id=<slug>}. It also
#' reads \code{resource$name_match_pattern}, a regular expression. It fetches
#' the endpoint as JSON, and walks \code{result$resources} in the order the
#' portal lists them. The first resource whose \code{name} matches the
#' pattern (case-insensitively, with [grepl()]) wins. If the slug
#' itself has
#' changed, [rslvckns()] is the
#' fallback.
#'
#' \code{NULL} is returned, without an error, when \code{prov} is
#' \code{NULL}, when either field is missing or empty, when the request
#' fails (offline, HTTP error, invalid JSON), when CKAN answers
#' \code{"success": false}, or when no resource name matches. Errors are
#' raised for a \code{prov} that is not a list, for an endpoint that is
#' not a public \code{https} URL (plain \code{http} only when the option
#' \code{rmoriebricklayer.allowhttp} is \code{TRUE}; loopback, private and
#' link-local addresses are refused), and for a matched resource URL that
#' fails the same check. One network request; nothing is written.
#'
#' @param prov A provenance list as returned by
#'   [loadprov()], or \code{NULL}.
#'   A lookup is made only when it has both of these fields:
#'   \itemize{
#'     \item \code{dataset$ckan_api_endpoint};
#'     \item \code{resource$name_match_pattern}.
#'   }
#' @return The matched resource URL as a length-1 character string, or
#'   \code{NULL} as described in Details.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Missing fields return NULL rather than erroring:
#' rslvckan(list())
#' rslvckan(NULL)
#'
#' # the endpoint must be public https, checked before any request
#' prov <- list(
#'   dataset = list(ckan_api_endpoint = "http://localhost/api/3/action/package_show?id=x"),
#'   resource = list(name_match_pattern = "2014")
#' )
#' try(rslvckan(prov))
#'
#' @examplesIf interactive()
#' # needs the network: asks data.ontario.ca for the current file URL
#' prov <- list(
#'   dataset = list(ckan_api_endpoint = paste0(
#'     "https://data.ontario.ca/api/3/action/package_show",
#'     "?id=ontario-public-library-statistics"
#'   )),
#'   resource = list(name_match_pattern = "2014")
#' )
#' rslvckan(prov)
#' @export
rslvckan <- function(prov) {
  if (is.null(prov)) {
    return(NULL)
  }
  if (!is.list(prov)) stop("rslvckan: `prov` must be a provenance list (loadprov())", call. = FALSE)
  ds <- prov$dataset
  res <- prov$resource
  if (is.null(ds$ckan_api_endpoint) || is.null(res$name_match_pattern)) {
    return(NULL)
  }
  api_url <- ds$ckan_api_endpoint
  if (is.null(api_url) || !nzchar(api_url)) {
    return(NULL)
  }
  api_url <- .rmbl_check_public_url(api_url, "ckan_api_endpoint")
  resp <- tryCatch(.rmbl_read_json(api_url, simplify = FALSE, strict = FALSE),
    error = function(e) NULL
  )
  if (is.null(resp) || !isTRUE(resp$success)) {
    return(NULL)
  }
  pat <- res$name_match_pattern
  for (r in resp$result$resources) {
    name <- if (is.null(r$name)) "" else r$name
    if (grepl(pat, name, ignore.case = TRUE)) {
      # a hostile record is an error in words, not "source unreachable"
      return(.rmbl_check_public_url(r$url, "the CKAN resource URL"))
    }
  }
  NULL
}

## ----- CKAN package_search (fallback if slug changes) -----

#' Resolve a Download URL via CKAN package_search
#'
#' The fallback for [rslvckan()] when a dataset's
#' slug has changed
#' and \code{package_show} no longer finds it. It runs a full-text
#' \code{package_search} on the same CKAN portal and returns the URL of the
#' first resource, across all datasets returned, whose name matches the
#' pinned pattern.
#'
#' @details
#' The portal base is the part of \code{dataset$ckan_api_endpoint} before
#' \code{/api/3/}; the request goes to \code{<base>/api/3/action/} followed by
#' \code{package_search?q=<query>}.
#'
#' The query is \code{resource$search_query} when given, otherwise the
#' \code{resource$name_match_pattern} with every character other than a
#' letter, digit or space replaced by a space. Datasets are walked in the
#' order CKAN ranks them, and their resources in listed order. A resource is
#' taken when its \code{name} matches \code{resource$name_match_pattern}
#' (case-insensitively) and either its format is CSV, or
#' \code{resource$format} is unset, or its format equals
#' \code{resource$format} (case-insensitively). So a CSV resource is accepted
#' even when \code{resource$format} asks for another format.
#'
#' \code{NULL} is returned when \code{prov} is \code{NULL}, when no
#' query can be formed, when there is no endpoint to derive the base from,
#' when the request fails, or when nothing matches. Errors: a
#' \code{prov} that is not a list; a search URL or matched resource
#' URL that is not public \code{https}. One network request.
#'
#' @param prov A provenance list as returned by
#'   [loadprov()], or \code{NULL}.
#'   The fields read are \code{dataset$ckan_api_endpoint},
#'   \code{resource$name_match_pattern} (a regular expression, required for
#'   a match), and, both optional, \code{resource$search_query} (search
#'   words) and \code{resource$format} (a format name such as \code{"XLSX"}).
#' @return The matched resource URL as a length-1 character string, or
#'   \code{NULL}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Missing fields return NULL rather than erroring:
#' rslvckns(list())
#'
#' # no endpoint to derive the portal from: NULL, no request made
#' rslvckns(list(resource = list(name_match_pattern = "2014")))
#'
#' # a provenance must be a list
#' try(rslvckns("data.ontario.ca"))
#'
#' @examplesIf interactive()
#' # needs the network: searches data.ontario.ca
#' prov <- list(
#'   dataset = list(ckan_api_endpoint = paste0(
#'     "https://data.ontario.ca/api/3/action/package_show",
#'     "?id=ontario-public-library-statistics"
#'   )),
#'   resource = list(
#'     name_match_pattern = "2014",
#'     search_query = "public library statistics"
#'   )
#' )
#' rslvckns(prov)
#' @export
rslvckns <- function(prov) {
  if (is.null(prov)) {
    return(NULL)
  }
  if (!is.list(prov)) stop("rslvckns: `prov` must be a provenance list (loadprov())", call. = FALSE)
  res <- prov$resource
  q <- res$search_query
  if (is.null(q) || !nzchar(q)) {
    ## Derive a search query from the resource name pattern
    q <- gsub("[^A-Za-z0-9 ]", " ", res$name_match_pattern %||% "")
    if (!nzchar(q)) {
      return(NULL)
    }
  }
  ## CKAN portal base URL inferred from package_show endpoint
  base <- sub(
    "/api/3/.*$", "",
    prov$dataset$ckan_api_endpoint %||% ""
  )
  if (!nzchar(base)) {
    return(NULL)
  }
  api_url <- .rmbl_check_public_url(sprintf(
    "%s/api/3/action/package_search?q=%s",
    base, utils::URLencode(q, reserved = TRUE)
  ), "the CKAN package_search URL")
  resp <- tryCatch(.rmbl_read_json(api_url, simplify = FALSE, strict = FALSE),
    error = function(e) NULL
  )
  if (is.null(resp)) {
    return(NULL)
  }
  pat <- res$name_match_pattern
  for (pkg in resp$result$results) {
    for (r in pkg$resources) {
      name <- if (is.null(r$name)) "" else r$name
      fmt <- toupper(r$format %||% "")
      if (grepl(pat, name, ignore.case = TRUE) &&
        (fmt == "CSV" || is.null(res$format) || toupper(res$format) == fmt)) {
        return(.rmbl_check_public_url(r$url, "the CKAN resource URL"))
      }
    }
  }
  NULL
}

## ----- Tiny `%||%` operator (R 4.4+ has it natively) -----

## ----- Download -----

#' Download a File
#'
#' Downloads one file to a path on disk through the package's own transport,
#' [bldl()], and returns the path. It is
#' the plain download
#' step of a data pipeline: resolve a URL (for example with
#' [rslvckan()]), download it with this function,
#' then check it with
#' [vrfsha256()]. Use
#' [fdl()] instead when a person should
#' see advice about the failure and a Wayback Machine fallback.
#'
#' @details
#' Before anything is fetched the URL must be one public \code{https} URL:
#' plain \code{http} needs the option \code{rmoriebricklayer.allowhttp} set to
#' \code{TRUE}, \code{file://} needs \code{allowfile = TRUE}, and loopback,
#' private, link-local and cloud-metadata addresses are refused. The
#' transport then resolves the host, pins the connection to the checked
#' addresses, re-checks every redirect hop, caps the body at 2 GiB and allows
#' 3600 seconds for the transfer. The file at \code{tpath} is
#' overwritten. Errors from the transfer (network, HTTP status, size cap)
#' propagate as R errors; nothing partial is left behind.
#'
#' Progress is drawn on stderr while \code{quiet = FALSE}, whatever the
#' \code{morie.quiet} option says, because the value is passed to the
#' transport explicitly.
#'
#' Errors: \code{url} or \code{tpath} not a single non-empty string;
#' a refused URL; \code{mode} other than \code{"wb"} or \code{"w"}.
#'
#' @param url The URL to download, a single string.
#' @param tpath Destination path on disk, a single string. Its
#'   directory must exist.
#' @param mode Kept for the signature of \code{utils::download.file()}; only
#'   \code{"wb"} (the default) or \code{"w"} is accepted. Every transfer is
#'   binary and written fresh through the package's own transport, so an
#'   append mode cannot be honoured and is an error rather than a silent
#'   \code{"wb"}.
#' @param quiet Logical. \code{TRUE} suppresses the progress output;
#'   \code{FALSE} (the default) shows it.
#' @param allowfile Logical. Accept a \code{file://} URL (default
#'   \code{FALSE}; offline tests and examples pass \code{TRUE}). Every URL
#'   must otherwise be \code{https} and public.
#' @return The \code{tpath}, returned invisibly.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # offline: a local file through a file:// URL
#' src <- tempfile(fileext = ".csv")
#' writeLines(c("id,value", "1,10", "2,20"), src)
#' dest <- dldata(paste0("file://", src), tempfile(fileext = ".csv"),
#'   quiet = TRUE, allowfile = TRUE)
#' read.csv(dest)
#'
#' # file:// is refused unless asked for, and so is an append mode
#' try(dldata(paste0("file://", src), tempfile()))
#' try(dldata("https://example.org/x.csv", tempfile(), mode = "a"))
#'
#' @examplesIf interactive()
#' # needs the network
#' dest <- dldata("https://cloud.r-project.org/",
#'   tempfile(fileext = ".html"),
#'   quiet = TRUE
#' )
#' file.exists(dest)
#' @export
dldata <- function(url, tpath, mode = "wb", quiet = FALSE,
                          allowfile = FALSE) {
  url <- .rmbl_string1(url, "url")
  url <- .rmbl_check_public_url(url, "url", allow_file = allowfile)
  tpath <- .rmbl_string1(tpath, "tpath")
  if (!identical(mode, "wb") && !identical(mode, "w")) {
    stop("`mode` must be \"wb\" (every transfer is binary)", call. = FALSE)
  }
  bldl(url, tpath, quiet = isTRUE(quiet),
                      allowfile = allowfile)
  invisible(tpath)
}

#' Resolve a Wayback Machine snapshot URL
#'
#' Asks the Internet Archive which archived copy of a web address is closest
#' to a given time and returns a URL that downloads that copy. This is the
#' fetch failsafe the wider morie package family relies on: callers try the
#' live source first and fall back to the snapshot when the source is down,
#' has moved or has been taken offline.
#' [fdl()] uses it
#' automatically.
#'
#' @details
#' The function sends one request to the availability API,\cr
#' \code{https://archive.org/wayback/available?url=<url>[&timestamp=<ts>]},\cr
#' where the timestamp part is sent only when \code{ts} is given.
#'
#' The answer's \code{archived_snapshots$closest} is read. When the API reports an
#' available snapshot its URL is returned, with \code{http://} rewritten to
#' \code{https://} and passed through the same public-URL check as every
#' other URL the package fetches. The timestamp is passed to the API as
#' given; the API accepts any prefix of \code{YYYYMMDDhhmmss} and returns the
#' snapshot nearest to it, before or after.
#'
#' \code{NULL} is returned when the API has no snapshot, when the request
#' fails (offline, an HTTP error, invalid JSON) or when the answer has no
#' usable URL. Error: \code{url} that is not a single non-empty string.
#' Nothing is written.
#'
#' @param url The original source URL to look up, a single string.
#' @param ts Optional target time as a string of digits
#'   \code{YYYYMMDDhhmmss} (or a prefix such as \code{"2023"} or
#'   \code{"20230115"}); the API returns the snapshot closest to it.
#'   \code{NULL} or \code{""} (the default) asks for the most recent.
#' @return A length-1 character string, the \code{https} snapshot URL of the
#'   form \code{https://web.archive.org/web/} followed by \code{<timestamp>/<url>}, or
#'   \code{NULL}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # argument errors come before any request
#' try(wbsnpurl(NA))
#' try(wbsnpurl(c("https://a.org", "https://b.org")))
#'
#' @examplesIf interactive()
#' # needs the network
#' wbsnpurl("https://www.r-project.org/")
#' # the snapshot nearest to January 2020
#' wbsnpurl("https://www.r-project.org/", ts = "202001")
#' @export
wbsnpurl <- function(url, ts = NULL) {
  url <- .rmbl_string1(url, "url")
  # https: over cleartext a MITM chose the fallback snapshot
  api <- paste0(
    "https://archive.org/wayback/available?url=",
    utils::URLencode(url, reserved = TRUE)
  )
  if (!is.null(ts) && nzchar(ts)) {
    api <- paste0(api, "&timestamp=", ts)
  }
  res <- tryCatch(.rmbl_read_json(api, strict = FALSE), error = function(e) NULL)
  snap <- tryCatch(res$archived_snapshots$closest, error = function(e) NULL)
  if (is.null(snap) || !isTRUE(snap$available) || is.null(snap$url)) {
    return(NULL)
  }
  snap_url <- unlist(snap$url)
  if (!is.character(snap_url) || length(snap_url) != 1L || !nzchar(snap_url)) return(NULL)
  ## Prefer HTTPS; the API sometimes returns http:// snapshot URLs. And
  ## whatever it returns is fetched next, so it passes the same gate as
  ## every other URL.
  .rmbl_check_public_url(sub("^http://", "https://", snap_url),
                         "the Wayback snapshot URL")
}

#' Downloads a URL to a file.
#'
#' The one transport fdl() uses, live and Wayback alike (tests
#' mock it). Inside the package it is bldl() with its live
#' progress bar; a staged bundle (which copies this file alone) uses base R.
#' @param url The URL to fetch.
#' @param dest The file to write.
#' @param allow_file Whether a `file://` URL is accepted.
#' @return What `bldl()` or `utils::download.file()` returns.
#' @noRd
.bl_fetch_file <- function(url, dest, allow_file = FALSE) {
  url <- .rmbl_check_public_url(url, "url", allow_file = allow_file)
  if (exists("bldl", mode = "function")) {
    bldl(url, dest, quiet = FALSE, allowfile = allow_file)
  } else {
    utils::download.file(url, dest, mode = "wb", quiet = FALSE)
  }
}

#' Tells whether an error is R's time limit (setTimeLimit()), in English or translated.
#' @param msg The error's message.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_time_limit <- function(msg) {
  k <- c("reached elapsed time limit", "reached CPU time limit", "reached session elapsed time limit",
         "reached session CPU time limit")
  any(vapply(unique(c(k, gettext(k, domain = "R"))), grepl, NA, msg, fixed = TRUE))
}

## ----- fdl: wraps bldl with diagnostic
## error messages for common academic/corporate network failures.
## Returns TRUE on success, FALSE on failure.

#' Download a File With Diagnostic Error Messages
#'
#' Downloads one file like [dldata()], but never stops
#' on a network
#' failure: it returns \code{TRUE} or \code{FALSE}, prints plain-language
#' advice for the usual academic and corporate network problems, and then
#' tries a Wayback Machine copy of the same address. Use it in scripts that
#' other people run on networks you do not control (university VPNs,
#' corporate proxies), where a bare \dQuote{cannot open the connection} is not
#' enough to act on.
#'
#' @details
#' The URL is checked first, as in [dldata()]; a
#' refused URL is an
#' error, not \code{FALSE}. The download is then attempted. On failure the
#' messages name the URL and the error, then the likely causes picked out
#' from the error text: rate limiting (HTTP 429, common behind shared VPN
#' addresses), a TLS handshake failure (VPNs that inspect TLS, such as Cisco
#' AnyConnect, GlobalProtect, Zscaler or Netskope), a DNS failure, a refused
#' or reset connection, a timeout, an HTTP 403, or otherwise a moved file or
#' a portal that is down. When base R reports the HTTP status only in a
#' warning, that warning's text is used as the cause.
#'
#' The fallback: with \code{attwb = NULL} a snapshot is looked up
#' with [wbsnpurl()]; with a URL that URL
#' is used; with
#' \code{""} or \code{FALSE} the fallback is off. The fallback is fetched
#' without \code{allowfile}, so it must be a public \code{https} URL even
#' when \code{allowfile = TRUE}; a refused fallback URL counts as a failed
#' fallback (\code{FALSE}), with a message.
#'
#' All output goes to the message stream. The transport always draws its
#' progress (it is called with \code{quiet = FALSE}). \code{tpath} is
#' overwritten on success.
#'
#' @param url URL to download, a single string.
#' @param tpath Destination path on disk, a single string.
#' @param attwb The Wayback Machine snapshot URL tried as a
#'   fallback if the primary download fails. \code{NULL} (the default)
#'   resolves a snapshot automatically via
#'   [wbsnpurl()] (one more
#'   request); a URL string overrides the lookup; \code{""} or \code{FALSE}
#'   disables the fallback entirely.
#' @param allowfile Logical. Accept a \code{file://} URL for \code{url}
#'   (default \code{FALSE}; offline tests pass \code{TRUE}). It does not
#'   apply to \code{attwb}.
#' @return \code{TRUE} if either the primary download or the Wayback
#'   fallback succeeded (the file is at \code{tpath}), otherwise
#'   \code{FALSE}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' src <- tempfile(fileext = ".csv")
#' writeLines(c("id,value", "1,10"), src)
#'
#' # a successful download returns TRUE
#' fdl(paste0("file://", src), tempfile(fileext = ".csv"),
#'   attwb = "", allowfile = TRUE)
#'
#' # a failed one returns FALSE with advice, here with the fallback off
#' fdl(paste0("file://", src, "-missing"), tempfile(),
#'   attwb = "", allowfile = TRUE)
#'
#' # a refused URL is an error, not FALSE
#' try(fdl("http://example.org/data.csv", tempfile()))
#'
#' @examplesIf interactive()
#' # needs the network; the Wayback fallback is looked up on failure
#' ok <- fdl("https://cloud.r-project.org/",
#'   tempfile(fileext = ".html"))
#' ok
#' @export
fdl <- function(url, tpath, attwb = NULL,
                              allowfile = FALSE) {
  url <- .rmbl_string1(url, "url")
  url <- .rmbl_check_public_url(url, "url", allow_file = allowfile)
  tpath <- .rmbl_string1(tpath, "tpath")
  # base R's url() reports the HTTP status in a warning and then errors with a bare
  # "cannot open the connection": keep the warning's words as the cause, and do not let it leak
  acc <- new.env(parent = emptyenv())
  acc$said <- character()
  result <- tryCatch(
    {
      withCallingHandlers(.bl_fetch_file(url, tpath, allow_file = allowfile), warning = function(w) {
        acc$said <- c(acc$said, conditionMessage(w))
        invokeRestart("muffleWarning")
      })
      TRUE
    },
    error = function(e) {
      msg <- conditionMessage(e)
      # a time limit (setTimeLimit()) is the caller's, not a failed download: it was swallowed and
      # the fallback ran on, 34 s under a 3 s limit (audit of 30bed8e, #17)
      if (.rmbl_time_limit(msg)) stop(e)
      if (length(acc$said) && grepl("cannot open the connection", msg, fixed = TRUE)) {
        msg <- acc$said[[length(acc$said)]]
      }
      message("  ! Download failed.")
      message("    URL:   ", url)
      message("    Error: ", msg, "\n\n")
      message("  Common causes (in rough order of likelihood):")
      known <- grepl(paste0("429|too many|rate|SSL|TLS|certificate|handshake|UNEXPECTED_EOF|could not|",
                            "unable to resolve|resolve host|name not|getaddrinfo|timeout|timed out|",
                            "connection (refused|reset)|couldn.t connect|",
                            "403|forbidden"),
                     msg, ignore.case = TRUE)
      if (grepl("429|too many|rate", msg, ignore.case = TRUE)) {
        message("    * Rate-limited (HTTP 429). VPNs share IPs across users")
        message("      and often trip rate limits. Try disabling your VPN.")
      }
      if (grepl("SSL|TLS|certificate|handshake|UNEXPECTED_EOF",
        msg,
        ignore.case = TRUE
      )) {
        message("    * SSL/TLS handshake failed.")
        message("      VPNs with TLS inspection (Cisco AnyConnect, GlobalProtect,")
        message("      Zscaler, NetSkope) break R's HTTPS. Try disabling.")
      }
      if (grepl("could not resolve|unable to resolve|resolve host|name not|getaddrinfo",
        msg,
        ignore.case = TRUE
      )) {
        message("    * DNS lookup failed; check network connectivity.")
      }
      if (grepl("could not connect|connection (refused|reset)|couldn.t connect",
        msg,
        ignore.case = TRUE
      )) {
        message("    * Could not connect to the server (offline, or a proxy or firewall refused the connection).")
      }
      if (grepl("timeout|timed out", msg, ignore.case = TRUE)) {
        message("    * Connection timed out (firewall, often institutional).")
      }
      if (grepl("403|forbidden", msg, ignore.case = TRUE)) {
        message("    * HTTP 403 Forbidden (geo-restriction; try a different VPN region).")
      }
      if (!known) {
        message("    * The server did not serve the file (see the error above): the URL may have moved or the")
        message("      portal may be down.")
      }
      ## Auto-resolve a Wayback snapshot if the caller did not supply one
      ## (NULL = auto; "" = explicitly disabled).
      if (isFALSE(attwb) || identical(attwb, "")) {
        attwb <- ""  # switched off by the caller: no lookup was made
        message("  The Wayback fallback is switched off; nothing more to try.")
      } else {
        if (is.null(attwb)) {
          attwb <- tryCatch(wbsnpurl(url), error = function(e) NULL)
        }
        if (!is.character(attwb) || length(attwb) != 1L || is.na(attwb) ||
            !nzchar(attwb)) {
          attwb <- ""  # no usable snapshot
          message("  The Wayback Machine has no snapshot of it (or did not answer); nothing more to try.")
        }
      }
      if (!is.null(attwb) && nzchar(attwb)) {
        message("  Trying Wayback Machine fallback snapshot...")
        tryCatch(
          {
            .bl_fetch_file(attwb, tpath)
            message("  [ok] Wayback snapshot retrieved.")
            return(TRUE)
          },
          error = function(e2) {
            message("  ! Wayback fallback also failed: ", conditionMessage(e2), "")
            FALSE
          }
        )
      }
      FALSE
    }
  )
  result
}

## ----- SHA256 check -----

#' Verify a File's SHA256 Against an Expected Digest
#'
#' Computes the SHA-256 digest of a file and compares it with the digest
#' pinned in a provenance record, so a pipeline can tell whether the file it
#' downloaded is byte for byte the one the analysis was run on. A changed
#' file (a silent re-release, a truncated download, an edited copy) gives a
#' different digest.
#'
#' @details
#' The digest is computed by [sha256file()], the package's own
#' compiled
#' SHA-256 core (FIPS 180-4), reading the file in chunks. The expected
#' value is normalised before the comparison: a length-1 list (as
#' [loadprov()] returns a pinned digest) is
#' unlisted, surrounding
#' spaces are trimmed and letters are lower-cased, so an upper-case digest
#' copied from a web page still matches. The function reports and does not
#' stop on a mismatch; the caller decides.
#'
#' Errors: \code{path} that does not name a readable file;
#' \code{expsha} that is not exactly one non-NA value.
#'
#' @param path Path to the file to hash, a single string.
#' @param expsha The expected SHA-256 digest: a hex string (64
#'   characters, any case), or a length-1 list holding one, as read from
#'   provenance JSON.
#' @return A list of three elements: \code{actual} (character, the computed
#'   digest, 64 lower-case hex characters), \code{expected} (character, the
#'   normalised expected value) and \code{match} (logical, \code{TRUE} when
#'   they are identical).
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' f <- tempfile()
#' writeLines("hello capsule", f)
#'
#' # Matching digest -> match TRUE.
#' chk <- vrfsha256(f, sha256file(f))
#' chk$match # TRUE
#'
#' # A wrong expected digest -> match FALSE, with both values reported.
#' bad <- vrfsha256(f, strrep("0", 64L))
#' bad$match # FALSE
#' bad$actual # the real digest
#'
#' # case and a list wrapper (as from provenance JSON) do not matter
#' vrfsha256(f, list(toupper(sha256file(f))))$match
#'
#' # a missing file, or more than one expected digest, is an error
#' try(vrfsha256(file.path(tempdir(), "missing.csv"), strrep("0", 64L)))
#' try(vrfsha256(f, c("a", "b")))
#' @export
vrfsha256 <- function(path, expsha) {
  .rmbl_no_fn(expected_sha = expsha)
  actual <- sha256file(path)
  # provenance JSON hands the pinned digest over as a length-1 list;
  # identical() on list-vs-character never matched, so every intact
  # capsule reported a mismatch between two identical strings.
  expected <- tolower(trimws(as.character(unlist(expsha))))
  if (length(expected) != 1L || is.na(expected)) {
    stop("`expsha` must be a single SHA-256 hex string", call. = FALSE)
  }
  list(
    actual = actual, expected = expected,
    match = identical(tolower(actual), expected)
  )
}

## ----- Schema validation -----
## `provenance$schema` should contain:
##   expected_columns       character vector
##   expected_value_sets    named list of allowed values per column
##   structural_invariants  list with min_data_rows / max_data_rows (optional)
##
## Returns a list of issues (length 0 = clean). The caller decides whether
## to stop() or warning() based on severity.

#' Validate a Data Frame Against a Provenance Schema
#'
#' Checks a data frame against the \code{schema} block of a provenance
#' record: required columns, row-count bounds, column types, numeric ranges,
#' missingness and allowed category values. It returns the problems it
#' finds instead of stopping, so the caller can log them, show them, or pass
#' the same schema to [schval()],
#' the wrapper that turns
#' them into errors and warnings. Use it each time a file is re-downloaded,
#' to catch a re-release that renamed, retyped or recoded a column.
#'
#' @details
#' Every schema field is optional and is checked only when present, so a
#' schema written for an earlier version keeps working unchanged.
#'
#' This is the STRUCTURAL check -- names, types, bounds, value sets. It
#' cannot tell you that a column kept its name, type and range while its
#' distribution moved; [cpsdrft()] answers that. Rules
#' that are
#' particular to a data set (an age must be non-negative, two dates must be
#' ordered) belong in [rul()] and
#' [valrules()].
#'
#' The checks, and the name of the issue each one adds:
#' \itemize{
#'   \item a missing \code{expected_columns} entry: \code{missing_columns},
#'     \code{"fatal"};
#'   \item fewer than \code{min_data_rows} rows: \code{row_count_low};
#'   \item more than \code{max_data_rows} rows: \code{row_count_high};
#'   \item a column whose class differs from \code{expected_types}:
#'     \code{type_<col>}. \code{integer}, \code{numeric} and \code{double} are
#'     one family, and so are \code{character} and \code{factor};
#'   \item non-missing values outside \code{numeric_ranges} (inclusive bounds;
#'     non-numeric columns are skipped): \code{range_<col>};
#'   \item a share of \code{NA} above \code{max_missing_fraction}:
#'     \code{missing_<col>};
#'   \item values not in \code{expected_value_sets}: \code{unexpected_<col>}.
#' }
#' A column that a check names but the data lack is skipped by that check.
#' Only the \code{expected_columns} check reports such a column. All of these are
#' \code{"warning"} except \code{missing_columns}.
#'
#' The schema itself is checked too. An empty schema (\code{list()}) gives
#' one \code{schema_empty} warning. An unknown field name within three edits
#' of a known one (\code{expected_colums}) is \code{"fatal"}, because it
#' would otherwise be ignored silently; any other unknown name is a warning.
#' An unknown structural invariant one edit, or one swap of neighbouring
#' letters, away from \code{min_data_rows} or \code{max_data_rows} is fatal;
#' other invariant names are left alone. \code{expected_dtypes} is accepted
#' as another name for \code{expected_types}, and \code{synthetic_recipe} is
#' a known field that is not checked here.
#'
#' Errors: \code{dfraw} that is not a data frame; a \code{schema} that is
#' not a list. A \code{prov} that is \code{NULL} or has no
#' \code{schema} returns an empty list (use
#' [schval()] to
#' make that an error).
#'
#' @param dfraw The data frame to validate.
#' @param prov A provenance list as returned by
#'   [loadprov()], or
#'   \code{list(schema = infsch(df))}. The
#'   \code{schema} block may contain:
#'   * \code{expected_columns} -- required column names (character). A missing
#'     one is \code{"fatal"}; everything else below is a \code{"warning"}.
#'   * \code{structural_invariants} -- a list with \code{min_data_rows} and
#'     \code{max_data_rows} (numbers of rows).
#'   * \code{expected_value_sets} -- a named list of allowed values per
#'     column.
#'   * \code{expected_types} -- a named character vector of expected classes.
#'     \code{integer}, \code{numeric} and \code{double} are treated as
#'     interchangeable, since a re-release legitimately widens one to another.
#'   * \code{numeric_ranges} -- a named list of \code{c(min =, max =)} bounds.
#'   * \code{max_missing_fraction} -- a named numeric of per-column ceilings
#'     on the share of \code{NA}, between 0 and 1.
#'
#'   [infsch()] produces all six from data you already
#'   trust.
#' @return A named list of issues; each issue is a list with
#'   \code{severity} (\code{"fatal"} or \code{"warning"}) and a
#'   human-readable \code{message}. The names are those listed in Details. A
#'   zero-length list means the data frame is clean.
#' @seealso
#' [infsch()] to derive a schema,
#' [cpsdrft()] for the distributional
#' check, [schval()]
#' to raise on the issues.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' prov <- list(schema = list(
#'   expected_columns      = c("id", "year"),
#'   structural_invariants = list(min_data_rows = 1),
#'   expected_value_sets   = list(year = 2020:2025)
#' ))
#' df <- data.frame(id = 1:3, year = c(2020, 2021, 2030))
#' issues <- valsch(df, prov)
#' names(issues) # flags the out-of-set year value
#'
#' # A column that silently changed type is caught.
#' typed <- list(schema = list(expected_types = c(id = "integer")))
#' valsch(data.frame(id = c("1", "2")), typed)[[1]]$message
#'
#' # So is a value outside its pinned range, and excess missingness.
#' ranged <- list(schema = list(numeric_ranges = list(v = c(min = 0, max = 1))))
#' valsch(data.frame(v = c(0.5, 9)), ranged)[[1]]$message
#'
#' gappy <- list(schema = list(max_missing_fraction = c(v = 0.1)))
#' valsch(data.frame(v = c(1, NA, NA, 4)), gappy)[[1]]$message
#'
#' # A clean frame produces nothing.
#' length(valsch(data.frame(id = 1:3, year = 2021), prov))
#'
#' # a misspelt schema field is fatal rather than silently ignored
#' valsch(df, list(schema = list(expcol = "id")))[[1]]
#'
#' # a schema inferred from trusted data, checked against a new release
#' sch <- infsch(data.frame(id = 1:3, year = 2020:2022))
#' names(valsch(data.frame(id = 1:2), list(schema = sch)))
#'
#' # the data must be a data frame
#' try(valsch(list(id = 1), prov))
#' @export
valsch <- function(dfraw, prov) {
  if (!is.data.frame(dfraw)) {
    stop("valsch: `dfraw` must be a data frame", call. = FALSE)
  }
  if (!is.null(prov) && !is.list(prov)) {
    stop("`prov` must be a provenance list (from read_provenance()), or NULL", call. = FALSE)
  }
  issues <- list()
  if (is.null(prov) || is.null(prov$schema)) {
    return(issues)
  }
  sch <- prov$schema
  if (!is.list(sch)) {
    stop(sprintf("`provenance$schema` must be a list (from infsch()), not %s", class(sch)[1L]), call. = FALSE)
  }
  # a schema with no fields checks nothing: it passed as valid (review of e57fed5, the M2 leftover)
  if (!length(sch)) {
    issues$schema_empty <- list(severity = "warning",
      message = "the schema is empty (list()): it lists no columns, types or invariants, so nothing would be checked")
    return(issues)
  }
  # a misspelt field validates nothing and says nothing: a name a few letters from a known one is
  # fatal, any other unknown name is said (review of 02a38be, M2). expected_dtypes is what the
  # provenance files call expected_types (the OTIS file's types were never checked).
  known <- c("expected_columns", "expected_types", "expected_dtypes", "structural_invariants",
             "expected_value_sets", "numeric_ranges", "max_missing_fraction", "synthetic_recipe")
  near <- function(x, pool, k = 3) pool[which(utils::adist(x, pool) <= k & utils::adist(x, pool) > 0)[1L]]
  for (nm in setdiff(names(sch), known)) {
    guess <- near(nm, known)
    if (!is.na(guess)) {
      issues[[paste0("schema_field_", nm)]] <- list(severity = "fatal",
        message = sprintf("unknown schema field '%s' (did you mean '%s'?): it would be ignored", nm, guess))
    } else {
      issues[[paste0("schema_field_", nm)]] <- list(severity = "warning",
        message = sprintf("schema field '%s' is not one valsch() uses: it was not checked", nm))
    }
  }
  inv_known <- c("min_data_rows", "max_data_rows")
  for (nm in setdiff(names(sch$structural_invariants), inv_known)) {
    # other invariants are a dataset's own, checked by its analysis: only a slip of one letter (one
    # added, dropped or changed) or two neighbours swapped is taken for a misspelling; min_data_cols,
    # two letters from min_data_rows, is a field of its own (review of e57fed5)
    guess <- near(nm, inv_known, k = 1)
    if (is.na(guess)) {
      swapped <- vapply(inv_known, function(k) {
        a <- strsplit(nm, "")[[1L]]
        b <- strsplit(k, "")[[1L]]
        # lengths first: a != b on two lengths warned "longer object length is not a multiple"
        if (length(a) != length(b)) return(FALSE)
        i <- which(a != b)
        length(i) == 2L && i[2L] == i[1L] + 1L && a[i[1L]] == b[i[2L]] && a[i[2L]] == b[i[1L]]
      }, logical(1))
      if (any(swapped)) guess <- inv_known[swapped][1L]
    }
    if (!is.na(guess)) {
      issues[[paste0("schema_field_", nm)]] <- list(severity = "fatal",
        message = sprintf("unknown structural invariant '%s' (did you mean '%s'?): it would be ignored", nm, guess))
    }
  }
  if (is.null(sch$expected_types) && !is.null(sch$expected_dtypes)) sch$expected_types <- sch$expected_dtypes

  ## --- Required columns ---
  if (!is.null(sch$expected_columns)) {
    missing_cols <- setdiff(sch$expected_columns, colnames(dfraw))
    if (length(missing_cols) > 0L) {
      issues$missing_columns <- list(
        severity = "fatal",
        message = paste0(
          "Missing required columns: ",
          paste(missing_cols, collapse = ", ")
        )
      )
    }
  }

  ## --- Row count bounds ---
  inv <- sch$structural_invariants
  if (!is.null(inv$min_data_rows) && nrow(dfraw) < inv$min_data_rows) {
    issues$row_count_low <- list(
      severity = "warning",
      message = sprintf(
        "Row count %d below expected minimum %d",
        nrow(dfraw), inv$min_data_rows
      )
    )
  }
  if (!is.null(inv$max_data_rows) && nrow(dfraw) > inv$max_data_rows) {
    issues$row_count_high <- list(
      severity = "warning",
      message = sprintf(
        "Row count %d above expected maximum %d",
        nrow(dfraw), inv$max_data_rows
      )
    )
  }

  ## --- Column types ---
  ## A column that silently changed type (a numeric read back as
  ## character because one row gained a footnote marker) breaks every
  ## downstream computation while passing a name-only check.
  if (!is.null(sch$expected_types)) {
    for (col in names(sch$expected_types)) {
      if (!col %in% colnames(dfraw)) next
      want <- sch$expected_types[[col]]
      got <- class(dfraw[[col]])[1L]
      ## integer and double are both "numeric" for this purpose; a
      ## re-release legitimately widens one to the other.
      numeric_like <- c("integer", "numeric", "double")
      ## a factor read back from a CSV is text: "factor" and "character" are one family
      text_like <- c("character", "factor")
      same <- identical(got, want) ||
        (got %in% numeric_like && want %in% numeric_like) ||
        (got %in% text_like && want %in% text_like)
      if (!same) {
        issues[[paste0("type_", col)]] <- list(
          severity = "warning",
          message = sprintf(
            "Column '%s' is %s, expected %s",
            col, got, want
          )
        )
      }
    }
  }

  ## --- Numeric ranges ---
  if (!is.null(sch$numeric_ranges)) {
    for (col in names(sch$numeric_ranges)) {
      if (!col %in% colnames(dfraw)) next
      v <- dfraw[[col]]
      if (!is.numeric(v)) next
      ok <- v[!is.na(v)]
      if (!length(ok)) next
      rng <- sch$numeric_ranges[[col]]
      lo <- rng[["min"]]
      hi <- rng[["max"]]
      n_out <- sum(ok < lo | ok > hi)
      if (n_out > 0L) {
        issues[[paste0("range_", col)]] <- list(
          severity = "warning",
          message = sprintf(
            "Column '%s' has %d value(s) outside [%s, %s]",
            col, n_out, format(lo), format(hi)
          )
        )
      }
    }
  }

  ## --- Missingness ---
  if (!is.null(sch$max_missing_fraction)) {
    for (col in names(sch$max_missing_fraction)) {
      if (!col %in% colnames(dfraw)) next
      frac <- sum(is.na(dfraw[[col]])) / max(1L, nrow(dfraw))
      cap <- sch$max_missing_fraction[[col]]
      if (frac > cap) {
        issues[[paste0("missing_", col)]] <- list(
          severity = "warning",
          message = sprintf(
            "Column '%s' is %.1f%% missing, above the expected %.1f%%",
            col, 100 * frac, 100 * cap
          )
        )
      }
    }
  }

  ## --- Categorical value sets ---
  if (!is.null(sch$expected_value_sets)) {
    for (col in names(sch$expected_value_sets)) {
      if (!col %in% colnames(dfraw)) next
      actual_vals <- unique(dfraw[[col]])
      expected_vals <- sch$expected_value_sets[[col]]
      unexpected <- setdiff(actual_vals, expected_vals)
      if (length(unexpected) > 0L) {
        issues[[paste0("unexpected_", col)]] <- list(
          severity = "warning",
          message = sprintf(
            "Column '%s' has unexpected values: %s",
            col, paste(unexpected, collapse = ", ")
          )
        )
      }
    }
  }
  issues
}

## ----- Apply schema validation; stop on fatal, warn otherwise -----

#' Apply Schema Validation, Stopping on Fatal Issues
#'
#' Runs [valsch()] (or, for a list of rules,
#' [valrules()]) and
#' acts on the result: the first fatal issue stops with an error, and every
#' warning-severity issue is raised as an R warning. Put it at the top of an
#' analysis script so that a re-released file with a missing column stops
#' the run before any result is computed.
#'
#' @details
#' Issues are handled in the order the validator returns them; a fatal issue
#' stops at once, so warnings after it are not raised. With a list of rules
#' the same contract applies to each rule's \code{severity}.
#'
#' Unlike [valsch()], this function refuses to
#' check against
#' nothing, because a validation that checks nothing must not report success.
#' Errors: \code{dfraw} not a data frame; \code{prov} a data frame;
#' \code{prov} \code{NULL} or an empty list; a list that mixes rules
#' with other elements; an unnamed list that is not all rules; something
#' other than a list; a provenance list with no \code{schema} element (the
#' message names the elements it has, so a typo such as \code{scheme}
#' shows); an empty schema (\code{list(schema = list())}).
#'
#' @param dfraw The data frame to validate.
#' @param prov A provenance list as returned by
#'   [loadprov()] (with a \code{schema} element), or
#'   one rule or a list
#'   of rules from [rul()], run with
#'   [valrules()] under the same
#'   stop-on-fatal contract.
#' @return Invisibly, \code{TRUE} if no issues were found and \code{FALSE}
#'   if only warning-severity issues were found (each raised as a warning).
#'   Errors if any fatal issue is present.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' prov <- list(schema = list(expected_columns = "id"))
#' schval(data.frame(id = 1), prov)
#' # A missing required column is fatal:
#' try(schval(data.frame(x = 1), prov))
#'
#' # a warning-level issue is raised as a warning and the result is FALSE
#' ranged <- list(schema = list(numeric_ranges = list(v = c(min = 0, max = 1))))
#' ok <- withCallingHandlers(
#'   schval(data.frame(v = c(0.5, 3)), ranged),
#'   warning = function(w) {
#'     message("warning: ", conditionMessage(w))
#'     invokeRestart("muffleWarning")
#'   }
#' )
#' ok
#'
#' # rules work the same way
#' rules <- list(rul("id_positive", function(v) v > 0, col = "id", sev = "fatal"))
#' try(schval(data.frame(id = c(1, -2)), rules))
#'
#' # a provenance without a schema is refused, not passed
#' try(schval(data.frame(id = 1), list(scheme = list())))
#' @export
schval <- function(dfraw, prov) {
  if (!is.data.frame(dfraw)) stop("schval: `dfraw` must be a data frame", call. = FALSE)
  if (is.data.frame(prov)) {
    stop("`prov` must be a provenance list or a list of rules, not a data frame", call. = FALSE)
  }
  is_rule <- vapply(prov, inherits, logical(1), "bricklayer_rule")
  is_rule_list <- inherits(prov, "bricklayer_rule") || (is.list(prov) && length(prov) && all(is_rule))
  if (!is_rule_list && is.list(prov) && any(is_rule)) {
    # a list that mixes rules with anything else (a number, a nested list of rules) would fall
    # through to valsch() and pass silently; it is neither contract, so it is refused
    stop(sprintf(paste("`prov` mixes rules with other elements (element %d is not a rule):",
                       "pass rules only, or a provenance list"), which(!is_rule)[[1L]]), call. = FALSE)
  }
  if (!is_rule_list && is.list(prov) && length(prov) && is.null(names(prov))) {
    stop("`prov` must be a named provenance list (with `schema`) or a list of rules", call. = FALSE)
  }
  if (!is_rule_list && !is.null(prov) && !is.list(prov)) {
    stop("`prov` must be a provenance list or a list of rules", call. = FALSE)
  }
  # asked to validate, there must be something to validate against: NULL, an empty list or a
  # provenance without `schema` (a typo such as `scheme`) returned TRUE having checked nothing
  # (review of 02a38be, M2)
  if (is.null(prov) || (is.list(prov) && !length(prov))) {
    stop("`prov` is empty: there is no schema to validate against (infsch() makes one)", call. = FALSE)
  }
  if (!is_rule_list && is.list(prov) && is.null(prov$schema)) {
    stop(sprintf("`prov` has no `schema` element (it has %s): nothing would be validated",
                 paste(names(prov), collapse = ", ")), call. = FALSE)
  }
  # the same for a schema with no fields: list(schema = list()) returned TRUE (review of e57fed5)
  if (!is_rule_list && is.list(prov$schema) && !length(prov$schema)) {
    stop("the schema is empty (list()): there is nothing to validate against (infsch() makes one)",
         call. = FALSE)
  }
  issues <- if (is_rule_list) valrules(dfraw, prov) else valsch(dfraw, prov)
  for (nm in names(issues)) {
    iss <- issues[[nm]]
    if (iss$severity == "fatal") stop(iss$message, call. = FALSE)
    if (iss$severity == "warning") warning(iss$message, call. = FALSE)
  }
  invisible(length(issues) == 0L)
}

## ----- Socrata + ArcGIS resolvers (same contract as rslvckan) -----

#' Resolve a Download URL via the Socrata Metadata API
#'
#' Checks that a dataset still exists on a Socrata open-data portal and
#' returns its full CSV export URL. Socrata powers the Calgary, Chicago and
#' New York City portals used across the MORIE family; a dataset is named by
#' its portal domain and a four-by-four id such as \code{ijzp-q8t2}.
#'
#' @details
#' One request is made, to \code{https://<domain>/api/views/<id>.json}. If
#' it answers with JSON that has an \code{id} field the dataset is taken to
#' exist. The function then returns the portal's export of every row, the URL
#' \code{https://<domain>/api/views/<id>/} followed by
#' \code{rows.csv?accessType=DOWNLOAD}. The id is not checked further, and the
#' export URL is not fetched.
#'
#' \code{NULL} is returned when \code{prov} is \code{NULL}, when the
#' domain or id is missing, when the request fails (offline, HTTP error,
#' invalid JSON) or when the metadata has no \code{id}. Errors: a
#' \code{prov} that is not a list; a domain that is not a public host
#' (\code{localhost}, a private address, a single-label name).
#'
#' @param prov A provenance list as returned by
#'   [loadprov()], or \code{NULL}.
#'   It must have two fields. The first is \code{dataset$socrata_domain}, a
#'   host name without scheme such as \code{"data.cityofchicago.org"}. The
#'   second is \code{dataset$socrata_id}, the four-by-four dataset id such as
#'   \code{"ijzp-q8t2"}.
#' @return The CSV export URL as a length-1 character string, or \code{NULL}
#'   if the fields are missing, the request fails, or the metadata reports an
#'   error.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Missing fields return NULL rather than erroring:
#' rslvsoc(list())
#' rslvsoc(list(dataset = list(socrata_domain = "data.cityofchicago.org")))
#'
#' # a local host is refused before any request
#' try(rslvsoc(list(dataset = list(
#'   socrata_domain = "localhost", socrata_id = "abcd-1234"))))
#'
#' @examplesIf interactive()
#' # needs the network
#' prov <- list(dataset = list(
#'   socrata_domain = "data.cityofchicago.org",
#'   socrata_id = "ijzp-q8t2"
#' ))
#' rslvsoc(prov)
#' @export
rslvsoc <- function(prov) {
  if (is.null(prov)) {
    return(NULL)
  }
  if (!is.list(prov)) stop("rslvsoc: `prov` must be a provenance list (loadprov())", call. = FALSE)
  domain <- prov$dataset$socrata_domain
  id <- prov$dataset$socrata_id
  if (is.null(domain) || is.null(id)) {
    return(NULL)
  }
  base <- .rmbl_check_public_url(paste0("https://", domain), "socrata_domain")
  meta_url <- paste0(base, "/api/views/", id, ".json")
  meta <- tryCatch(.rmbl_read_json(meta_url, strict = FALSE), error = function(e) NULL)
  if (is.null(meta) || is.null(meta$id)) {
    return(NULL)
  }
  paste0(base, "/api/views/", id, "/rows.csv?accessType=DOWNLOAD")
}

#' Resolve a Query URL via ArcGIS FeatureServer Metadata
#'
#' Checks that an ArcGIS FeatureServer layer still exists and returns a
#' query URL that downloads every feature of the layer as GeoJSON.
#' FeatureServer layers back the Toronto Police Service open-data portal
#' and many municipal portals used across the MORIE family.
#'
#' @details
#' Trailing slashes are dropped from \code{dataset$arcgis_layer_url}, the
#' URL is checked (public \code{https} only), and one request is made to
#' \code{<layer>?f=json}. If the answer is JSON with a \code{name} and no
#' \code{error} element, the function returns
#' \code{<layer>/query?where=1\%3D1&outFields=*&f=geojson}: every row
#' (\code{where=1=1}), every field, as GeoJSON. ArcGIS servers return at
#' most their \code{maxRecordCount} features per request, so a large layer
#' needs paging (\code{resultOffset}) by the caller; the URL is not fetched
#' here.
#'
#' \code{NULL} is returned when \code{prov} is \code{NULL}, when the
#' field is missing, when the request fails or when the metadata reports an
#' error. Errors: a \code{prov} that is not a list; a layer URL that is
#' not public \code{https}.
#'
#' @param prov A provenance list as returned by
#'   [loadprov()], or \code{NULL}.
#'   It must have the field \code{dataset$arcgis_layer_url}, a
#'   FeatureServer layer root. An example is\cr
#'   \code{https://services.arcgis.com/.../}\cr
#'   followed by \code{Assault_Open_Data/FeatureServer/0}.
#' @return The layer query URL as a length-1 character string, or
#'   \code{NULL} if the field is missing, the request fails, or the layer
#'   metadata reports an error.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Missing fields return NULL rather than erroring:
#' rslvarc(list())
#'
#' # only https layer URLs are accepted
#' try(rslvarc(list(dataset = list(
#'   arcgis_layer_url = "ftp://example.org/FeatureServer/0"))))
#' try(rslvarc("not a list"))
#'
#' @examplesIf interactive()
#' # needs the network
#' prov <- list(dataset = list(arcgis_layer_url = paste0(
#'   "https://services.arcgis.com/S9th0jAJ7bqgIRjw/arcgis/rest/services/",
#'   "Neighbourhood_Crime_Rates_Open_Data/FeatureServer/0"
#' )))
#' rslvarc(prov)
#' @export
rslvarc <- function(prov) {
  if (is.null(prov)) {
    return(NULL)
  }
  if (!is.list(prov)) stop("rslvarc: `prov` must be a provenance list (loadprov())", call. = FALSE)
  layer <- prov$dataset$arcgis_layer_url
  if (is.null(layer)) {
    return(NULL)
  }
  layer <- .rmbl_check_public_url(sub("/+$", "", layer), "arcgis_layer_url")
  meta <- tryCatch(.rmbl_read_json(paste0(layer, "?f=json"), strict = FALSE),
    error = function(e) NULL
  )
  if (is.null(meta) || !is.null(meta$error) || is.null(meta$name)) {
    return(NULL)
  }
  paste0(layer, "/query?where=1%3D1&outFields=*&f=geojson")
}
