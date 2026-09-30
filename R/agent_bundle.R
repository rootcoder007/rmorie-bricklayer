# SPDX-License-Identifier: AGPL-3.0-or-later

#' Agent-assisted reproducibility-bundle help
#'
#' Sends a bundle-building request, with a rmoriebricklayer-focused
#' preamble, to a language model. Routes, in order: the \code{rmorie}
#' package when installed (\code{rmorie::morie_llm_ask()}: a local Ollama
#' first, then the hosted MORIE tier at \url{https://llm.rmorie.com},
#' then any Gemini or OpenAI-compatible key, then a keyword fallback);
#' otherwise the hosted tier directly through this package's own HTTP
#' layer when a key is stored (\code{\link{bricklayer_llm_login}});
#' otherwise the optional \code{rmorie} command-line agent from
#' rmorie-cli if it is on the PATH.
#'
#' @param request Character scalar describing the bundle task.
#' @param model Optional model id, e.g. \code{"minimax-m3:cloud"} for the
#'   Ollama or hosted route, \code{"claude-sonnet-5"} for the Anthropic
#'   route of the CLI agent; \code{NULL} lets the route pick.
#' @param backend \code{"auto"} (default, the order above),
#'   \code{"rmorie"} (only the package route), \code{"hosted"} (only the
#'   native hosted route), \code{"ollama"} or \code{"anthropic"} (only
#'   the CLI agent, with its \code{$RMORIE_AGENT_OLLAMA_URL} /
#'   \code{$RMORIE_AGENT_API_KEY}).
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
#' if (!requireNamespace("rmorie", quietly = TRUE) &&
#'     !nzchar(Sys.getenv("MORIE_HOSTED_KEY"))) {
#'   agent_bundle("hello")
#' }
#' @export
agent_bundle <- function(request, model = NULL, backend = "auto") {
  stopifnot(is.character(request), length(request) == 1L, nzchar(request))
  backend <- match.arg(backend,
                       c("auto", "rmorie", "hosted", "ollama", "anthropic"))
  preamble <- paste0(
    "You are helping build a brick-proof, reproducible data bundle with ",
    "rmoriebricklayer (cross-platform launchers, CKAN resolution, SHA256 + ",
    "Wayback provenance, synthetic fallback). Request: ", request)
  if (backend %in% c("auto", "rmorie") && .bl_has_rmorie()) {
    ans <- .rmorie_ask(preamble, model)
    if (!is.null(ans)) return(ans)
  }
  if (identical(backend, "rmorie")) {
    return(paste0(
      "The rmorie package is not installed: install.packages(\"rmorie\", ",
      "repos = c(\"https://rootcoder007.r-universe.dev\", ",
      "\"https://cloud.r-project.org\")) and sign in with ",
      "rmorie::morie_llm_login()."))
  }
  if (backend %in% c("auto", "hosted") && !is.null(.bl_hosted_base()) &&
      !is.null(.bl_hosted_key())) {
    ans <- tryCatch(.bl_hosted_ask(preamble, model = model),
                    error = function(e) NULL)
    if (!is.null(ans)) return(ans)
  }
  if (identical(backend, "hosted")) {
    return(paste0(
      "No key for the hosted MORIE LLM tier: bricklayer_llm_login(token = ) ",
      "with a key from https://llm.rmorie.com, or `rmoriebricklayer login`."))
  }
  bin <- .rmorie_cli_binary()
  if (!nzchar(bin)) {
    return(paste0(
      "No language-model route is set up. Sign in to the hosted MORIE tier ",
      "with bricklayer_llm_login() (key from https://llm.rmorie.com), ",
      "install the rmorie package for the full provider chain, or put the ",
      "rmorie-cli agent on the PATH."))
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

# The rmorie route, in one small helper so tests can stand in for it
# without a network or an installed rmorie.
.rmorie_ask <- function(prompt, model = NULL) {
  ans <- tryCatch(rmorie::morie_llm_ask(prompt, model = model),
                  error = function(e) NULL)
  if (is.null(ans)) return(NULL)
  paste(as.character(ans), collapse = "\n")
}

# The `rmorie` launcher that rmorie::install_cli() puts on the PATH runs the
# package's morie_cli(), which has no `agent` verb; only the rmorie-cli
# binary does. Tell them apart by looking for morie_cli in the launcher.
.rmorie_cli_binary <- function() {
  bin <- Sys.which("rmorie")
  if (!nzchar(bin)) return("")
  head <- tryCatch(suppressWarnings(readLines(bin, n = 6L, warn = FALSE)),
                   error = function(e) character())
  if (any(grepl("morie_cli", head, fixed = TRUE))) return("")
  bin
}
