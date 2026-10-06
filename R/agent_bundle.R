# SPDX-License-Identifier: AGPL-3.0-or-later

#' Agent-assisted reproducibility-bundle help
#'
#' Sends a bundle-building request, with a rmoriebricklayer-focused
#' preamble, to the hosted MORIE language model at
#' \url{https://llm.rmorie.com} with the key stored by
#' \code{\link{bricklayer_llm_login}} (\code{rmbl login} from the shell).
#'
#' @param request Character scalar describing the bundle task.
#' @param model Optional model id, e.g. \code{"minimax-m3:cloud"};
#'   \code{NULL} uses the default (\code{rmbl models} lists them).
#' @param backend \code{"auto"} (default) or \code{"hosted"}: both send the
#'   request to the hosted MORIE tier.
#' @return Character scalar: the answer, or a message saying what to set
#'   up when no key is stored.
#' @examples
#' \donttest{
#' agent_bundle("scaffold a bundle for analysis.R from the Toronto CKAN data")
#' agent_bundle("add a Wayback fallback to my fetch step", model = "minimax-m3:cloud")
#' }
#'
#' # With the hosted tier switched off the call returns a setup hint, not
#' # an error, and reaches no network -- safe to run anywhere:
#' old <- Sys.getenv("MORIE_HOSTED_BASE_URL", unset = NA)
#' Sys.setenv(MORIE_HOSTED_BASE_URL = "off")
#' agent_bundle("hello")
#' if (is.na(old)) Sys.unsetenv("MORIE_HOSTED_BASE_URL") else
#'   Sys.setenv(MORIE_HOSTED_BASE_URL = old)
#' @export
agent_bundle <- function(request, model = NULL, backend = "auto") {
  request <- .rmbl_string1(request, "request")
  backend <- match.arg(backend, c("auto", "hosted"))
  preamble <- paste0(
    "You are helping build a brick-proof, reproducible data bundle with the R package ",
    "rmoriebricklayer. Use only its functions: resolve_via_ckan(), resolve_via_ckan_search(), ",
    "resolve_via_arcgis() and resolve_via_socrata() find a portal's download URL; ",
    "bricklayer_fetch() and friendly_download() download with a Wayback Machine fallback ",
    "(wayback_snapshot_url()); sha256_file() and make_manifest() / write_manifest_json() record ",
    "provenance; make_synthetic_csv() writes a synthetic stand-in with the same columns; ",
    "capsule_bundle(), capsule_sign() and capsule_verify() package and check the bundle; ",
    "use_capsule_template() scaffolds one. Answer with a short plan and R code. Request: ", request)
  if (is.null(.bl_hosted_base()) || is.null(.bl_hosted_key())) {
    return(paste0(
      "No language-model route is set up: sign in to the hosted MORIE tier with ",
      "bricklayer_llm_login() or `rmbl login` (GitHub, an emailed code, or a key from https://llm.rmorie.com)."))
  }
  bricklayer_llm_ask(preamble, model = model)
}
