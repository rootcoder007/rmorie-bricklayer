# The print() methods whose box comes wholly from their format() method.
# Each is the same two lines, so they live together here rather than
# repeated beside every format() method; format() stays with its result.
# The shared method is defined first, in this file, so that the file
# stands on its own wherever it is sourced.

#' Prints a result's box, as its format() method builds it.
#' @param x The result.
#' @param ... Passed on to the result's format() method.
#' @return `x`, invisibly.
#' @noRd
.rmbl_print_box <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
print.bricklayer_analysis <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_attestation_check
print.bricklayer_attestation_check <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_benford
print.bricklayer_benford <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_bundle_check
print.bricklayer_bundle_check <- .rmbl_print_box

#' @export
#' @method print bricklayer_capsule_check
print.bricklayer_capsule_check <- .rmbl_print_box

#' @export
print.bricklayer_category_audit <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_certificate
print.bricklayer_certificate <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_certpath_check
print.bricklayer_certpath_check <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_chain
print.bricklayer_chain <- .rmbl_print_box

#' @export
print.bricklayer_chain_check <- .rmbl_print_box

#' @export
print.bricklayer_cortable <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_drbg
print.bricklayer_drbg <- .rmbl_print_box

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
print.bricklayer_drift <- .rmbl_print_box

#' @export
print.bricklayer_drift_summary <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_env_diff
print.bricklayer_env_diff <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_falsification
print.bricklayer_falsification <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_falsify_family
print.bricklayer_falsify_family <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_fips_key
print.bricklayer_fips_key <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_fips_public_key
print.bricklayer_fips_public_key <- .rmbl_print_box

#' @export
print.bricklayer_freq <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_hqc_capsule
print.bricklayer_hqc_capsule <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_hqc_key
print.bricklayer_hqc_key <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_hqc_public_key
print.bricklayer_hqc_public_key <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_kem_capsule
print.bricklayer_kem_capsule <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_kem_key
print.bricklayer_kem_key <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_kem_public_key
print.bricklayer_kem_public_key <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_mcar
print.bricklayer_mcar <- .rmbl_print_box

#' @export
print.bricklayer_online <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_oqs_key
print.bricklayer_oqs_key <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_oqs_public_key
print.bricklayer_oqs_public_key <- .rmbl_print_box

#' @export
print.bricklayer_outliers <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_power
print.bricklayer_power <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_prereg
print.bricklayer_prereg <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_prereg_check
print.bricklayer_prereg_check <- .rmbl_print_box

#' @export
print.bricklayer_profile <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_public_key
print.bricklayer_public_key <- .rmbl_print_box

#' @rdname printmeth
#' @export
print.bricklayer_recode_manifest <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_recompute
print.bricklayer_recompute <- .rmbl_print_box

#' @export
print.bricklayer_relabel_forensics <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_report
print.bricklayer_report <- .rmbl_print_box

#' @export
print.bricklayer_rule <- .rmbl_print_box

#' @export
print.bricklayer_runs <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_schema
print.bricklayer_schema <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_signature
print.bricklayer_signature <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_signing_key
print.bricklayer_signing_key <- .rmbl_print_box

#' @rdname printmeth
#' @export
#' @method print bricklayer_timestamp
print.bricklayer_timestamp <- .rmbl_print_box

#' @export
print.rmbl_admits <- .rmbl_print_box

#' @export
print.rmbl_adp <- .rmbl_print_box

#' @export
print.rmbl_adpcnts <- .rmbl_print_box

#' @export
print.rmbl_aipw <- .rmbl_print_box

#' @export
print.rmbl_alos <- .rmbl_print_box

#' @export
print.rmbl_archive_capture <- .rmbl_print_box

#' @export
print.rmbl_archive_find <- .rmbl_print_box

#' @export
print.rmbl_attrfrac <- .rmbl_print_box

#' @export
print.rmbl_bacon <- .rmbl_print_box

#' @export
print.rmbl_balance <- .rmbl_print_box

#' @rdname bandsens
#' @export
print.rmbl_band_sensitivity <- .rmbl_print_box

#' @rdname printmeth
#' @export
print.rmbl_bounds <- .rmbl_print_box

#' @export
print.rmbl_buffer <- .rmbl_print_box

#' @export
print.rmbl_burden <- .rmbl_print_box

#' @export
print.rmbl_burden_area <- .rmbl_print_box

#' @export
print.rmbl_capenv <- .rmbl_print_box

#' @export
print.rmbl_case_flow <- .rmbl_print_box

#' @export
print.rmbl_census_cwb <- .rmbl_print_box

#' @export
print.rmbl_census_profile <- .rmbl_print_box

#' @export
print.rmbl_change_bounds <- .rmbl_print_box

#' @export
print.rmbl_citation <- .rmbl_print_box

#' @export
print.rmbl_clearance_decomposition <- .rmbl_print_box

#' @export
print.rmbl_co2eqv <- .rmbl_print_box

#' @export
print.rmbl_co2int <- .rmbl_print_box

#' @export
print.rmbl_cohort_trends <- .rmbl_print_box

#' @export
print.rmbl_community_index <- .rmbl_print_box

#' @export
print.rmbl_connection <- .rmbl_print_box

#' @export
print.rmbl_count_trend <- .rmbl_print_box

#' @export
print.rmbl_cramerv <- .rmbl_print_box

#' @export
print.rmbl_crf <- .rmbl_print_box

#' @export
print.rmbl_cumrisk <- .rmbl_print_box

#' @export
print.rmbl_cwb_scores <- .rmbl_print_box

#' @export
print.rmbl_datummap <- .rmbl_print_box

#' @export
print.rmbl_density <- .rmbl_print_box

#' @export
print.rmbl_did <- .rmbl_print_box

#' @export
print.rmbl_disposition_mix <- .rmbl_print_box

#' @export
print.rmbl_distinctions <- .rmbl_print_box

#' @export
print.rmbl_dml <- .rmbl_print_box

#' @export
print.rmbl_drftchisq <- .rmbl_print_box

#' @export
print.rmbl_drfthomog <- .rmbl_print_box

#' @export
print.rmbl_drftks <- .rmbl_print_box

#' @export
print.rmbl_drftpsi <- .rmbl_print_box

#' @export
print.rmbl_drift_calibration <- .rmbl_print_box

#' @export
print.rmbl_dsr <- .rmbl_print_box

#' @rdname dstfit
#' @export
print.rmbl_dstfit <- .rmbl_print_box

#' @export
print.rmbl_dual_continuum <- .rmbl_print_box

#' @export
print.rmbl_ebrates <- .rmbl_print_box

#' @export
print.rmbl_equity <- .rmbl_print_box

#' @export
print.rmbl_event_study <- .rmbl_print_box

#' @export
print.rmbl_expected <- .rmbl_print_box

#' @export
print.rmbl_exposure_trend <- .rmbl_print_box

#' @export
print.rmbl_fe_poisson <- .rmbl_print_box

#' @rdname printmeth
#' @export
print.rmbl_fetch <- .rmbl_print_box

#' @export
print.rmbl_field <- .rmbl_print_box

#' @export
print.rmbl_footprint <- .rmbl_print_box

#' @export
print.rmbl_framing <- .rmbl_print_box

#' @export
print.rmbl_gini <- .rmbl_print_box

#' @export
print.rmbl_hawkes_fit <- .rmbl_print_box

#' @export
print.rmbl_healing_change <- .rmbl_print_box

#' @export
print.rmbl_holistic_balance <- .rmbl_print_box

#' @export
print.rmbl_hotspot <- .rmbl_print_box

#' @export
print.rmbl_indigenous_gap <- .rmbl_print_box

#' @export
print.rmbl_knox <- .rmbl_print_box

#' @rdname ldgrread
#' @export
print.rmbl_ledger <- .rmbl_print_box

#' @export
print.rmbl_life_table <- .rmbl_print_box

#' @export
print.rmbl_limits <- .rmbl_print_box

#' @export
print.rmbl_loo <- .rmbl_print_box

#' @export
print.rmbl_ltrlrng <- .rmbl_print_box

#' @export
print.rmbl_manifest <- .rmbl_print_box

#' @export
print.rmbl_map_compare <- .rmbl_print_box

#' @export
print.rmbl_map_integrity <- .rmbl_print_box

#' @rdname printmeth
#' @export
print.rmbl_margin_check <- .rmbl_print_box

#' @export
print.rmbl_matched_did <- .rmbl_print_box

#' @rdname mnfdiff
#' @export
#' @method print rmbl_mnfdiff
print.rmbl_mnfdiff <- .rmbl_print_box

#' @export
print.rmbl_moran <- .rmbl_print_box

#' @export
print.rmbl_optcrc <- .rmbl_print_box

#' @export
print.rmbl_opteffort <- .rmbl_print_box

#' @rdname printmeth
#' @export
print.rmbl_or_check <- .rmbl_print_box

#' @export
print.rmbl_ordinal_compare <- .rmbl_print_box

#' @export
print.rmbl_particles <- .rmbl_print_box

#' @export
print.rmbl_perdays <- .rmbl_print_box

#' @export
print.rmbl_permutation <- .rmbl_print_box

#' @export
print.rmbl_pipeline_rate <- .rmbl_print_box

#' @export
print.rmbl_plr <- .rmbl_print_box

#' @export
print.rmbl_plr_boot <- .rmbl_print_box

#' @export
print.rmbl_pollution_report <- .rmbl_print_box

#' @export
print.rmbl_power <- .rmbl_print_box

#' @export
print.rmbl_prevalence <- .rmbl_print_box

#' @export
print.rmbl_profile_share <- .rmbl_print_box

#' @export
print.rmbl_provenance <- .rmbl_print_box

#' @export
print.rmbl_rate <- .rmbl_print_box

#' @export
print.rmbl_rate_change <- .rmbl_print_box

#' @export
print.rmbl_rate_gap <- .rmbl_print_box

#' @rdname printmeth
#' @export
print.rmbl_recode_manifest_check <- .rmbl_print_box

#' @export
print.rmbl_search_plan <- .rmbl_print_box

#' @export
print.rmbl_sensitivity <- .rmbl_print_box

#' @export
print.rmbl_severity <- .rmbl_print_box

#' @export
print.rmbl_share <- .rmbl_print_box

#' @export
print.rmbl_sir <- .rmbl_print_box

#' @export
print.rmbl_spread <- .rmbl_print_box

#' @export
print.rmbl_srchpod <- .rmbl_print_box

#' @export
print.rmbl_srchscs <- .rmbl_print_box

#' @export
print.rmbl_staggered_att <- .rmbl_print_box

#' @export
print.rmbl_statcan <- .rmbl_print_box

#' @export
print.rmbl_stay_summary <- .rmbl_print_box

#' @export
print.rmbl_step_change <- .rmbl_print_box

#' @export
print.rmbl_stock_flow <- .rmbl_print_box

#' @noRd
#' @export
print.rmbl_svy_colspec <- .rmbl_print_box

#' @export
print.rmbl_svy_design <- .rmbl_print_box

#' @export
print.rmbl_switching_did <- .rmbl_print_box

#' @export
print.rmbl_synth <- .rmbl_print_box

#' @export
print.rmbl_synthdid <- .rmbl_print_box

#' @export
print.rmbl_tail_index <- .rmbl_print_box

#' @export
print.rmbl_top_share <- .rmbl_print_box

#' @rdname printmeth
#' @export
print.rmbl_transfer_check <- .rmbl_print_box

#' @export
print.rmbl_trc_gaps <- .rmbl_print_box

#' @export
print.rmbl_trc_progress <- .rmbl_print_box

#' @export
print.rmbl_trend_test <- .rmbl_print_box

#' @export
print.rmbl_wayback_save <- .rmbl_print_box

#' @export
print.rmbl_wellness_continuum <- .rmbl_print_box

#' @export
print.rmbl_wellness_profile <- .rmbl_print_box

#' @export
print.rmbl_wild <- .rmbl_print_box

#' @export
print.rmbl_yoy_summary <- .rmbl_print_box

#' @export
print.rmbl_bundle <- .rmbl_print_box

#' @export
print.rmbl_bundle_project <- .rmbl_print_box

#' @export
print.rmbl_alloc <- .rmbl_print_box

#' @export
print.rmbl_alloc_check <- .rmbl_print_box

#' @export
print.rmbl_xvrf <- .rmbl_print_box

#' @export
print.rmbl_plant <- .rmbl_print_box

#' @export
print.rmbl_spec <- .rmbl_print_box

#' @export
print.rmbl_fipsmod_key <- .rmbl_print_box

#' @export
print.rmbl_fipsmod <- .rmbl_print_box

#' @export
print.rmbl_bundle_audit <- .rmbl_print_box
