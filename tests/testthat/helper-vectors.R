# The C2SP Wycheproof and NIST ACVP vector runner, shared by the offline subset test
# (test-vectors-subset.R) and the full CI run (tools/vectors/run.R). Defines functions only.
# vec: a directory with wycheproof/*.json and acvp/<set>/{prompt,expectedResults}.json.
# Returns list(file = list(pass, fail, na = list(reason = n), failures = character())).
rmbl_run_vectors <- function(vec, per_group = NA_integer_, verbose = FALSE) {
  TOTAL <- list()
  tally <- function(file, status, why = NULL, id = NULL) {
    r <- TOTAL[[file]] %||% list(pass = 0L, fail = 0L, na = list(), failures = character())
    if (status == "pass") {
      r$pass <- r$pass + 1L
    } else if (status == "fail") {
      r$fail <- r$fail + 1L
      msg <- sprintf("%s tcId=%s %s", file, id %||% "?", why %||% "")
      r$failures <- c(r$failures, msg)
      if (verbose) cat("FAIL", msg, "\n")
    } else {
      r$na[[why]] <- (r$na[[why]] %||% 0L) + 1L
    }
    TOTAL[[file]] <<- r
  }
  ns <- asNamespace("rmoriebricklayer")
  C <- function(n) get(n, envir = ns)

  h <- function(x) {
    # absent, empty, or an empty array a JSON writer made of "": no bytes
    if (is.null(x) || !length(x) || is.list(x) || !nzchar(x)) {
      return(raw(0))
    }
    as.raw(strtoi(substring(x, seq(1, nchar(x), 2), seq(2, nchar(x), 2)), 16L))
  }
  hx <- function(r) toupper(paste(as.character(r), collapse = ""))
  eqhex <- function(r, x) identical(hx(r), toupper(x %||% ""))
  `%||%` <- function(a, b) if (is.null(a)) b else a
  ok <- function(expr) !inherits(tryCatch(expr, error = function(e) e), "error")
  readj <- function(path) {
    x <- bricklayer_json_from_json(paste(readLines(path, warn = FALSE), collapse = "\n"),
      simplifyVector = FALSE
    )
    if (is.null(x$testGroups)) for (el in x) if (is.list(el) && !is.null(el$testGroups)) {
      return(el)
    }
    x
  }
  take <- function(tests) if (is.na(per_group)) tests else utils::head(tests, per_group)

  check <- function(file, id, cond, why = "") tally(file, if (isTRUE(cond)) "pass" else "fail", why, id)

  KEM <- function(ps) as.integer(sub("ML-KEM-", "", ps))
  DSA <- function(ps) as.integer(sub("ML-DSA-", "", ps))
  PH <- c(
    "SHA2-224" = "sha224", "SHA2-256" = "sha256", "SHA2-384" = "sha384", "SHA2-512" = "sha512",
    "SHA2-512/224" = "sha512_224", "SHA2-512/256" = "sha512_256", "SHA3-224" = "sha3_224",
    "SHA3-256" = "sha3_256", "SHA3-384" = "sha3_384", "SHA3-512" = "sha3_512",
    "SHAKE-128" = "shake128", "SHAKE-256" = "shake256"
  )
  shake256 <- function(x, n) .Call(C("C_rmbl_shake"), 256L, x, as.integer(n))
  # an ML-DSA secret key starts rho (32 bytes), K (32 bytes), then tr (64 bytes)
  mldsa_tr_sk <- function(sk) sk[65:128]
  mldsa_mu <- function(tr, mprime) shake256(c(tr, mprime), 64L)

  # ---------------------------------------------------------------- Wycheproof
  wp <- file.path(vec, "wycheproof")
  for (f in sort(list.files(wp, pattern = "^mlkem_.*\\.json$", full.names = TRUE))) {
    d <- readj(f)
    fn <- basename(f)
    for (g in d$testGroups) {
      lv <- KEM(g$parameterSet)
      for (t in take(g$tests)) {
        valid <- identical(t$result, "valid")
        if (identical(g$type, "MLKEMKeyGen")) {
          kp <- tryCatch(.Call(C("C_rmbl_mlkem_keygen"), lv, h(t$seed)), error = function(e) NULL)
          check(fn, t$tcId, !is.null(kp) && eqhex(kp[[1]], t$ek) && eqhex(kp[[2]], t$dk), "keygen")
        } else if (identical(g$type, "MLKEMTest")) {
          r <- tryCatch(
            {
              kp <- .Call(C("C_rmbl_mlkem_keygen"), lv, h(t$seed))
              k <- .Call(C("C_rmbl_mlkem_decaps"), lv, kp[[2]], h(t$c))
              if (!identical(k, .Call(C("C_rmbl_mlkem_decaps_masked"), lv, kp[[2]], h(t$c)))) {
                stop("masked decapsulation disagrees")
              }
              list(ek = kp[[1]], K = k)
            },
            error = function(e) NULL
          )
          if (valid) {
            check(fn, t$tcId, !is.null(r) && eqhex(r$ek, t$ek) && eqhex(r$K, t$K), "keygen+decaps")
          } else {
            check(fn, t$tcId, is.null(r), "invalid input accepted")
          }
        } else if (identical(g$type, "MLKEMEncapsTest")) {
          r <- tryCatch(.Call(C("C_rmbl_mlkem_encaps"), lv, h(t$ek), h(t$m)), error = function(e) NULL)
          if (valid) {
            check(fn, t$tcId, !is.null(r) && eqhex(r$ciphertext, t$c) && eqhex(r$shared, t$K), "encaps")
          } else {
            check(fn, t$tcId, is.null(r), paste("invalid encapsulation key accepted:", t$comment %||% ""))
          }
        } else if (identical(g$type, "MLKEMDecapsValidationTest")) {
          r <- tryCatch(.Call(C("C_rmbl_mlkem_decaps"), lv, h(t$dk), h(t$c)), error = function(e) NULL)
          rm_ <- tryCatch(.Call(C("C_rmbl_mlkem_decaps_masked"), lv, h(t$dk), h(t$c)), error = function(e) NULL)
          if (!identical(r, rm_)) r <- "masked and plain decapsulation disagree"
          if (valid) {
            check(fn, t$tcId, !is.null(r) && eqhex(r, t$K), "decaps")
          } else {
            check(fn, t$tcId, is.null(r), paste("invalid decapsulation input accepted:", t$comment %||% ""))
          }
        } else {
          tally(fn, "na", paste("group type", g$type))
        }
      }
    }
  }
  for (f in sort(list.files(wp, pattern = "^mldsa_.*\\.json$", full.names = TRUE))) {
    d <- readj(f)
    fn <- basename(f)
    mode <- as.integer(sub("^mldsa_([0-9]+)_.*$", "\\1", fn))
    for (g in d$testGroups) {
      pk <- h(g$publicKey)
      sk <- NULL
      if (!is.null(g$privateSeed)) {
        sk <- tryCatch(.Call(C("C_rmbl_mldsa_keypair"), mode, h(g$privateSeed))[[2]],
          error = function(e) NULL
        )
      } else if (!is.null(g$privateKey)) {
        sk <- h(g$privateKey)
      }
      for (t in take(g$tests)) {
        valid <- identical(t$result, "valid")
        flags <- unlist(t$flags)
        if (identical(g$type, "MlDsaVerify")) {
          v <- tryCatch(.Call(C("C_rmbl_mldsa_verify"), mode, pk, h(t$msg), h(t$ctx), h(t$sig), "none"),
            error = function(e) FALSE
          )
          check(fn, t$tcId, identical(isTRUE(v), valid), paste("verify:", t$comment %||% ""))
        } else if (identical(g$type, "MlDsaSign")) {
          rnd <- raw(32)
          if ("Randomized" %in% flags) {
            tally(fn, "na", "randomized signing (hedged rnd not given)")
            next
          }
          sig <- tryCatch(
            {
              if (is.null(sk)) stop("no key")
              sgn <- function(masked) {
                if (!is.null(t$mu) && is.null(t$msg)) {
                  .Call(C("C_rmbl_mldsa_sign_mu"), mode, sk, h(t$mu), rnd, masked)
                } else if ("Internal" %in% flags) {
                  .Call(C("C_rmbl_mldsa_sign_mu"), mode, sk, h(t$mu), rnd, masked)
                } else {
                  .Call(C("C_rmbl_mldsa_sign"), mode, sk, h(t$msg), h(t$ctx), rnd, "none", masked)
                }
              }
              plain <- sgn(FALSE)
              if (!identical(plain, sgn(TRUE))) stop("masked signing disagrees")
              plain
            },
            error = function(e) NULL
          )
          if (valid) {
            check(fn, t$tcId, !is.null(sig) && eqhex(sig, t$sig), paste("sign:", t$comment %||% ""))
          } else {
            check(fn, t$tcId, is.null(sig), paste("invalid signing input accepted:", t$comment %||% ""))
          }
        } else {
          tally(fn, "na", paste("group type", g$type))
        }
      }
    }
  }

  # --------------------------------------------------------------------- ACVP
  ac <- file.path(vec, "acvp")
  acvp <- function(set) {
    p <- readj(file.path(ac, set, "prompt.json"))
    e <- readj(file.path(ac, set, "expectedResults.json"))
    exp <- list()
    for (g in e$testGroups) for (t in g$tests) exp[[as.character(t$tcId)]] <- t
    list(groups = p$testGroups, exp = exp)
  }
  run_set <- function(set, fun) {
    if (!dir.exists(file.path(ac, set))) {
      return(invisible())
    }
    a <- acvp(set)
    for (g in a$groups) for (t in take(g$tests)) fun(set, g, t, a$exp[[as.character(t$tcId)]])
  }

  run_set("ML-KEM-keyGen-FIPS203", function(s, g, t, e) {
    kp <- .Call(C("C_rmbl_mlkem_keygen"), KEM(g$parameterSet), c(h(t$d), h(t$z)))
    check(s, t$tcId, eqhex(kp[[1]], e$ek) && eqhex(kp[[2]], e$dk))
  })
  run_set("ML-KEM-encapDecap-FIPS203", function(s, g, t, e) {
    lv <- KEM(g$parameterSet)
    switch(g$`function`,
      encapsulation = {
        r <- .Call(C("C_rmbl_mlkem_encaps"), lv, h(t$ek), h(t$m))
        check(s, t$tcId, eqhex(r$ciphertext, e$c) && eqhex(r$shared, e$k), "encapsulation")
      },
      decapsulation = {
        k <- .Call(C("C_rmbl_mlkem_decaps"), lv, h(t$dk), h(t$c))
        km <- .Call(C("C_rmbl_mlkem_decaps_masked"), lv, h(t$dk), h(t$c))
        check(s, t$tcId, eqhex(k, e$k) && identical(k, km), "decapsulation (plain and masked)")
      },
      encapsulationKeyCheck = {
        acc <- ok(.Call(C("C_rmbl_mlkem_encaps"), lv, h(t$ek), raw(32)))
        check(s, t$tcId, identical(acc, isTRUE(e$testPassed)), "encapsulation key check (FIPS 203 7.2)")
      },
      decapsulationKeyCheck = {
        ct <- raw(.Call(C("C_rmbl_mlkem_sizes"), lv)[[3]])
        acc <- ok(.Call(C("C_rmbl_mlkem_decaps"), lv, h(t$dk), ct))
        check(s, t$tcId, identical(acc, isTRUE(e$testPassed)), "decapsulation key check (FIPS 203 7.3)")
      },
      tally(s, "na", paste("function", g$`function`))
    )
  })
  run_set("ML-DSA-keyGen-FIPS204", function(s, g, t, e) {
    kp <- .Call(C("C_rmbl_mldsa_keypair"), DSA(g$parameterSet), h(t$seed))
    check(s, t$tcId, eqhex(kp[[1]], e$pk) && eqhex(kp[[2]], e$sk))
  })
  run_set("ML-DSA-sigGen-FIPS204", function(s, g, t, e) {
    mode <- DSA(g$parameterSet)
    sk <- h(t$sk)
    rnd <- if (isTRUE(g$deterministic)) raw(32) else h(t$rnd)
    sgn <- function(masked) {
      if (identical(g$signatureInterface, "internal")) {
        mu <- if (isTRUE(g$externalMu)) h(t$mu) else mldsa_mu(mldsa_tr_sk(sk), h(t$message))
        .Call(C("C_rmbl_mldsa_sign_mu"), mode, sk, mu, rnd, masked)
      } else {
        ph <- if (identical(g$preHash, "preHash")) PH[[t$hashAlg]] else "none"
        .Call(C("C_rmbl_mldsa_sign"), mode, sk, h(t$message), h(t$context), rnd, ph, masked)
      }
    }
    sig <- sgn(FALSE)
    what <- paste(g$signatureInterface, g$preHash %||% "", t$hashAlg %||% "")
    check(s, t$tcId, eqhex(sig, e$signature), what)
    check(s, t$tcId, identical(sig, sgn(TRUE)), paste("masked signing disagrees:", what))
  })
  run_set("ML-DSA-sigVer-FIPS204", function(s, g, t, e) {
    mode <- DSA(g$parameterSet)
    pk <- h(t$pk)
    if (identical(g$signatureInterface, "internal")) {
      mu <- if (isTRUE(g$externalMu)) h(t$mu) else mldsa_mu(shake256(pk, 64L), h(t$message))
      v <- .Call(C("C_rmbl_mldsa_verify_mu"), mode, pk, mu, h(t$signature))
    } else {
      ph <- if (identical(g$preHash, "preHash")) PH[[t$hashAlg]] else "none"
      v <- .Call(C("C_rmbl_mldsa_verify"), mode, pk, h(t$message), h(t$context), h(t$signature), ph)
    }
    check(s, t$tcId, identical(isTRUE(v), isTRUE(e$testPassed)), paste("verify", g$signatureInterface))
  })
  run_set("SLH-DSA-keyGen-FIPS205", function(s, g, t, e) {
    kp <- .Call(C("C_rmbl_slhdsa_keypair"), g$parameterSet, c(h(t$skSeed), h(t$skPrf), h(t$pkSeed)))
    check(s, t$tcId, eqhex(kp[[1]], e$pk) && eqhex(kp[[2]], e$sk))
  })
  run_set("SLH-DSA-sigGen-FIPS205", function(s, g, t, e) {
    sk <- h(t$sk)
    n <- length(sk) / 4L
    opt <- if (isTRUE(g$deterministic)) sk[(2L * n + 1L):(3L * n)] else h(t$additionalRandomness)
    sig <- if (identical(g$signatureInterface, "internal")) {
      .Call(C("C_rmbl_slhdsa_sign_internal"), g$parameterSet, sk, h(t$message), opt)
    } else {
      ph <- if (identical(g$preHash, "preHash")) PH[[t$hashAlg]] else "none"
      .Call(C("C_rmbl_slhdsa_sign"), g$parameterSet, sk, h(t$message), h(t$context), opt, ph)
    }
    check(s, t$tcId, eqhex(sig, e$signature), paste(g$parameterSet, g$signatureInterface, t$hashAlg %||% ""))
  })
  run_set("SLH-DSA-sigVer-FIPS205", function(s, g, t, e) {
    v <- if (identical(g$signatureInterface, "internal")) {
      .Call(C("C_rmbl_slhdsa_verify_internal"), g$parameterSet, h(t$pk), h(t$message), h(t$signature))
    } else {
      ph <- if (identical(g$preHash, "preHash")) PH[[t$hashAlg]] else "none"
      .Call(C("C_rmbl_slhdsa_verify"), g$parameterSet, h(t$pk), h(t$message), h(t$context), h(t$signature), ph)
    }
    check(s, t$tcId, identical(isTRUE(v), isTRUE(e$testPassed)), paste(g$parameterSet, g$signatureInterface))
  })
  for (set in c("SHA3-224-2.0", "SHA3-256-2.0", "SHA3-384-2.0", "SHA3-512-2.0")) {
    nm <- sub("^SHA3-([0-9]+).*$", "sha3_\\1", set)
    run_set(set, function(s, g, t, e) {
      if (identical(g$testType, "LDT")) {
        return(tally(s, "na", "large-data test (gigabyte message)"))
      }
      if (as.integer(t$len) %% 8L != 0L) {
        return(tally(s, "na", "bit-length message (the API hashes bytes)"))
      }
      if (identical(g$testType, "MCT")) {
        md <- h(t$msg)
        for (j in seq_along(e$resultsArray)) {
          for (i in seq_len(1000L)) md <- .Call(C("C_rmbl_prehash_digest"), nm, md)
          check(s, paste0(t$tcId, ".", j), eqhex(md, e$resultsArray[[j]]$md), "MCT")
        }
        return(invisible())
      }
      check(s, t$tcId, eqhex(.Call(C("C_rmbl_prehash_digest"), nm, h(t$msg)), e$md))
    })
  }
  for (set in c("SHAKE-128-FIPS202", "SHAKE-256-FIPS202")) {
    w <- if (grepl("128", set)) 128L else 256L
    run_set(set, function(s, g, t, e) {
      if (as.integer(t$len) %% 8L != 0L || as.integer(t$outLen) %% 8L != 0L) {
        return(tally(s, "na", "bit-length input or output"))
      }
      if (!identical(g$testType, "AFT")) {
        return(tally(s, "na", paste("test type", g$testType)))
      }
      check(s, t$tcId, eqhex(.Call(C("C_rmbl_shake"), w, h(t$msg), as.integer(t$outLen) %/% 8L), e$md))
    })
  }
  for (set in c("HMAC-SHA2-256-2.0", "HMAC-SHA2-512-2.0")) {
    bits <- if (grepl("512", set)) 512L else 256L
    run_set(set, function(s, g, t, e) {
      mac <- .Call(C("C_rmbl_hmac_shax"), bits, h(t$key), h(t$msg))
      check(s, t$tcId, eqhex(mac[seq_len(as.integer(t$macLen) %/% 8L)], e$mac))
    })
  }
  run_set("PBKDF-1.0", function(s, g, t, e) {
    if (!identical(g$hmacAlg, "SHA2-256")) {
      return(tally(s, "na", paste("PBKDF2 with", g$hmacAlg, "(the package's is HMAC-SHA-256)")))
    }
    dk <- .Call(C("C_rmbl_pbkdf2"), t$password, h(t$salt), as.integer(t$iterationCount), as.integer(t$keyLen) %/% 8L)
    check(s, t$tcId, eqhex(if (is.raw(dk)) dk else h(dk), e$derivedKey))
  })
  TOTAL
}
