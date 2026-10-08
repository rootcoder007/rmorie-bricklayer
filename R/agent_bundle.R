# SPDX-License-Identifier: AGPL-3.0-or-later

#' Agent-assisted reproducibility-bundle help
#'
#' Sends a bundle-building request, with a rmoriebricklayer-focused
#' preamble, to the first language-model route that answers (your own
#' endpoint, a local Ollama server, then the hosted MORIE tier; see
#' \code{\link{bricklayer_llm_ask}}).
#'
#' @param request Character scalar describing the bundle task.
#' @param model Optional model id, e.g. \code{"minimax-m3:cloud"};
#'   \code{NULL} uses the default (\code{rmbl models} lists them).
#' @param backend \code{"auto"} (default): the first route that answers;
#'   \code{"hosted"}: the hosted MORIE tier only.
#' @return Character scalar: the answer, or a message saying what to set
#'   up when no route answers.
#' @examples
#' \donttest{
#' # Needs a language-model route: a stored key (bricklayer_llm_login()), your
#' # own endpoint or a local Ollama. try() keeps the example graceful when no
#' # route answers or the hosted tier is slow.
#' try(agent_bundle("scaffold a bundle for analysis.R from the Toronto CKAN data"))
#' try(agent_bundle("add a Wayback fallback to my fetch step", model = "minimax-m3:cloud"))
#' }
#'
#' # With every route switched off the call returns a setup hint, not an
#' # error, and reaches no network -- safe to run anywhere:
#' routes <- c("MORIE_HOSTED_BASE_URL", "OLLAMA_HOST", "MORIE_LLM_BASE_URL")
#' old <- Sys.getenv(routes, unset = NA)
#' Sys.setenv(MORIE_HOSTED_BASE_URL = "off", OLLAMA_HOST = "off",
#'            MORIE_LLM_BASE_URL = "off")
#' agent_bundle("hello")
#' for (v in routes) {
#'   if (is.na(old[[v]])) Sys.unsetenv(v) else do.call(Sys.setenv, as.list(old[v]))
#' }
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
  route <- if (identical(backend, "hosted")) "hosted" else NULL
  if (is.null(.bl_llm_route(route))) return(.bl_no_route_message(route))
  bricklayer_llm_ask(preamble, model = model, route = route)
}
