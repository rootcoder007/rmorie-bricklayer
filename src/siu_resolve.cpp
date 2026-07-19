// SPDX-License-Identifier: AGPL-3.0-or-later
// Canonical home of the SIU parse/resolve core. The standalone `siu`
// package (github.com/rootcoder007/siu) mirrors these sources; edit here
// first, then resync the mirror.
#include "siu_resolve.h"

#include <algorithm>
#include <array>
#include <regex>
#include <unordered_map>

namespace siu {
namespace {

const std::unordered_map<std::string, int> kWordNum = {
    {"one", 1}, {"two", 2}, {"three", 3}, {"four", 4},  {"five", 5},
    {"six", 6}, {"seven", 7}, {"eight", 8}, {"nine", 9}, {"ten", 10}};

int count_matches(const std::string& s, const std::regex& re) {
    return static_cast<int>(
        std::distance(std::sregex_iterator(s.begin(), s.end(), re),
                      std::sregex_iterator()));
}

}  // namespace

std::string strip_boilerplate(const std::string& t) {
    // The privacy paragraph runs from "this information may include" to the
    // first "affected person" / "evidence". Remove every occurrence.
    static const std::regex kBoiler(
        R"(this information may include[\s\S]*?(?:affected person|evidence)\.?)",
        std::regex::icase);
    return std::regex_replace(t, kBoiler, " ");
}

SoResolution resolve_subject_officers(const std::string& report_text) {
    const std::string body = strip_boilerplate(report_text);

    // 1. Highest explicit ordinal: "SO #3", "Subject Officer #2", "SO 2".
    static const std::regex kOrd(
        R"((?:subject offic(?:er|ial)|SO)\s*#?\s*(\d{1,2})\b)",
        std::regex::icase);
    int max_ord = 0;
    for (auto it = std::sregex_iterator(body.begin(), body.end(), kOrd);
         it != std::sregex_iterator(); ++it) {
        max_ord = std::max(max_ord, std::stoi((*it)[1].str()));
    }
    if (max_ord > 0) {
        return {max_ord, "max ordinal SO #" + std::to_string(max_ord)};
    }

    // 2. Spelled-out / numeric plural: "the two subject officials".
    static const std::regex kPlural(
        R"(\bthe\s+(\d{1,2}|one|two|three|four|five|six|seven|eight|nine|ten)\s+subject offic(?:er|ial)s\b)",
        std::regex::icase);
    std::smatch m;
    if (std::regex_search(body, m, kPlural)) {
        const std::string tok = m[1].str();
        int n = 0;
        std::string low = tok;
        std::transform(low.begin(), low.end(), low.begin(), ::tolower);
        auto wit = kWordNum.find(low);
        n = (wit != kWordNum.end()) ? wit->second : std::stoi(tok);
        return {n, "plural cue '" + m[0].str() + "'"};
    }

    // 3. A subject officer is PRESENT (runs BEFORE the zero-rule).
    // "SO" stays case-strict (icase would match "the so-called"); only the
    // article is sentence-initial-tolerant.
    static const std::regex kTheSo(R"(\b[Tt]he SO\b)");
    static const std::regex kTheSubj(R"(\bthe subject offic(?:er|ial)\b)",
                                     std::regex::icase);
    static const std::regex kAnyPlural(
        R"(\bthe SOs\b|the subject offic(?:er|ial)s\b)", std::regex::icase);
    const int the_so = count_matches(body, kTheSo);
    const int the_subj = count_matches(body, kTheSubj);
    const bool plural = std::regex_search(body, kAnyPlural);
    if ((the_so + the_subj) >= 1 && !plural) {
        return {1, "singular present: 'the SO'x" + std::to_string(the_so) +
                       " 'the subject official'x" + std::to_string(the_subj)};
    }

    // 4. Explicitly ZERO subject officers (witness-officer-only cases).
    static const std::array<std::regex, 4> kZero = {
        std::regex(R"(no subject offic(?:er|ial)s?\b)", std::regex::icase),
        std::regex(
            R"((?:did not|not|never)\s+designate[d]?\s+(?:a\s+|any\s+)?subject offic)",
            std::regex::icase),
        std::regex(R"(\bundesignated offic(?:er|ial)\b)", std::regex::icase),
        std::regex(R"(\b(?:is|was)\s+not\s+a\s+subject offic(?:er|ial)\b)",
                   std::regex::icase)};
    for (const auto& re : kZero) {
        if (std::regex_search(body, re)) {
            return {0, "zero: witness-officer-only / 'not a subject official'"};
        }
    }

    // 5. Needs a human read.
    return {std::nullopt, "UNRESOLVED: 'the SO'x" + std::to_string(the_so) +
                              " 'the subj off'x" + std::to_string(the_subj)};
}

}  // namespace siu
