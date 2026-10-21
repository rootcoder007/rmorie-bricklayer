# SPDX-License-Identifier: AGPL-3.0-or-later

#' Agent-assisted reproducibility-bundle help
#'
#' Asks a language model to plan a brick-proof, reproducible data bundle,
#' through \code{\link{llmask}}: your own key, your own
#' endpoint or a local Ollama server, with the packages' help at hand (the
#' model reads the help pages of the functions it proposes before it
#' answers). Use it to get a first draft of the steps and R code for
#' packaging an analysis: finding the portal's download URL, fetching with a
#' Wayback fallback, recording hashes and a manifest, writing a synthetic
#' stand-in, then packaging, signing and verifying the bundle.
#'
#' @details
#' The request is sent with a fixed system prompt that describes that task
#' and asks for a short plan and R code. The route is chosen as in
#' [llmask()]; when no route is set up, the
#' function returns a
#' message saying what to set up (a provider key, a local Ollama or your own
#' endpoint) instead of an error, and makes no network request. When a
#' route is set up, the request and the prompt are sent to that provider or
#' server. The answer is model output: check the code it proposes against
#' the help pages before running it.
#'
#' Errors: \code{req} not a single non-empty string; \code{route} not one
#' of the names listed; \code{route = "hosted"} (the hosted tier is retired);
#' and errors raised by [llmask()].
#'
#' @param req Character scalar describing the bundle task.
#' @param model Optional model id, a string; \code{NULL} uses the route's model
#'   (\code{rmbl models} lists them).
#' @param route \code{NULL} (the saved route, else the first that is set
#'   up), \code{"auto"}, \code{"own"}, \code{"ollama"} or a provider id such as
#'   \code{"anthropic"} or \code{"openai"}.
#' @return Character scalar: the answer, or a message saying what to set
#'   up when no route answers.
#' @examplesIf interactive()
#' # Needs a language model: a provider key (e.g. ANTHROPIC_API_KEY), your own
#' # endpoint or a local Ollama.
#' agentbndl("scaffold a bundle for analysis.R from the Toronto CKAN data")
#' agentbndl("sign and verify my capsule", route = "ollama")
#'
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#'
#' # With every route switched off (no key in the environment and no saved
#' # settings: the settings folder is pointed at an empty one) the call returns
#' # a setup hint, not an error, and reaches no network -- safe to run anywhere:
#' keys <- c("OLLAMA_HOST", "MORIE_LLM_BASE_URL", "XDG_CONFIG_HOME",
#'           llmprvd()$key_env,
#'           llmprvd()$alt_env[nzchar(llmprvd()$alt_env)])
#' old <- Sys.getenv(keys, unset = NA)
#' Sys.setenv(OLLAMA_HOST = "off", MORIE_LLM_BASE_URL = "off", XDG_CONFIG_HOME = tempfile())
#' Sys.unsetenv(setdiff(keys, c("OLLAMA_HOST", "MORIE_LLM_BASE_URL", "XDG_CONFIG_HOME")))
#' cat(agentbndl("hello"))
#' for (v in keys) {
#'   if (is.na(old[[v]])) Sys.unsetenv(v) else do.call(Sys.setenv, as.list(old[v]))
#' }
#'
#' # argument errors come first
#' try(agentbndl(""))
#' try(agentbndl("plan a bundle", route = "hosted"))
#' @export
agentbndl <- function(req, model = NULL, route = NULL) {
  req <- .rmbl_string1(req, "req")
  model <- .bl_model_name(model)
  if (identical(route, "hosted")) stop(.bl_hosted_retired(), call. = FALSE)
  if (!is.null(route)) route <- .rmbl_arg(route, c("auto", .bl_llm_route_names()))
  if (is.null(.bl_llm_route(route))) return(.bl_no_route_message(route))
  extra <- paste("The task is a brick-proof, reproducible data bundle: find a portal's download URL, fetch",
                 "with a Wayback fallback, record provenance (hashes, a manifest), write a synthetic stand-in,",
                 "then package, sign and verify the bundle. Answer with a short plan and R code.")
  llmask(req, model = model, route = route, syspro = extra)
}
