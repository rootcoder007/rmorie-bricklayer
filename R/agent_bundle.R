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
#' # With no key stored the call returns a setup hint, not an
#' # error -- safe to run anywhere:
#' if (!nzchar(Sys.getenv("MORIE_HOSTED_KEY"))) agent_bundle("hello")
#' @export
agent_bundle <- function(request, model = NULL, backend = "auto") {
  request <- .rmbl_string1(request, "request")
  backend <- match.arg(backend, c("auto", "hosted"))
  preamble <- paste0(
    "You are helping build a brick-proof, reproducible data bundle with ",
    "rmoriebricklayer (cross-platform launchers, CKAN resolution, SHA256 + ",
    "Wayback provenance, synthetic fallback). Request: ", request)
  if (is.null(.bl_hosted_base()) || is.null(.bl_hosted_key())) {
    return(paste0(
      "No language-model route is set up: sign in to the hosted MORIE tier with ",
      "bricklayer_llm_login() or `rmbl login` (GitHub, an emailed code, or a key from https://llm.rmorie.com)."))
  }
  bricklayer_llm_ask(preamble, model = model)
}
