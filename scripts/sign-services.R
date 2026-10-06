#!/usr/bin/env Rscript
# Sign inst/services/morie-services.json with the MORIE services key.
#
#   Rscript scripts/sign-services.R [path/to/morie-services.json]
#
# The secret key is read from $MORIE_SERVICES_KEY (default
# ~/secrets-backup/morie-services-signing-mldsa44.json, never in the repo).
# The signature is deterministic (FIPS 204 variant), so re-signing unchanged
# bytes gives the same .sig and a diff shows exactly what changed. The same
# pair is what gets uploaded to https://rmorie.com/.well-known/.
suppressPackageStartupMessages(library(rmoriebricklayer))
args <- commandArgs(trailingOnly = TRUE)
doc <- if (length(args)) args[[1]] else "inst/services/morie-services.json"
keyfile <- Sys.getenv("MORIE_SERVICES_KEY",
                      path.expand("~/secrets-backup/morie-services-signing-mldsa44.json"))
stopifnot(file.exists(doc), file.exists(keyfile))
k <- bricklayer_json_from_json(paste(readLines(keyfile, warn = FALSE), collapse = "\n"),
                               simplifyVector = TRUE)
stopifnot(identical(k$scheme, "ML-DSA-44"))
key <- fips_key("ML-DSA-44", k$public, k$secret)
bytes <- readBin(doc, "raw", file.size(doc))
# the document must parse as what the packages accept before it is signed
parsed <- rmoriebricklayer:::.rmbl_services_parse(bytes)
if (is.null(parsed)) stop("not a valid v1 services document: ", doc)
pinned <- rmoriebricklayer:::.rmbl_services_pubkey()
if (!identical(tolower(k$public), tolower(pinned))) {
  stop("this key is not the one pinned in R/services.R; a key rotation is a package release")
}
sig <- capsule_sign(bytes, key, context = "morie-services", deterministic = TRUE)
out <- sprintf('{"scheme":"ML-DSA-44","context":"morie-services","signature":"%s"}\n', sig$signature)
sigfile <- sub("[.]json$", ".sig", doc)
cat(out, file = sigfile)
ok <- rmoriebricklayer:::.rmbl_services_verify(bytes, out)
stopifnot(isTRUE(ok))
cat(sprintf("signed %s (issued %s) -> %s\n", doc, parsed$issued, sigfile))
