// Host-only: see hostile_rule_check.hpp.

#include "packbin/packbin.hpp"

#include "check.hpp"
#include "hostile_pack_loop21.hpp"
#include "hostile_rule_check.hpp"

#include <cstdio>
#include <string>
#include <vector>

using check::expect;

namespace {

using RefusalLookup = hostile_pack::Refusal const* (*)(std::string const&);

// AZ-2392: a refused case must carry the error its table entry names, so a refusal by another
// rule (another kind, or another member) fails. Answers the problem (empty when none), which
// always starts with the case id so a failure names its case.
std::string refusal_problem(Case const& c, RefusalLookup lookup) {
  auto const* want = lookup(c.id);
  if (want == nullptr)
    return "hostile " + c.id + " has no refusal entry";
  auto const& got = hostile_pack::last_result;
  if (got.error == want->error && got.field == want->field)
    return "";
  return "hostile " + c.id + ": refused with error " + std::to_string(static_cast<int>(got.error)) +
         " field " + std::to_string(got.field) + ", table says " +
         std::to_string(static_cast<int>(want->error)) + " field " + std::to_string(want->field);
}

// One pack case against the loader: run or skip exactly once, the outcome the file names, and for
// a refusal the error its table entry names. Answers the problem, empty when the case passes.
std::string pack_case_problem(Case const& c, RefusalLookup lookup) {
  auto out = hostile_pack::outcome_of_all(c.id);
  if (out.ran == out.skipped)
    return "hostile " + c.id + " is neither run nor skipped exactly once";
  if (out.skipped) {
    if (out.text.empty())
      return "hostile " + c.id + " skip names no reason";
    std::printf("hostile %s skipped: %s\n", c.id.c_str(), out.text.c_str());
    return "";
  }
  bool ok = c.expected == "bytes" ? out.text == c.hex
                                  : c.expected == "pack_error" && out.text == c.expected;
  if (!ok)
    return "hostile " + c.id + ": got " + out.text + ", expected " + c.expected + " " + c.hex;
  return c.expected == "pack_error" ? refusal_problem(c, lookup) : "";
}

void pack_cases(std::vector<Case> const& packs) {
  expect(!packs.empty(), "pack cases found");
  for (auto const& c : packs) {
    auto problem = pack_case_problem(c, hostile_pack::refusal_of);
    if (!problem.empty())
      std::fprintf(stderr, "%s\n", problem.c_str());
    expect(problem.empty(), "hostile pack case outcome");
  }
}

// AZ-2418 AC-2: a rule table that is wrong cannot pass. The loader gets a table whose entry for a
// real refused case is deliberately wrong (built here, nothing on disk changes) and must fail
// naming that case; the right entry, a missing entry and a wrong field or kind are all checked.
Case const kRefusedCase{"pack_missing_required_value", "pack", "pack_error", "-"};

hostile_pack::Refusal const* wrong_field(std::string const&) {
  static hostile_pack::Refusal const r{"pack_missing_required_value", packbin::Error::BadValue, 99};
  return &r;
}

hostile_pack::Refusal const* wrong_kind(std::string const&) {
  static hostile_pack::Refusal const r{"pack_missing_required_value", packbin::Error::TypeMismatch,
                                       1};
  return &r;
}

hostile_pack::Refusal const* no_entry(std::string const&) { return nullptr; }

bool names_the_case(std::string const& problem) {
  return problem.rfind("hostile pack_missing_required_value", 0) == 0;
}

void wrong_rule_entry_fails_the_loader() {
  expect(pack_case_problem(kRefusedCase, hostile_pack::refusal_of).empty(),
         "AZ-2418 the real entry passes the loader");
  for (auto lookup : {wrong_field, wrong_kind, no_entry}) {
    auto problem = pack_case_problem(kRefusedCase, lookup);
    if (problem.empty() || !names_the_case(problem))
      std::fprintf(stderr, "wrong rule entry not caught: [%s]\n", problem.c_str());
    expect(!problem.empty() && names_the_case(problem),
           "AZ-2418 AC-2 a wrong rule entry fails the loader naming its case");
  }
}

}  // namespace

void run_hostile_pack_checks(std::vector<Case> const& packs) {
  pack_cases(packs);
  wrong_rule_entry_fails_the_loader();
}
