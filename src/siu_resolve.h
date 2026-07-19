// SPDX-License-Identifier: AGPL-3.0-or-later
// Canonical home of the SIU parse/resolve core. The standalone `siu`
// package (github.com/rootcoder007/siu) mirrors these sources; edit here
// first, then resync the mirror.
//
// resolve.hpp -- deterministic extraction of count-type fields (e.g. the
// subject-officer count) from an SIU director's report, for the residual the
// LLM panel leaves unresolved. Text-only, no model, fully reproducible.
#pragma once
#include <optional>
#include <string>

namespace siu {

// The resolved subject-officer count plus the human-readable evidence for it.
struct SoResolution {
    std::optional<int> count;  // nullopt = needs a human read
    std::string reason;        // why this count (or why unresolved)
};

// Strip the standard SIU privacy boilerplate ("This information may include ...
// Subject Officer name(s) ...") so it never counts as a substantive mention.
std::string strip_boilerplate(const std::string& report_text);

// Resolve the subject-officer count from report text. Rule order (most specific
// first) mirrors resolve_so_residual.py:
//   1. highest "SO #N" / "Subject Officer #N" ordinal   -> N
//   2. spelled-out / numeric plural ("the two ... officers") -> that number
//   3. a subject officer is PRESENT (singular "the SO" / "the subject official",
//      no plural)                                        -> 1
//   4. witness-officer-only / "not a subject official" / "undesignated officer"
//      / "no subject official(s)"                        -> 0
//   5. otherwise                                         -> unresolved
// Rule 3 MUST precede rule 4: a 1-SO report often also says some witness
// officer "is not a subject official".
SoResolution resolve_subject_officers(const std::string& report_text);

}  // namespace siu
