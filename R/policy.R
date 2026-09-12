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

# An absent field is NA, not NULL.
#
# `is.na(NULL)` is logical(0), and `if (logical(0))` is an error, not
# FALSE -- so reading a counter straight out of a list that happens not
# to carry it fails rather than defaulting. cert_parse() always sets
# these, but a certificate built by hand, or one round-tripped through
# JSON where NA became null, does not.
.rmbl_na_int <- function(x) {
  if (is.null(x) || !length(x)) return(NA_integer_)
  suppressWarnings(as.integer(x)[1L])
}

.rmbl_chr0 <- function(x) {
  if (is.null(x)) character(0) else as.character(x)
}

# The policy set valid for a path, working from the anchor down.
#
# `path` is leaf-first, as cert_chain_verify() builds it; the algorithm
# runs root-first, which is why it is reversed. The counters start at
# the number of certificates and are decremented as the standard says:
# a value of zero at a certificate means the constraint is in force for
# that certificate onward, which is why they are tested before being
# decremented.
.rmbl_policy_tree <- function(path, initial = kAnyPolicy) {
  certs <- rev(path)                       # anchor first
  n <- length(certs)
  # the anchor's own policies do not constrain; processing starts with
  # the any-policy at the top
  valid <- kAnyPolicy
  mappings_seen <- list()
  explicit_after <- NA_integer_            # require_explicit_policy
  inhibit_map_after <- NA_integer_
  inhibit_any_after <- NA_integer_
  explicit_required <- FALSE
  any_inhibited <- FALSE
  mapping_inhibited <- FALSE
  notes <- character(0)

  for (i in seq_len(n)) {
    cert <- certs[[i]]
    is_last <- (i == n)

    # the counters come into force when they reach zero
    if (!is.na(explicit_after)) {
      if (explicit_after <= 0L) explicit_required <- TRUE
      explicit_after <- explicit_after - 1L
    }
    if (!is.na(inhibit_map_after)) {
      if (inhibit_map_after <= 0L) mapping_inhibited <- TRUE
      inhibit_map_after <- inhibit_map_after - 1L
    }
    if (!is.na(inhibit_any_after)) {
      if (inhibit_any_after <= 0L) any_inhibited <- TRUE
      inhibit_any_after <- inhibit_any_after - 1L
    }

    if (i > 1L) {
      # intersect the certificate's policies with what is still valid
      have <- .rmbl_chr0(cert$policies)
      if (!length(have)) {
        # A certificate with no policies extension prunes the tree
        # entirely. That is only fatal where an explicit policy is
        # required, which is the distinction the counters exist for.
        valid <- character(0)
        notes <- c(notes,
                   sprintf("[%d] states no certificate policies", i))
      } else if (kAnyPolicy %in% have && !any_inhibited) {
        # anyPolicy asserts everything still valid
        notes <- c(notes, sprintf("[%d] asserts anyPolicy", i))
      } else {
        have <- setdiff(have, kAnyPolicy)
        if (identical(valid, kAnyPolicy)) {
          valid <- have
        } else {
          valid <- intersect(valid, have)
        }
      }
    }

    # policy mapping, unless inhibited: a mapped policy continues under
    # its new name
    if (!is_last && !is.null(cert$policy_mappings) &&
        length(cert$policy_mappings)) {
      if (mapping_inhibited) {
        notes <- c(notes,
                   sprintf("[%d] asserts policy mappings while mapping is inhibited",
                           i))
        valid <- character(0)
      } else {
        for (m in cert$policy_mappings) {
          if (identical(m$issuer, kAnyPolicy) ||
              identical(m$subject, kAnyPolicy)) {
            # mapping to or from anyPolicy is forbidden
            notes <- c(notes,
                       sprintf("[%d] maps to or from anyPolicy", i))
            valid <- character(0)
            next
          }
          mappings_seen[[length(mappings_seen) + 1L]] <- m
          if (m$issuer %in% valid) {
            valid <- unique(c(setdiff(valid, m$issuer), m$subject))
          }
        }
      }
    }

    # the constraints this certificate imposes on the rest of the path
    rep_v <- .rmbl_na_int(cert$require_explicit_policy)
    map_v <- .rmbl_na_int(cert$inhibit_policy_mapping)
    any_v <- .rmbl_na_int(cert$inhibit_any_policy)
    if (!is.na(rep_v)) {
      explicit_after <- min(c(explicit_after, rep_v), na.rm = TRUE)
    }
    if (!is.na(map_v)) {
      inhibit_map_after <- min(c(inhibit_map_after, map_v), na.rm = TRUE)
    }
    if (!is.na(any_v)) {
      inhibit_any_after <- min(c(inhibit_any_after, any_v), na.rm = TRUE)
    }
  }

  initial <- as.character(initial)
  wanted <- if (!length(initial) || kAnyPolicy %in% initial) {
    valid
  } else if (identical(valid, kAnyPolicy)) {
    initial
  } else {
    intersect(valid, initial)
  }

  list(valid = valid,
       authorities_constrained_to = wanted,
       explicit_required = explicit_required,
       any_inhibited = any_inhibited,
       mapping_inhibited = mapping_inhibited,
       mappings = mappings_seen,
       notes = notes,
       # A path satisfies the policy requirement when either nothing was
       # required of it, or something acceptable survived.
       ok = (!explicit_required && (!length(initial) ||
                                    kAnyPolicy %in% initial)) ||
         length(wanted) > 0L)
}
