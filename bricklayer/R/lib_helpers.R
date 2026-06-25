# SPDX-License-Identifier: AGPL-3.0-or-later
## lib_helpers.R -- SHA256 file-digest helper (package API).

## ----------------- SHA256 (uses digest pkg) -----------------

#' Compute a File's SHA256 Digest
#'
#' Returns the SHA256 digest of a file as a lowercase hex string, using
#' the digest package. Used to record and verify data provenance.
#'
#' @param path Path to the file to hash.
#' @return The SHA256 digest as a character string.
#' @export
sha256_file <- function(path) {
  if (!requireNamespace("digest", quietly = TRUE))
    stop("The 'digest' package is required for SHA256 verification.")
  digest::digest(file = path, algo = "sha256")
}
