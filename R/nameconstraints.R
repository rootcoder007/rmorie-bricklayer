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

#' Reads the GeneralNames under a parsed DER node.
#'
#' One GeneralName, as a type and a value. The types this handles are the
#' ones name constraints are written against in practice; an unhandled
#' type is carried through with its tag so that a constraint on it can be
#' reported rather than silently ignored.
#' @param nd A node from `C_rmbl_der_parse`.
#' @return A list of names, each a list with `type` and `value`.
#' @noRd
.rmbl_general_names <- function(nd) {
  out <- list()
  for (g in nd$children) {
    if (!identical(g$class, 2L)) {
      next
    }
    tag <- g$tag
    if (identical(tag, 1)) {
      out[[length(out) + 1L]] <- list(
        type = "email",
        value = .rmbl_raw_text(g$value)
      )
    } else if (identical(tag, 2)) {
      out[[length(out) + 1L]] <- list(
        type = "dns",
        value = .rmbl_raw_text(g$value)
      )
    } else if (identical(tag, 6)) {
      out[[length(out) + 1L]] <- list(
        type = "uri",
        value = .rmbl_raw_text(g$value)
      )
    } else if (identical(tag, 7)) {
      out[[length(out) + 1L]] <- list(type = "ip", value = g$value)
    } else if (identical(tag, 4)) {
      # directoryName is [4] EXPLICIT, so the Name sits inside
      inner <- if (length(g$children)) g$children[[1]] else NULL
      if (!is.null(inner)) {
        out[[length(out) + 1L]] <- list(
          type = "dirname",
          value = .rmbl_x509_rdns(inner)
        )
      }
    } else {
      out[[length(out) + 1L]] <- list(
        type = paste0("tag", tag),
        value = g$value
      )
    }
  }
  out
}

#' Converts raw bytes to text, \code{""} when they are empty or cannot be
#' converted. Bytes that are not UTF-8 are shown as \code{<xx>}: a string
#' holding them made nchar(), substring(), tolower() and trimws() fail with
#' "invalid multibyte string".
#' @param v A raw vector.
#' @return One string.
#' @noRd
.rmbl_raw_text <- function(v) {
  if (!length(v)) {
    return("")
  }
  s <- tryCatch(rawToChar(v), error = function(e) "")
  if (validUTF8(s)) s else iconv(s, "UTF-8", "UTF-8", sub = "byte")
}

#' Reads a distinguished name as a list of RDNs.
#'
#' A distinguished name as a list of RDNs, each a set of attribute
#' type/value pairs. The flattened string is for people; constraint
#' matching needs the structure, because a prefix match is defined on
#' whole RDNs.
#' @param nd The parsed DER node of the Name.
#' @return A list of RDNs, each a list of attributes with `oid` and `value`.
#' @noRd
.rmbl_x509_rdns <- function(nd) {
  lapply(nd$children, function(rdn) {
    lapply(rdn$children, function(atv) {
      if (length(atv$children) < 2L) {
        return(NULL)
      }
      list(
        oid = .rmbl_oid_string(atv$children[[1]]$value),
        value = .rmbl_raw_text(atv$children[[2]]$value)
      )
    })
  })
}

#' Parses a NameConstraints extension value.
#'
#' NameConstraints ::= SEQUENCE { permittedSubtrees \[0\] OPTIONAL,
#'                                excludedSubtrees  \[1\] OPTIONAL }
#' @param val The extension's DER bytes.
#' @return A list with `permitted` and `excluded` subtrees, or NULL when there
#'   are none.
#' @noRd
.rmbl_name_constraints <- function(val) {
  inner <- tryCatch(.Call(C_rmbl_der_parse, val), error = function(e) NULL)
  if (is.null(inner)) {
    return(NULL)
  }
  out <- list(permitted = list(), excluded = list())
  for (part in inner$children) {
    if (!identical(part$class, 2L)) {
      next
    }
    subs <- lapply(part$children, function(gs) {
      # GeneralSubtree ::= SEQUENCE { base GeneralName, ... }
      g <- .rmbl_general_names(gs)
      if (length(g)) g[[1]] else NULL
    })
    subs <- subs[!vapply(subs, is.null, logical(1))]
    if (identical(part$tag, 0)) {
      out$permitted <- subs
    }
    if (identical(part$tag, 1)) out$excluded <- subs
  }
  if (!length(out$permitted) && !length(out$excluded)) {
    return(NULL)
  }
  out
}

#' Tells whether a DNS name is inside a DNS constraint.
#'
#' A DNS constraint of \code{"example.org"} is satisfied by \code{"example.org"}
#' and by anything under it. A leading dot, which is a convention rather than
#' the RFC's text, is read as subdomains only.
#' @param name The DNS name.
#' @param base The constraint.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_nc_match_dns <- function(name, base) {
  name <- tolower(name)
  base <- tolower(base)
  if (!nzchar(base)) {
    return(TRUE)
  }
  if (startsWith(base, ".")) {
    return(endsWith(name, base))
  }
  identical(name, base) || endsWith(name, paste0(".", base))
}

#' Tells whether a mailbox is inside an email constraint.
#'
#' An email constraint may be a full mailbox, a host, or a dot-prefixed
#' domain. A host constraint is NOT satisfied by a subdomain of it, which
#' is where this differs from DNS and where a verifier that reuses the
#' DNS rule becomes too permissive.
#' @param name The mailbox.
#' @param base The constraint.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_nc_match_email <- function(name, base) {
  name <- tolower(name)
  base <- tolower(base)
  if (grepl("@", base, fixed = TRUE)) {
    return(identical(name, base))
  }
  host <- sub("^[^@]*@", "", name)
  if (startsWith(base, ".")) {
    return(endsWith(host, base))
  }
  identical(host, base)
}

#' Tells whether a URI's host is inside a DNS-style constraint.
#' @param name The URI.
#' @param base The constraint.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_nc_match_uri <- function(name, base) {
  host <- sub("^[a-zA-Z][a-zA-Z0-9+.-]*://", "", name)
  host <- sub("[/?#].*$", "", host)
  host <- sub("^[^@]*@", "", host)
  host <- sub(":[0-9]*$", "", host)
  .rmbl_nc_match_dns(host, base)
}

#' Tells whether an IP address is inside an address-and-mask constraint.
#'
#' The constraint is the address followed by the mask, so 8 bytes for
#' IPv4 and 32 for IPv6.
#' @param name The address bytes.
#' @param base The constraint: the address bytes followed by the mask bytes.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_nc_match_ip <- function(name, base) {
  n <- length(name)
  if (length(base) != 2L * n) {
    return(FALSE)
  }
  addr <- as.integer(base[seq_len(n)])
  mask <- as.integer(base[n + seq_len(n)])
  ip <- as.integer(name)
  all(bitwAnd(ip, mask) == bitwAnd(addr, mask))
}

#' Tells whether a directory name is inside a directory name constraint.
#'
#' A directory name constraint matches when its RDNs are an initial
#' sequence of the name's, compared whole: \dQuote{O=Acme} does not match
#' \dQuote{O=AcmeCorp}, and a partial attribute value never matches.
#' @param rdns The name's RDNs, as from `.rmbl_x509_rdns()`.
#' @param base The constraint's RDNs.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_nc_match_dirname <- function(rdns, base) {
  if (!length(base)) {
    return(TRUE)
  }
  if (length(rdns) < length(base)) {
    return(FALSE)
  }
  norm <- function(atvs) {
    v <- vapply(
      Filter(Negate(is.null), atvs),
      function(a) {
        paste0(a$oid, "=", tolower(trimws(a$value)))
      },
      character(1)
    )
    paste(sort(v), collapse = "+")
  }
  for (i in seq_along(base)) {
    if (!identical(norm(rdns[[i]]), norm(base[[i]]))) return(FALSE)
  }
  TRUE
}

#' Matches a name against a constraint of the same type.
#' @param nm A name, a list with `type` and `value`.
#' @param base A constraint, a list with `type` and `value`.
#' @return TRUE or FALSE, or NA when the types differ or the type is not
#'   handled.
#' @noRd
.rmbl_nc_match <- function(nm, base) {
  if (!identical(nm$type, base$type)) {
    return(NA)
  }
  switch(
    nm$type,
    dns = .rmbl_nc_match_dns(nm$value, base$value),
    email = .rmbl_nc_match_email(nm$value, base$value),
    uri = .rmbl_nc_match_uri(nm$value, base$value),
    ip = .rmbl_nc_match_ip(nm$value, base$value),
    dirname = .rmbl_nc_match_dirname(nm$value, base$value),
    NA
  )
}

#' Check one certificate's names against one CA's constraints.
#'
#' The asymmetry is in the RFC and is easy to get backwards: an excluded
#' subtree rejects on any match, while permitted subtrees only bite for
#' name types they actually mention. A certificate carrying no name of a
#' constrained type is not rejected on that type -- otherwise every
#' constraint on email would reject every certificate without one.
#' @param cert A parsed certificate, with `san` and `subject_rdns`.
#' @param nc The CA's constraints, as from `.rmbl_name_constraints()`.
#' @return A character vector of problems, empty when the names pass.
#' @noRd
.rmbl_nc_check_one <- function(cert, nc) {
  names_to_check <- cert$san
  if (length(cert$subject_rdns)) {
    names_to_check <- c(
      names_to_check,
      list(list(type = "dirname", value = cert$subject_rdns))
    )
  }
  problems <- character(0)
  for (ex in nc$excluded) {
    for (nm in names_to_check) {
      hit <- .rmbl_nc_match(nm, ex)
      if (isTRUE(hit)) {
        problems <- c(
          problems,
          sprintf(
            "%s '%s' is inside an excluded subtree",
            nm$type,
            .rmbl_nc_show(nm)
          )
        )
      }
    }
  }
  c(problems, .rmbl_nc_outside(names_to_check, nc$permitted))
}

#' Formats a name for a message.
#' @param nm A name, a list with `type` and `value`.
#' @return One string.
#' @noRd
.rmbl_nc_show <- function(nm) {
  if (identical(nm$type, "dirname")) {
    parts <- unlist(lapply(nm$value, function(rdn) {
      vapply(
        Filter(Negate(is.null), rdn),
        function(a) {
          paste0(a$oid, "=", a$value)
        },
        character(1)
      )
    }))
    return(toString(parts))
  }
  if (identical(nm$type, "ip")) {
    return(paste(as.integer(nm$value), collapse = "."))
  }
  as.character(nm$value)
}

#' The names a certificate carries outside every permitted subtree of
#' their type.
#' @param names_to_check The certificate's names.
#' @param permitted The permitted subtrees.
#' @return A character vector of problems, empty when none.
#' @noRd
.rmbl_nc_outside <- function(names_to_check, permitted) {
  problems <- character(0)
  types <- unique(vapply(permitted, `[[`, character(1), "type"))
  for (ty in types) {
    mine <- Filter(function(n) identical(n$type, ty), names_to_check)
    if (!length(mine)) {
      next
    }
    bases <- Filter(function(b) identical(b$type, ty), permitted)
    for (nm in mine) {
      if (
        !any(vapply(
          bases,
          function(b) isTRUE(.rmbl_nc_match(nm, b)),
          logical(1)
        ))
      ) {
        problems <- c(
          problems,
          sprintf(
            "%s '%s' is outside every permitted subtree",
            ty,
            .rmbl_nc_show(nm)
          )
        )
      }
    }
  }
  problems
}
