# SPDX-License-Identifier: AGPL-3.0-or-later

#' Agent-assisted reproducibility-bundle help
#'
#' Asks a language model to plan a brick-proof, reproducible data bundle,
#' through \code{\link{bricklayer_llm_ask}}: your own key, your own
#' endpoint or a local Ollama server, with the packages' help at hand (the
#' model reads the help pages of the functions it proposes before it
#' answers).
#'
#' @param request Character scalar describing the bundle task.
#' @param model Optional model id; \code{NULL} uses the route's model
#'   (\code{rmbl models} lists them).
#' @param route \code{NULL} (the saved route, else the first that is set
#'   up), \code{"auto"}, \code{"own"}, \code{"ollama"} or a provider id.
#' @return Character scalar: the answer, or a message saying what to set
#'   up when no route answers.
#' @examples
#' \donttest{
#' # Needs a language model: a provider key (e.g. ANTHROPIC_API_KEY), your own
#' # endpoint or a local Ollama. try() keeps the example graceful when none answers.
#' try(agent_bundle("scaffold a bundle for analysis.R from the Toronto CKAN data"))
#' }
#'
#' # With every route switched off the call returns a setup hint, not an
#' # error, and reaches no network -- safe to run anywhere:
#' keys <- c("OLLAMA_HOST", "MORIE_LLM_BASE_URL", bricklayer_llm_providers()$key_env,
#'           bricklayer_llm_providers()$alt_env[nzchar(bricklayer_llm_providers()$alt_env)])
#' old <- Sys.getenv(keys, unset = NA)
#' Sys.setenv(OLLAMA_HOST = "off", MORIE_LLM_BASE_URL = "off")
#' Sys.unsetenv(setdiff(keys, c("OLLAMA_HOST", "MORIE_LLM_BASE_URL")))
#' agent_bundle("hello")
#' for (v in keys) {
#'   if (is.na(old[[v]])) Sys.unsetenv(v) else do.call(Sys.setenv, as.list(old[v]))
#' }
#' @export
agent_bundle <- function(request, model = NULL, route = NULL) {
  request <- .rmbl_string1(request, "request")
  if (identical(route, "hosted")) stop(.bl_hosted_retired(), call. = FALSE)
  if (!is.null(route)) route <- .rmbl_arg(route, c("auto", .bl_llm_route_names()))
  if (is.null(.bl_llm_route(route))) return(.bl_no_route_message(route))
  extra <- paste("The task is a brick-proof, reproducible data bundle: find a portal's download URL, fetch",
                 "with a Wayback fallback, record provenance (hashes, a manifest), write a synthetic stand-in,",
                 "then package, sign and verify the bundle. Answer with a short plan and R code.")
  bricklayer_llm_ask(request, model = model, route = route, system_prompt = extra)
}
