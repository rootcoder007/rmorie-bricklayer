## otis_crosswalk_verify.R -- re-derive the institution to census
## division crosswalk and the census division populations it rests on,
## and compare both against the published files.
##
## The page at
##   https://zeus.tail6f5dd7.ts.net/dashboard/otis-crosswalk.html
## states where every open institution sits, by census division, and the
## population of the divisions that hold one. Those two published files
## travel with this example:
##
##   institution_cd_crosswalk.csv   35 institutions, assigned by point in
##                                  polygon against the 2021 cartographic
##                                  boundary file lcd_000b21a_e.shp
##   cd_population_2022.csv         49 Ontario census divisions, from
##                                  Statistics Canada 17-10-0139-01
##
## Neither can be checked by recomputing the tables built on them: an
## error here reproduces perfectly downstream, because everything
## downstream reads it. So the two inputs are re-derived instead.
##
## THE POPULATIONS re-derive completely and with nothing granted. The
## published table is 27 MB of Canada-wide estimates; filtering it to
## 2022, both sexes, all ages, and the 49 census divisions whose DGUID
## begins 2016A000335 must return the shipped file exactly. If Statistics
## Canada revises an estimate, this is what notices.
##
## THE ASSIGNMENT has two routes, and they are not equally good:
##
##   A recompute by the SAME method -- st_within against the same
##   boundary file -- proves the pipeline is deterministic and the file
##   was not edited. It cannot prove the method was right, because a
##   definitional error would reproduce. It needs sf and the boundary
##   file, and runs only when both are present.
##
##   A SECOND ROUTE, deriving the division from the institution's city
##   name rather than its coordinates, can disagree, and a disagreement
##   is information whichever way round it points. It covers only the
##   institutions whose city IS a census division name -- Ottawa,
##   Toronto, Hamilton, Thunder Bay, Kenora -- which is a handful, not
##   all 25, and the count of covered institutions is recorded so that
##   the check cannot quietly become vacuous. The cities that defeat the
##   name route are the ones the provenance names -- Monteith is a
##   community in Cochrane District, Scarborough is part of Toronto,
##   Maidstone is part of Lakeshore -- and none of them is a census
##   division name, so they are skipped rather than allowed for.
##
## What is NOT checked, deliberately: any per-capita rate by census
## division or by correctional region. region_coverage() reports the
## covered share and its print method says why that share is not a
## denominator. See the WHAT IT DOES NOT SUPPORT section of the
## crosswalk's own PROVENANCE.txt.

OTIS_CD_POP_URL <- "https://www150.statcan.gc.ca/n1/tbl/csv/17100139-eng.zip"

## Census divisions carry a 2016-vintage DGUID in this table, and the
## last four digits are the CDUID. Ontario is 35.
OTIS_CD_DGUID <- "^2016A0003[0-9]{4}$"
OTIS_CD_PROV <- "35"
OTIS_CD_YEAR <- "2022"

## The city-name route is known to get one institution wrong, and the
## reason is the reason to distrust name matching generally. Sudbury Jail
## stands at 46.4928, -81.0026, inside the City of Greater Sudbury, which
## is census division 3553 and holds 171,568 people. The bare name
## "Sudbury" belongs to census division 3552, Sudbury DISTRICT, the
## surrounding territory of 22,746 people. Two different places, one
## name, and the name route takes the wrong one. The geometry does not
## care what anything is called.
##
## It is listed by name rather than allowed for by loosening the check,
## so that a SECOND disagreement is still a failure.
OTIS_CW_NAME_KNOWN <- c("Sudbury Jail")

## Recorded as a fixed number so the route cannot quietly stop covering
## anything and leave the disagreement check passing over an empty set.
OTIS_CW_NAME_COVERAGE <- 11L

.ocv_read <- function(p) {
  d <- utils::read.csv(p, fileEncoding = "UTF-8-BOM", check.names = TRUE,
                       stringsAsFactors = FALSE)
  names(d) <- sub("^X\\.U\\.FEFF\\.", "", names(d))
  for (j in which(vapply(d, is.character, logical(1))))
    d[[j]] <- trimws(d[[j]])
  d
}

.ocv_norm <- function(x) {
  x <- tolower(trimws(as.character(x)))
  gsub("[^a-z0-9]+", "", x)
}

#' Download and reduce the census division population estimates.
#'
#' Returns a data frame of `cduid` and `population` for the province's
#' census divisions in the reference year, or NULL if the download or the
#' unzip fails. The archive is 27 MB and the CSV inside it is 334 MB, so
#' it is read with data.table::fread and only the five columns needed.
otis_cd_population_download <- function(dir, year = OTIS_CD_YEAR,
                                        prov = OTIS_CD_PROV) {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  zip <- file.path(dir, "17100139-eng.zip")
  csv <- file.path(dir, "17100139.csv")
  if (!file.exists(csv)) {
    ok <- tryCatch({
      utils::download.file(OTIS_CD_POP_URL, zip, mode = "wb", quiet = TRUE)
      utils::unzip(zip, exdir = dir)
      TRUE
    }, error = function(e) FALSE, warning = function(w) FALSE)
    if (!ok || !file.exists(csv)) return(NULL)
  }
  if (!requireNamespace("data.table", quietly = TRUE)) return(NULL)
  d <- tryCatch(
    data.table::fread(csv, select = c("REF_DATE", "GEO", "DGUID", "Sex",
                                      "Age group", "VALUE"),
                      showProgress = FALSE, data.table = FALSE),
    error = function(e) NULL)
  if (is.null(d)) return(NULL)
  keep <- as.character(d$REF_DATE) == year &
    d$Sex == "Both sexes" & d[["Age group"]] == "All ages" &
    grepl(OTIS_CD_DGUID, d$DGUID)
  d <- d[keep, , drop = FALSE]
  d$cduid <- substr(d$DGUID, 10, 13)
  d <- d[substr(d$cduid, 1, 2) == prov, , drop = FALSE]
  if (!nrow(d)) return(NULL)
  out <- data.frame(cduid = d$cduid, geo = d$GEO,
                    population = as.numeric(d$VALUE),
                    stringsAsFactors = FALSE)
  out[order(out$cduid), , drop = FALSE]
}

#' The name route: city name matched against census division name.
#'
#' Returns a named character vector, institution to CDUID, covering only
#' the institutions whose city is itself the name of a census division.
#' Everything else is left out, so crosswalk_second_route() skips it
#' rather than counting it as a disagreement.
otis_crosswalk_name_route <- function(crosswalk, population) {
  ## "Ottawa, Ontario" -> "Ottawa"
  cdname <- sub(",\\s*Ontario$", "", population$geo)
  key <- .ocv_norm(cdname)
  ok <- !duplicated(key) & nzchar(key)
  lookup <- stats::setNames(population$cduid[ok], key[ok])
  hit <- lookup[.ocv_norm(crosswalk$City)]
  keep <- !is.na(hit)
  stats::setNames(as.character(hit[keep]), crosswalk$Institution[keep])
}

#' Recompute the assignment by point in polygon, if sf and the boundary
#' file are both available. NULL otherwise.
otis_crosswalk_recompute_sf <- function(crosswalk, boundaries) {
  if (!nzchar(boundaries)) return(NULL)
  crosswalk_from_points(
    x = crosswalk$Longitude, y = crosswalk$Latitude,
    unit = crosswalk$Institution, boundaries = boundaries,
    fields = c("CDUID", "CDNAME"))
}

#' Every crosswalk check, as one frame of check / observed / expected.
#'
#' Each row is written so that the expected value is what a sound
#' crosswalk gives, and every row can fail: the populations are re-derived
#' from Statistics Canada rather than restated, the division count and the
#' covered population are arithmetic over that re-derivation, the name
#' route is an independent assignment, and the institution join is
#' measured against the OTIS data rather than assumed.
otis_crosswalk_checks <- function(cw, pop, obs_pop = NULL, otis_inst = NULL,
                                  sf_obs = NULL) {
  add <- function(d, check, observed, expected, note = "") {
    rbind(d, data.frame(check = check, observed = observed,
                        expected = expected, note = note,
                        stringsAsFactors = FALSE))
  }
  out <- data.frame(check = character(), observed = numeric(),
                    expected = numeric(), note = character(),
                    stringsAsFactors = FALSE)

  ## --- structure -----------------------------------------------------
  integ <- crosswalk_integrity(cw, "Institution", "CDUID",
                               regions = pop$cduid)
  for (i in seq_len(nrow(integ)))
    out <- add(out, integ$check[i], integ$observed[i], integ$expected[i])

  open <- cw[grepl("open", cw$Operating_Status, ignore.case = TRUE), ]
  units <- vapply(pop$cduid, function(u) sum(open$CDUID == u), numeric(1))
  cov <- region_coverage(pop$cduid, pop$population, units)
  a <- attr(cov, "coverage")
  out <- add(out, "census divisions in the province", a$regions, 49)
  out <- add(out, "open institutions", a$units, 25)
  out <- add(out, "divisions holding an open institution", a$with_unit, 21)
  out <- add(out, "provincial population", a$total_population, 15109416,
             "Statistics Canada 17-10-0139-01, 2022")
  out <- add(out, "population of divisions holding an institution",
             a$covered_population, 10110752)
  out <- add(out, "population of divisions holding none",
             a$uncovered_population, 4998664)

  ## --- the populations, re-derived from Statistics Canada ------------
  if (!is.null(obs_pop)) {
    cmp <- crosswalk_compare(pop, obs_pop, "cduid", cols = "population")
    for (i in seq_len(nrow(cmp)))
      out <- add(out, paste0("cd_population_2022.csv, ", cmp$column[i]),
                 cmp$mismatched[i], 0, cmp$first[i])
  }

  ## --- the second route ----------------------------------------------
  route <- otis_crosswalk_name_route(cw, pop)
  dis <- crosswalk_second_route(cw, "Institution", "CDUID", route,
                                known = OTIS_CW_NAME_KNOWN)
  out <- add(out, "institutions covered by the city-name route",
             length(route), OTIS_CW_NAME_COVERAGE,
             "fixed, so the disagreement check cannot pass over an empty set")
  out <- add(out, "documented city-name disagreements",
             sum(dis$known), length(OTIS_CW_NAME_KNOWN),
             paste("a documented case that stops disagreeing means the route",
                   "changed underneath the documentation"))
  unexplained <- dis[!dis$known, , drop = FALSE]
  out <- add(out, "unexplained city-name disagreements", nrow(unexplained), 0,
             if (nrow(unexplained))
               sprintf("%s: geometry %s, name %s", unexplained$unit[1],
                       unexplained$primary[1], unexplained$second[1]) else "")

  ## --- the OTIS join --------------------------------------------------
  if (!is.null(otis_inst)) {
    inst <- unique(otis_inst[nzchar(otis_inst)])
    matched <- sum(.ocv_norm(inst) %in% .ocv_norm(cw$Institution))
    out <- add(out, "OTIS institution names matched into the crosswalk",
               matched, length(inst),
               "after collapsing non-alphanumerics")
  }

  ## --- point in polygon, when sf and the boundary file are there ------
  if (!is.null(sf_obs)) {
    out <- add(out, "institutions inside exactly one census division",
               sum(sf_obs$n_regions == 1L), nrow(sf_obs))
    scmp <- crosswalk_compare(cw, sf_obs, "Institution", cols = "CDUID")
    for (i in seq_len(nrow(scmp)))
      out <- add(out, paste0("point in polygon recompute, ", scmp$column[i]),
                 scmp$mismatched[i], 0, scmp$first[i])
  }
  out
}
