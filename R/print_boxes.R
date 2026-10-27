# The print() methods whose box comes wholly from their format() method.
# Each is the same two lines, so they live together here rather than
# repeated beside every format() method; format() stays with its result.

#' @export
print.bricklayer_analysis <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_attestation_check
print.bricklayer_attestation_check <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_benford
print.bricklayer_benford <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_bundle_check
print.bricklayer_bundle_check <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
#' @method print bricklayer_capsule_check
print.bricklayer_capsule_check <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.bricklayer_category_audit <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_certificate
print.bricklayer_certificate <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_certpath_check
print.bricklayer_certpath_check <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_chain
print.bricklayer_chain <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.bricklayer_chain_check <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.bricklayer_cortable <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_drbg
print.bricklayer_drbg <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' Printed reports for bricklayer objects
#'
#' Human-readable renderings of the objects the package returns. Each leads
#' with the verdict, then the evidence. `format()` returns the lines
#' as a character vector so they can be logged or written to a file;
#' `print()` sends them to the console and returns its argument
#' invisibly.
#'
#' Box-drawing characters are used only when the session's encoding can
#' render them; otherwise the same layout is drawn in plain ASCII. Set the
#' environment variable `RMBL_ASCII_ONLY` to force the ASCII form,
#' which is what to do when capturing output into a fixed-width log.
#'
#' @param x The object to render.
#' @param ... Ignored, present for S3 consistency.
#' @return `format()` methods return a character vector;
#' `print()` methods return `x` invisibly.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # keep this example's
#' op <- options(rmoriebricklayer.xmssidxfile = tempfile())
#' # one-time index record out of your configuration directory; leave the
#' # default in use
#' set.seed(7)
#' ref <- data.frame(v = stats::rnorm(200), g = sample(c("a", "b"), 200, TRUE))
#' cur <- data.frame(
#'   v = stats::rnorm(200, mean = 1),
#'   g = sample(c("a", "b"), 200, TRUE)
#' )
#'
#' # The drift report leads with its verdict.
#' cpsdrft(ref, cur)
#'
#' # format() gives the same lines for a log file.
#' head(format(cpsdrft(ref, cur)), 3)
#'
#' # A Benford screen.
#' benfordtst(10^stats::runif(500, 0, 5))
#'
#' # Keys and signatures print without ever showing the secret seed.
#' key <- pqckg(height = 2)
#' key
#' cpssign("a-manifest", key)
#' options(op)
#' @name printmeth
#' @export
#' @method print bricklayer_drift
print.bricklayer_drift <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.bricklayer_drift_summary <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_env_diff
print.bricklayer_env_diff <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_falsification
print.bricklayer_falsification <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_falsify_family
print.bricklayer_falsify_family <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_fips_key
print.bricklayer_fips_key <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_fips_public_key
print.bricklayer_fips_public_key <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.bricklayer_freq <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_hqc_capsule
print.bricklayer_hqc_capsule <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_hqc_key
print.bricklayer_hqc_key <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_hqc_public_key
print.bricklayer_hqc_public_key <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_kem_capsule
print.bricklayer_kem_capsule <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_kem_key
print.bricklayer_kem_key <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_kem_public_key
print.bricklayer_kem_public_key <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_mcar
print.bricklayer_mcar <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.bricklayer_online <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_oqs_key
print.bricklayer_oqs_key <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_oqs_public_key
print.bricklayer_oqs_public_key <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.bricklayer_outliers <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_power
print.bricklayer_power <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_prereg
print.bricklayer_prereg <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_prereg_check
print.bricklayer_prereg_check <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.bricklayer_profile <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_public_key
print.bricklayer_public_key <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
print.bricklayer_recode_manifest <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_recompute
print.bricklayer_recompute <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.bricklayer_relabel_forensics <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_report
print.bricklayer_report <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.bricklayer_rule <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.bricklayer_runs <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_schema
print.bricklayer_schema <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_signature
print.bricklayer_signature <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_signing_key
print.bricklayer_signing_key <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_timestamp
print.bricklayer_timestamp <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_admits <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_adp <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_adpcnts <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_aipw <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_alos <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_archive_capture <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_archive_find <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_attrfrac <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_bacon <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_balance <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname bandsens
#' @export
print.rmbl_band_sensitivity <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
print.rmbl_bounds <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_buffer <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_burden <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_burden_area <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_capenv <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_case_flow <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_census_cwb <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_census_profile <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_change_bounds <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_citation <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_clearance_decomposition <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_co2eqv <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_co2int <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_cohort_trends <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_community_index <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_connection <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_count_trend <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_cramerv <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_crf <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_cumrisk <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_cwb_scores <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_datummap <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_density <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_did <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_disposition_mix <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_distinctions <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_dml <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_drftchisq <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_drfthomog <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_drftks <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_drftpsi <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_drift_calibration <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_dsr <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname dstfit
#' @export
print.rmbl_dstfit <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_dual_continuum <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_ebrates <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_equity <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_event_study <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_expected <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_exposure_trend <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_fe_poisson <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
print.rmbl_fetch <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_field <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_footprint <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_framing <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_gini <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_hawkes_fit <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_healing_change <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_holistic_balance <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_hotspot <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_indigenous_gap <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_knox <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname ldgrread
#' @export
print.rmbl_ledger <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_life_table <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_limits <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_loo <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_ltrlrng <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_manifest <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_map_compare <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_map_integrity <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
print.rmbl_margin_check <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_matched_did <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname mnfdiff
#' @export
#' @method print rmbl_mnfdiff
print.rmbl_mnfdiff <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_moran <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_optcrc <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_opteffort <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
print.rmbl_or_check <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_ordinal_compare <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_particles <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_perdays <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_permutation <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_pipeline_rate <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_plr <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_plr_boot <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_pollution_report <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_power <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_prevalence <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_profile_share <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_provenance <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_rate <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_rate_change <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_rate_gap <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
print.rmbl_recode_manifest_check <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_search_plan <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_sensitivity <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_severity <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_share <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_sir <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_spread <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_srchpod <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_srchscs <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_staggered_att <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_statcan <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_stay_summary <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_step_change <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_stock_flow <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @noRd
#' @export
print.rmbl_svy_colspec <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_svy_design <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_switching_did <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_synth <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_synthdid <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_tail_index <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_top_share <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @rdname printmeth
#' @export
print.rmbl_transfer_check <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_trc_gaps <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_trc_progress <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_trend_test <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_wayback_save <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_wellness_continuum <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_wellness_profile <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_wild <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.rmbl_yoy_summary <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}
