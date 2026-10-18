# The language-model tests exercise one route at a time with canned replies.
# A real Ollama server on the machine running the tests would answer first and
# turn them into live calls, so unless a test sets it, the local route is off.
# The developer's own OLLAMA_HOST, endpoint and keys are not kept either (a test prompt went to a
# developer's endpoint with their real key; review of 29a55d8, L4): RMBL_LIVE_LLM=1 keeps them for
# the live checks.
if (!identical(Sys.getenv("RMBL_LIVE_LLM"), "1")) {
  # nor the developer's saved keys: a fresh, empty config directory for the whole run (a test
  # POSTed a prompt to api.anthropic.com with a saved key; review of 46de6a9, H8)
  Sys.setenv(OLLAMA_HOST = "off", XDG_CONFIG_HOME = tempfile("rmbl-test-xdg-"))
  Sys.unsetenv(c("MORIE_HOSTED_KEY", "MORIE_HOSTED_BASE_URL", "MORIE_DATA_URL"))
  local({
    ps <- get(".bl_llm_presets", envir = asNamespace("rmoriebricklayer"))()
    Sys.unsetenv(c(ps$key_env, ps$alt_env[nzchar(ps$alt_env)], get(".bl_preset_model_env",
                 envir = asNamespace("rmoriebricklayer"))(ps$id),
                 "MORIE_LLM_ROUTE", "MORIE_LLM_BASE_URL", "MORIE_LLM_API_KEY", "MORIE_LLM_MODEL",
                 "OLLAMA_API_KEY", "OLLAMA_BASE_URL", "OLLAMA_MODEL"))
  })
}

# answers are kept on this machine only for a person watching (never in a check); the CLI tests turn
# morie.progress on, so the cache is off here unless a test turns it on
options(rmoriebricklayer.llmcache = FALSE)
