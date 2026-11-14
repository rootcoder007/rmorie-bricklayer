# Curated datasets at data.rmorie.com (the address comes from the signed
# services document), with no sign-in and no key. The same tables rmorie and
# morie pull; a manifest lists every table with its rows, columns, SHA-256
# and the BigQuery public dataset it was built from.

#' Curated datasets at data.rmorie.com
#'
#' The MORIE project keeps databases materialised from Google BigQuery
#' public datasets (Chicago crime, EPA air quality, US census, FEC, FDA,
#' NOAA, NHTSA, Hacker News, Ethereum, World Bank, ...) and serves their
#' tables from the edge, under the data access terms at
#' \code{www.rmorie.com/data-license/}. They need no sign-in and no key. The
#' service address comes from \code{\link{svcs}}.
#' \code{dmnf()} returns the gateway's manifest
#' (every table with rows, columns, size, SHA-256 and its BigQuery source),
#' kept for a day; \code{dtabs()} the same as a data frame;
#' \code{dload("db/table")} one table as a data frame, cached
#' under \code{tempdir()} (or the directory in
#' \code{options(rmoriebricklayer.dcache = )}) so later calls are
#' local.
#' From the shell: \code{rmoriebricklayer data list} and
#' \code{rmoriebricklayer data pull db/table [--out FILE.csv]}.
#'
#' @details
#' The manifest is cached as \code{manifest.json} in the cache folder and
#' fetched again when it is more than a day old or \code{refresh = TRUE}. A
#' reply that is not a manifest (not a JSON object with a list of datasets
#' each carrying a \code{key}), or one that lists no tables while the cached
#' copy lists some, is refused and the cached copy kept.
#'
#' \code{dload()} downloads \code{db/table.csv.gz} once into the
#' cache folder (as \code{db__table.csv.gz}) and checks its SHA-256 against the
#' manifest before every use, cached or not: a file that does not match is
#' deleted and refused (after one refresh of the manifest, since a table
#' rebuilt upstream has a new digest). When the manifest cannot be fetched,
#' the last copy on disk, however old, supplies the digest; with none, a fresh
#' download is not kept and a cached file is kept but not used. The CSV is
#' read in compiled code with the same result as
#' \code{read.csv(gzfile(f), stringsAsFactors = FALSE)}, two malformed shapes
#' apart, which are refused with the record they are in where \code{read.csv()}
#' changes the data without a word: a record with more fields than the header
#' (\code{read.csv()} turns the first column into row names) and a quote mark
#' inside an unquoted field (\code{read.csv()} takes the rest of the file as one
#' quoted run). Tables that inflate
#' past 512 MiB are read by \code{read.csv()} itself, a piece at a time. A
#' table whose SHA-256 matches the manifest is the file the service holds, so
#' it is read whatever its size; one the manifest lists without a digest may
#' decompress to at most the option \code{rmoriebricklayer.maxcsvbytes}
#' (1 GiB by default). A large table needs memory for all of it: a 1 GB
#' decompressed CSV takes a few GB of RAM as a data frame.
#'
#' A table the manifest lists without any digest is used with a warning, once
#' per session and table.
#'
#' \code{MORIE_DATA_URL} sets another address for the service (https and
#' public). No key is sent to either. Tables whose source terms do not allow
#' redistribution (ICPSR studies, among them the NCVS 38604 extract, and any
#' table the manifest marks restricted, with \code{access} other than
#' \code{"open"} or \code{"public"} or \code{restricted: true}) are not served:
#' \code{dmnf()} and \code{dtabs()} leave them out (the listing counts them in
#' one line), and \code{dload()} refuses them before any request, saying
#' where to get them. Downloads draw a progress bar when
#' \code{options(morie.progress)} allows it.
#'
#' Errors: \code{refresh} not \code{TRUE} or \code{FALSE}; the service
#' unavailable; a \code{key} that is not of the form \code{db/table}, not
#' listed in the manifest, or a table that is not served; a digest mismatch.
#'
#' @param refresh Logical scalar, default \code{FALSE}: fetch again even when a
#'   day-old copy (of the manifest, or for \code{dload()} of the
#'   table) is cached.
#' @param key Character scalar, a \code{db/table} key from the manifest (the
#'   \code{key} column of \code{dtabs()}).
#' @param cols Character vector, default \code{NULL} (every column): the
#'   columns to read, by the names in the manifest or as \code{dload()}
#'   returns them. The others are skipped as the file is read.
#' @param n A whole number, default \code{Inf}: at most this many rows are
#'   kept, and reading stops there.
#' @param keep \code{NULL}, or a function of one data frame that returns
#'   \code{TRUE} for the rows to keep. The table is read a piece at a time
#'   and \code{keep} is called on each piece, so a table too large for
#'   memory can be reduced to the part that is wanted (one province, one
#'   year) without ever being held whole. It sees every column, whatever
#'   \code{cols} says is returned.
#' @param file Logical scalar, default \code{FALSE}. \code{TRUE} downloads
#'   and verifies the table and returns the path of its gzip-compressed CSV
#'   without reading it, for tools that query a file in place.
#' @param token Ignored, with a warning: the tables need no key, and none is
#'   sent. Kept so that calls written for earlier versions still run.
#' @return \code{dmnf()}: the manifest as a list (element
#'   \code{datasets}, one list per table served with at least \code{key},
#'   attribute \code{unserved} the number of tables left out; and as the
#'   service provides them \code{rows}, \code{columns}, sizes, the SHA-256 of
#'   the compressed file and the BigQuery \code{source});
#'   \code{dtabs()}: a data frame with \code{key},
#'   \code{name} (the description, else the source, else the key), integer
#'   \code{rows} and \code{source} (class
#'   \code{dtabs}, which prints one left-aligned line per
#'   table, cut to the console width);
#'   \code{dload()}: the table as a data frame.
#' @seealso \code{\link{svcs}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Offline, against a cache folder holding a manifest and one table made
#' # here (nothing is fetched).
#' cache <- file.path(tempdir(), "data-hub-example")
#' dir.create(cache)
#' old <- options(rmoriebricklayer.dcache = cache)
#' f <- file.path(cache, "demo__counts.csv.gz")
#' con <- gzfile(f, "w")
#' write.csv(
#'   data.frame(region = c("a", "b"), n = c(3L, 5L)),
#'   con,
#'   row.names = FALSE
#' )
#' close(con)
#' m <- list(
#'   datasets = list(list(
#'     key = "demo/counts",
#'     rows = 2,
#'     source = "an example",
#'     meta = list(description = "Counts by region"),
#'     sha256_gz = csha256(readBin(f, "raw", file.size(f)))
#'   ))
#' )
#' writeLines(tojs(m, auto_unbox = TRUE), file.path(cache, "manifest.json"))
#'
#' dtabs()
#' dload("demo/counts")
#'
#' # keys are checked against the manifest
#' try(dload("counts"))
#' try(dload("demo/other"))
#'
#' # a cached file that no longer matches its digest is deleted and refused
#' writeBin(as.raw(1:10), f)
#' try(dload("demo/counts"))
#' file.exists(f)
#'
#' options(old)
#' unlink(cache, recursive = TRUE)
#'
#' @examplesIf interactive()
#' # the real service: needs the network, no sign-in
#' head(dtabs())
#' df <- dload("chicago_crime/incidents")
#' @export
dmnf <- function(refresh = FALSE) {
  .bl_data_served(.bl_dmnf_raw(refresh))
}

#' @rdname dmnf
#' @export
dtabs <- function(refresh = FALSE) {
  m <- dmnf(refresh = refresh)
  ds <- m$datasets
  if (length(ds)) {
    keys <- vapply(ds, function(d) d[["key"]], "")
    names <- vapply(ds, .bl_data_name, "")
    rows <- vapply(ds, function(d) as.integer(d[["rows"]] %||% NA), 1L)
    sources <- vapply(ds, function(d) (d[["source"]] %||% "")[[1L]], "")
    out <- .bl_data_tables_df(keys, names, rows, sources)
  } else {
    out <- .bl_data_tables_df(character(), character(), integer(), character())
  }
  attr(out, "unserved") <- attr(m, "unserved")
  out
}

#' @export
print.bricklayer_data_tables <- function(x, ...) {
  if (!all(c("key", "name", "rows") %in% names(x))) {
    return(NextMethod())
  }
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
format.bricklayer_data_tables <- function(x, ...) {
  if (!all(c("key", "name", "rows") %in% names(x))) {
    return(utils::capture.output(print(as.data.frame(unclass(x)))))
  }
  txt <- .bl_format_data_tables(x, width = 72L)
  lines <- strsplit(sub("\n+$", "", txt), "\n", fixed = TRUE)[[1L]]
  .rmbl_stat_block(
    "Curated tables at data.rmorie.com",
    facts = list(Tables = nrow(x)),
    notes = lines
  )
}

#' @rdname dmnf
#' @export
dload <- function(
  key,
  refresh = FALSE,
  token = NULL,
  cols = NULL,
  n = Inf,
  keep = NULL,
  file = FALSE
) {
  .bl_data_check_keyarg(key)
  .bl_check_flag(refresh, "refresh")
  .bl_check_flag(file, "file")
  part <- .bl_csv_part_args(cols, n, keep)
  # a table that is not served is refused before any request
  if (.bl_data_restricted(key)) {
    .bl_data_unserved_stop(key)
  }
  if (!is.null(token)) {
    warning(
      "dload(): `token` is ignored: the curated tables need no key",
      call. = FALSE
    )
  }
  .bl_data_known(key)
  dest <- file.path(
    .bl_data_cache_dir(),
    paste0(gsub("/", "__", key, fixed = TRUE), ".csv.gz")
  )
  cached <- !refresh && file.exists(dest)
  if (!cached) {
    .bl_data_get(.bl_data_path(key), dest)
  }
  how <- .bl_data_check_sha(key, dest, cached = cached)
  if (file) {
    return(dest)
  }
  if (part) {
    return(.bl_csv_part(dest, cols, n, keep))
  }
  .bl_data_big_note(key)
  # a file whose digest matches the manifest is the service's own, not a
  # decompression bomb, so the size cap for untrusted CSVs does not apply:
  # tables of 95 MB gzip and more inflate past 1 GiB and were refused
  .bl_read_csv_gz(
    dest,
    lim = if (identical(attr(how, "verified"), "digest")) {
      Inf
    } else {
      .rmbl_max_csv_bytes()
    }
  )
}

#' The manifest as the service sends it, the tables that are not served
#' included (dmnf() leaves them out).
#' @param refresh Whether to fetch it again.
#' @return The manifest, a list.
#' @noRd
.bl_dmnf_raw <- function(refresh = FALSE) {
  .bl_check_flag(refresh, "refresh")
  p <- file.path(.bl_data_cache_dir(), "manifest.json")
  age <- if (file.exists(p)) {
    as.numeric(difftime(Sys.time(), file.mtime(p), units = "secs"))
  } else {
    Inf
  }
  fresh <- age < 86400
  if (refresh || !fresh) {
    # fetched beside the cached copy and moved over it only once it is a
    # manifest: a refresh that fails leaves the last good one in place, and the
    # digest check falls back on it. The temporary name is this process's own:
    # one shared `manifest.json.part` let parallel refreshes delete each other's
    # file (11 of 12 workers failed; review of 02a38be, C8).
    dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
    tmp <- tempfile(
      pattern = "manifest-",
      tmpdir = dirname(p),
      fileext = ".part"
    )
    on.exit(unlink(tmp), add = TRUE)
    # the manifest is a list of tables (well under 1 MiB): 32 MiB is far past
    # any real one, and a 300 MiB reply (a gzip bomb) was read whole, then
    # failed to allocate (CRAN stress test of 0.5.14)
    .bl_data_get("/manifest.json", tmp, timeout = 60, max_bytes = 32 * 2^20)
    m <- .rmbl_json_text(
      .bl_read_text_capped(tmp, 32 * 2^20),
      simplifyVector = FALSE
    )
    .bl_manifest_check(m, p)
    if (!isTRUE(file.rename(tmp, p))) {
      stop(sprintf("could not store the manifest in %s", p), call. = FALSE)
    }
    return(m)
  }
  .rmbl_json_text(.bl_read_text_capped(p, 32 * 2^20), simplifyVector = FALSE)
}

#' Reads a gzip-compressed CSV as read.csv() reads it, faster.
#'
#' A gzip-compressed CSV as utils::read.csv(gzfile(f), stringsAsFactors = FALSE,
#' skipNul = TRUE) reads it (the same columns, types, names and row names), in a
#' fraction of the time: the file is decompressed by the checked reader, split
#' into columns in C (rmbl_csv.c) and typed by type.convert(), which is what
#' read.csv() does after scan(). read.csv() took 20 to 28 s on a 75 MB table
#' (review of 29a55d8 and after, CSV speed). The fast way holds the whole
#' decompressed table in memory, so it is taken up to `in_memory` bytes (the
#' gzip reader measures the output before it allocates any of it). Past that the
#' table is read as read.csv(gzfile()) reads it, a piece at a time: a 2.6 MB
#' file that inflated to 2.5 GiB of blank lines got the process killed for
#' memory (network stress test of 5e1dce5). A file that is not gzip data at all,
#' though its name ends in .gz, is read as the plain CSV it is, as gzfile() did.
#' Either way the table may decompress to at most the option
#' rmoriebricklayer.maxcsvbytes (1 GiB by default), as the pollution readers'
#' tables may: it was not applied here, and a 612 KB gzip asked for 2 GB (CRAN
#' stress test of b617a3f, #6).
#' @param path The CSV file, gzipped or plain, to read.
#' @param in_memory The most decompressed bytes read the fast way.
#' @param lim The most bytes the table may decompress to; `Inf` for a file
#'   verified against the manifest.
#' @return A data frame.
#' @noRd
#' Checks dload()'s `cols`, `n` and `keep`, and says whether any asks for
#' part of the table.
#' @param cols,n,keep As for dload().
#' @return TRUE when part of the table is asked for.
#' @noRd
.bl_csv_part_args <- function(cols, n, keep) {
  if (
    !is.null(cols) &&
      (!is.character(cols) || !length(cols) || anyNA(cols) ||
        !all(nzchar(cols)))
  ) {
    stop("`cols` must be column names (or NULL for all)", call. = FALSE)
  }
  if (
    !is.numeric(n) || length(n) != 1L || is.na(n) || n < 1 ||
      (is.finite(n) && n != floor(n))
  ) {
    stop("`n` must be one whole number of rows, at least 1", call. = FALSE)
  }
  if (!is.null(keep) && !is.function(keep)) {
    stop("`keep` must be a function of a data frame (or NULL)", call. = FALSE)
  }
  !is.null(cols) || is.finite(n) || !is.null(keep)
}

#' Says, before a table too large for most computers is read whole, how to
#' read part of it. A data frame takes at least 8 bytes a cell.
#' @param key The table's key.
#' @return NULL, invisibly.
#' @noRd
.bl_data_big_note <- function(key) {
  d <- tryCatch(
    Filter(function(e) identical(e$key, key), dmnf()$datasets),
    error = function(e) list()
  )
  if (!length(d)) {
    return(invisible(NULL))
  }
  rows <- suppressWarnings(as.numeric(d[[1L]]$rows %||% NA)[1L])
  nc <- length(d[[1L]]$columns)
  gb <- rows * nc * 8 / 2^30
  if (is.finite(gb) && gb > 2) {
    message(sprintf(
      paste0(
        "%s has %s rows and %d columns: about %.0f GB in memory. To read ",
        "part of it, pass `cols`, `n` or `keep`; `file = TRUE` gives the ",
        "file's path."
      ),
      key,
      format(rows, big.mark = ",", scientific = FALSE),
      nc,
      gb
    ))
  }
  invisible(NULL)
}

#' Reads the header of a CSV being read in part and settles which columns
#' are wanted.
#' @param con The open connection, at the start of the file.
#' @param cols As for dload().
#' @return A list: nm (the data frame's column names) and want (which are
#'   returned).
#' @noRd
.bl_csv_part_head <- function(con, cols) {
  head <- utils::read.csv(
    con,
    nrows = 1L,
    header = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = character()
  )
  raw <- as.character(unlist(head[1L, ], use.names = FALSE))
  nm <- make.names(raw, unique = TRUE)
  want <- rep(TRUE, length(nm))
  if (!is.null(cols)) {
    hit <- match(cols, nm)
    hit[is.na(hit)] <- match(cols[is.na(hit)], raw)
    if (anyNA(hit)) {
      stop(
        sprintf(
          "`cols`: no column %s (the table has: %s)",
          toString(cols[is.na(hit)]),
          toString(nm)
        ),
        call. = FALSE
      )
    }
    want <- seq_along(nm) %in% hit
  }
  # `keep` sees every column; `cols` says which are returned
  list(nm = nm, want = want)
}

#' Reads the next piece of a CSV being read in part, every wanted column as
#' text.
#' @param con The open connection.
#' @param piece Rows to read.
#' @param nm The column names.
#' @param classes "character" for a column read, "NULL" for one skipped.
#' @return A data frame, or NULL at the end of the file.
#' @noRd
.bl_csv_part_piece <- function(con, piece, nm, classes) {
  tryCatch(
    utils::read.csv(
      con,
      nrows = piece,
      header = FALSE,
      col.names = nm,
      colClasses = classes,
      check.names = FALSE,
      stringsAsFactors = FALSE,
      skipNul = TRUE
    ),
    error = function(e) {
      # the end of the file, said by read.csv() as an error
      if (grepl("no lines available", conditionMessage(e), fixed = TRUE)) {
        return(NULL)
      }
      stop(
        "dload: the CSV cannot be read: ",
        conditionMessage(e),
        call. = FALSE
      )
    }
  )
}

#' Reads part of a gzip-compressed CSV, a piece at a time: some columns, the
#' rows a function keeps, at most `n` of them. Memory holds one piece and what
#' has been kept. Types are settled at the end, over the kept rows, as
#' read.csv() settles them over a whole column.
#' @param path The gzipped CSV file.
#' @param cols,n,keep As for dload().
#' @param piece Rows read at a time.
#' @return A data frame.
#' @noRd
.bl_csv_part <- function(path, cols, n, keep, piece = 250000L) {
  path <- .rmbl_file1(path, "path")
  con <- gzfile(path, "rt")
  on.exit(close(con), add = TRUE)
  h <- .bl_csv_part_head(con, cols)
  nm <- h$nm
  want <- h$want
  classes <- ifelse(want | !is.null(keep), "character", "NULL")
  kept <- list()
  have <- 0
  repeat {
    chunk <- .bl_csv_part_piece(con, piece, nm, classes)
    if (is.null(chunk) || !nrow(chunk)) {
      break
    }
    last <- nrow(chunk) < piece
    if (!is.null(keep)) {
      sel <- keep(utils::type.convert(chunk, as.is = TRUE))
      if (!is.logical(sel) || length(sel) != nrow(chunk)) {
        stop(
          "`keep` must return TRUE or FALSE for each row of its data frame",
          call. = FALSE
        )
      }
      chunk <- chunk[which(sel), nm[want], drop = FALSE]
    }
    if (nrow(chunk) > n - have) {
      chunk <- chunk[seq_len(n - have), , drop = FALSE]
    }
    kept[[length(kept) + 1L]] <- chunk
    have <- have + nrow(chunk)
    if (have >= n || last) {
      break
    }
  }
  out <- if (length(kept)) {
    do.call(rbind, kept)
  } else {
    as.data.frame(
      stats::setNames(rep(list(character()), sum(want)), nm[want]),
      stringsAsFactors = FALSE
    )
  }
  out <- utils::type.convert(out, as.is = TRUE)
  rownames(out) <- NULL
  out
}

.bl_read_csv_gz <- function(
  path,
  in_memory = 512 * 2^20,
  lim = .rmbl_max_csv_bytes()
) {
  # a directory is refused by name: gzfile() on one hung (1.0.3)
  path <- .rmbl_file1(path, "path")
  in_memory <- min(in_memory, lim)
  head <- readBin(path, "raw", 2L)
  gz <- length(head) == 2L && head[[1L]] == as.raw(0x1f) &&
    head[[2L]] == as.raw(0x8b)
  if (gz && is.finite(lim)) {
    # a gzip that inflates a thousandfold is a bomb, under the byte cap or not
    lim <- min(lim, .rmbl_max_csv_bytes(file.size(path)))
    in_memory <- min(in_memory, lim)
  }
  if (!gz) {
    if (file.size(path) > lim) {
      .bl_csv_too_big(path, lim)
    }
    if (file.size(path) > in_memory) {
      return(.bl_read_csv_streamed(path))
    }
    return(.bl_csv_from_bytes(readBin(path, "raw", file.size(path))))
  }
  # the checked reader takes at most 2 GB of gzip (which inflates past in_memory
  # anyway); a larger file goes the piece-at-a-time way
  bytes <- .bl_gunzip_held(path, in_memory)
  if (!is.null(bytes)) {
    return(.bl_csv_from_bytes(bytes))
  }
  if (in_memory >= lim) {
    .bl_csv_too_big(path, lim)
  }
  # past what is held in memory: the stream is checked whole (trailers, CRC,
  # size) before read.csv() reads it, which takes a truncated one as short
  .bl_gz_verify(path, lim)
  .bl_read_csv_streamed(path)
}

#' Checks a gzip file whole before the piece-at-a-time read: refuses a
#' truncated or damaged stream, as the in-memory path does, and a table past
#' the cap. Holds the compressed bytes and a 64 kB buffer, not the table.
#' @param path The gzipped file.
#' @param lim The most bytes it may decompress to.
#' @return NULL, invisibly.
#' @noRd
.bl_gz_verify <- function(path, lim) {
  if (file.size(path) > 0x7fffffff) {
    # past what the checked reader takes: the size is counted, 4 MiB a time
    if (is.finite(lim)) .bl_gz_count(path, lim)
    return(invisible(NULL))
  }
  tryCatch(
    .Call(C_rmbl_gunzip_count, readBin(path, "raw", file.size(path)), lim),
    error = function(e) {
      msg <- conditionMessage(e)
      if (grepl("more than the size limit", msg, fixed = TRUE)) {
        .bl_csv_too_big(path, lim)
      }
      stop(e)
    }
  )
  invisible(NULL)
}

#' The large-table path: read.csv() itself, on a gzfile() connection (it reads
#' plain files too).
#' @param path The gzipped CSV file, read in chunks.
#' @return A data frame.
#' @noRd
.bl_read_csv_streamed <- function(path) {
  # a directory is refused by name: gzfile() on one hung (1.0.3)
  path <- .rmbl_file1(path, "path")
  # the field count of every record first: read.csv() reads a table whose header
  # is one field short of its rows with the first column as row names and the
  # data shifted one column left, silently, where the in-memory path refuses
  # "record 3 has 3 fields" (1,624 of 6,000 ragged inputs; final audit of
  # 1.0.0, item 2). count.fields() is one pass over the file and one integer a
  # record.
  con <- gzfile(path, "rt")
  nf <- tryCatch(
    utils::count.fields(
      con,
      sep = ",",
      quote = "\"",
      comment.char = "",
      blank.lines.skip = TRUE
    ),
    error = function(e) {
      stop(
        .rmbl_fn(),
        "the CSV cannot be read: ",
        conditionMessage(e),
        call. = FALSE
      )
    },
    finally = close(con)
  )
  .bl_csv_same_fields(nf[!is.na(nf)])
  con <- gzfile(path, "rt")
  on.exit(close(con), add = TRUE)
  utils::read.csv(
    con,
    stringsAsFactors = FALSE,
    skipNul = TRUE,
    row.names = NULL
  )
}

#' Refuses a table whose records do not all have the header's field count.
#' @param nf The field count of each record, the header's first.
#' @return NULL, invisibly.
#' @noRd
.bl_csv_same_fields <- function(nf) {
  if (length(nf) < 2L) {
    return(invisible(NULL))
  }
  bad <- which(nf != nf[[1L]])
  if (length(bad)) {
    stop(
      sprintf(
        "record %d has %d fields, the header %d",
        bad[[1L]],
        nf[[bad[[1L]]]],
        nf[[1L]]
      ),
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' Reads a CSV held in memory as read.csv() reads it.
#' @param bytes The CSV as a raw vector.
#' @param skip_nul Whether nul bytes are skipped.
#' @return A data frame.
#' @noRd
.bl_csv_from_bytes <- function(bytes, skip_nul = TRUE) {
  parts <- .Call(C_rmbl_csv_split, bytes, skip_nul)
  # a header of no columns ("", blanks, a byte-order mark alone): read.csv()
  # takes each row's one field as its row name, and refuses more; a table of no
  # columns is small, so read.csv() reads it (it was named "1", "2", ...;
  # re-test of the b617a3f CRAN stress fixes)
  if (!length(parts$names)) {
    return(.bl_csv_no_columns(bytes, skip_nul))
  }
  # the bytes decided the plain integer, decimal and logical columns; the rest
  # is text for R to judge
  cols <- lapply(parts$columns, function(v) {
    if (is.character(v)) {
      utils::type.convert(v, as.is = TRUE, na.strings = character())
    } else {
      v
    }
  })
  # the splitter gives one column per name, so there is at least one here (a
  # header of no columns returned above)
  names(cols) <- make.names(parts$names, unique = TRUE)
  structure(
    cols,
    class = "data.frame",
    row.names = c(NA_integer_, -length(cols[[1L]]))
  )
}

#' A TRUE/FALSE argument, said plainly when it is not one
#' @param x The flag's value, checked to be TRUE or FALSE.
#' @param name The argument's name, used in the error message.
#' @return `x`, invisibly.
#' @noRd
.bl_check_flag <- function(x, name) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    stop(.rmbl_fn(), sprintf("`%s` must be TRUE or FALSE", name), call. = FALSE)
  }
  invisible(x)
}

#' Returns the address of the curated-data service: MORIE_DATA_URL when set,
#' else the signed services document's.
#' @return One URL.
#' @noRd
.bl_data_url <- function() {
  env <- sub("/+$", "", trimws(Sys.getenv("MORIE_DATA_URL", unset = "")))
  if (nzchar(env)) {
    # https and a public address only
    return(.rmbl_check_public_url(env, "MORIE_DATA_URL"))
  }
  svc <- .rmbl_services_data()
  if (!identical(svc$mode, "key") || !nzchar(svc$base_url %||% "")) {
    notice <- svcs(offline = TRUE)$notice %||% ""
    stop(
      "the curated-data service is not available right now",
      if (nzchar(notice)) paste0(": ", notice) else "",
      sprintf(
        " (see %s)",
        svc$request_access %||% "https://www.rmorie.com/access/"
      ),
      call. = FALSE
    )
  }
  svc$base_url
}

#' The keys of the tables data.rmorie.com does not serve.
#'
#' Their source terms do not allow redistribution: the ICPSR studies, among
#' them the NCVS 38604 extract. The one list in this package; dmnf() leaves
#' them out and dload() refuses them before any request. The A2AJ case law is
#' an open table.
#' @noRd
.bl_data_unserved_re <- "^(icpsr_|ncvs_38604)"

#' Says whether a table key is one data.rmorie.com does not serve.
#' @param key The table's key, with or without its db/ or files/ prefix.
#' @return TRUE or FALSE for each key.
#' @noRd
.bl_data_restricted <- function(key) {
  grepl(.bl_data_unserved_re, sub("^(db|files)/", "", key))
}

#' Says whether a manifest entry is a table that is not served: its key is on
#' the list, or the manifest marks it (`access` other than "open" or "public",
#' or `restricted: true`, on the entry or in its `meta`).
#' @param d One table's entry in the manifest.
#' @return TRUE or FALSE.
#' @noRd
.bl_data_unserved <- function(d) {
  k <- d[["key"]]
  if (is.character(k) && length(k) == 1L && .bl_data_restricted(k)) {
    return(TRUE)
  }
  for (x in list(d, d[["meta"]])) {
    a <- if (is.list(x)) x[["access"]]
    open <- !is.character(a) || length(a) != 1L ||
      tolower(a) %in% c("open", "public")
    if (!open || (is.list(x) && isTRUE(x[["restricted"]]))) {
      return(TRUE)
    }
  }
  FALSE
}

#' The manifest without the tables that are not served; attribute
#' `unserved` counts them.
#' @param m The manifest, as .bl_dmnf_raw() returns it.
#' @return The manifest.
#' @noRd
.bl_data_served <- function(m) {
  if (!is.list(m)) {
    return(m)
  }
  ds <- m$datasets
  off <- vapply(ds, function(d) is.list(d) && .bl_data_unserved(d), NA)
  if (any(off)) {
    m$datasets <- ds[!off]
  }
  attr(m, "unserved") <- sum(off)
  m
}

#' Refuses a table that is not served, before any request.
#' @param key The table's key.
#' @noRd
.bl_data_unserved_stop <- function(key) {
  stop(
    key,
    " is not served by data.rmorie.com: ",
    if (.bl_data_restricted(key)) {
      paste(
        "ICPSR's terms do not allow redistribution; download it from ICPSR",
        "(https://www.icpsr.umich.edu)"
      )
    } else {
      paste(
        "its source terms do not allow redistribution; download it from its",
        "source"
      )
    },
    call. = FALSE
  )
}

#' Returns the directory of the data cache, made when missing.
#' @return A path.
#' @noRd
.bl_data_cache_dir <- function() {
  d <- .rmbl_getopt_ok(
    "dcache",
    NULL,
    function(v) is.character(v) && length(v) == 1L && !is.na(v),
    "one folder path"
  )
  if (is.null(d) || !nzchar(d)) {
    d <- file.path(tempdir(), "rmoriebricklayer-data")
  }
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

#' Raises an interrupt again and turns any other error into a value.
#'
#' A Ctrl-C that a native call took is raised as R's interrupt condition and
#' ends the command with 130. When that condition finds no handler the barrier
#' says it as an error, \dQuote{<entry>: interrupted}, and a tryCatch(error = )
#' that swallows errors swallowed the Ctrl-C: `rmbl data pull` went on for 65 s
#' once in ten runs (final audit of 1.0.0, #11). Such an error is raised again
#' as the interrupt it was; any other error gives `value`.
#' @param e The condition caught.
#' @param value What any other error gives.
#' @return `value`.
#' @noRd
.bl_unless_interrupted <- function(e, value = NULL) {
  if (grepl("(^|: )interrupted$", conditionMessage(e))) {
    signalCondition(structure(
      list(message = "interrupt", call = NULL),
      class = c("interrupt", "condition")
    ))
    invokeRestart("abort")
  }
  value
}

#' Downloads a path from the curated-data service (no key: none is needed).
#' @param path The path on the service.
#' @param dest The local file the downloaded table is written to.
#' @param timeout Seconds before the download gives up.
#' @param max_bytes The most bytes the download may write.
#' @return `dest`, invisibly.
#' @noRd
.bl_data_get <- function(path, dest, timeout = 600, max_bytes = 2^31) {
  old <- options(timeout = max(getOption("timeout", 60), timeout))
  on.exit(options(old), add = TRUE)
  hdr <- c("User-Agent" = "rmoriebricklayer/1 (+https://www.rmorie.com)")
  lb <- .bl_data_label(path)
  label <- lb$label
  size <- lb$size
  part <- .bl_data_part_bytes()
  if (!is.null(size) && is.finite(size) && size > 2 * part) {
    return(.bl_data_get_parts(path, dest, hdr, label, size, part, timeout))
  }
  rc <- tryCatch(
    bldl(
      paste0(.bl_data_url(), path),
      dest,
      headers = hdr,
      label = label,
      size = size,
      tmout = timeout,
      maxbytes = max_bytes
    ),
    error = function(e) .bl_unless_interrupted(e, e),
    warning = function(w) w
  )
  if (inherits(rc, "condition")) {
    .bl_data_get_failed(rc, label)
  }
  invisible(dest)
}

#' The size of one part of a large download (option
#' `rmoriebricklayer.dpart`, default 90 MB).
#' @return A number of bytes.
#' @noRd
.bl_data_part_bytes <- function() {
  .rmbl_getopt_ok(
    "dpart",
    90 * 2^20,
    function(v) is.numeric(v) && length(v) == 1L && is.finite(v) && v >= 2^20,
    "a number of bytes, at least 1 MB"
  )
}

#' Downloads a large table in parts, each a byte range of the file.
#'
#' A slow or broken connection loses at most one part: each part is retried by
#' the transport, kept on disk once whole, and a later run starts from the
#' first part still missing. The parts are joined into `dest`, whose SHA-256
#' the caller checks against the manifest.
#' @param path,dest,timeout As for .bl_data_get().
#' @param hdr The request headers.
#' @param label The table's key.
#' @param size The file's size, from the manifest.
#' @param part The size of one part.
#' @return `dest`, invisibly.
#' @noRd
.bl_data_get_parts <- function(path, dest, hdr, label, size, part, timeout) {
  starts <- seq(0, size - 1, by = part)
  n <- length(starts)
  pdir <- paste0(dest, ".parts")
  dir.create(pdir, recursive = TRUE, showWarnings = FALSE)
  pfile <- file.path(pdir, sprintf("%05d", seq_len(n)))
  for (i in seq_len(n)) {
    a <- starts[i]
    want <- min(a + part, size) - a
    if (file.exists(pfile[i]) && identical(file.size(pfile[i]), want)) {
      next
    }
    unlink(pfile[i])
    rc <- tryCatch(
      bldl(
        paste0(.bl_data_url(), path),
        pfile[i],
        headers = c(hdr, Range = sprintf("bytes=%.0f-%.0f", a, a + want - 1)),
        label = sprintf("%s (part %d of %d)", label, i, n),
        size = want,
        tmout = timeout,
        maxbytes = want
      ),
      error = function(e) .bl_unless_interrupted(e, e),
      warning = function(w) w
    )
    if (inherits(rc, "condition")) {
      .bl_data_get_failed(rc, label)
    }
    if (!identical(file.size(pfile[i]), want)) {
      got <- file.size(pfile[i])
      unlink(pfile[i])
      stop(
        sprintf(
          paste(
            "data.rmorie.com: part %d of %s came back with %.0f bytes, not",
            "%.0f; run again to resume from that part"
          ),
          i, label, got, want
        ),
        call. = FALSE
      )
    }
  }
  .bl_data_join(pfile, dest)
  unlink(pdir, recursive = TRUE)
  invisible(dest)
}

#' Joins the parts of a download into one file.
#' @param pfile The part files, in order.
#' @param dest The file written.
#' @return `dest`, invisibly.
#' @noRd
.bl_data_join <- function(pfile, dest) {
  # written beside `dest` and renamed when whole: a join cut short (a
  # killed session) left a file that looked finished until its digest was
  # checked
  tmp <- paste0(dest, ".join")
  total <- sum(file.size(pfile))
  full <- function() {
    stop(
      sprintf(
        paste0(
          "cannot join the parts of %s: the folder %s is full or cannot be ",
          "written (the file needs %.0f MB). Name a folder with room in ",
          "options(rmoriebricklayer.dcache = ) and run again."
        ),
        basename(dest),
        dirname(dest),
        total / 2^20
      ),
      call. = FALSE
    )
  }
  out <- file(tmp, "wb")
  open <- TRUE
  on.exit(
    {
      if (open) {
        close(out)
      }
      unlink(tmp)
    },
    add = TRUE
  )
  for (p in pfile) {
    if (!.bl_data_append(p, out)) {
      full()
    }
    # a part is freed once it is in the joined file: the two together took
    # twice the table's size on disk
    unlink(p)
  }
  close(out)
  open <- FALSE
  # a write that failed only when the file was closed shows in its size
  if (!identical(as.numeric(file.size(tmp)), as.numeric(total))) {
    full()
  }
  unlink(dest)
  if (!file.rename(tmp, dest)) {
    full()
  }
  invisible(dest)
}

#' Appends one part file to an open connection.
#' @param p The part file.
#' @param out The connection written to.
#' @return TRUE, or FALSE when a write failed (writeBin() only warns when the
#'   disk is full).
#' @noRd
.bl_data_append <- function(p, out) {
  con <- file(p, "rb")
  on.exit(close(con), add = TRUE)
  repeat {
    buf <- readBin(con, "raw", 2^24)
    if (!length(buf)) {
      return(TRUE)
    }
    ok <- tryCatch(
      {
        .bl_write_raw(buf, out)
        TRUE
      },
      warning = function(w) FALSE,
      error = function(e) FALSE
    )
    if (!ok) {
      return(FALSE)
    }
  }
}

#' writeBin(), under a name the tests can replace.
#' @param buf The bytes.
#' @param out The connection.
#' @return NULL, invisibly.
#' @noRd
.bl_write_raw <- function(buf, out) {
  writeBin(buf, out)
  invisible(NULL)
}

#' A fetched manifest, checked before it replaces the cached one: a JSON
#' object listing datasets with keys, and not an empty list in place of one
#' that lists tables.
#' @param m The fetched manifest.
#' @param p The cached manifest's path.
#' @noRd
.bl_manifest_check <- function(m, p) {
  if (!is.list(m) || (length(m) && is.null(names(m)))) {
    stop(
      "the manifest fetched from data.rmorie.com is not a JSON object",
      call. = FALSE
    )
  }
  # `{}` or `{"error": ...}` from a gateway is not a manifest: it replaced the
  # good copy, and the digests with it (C9). A manifest is an object whose
  # `datasets` is an array of objects with a key.
  ds <- m$datasets
  if (
    !is.list(ds) ||
      !is.null(names(ds)) ||
      !all(vapply(
        ds,
        function(d) is.list(d) && is.character(d$key) && length(d$key) == 1L,
        NA
      ))
  ) {
    stop(
      "the reply from data.rmorie.com is not a manifest (no list of ",
      "datasets): the cached copy is kept",
      call. = FALSE
    )
  }
  # an empty list does not replace a manifest that lists tables: `{"datasets":
  # []}` took the place of the good copy and, with no digest left, a tampered
  # cached table loaded (review of e57fed5, E10)
  if (!length(ds) && file.exists(p)) {
    old <- tryCatch(
      .rmbl_json_text(
        .bl_read_text_capped(p, 32 * 2^20),
        simplifyVector = FALSE
      ),
      error = function(e) NULL
    )
    if (is.list(old) && is.list(old$datasets) && length(old$datasets)) {
      stop(
        "the manifest from data.rmorie.com lists no tables: the ",
        "cached copy, which does, is kept",
        call. = FALSE
      )
    }
  }
  invisible(NULL)
}

#' Reads a text file whole with a bound on its decoded size.
#'
#' A text file read whole with a bound on its DECODED size. The transport caps
#' the bytes it writes, but a reply sent with Content-Encoding: gzip is stored
#' as sent, and readLines() decompresses a gzip file on its own: 300 MiB of
#' zeros in a 300 KB body were decoded whole and pasted (a 2.3 GB allocation, or
#' an OOM kill; final audit of 1.0.0, #4). A compressed file is read through
#' gzcon() a megabyte at a time and refused past `max_bytes`.
#' @param path The text file, gzipped or not, read up to `max_bytes`.
#' @param max_bytes The most bytes the decoded text may hold.
#' @return One string.
#' @noRd
.bl_read_text_capped <- function(path, max_bytes) {
  # a directory is refused by name: gzfile() on one hung (1.0.3)
  path <- .rmbl_file1(path, "path")
  raw_con <- file(path, "rb")
  magic <- readBin(raw_con, "raw", 2L)
  close(raw_con)
  gz <- length(magic) == 2L && identical(magic, as.raw(c(0x1f, 0x8b)))
  con <- if (gz) gzcon(file(path, "rb")) else file(path, "rb")
  on.exit(close(con), add = TRUE)
  parts <- list()
  total <- 0
  repeat {
    b <- readBin(con, "raw", 2^20)
    if (!length(b)) {
      break
    }
    total <- total + length(b)
    if (total > max_bytes) {
      stop(
        sprintf(
          "%s holds more than %d bytes once decoded: not a manifest",
          basename(path),
          max_bytes
        ),
        call. = FALSE
      )
    }
    parts[[length(parts) + 1L]] <- b
  }
  txt <- rawToChar(unlist(parts, use.names = FALSE))
  Encoding(txt) <- "UTF-8"
  # readLines() dropped a final line break and joined lines with "\n": the same
  # text
  sub("\r?\n$", "", gsub("\r\n", "\n", txt, fixed = TRUE))
}

#' Returns a table's name for the listing.
#'
#' The description, else the source, else the key: the first that is set and not
#' blank (the otis tables carry \code{""} for both, which printed as an empty
#' name)
#' @param d One table's entry in the manifest.
#' @return One string.
#' @noRd
.bl_data_name <- function(d) {
  for (v in list(d$meta$description, d$source, d$key)) {
    if (length(v) && nzchar(trimws(v[[1L]]))) return(v[[1L]])
  }
  ""
}

#' Returns the manifest's SHA-256 for a table.
#'
#' The manifest's SHA-256 for a table, when it lists one (the field may be named
#' sha256 or sha256_gz, of the compressed file as served). NULL when the
#' manifest lists none; a digest field that is not a digest is an error of class
#' bl_bad_digest.
#' @param ds The manifest's list of datasets.
#' @param key The table's key.
#' @return A lower-case hex digest, or NULL.
#' @noRd
.bl_manifest_digest <- function(ds, key) {
  for (d in ds) {
    if (identical(d$key, key)) {
      for (f in c("sha256_gz", "sha256", "sha")) {
        v <- d[[f]]
        if (is.null(v)) {
          next
        }
        # one digest, not a list whose first element happens to be one
        one <- length(v) == 1L && (is.character(v) || is.na(v))
        v <- if (one) sub("^sha256:", "", as.character(v)) else NA_character_
        if (length(v) == 1L && !is.na(v) && grepl("^[0-9a-fA-F]{64}$", v)) {
          return(tolower(v))
        }
        # a digest field that is not a digest is not "no digest": the file
        # cannot be trusted
        stop(structure(
          class = c("bl_bad_digest", "error", "condition"),
          list(
            message = sprintf(
              "the manifest's %s for %s is not a SHA-256 hex digest (%s)",
              f,
              key,
              as.character(v)[1L]
            ),
            call = NULL
          )
        ))
      }
    }
  }
  NULL
}

#' Returns a table's digest from the manifest dmnf() returns.
#'
#' The digest from the manifest as dmnf() returns it (re-fetched when the cached
#' copy is over a day old). A manifest that cannot be had is an error here,
#' never \dQuote{no digest} (review of 52a8883, B1).
#' @param key The table's key.
#' @param refresh Whether to fetch the manifest again.
#' @return A hex digest, or NULL.
#' @noRd
.bl_data_manifest_sha <- function(key, refresh = FALSE) {
  .bl_manifest_digest(dmnf(refresh = refresh)$datasets, key)
}

#' Returns a table's digest from the manifest copy on disk.
#'
#' The digest from the manifest copy on disk, however old: NA when there is no
#' usable copy or it does not list the table, NULL when it lists the table
#' without a digest (as the live manifest with no digest is: the table loads),
#' the digest otherwise.
#' @param key The table's key.
#' @return A hex digest, NULL or NA.
#' @noRd
.bl_data_cached_digest <- function(key) {
  p <- file.path(.bl_data_cache_dir(), "manifest.json")
  if (!file.exists(p)) {
    return(NA)
  }
  m <- tryCatch(
    .rmbl_json_text(
      paste(readLines(p, warn = FALSE), collapse = "\n"),
      simplifyVector = FALSE
    ),
    error = function(e) NULL
  )
  ds <- if (is.list(m)) m$datasets else NULL
  if (!is.list(ds) || !is.null(names(ds))) {
    return(NA)
  }
  listed <- any(vapply(ds, function(d) is.list(d) && identical(d$key, key), NA))
  if (!listed) {
    return(NA)
  }
  .bl_manifest_digest(ds, key)
}

#' Checks a table file against the manifest's SHA-256.
#'
#' A cached or freshly downloaded file that does not match the manifest's
#' SHA-256 is deleted and refused: a tampered cache, a truncated download or a
#' table rebuilt upstream all look the same. When the manifest cannot be
#' fetched, the last copy on disk (however old) still holds the digest the table
#' had and is used; with no copy at all the file cannot be verified and is not
#' kept. A mismatch triggers one refresh of the manifest (a table rebuilt
#' upstream has a new digest), and a refresh that fails changes nothing. Only a
#' file that fails a known digest is deleted. One that cannot be checked now (no
#' manifest from the service and no copy that lists the table) is refused but,
#' when it was already in the cache, kept: it is checked again before every use,
#' and deleting it threw away a genuine table whenever the service was
#' unreachable (review of 02a38be, C9). A file just downloaded and not
#' verifiable is not kept.
#' @param key The table's key.
#' @param dest The file.
#' @param cached Whether the file was already in the cache.
#' @return TRUE, invisibly; an error otherwise.
#' @noRd
.bl_data_check_sha <- function(key, dest, cached = FALSE) {
  want <- .bl_data_want(key, dest, cached)
  # no digest: loaded only when the manifest lists the table (without a digest,
  # as some tables are); a manifest that does not list it at all says nothing
  # about the file, which is refused
  if (is.null(want)) {
    .bl_data_listed(key, dest, cached)
    .bl_data_warn_nodigest(key)
    return(invisible(structure(TRUE, verified = "listed")))
  }
  .bl_data_digest_match(key, dest, want)
  invisible(structure(TRUE, verified = "digest"))
}

#' The tables already warned about this session for having no digest.
#' @noRd
.bl_data_nodigest <- new.env(parent = emptyenv())

#' Warns, once per session and table, that a table the manifest lists without
#' a digest is used unverified.
#' @param key The table's key.
#' @noRd
.bl_data_warn_nodigest <- function(key) {
  if (!isTRUE(.bl_data_nodigest[[key]])) {
    assign(key, TRUE, envir = .bl_data_nodigest)
    warning(
      key,
      " is listed in the manifest of data.rmorie.com without a SHA-256: ",
      "it is used unverified",
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' Builds the listing of curated tables.
#' @param key The tables' keys.
#' @param name Their names.
#' @param rows Their row counts.
#' @param source Their sources.
#' @return A data frame of class `bricklayer_data_tables`.
#' @noRd
.bl_data_tables_df <- function(key, name, rows, source) {
  df <- data.frame(
    key = key,
    name = name,
    rows = rows,
    source = source,
    stringsAsFactors = FALSE
  )
  class(df) <- c("bricklayer_data_tables", "data.frame")
  df
}

#' Formats the listing of curated tables as text.
#'
#' One line per table, key and row count first and the name after, all
#' left-aligned and cut to the width (print.data.frame right-aligned the names
#' and, once a line was wider than the console, put each column in a block of
#' its own). Shared by print() and `rmbl data list`.
#' @param tables The listing, from `.bl_data_tables_df()`.
#' @param width The width to cut lines to, or NULL for the console's.
#' @param hint The line that ends the listing.
#' @return One string.
#' @noRd
.bl_format_data_tables <- function(
  tables,
  width = NULL,
  hint = "dload(\"KEY\") loads one"
) {
  if (!nrow(tables)) {
    return(paste0(
      "no curated tables are listed at data.rmorie.com right now\n",
      .bl_data_unserved_note(tables)
    ))
  }
  if (is.null(width)) {
    width <- suppressWarnings(as.integer(Sys.getenv("COLUMNS", "")))
    if (is.na(width) || width < 40L) {
      width <- max(80L, as.integer(getOption("width", 80L)))
    }
  }
  rows <- ifelse(
    is.na(tables$rows),
    "-",
    formatC(tables$rows, format = "d", big.mark = ",")
  )
  # the manifest is fetched text: what would not print as itself is removed
  # (.rmbl_printable)
  printable <- .rmbl_printable
  tables$key <- printable(tables$key)
  name <- gsub("[[:space:]]+", " ", trimws(printable(tables$name)))
  name[!nzchar(name) | name == tables$key] <- "-"
  kw <- max(nchar("key"), nchar(tables$key))
  rw <- max(nchar("rows"), nchar(rows))
  room <- max(20L, width - kw - rw - 4L)
  cut <- nchar(name) > room
  name[cut] <- paste0(trimws(substr(name[cut], 1L, room - 3L)), "...")
  line <- function(k, r, n) {
    sprintf("%s  %s  %s", formatC(k, width = -kw), formatC(r, width = rw), n)
  }
  paste0(
    line("key", "rows", "name"),
    "\n",
    paste(line(tables$key, rows, name), collapse = "\n"),
    "\n\n",
    sprintf("%d tables; %s\n", nrow(tables), hint),
    .bl_data_unserved_note(tables)
  )
}

#' The line that counts the tables a listing leaves out, or "".
#' @param tables The listing, with attribute `unserved`.
#' @return One string.
#' @noRd
.bl_data_unserved_note <- function(tables) {
  n <- attr(tables, "unserved")
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 1) {
    return("")
  }
  paste0(
    sprintf(
      ngettext(
        n,
        "%d table is not served: its source terms do not",
        "%d tables are not served: their source terms do not"
      ),
      as.integer(n)
    ),
    " allow redistribution\n"
  )
}

#' Refuses a dload() key that is not db/table.
#' @param key The table key to check: one string like `db/table`.
#' @return `key`, invisibly.
#' @noRd
.bl_data_check_keyarg <- function(key) {
  ok <- is.character(key) &&
    length(key) == 1L &&
    grepl("/", key, fixed = TRUE) &&
    !startsWith(key, "/") &&
    !endsWith(key, "/")
  if (!ok) {
    stop("key must be db/table (see dtabs())", call. = FALSE)
  }
  invisible(key)
}

#' Refuses a key the manifest does not list, or lists as a table that is not
#' served; a manifest that cannot be read says nothing, and the download
#' decides.
#' @param key The table's key.
#' @return `key`, invisibly.
#' @noRd
.bl_data_known <- function(key) {
  known <- tryCatch(
    vapply(dmnf()$datasets, function(d) d$key, ""),
    error = function(e) .bl_unless_interrupted(e)
  )
  # an empty list is an answer too: no table is listed, so none is loaded
  if (!is.null(known) && !key %in% known) {
    # left out because it is not served: said so, before any request
    if (.bl_data_marked(key)) {
      .bl_data_unserved_stop(key)
    }
    stop(
      sprintf(
        "no table %s at data.rmorie.com (`%s data list` shows them)",
        key,
        .bl_prog()
      ),
      call. = FALSE
    )
  }
  invisible(key)
}

#' Says whether the manifest copy on disk lists a table as one that is not
#' served (marked restricted). Nothing is fetched: dmnf() has just refreshed
#' the copy when it was stale.
#' @param key The table's key.
#' @return TRUE or FALSE.
#' @noRd
.bl_data_marked <- function(key) {
  p <- file.path(.bl_data_cache_dir(), "manifest.json")
  m <- if (file.exists(p)) {
    tryCatch(
      .rmbl_json_text(
        .bl_read_text_capped(p, 32 * 2^20),
        simplifyVector = FALSE
      ),
      error = function(e) NULL
    )
  }
  ds <- if (is.list(m) && is.list(m$datasets)) m$datasets else list()
  hit <- function(d) {
    is.list(d) && identical(d[["key"]], key) && .bl_data_unserved(d)
  }
  any(vapply(ds, hit, NA))
}

#' The path of a table's file on the curated-data service.
#' @param key The table's key, db/table.
#' @return The path, starting with a slash.
#' @noRd
.bl_data_path <- function(key) {
  parts <- strsplit(key, "/", fixed = TRUE)[[1L]]
  rest <- paste(parts[-1L], collapse = "/")
  sprintf("/%s/%s.csv.gz", parts[[1L]], rest)
}

#' Refuses a table that decompresses past the size cap.
#' @param path The CSV file named in the size error.
#' @param lim The cap, in bytes.
#' @noRd
.bl_csv_too_big <- function(path, lim) {
  stop(
    sprintf(
      paste(
        "%s decompresses to more than %s bytes (options",
        "rmoriebricklayer.maxcsvbytes and rmoriebricklayer.maxgzratio);",
        "raise them to read it"
      ),
      basename(path),
      format(lim, big.mark = ",", scientific = FALSE)
    ),
    call. = FALSE
  )
}

#' A gzip file decompressed in memory, when it fits.
#' @param path The gzipped file to inflate in memory.
#' @param in_memory The most decompressed bytes held.
#' @return The decompressed bytes, or NULL when the file is larger.
#' @noRd
.bl_gunzip_held <- function(path, in_memory) {
  if (file.size(path) > 0x7fffffff) {
    NULL
  } else {
    tryCatch(
      .Call(
        C_rmbl_gunzip_checked,
        readBin(path, "raw", file.size(path)),
        in_memory
      ),
      error = function(e) {
        if (
          grepl("more than the size limit", conditionMessage(e), fixed = TRUE)
        ) {
          NULL
        } else {
          stop(e)
        }
      }
    )
  }
}

#' Counts a gzip file's decompressed size a piece at a time, holding 4 MiB,
#' and refuses it past the cap.
#' @param path The gzipped file whose inflated size is counted.
#' @param lim The cap, in bytes.
#' @return NULL, invisibly.
#' @noRd
.bl_gz_count <- function(path, lim) {
  # a directory is refused by name: gzfile() on one hung (1.0.3)
  path <- .rmbl_file1(path, "path")
  con <- gzfile(path, "rb")
  total <- 0
  tryCatch(
    repeat {
      b <- readBin(con, "raw", 4194304L)
      if (!length(b)) {
        break
      }
      total <- total + length(b)
      if (total > lim) .bl_csv_too_big(path, lim)
    },
    finally = close(con)
  )
  invisible(NULL)
}

#' Reads a CSV whose header has no columns, as read.csv() reads it.
#' @param bytes The CSV as a raw vector.
#' @param skip_nul Whether nul bytes are skipped.
#' @return A data frame.
#' @noRd
.bl_csv_no_columns <- function(bytes, skip_nul) {
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)
  # the fast way reads a last line without its line break silently; given one,
  # so does this
  n <- length(bytes)
  if (n && !bytes[[n]] %in% as.raw(c(10, 13))) {
    bytes <- c(bytes, as.raw(10))
  }
  writeBin(bytes, f)
  # what read.csv() refuses (a header of "" and nothing under it: "first five
  # rows are empty") is refused in words, as the reader refuses
  tryCatch(
    utils::read.csv(f, stringsAsFactors = FALSE, skipNul = skip_nul),
    error = function(e) {
      stop(
        .rmbl_fn(),
        "the CSV cannot be read: ",
        conditionMessage(e),
        call. = FALSE
      )
    }
  )
}

#' The label and the expected size of a download from the service.
#' @param path The path on the service.
#' @return list(label, size): the table's key for a table (its size from the
#'   manifest, or NULL), else the path.
#' @noRd
.bl_data_label <- function(path) {
  label <- sub("^/", "", path)
  size <- NULL
  if (grepl("\\.csv\\.gz$", path)) {
    label <- sub("\\.csv\\.gz$", "", label)
    m <- tryCatch(dmnf(), error = function(e) .bl_unless_interrupted(e))
    for (d in m$datasets %||% list()) {
      if (identical(d$key, label)) {
        size <- d$bytes_gz
        break
      }
    }
  }
  list(label = label, size = size)
}

#' Says why a download from the curated-data service failed.
#' @param rc The error or warning the download raised.
#' @param label The download's label.
#' @noRd
.bl_data_get_failed <- function(rc, label) {
  msg <- conditionMessage(rc)
  if (grepl("\\b410\\b|Gone", msg)) {
    stop(
      label,
      " is not served by data.rmorie.com: ICPSR's terms do not allow ",
      "redistribution; download it from ICPSR (https://www.icpsr.umich.edu)",
      call. = FALSE
    )
  }
  if (grepl("401|403|Unauthorized|Forbidden", msg)) {
    stop(
      sprintf(
        paste(
          "data.rmorie.com asked for a key for %s: the tables need no",
          "sign-in; update the package, or try again later"
        ),
        label
      ),
      call. = FALSE
    )
  }
  stop("data.rmorie.com: ", msg, call. = FALSE)
}

#' Refuses a curated table, deleting its file unless asked not to.
#' @param msg The refusal's error message.
#' @param dest The file.
#' @param delete Whether the file is deleted.
#' @noRd
.bl_data_refuse <- function(msg, dest, delete = TRUE) {
  if (delete) {
    unlink(dest)
  }
  stop(msg, call. = FALSE)
}

#' The SHA-256 a curated table must have: from the manifest, else from the
#' copy of it kept earlier.
#' @param key The table's key.
#' @param dest The file.
#' @param cached Whether the file was already in the cache.
#' @return The digest, or NULL when the manifest lists none.
#' @noRd
.bl_data_want <- function(key, dest, cached) {
  want <- tryCatch(.bl_data_manifest_sha(key), error = function(e) e)
  if (inherits(want, "bl_bad_digest")) {
    .bl_data_refuse(conditionMessage(want), dest)
  }
  if (inherits(want, "error")) {
    want <- tryCatch(.bl_data_cached_digest(key), error = function(e) e)
    if (inherits(want, "error")) {
      .bl_data_refuse(conditionMessage(want), dest)
    }
    if (identical(want, NA)) {
      .bl_data_refuse(
        sprintf(
          paste(
            "%s cannot be verified: the manifest could not be fetched",
            "from data.rmorie.com",
            "(offline or an error) and no earlier copy lists the table;",
            "%s run again when",
            "the service answers"
          ),
          key,
          if (cached) {
            "the cached file is kept unused until then;"
          } else {
            "the download was not kept;"
          }
        ),
        dest,
        delete = !cached
      )
    }
  }
  want
}

#' Refuses a table without a digest that the manifest does not list.
#' @param key The table's key.
#' @param dest The file.
#' @param cached Whether the file was already in the cache.
#' @return NULL, invisibly.
#' @noRd
.bl_data_listed <- function(key, dest, cached) {
  listed <- tryCatch(
    any(vapply(
      dmnf()$datasets,
      function(d) is.list(d) && identical(d$key, key),
      NA
    )),
    error = function(e) !identical(.bl_data_cached_digest(key), NA)
  )
  if (!isTRUE(listed)) {
    .bl_data_refuse(
      sprintf(
        paste0(
          "%s is not listed in the manifest of data.rmorie.com, so the ",
          "file cannot be verified"
        ),
        key
      ),
      dest,
      delete = !cached
    )
  }
  invisible(NULL)
}

#' Refuses a table whose SHA-256 is not the manifest's, after one refresh of
#' the manifest.
#' @param key The table's key.
#' @param dest The file.
#' @param want The digest it must have.
#' @return NULL, invisibly.
#' @noRd
.bl_data_digest_match <- function(key, dest, want) {
  have <- tolower(csha256(readBin(dest, "raw", file.size(dest))))
  if (!identical(have, want)) {
    # a table rebuilt upstream has a new digest in a new manifest: fetch the
    # manifest again before calling the file bad, so a stale cached manifest
    # does not refuse every call
    fresh <- tryCatch(
      .bl_data_manifest_sha(key, refresh = TRUE),
      error = function(e) NULL
    )
    if (is.character(fresh) && length(fresh) == 1L && !is.na(fresh)) {
      want <- fresh
    }
    if (!identical(have, want)) {
      .bl_data_refuse(
        sprintf(
          paste(
            "%s does not match the manifest's SHA-256 (%s... vs %s...):",
            "the cached file was deleted;",
            "run again to download it, and if it still fails the file was",
            "tampered with in transit"
          ),
          key,
          substr(have, 1L, 12L),
          substr(want, 1L, 12L)
        ),
        dest
      )
    }
  }
  invisible(NULL)
}
