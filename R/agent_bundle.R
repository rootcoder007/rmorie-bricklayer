# SPDX-License-Identifier: AGPL-3.0-or-later

#' Agent-assisted reproducibility-bundle help
#'
#' Forwards a bundle-building request to the \code{rmorie} command-line agent
#' (optional binary from rmorie-cli), with a rmoriebricklayer-focused
#' preamble. The agent can run R and read/write files to help assemble or
#' repair a brick-proof bundle. See \code{rmorie::agent} for requirements.
#'
#' @param request Character scalar describing the bundle task.
#' @param model Optional model id (see \code{rmorie::agent}).
#' @param backend Optional backend override (see \code{rmorie::agent}).
#' @return Character scalar: the agent's output, or a message if the
#'   \code{rmorie} binary is not installed.
#' @examples
#' \donttest{
#' # Routed to the optional rmorie CLI agent when it is installed; with no
#' # binary on PATH each call returns an install hint instantly (no error,
#' # no network), so this is safe to execute anywhere.
#' agent_bundle("scaffold a bundle for analysis.R using the Toronto CKAN dataset")
#'
#' # Pin a model, or force a backend (see rmorie::agent for the values).
#' agent_bundle("repair the SHA256 provenance for my capsule",
#'              model = "gpt-4o-mini")
#' agent_bundle("add a Wayback fallback to my fetch step", backend = "ollama")
#' }
#'
#' # With no rmorie binary on PATH the call returns an install hint, not an
#' # error -- safe to run anywhere:
#' if (!nzchar(Sys.which("rmorie"))) agent_bundle("hello")
#' @export
agent_bundle <- function(request, model = NULL, backend = "auto") {
  stopifnot(is.character(request), length(request) == 1L, nzchar(request))
  bin <- Sys.which("rmorie")
  if (!nzchar(bin)) {
    return("rmorie CLI not found on PATH. Install rmorie-cli to use agent_bundle().")
  }
  # nocov start -- forwards to the optional AGPL-licensed rmorie-cli binary
  preamble <- paste0(
    "You are helping build a brick-proof, reproducible data bundle with ",
    "rmoriebricklayer (cross-platform launchers, CKAN resolution, SHA256 + ",
    "Wayback provenance, synthetic fallback). Request: ", request)
  args <- c("agent", "--backend", backend)
  if (!is.null(model)) args <- c(args, "-m", model)
  args <- c(args, preamble)
  paste(suppressWarnings(
    system2(bin, args = args, stdout = TRUE, stderr = TRUE)), collapse = "\n")
  # nocov end
}
