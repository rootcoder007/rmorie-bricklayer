# Test seams: they reach the package's internals to force a native backend or reset a memo, so
# they live with the tests, not in the package.
.seam_ns <- asNamespace("rmoriebricklayer")

# The overflow fallback of cmn(): a running mean that cannot overflow on finite input. cmn()
# reaches it only where long double is 64-bit, so it is called directly to be tested everywhere.
.core_mean_running <- function(x) .Call(.seam_ns$C_rmbl_mean_running, as.numeric(x))

# The AES backend in use, "aesni" or "portable": portable = TRUE forces the portable cipher, FALSE
# restores the hardware path, NA leaves it (the tests run the vectors through both).
.rmbl_aes_backend <- function(portable = NA) .Call(.seam_ns$C_rmbl_aes_backend, as.logical(portable))

# The carry-less multiplier the HQC products use, "pclmul", "pmull" or "portable": portable = TRUE
# forces the portable one, FALSE restores the hardware path, NA leaves it.
.rmbl_hqc_backend <- function(portable = NA) .Call(.seam_ns$C_rmbl_hqc_backend, as.logical(portable))

# Clears the in-session memo of the services document.
.rmbl_services_forget <- function() {
  memo <- .seam_ns$.rmbl_services_memo
  rm(list = ls(memo, all.names = TRUE), envir = memo)
  invisible(NULL)
}
