## ----- Randomisation lists for trials -----
## A list made before the first participant, committed to (its SHA-256,
## signed and timestamped) and kept concealed; at unblinding anyone can
## check that the list used is the list committed to, and that it is the
## one the stated procedure and seed produce.

#' Make a Randomisation List with a Sealed Commitment
#'
#' Allocates participants to arms by simple, permuted-block or stratified
#' block randomisation, from a seed through the package's NIST SP 800-90A
#' generator ([drbgnew()]), so the list can be regenerated exactly. It
#' returns the list and one SHA-256 commitment to it: sign and timestamp
#' the commitment before the first participant is enrolled, keep the list
#' and the seed with the unblinded statistician, and at unblinding
#' [rallocvrf()] shows that the allocation used is the one committed
#' to.
#'
#' @details
#' Every draw is exact: an arm or a block size is chosen with rejection
#' sampling on 32-bit draws (no modulo bias), and a block is shuffled by
#' Fisher-Yates. With `block = NULL` each participant is allocated on
#' their own (simple randomisation), with probabilities in the ratio
#' `ratio`. Otherwise blocks are drawn one after another, each of a size
#' chosen at random from `block` (every size a multiple of `sum(ratio)`),
#' each holding the arms in the ratio; random block sizes keep the next
#' allocation hard to guess at a site. The list stops at `n` participants,
#' so its last block may be incomplete; the print-out says how far the
#' arms then differ.
#'
#' With `strata`, each stratum has its own sequence of blocks: name the
#' strata and how many places each needs, as a named vector
#' (`c(site1 = 40, site2 = 40)`) or a data frame with the stratum
#' columns and a column `n` (one row per combination, such as site by
#' sex).
#'
#' The commitment is the SHA-256 of the settings, every row of the list and
#' the SHA-256 of the seed, so it binds both the list and the seed: a list
#' edited afterwards, or a seed chosen afterwards to give a wanted list,
#' does not match it. Each field enters it with its length, so settings
#' that differ (a stratum named `"x,y"` against strata `"x"` and `"y"`)
#' never share a commitment; lists made by 1.0.3's first release keep
#' their commitment and still verify. The print-out shows how many
#' participants each arm has, never who is in which arm, and not the seed.
#'
#' Keep `seed = NULL` for a trial: the seed is then 48 bytes from the
#' operating system's generator ([rndbytes()]), which nobody can guess
#' before the list is opened. A number or a word as `seed` gives a list
#' anyone can recompute, which suits teaching and testing, not
#' concealment.
#'
#' With `codes = TRUE` every participant also gets a kit code (six
#' characters, no look-alike letters or digits): sites and pharmacies are
#' given `id` and `kit` only, and the arm stays with the statistician.
#'
#' Errors: fewer than two arms, repeated or empty arm names; a `ratio`
#' that is not one positive whole number per arm; a block size that is
#' not a positive multiple of `sum(ratio)` up to 1000000; `n` that is not
#' a whole number from 1 to 10000000, or that disagrees with the strata's
#' total; a `seed` that is not one value, or a raw `seed` that is not 48
#' bytes.
#'
#' @param n How many participants, a positive whole number. With `strata`,
#'   it may be left out (it is their total).
#' @param arms The arms' names, default `c("A", "B")`.
#' @param ratio Whole numbers, one per arm: the allocation ratio, default
#'   equal.
#' @param block The block sizes to choose from at random, default
#'   `2 * sum(ratio)` and `3 * sum(ratio)` (4 and 6 for two equal arms);
#'   `NULL` for simple randomisation.
#' @param strata `NULL`, or the strata and their numbers of places: a named
#'   vector of counts, or a data frame with the stratum columns and `n`.
#' @param seed `NULL` (default, 48 random bytes), 48 raw bytes, their 96
#'   hexadecimal characters, or a number or word that is expanded to 48
#'   bytes.
#' @param codes Give every participant a kit code, default `FALSE`.
#' @param prefix The start of the participant ids, default `"P"`.
#' @return An object of class `rmbl_alloc`: a data frame with `id`,
#'   `stratum` (with `strata`), `block` (the block's number in its stratum;
#'   `NA` for simple randomisation), `arm` and, with `codes`, `kit`, in
#'   enrolment order. Attribute `"alloc"` holds the settings, the seed (as
#'   hexadecimal) and `digest`, the commitment. It prints as a box of
#'   counts.
#' @seealso [rallocvrf()] at unblinding;
#'   [cpssign()] and
#'   [idcrd()] to sign the commitment;
#'   [tsstmp()] to timestamp it and
#'   [tsvrf()] to check the timestamp;
#'   [prrgdecl()] to declare the outcomes in the same signed record.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # 1:1 in blocks of 4 or 6, for 40 participants
#' a <- ralloc(40, seed = "teaching example")
#' a
#' attr(a, "alloc")$digest            # sign and timestamp this first
#' head(as.data.frame(a))
#'
#' # 2:1, stratified by site, with kit codes for the pharmacy
#' s <- ralloc(arms = c("drug", "placebo"), ratio = c(2, 1),
#'             strata = c(Toronto = 30, Ottawa = 24), codes = TRUE,
#'             seed = 7)
#' s
#' head(as.data.frame(s)[c("id", "kit")])  # what the sites are given
#'
#' # simple randomisation: how many each arm has, against the ratio
#' plot(ralloc(60, block = NULL, seed = 1))
#'
#' # at unblinding: the list is the one committed to
#' rallocvrf(a, digest = attr(a, "alloc")$digest)
#'
#' # a block size the ratio does not divide
#' try(ralloc(30, block = 5))
#' @export
ralloc <- function(
  n = NULL,
  arms = c("A", "B"),
  ratio = rep(1, length(arms)),
  block = 2 * sum(ratio) * c(1, 1.5),
  strata = NULL,
  seed = NULL,
  codes = FALSE,
  prefix = "P"
) {
  set <- .ralloc_settings(n, arms, ratio, block, strata, codes, prefix)
  sd <- .ralloc_seed(seed)
  .ralloc_make(set, sd)
}

#' Check a Randomisation List at Unblinding
#'
#' Checks that a list from [ralloc()] is the one committed to before
#' enrolment, and that the stated procedure and seed produce exactly it.
#'
#' @details
#' Three checks: the list's own commitment, recomputed from its rows,
#' settings and seed, equals `digest` (the value signed and timestamped
#' before enrolment; without it, the commitment stored in the list); the
#' list regenerates row for row from the seed and the settings; and every
#' participant id is there once. A list edited after the commitment fails
#' the first; a list that does not come from its seed (one chosen among
#' many, or written by hand) fails the second.
#'
#' Errors: `x` that does not come from [ralloc()].
#'
#' @param x A list from [ralloc()]
#'   (kept with [saveRDS()]).
#' @param digest The commitment published before enrolment, or `NULL` to
#'   check against the one in `x`.
#' @param seed The seed revealed at unblinding, or `NULL` for the one in
#'   `x`.
#' @return An object of class `rmbl_alloc_check`: a list with `ok` (all
#'   checks passed) and `checks` (a data frame of `check`, `ok` and
#'   `detail`). It prints as a box that opens with VERIFIED or NOT
#'   VERIFIED.
#' @seealso [ralloc()]
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' a <- ralloc(20, seed = "teaching example")
#' commitment <- attr(a, "alloc")$digest
#' rallocvrf(a, digest = commitment)
#'
#' # one allocation changed after the commitment
#' b <- a
#' b$arm[3] <- if (b$arm[3] == "A") "B" else "A"
#' rallocvrf(b, digest = commitment)
#'
#' # a different seed revealed at unblinding
#' rallocvrf(a, digest = commitment, seed = "another seed")
#' @export
rallocvrf <- function(x, digest = NULL, seed = NULL) {
  set <- attr(x, "alloc")
  if (!inherits(x, "rmbl_alloc") || !is.list(set)) {
    stop("rallocvrf: `x` must be a list from ralloc()", call. = FALSE)
  }
  sd <- if (is.null(seed)) .ralloc_seed(set$seed) else .ralloc_seed(seed)
  want <- if (is.null(digest)) set$digest else .rmbl_string1(digest, "digest")
  got <- .ralloc_digest(as.data.frame(x), set, sd$hex)
  again <- .ralloc_make(set, sd)
  cols <- intersect(c("id", "stratum", "block", "arm", "kit"),
                    union(names(again), names(x)))
  as_chr <- function(d) {
    lapply(as.data.frame(d)[intersect(cols, names(d))], as.character)
  }
  same <- identical(as_chr(again), as_chr(x)) &&
    identical(nrow(again), nrow(x))
  ids <- !anyDuplicated(x$id) && identical(nrow(x), as.integer(set$n))
  checks <- .ralloc_checks(identical(got, tolower(want)), same, ids, nrow(x))
  .rmbl_cls(
    list(ok = all(checks$ok), checks = checks, digest = got),
    "rmbl_alloc_check"
  )
}

#' @export
format.rmbl_alloc <- function(x, ...) {
  set <- attr(x, "alloc")
  if (!is.list(set) || !all(c("id", "arm") %in% names(x))) {
    return(.an_plain(x, ...))
  }
  d <- as.data.frame(x)
  tab <- .ralloc_counts(d, set)
  gap <- max(apply(tab[-1L], 1L, function(r) {
    max(r / set$ratio) - min(r / set$ratio)
  }))
  tot <- colSums(tab[-1L])
  .an_block(
    "Randomisation list",
    facts = list(
      Method = .ralloc_method(set),
      Participants = nrow(d),
      Arms = sprintf(
        "%s (%s)",
        toString(set$arms),
        paste(set$ratio, collapse = ":")
      ),
      Strata = if (length(set$strata)) length(set$strata) else "none",
      `Kit codes` = if (isTRUE(set$codes)) "yes" else "no",
      Seed = "concealed: attr(x, \"alloc\")$seed",
      Commitment = set$digest
    ),
    tables = list(tab),
    reading = c(
      .ralloc_reading(tot, gap, set),
      paste(
        "Sign and timestamp the commitment before the first participant;",
        "keep the list and the seed with the unblinded statistician."
      )
    ),
    notes = if (isTRUE(set$codes)) {
      "Give sites and the pharmacy only the id and kit columns."
    }
  )
}

#' @export
format.rmbl_alloc_check <- function(x, ...) {
  c(
    .rmbl_rule(sprintf(
      "Randomisation list: %s",
      if (isTRUE(x$ok)) "verified" else "NOT verified"
    )),
    sprintf(
      "  %s %-13s %s",
      ifelse(x$checks$ok, "ok  ", "FAIL"),
      x$checks$check,
      x$checks$detail
    ),
    sprintf("  %-4s %-13s %s", "", "commitment", x$digest),
    .rmbl_rule()
  )
}

#' @rdname ralloc
#' @param x A list from ralloc(), for `plot()`.
#' @param ... Passed to the base plot.
#' @export
plot.rmbl_alloc <- function(x, ...) {
  .rmbl_plot_check(x, "rmbl_alloc")
  set <- attr(x, "alloc")
  d <- as.data.frame(x)
  # how many each arm has, never in what order: a plot of the allocation as
  # participants enrol has one step per participant, and recovers who is in
  # which arm from a report or a shared page
  n <- table(factor(d$arm, levels = set$arms))
  target <- nrow(d) * set$ratio / sum(set$ratio)
  cols <- .bl_cols(length(set$arms), NULL, NULL)
  mid <- graphics::barplot(
    as.vector(n),
    names.arg = set$arms,
    col = cols,
    ylim = c(0, max(c(n, target)) * 1.15),
    xlab = "Arm",
    ylab = "Participants allocated",
    main = "Allocation by arm",
    ...
  )
  graphics::points(mid, target, pch = 4, lwd = 2)
  graphics::legend(
    "topright", legend = "ratio's share", pch = 4, bty = "n", cex = 0.8
  )
  invisible(data.frame(
    arm = set$arms,
    allocated = as.vector(n),
    target = target,
    stringsAsFactors = FALSE
  ))
}

#' The three checks of rallocvrf(), with what each found.
#' @param com,same,ids Whether each passed.
#' @param n The number of rows.
#' @return A data frame of `check`, `ok` and `detail`.
#' @noRd
.ralloc_checks <- function(com, same, ids, n) {
  data.frame(
    check = c("commitment", "seed", "participants"),
    ok = c(com, same, ids),
    detail = c(
      if (com) {
        "the list is the one committed to"
      } else {
        "the list, its settings or the seed differ from the commitment"
      },
      if (same) {
        "the seed and the settings give this list, row for row"
      } else {
        "the seed and the settings give a different list"
      },
      if (ids) {
        sprintf("%d participants, each once", n)
      } else {
        "participants are missing or repeated"
      }
    ),
    stringsAsFactors = FALSE
  )
}

#' The first sentence of the list's reading: totals, and how far off.
#' @param tot The total per arm.
#' @param gap The largest departure from the ratio, in ratio units.
#' @param set The allocation settings.
#' @return One string.
#' @noRd
.ralloc_reading <- function(tot, gap, set) {
  sprintf(
    "In all: %s.%s",
    paste(names(tot), tot, collapse = ", "),
    if (gap == 0) {
      " Every stratum is exactly in the ratio."
    } else if (is.null(set$block)) {
      " Simple randomisation lets the totals drift from the ratio."
    } else {
      paste(
        " The last block of a stratum is cut at its number of places,",
        "so a stratum can be a little off the ratio."
      )
    }
  )
}

#' The participants of each arm in each stratum.
#' @param d The list, as a data frame.
#' @param set The allocation settings.
#' @return A data frame: `stratum`, then one count column per arm.
#' @noRd
.ralloc_counts <- function(d, set) {
  by <- if (is.null(d$stratum)) rep("all", nrow(d)) else d$stratum
  tab <- as.data.frame.matrix(table(
    factor(by, unique(by)),
    factor(d$arm, set$arms)
  ))
  tab <- cbind(stratum = rownames(tab), tab, stringsAsFactors = FALSE)
  rownames(tab) <- NULL
  tab
}

#' The settings of ralloc(), checked.
#' @param n,arms,ratio,block,strata,codes,prefix As for ralloc().
#' @return A list.
#' @noRd
.ralloc_settings <- function(n, arms, ratio, block, strata, codes, prefix) {
  # a blank name (" ") or two that differ only in spaces ("A", "A ") print
  # alike on the allocation list (recheck of a8cdaf9)
  if (.rmbl_anyof(!is.character(arms), length(arms) < 2L,
                  .rmbl_badnames(arms))) {
    stop("ralloc: `arms` must be two or more different names",
         call. = FALSE)
  }
  if (.rmbl_anyof(!is.numeric(ratio), length(ratio) != length(arms),
                  anyNA(ratio), any(ratio < 1), any(ratio != round(ratio)))) {
    stop("ralloc: `ratio` must be one positive whole number per arm",
         call. = FALSE)
  }
  ratio <- as.integer(ratio)
  block <- .ralloc_block(block, ratio)
  st <- .ralloc_strata(strata)
  if (is.null(st)) {
    n <- .rmbl_scalar(n, "n", min = 1, max = 1e7, integer = TRUE)
  } else if (!is.null(n) && !identical(as.integer(n), sum(st))) {
    stop(
      sprintf("ralloc: `n` (%s) is not the strata's total (%d)", n, sum(st)),
      call. = FALSE
    )
  }
  list(
    version = 2L,
    arms = arms,
    ratio = ratio,
    block = block,
    strata = st,
    n = if (is.null(st)) as.integer(n) else sum(st),
    codes = .rmbl_flag1(codes, "codes"),
    prefix = .rmbl_string1(prefix, "prefix")
  )
}

#' ralloc()'s block sizes, checked: positive multiples of the ratio's sum.
#' @param block As for ralloc().
#' @param ratio The checked ratio.
#' @return The sizes, sorted and unique, or NULL.
#' @noRd
.ralloc_block <- function(block, ratio) {
  if (is.null(block)) {
    return(NULL)
  }
  # as.integer() turned 3e9 into NA and Inf into an error of R's own
  if (.rmbl_anyof(!is.numeric(block), !length(block), anyNA(block),
                  !all(is.finite(block)), any(block < 1), any(block > 1e6),
                  any(block %% sum(ratio) != 0))) {
    stop(
      sprintf(
        paste0("ralloc: every block size must be a positive multiple ",
               "of %d, at most 1000000"),
        sum(ratio)
      ),
      call. = FALSE
    )
  }
  sort(unique(as.integer(block)))
}

#' The strata as a named integer vector of places, or NULL.
#' @param strata As for ralloc().
#' @return A named integer vector, or NULL.
#' @noRd
.ralloc_strata <- function(strata) {
  if (is.null(strata)) {
    return(NULL)
  }
  if (is.data.frame(strata)) {
    if (is.null(strata$n) || ncol(strata) < 2L) {
      stop("ralloc: a `strata` data frame needs stratum columns and `n`",
           call. = FALSE)
    }
    lab <- do.call(paste, c(strata[setdiff(names(strata), "n")], sep = " / "))
    strata <- stats::setNames(strata$n, lab)
  }
  if (.rmbl_anyof(!is.numeric(strata), is.null(names(strata)),
                  anyNA(strata), any(strata < 1),
                  any(strata != round(strata)), sum(strata) > 1e7,
                  .rmbl_badnames(names(strata)))) {
    stop(
      "ralloc: `strata` must name each stratum and its number of places",
      call. = FALSE
    )
  }
  stats::setNames(as.integer(strata), names(strata))
}

#' The 48 bytes of entropy a seed stands for, and their hexadecimal.
#' @param seed As for ralloc().
#' @return A list: `raw` (48 bytes) and `hex`.
#' @noRd
.ralloc_seed <- function(seed) {
  if (is.null(seed)) {
    seed <- rndbytes(48L)
  }
  # a vector or list was read by its first element, and a function was an
  # error of R's own
  one <- length(seed) == 1L && !is.list(seed) && !is.na(seed) &&
    (is.character(seed) || (is.numeric(seed) && is.finite(seed)))
  if (!is.raw(seed) && !one) {
    stop(
      "ralloc: `seed` must be NULL, 48 raw bytes, their 96 ",
      "hexadecimal digits, or one word or number",
      call. = FALSE
    )
  }
  if (is.character(seed) && length(seed) == 1L &&
        grepl("^[0-9a-fA-F]{96}$", seed)) {
    seed <- as.raw(strtoi(substring(seed, seq(1, 95, 2), seq(2, 96, 2)), 16L))
  }
  if (is.raw(seed)) {
    if (length(seed) != 48L) {
      stop("ralloc: a raw `seed` must be 48 bytes", call. = FALSE)
    }
  } else {
    s <- .rmbl_string1(as.character(seed), "seed")
    seed <- c(
      .rmbl_sha256_raw(charToRaw(paste0("ralloc seed 1:", s))),
      .rmbl_sha256_raw(charToRaw(paste0("ralloc seed 2:", s)))
    )[1:48]
  }
  list(raw = seed, hex = paste(format(as.hexmode(as.integer(seed)),
                                      width = 2L), collapse = ""))
}

#' Builds the list from checked settings and a seed.
#' @param set The allocation settings.
#' @param sd The seed, from .ralloc_seed().
#' @return An rmbl_alloc.
#' @noRd
.ralloc_make <- function(set, sd) {
  g <- new.env(parent = emptyenv())
  g$d <- drbgnew(sd$raw, person = charToRaw("rmoriebricklayer ralloc 1"))
  g$buf <- raw()
  places <- if (is.null(set$strata)) c(all = set$n) else set$strata
  parts <- lapply(names(places), function(s) {
    a <- .ralloc_stratum(g, set, places[[s]])
    a$stratum <- s
    a
  })
  d <- do.call(rbind, parts)
  w <- max(4L, nchar(nrow(d)))
  out <- data.frame(
    id = sprintf("%s-%0*d", set$prefix, w, seq_len(nrow(d))),
    stringsAsFactors = FALSE
  )
  if (!is.null(set$strata)) out$stratum <- d$stratum
  out$block <- d$block
  out$arm <- d$arm
  if (isTRUE(set$codes)) out$kit <- .ralloc_kits(g, nrow(out))
  set$seed <- sd$hex
  set$digest <- .ralloc_digest(out, set, sd$hex)
  attr(out, "alloc") <- set
  class(out) <- c("rmbl_alloc", "data.frame")
  out
}

#' One stratum's allocation, `m` places long.
#' @param g The generator.
#' @param set The allocation settings.
#' @param m The number of places.
#' @return A data frame of `block` and `arm`.
#' @noRd
.ralloc_stratum <- function(g, set, m) {
  if (is.null(set$block)) {
    cut <- cumsum(set$ratio)
    arm <- vapply(seq_len(m), function(i) {
      set$arms[which(cut > .ralloc_unif(g, sum(set$ratio)))[1L]]
    }, "")
    return(data.frame(block = NA_integer_, arm = arm,
                      stringsAsFactors = FALSE))
  }
  arm <- character()
  blk <- integer()
  b <- 0L
  while (length(arm) < m) {
    b <- b + 1L
    size <- set$block[.ralloc_unif(g, length(set$block)) + 1L]
    cell <- rep(set$arms, set$ratio * size / sum(set$ratio))
    arm <- c(arm, .ralloc_shuffle(g, cell))
    blk <- c(blk, rep(b, size))
  }
  data.frame(block = blk[seq_len(m)], arm = arm[seq_len(m)],
             stringsAsFactors = FALSE)
}

#' One whole number in 0..k-1, without modulo bias.
#' @param g The generator.
#' @param k How many values.
#' @return One number.
#' @noRd
.ralloc_unif <- function(g, k) {
  lim <- floor(4294967296 / k) * k
  repeat {
    if (length(g$buf) < 4L) g$buf <- c(g$buf, drbggen(g$d, 1024L))
    b <- as.integer(g$buf[1:4])
    g$buf <- g$buf[-(1:4)]
    u <- ((b[1L] * 256 + b[2L]) * 256 + b[3L]) * 256 + b[4L]
    if (u < lim) {
      return(u %% k)
    }
  }
}

#' A Fisher-Yates shuffle.
#' @param g The generator.
#' @param v The values to shuffle.
#' @return `v`, shuffled.
#' @noRd
.ralloc_shuffle <- function(g, v) {
  for (i in rev(seq_along(v))[-length(v)]) {
    j <- .ralloc_unif(g, i) + 1L
    v[c(i, j)] <- v[c(j, i)]
  }
  v
}

#' Kit codes: six characters each, unique, no look-alikes.
#' @param g The generator.
#' @param m How many.
#' @return A character vector.
#' @noRd
.ralloc_kits <- function(g, m) {
  abc <- strsplit("23456789ABCDEFGHJKMNPQRSTUVWXYZ", "", fixed = TRUE)[[1L]]
  # a hashed set: `k %in% out` made 10^5 codes take minutes
  seen <- new.env(hash = TRUE, parent = emptyenv(), size = max(29L, m))
  out <- character(m)
  i <- 0L
  while (i < m) {
    k <- paste(abc[vapply(1:6, function(i) {
      .ralloc_unif(g, length(abc)) + 1
    }, 0)], collapse = "")
    if (is.null(seen[[k]])) {
      assign(k, TRUE, envir = seen)
      i <- i + 1L
      out[i] <- k
    }
  }
  out
}

#' The commitment: SHA-256 of the settings, the rows and the seed's SHA-256.
#' @param d The list, as a data frame.
#' @param set The allocation settings.
#' @param hex The seed, hexadecimal.
#' @return 64 hexadecimal characters.
#' @noRd
.ralloc_digest <- function(d, set, hex) {
  cols <- intersect(c("id", "stratum", "block", "arm", "kit"), names(d))
  if (!identical(set$version, 1L)) {
    # every field length-prefixed: with "," between them, strata "x,y"
    # and "x" + "y" (or arms holding a comma) shared one commitment
    f <- .rmbl_fields
    rows <- if (nrow(d)) {
      vapply(seq_len(nrow(d)), function(i) {
        f(vapply(d[i, cols, drop = FALSE], as.character, ""))
      }, "")
    }
    return(csha256(f(c(
      "rmoriebricklayer ralloc 2",
      f(set$arms), f(set$ratio), f(set$block),
      f(names(set$strata)), f(set$strata), f(cols), rows,
      paste0("seed-sha256=", csha256(hex))
    ))))
  }
  rows <- do.call(paste, c(lapply(d[cols], as.character), sep = ","))
  txt <- c(
    "rmoriebricklayer ralloc 1",
    paste0("arms=", paste(set$arms, collapse = ",")),
    paste0("ratio=", paste(set$ratio, collapse = ",")),
    paste0("block=", paste(set$block, collapse = ",")),
    paste0(
      "strata=",
      paste(names(set$strata), set$strata, sep = ":", collapse = ",")
    ),
    paste(cols, collapse = ","),
    rows,
    paste0("seed-sha256=", csha256(hex))
  )
  csha256(paste(txt, collapse = "\n"))
}

#' The method, in words.
#' @param set The allocation settings.
#' @return One string.
#' @noRd
.ralloc_method <- function(set) {
  kind <- if (is.null(set$block)) {
    "simple randomisation"
  } else {
    sprintf("permuted blocks of %s", paste(set$block, collapse = " or "))
  }
  if (length(set$strata)) paste(kind, "within strata") else kind
}
