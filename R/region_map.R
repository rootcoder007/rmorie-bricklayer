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
      call. = FALSE
    )
  }
  x
}

.rmbl_rm_col <- function(d, nm, arg) {
  if (!is.data.frame(d)) {
    stop(sprintf("`%s` must be a data frame", arg),
      call. = FALSE
    )
  }
  if (length(nm) != 1L || !nm %in% names(d)) {
    stop(sprintf("`%s` has no column `%s`", arg, nm), call. = FALSE)
  }
  d[[nm]]
}

#' Population of the regions that contain a unit, and of those that do not
#'
#' Summarises where a set of point-located units (jails, courthouses,
#' hospitals, police stations) sits relative to the regions of a statistical
#' geography: how many regions hold at least one unit, and what share of the
#' population lives in them. Use it to describe the footprint of a set of
#' facilities, not to build a per-capita rate (see Details).
#'
#' @param region Region identifiers, one per region, not repeated
#'   (character, or anything that converts to it; surrounding spaces are
#'   trimmed).
#' @param population Population of each region, same length and order,
#'   non-negative numbers.
#' @param units Number of units located in each region, same length and
#'   order, non-negative whole numbers. Zero is the expected value for most
#'   regions in most geographies.
#'
#' @return A data frame of class \code{c("rmbl_region_coverage",
#'   "data.frame")}, one row per region, with the columns
#'   \code{region} (character),
#'   \code{population} (numeric),
#'   \code{units} (numeric),
#'   \code{has_unit} (logical)
#'   and \code{pop_share} (numeric, percent of the total population),
#'   ordered by units then population, both descending. The totals are
#'   carried on the \code{coverage} attribute, a list of \code{regions},
#'   \code{with_unit}, \code{without_unit}, \code{units},
#'   \code{total_population}, \code{covered_population},
#'   \code{uncovered_population} and \code{covered_share} (percent), and
#'   printed by the print method (which shows the first \code{n = 10} regions).
#'
#' @details
#' The share this returns is CONTEXT, not a denominator, and the
#' distinction is the reason the function exists rather than a bare
#' \code{tapply()}.
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
#' precisely the number a reader is tempted to divide by. With a total
#' population of zero the shares are \code{NA}.
#'
#' Errors: empty, missing or repeated \code{region} values; arguments of
#' different lengths; missing or negative \code{population}; missing,
#' negative or fractional \code{units}.
#'
#' @seealso [region_map_integrity()],
#'   [region_map_compare()],
#'   [region_map_second_route()]
#'
#' @examples
#' # Four regions, two of which hold a facility.
#' cov <- region_coverage(
#'   region = c("A", "B", "C", "D"),
#'   population = c(1200000, 800000, 450000, 90000),
#'   units = c(3, 0, 1, 0)
#' )
#' cov
#'
#' # The covered share is reported, and is not a rate denominator.
#' attr(cov, "coverage")$covered_share
#' attr(cov, "coverage")[c("with_unit", "uncovered_population")]
#'
#' # counting units per region from a facility list first
#' fac <- c("C", "A", "A", "A")
#' regions <- c("A", "B", "C", "D")
#' units <- as.vector(table(factor(fac, levels = regions)))
#' region_coverage(regions, c(1200000, 800000, 450000, 90000), units)$has_unit
#'
#' # a region listed twice is refused
#' try(region_coverage(c("A", "A"), c(10, 20), c(1, 0)))
#' @export
region_coverage <- function(region, population, units) {
  .rmbl_no_fn(region = region)
  region <- .rmbl_rm_chr(region, "region")
  population <- .rmbl_num(population, "population")
  units <- .rmbl_num(units, "units")
  if (length(population) != length(region) || length(units) != length(region)) {
    stop("`region`, `population` and `units` must be the same length",
      call. = FALSE
    )
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
  out <- data.frame(
    region = region, population = population, units = units,
    has_unit = units > 0,
    pop_share = if (tot > 0) 100 * population / tot else NA_real_,
    stringsAsFactors = FALSE
  )
  out <- out[order(-out$units, -out$population), ]
  row.names(out) <- NULL
  cov <- sum(population[units > 0])
  structure(out,
    class = c("rmbl_region_coverage", "data.frame"),
    coverage = list(
      regions = length(region),
      with_unit = sum(units > 0),
      without_unit = sum(units == 0),
      units = sum(units),
      total_population = tot,
      covered_population = cov,
      uncovered_population = tot - cov,
      covered_share =
        if (tot > 0) 100 * cov / tot else NA_real_
    )
  )
}

#' @export
print.rmbl_region_coverage <- function(x, n = 10L, ...) {
  a <- attr(x, "coverage")
  fm <- function(v) format(round(v), big.mark = ",", trim = TRUE)
  n <- min(as.integer(n)[1L], nrow(x))
  footer <- c(
    if (nrow(x) > n) sprintf("... %d more regions", nrow(x) - n),
    "The covered share is context, not a denominator: units serve",
    "catchments, so a rate over these regions alone would take its",
    "numerator from the whole territory and is inflated."
  )
  .rmbl_print_table(
    sprintf(
      "%s units in %s of %s regions", fm(a$units), fm(a$with_unit),
      fm(a$regions)
    ),
    x[seq_len(n), , drop = FALSE],
    notes = c(
      sprintf(
        "those regions hold %s of %s residents (%.1f%%)",
        fm(a$covered_population), fm(a$total_population),
        a$covered_share
      ),
      sprintf(
        "%s regions hold none; %s residents (%.1f%%) live there",
        fm(a$without_unit), fm(a$uncovered_population),
        100 - a$covered_share
      )
    ),
    footer = footer, ...
  )
  invisible(x)
}

#' Internal soundness of a region map
#'
#' Checks that a region map (a crosswalk from units, such as facilities, to
#' the statistical regions that contain them) lists each unit once, gives
#' every unit a region, and names only regions the reference geography knows
#' about. Run it on any crosswalk before tables are built on top of it.
#'
#' @param map Data frame, one row per unit.
#' @param unit Name of the column holding the unit identifier (a string).
#' @param region Name of the column holding the region identifier (a string).
#' @param regions Optional character vector of every valid region
#'   identifier, typically the identifier column of the population table.
#'   When supplied, region codes outside it are counted as failures; when
#'   \code{NULL} (the default) that check is not run and its row is absent.
#'
#' @return A data frame with one row per check: \code{check} (character),
#'   \code{observed} (numeric count), \code{expected} (numeric, always 0) and
#'   \code{pass} (logical). Every check is stated so that zero is the
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
#' The checks as computed: "units assigned more than one region" counts
#' rows whose (non-blank) unit identifier repeats an earlier row's, whether
#' or not the region differs, so an exact duplicate row also fails;
#' "units assigned no region" counts rows whose region is \code{NA} or blank;
#' "region codes not in the reference geography" counts non-blank region
#' codes not in \code{regions}, comparing the codes as text after trimming
#' spaces (so \code{"3506"} and \code{3506} match, but \code{"03506"} does
#' not). Errors: \code{map} not a data frame, or without the named columns.
#'
#' @seealso [region_map_compare()],
#'   [region_map_second_route()],
#'   [region_coverage()]
#'
#' @examples
#' cw <- data.frame(
#'   inst = c("North Jail", "South Jail", "East Jail"),
#'   cd = c("3557", "3520", "3506"),
#'   stringsAsFactors = FALSE
#' )
#' region_map_integrity(cw, "inst", "cd", regions = c("3557", "3520", "3506"))
#'
#' # a region code the geography does not know fails the third check
#' cw$cd[3] <- "2406"
#' region_map_integrity(cw, "inst", "cd", regions = c("3557", "3520", "3506"))
#'
#' # a unit listed twice and a unit with no region, without a reference list
#' cw2 <- rbind(cw, data.frame(inst = c("North Jail", "West Jail"), cd = c("3560", "")))
#' region_map_integrity(cw2, "inst", "cd")
#'
#' # the columns must exist
#' try(region_map_integrity(cw, "institution", "cd"))
#' @export
region_map_integrity <- function(map, unit, region, regions = NULL) {
  .rmbl_no_fn(unit = unit, region = region, regions = regions)
  u <- as.character(.rmbl_rm_col(map, unit, "map"))
  r <- as.character(.rmbl_rm_col(map, region, "map"))
  blank <- function(v) is.na(v) | !nzchar(trimws(ifelse(is.na(v), "", v)))
  dup <- sum(duplicated(u[!blank(u)]))
  gap <- sum(blank(r))
  unknown <- if (is.null(regions)) {
    0L
  } else {
    known <- as.character(regions)
    sum(!blank(r) & !(trimws(r) %in% trimws(known)))
  }
  rows <- list(
    c("units assigned more than one region", dup),
    c("units assigned no region", gap),
    c("region codes not in the reference geography", unknown)
  )
  out <- data.frame(
    check = vapply(rows, `[`, character(1), 1L),
    observed = as.numeric(vapply(rows, `[`, character(1), 2L)),
    expected = 0, stringsAsFactors = FALSE
  )
  if (is.null(regions)) out <- out[out$check != rows[[3]][1], , drop = FALSE]
  out$pass <- out$observed == out$expected
  row.names(out) <- NULL
  out
}

#' Compare a recomputed region map against a published one
#'
#' Matches two region maps on the unit identifier and compares the named
#' columns cell by cell, reporting for each column how many cells disagree
#' and the first disagreement. Use it to confirm that a region map rebuilt
#' from the boundary file (for example with
#' [region_map_from_points()])
#' reproduces the one that was published or pinned.
#'
#' @param published The region map as published (a data frame).
#' @param observed The region map as recomputed (a data frame).
#' @param unit Name of the unit identifier column, present in both.
#' @param cols Character vector of columns to compare. \code{NULL} (the
#'   default) compares every column the two share apart from \code{unit}.
#'
#' @return A data frame, one row per compared column plus a first
#'   \code{"rows"} row for units present on one side only, with columns
#'   \code{column} (character), \code{cells} (integer: for \code{"rows"} the
#'   number of distinct units on either side, otherwise the number of shared
#'   units compared), \code{mismatched} (integer) and \code{first}
#'   (character, the first disagreement written out as text, \code{""} when
#'   none). Zero \code{mismatched} throughout is the passing result.
#'
#' @details
#' Units are matched by their identifier as text with spaces trimmed; when
#' an identifier repeats, its first row is used. Numeric columns are compared
#' with [all.equal()] at its default tolerance (relative
#' \eqn{1.5 \times
#' 10^{-8}}), so a coordinate that survived a round trip through text is not
#' reported as a change; everything else is compared exactly as text after
#' trimming whitespace. Two missing values agree; a missing value against a
#' present one disagrees.
#'
#' What this establishes is that the recomputation reproduced the
#' published assignment. It does NOT establish that the assignment is
#' right: run the same method against the same boundary file and a
#' definitional error reproduces perfectly. That is what
#' [region_map_second_route()] is for.
#'
#' Errors: either input not a data frame or without \code{unit}; a column in
#' \code{cols} that is not in both.
#'
#' @seealso [region_map_second_route()],
#'   [region_map_integrity()]
#'
#' @examples
#' pub <- data.frame(
#'   inst = c("North Jail", "South Jail"),
#'   cd = c("3557", "3520"), stringsAsFactors = FALSE
#' )
#' obs <- pub
#' region_map_compare(pub, obs, "inst")
#'
#' # a changed assignment is reported with the unit that moved
#' obs$cd[2] <- "3521"
#' region_map_compare(pub, obs, "inst")
#'
#' # a unit on one side only, and a coordinate that only moved by rounding noise
#' pub$lat <- c(44.39, 43.65)
#' obs2 <- data.frame(inst = c("North Jail", "Hill Jail"), cd = c("3557", "3506"),
#'                    lat = c(44.39 + 1e-12, 45.1))
#' region_map_compare(pub, obs2, "inst", cols = c("cd", "lat"))
#'
#' # a compared column must be in both maps
#' try(region_map_compare(pub, obs, "inst", cols = "lat"))
#' @export
region_map_compare <- function(published, observed, unit, cols = NULL) {
  .rmbl_no_fn(unit = unit, cols = cols)
  pu <- trimws(as.character(.rmbl_rm_col(published, unit, "published")))
  ou <- trimws(as.character(.rmbl_rm_col(observed, unit, "observed")))
  if (is.null(cols)) {
    cols <- setdiff(intersect(names(published), names(observed)), unit)
  }
  cols <- as.character(cols)
  missing_cols <- setdiff(cols, intersect(names(published), names(observed)))
  if (length(missing_cols)) {
    stop("both frames need the compared columns; missing: ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }
  only_pub <- setdiff(pu, ou)
  only_obs <- setdiff(ou, pu)
  shared <- intersect(pu, ou)
  ip <- match(shared, pu)
  io <- match(shared, ou)
  res <- list(data.frame(
    column = "rows", cells = length(unique(c(pu, ou))),
    mismatched = length(only_pub) + length(only_obs),
    first = if (length(only_pub)) {
      paste0("published only: ", only_pub[1])
    } else if (length(only_obs)) {
      paste0("recomputed only: ", only_obs[1])
    } else {
      ""
    }, stringsAsFactors = FALSE
  ))
  for (cl in cols) {
    a <- published[[cl]][ip]
    b <- observed[[cl]][io]
    same <- if (is.numeric(a) && is.numeric(b)) {
      vapply(seq_along(a), function(i) {
        isTRUE(all.equal(a[i], b[i]))
      }, logical(1))
    } else {
      trimws(as.character(a)) == trimws(as.character(b))
    }
    same[is.na(same)] <- is.na(a[is.na(same)]) & is.na(b[is.na(same)])
    bad <- which(!same)
    res[[length(res) + 1L]] <- data.frame(
      column = cl, cells = length(shared), mismatched = length(bad),
      first = if (length(bad)) {
        sprintf(
          "%s: published %s, recomputed %s",
          shared[bad[1]], a[bad[1]], b[bad[1]]
        )
      } else {
        ""
      }, stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, res)
  row.names(out) <- NULL
  out
}

#' Check a region map against an independently derived assignment
#'
#' Compares the region each unit was assigned with the region a DIFFERENT
#' method assigns it, and marks the disagreements that are already known
#' and explained. Use it to catch errors in the method that built the map,
#' which re-running that same method can never find.
#'
#' @param map Data frame, one row per unit.
#' @param unit Name of the unit identifier column (a string).
#' @param region Name of the assigned region column (a string).
#' @param route Named character vector (names are units, values regions),
#'   or a data frame with the same two column names as \code{map}, giving the
#'   second method's assignment. Units it does not cover, and entries that
#'   are \code{NA} or blank, are skipped rather than counted as disagreements.
#' @param known Character vector of units whose disagreement is expected and
#'   documented -- the cases the second route is known to get wrong. Default
#'   none.
#'
#' @return A data frame of disagreements, sorted with unexplained ones first,
#'   with the columns \code{unit}, \code{primary} (the map's region),
#'   \code{second} (the route's region), all character, and \code{known}
#'   (logical). \code{sum(!x$known)} is the number of unexplained
#'   disagreements and zero is the passing value; \code{nrow(x)} should equal
#'   the number of documented cases, because a documented case that stops
#'   disagreeing means the second route changed underneath the documentation.
#'
#' @details
#' This is the only check here that can catch an error in the original
#' method, because it does not use that method. Recomputing point in
#' polygon against the same boundary file proves the pipeline is
#' deterministic; deriving the region a second way -- from a name, a
#' postal geography, an administrative lookup -- can disagree, and a
#' disagreement is information either way round.
#'
#' The \code{known} argument exists because a second route usually has
#' understood weaknesses: a place name that is a community rather than a
#' municipality, an amalgamated city, a township absorbed into a
#' neighbour. Listing them keeps the check sharp instead of loosening the
#' tolerance until everything passes, and listing them by NAME means an
#' unexpected disagreement cannot hide inside an allowance.
#'
#' Units and regions are compared as text with spaces trimmed. Errors:
#' \code{map} not a data frame or without the named columns; a \code{route}
#' vector without names; a \code{route} data frame without the two columns.
#'
#' @seealso [region_map_compare()],
#'   [region_map_integrity()]
#'
#' @examples
#' cw <- data.frame(
#'   inst = c("North Jail", "South Jail", "Hill Jail"),
#'   cd = c("3557", "3520", "3506"),
#'   stringsAsFactors = FALSE
#' )
#'
#' # a name-based route that is known to mis-place one unit
#' route <- c(
#'   "North Jail" = "3557", "South Jail" = "3520",
#'   "Hill Jail" = "3519"
#' )
#' region_map_second_route(cw, "inst", "cd", route, known = "Hill Jail")
#'
#' # an undocumented disagreement is what the check is for
#' route["South Jail"] <- "3521"
#' d <- region_map_second_route(cw, "inst", "cd", route, known = "Hill Jail")
#' sum(!d$known)
#'
#' # the route as a data frame with the same column names
#' route_df <- data.frame(inst = c("North Jail", "Hill Jail"), cd = c("3557", "3506"))
#' nrow(region_map_second_route(cw, "inst", "cd", route_df))
#'
#' # an unnamed vector cannot be matched to units
#' try(region_map_second_route(cw, "inst", "cd", c("3557", "3520")))
#' @export
region_map_second_route <- function(map, unit, region, route,
                                    known = character()) {
  .rmbl_no_fn(unit = unit, region = region, route = route, known = known)
  u <- trimws(as.character(.rmbl_rm_col(map, unit, "map")))
  r <- trimws(as.character(.rmbl_rm_col(map, region, "map")))
  if (is.data.frame(route)) {
    route <- stats::setNames(
      trimws(as.character(.rmbl_rm_col(route, region, "route"))),
      trimws(as.character(.rmbl_rm_col(route, unit, "route")))
    )
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
    known = u[bad] %in% known, stringsAsFactors = FALSE
  )
  out <- out[order(out$known, out$unit), ]
  row.names(out) <- NULL
  out
}

#' Recompute a region map by point in polygon
#'
#' Assigns each point (a facility's longitude and latitude) to the polygon of
#' a boundary file that contains it, and carries the polygon's identifier
#' and name columns onto the result. Requires the \code{sf} package and a
#' boundary file; returns \code{NULL} when either is absent, so a
#' verification script can record the check as unavailable instead of
#' failing for a missing optional dependency.
#'
#' @param x,y Longitude and latitude of each point (numeric vectors, no
#'   \code{NA}), in the coordinate reference system \code{crs}.
#' @param unit Identifier for each point, same length (character, no
#'   missing or empty values).
#' @param boundaries Path to a boundary file \code{sf} can read (a shapefile,
#'   GeoPackage, GeoJSON, ...).
#' @param fields Character vector of columns of the boundary file to carry
#'   onto the result.
#' @param crs Coordinate reference system the points are in, anything
#'   \code{sf::st_crs()} accepts. Default \code{4326}, that is WGS84, which is
#'   what published latitude and longitude columns almost always are.
#'
#' @return A data frame: \code{unit}, the requested \code{fields} (factors
#'   converted to character; \code{NA} for a point in no polygon, the first
#'   polygon's values for a point in several), and \code{n_regions} (integer),
#'   the number of polygons that contained the point. Any value of
#'   \code{n_regions} other than 1 is a failure -- zero means the point fell
#'   outside the geography, more than one means the boundaries overlap --
#'   so it is returned rather than silently resolved. \code{NULL} if \code{sf}
#'   is not installed or \code{boundaries} does not exist.
#'
#' @details
#' The points are projected onto the boundary file's own coordinate
#' reference system before matching, never the other way round: a
#' cartographic boundary file is published in a projection chosen for the
#' country it covers, and reprojecting the polygons to compare them
#' against unprojected points moves the edges. Containment is
#' \code{sf::st_within()}, so a point exactly on a shared edge is in neither
#' polygon. The whole boundary file is read into memory with
#' \code{sf::st_read()}; national files can take some seconds.
#'
#' Point in polygon is preferred to matching place names against
#' subdivision names whenever both are available. Names fail on exactly
#' the cases that matter and fail quietly: a facility in a community
#' rather than an incorporated municipality, a city amalgamated into a
#' larger one, a township absorbed by a neighbour. The geometry has no
#' opinion about any of that.
#'
#' Use [region_map_second_route()]
#' to check this result against the name route, with those cases named,
#' and [region_map_compare()] to compare it with a
#' published map.
#'
#' Errors (when \code{sf} and the file are present): missing or empty
#' \code{unit}; \code{x}, \code{y} and \code{unit} of different lengths;
#' missing coordinates; a field the boundary file does not have.
#'
#' @seealso [region_map_compare()],
#'   [region_map_second_route()]
#'
#' @examples
#' # Two square regions as a small GeoJSON boundary file.
#' gj <- tempfile(fileext = ".geojson")
#' writeLines(paste0(
#'   '{"type":"FeatureCollection","features":[',
#'   '{"type":"Feature","properties":{"CDUID":"A","CDNAME":"West"},"geometry":',
#'   '{"type":"Polygon","coordinates":[[[-80,43],[-79,43],[-79,44],[-80,44],[-80,43]]]}},',
#'   '{"type":"Feature","properties":{"CDUID":"B","CDNAME":"East"},"geometry":',
#'   '{"type":"Polygon","coordinates":[[[-79,43],[-78,43],[-78,44],[-79,44],[-79,43]]]}}]}'
#' ), gj)
#'
#' if (requireNamespace("sf", quietly = TRUE)) {
#'   obs <- region_map_from_points(
#'     x = c(-79.5, -78.5, -70), y = c(43.5, 43.5, 43.5),
#'     unit = c("North Jail", "South Jail", "Far Jail"),
#'     boundaries = gj, fields = c("CDUID", "CDNAME")
#'   )
#'   print(obs)
#'   # the point outside both regions is reported, not dropped
#'   obs$unit[obs$n_regions != 1]
#'
#'   # a field the file does not have is an error
#'   print(try(region_map_from_points(-79.5, 43.5, "North Jail", gj, fields = "PRUID")))
#' }
#'
#' # no boundary file: NULL, so a script can record the check as unavailable
#' region_map_from_points(-79.5, 43.5, "North Jail",
#'                        boundaries = file.path(tempdir(), "missing.shp"), fields = "CDUID")
#' unlink(gj)
#' @export
region_map_from_points <- function(x, y, unit, boundaries, fields,
                                   crs = 4326) {
  if (!requireNamespace("sf", quietly = TRUE)) {
    return(NULL)
  }
  if (!is.character(boundaries) || length(boundaries) != 1L || is.na(boundaries)) {
    stop("`boundaries` must be the path of one boundary file", call. = FALSE)
  }
  if (!file.exists(boundaries)) {
    return(NULL)
  }
  unit <- .rmbl_rm_chr(unit, "unit")
  x <- .rmbl_num(x, "x")
  y <- .rmbl_num(y, "y")
  if (length(x) != length(unit) || length(y) != length(unit)) {
    stop("`x`, `y` and `unit` must be the same length", call. = FALSE)
  }
  if (anyNA(x) || anyNA(y)) {
    stop("`x` and `y` must be complete: a point with no coordinate ",
      "cannot be matched",
      call. = FALSE
    )
  }
  poly <- sf::st_read(boundaries, quiet = TRUE)
  fields <- as.character(fields)
  miss <- setdiff(fields, names(poly))
  if (length(miss)) {
    stop("boundary file has no column(s): ", paste(miss, collapse = ", "),
      call. = FALSE
    )
  }
  pts <- sf::st_as_sf(data.frame(.x = x, .y = y),
    coords = c(".x", ".y"),
    crs = crs
  )
  ## onto the boundary file's CRS, not the reverse: reprojecting the
  ## polygons would move their edges
  pts <- sf::st_transform(pts, sf::st_crs(poly))
  hit <- sf::st_within(pts, poly)
  n <- lengths(hit)
  first <- vapply(
    hit, function(h) if (length(h)) h[1] else NA_integer_,
    integer(1)
  )
  out <- data.frame(unit = unit, stringsAsFactors = FALSE)
  for (f in fields) {
    v <- poly[[f]][first]
    out[[f]] <- if (is.factor(v)) as.character(v) else v
  }
  out$n_regions <- as.integer(n)
  out
}
