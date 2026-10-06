# The language-model tests exercise one route at a time with canned replies.
# A real Ollama server on the machine running the tests would answer first and
# turn them into live calls, so unless a test sets it, the local route is off.
if (!nzchar(Sys.getenv("OLLAMA_HOST", unset = ""))) Sys.setenv(OLLAMA_HOST = "off")
