# SPDX-License-Identifier: AGPL-3.0-or-later

#' Agent-assisted reproducibility-bundle help
#'
#' Sends a bundle-building request, with a rmoriebricklayer-focused
#' preamble, to a language model: the hosted MORIE tier at
#' \url{https://llm.rmorie.com} when a key is stored
#' (\code{\link{bricklayer_llm_login}}), otherwise the optional
#' \code{rmorie} command-line agent from rmorie-cli if it is on the PATH.
#'
#' @param request Character scalar describing the bundle task.
#' @param model Optional model id, e.g. \code{"minimax-m3:cloud"} for the
#'   hosted tier, \code{"claude-sonnet-5"} for the Anthropic route of the
#'   CLI agent; \code{NULL} lets the route pick.
#' @param backend \code{"auto"} (default: hosted tier, then the CLI
#'   agent), \code{"hosted"} (only the hosted tier), \code{"ollama"} or
#'   \code{"anthropic"} (only the CLI agent, with its
#'   \code{$RMORIE_AGENT_OLLAMA_URL} / \code{$RMORIE_AGENT_API_KEY}).
#' @return Character scalar: the answer, or a message saying what to set
#'   up when no route is available.
#' @examples
#' \donttest{
#' agent_bundle("scaffold a bundle for analysis.R from the Toronto CKAN data")
#' agent_bundle("add a Wayback fallback to my fetch step", backend = "hosted")
#' agent_bundle("repair the SHA256 provenance for my capsule",
#'              backend = "anthropic", model = "claude-sonnet-5")
#' }
#'
#' # With no route configured the call returns a setup hint, not an
#' # error -- safe to run anywhere:
#' if (!nzchar(Sys.getenv("MORIE_HOSTED_KEY"))) agent_bundle("hello")
#' @export
agent_bundle <- function(request, model = NULL, backend = "auto") {
  stopifnot(is.character(request), length(request) == 1L, nzchar(request))
  backend <- match.arg(backend, c("auto", "hosted", "ollama", "anthropic"))
  preamble <- paste0(
    "You are helping build a brick-proof, reproducible data bundle with ",
    "rmoriebricklayer (cross-platform launchers, CKAN resolution, SHA256 + ",
    "Wayback provenance, synthetic fallback). Request: ", request)
  if (backend %in% c("auto", "hosted") && !is.null(.bl_hosted_base()) &&
      !is.null(.bl_hosted_key())) {
    ans <- tryCatch(bricklayer_llm_ask(preamble, model = model),
                    error = function(e) NULL)
    if (!is.null(ans)) return(ans)
  }
  if (identical(backend, "hosted")) {
    return(paste0(
      "No key for the hosted MORIE LLM tier: bricklayer_llm_login() ",
      "(GitHub, an emailed code, or a key from https://llm.rmorie.com), ",
      "or `rmoriebricklayer login` from the shell."))
  }
  bin <- .rmorie_cli_binary()
  if (!nzchar(bin)) {
    return(paste0(
      "No language-model route is set up. Sign in to the hosted MORIE tier ",
      "with bricklayer_llm_login() or `rmbl login` (GitHub, an emailed code, or a key from https://llm.rmorie.com)."))
  }
  # nocov start -- forwards to the optional AGPL-licensed rmorie-cli binary
  # system2() hands `args` to a shell: quote every value, or the first
  # parenthesis in the request is a shell syntax error.
  args <- c("agent", "--backend", shQuote(backend))
  if (!is.null(model)) args <- c(args, "-m", shQuote(model))
  args <- c(args, shQuote(preamble))
  paste(suppressWarnings(
    system2(bin, args = args, stdout = TRUE, stderr = TRUE)),
    collapse = "\n")
  # nocov end
}

# The `rmorie` command on a PATH may be the launcher that the rmorie R
# package installs, which has no `agent` verb; only the rmorie-cli binary
# does. Tell them apart by looking for morie_cli in the launcher text.
.rmorie_cli_binary <- function() {
  bin <- Sys.which("rmorie")
  if (!nzchar(bin)) return("")
  head <- tryCatch(suppressWarnings(readLines(bin, n = 6L, warn = FALSE)),
                   error = function(e) character())
  if (any(grepl("morie_cli", head, fixed = TRUE))) return("")
  bin
}
