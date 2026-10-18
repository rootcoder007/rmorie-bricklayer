# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The 2021 Census Indigenous Population Profile (Statistics Canada 98-510-X2021001 to -016): read as
# published, shares with intervals that carry the long-form sample and random rounding, an Indigenous
# standard population for age standardisation, and a Community Well-Being score from public figures.

# identity columns of the profile, as the files name them, and the labels used here
.rmbl_ipp_groups <- c(
  TOTAL_IND_IDENT = "Total", IND_IDENT = "Indigenous identity", SINGLE_IND_RESP = "Single Indigenous responses",
  FIRST_NATIONS = "First Nations", "MÉTIS" = "Métis", INUK = "Inuit",
  MULTI_IND_RESP = "Multiple Indigenous responses", IND_RESP_NIE = "Indigenous responses not included elsewhere",
  NON_IND = "Non-Indigenous", TOTAL_IND_HHLD = "Total households", IND_HHLD = "Indigenous households",
  NON_IND_HHLD = "Non-Indigenous households")

#' Read the 2021 Census Indigenous Population Profile
#'
#' Reads a table of the Indigenous Population Profile, 2021 Census of Population (Statistics Canada
#' catalogue 98-510-X2021001 to 98-510-X2021016), as the data service mirrors it under
#' \code{census2021_ipp/}, into one row per geography, gender, age group, characteristic and group:
#' First Nations, Metis, Inuit, the other identity groups and non-Indigenous people (or, in the
#' household tables, Indigenous and non-Indigenous households), each in its own rows.
#'
#' @details
#' The profile gives each characteristic in a hierarchy shown only by indentation ("Total - Highest
#' certificate, diploma or degree", "High (secondary) school diploma or equivalency certificate",
#' ...): the level, the parent and the topic's total (\code{root_id}) are worked out from it, so a
#' share can be taken of its parent. A topic marked "25\% sample data" comes from the long-form
#' sample (\code{sample = "25\%"}); the others from the full count (\code{"100\%"}). Counts are
#' randomly rounded to multiples of 5 (of 10 below 10) by Statistics Canada, and a cell suppressed
#' to protect confidentiality (\code{x}), too unreliable (\code{F}), not available (\code{..}) or not
#' applicable (\code{...}) has no value here; \code{E} values are kept and marked. The global
#' non-response rates of the geography (\code{tnr_sf}, \code{tnr_lf}, in percent) are kept: Statistics
#' Canada suppresses an area whose long-form rate is 50\% or more, and a high rate means a larger error
#' than the sample alone.
#'
#' @param x A profile table as published (a data frame read from its CSV), or a data service key
#'   (\code{"census2021_ipp/x2021001_pop"}).
#' @return A data frame of class \code{rmbl_census_profile}: \code{geo}, \code{dguid},
#'   \code{geo_level}, \code{residence} (on or off reserve, in the tables that split it), \code{gender},
#'   \code{age}, \code{characteristic_id}, \code{characteristic},
#'   \code{level}, \code{parent_id}, \code{root_id}, \code{sample}, \code{group}, \code{value},
#'   \code{quality}, \code{tnr_sf}, \code{tnr_lf}.
#' @references
#' Statistics Canada (2023). Indigenous Population Profile, 2021 Census of Population. Statistics
#' Canada Catalogue no. 98-510-X2021001. Released June 21, 2023.
#' \url{https://www12.statcan.gc.ca/census-recensement/2021/dp-pd/ipp-ppa/index.cfm?Lang=E}
#'
#' Statistics Canada (2022). Guide to the Census of Population, 2021. Catalogue no. 98-304-X.
#' @seealso \code{\link{profile_share}}, \code{\link{census_standard}}, \code{\link{census_cwb}},
#'   \code{\link{indigenous_example}}.
#' @examples
#' p <- census_profile(indigenous_example("census_population"))
#' head(p[p$characteristic == "Foster children" & p$geo == "Canada", ])
#' @export
census_profile <- function(x) {
  if (is.character(x) && length(x) == 1L && !is.na(x)) x <- bricklayer_data_load(x)
  if (!is.data.frame(x)) stop("`x` must be a data frame or a data service key", call. = FALSE)
  need <- c("GEO_NAME", "CHARACTERISTIC_ID", "CHARACTERISTIC_NAME")
  if (!all(need %in% names(x))) {
    stop("`x` is not an Indigenous Population Profile table (no GEO_NAME, CHARACTERISTIC_ID, CHARACTERISTIC_NAME)",
         call. = FALSE)
  }
  nm <- names(x)
  sym <- grep("^SYMBOL_", nm, value = TRUE)
  base <- sub("^SYMBOL_", "", sym)
  vcol <- vapply(base, function(b) {
    hit <- nm[sub("\\s*\\([0-9]+\\)$", "", nm) == b & !grepl("^SYMBOL_", nm)]
    if (length(hit)) hit[[1L]] else NA_character_
  }, "")
  keep <- !is.na(vcol)
  if (!any(keep)) stop("`x` has no group columns with their SYMBOL_ columns", call. = FALSE)
  sym <- sym[keep]
  base <- base[keep]
  vcol <- vcol[keep]
  lab <- ifelse(base %in% names(.rmbl_ipp_groups), .rmbl_ipp_groups[base], base)
  # the hierarchy, from the indentation of each characteristic's name (two spaces a level)
  cid <- as.integer(x$CHARACTERISTIC_ID)
  raw <- as.character(x$CHARACTERISTIC_NAME)
  u <- !duplicated(cid)
  ch <- data.frame(id = cid[u], name = raw[u])
  ch <- ch[order(ch$id), ]
  ch$level <- (nchar(ch$name) - nchar(sub("^\\s+", "", ch$name))) %/% 2L
  ch$name <- trimws(gsub(" ", " ", ch$name))
  ch$parent <- NA_integer_
  ch$root <- NA_integer_
  stack <- integer()
  last_total <- NA_integer_
  for (i in seq_len(nrow(ch))) {
    lv <- ch$level[i]
    stack <- stack[seq_len(min(length(stack), lv))]
    ch$parent[i] <- if (lv > 0L && length(stack) >= lv) stack[lv] else NA_integer_
    ch$root[i] <- if (lv > 0L && length(stack)) stack[1L] else ch$id[i]
    # a top-level line that is not a "Total - " ("Participation rate", "In low income ...") belongs to
    # the topic above it: its sample is that topic's
    if (lv == 0L && grepl("^Total", ch$name[i])) last_total <- ch$id[i]
    if (lv == 0L && !grepl("^Total", ch$name[i]) && !is.na(last_total)) ch$root[i] <- last_total
    stack[lv + 1L] <- ch$id[i]
  }
  root_name <- ch$name[match(ch$root, ch$id)]
  ch$sample <- ifelse(grepl("25% sample", root_name, fixed = TRUE), "25%", "100%")
  m <- match(cid, ch$id)
  col_or <- function(n, default = NA) if (n %in% nm) x[[n]] else rep(default, nrow(x))
  n <- nrow(x)
  k <- length(vcol)
  rep_k <- function(v) rep(v, times = k)
  st <- unlist(lapply(sym, function(s) as.character(x[[s]])), use.names = FALSE)
  st[is.na(st)] <- ""
  st <- trimws(st)
  q <- ifelse(st == "", "ok", st)
  q[q == "rE"] <- "E"
  q[!q %in% c("ok", "E", "F", "x", "..", "...")] <- "ok"
  val <- suppressWarnings(as.numeric(unlist(lapply(vcol, function(v) as.character(x[[v]])), use.names = FALSE)))
  val[q %in% c("F", "x", "..", "...")] <- NA_real_
  out <- data.frame(
    geo = rep_k(as.character(x$GEO_NAME)), dguid = rep_k(as.character(col_or("DGUID"))),
    geo_level = rep_k(as.character(col_or("GEO_LEVEL"))),
    residence = rep_k(as.character(col_or("RESIDENCE", "Total"))),
    gender = rep_k(as.character(col_or("GENDER", "Total"))),
    age = rep_k(as.character(col_or("AGE_GROUP", "Total"))), characteristic_id = rep_k(cid),
    characteristic = rep_k(ch$name[m]), level = rep_k(ch$level[m]), parent_id = rep_k(ch$parent[m]),
    root_id = rep_k(ch$root[m]), sample = rep_k(ch$sample[m]), group = rep(unname(lab), each = n),
    value = val, quality = factor(q, levels = c("ok", "E", "F", "x", "..", "...")),
    tnr_sf = rep_k(suppressWarnings(as.numeric(col_or("TNR_SF")))),
    tnr_lf = rep_k(suppressWarnings(as.numeric(col_or("TNR_LF")))), stringsAsFactors = FALSE)
  class(out) <- c("rmbl_census_profile", "data.frame")
  out
}

#' The share of a population with a characteristic, from the census profile
#'
#' The share of a group with a characteristic of the 2021 Census Indigenous Population Profile
#' (foster children among children, speakers of an Indigenous language, households needing major
#' repairs, ...), with an approximate confidence interval that carries the long-form sample and the
#' random rounding of the counts.
#'
#' @details
#' The share is the numerator's count over the denominator's (by default the numerator's parent in
#' the profile's hierarchy), for each geography, gender, age group and group. Statistics Canada does
#' not publish standard errors for the profile, so the interval is an approximation built from what is
#' known about how the counts were made:
#' \itemize{
#'   \item a long-form ("25\% sample") count is estimated from a sample of about one household in four,
#'     so the share has variance \eqn{d (1 - f) p (1 - p) / (f N)} for a sampling fraction \eqn{f}
#'     (\code{sample_fraction}, 0.25) of a population of \eqn{N} (the denominator) and a design effect
#'     \eqn{d} (\code{deff}, 1 by default: the clustering of people in households raises it, and a
#'     value of 1.5 to 2 is prudent for characteristics shared within a household);
#'   \item every count is randomly rounded to a multiple of 5, which adds an error of variance about 4
#'     to each count, so \eqn{4 (1 + p^2) / N^2} more (the only error of a full-count share).
#' }
#' The interval is Wilson's at the effective sample size \eqn{p(1-p)} over that variance, so it stays
#' inside 0 and 100. It does not carry non-response (see \code{tnr_lf}) or the edit and imputation
#' error, so it is narrower than the full error; treat it as a lower bound on the uncertainty.
#'
#' @param x A \code{\link{census_profile}}.
#' @param numerator The characteristic counted: its \code{characteristic_id}, or its name exactly.
#' @param denominator The characteristic it is a share of (id or name); default its parent.
#' @param sample_fraction The long-form sampling fraction (default 0.25); full-count characteristics
#'   use 1 whatever is given.
#' @param deff Design effect (default 1).
#' @param conf_level Confidence level (default 0.95).
#' @return A data frame of class \code{rmbl_profile_share}: \code{geo}, \code{dguid}, \code{residence},
#'   \code{gender},
#'   \code{age}, \code{group}, \code{numerator}, \code{denominator}, \code{estimate} (percent),
#'   \code{lower}, \code{upper}, \code{quality}; ready for \code{\link{indigenous_gap}} and
#'   \code{\link{distinctions_test}}. \code{plot()} draws it.
#' @references
#' Statistics Canada (2022). Guide to the Census of Population, 2021, chapter 9 (data quality) and
#' chapter 10 (confidentiality and random rounding). Catalogue no. 98-304-X.
#'
#' Wilson EB (1927). Probable inference, the law of succession, and statistical inference. Journal of
#' the American Statistical Association 22(158):209-212. \doi{10.1080/01621459.1927.10502953}
#' @seealso \code{\link{census_profile}}.
#' @examples
#' p <- census_profile(indigenous_example("census_population"))
#' # children who are foster children, by province, First Nations, Metis, Inuit and non-Indigenous
#' fc <- profile_share(p, "Foster children", "Total - Children in census families")
#' fc <- fc[fc$age == "0 to 14 years" & fc$group %in% c("First Nations", "Métis", "Inuit",
#'                                                      "Non-Indigenous"), ]
#' head(fc)
#' plot(fc[fc$geo == "Canada", ])
#' @export
profile_share <- function(x, numerator, denominator = NULL, sample_fraction = 0.25, deff = 1, conf_level = 0.95) {
  if (!inherits(x, "rmbl_census_profile")) stop("`x` must come from census_profile()", call. = FALSE)
  sample_fraction <- .rmbl_scalar(sample_fraction, "sample_fraction", 0.001, 1)
  deff <- .rmbl_scalar(deff, "deff", 0.1, 100)
  conf_level <- .rmbl_conf_level(conf_level)
  pick <- function(v, what) {
    if (length(v) != 1L || is.na(v)) stop(sprintf("`%s` must be one characteristic id or name", what), call. = FALSE)
    id <- if (is.numeric(v)) as.integer(v) else unique(x$characteristic_id[x$characteristic == v])
    if (length(id) != 1L || !id %in% x$characteristic_id) {
      stop(sprintf("`%s` (%s) names %s characteristic of `x`", what, v,
                   if (length(id) > 1L) "more than one" else "no"), call. = FALSE)
    }
    id
  }
  nid <- pick(numerator, "numerator")
  did <- if (is.null(denominator)) unique(x$parent_id[x$characteristic_id == nid]) else pick(denominator, "denominator")
  if (length(did) != 1L || is.na(did)) stop("the numerator has no parent: give `denominator`", call. = FALSE)
  key <- function(d) paste(d$dguid, d$geo, d$residence, d$gender, d$age, d$group, sep = "\r")
  a <- x[x$characteristic_id == nid, ]
  b <- x[x$characteristic_id == did, ]
  m <- match(key(a), key(b))
  num <- a$value
  den <- b$value[m]
  ok <- is.finite(num) & is.finite(den) & den > 0 & num >= 0 & num <= den
  p <- ifelse(ok, num / den, NA_real_)
  f <- ifelse(a$sample == "25%", sample_fraction, 1)
  v <- ifelse(ok, deff * (1 - f) * p * (1 - p) / (f * den) + 4 * (1 + p^2) / den^2, NA_real_)
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  ne <- ifelse(ok & v > 0, pmax(p * (1 - p), 1 / den) / v, NA_real_)
  centre <- (p + z^2 / (2 * ne)) / (1 + z^2 / ne)
  half <- z / (1 + z^2 / ne) * sqrt(p * (1 - p) / ne + z^2 / (4 * ne^2))
  qa <- as.character(a$quality)
  qb <- as.character(b$quality)[m]
  qual <- ifelse(qa == "ok" & qb %in% "ok", "ok", ifelse(qa == "ok", qb, qa))
  out <- data.frame(geo = a$geo, dguid = a$dguid, residence = a$residence, gender = a$gender, age = a$age,
                    group = a$group,
                    numerator = num, denominator = den, estimate = 100 * p,
                    lower = 100 * pmax(0, centre - half), upper = 100 * pmin(1, centre + half),
                    quality = qual, stringsAsFactors = FALSE)
  rownames(out) <- NULL
  attr(out, "characteristics") <- c(numerator = unique(a$characteristic), denominator = unique(b$characteristic))
  attr(out, "conf_level") <- conf_level
  class(out) <- c("rmbl_profile_share", "data.frame")
  out
}

#' An Indigenous standard population from the census
#'
#' The age structure of a group in a geography of the 2021 Census Indigenous Population Profile, as
#' the standard of \code{\link{age_standardise}} or \code{\link{standardise_prevalence}}.
#'
#' @details
#' Comparisons of First Nations, Metis and Inuit health are standardised to the Indigenous
#' population's own, younger, age structure (Kumar and Tjepkema 2019): a standard as old as Canada's
#' gives weight to ages where few Indigenous people are. This takes the population in private
#' households of each age group (the profile's first characteristic) for the group and geography
#' given. Age groups that do not overlap are chosen by default (0 to 4, 5 to 9, 10 to 14, 15 to 19, 20
#' to 24, 25 to 34, 35 to 44, 45 to 54, 55 to 64, 65 to 74, 75 and over); collapse them to the age
#' groups of the rates being standardised.
#'
#' @param x A \code{\link{census_profile}}.
#' @param group The group (default \code{"Indigenous identity"}).
#' @param geo The geography (default \code{"Canada"}).
#' @param ages The age groups, as the profile names them.
#' @param residence On or off reserve, in the tables that split it (default the total).
#' @return A data frame: \code{age}, \code{population}, \code{weight} (shares summing to 1).
#' @references Kumar MB, Tjepkema M (2019). Suicide among First Nations people, Metis and Inuit
#'   (2011-2016): findings from the 2011 Canadian Census Health and Environment Cohort (CanCHEC).
#'   Statistics Canada catalogue no. 99-011-X2019001.
#' @seealso \code{\link{age_standardise}}, \code{\link{standardise_prevalence}}.
#' @examples
#' p <- census_profile(indigenous_example("census_population"))
#' census_standard(p)
#' @export
census_standard <- function(x, group = "Indigenous identity", geo = "Canada",
                            ages = c("0 to 4 years", "5 to 9 years", "10 to 14 years", "15 to 19 years",
                                     "20 to 24 years", "25 to 34 years", "35 to 44 years", "45 to 54 years",
                                     "55 to 64 years", "65 to 74 years", "75 years and over"),
                            residence = "Total - Residence on or off reserve") {
  if (!inherits(x, "rmbl_census_profile")) stop("`x` must come from census_profile()", call. = FALSE)
  group <- .rmbl_string1(group, "group")
  geo <- .rmbl_string1(geo, "geo")
  .rmbl_no_fn(ages = ages)
  if (!is.character(ages) || !length(ages) || anyNA(ages)) stop("`ages` must name age groups", call. = FALSE)
  first <- min(x$characteristic_id)
  residence <- .rmbl_string1(residence, "residence")
  d <- x[x$characteristic_id == first & x$group == group & x$geo == geo & x$gender %in% c("Total - Gender", "Total") &
           x$residence %in% c(residence, "Total"), ]
  if (!nrow(d)) stop(sprintf("no population for group \"%s\" in \"%s\"", group, geo), call. = FALSE)
  pop <- d$value[match(ages, d$age)]
  if (anyNA(pop)) {
    stop(sprintf("no population for: %s", paste(ages[is.na(pop)], collapse = ", ")), call. = FALSE)
  }
  data.frame(age = ages, population = pop, weight = pop / sum(pop), stringsAsFactors = FALSE)
}

#' A Community Well-Being score from the census profile
#'
#' Indigenous Services Canada's Community Well-Being (CWB) index (\code{\link{cwb_score}}) computed
#' from the public 2021 Census Indigenous Population Profile, for each geography and group.
#'
#' @details
#' The Department computes the CWB from census microdata; the public profile gives close but not the
#' same inputs, and this function says where it departs:
#' \describe{
#'   \item{income}{per capita: the number of total income recipients aged 15 and over times their
#'     average total income, over the population in private households (all ages), as the CWB does.}
#'   \item{education}{the shares with at least a high school diploma (all but those with no
#'     certificate, diploma or degree) and with a bachelor's degree or higher, both among those aged 25
#'     and over: the profile has no age group of 20 and over, which
#'     the CWB uses for the first.}
#'   \item{labour force}{the participation rate and the employment rate of participants (100 less the
#'     unemployment rate) of those aged 25 to 64: the CWB uses 20 to 64.}
#'   \item{housing}{the shares of households with one person or fewer per room and needing no major
#'     repairs, from the household profile (\code{dwelling}), which splits Indigenous from non-Indigenous
#'     households only: the CWB counts persons, not households. Without \code{dwelling} the housing
#'     component and the score are \code{NA}.}
#' }
#' A group of fewer than 250 people in a geography gets no score, as the Department suppresses
#' communities that small. Read the result as a CWB-style description of socio-economic conditions, close to but not the
#' Department's index, and never as a measure of the wellness of First Nations, Metis or Inuit people
#' as they define it (see \code{\link{cwb_score}}).
#'
#' @param x A \code{\link{census_profile}} of a population table.
#' @param dwelling Optional \code{\link{census_profile}} of the matching household table.
#' @param groups The groups to score (default First Nations, Metis, Inuit and non-Indigenous people).
#' @param bounds Income bounds of \code{\link{cwb_score}}.
#' @param residence On or off reserve, in the tables that split it (default the total).
#' @return A data frame: \code{geo}, \code{group}, the four components, \code{cwb}, and the inputs.
#' @references Indigenous Services Canada (2019). Report on trends in First Nations communities, 1981
#'   to 2016 (Community Well-Being index).
#'   \url{https://www.sac-isc.gc.ca/eng/1345816651029/1557323327644}
#' @seealso \code{\link{cwb_score}}.
#' @examples
#' p <- census_profile(indigenous_example("census_population"))
#' h <- census_profile(indigenous_example("census_households"))
#' census_cwb(p, h)[, c("geo", "group", "income", "education", "housing", "labour", "cwb")]
#' @export
census_cwb <- function(x, dwelling = NULL, groups = c("First Nations", "Métis", "Inuit", "Non-Indigenous"),
                       bounds = c(2650, 75000), residence = "Total - Residence on or off reserve") {
  if (!inherits(x, "rmbl_census_profile")) stop("`x` must come from census_profile()", call. = FALSE)
  if (!is.null(dwelling) && !inherits(dwelling, "rmbl_census_profile")) {
    stop("`dwelling` must come from census_profile()", call. = FALSE)
  }
  .rmbl_no_fn(groups = groups)
  residence <- .rmbl_string1(residence, "residence")
  tot_g <- x$gender %in% c("Total - Gender", "Total") & x$residence %in% c(residence, "Total")
  val <- function(name, age, root = NULL) {
    d <- x[tot_g & x$characteristic == name & x$age == age, ]
    if (!is.null(root)) d <- d[d$root_id == root, ]
    d
  }
  look <- function(d, geo, group) {
    v <- d$value[d$geo == geo & d$group == group]
    if (length(v)) v[[1L]] else NA_real_
  }
  pop_id <- min(x$characteristic_id)
  pop <- x[tot_g & x$characteristic_id == pop_id & x$age == "Total - Age groups", ]
  rec <- val("Number of total income recipients aged 15 years and over in private households in 2020 - 25% sample data",
             "Total - Age groups")
  avg <- val("Average total income in 2020 among recipients ($)", "Total - Age groups")
  edu_tot <- x[tot_g & x$age == "25 years and over" & grepl("^Total - Highest certificate", x$characteristic), ]
  # "High (secondary) school diploma" is high school only in the 2021 profile: at least high school is
  # everyone but those with no certificate
  none <- val("No certificate, diploma or degree", "25 years and over", unique(edu_tot$characteristic_id))
  ba <- val("Bachelor's degree or higher", "25 years and over", unique(edu_tot$characteristic_id))
  part <- val("Participation rate", "25 to 64 years")
  unemp <- val("Unemployment rate", "25 to 64 years")
  geos <- unique(x$geo)
  rows <- list()
  for (g in geos) {
    for (gr in groups) {
      inc <- look(rec, g, gr) * look(avg, g, gr) / look(pop, g, gr)
      e_t <- look(edu_tot, g, gr)
      rows[[length(rows) + 1L]] <- data.frame(
        geo = g, group = gr, income_per_capita = inc,
        high_school_25plus = 100 * (1 - look(none, g, gr) / e_t), university_25plus = 100 * look(ba, g, gr) / e_t,
        population = look(pop, g, gr),
        participation = look(part, g, gr), employment = 100 - look(unemp, g, gr), stringsAsFactors = FALSE)
    }
  }
  d <- do.call(rbind, rows)
  d$not_crowded <- d$no_major_repairs <- NA_real_
  if (!is.null(dwelling)) {
    hh <- function(name) dwelling[dwelling$characteristic == name, ]
    crowd_t <- hh("Total - Private households by number of persons per room - 25% sample data")
    crowd_ok <- hh("One person or fewer per room")
    rep_t <- hh("Total - Occupied private dwellings by dwelling condition - 25% sample data")
    rep_maj <- hh("Major repairs needed")
    hgroup <- ifelse(d$group == "Non-Indigenous", "Non-Indigenous households", "Indigenous households")
    for (i in seq_len(nrow(d))) {
      d$not_crowded[i] <- 100 * look(crowd_ok, d$geo[i], hgroup[i]) / look(crowd_t, d$geo[i], hgroup[i])
      d$no_major_repairs[i] <- 100 * (1 - look(rep_maj, d$geo[i], hgroup[i]) / look(rep_t, d$geo[i], hgroup[i]))
    }
  }
  # as the Department does: no score for a population under 250 (its components would rest on a few
  # dozen sampled households)
  ok <- is.finite(d$income_per_capita) & d$income_per_capita > 0 & is.finite(d$population) & d$population >= 250
  sc <- data.frame(income = NA_real_, education = NA_real_, housing = NA_real_, labour = NA_real_, cwb = NA_real_)
  sc <- sc[rep(1L, nrow(d)), ]
  if (any(ok)) {
    s <- cwb_score(d$income_per_capita[ok], pmin(100, d$high_school_25plus[ok]), pmin(100, d$university_25plus[ok]),
                   ifelse(is.na(d$not_crowded[ok]), 50, d$not_crowded[ok]),
                   ifelse(is.na(d$no_major_repairs[ok]), 50, d$no_major_repairs[ok]),
                   d$participation[ok], d$employment[ok], bounds = bounds)
    s$housing[is.na(d$not_crowded[ok]) | is.na(d$no_major_repairs[ok])] <- NA_real_
    s$cwb <- rowMeans(s[c("income", "education", "housing", "labour")])
    sc[ok, ] <- s
  }
  rownames(sc) <- NULL
  out <- cbind(d[c("geo", "group")], sc, d[setdiff(names(d), c("geo", "group"))])
  class(out) <- c("rmbl_census_cwb", "data.frame")
  out
}

#' @rdname plot-methods
#' @export
plot.rmbl_profile_share <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_profile_share")
  d <- as.data.frame(x)
  lab <- paste0(if (length(unique(d$geo)) > 1L) paste0(d$geo, ": ") else "", d$group,
                if (length(unique(d$age)) > 1L) paste0(" (", d$age, ")") else "")
  ch <- attr(x, "characteristics")
  .bl_dot_interval(lab, d$estimate, d$lower, d$upper,
                   .bl_main(main, ch[["numerator"]]),
                   sprintf("Percent of: %s", .bl_short_label(ch[["denominator"]], 60L)),
                   .bl_cols(nrow(d), col, palette),
                   note = ifelse(is.finite(d$estimate), NA_character_, "suppressed or not available"), ...)
  invisible(d[c("geo", "group", "estimate", "lower", "upper")])
}
