# Mapping point locations to the regions that contain them, and checking
# the result rather than trusting it.
#
# A region map from facilities to statistical regions is built once, by
# geometry, and then read many times. Everything downstream inherits it,
# so the failure that matters is not a wrong arithmetic step later: it is
# a silently wrong assignment here, which no recomputation of the tables
# built on top can detect, because both sides move together.
#
# Three separate things are therefore checked, and they fail for
# different reasons:
#
#   region_map_integrity()    the map is internally sound -- one region
#                             per unit, no gaps, every region id known to
#                             the population table.
#   region_map_compare()      a recomputed map agrees with the published
#                             one, cell by cell.
#   region_map_second_route() an assignment derived a DIFFERENT way
#                             agrees, except on the cases already known to
#                             defeat that route. This is the only one of
#                             the three that can catch an error in the
#                             original method, because it does not use
#                             that method.
#
# And one thing is deliberately not offered: a per-capita rate by region.
# See region_coverage().

.rmbl_rm_chr <- function(x, arg) {
  x <- trimws(as.character(x))
  if (!length(x)) stop(sprintf("`%s` must not be empty", arg), call. = FALSE)
  if (anyNA(x) || !all(nzchar(x))) {
    stop(sprintf("`%s` must not contain missing or empty values", arg),
         call. = FALSE)
  }
  x
}

.rmbl_rm_col <- function(d, nm, arg) {
  if (!is.data.frame(d)) stop(sprintf("`%s` must be a data frame", arg),
                              call. = FALSE)
  if (length(nm) != 1L || !nm %in% names(d)) {
    stop(sprintf("`%s` has no column `%s`", arg, nm), call. = FALSE)
  }
  d[[nm]]
}

#' Population of the regions that contain a unit, and of those that do not
#'
#' Summarises where a set of point-located units sits relative to the
#' regions of a statistical geography: how many regions hold at least one
#' unit, and what share of the population lives in them.
#'
#' @param region Region identifiers, one per region, not repeated.
#' @param population Population of each region, same length and order.
#' @param units Number of units located in each region. Zero is the
#'   expected value for most regions in most geographies.
#'
#' @return A data frame of class `rmbl_region_coverage`, one row per
#'   region, with the columns
#'   `region`,
#'   `population`,
#'   `units`,
#'   `has_unit`
#'   and `pop_share`,
#'   ordered by units then population. The totals are carried on the
#'   `coverage` attribute and printed by the print method.
#'
#' @details
#' The share this returns is CONTEXT, not a denominator, and the
#' distinction is the reason the function exists rather than a bare
#' `tapply()`.
#'
#' A region holding no unit is not an unserved population. Units serve
#' catchments, and a catchment is an administrative fact about where
#' people are sent from; a point location does not state it and cannot
#' imply it. Some geographies were never meant to have one unit each.
#'
#' So a rate built by summing the populations of unit-holding regions
#' pairs a denominator covering part of the territory with a numerator
#' drawn from all of it. Every such rate is inflated, and inflated
#' unevenly: a dense region holding one unit and a sparse region holding
#' seven distort it in opposite directions. Where numerator and
#' denominator must cover the same population, the defensible figure is
#' the whole-territory one.
#'
#' The print method says this each time, because the covered share is
#' precisely the number a reader is tempted to divide by.
#'
#' @seealso [region_map_integrity()],
#'   [region_map_compare()],
#'   [region_map_second_route()]
#'
#' @examples
#' # Four regions, two of which hold a facility.
#' cov <- region_coverage(region = c("A", "B", "C", "D"),
#'                        population = c(1200000, 800000, 450000, 90000),
#'                        units = c(3, 0, 1, 0))
#' cov
#'
#' # The covered share is reported, and is not a rate denominator.
#' attr(cov, "coverage")$covered_share
#' @export
region_coverage <- function(region, population, units) {
  region <- .rmbl_rm_chr(region, "region")
  population <- as.numeric(population)
  units <- as.numeric(units)
  if (length(population) != length(region) || length(units) != length(region)) {
    stop("`region`, `population` and `units` must be the same length",
         call. = FALSE)
  }
  if (anyDuplicated(region)) {
    stop("`region` must not repeat: one row per region", call. = FALSE)
  }
  if (anyNA(population) || any(population < 0)) {
    stop("`population` must be complete and non-negative", call. = FALSE)
  }
  if (anyNA(units) || any(units < 0) || any(units != round(units))) {
    stop("`units` must be complete, non-negative whole numbers", call. = FALSE)
  }
  tot <- sum(population)
  out <- data.frame(region = region, population = population, units = units,
                    has_unit = units > 0,
                    pop_share = if (tot > 0) 100 * population / tot else NA_real_,
                    stringsAsFactors = FALSE)
  out <- out[order(-out$units, -out$population), ]
  row.names(out) <- NULL
  cov <- sum(population[units > 0])
  structure(out, class = c("rmbl_region_coverage", "data.frame"),
            coverage = list(regions = length(region),
                            with_unit = sum(units > 0),
                            without_unit = sum(units == 0),
                            units = sum(units),
                            total_population = tot,
                            covered_population = cov,
                            uncovered_population = tot - cov,
                            covered_share =
                              if (tot > 0) 100 * cov / tot else NA_real_))
}

#' @export
print.rmbl_region_coverage <- function(x, n = 10L, ...) {
  a <- attr(x, "coverage")
  fm <- function(v) format(round(v), big.mark = ",", trim = TRUE)
  cat(sprintf("%s units in %s of %s regions\n",
              fm(a$units), fm(a$with_unit), fm(a$regions)))
  cat(sprintf("  those regions hold %s of %s residents (%.1f%%)\n",
              fm(a$covered_population), fm(a$total_population),
              a$covered_share))
  cat(sprintf("  %s regions hold none; %s residents (%.1f%%) live there\n",
              fm(a$without_unit), fm(a$uncovered_population),
              100 - a$covered_share))
  n <- min(as.integer(n)[1L], nrow(x))
  if (n > 0L) {
    cat("\n")
    print.data.frame(x[seq_len(n), , drop = FALSE], row.names = FALSE, ...)
    if (nrow(x) > n) cat(sprintf("  ... %d more regions\n", nrow(x) - n))
  }
  cat("\nThe covered share is context, not a denominator: units serve",
      "\ncatchments, so a rate over these regions alone would take its",
      "\nnumerator from the whole territory and is inflated.\n")
  invisible(x)
}

#' Internal soundness of a region map
#'
#' Checks that a region map assigns exactly one region to every unit and
#' that every region it names is one the reference geography knows about.
#'
#' @param map Data frame, one row per unit.
#' @param unit Name of the column holding the unit identifier.
#' @param region Name of the column holding the region identifier.
#' @param regions Optional character vector of every valid region
#'   identifier, typically the identifier column of the population table.
#'   When supplied, region codes outside it are counted as failures.
#'
#' @return A data frame with one row per check: `check`, `observed`,
#'   `expected` and `pass`. Every check is stated so that zero is the
#'   passing value, which is what makes the frame safe to feed straight
#'   into a manifest.
#'
#' @details
#' These are the failures that a comparison against published output
#' cannot see, because they would be present on both sides: a unit
#' matched into two regions, a unit matched into none, a region code that
#' is a typo or belongs to a neighbouring province. None of them require
#' the geometry, so they run with nothing installed.
#'
#' @seealso [region_map_compare()],
#'   [region_map_second_route()],
#'   [region_coverage()]
#'
#' @examples
#' cw <- data.frame(inst = c("North Jail", "South Jail", "East Jail"),
#'                  cd = c("3557", "3520", "3506"),
#'                  stringsAsFactors = FALSE)
#' region_map_integrity(cw, "inst", "cd", regions = c("3557", "3520", "3506"))
#'
#' # a region code the geography does not know fails the third check
#' cw$cd[3] <- "2406"
#' region_map_integrity(cw, "inst", "cd", regions = c("3557", "3520", "3506"))
#' @export
region_map_integrity <- function(map, unit, region, regions = NULL) {
  u <- as.character(.rmbl_rm_col(map, unit, "map"))
  r <- as.character(.rmbl_rm_col(map, region, "map"))
  blank <- function(v) is.na(v) | !nzchar(trimws(ifelse(is.na(v), "", v)))
  dup <- sum(duplicated(u[!blank(u)]))
  gap <- sum(blank(r))
  unknown <- if (is.null(regions)) 0L else {
    known <- as.character(regions)
    sum(!blank(r) & !(trimws(r) %in% trimws(known)))
  }
  rows <- list(
    c("units assigned more than one region", dup),
    c("units assigned no region", gap),
    c("region codes not in the reference geography", unknown))
  out <- data.frame(
    check = vapply(rows, `[`, character(1), 1L),
    observed = as.numeric(vapply(rows, `[`, character(1), 2L)),
    expected = 0, stringsAsFactors = FALSE)
  if (is.null(regions)) out <- out[out$check != rows[[3]][1], , drop = FALSE]
  out$pass <- out$observed == out$expected
  row.names(out) <- NULL
  out
}

#' Compare a recomputed region map against a published one
#'
#' Matches two region maps on the unit identifier and compares the named
#' columns cell by cell.
#'
#' @param published The region map as published.
#' @param observed The region map as recomputed.
#' @param unit Name of the unit identifier column, present in both.
#' @param cols Columns to compare. Defaults to every column the two share
#'   apart from `unit`.
#'
#' @return A data frame, one row per compared column plus a `rows` row for
#'   units present on one side only: `column`, `cells`, `mismatched` and
#'   `first`, the first disagreement written out as text. Zero
#'   `mismatched` throughout is the passing result.
#'
#' @details
#' Numeric columns are compared with [all.equal()] at its default
#' tolerance, so a coordinate that survived a round trip through text is
#' not reported as a change; everything else is compared exactly after
#' trimming whitespace.
#'
#' What this establishes is that the recomputation reproduced the
#' published assignment. It does NOT establish that the assignment is
#' right: run the same method against the same boundary file and a
#' definitional error reproduces perfectly. That is what
#' [region_map_second_route()] is for.
#'
#' @seealso [region_map_second_route()],
#'   [region_map_integrity()]
#'
#' @examples
#' pub <- data.frame(inst = c("North Jail", "South Jail"),
#'                   cd = c("3557", "3520"), stringsAsFactors = FALSE)
#' obs <- pub
#' region_map_compare(pub, obs, "inst")
#'
#' # a changed assignment is reported with the unit that moved
#' obs$cd[2] <- "3521"
#' region_map_compare(pub, obs, "inst")
#' @export
region_map_compare <- function(published, observed, unit, cols = NULL) {
  pu <- trimws(as.character(.rmbl_rm_col(published, unit, "published")))
  ou <- trimws(as.character(.rmbl_rm_col(observed, unit, "observed")))
  if (is.null(cols)) {
    cols <- setdiff(intersect(names(published), names(observed)), unit)
  }
  cols <- as.character(cols)
  missing_cols <- setdiff(cols, intersect(names(published), names(observed)))
  if (length(missing_cols)) {
    stop("both frames need the compared columns; missing: ",
         paste(missing_cols, collapse = ", "), call. = FALSE)
  }
  only_pub <- setdiff(pu, ou)
  only_obs <- setdiff(ou, pu)
  shared <- intersect(pu, ou)
  ip <- match(shared, pu)
  io <- match(shared, ou)
  res <- list(data.frame(
    column = "rows", cells = length(unique(c(pu, ou))),
    mismatched = length(only_pub) + length(only_obs),
    first = if (length(only_pub)) paste0("published only: ", only_pub[1])
            else if (length(only_obs)) paste0("recomputed only: ", only_obs[1])
            else "", stringsAsFactors = FALSE))
  for (cl in cols) {
    a <- published[[cl]][ip]
    b <- observed[[cl]][io]
    same <- if (is.numeric(a) && is.numeric(b)) {
      vapply(seq_along(a), function(i)
        isTRUE(all.equal(a[i], b[i])), logical(1))
    } else {
      trimws(as.character(a)) == trimws(as.character(b))
    }
    same[is.na(same)] <- is.na(a[is.na(same)]) & is.na(b[is.na(same)])
    bad <- which(!same)
    res[[length(res) + 1L]] <- data.frame(
      column = cl, cells = length(shared), mismatched = length(bad),
      first = if (length(bad)) sprintf("%s: published %s, recomputed %s",
                                       shared[bad[1]], a[bad[1]], b[bad[1]])
              else "", stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, res)
  row.names(out) <- NULL
  out
}

#' Check a region map against an independently derived assignment
#'
#' Compares the region each unit was assigned with the region a DIFFERENT
#' method assigns it, and marks the disagreements that are already known
#' and explained.
#'
#' @param map Data frame, one row per unit.
#' @param unit Name of the unit identifier column.
#' @param region Name of the assigned region column.
#' @param route Named character vector, or a data frame with the same two
#'   column names, giving the second method's assignment. Units it does
#'   not cover are skipped rather than counted as disagreements.
#' @param known Units whose disagreement is expected and documented --
#'   the cases the second route is known to get wrong.
#'
#' @return A data frame of disagreements: `unit`, `primary`, `second` and
#'   `known`. `sum(!x$known)` is the number of unexplained disagreements
#'   and zero is the passing value; `nrow(x)` should equal the number of
#'   documented cases, because a documented case that stops disagreeing
#'   means the second route changed underneath the documentation.
#'
#' @details
#' This is the only check here that can catch an error in the original
#' method, because it does not use that method. Recomputing point in
#' polygon against the same boundary file proves the pipeline is
#' deterministic; deriving the region a second way -- from a name, a
#' postal geography, an administrative lookup -- can disagree, and a
#' disagreement is information either way round.
#'
#' The `known` argument exists because a second route usually has
#' understood weaknesses: a place name that is a community rather than a
#' municipality, an amalgamated city, a township absorbed into a
#' neighbour. Listing them keeps the check sharp instead of loosening the
#' tolerance until everything passes, and listing them by NAME means an
#' unexpected disagreement cannot hide inside an allowance.
#'
#' @seealso [region_map_compare()],
#'   [region_map_integrity()]
#'
#' @examples
#' cw <- data.frame(inst = c("North Jail", "South Jail", "Hill Jail"),
#'                  cd = c("3557", "3520", "3506"),
#'                  stringsAsFactors = FALSE)
#'
#' # a name-based route that is known to mis-place one unit
#' route <- c("North Jail" = "3557", "South Jail" = "3520",
#'            "Hill Jail" = "3519")
#' region_map_second_route(cw, "inst", "cd", route, known = "Hill Jail")
#'
#' # an undocumented disagreement is what the check is for
#' route["South Jail"] <- "3521"
#' d <- region_map_second_route(cw, "inst", "cd", route, known = "Hill Jail")
#' sum(!d$known)
#' @export
region_map_second_route <- function(map, unit, region, route,
                                   known = character()) {
  u <- trimws(as.character(.rmbl_rm_col(map, unit, "map")))
  r <- trimws(as.character(.rmbl_rm_col(map, region, "map")))
  if (is.data.frame(route)) {
    route <- stats::setNames(
      trimws(as.character(.rmbl_rm_col(route, region, "route"))),
      trimws(as.character(.rmbl_rm_col(route, unit, "route"))))
  }
  route <- route[!is.na(route) & nzchar(trimws(as.character(route)))]
  if (is.null(names(route))) {
    stop("`route` must be named by unit, or be a data frame", call. = FALSE)
  }
  names(route) <- trimws(names(route))
  known <- trimws(as.character(known))
  i <- which(u %in% names(route))
  second <- trimws(as.character(route[u[i]]))
  bad <- i[second != r[i]]
  out <- data.frame(
    unit = u[bad], primary = r[bad],
    second = trimws(as.character(route[u[bad]])),
    known = u[bad] %in% known, stringsAsFactors = FALSE)
  out <- out[order(out$known, out$unit), ]
  row.names(out) <- NULL
  out
}

#' Recompute a region map by point in polygon
#'
#' Assigns each point to the polygon that contains it. Requires the `sf`
#' package and a boundary file; returns `NULL` when either is absent, so
#' a verification script can record the check as unavailable instead of
#' failing for a missing optional dependency.
#'
#' @param x,y Longitude and latitude of each point.
#' @param unit Identifier for each point, same length.
#' @param boundaries Path to a boundary file `sf` can read.
#' @param fields Columns of the boundary file to carry onto the result.
#' @param crs Coordinate reference system the points are in. Default
#'   `4326`, that is WGS84, which is what published latitude and
#'   longitude columns almost always are.
#'
#' @return A data frame: `unit`, the requested `fields`, and `n_regions`,
#'   the number of polygons that contained the point. Any value of
#'   `n_regions` other than 1 is a failure -- zero means the point fell
#'   outside the geography, more than one means the boundaries overlap --
#'   so it is returned rather than silently resolved. `NULL` if `sf` is
#'   not installed or `boundaries` does not exist.
#'
#' @details
#' The points are projected onto the boundary file's own coordinate
#' reference system before matching, never the other way round: a
#' cartographic boundary file is published in a projection chosen for the
#' country it covers, and reprojecting the polygons to compare them
#' against unprojected points moves the edges.
#'
#' Point in polygon is preferred to matching place names against
#' subdivision names whenever both are available. Names fail on exactly
#' the cases that matter and fail quietly: a facility in a community
#' rather than an incorporated municipality, a city amalgamated into a
#' larger one, a township absorbed by a neighbour. The geometry has no
#' opinion about any of that.
#'
#' Use [region_map_second_route()]
#' to check this result against the name route, with those cases named.
#'
#' @seealso [region_map_compare()],
#'   [region_map_second_route()]
#'
#' @examples
#' # Needs sf and a boundary file, so this is the shape of the call
#' # rather than a run of it.
#' \dontrun{
#' obs <- region_map_from_points(
#'   x = inst$Longitude, y = inst$Latitude, unit = inst$Institution,
#'   boundaries = "lcd_000b21a_e.shp", fields = c("CDUID", "CDNAME"))
#' stopifnot(all(obs$n_regions == 1))
#' }
#' @export
region_map_from_points <- function(x, y, unit, boundaries, fields,
                                  crs = 4326) {
  if (!requireNamespace("sf", quietly = TRUE)) return(NULL)
  if (length(boundaries) != 1L || !file.exists(boundaries)) return(NULL)
  unit <- .rmbl_rm_chr(unit, "unit")
  x <- as.numeric(x); y <- as.numeric(y)
  if (length(x) != length(unit) || length(y) != length(unit)) {
    stop("`x`, `y` and `unit` must be the same length", call. = FALSE)
  }
  if (anyNA(x) || anyNA(y)) {
    stop("`x` and `y` must be complete: a point with no coordinate ",
         "cannot be matched", call. = FALSE)
  }
  poly <- sf::st_read(boundaries, quiet = TRUE)
  fields <- as.character(fields)
  miss <- setdiff(fields, names(poly))
  if (length(miss)) {
    stop("boundary file has no column(s): ", paste(miss, collapse = ", "),
         call. = FALSE)
  }
  pts <- sf::st_as_sf(data.frame(.x = x, .y = y), coords = c(".x", ".y"),
                      crs = crs)
  ## onto the boundary file's CRS, not the reverse: reprojecting the
  ## polygons would move their edges
  pts <- sf::st_transform(pts, sf::st_crs(poly))
  hit <- sf::st_within(pts, poly)
  n <- lengths(hit)
  first <- vapply(hit, function(h) if (length(h)) h[1] else NA_integer_,
                  integer(1))
  out <- data.frame(unit = unit, stringsAsFactors = FALSE)
  for (f in fields) {
    v <- poly[[f]][first]
    out[[f]] <- if (is.factor(v)) as.character(v) else v
  }
  out$n_regions <- as.integer(n)
  out
}
