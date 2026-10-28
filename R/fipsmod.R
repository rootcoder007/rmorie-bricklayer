# SPDX-License-Identifier: AGPL-3.0-or-later
#
# FIPS mode: keys made and signatures computed inside an OpenSSL FIPS
# provider, a FIPS 140-3 cryptographic module, driven through the openssl
# program. The package's own ML-DSA and SLH-DSA still verify the result:
# both sides implement the same standards, so each accepts the other's
# signatures.

.rmbl_fipsmod_cache <- new.env(parent = emptyenv())

#' Sign Inside a FIPS 140-3 Module
#'
#' Finds the OpenSSL FIPS provider (a FIPS 140-3 cryptographic module),
#' loads it on its own, and reports which module it is and whether that
#' module is on the package's list of validated ones. Keys from
#' [fipsmkg()]
#' are then made, and
#' [cpssign()]
#' signs with them, inside that module rather than in this package's own
#' code.
#'
#' The package's own ML-DSA and SLH-DSA are not a validated module, and
#' FIPS mode does not change that. What it gives is a way to sign with a
#' module that is: a module listed as validated, run as this function runs
#' it, is used in its approved mode. Whether a given module is validated
#' is NIST's to say; the package only recognises the exact module names and
#' builds that a certificate names (the file `modules.csv` in the
#' package's `fips` folder), and says "not on the list" for every
#' other one, including a FIPS provider that may well be validated under a
#' certificate the list does not have yet.
#'
#' @details
#' The `openssl` program must be 3.5 or later (the first with ML-DSA and
#' SLH-DSA). Unless `conf` names a configuration, the package writes its
#' own to a private temporary folder: it loads only the FIPS provider and
#' the base provider, sets `default_properties = fips=yes`, and makes a
#' configuration error fatal, so nothing can quietly fall back to the
#' default provider. A distribution's own FIPS provider (Red Hat, Fedora,
#' Chainguard) loads as it is; an upstream build is first installed with
#' `openssl fipsinstall`, which runs the module's self-tests. Give `conf`
#' (or set the option `rmbl.fips.conf` or the environment variable
#' `RMBL_FIPS_CONF`) to use the configuration your organisation's FIPS
#' deployment prescribes instead.
#'
#' The status is the module's own report, matched against the list: it is
#' as true as the `openssl` program run, which is why a key never chooses
#' that program. [cpssign()] loads the module set up now (the options
#' `rmbl.fips.openssl` and `rmbl.fips.conf`) and refuses a key made in
#' another. Every run of the program is stopped after `rmbl.fips.timeout`
#' seconds (default 300). The private key reaches the program through a
#' file in a folder only you can read, removed when the operation ends; a
#' process killed meanwhile leaves it in R's session folder.
#'
#' Refusals: no `openssl` program, one older than 3.5, a FIPS provider that
#' is missing or does not load, or a `conf` file that does not exist.
#'
#' @param openssl Path to the `openssl` program. The default is the option
#'   `rmbl.fips.openssl`, else the `openssl` on the `PATH`.
#' @param conf Path to an OpenSSL configuration that loads the FIPS
#'   provider, or `""` to let the package write one.
#' @return A list of class `rmbl_fipsmod`: `name`, `version` and `build`
#'   (the module as it reports itself), `status` (`"validated"`,
#'   `"validated without PQC"` or `"not listed"`), `cmvp` (the certificate,
#'   such as `"#5523"`, or `NA`), `pqc` (whether that certificate covers
#'   ML-DSA and SLH-DSA), `openssl`, `openssl_version` and `conf`. It prints
#'   as a box. The result is remembered for the session.
#' @seealso
#' [fipsmkg()],
#' [cpssign()],
#' [cpsxvrf()].
#' @export
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Only where an OpenSSL 3.5 FIPS provider is installed:
#' mod <- try(fipsmod(), silent = TRUE)
#' if (inherits(mod, "rmbl_fipsmod")) {
#'   print(mod)
#'   key <- fipsmkg("ML-DSA-44", mod)
#'   sig <- cpssign("a manifest digest", key)
#'   cpsvrf("a manifest digest", sig, key)
#' }
fipsmod <- function(openssl = getOption("rmbl.fips.openssl",
                                         Sys.which("openssl")),
                    conf = getOption("rmbl.fips.conf",
                                     Sys.getenv("RMBL_FIPS_CONF"))) {
  openssl <- .rmbl_fipsmod_program(openssl)
  if (is.null(conf)) {
    conf <- ""
  }
  if (!is.character(conf) || length(conf) != 1L || is.na(conf)) {
    stop("`conf` must be one path, or \"\"", call. = FALSE)
  }
  # keyed on the files as they are now, so a program or configuration
  # replaced during the session is not answered from the cache
  stamp <- function(f) {
    i <- suppressWarnings(file.info(f, extra_cols = FALSE))
    paste(f, i$size, as.numeric(i$mtime))
  }
  id <- paste(stamp(openssl$path), if (nzchar(conf)) stamp(conf) else "",
              sep = "\n")
  hit <- .rmbl_fipsmod_cache[[id]]
  if (!is.null(hit)) {
    return(hit)
  }
  cfg <- if (nzchar(conf)) {
    .rmbl_fipsmod_given_conf(conf)
  } else {
    .rmbl_fipsmod_conf(openssl$path)
  }
  prov <- .rmbl_fipsmod_provider(openssl$path, cfg)
  if (is.null(prov)) {
    stop(
      "the OpenSSL FIPS provider did not load with ", cfg, ": install a ",
      "FIPS provider for OpenSSL ", openssl$number, ", or give `conf`",
      call. = FALSE
    )
  }
  out <- c(
    prov,
    .rmbl_fipsmod_lookup(prov$name, prov$build),
    list(openssl = openssl$path, openssl_version = openssl$number,
         conf = cfg)
  )
  class(out) <- c("rmbl_fipsmod", "list")
  assign(id, out, envir = .rmbl_fipsmod_cache)
  out
}

#' Make a Signing Key Inside a FIPS 140-3 Module
#'
#' Generates an ML-DSA or SLH-DSA key pair inside the module that
#' [fipsmod()]
#' found. The private key stays in the module's own format (PEM) and never
#' passes through this package's code; [cpssign()] hands it back to the
#' module to sign. The public key is the standard one, so the signatures
#' verify with [cpsvrf()] (this package's implementation), with
#' [cpsxvrf()] (OpenSSL's), and anywhere else FIPS 204 and 205 are
#' implemented.
#'
#' @details
#' The key prints without its private part. It is an ordinary R object:
#' anything that saves it (`saveRDS()`, a workspace) saves the private key
#' too, so keep it as carefully as any other private key. Signing checks
#' that the module loaded now is the one that made the key and refuses
#' otherwise. XMSS and HQC have no FIPS module and are refused.
#'
#' @param scheme An ML-DSA or SLH-DSA parameter set, default
#'   `"SLH-DSA-SHA2-128s"` (as for [fipskg()]), or such as `"ML-DSA-65"`
#'   or `"SLH-DSA-SHA2-128s"` (see [fipssz()]).
#' @param mod The module, from [fipsmod()].
#' @return A key of class `rmbl_fipsmod_key` (also a
#'   `bricklayer_fips_public_key`, so every verifier accepts it): `public`
#'   (hex), `scheme`, `module` (name, build, status and certificate) and
#'   the private key in `pem`.
#' @seealso
#' [fipsmod()],
#' [cpssign()],
#' [fipskg()] for keys made by this package's own code.
#' @export
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' mod <- try(fipsmod(), silent = TRUE)
#' if (inherits(mod, "rmbl_fipsmod")) {
#'   key <- fipsmkg("SLH-DSA-SHA2-128s", mod)
#'   key
#' }
fipsmkg <- function(scheme = "SLH-DSA-SHA2-128s", mod = fipsmod()) {
  # only ML-DSA and SLH-DSA names pass; XMSS is refused there, with
  # where to make such a key instead
  scheme <- .rmbl_fips_scheme(scheme)
  if (!inherits(mod, "rmbl_fipsmod")) {
    stop("`mod` must come from fipsmod()", call. = FALSE)
  }
  d <- .rmbl_fipsmod_dir()
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  pem <- file.path(d, "key.pem")
  pub <- file.path(d, "pub.der")
  .rmbl_fipsmod_ok(mod, c("genpkey", "-algorithm", scheme, "-out",
                          .rmbl_fipsmod_q(pem)), "key generation")
  .rmbl_fipsmod_ok(mod, c("pkey", "-in", .rmbl_fipsmod_q(pem), "-pubout",
                          "-outform", "DER", "-out", .rmbl_fipsmod_q(pub)),
                   "public key export")
  der <- readBin(pub, "raw", file.size(pub))
  pk <- .rmbl_fipsmod_spki_key(der, scheme)
  out <- list(
    public = .rmbl_hexlify(pk),
    scheme = scheme,
    module = .rmbl_fipsmod_id(mod),
    pem = paste(readLines(pem, warn = FALSE), collapse = "\n")
  )
  class(out) <- c("rmbl_fipsmod_key", "bricklayer_fips_public_key",
                  "bricklayer_oqs_public_key", "list")
  out
}

#' @export
format.rmbl_fipsmod_key <- function(x, ...) {
  m <- x$module
  c(
    .rmbl_rule("FIPS module key"),
    .rmbl_kv(list(
      Scheme = x$scheme,
      Public = .rmbl_fipsmod_short(x$public),
      Module = paste(m$name, m$build),
      Status = .rmbl_fipsmod_status_text(m$status, m$cmvp)
    )),
    "",
    paste0("  ", .rmbl_wrap(paste(
      "The private key was made inside the module and is held in its",
      "format; it is not shown. Sign with cpssign(); verify with",
      "cpsvrf() or cpsxvrf()."
    ))),
    .rmbl_rule()
  )
}

#' @export
format.rmbl_fipsmod <- function(x, ...) {
  head <- switch(
    x$status,
    "validated" = "FIPS module: validated, with ML-DSA and SLH-DSA",
    "validated without PQC" =
      "FIPS module: validated, but not for ML-DSA or SLH-DSA",
    "FIPS module: loaded, not on the list of validated modules"
  )
  c(
    .rmbl_rule(head),
    .rmbl_kv(list(
      Module = x$name,
      Build = x$build,
      Certificate = if (is.na(x$cmvp)) "none on the list" else
        paste("CMVP", x$cmvp),
      OpenSSL = x$openssl_version
    )),
    "",
    paste0("  ", .rmbl_wrap(.rmbl_fipsmod_reading(x))),
    .rmbl_rule()
  )
}

#' What a module's status means, in a sentence or two.
#' @param x A result of fipsmod().
#' @return A string.
#' @noRd
.rmbl_fipsmod_reading <- function(x) {
  switch(
    x$status,
    "validated" = paste(
      "The module reports itself as one that a FIPS 140-3 certificate",
      "(CMVP", paste0(x$cmvp, ")"), "names; signatures made with",
      "fipsmkg() keys are computed inside it, in its approved mode. The",
      "report comes from the openssl program you chose, so it is as",
      "true as that program."
    ),
    "validated without PQC" = paste(
      "This module's certificate does not cover ML-DSA or SLH-DSA, so",
      "post-quantum signatures from it are not made by a validated",
      "module."
    ),
    paste(
      "The package does not know of a certificate for this exact module",
      "and build. It may still be validated: check NIST's list",
      "(csrc.nist.gov/projects/cryptographic-module-validation-program)",
      "before you claim it is."
    )
  )
}

#' One-line status for a key's box.
#' @param status,cmvp As fipsmod() reports them.
#' @return A string.
#' @noRd
.rmbl_fipsmod_status_text <- function(status, cmvp) {
  if (identical(status, "validated")) {
    return(paste("validated, CMVP", cmvp))
  }
  status
}

#' The first and last bytes of a long hex string.
#' @param h A digest in hex.
#' @return A shortened string.
#' @noRd
.rmbl_fipsmod_short <- function(h) {
  if (nchar(h) <= 32L) {
    return(h)
  }
  sprintf("%s...%s (%d bytes)", substring(h, 1L, 16L),
          substring(h, nchar(h) - 15L), nchar(h) %/% 2L)
}

#' The openssl program, checked: present and 3.5 or later.
#' @param openssl Its path.
#' @return A list: `path` and `number`.
#' @noRd
.rmbl_fipsmod_program <- function(openssl) {
  if (!is.character(openssl) || length(openssl) != 1L || is.na(openssl) ||
      !nzchar(openssl)) {
    stop("the openssl program was not found on the PATH", call. = FALSE)
  }
  ver <- .rmbl_xvrf_version(openssl)
  if (is.na(ver$number)) {
    stop("the openssl program did not report its version", call. = FALSE)
  }
  if (utils::compareVersion(ver$number, "3.5.0") < 0) {
    stop(ver$label, " is older than 3.5, which first added ML-DSA and ",
         "SLH-DSA", call. = FALSE)
  }
  list(path = unname(openssl), number = ver$number)
}

#' A configuration the caller names, checked to exist.
#' @param conf Its path.
#' @return The normalised path.
#' @noRd
.rmbl_fipsmod_given_conf <- function(conf) {
  if (!file.exists(conf) || dir.exists(conf)) {
    stop("`conf` is not a file: ", conf, call. = FALSE)
  }
  normalizePath(conf, winslash = "/")
}

#' A private folder for one operation's files.
#' @return Its path; the caller removes it.
#' @noRd
.rmbl_fipsmod_dir <- function() {
  d <- tempfile("rmbl-fips-")
  old <- Sys.umask("077")
  on.exit(Sys.umask(old), add = TRUE)
  dir.create(d, mode = "0700")
  d
}

#' Quotes a path for the shell system2() runs.
#' @param p The path.
#' @return The quoted path.
#' @noRd
.rmbl_fipsmod_q <- function(p) {
  shQuote(p, type = if (.Platform$OS.type == "windows") "cmd" else "sh")
}

#' The configuration text that loads only the FIPS and base providers.
#' @param include A file to include (the output of fipsinstall), or NULL
#'   to activate a provider that carries its own integrity check.
#' @return The lines.
#' @noRd
.rmbl_fipsmod_conf_text <- function(include = NULL) {
  c(
    "config_diagnostics = 1",
    "openssl_conf = openssl_init",
    if (!is.null(include)) paste(".include", include),
    "[openssl_init]",
    "providers = provider_sect",
    "alg_section = algorithm_sect",
    "[provider_sect]",
    "fips = fips_sect",
    "base = base_sect",
    "[base_sect]",
    "activate = 1",
    if (is.null(include)) c("[fips_sect]", "activate = 1"),
    "[algorithm_sect]",
    "default_properties = fips=yes"
  )
}

#' Writes the package's FIPS configuration, installing the provider with
#' fipsinstall when it does not load as it is.
#' @param openssl The program.
#' @return The configuration's path.
#' @noRd
.rmbl_fipsmod_conf <- function(openssl) {
  d <- file.path(tempdir(), "rmbl-fips")
  dir.create(d, showWarnings = FALSE, mode = "0700")
  cfg <- file.path(d, "openssl.cnf")
  writeLines(.rmbl_fipsmod_conf_text(), cfg)
  if (!is.null(.rmbl_fipsmod_provider(openssl, cfg))) {
    return(cfg)
  }
  mod <- .rmbl_fipsmod_module_file(openssl)
  if (is.na(mod)) {
    return(cfg)
  }
  inst <- file.path(d, "fipsmodule.cnf")
  res <- .rmbl_fipsmod_run(openssl, "", c(
    "fipsinstall", "-module", .rmbl_fipsmod_q(mod), "-out",
    .rmbl_fipsmod_q(inst)
  ))
  if (res$status != 0L || !file.exists(inst)) {
    return(cfg)
  }
  writeLines(.rmbl_fipsmod_conf_text(inst), cfg)
  cfg
}

#' The FIPS provider's module file in OpenSSL's modules folder.
#' @param openssl The program.
#' @return Its path, or NA.
#' @noRd
.rmbl_fipsmod_module_file <- function(openssl) {
  res <- .rmbl_fipsmod_run(openssl, "", c("info", "-modulesdir"))
  dir <- trimws(utils::tail(res$out, 1L))
  if (res$status != 0L || !length(dir) || !dir.exists(dir)) {
    return(NA_character_)
  }
  f <- file.path(dir, c("fips.so", "fips.dylib", "fips.dll"))
  f <- f[file.exists(f)]
  if (length(f)) f[[1L]] else NA_character_
}

#' Runs the openssl program with a configuration.
#' @param openssl The program.
#' @param cfg The configuration, or "" for none.
#' @param args Its arguments.
#' @return A list: `status` and `out` (stdout and stderr lines).
#' @noRd
.rmbl_fipsmod_run <- function(openssl, cfg, args) {
  # set and restored around the call: system2(env =) prefixes the command,
  # which cmd.exe cannot run
  old <- Sys.getenv("OPENSSL_CONF", unset = NA)
  if (nzchar(cfg)) {
    Sys.setenv(OPENSSL_CONF = cfg)
  } else {
    Sys.unsetenv("OPENSSL_CONF")
  }
  on.exit(
    if (is.na(old)) Sys.unsetenv("OPENSSL_CONF") else
      Sys.setenv(OPENSSL_CONF = old),
    add = TRUE
  )
  out <- tryCatch(
    suppressWarnings(system2(openssl, args, stdout = TRUE, stderr = TRUE,
                             timeout = .rmbl_fipsmod_timeout())),
    error = function(e) structure(conditionMessage(e), status = 127L)
  )
  st <- attr(out, "status") %||% 0L
  if (identical(as.integer(st), 124L)) {
    out <- sprintf("the openssl program did not finish within %d seconds",
                   .rmbl_fipsmod_timeout())
  }
  list(status = st, out = as.character(out))
}

#' Seconds an openssl run may take (option `rmbl.fips.timeout`, default
#' 300: SLH-DSA's small variants sign slowly).
#' @return A whole number of seconds.
#' @noRd
.rmbl_fipsmod_timeout <- function() {
  t <- suppressWarnings(as.integer(getOption("rmbl.fips.timeout", 300L)))
  if (length(t) != 1L || is.na(t) || t < 1L) 300L else t
}

#' Runs a module operation and stops when it fails.
#' @param mod The module.
#' @param args The openssl arguments.
#' @param what What the operation is, for the message.
#' @return The output lines, invisibly.
#' @noRd
.rmbl_fipsmod_ok <- function(mod, args, what) {
  res <- .rmbl_fipsmod_run(mod$openssl, mod$conf, args)
  if (res$status != 0L) {
    stop(
      "the FIPS module refused the ", what, ": ",
      substr(paste(res$out, collapse = " "), 1L, 300L),
      call. = FALSE
    )
  }
  invisible(res$out)
}

#' The active FIPS provider under a configuration.
#' @param openssl The program.
#' @param cfg The configuration.
#' @return A list (`name`, `version`, `build`), or NULL when no FIPS
#'   provider is active.
#' @noRd
.rmbl_fipsmod_provider <- function(openssl, cfg) {
  res <- .rmbl_fipsmod_run(openssl, cfg, c("list", "-providers",
                                           "-verbose"))
  if (res$status != 0L) {
    return(NULL)
  }
  .rmbl_fipsmod_parse(res$out)
}

#' Reads the FIPS provider's block from `openssl list -providers -verbose`.
#' @param lines The output.
#' @return A list (`name`, `version`, `build`), or NULL.
#' @noRd
.rmbl_fipsmod_parse <- function(lines) {
  starts <- grep("^  [^ ]", lines)
  for (i in seq_along(starts)) {
    end <- if (i < length(starts)) starts[i + 1L] - 1L else length(lines)
    blk <- lines[starts[i]:end]
    val <- function(k) {
      hit <- grep(paste0("^    ", k, ": "), blk, value = TRUE)
      if (length(hit)) sub(paste0("^    ", k, ": "), "", hit[[1L]]) else NA
    }
    name <- val("name")
    if (!is.na(name) && grepl("FIPS", name, fixed = TRUE) &&
        identical(val("status"), "active")) {
      ver <- val("version")
      build <- val("build info")
      return(list(name = name, version = ver,
                  build = if (is.na(build)) ver else build))
    }
  }
  NULL
}

#' Looks a module up in the package's list of validated modules.
#' @param name,build The module's name and build, as it reports them.
#' @param file The list (inst/fips/modules.csv).
#' @return A list: `status`, `cmvp` and `pqc`.
#' @noRd
.rmbl_fipsmod_lookup <- function(name, build,
                                 file = system.file("fips", "modules.csv",
                                                    package =
                                                      "rmoriebricklayer")) {
  none <- list(status = "not listed", cmvp = NA_character_, pqc = FALSE)
  if (!nzchar(file) || !file.exists(file)) {
    return(none)
  }
  tab <- utils::read.csv(file, stringsAsFactors = FALSE,
                         comment.char = "#")
  hit <- tab[tab$name == name & tab$build == build, , drop = FALSE]
  if (!nrow(hit)) {
    return(none)
  }
  pqc <- isTRUE(as.logical(hit$pqc[[1L]]))
  list(
    status = if (pqc) "validated" else "validated without PQC",
    cmvp = paste0("#", hit$cmvp[[1L]]),
    pqc = pqc
  )
}

#' The module fields a key and a signature record.
#' @param mod The module.
#' @return A list.
#' @noRd
.rmbl_fipsmod_id <- function(mod) {
  list(name = mod$name, build = mod$build, status = mod$status,
       cmvp = mod$cmvp, openssl = mod$openssl, conf = mod$conf)
}

#' The raw public key inside a DER SubjectPublicKeyInfo, checked to be
#' exactly the standard encoding for its scheme.
#' @param der The DER bytes.
#' @param scheme The scheme.
#' @return The public key bytes.
#' @noRd
.rmbl_fipsmod_spki_key <- function(der, scheme) {
  n <- fipssz(scheme)[["public_key"]]
  pk <- if (length(der) > n) der[(length(der) - n + 1L):length(der)] else
    raw(0)
  if (!length(pk) ||
      !identical(der, .rmbl_xvrf_spki(.rmbl_xvrf_oid(scheme), pk))) {
    stop("the FIPS module returned a public key that is not a standard ",
         scheme, " key", call. = FALSE)
  }
  pk
}

#' Signs inside the module that made the key.
#' @param msg The message (raw or text, as cpssign() takes it).
#' @param key A key from fipsmkg().
#' @param ctx The context string, or NULL.
#' @param determ Whether to sign deterministically.
#' @param prehash Must be "none": the module signs pure ML-DSA/SLH-DSA.
#' @return A bricklayer_signature, with the module recorded.
#' @noRd
.rmbl_fipsmod_sign <- function(msg, key, ctx, determ, prehash) {
  if (!identical(prehash, "none")) {
    stop("a FIPS module key signs pure (prehash = \"none\") only",
         call. = FALSE)
  }
  mod <- .rmbl_fipsmod_same(key)
  d <- .rmbl_fipsmod_dir()
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  f <- file.path(d, c("key.pem", "msg", "sig"))
  writeLines(key$pem, f[1L])
  writeBin(.rmbl_sign_message(msg), f[2L])
  cx <- .rmbl_fips_context(ctx)
  args <- c("pkeyutl", "-sign", "-rawin", "-inkey", .rmbl_fipsmod_q(f[1L]),
            "-in", .rmbl_fipsmod_q(f[2L]), "-out", .rmbl_fipsmod_q(f[3L]))
  if (length(cx)) {
    args <- c(args, "-pkeyopt",
              paste0("hexcontext-string:", .rmbl_hexlify(cx)))
  }
  if (isTRUE(determ)) {
    args <- c(args, "-pkeyopt", "deterministic:1")
  }
  .rmbl_fipsmod_ok(mod, args, "signature")
  sg <- readBin(f[3L], "raw", file.size(f[3L]))
  out <- list(
    scheme = key$scheme,
    signature = .rmbl_hexlify(sg),
    context = cx,
    prehash = "none",
    module = key$module[c("name", "build", "status", "cmvp")]
  )
  class(out) <- c("bricklayer_signature", "list")
  out
}

#' The module a key was made in, loaded again and checked to be the same.
#' @param key A key from fipsmkg().
#' @return The module.
#' @noRd
.rmbl_fipsmod_same <- function(key) {
  k <- key$module
  if (!is.list(k) || !is.character(key$pem) || length(key$pem) != 1L) {
    stop("this FIPS module key is damaged: make a new one with fipsmkg()",
         call. = FALSE)
  }
  # the program and configuration recorded in a key are never run: a key
  # read from a file would otherwise choose what this package executes
  mod <- fipsmod()
  if (!identical(mod$name, k$name) || !identical(mod$build, k$build)) {
    stop("the FIPS module loaded now (", mod$name, " ", mod$build,
         ") is not the one that made this key (", k$name, " ", k$build,
         "): point options(rmbl.fips.openssl =, rmbl.fips.conf =) at it",
         call. = FALSE)
  }
  mod
}
