# The language-model tests exercise one route at a time with canned replies.
# A real Ollama server on the machine running the tests would answer first and
# turn them into live calls, so unless a test sets it, the local route is off.
if (!nzchar(Sys.getenv("OLLAMA_HOST", unset = ""))) Sys.setenv(OLLAMA_HOST = "off")
# Likewise a provider key in the environment of the machine running the tests would make that
# provider the route; the tests that want one set it themselves.
local({
  ps <- get(".bl_llm_presets", envir = asNamespace("rmoriebricklayer"))()
  Sys.unsetenv(c(ps$key_env, ps$alt_env[nzchar(ps$alt_env)], "MORIE_LLM_ROUTE"))
})

# answers are kept on this machine only for a person watching (never in a check); the CLI tests turn
# morie.progress on, so the cache is off here unless a test turns it on
options(rmoriebricklayer.llm_cache = FALSE)
