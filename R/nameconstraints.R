# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Name constraints (RFC 5280 section 4.2.1.10).
#
# A certificate authority can be limited to a part of the name space:
# permitted to issue for example.org and nothing else, or excluded from
# a subtree inside what it is otherwise permitted. A verifier that
# ignores the extension treats a CA constrained to one organisation's
# domains as able to issue for any name at all, which is the whole
# reason the constraint exists.
#
# The matching rules differ by name type and are not interchangeable.
# A DNS constraint of "example.org" covers "host.example.org" AND
# "example.org"; an email constraint of "example.org" covers mailboxes
# whose host is exactly that, not its subdomains; a directory name
# constraint matches on whole relative distinguished names, so a
# constraint of "O=Acme" is not satisfied by "O=AcmeCorp".

# One GeneralName, as a type and a value. The types this handles are the
# ones name constraints are written against in practice; an unhandled
# type is carried through with its tag so that a constraint on it can be
# reported rather than silently ignored.
.rmbl_general_names <- function(nd) {
  out <- list()
  for (g in nd$children) {
    if (!identical(g$class, 2L)) next
    tag <- g$tag
    if (identical(tag, 1)) {
      out[[length(out) + 1L]] <- list(type = "email",
                                      value = .rmbl_raw_text(g$value))
    } else if (identical(tag, 2)) {
      out[[length(out) + 1L]] <- list(type = "dns",
                                      value = .rmbl_raw_text(g$value))
    } else if (identical(tag, 6)) {
      out[[length(out) + 1L]] <- list(type = "uri",
                                      value = .rmbl_raw_text(g$value))
    } else if (identical(tag, 7)) {
      out[[length(out) + 1L]] <- list(type = "ip", value = g$value)
    } else if (identical(tag, 4)) {
      # directoryName is [4] EXPLICIT, so the Name sits inside
      inner <- if (length(g$children)) g$children[[1]] else NULL
      if (!is.null(inner)) {
        out[[length(out) + 1L]] <- list(type = "dirname",
                                        value = .rmbl_x509_rdns(inner))
      }
    } else {
      out[[length(out) + 1L]] <- list(type = paste0("tag", tag),
                                      value = g$value)
    }
  }
  out
}

.rmbl_raw_text <- function(v) {
  if (!length(v)) return("")
  tryCatch(rawToChar(v), error = function(e) "")
}

# A distinguished name as a list of RDNs, each a set of attribute
# type/value pairs. The flattened string is for people; constraint
# matching needs the structure, because a prefix match is defined on
# whole RDNs.
.rmbl_x509_rdns <- function(nd) {
  lapply(nd$children, function(rdn) {
    lapply(rdn$children, function(atv) {
      if (length(atv$children) < 2L) return(NULL)
      list(oid = .rmbl_oid_string(atv$children[[1]]$value),
           value = .rmbl_raw_text(atv$children[[2]]$value))
    })
  })
}

# NameConstraints ::= SEQUENCE { permittedSubtrees [0] OPTIONAL,
#                                excludedSubtrees  [1] OPTIONAL }
.rmbl_name_constraints <- function(val) {
  inner <- tryCatch(.Call(C_rmbl_der_parse, val), error = function(e) NULL)
  if (is.null(inner)) return(NULL)
  out <- list(permitted = list(), excluded = list())
  for (part in inner$children) {
    if (!identical(part$class, 2L)) next
    subs <- lapply(part$children, function(gs) {
      # GeneralSubtree ::= SEQUENCE { base GeneralName, ... }
      g <- .rmbl_general_names(gs)
      if (length(g)) g[[1]] else NULL
    })
    subs <- subs[!vapply(subs, is.null, logical(1))]
    if (identical(part$tag, 0)) out$permitted <- subs
    if (identical(part$tag, 1)) out$excluded <- subs
  }
  if (!length(out$permitted) && !length(out$excluded)) return(NULL)
  out
}

# A DNS constraint of "example.org" is satisfied by "example.org" and by
# anything under it. A leading dot, which is a convention rather than
# the RFC's text, is read as subdomains only.
.rmbl_nc_match_dns <- function(name, base) {
  name <- tolower(name)
  base <- tolower(base)
  if (!nzchar(base)) return(TRUE)
  if (startsWith(base, ".")) {
    return(endsWith(name, base))
  }
  identical(name, base) || endsWith(name, paste0(".", base))
}

# An email constraint may be a full mailbox, a host, or a dot-prefixed
# domain. A host constraint is NOT satisfied by a subdomain of it, which
# is where this differs from DNS and where a verifier that reuses the
# DNS rule becomes too permissive.
.rmbl_nc_match_email <- function(name, base) {
  name <- tolower(name)
  base <- tolower(base)
  if (grepl("@", base, fixed = TRUE)) return(identical(name, base))
  host <- sub("^[^@]*@", "", name)
  if (startsWith(base, ".")) return(endsWith(host, base))
  identical(host, base)
}

.rmbl_nc_match_uri <- function(name, base) {
  host <- sub("^[a-zA-Z][a-zA-Z0-9+.-]*://", "", name)
  host <- sub("[/?#].*$", "", host)
  host <- sub("^[^@]*@", "", host)
  host <- sub(":[0-9]*$", "", host)
  .rmbl_nc_match_dns(host, base)
}

# The constraint is the address followed by the mask, so 8 bytes for
# IPv4 and 32 for IPv6.
.rmbl_nc_match_ip <- function(name, base) {
  n <- length(name)
  if (length(base) != 2L * n) return(FALSE)
  addr <- as.integer(base[seq_len(n)])
  mask <- as.integer(base[n + seq_len(n)])
  ip <- as.integer(name)
  all(bitwAnd(ip, mask) == bitwAnd(addr, mask))
}

# A directory name constraint matches when its RDNs are an initial
# sequence of the name's, compared whole: "O=Acme" does not match
# "O=AcmeCorp", and a partial attribute value never matches.
.rmbl_nc_match_dirname <- function(rdns, base) {
  if (!length(base)) return(TRUE)
  if (length(rdns) < length(base)) return(FALSE)
  norm <- function(atvs) {
    v <- vapply(Filter(Negate(is.null), atvs), function(a) {
      paste0(a$oid, "=", tolower(trimws(a$value)))
    }, character(1))
    paste(sort(v), collapse = "+")
  }
  for (i in seq_along(base)) {
    if (!identical(norm(rdns[[i]]), norm(base[[i]]))) return(FALSE)
  }
  TRUE
}

.rmbl_nc_match <- function(nm, base) {
  if (!identical(nm$type, base$type)) return(NA)
  switch(nm$type,
         dns = .rmbl_nc_match_dns(nm$value, base$value),
         email = .rmbl_nc_match_email(nm$value, base$value),
         uri = .rmbl_nc_match_uri(nm$value, base$value),
         ip = .rmbl_nc_match_ip(nm$value, base$value),
         dirname = .rmbl_nc_match_dirname(nm$value, base$value),
         NA)
}

# Check one certificate's names against one CA's constraints.
#
# The asymmetry is in the RFC and is easy to get backwards: an excluded
# subtree rejects on any match, while permitted subtrees only bite for
# name types they actually mention. A certificate carrying no name of a
# constrained type is not rejected on that type -- otherwise every
# constraint on email would reject every certificate without one.
.rmbl_nc_check_one <- function(cert, nc) {
  names_to_check <- cert$san
  if (length(cert$subject_rdns)) {
    names_to_check <- c(names_to_check,
                        list(list(type = "dirname",
                                  value = cert$subject_rdns)))
  }
  problems <- character(0)
  for (ex in nc$excluded) {
    for (nm in names_to_check) {
      hit <- .rmbl_nc_match(nm, ex)
      if (isTRUE(hit)) {
        problems <- c(problems,
                      sprintf("%s '%s' is inside an excluded subtree",
                              nm$type, .rmbl_nc_show(nm)))
      }
    }
  }
  if (length(nc$permitted)) {
    types <- unique(vapply(nc$permitted, `[[`, character(1), "type"))
    for (ty in types) {
      mine <- Filter(function(n) identical(n$type, ty), names_to_check)
      if (!length(mine)) next
      bases <- Filter(function(b) identical(b$type, ty), nc$permitted)
      for (nm in mine) {
        if (!any(vapply(bases, function(b) isTRUE(.rmbl_nc_match(nm, b)),
                        logical(1)))) {
          problems <- c(problems,
                        sprintf("%s '%s' is outside every permitted subtree",
                                ty, .rmbl_nc_show(nm)))
        }
      }
    }
  }
  problems
}

.rmbl_nc_show <- function(nm) {
  if (identical(nm$type, "dirname")) {
    parts <- unlist(lapply(nm$value, function(rdn) {
      vapply(Filter(Negate(is.null), rdn), function(a) {
        paste0(a$oid, "=", a$value)
      }, character(1))
    }))
    return(paste(parts, collapse = ", "))
  }
  if (identical(nm$type, "ip")) return(paste(as.integer(nm$value),
                                             collapse = "."))
  as.character(nm$value)
}
