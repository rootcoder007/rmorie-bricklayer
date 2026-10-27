# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Certificate policies (RFC 5280 sections 4.2.1.4, 4.2.1.5, 6.1).
#
# A policy identifier says what a certificate was issued FOR: which
# practices its CA followed, which audit it sits under. A relying party
# that cares only accepts a path whose every certificate carries an
# acceptable policy -- and the path is allowed to translate between
# policy identifiers as it descends, which is what policy mapping is.
#
# What is implemented here is the state machine RFC 5280 section 6.1
# describes, with its three counters and the valid-policy tree, reduced
# to what determines the outcome: the set of policies valid for the
# whole path. What is NOT implemented is qualifier processing -- the
# user notices and CPS pointers attached to a policy are parsed past,
# not surfaced -- so a caller who needs to display a notice to a human
# will not find it here.

kAnyPolicy <- "2.5.29.32.0"

#' An absent field is NA, not NULL.
#'
#' `is.na(NULL)` is logical(0), and `if (logical(0))` is an error, not
#' FALSE -- so reading a counter straight out of a list that happens not
#' to carry it fails rather than defaulting. certprs() always sets
#' these, but a certificate built by hand, or one round-tripped through
#' JSON where NA became null, does not.
#' @param x A field read from a certificate list, possibly NULL.
#' @return One integer, NA when the field is absent.
#' @noRd
.rmbl_na_int <- function(x) {
  if (is.null(x) || !length(x)) {
    return(NA_integer_)
  }
  suppressWarnings(as.integer(x)[1L])
}

#' Reads a field as character, giving `character(0)` for NULL.
#' @param x A field read from a certificate list, possibly NULL.
#' @return A character vector.
#' @noRd
.rmbl_chr0 <- function(x) {
  if (is.null(x)) character(0) else as.character(x)
}

#' The policy set valid for a path, working from the anchor down.
#'
#' `path` is leaf-first, as certchnvrf() builds it; the algorithm
#' runs root-first, which is why it is reversed. The counters start at
#' the number of certificates and are decremented as the standard says:
#' a value of zero at a certificate means the constraint is in force for
#' that certificate onward, which is why they are tested before being
#' decremented.
#' @param path The certificate path, leaf first.
#' @param initial The initial policy set the caller accepts.
#' @return A list with the valid policy set, the authorities it is constrained
#'   to, the explicit-policy and inhibit flags, the mappings seen, notes, and
#'   `ok`.
#' @noRd
.rmbl_policy_tree <- function(path, initial = kAnyPolicy) {
  certs <- rev(path) # anchor first
  n <- length(certs)
  # the anchor's own policies do not constrain; processing starts with
  # the any-policy at the top
  st <- .rmbl_pt_start()

  for (i in seq_len(n)) {
    cert <- certs[[i]]
    st <- .rmbl_pt_counters(st)
    if (i > 1L) {
      st <- .rmbl_pt_policies(st, cert, i)
    }
    # policy mapping, unless inhibited: a mapped policy continues under
    # its new name
    if (i != n && length(cert$policy_mappings)) {
      st <- .rmbl_pt_mappings(st, cert, i)
    }
    st <- .rmbl_pt_constraints(st, cert)
  }

  .rmbl_pt_result(st, initial)
}

#' The policy tree's counters, one certificate on: each comes into force
#' when it reaches zero.
#' @param st The tree's state.
#' @return The state.
#' @noRd
.rmbl_pt_counters <- function(st) {
  flags <- c(
    explicit_after = "explicit_required",
    inhibit_map_after = "mapping_inhibited",
    inhibit_any_after = "any_inhibited"
  )
  for (k in names(flags)) {
    if (!is.na(st[[k]])) {
      if (st[[k]] <= 0L) {
        st[[flags[[k]]]] <- TRUE
      }
      st[[k]] <- st[[k]] - 1L
    }
  }
  st
}

#' The policies still valid, intersected with a certificate's.
#' @param st The tree's state.
#' @param cert The certificate.
#' @param i Its place in the path, anchor first.
#' @return The state.
#' @noRd
.rmbl_pt_policies <- function(st, cert, i) {
  have <- .rmbl_chr0(cert$policies)
  if (!length(have)) {
    # A certificate with no policies extension prunes the tree
    # entirely. That is only fatal where an explicit policy is
    # required, which is the distinction the counters exist for.
    st$valid <- character(0)
    st$notes <- c(st$notes, sprintf("[%d] states no certificate policies", i))
  } else if (kAnyPolicy %in% have && !st$any_inhibited) {
    # anyPolicy asserts everything still valid
    st$notes <- c(st$notes, sprintf("[%d] asserts anyPolicy", i))
  } else {
    have <- setdiff(have, kAnyPolicy)
    st$valid <- if (identical(st$valid, kAnyPolicy)) {
      have
    } else {
      intersect(st$valid, have)
    }
  }
  st
}

#' A certificate's policy mappings, applied to the policies still valid.
#' @param st The tree's state.
#' @param cert The certificate, with mappings.
#' @param i Its place in the path, anchor first.
#' @return The state.
#' @noRd
.rmbl_pt_mappings <- function(st, cert, i) {
  if (st$mapping_inhibited) {
    st$notes <- c(
      st$notes,
      sprintf("[%d] asserts policy mappings while mapping is inhibited", i)
    )
    st$valid <- character(0)
    return(st)
  }
  for (m in cert$policy_mappings) {
    if (identical(m$issuer, kAnyPolicy) || identical(m$subject, kAnyPolicy)) {
      # mapping to or from anyPolicy is forbidden
      st$notes <- c(st$notes, sprintf("[%d] maps to or from anyPolicy", i))
      st$valid <- character(0)
      next
    }
    st$mappings_seen[[length(st$mappings_seen) + 1L]] <- m
    if (m$issuer %in% st$valid) {
      st$valid <- unique(c(setdiff(st$valid, m$issuer), m$subject))
    }
  }
  st
}

#' The constraints a certificate imposes on the rest of the path.
#' @param st The tree's state.
#' @param cert The certificate.
#' @return The state.
#' @noRd
.rmbl_pt_constraints <- function(st, cert) {
  v <- c(
    explicit_after = .rmbl_na_int(cert$require_explicit_policy),
    inhibit_map_after = .rmbl_na_int(cert$inhibit_policy_mapping),
    inhibit_any_after = .rmbl_na_int(cert$inhibit_any_policy)
  )
  for (k in names(v)) {
    if (!is.na(v[[k]])) {
      st[[k]] <- min(c(st[[k]], v[[k]]), na.rm = TRUE)
    }
  }
  st
}

#' The policy tree's state before the first certificate.
#' @return The state: the any-policy valid, no counter set, nothing seen.
#' @noRd
.rmbl_pt_start <- function() {
  list(
    valid = kAnyPolicy,
    mappings_seen = list(),
    explicit_after = NA_integer_, # require_explicit_policy
    inhibit_map_after = NA_integer_,
    inhibit_any_after = NA_integer_,
    explicit_required = FALSE,
    any_inhibited = FALSE,
    mapping_inhibited = FALSE,
    notes = character(0)
  )
}

#' The result of .rmbl_policy_tree() from the state after the path.
#' @param st The tree's state after the last certificate.
#' @param initial The initial policy set the caller accepts.
#' @return As for .rmbl_policy_tree().
#' @noRd
.rmbl_pt_result <- function(st, initial) {
  valid <- st$valid
  initial <- as.character(initial)
  wanted <- if (!length(initial) || kAnyPolicy %in% initial) {
    valid
  } else if (identical(valid, kAnyPolicy)) {
    initial
  } else {
    intersect(valid, initial)
  }

  list(
    valid = valid,
    authorities_constrained_to = wanted,
    explicit_required = st$explicit_required,
    anyinh = st$any_inhibited,
    mapinh = st$mapping_inhibited,
    mappings = st$mappings_seen,
    notes = st$notes,
    # A path satisfies the policy requirement when either nothing was
    # required of it, or something acceptable survived.
    ok = (!st$explicit_required &&
      (!length(initial) ||
        kAnyPolicy %in% initial)) ||
      length(wanted) > 0L
  )
}
