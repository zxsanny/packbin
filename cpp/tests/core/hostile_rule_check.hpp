// Host-only: the pack-case half of the hostile suite (hostile_host_tests.cpp). Loads each pack case
// of fixtures/hostile/cases.txt through hostile_pack_loop21.hpp, checks the outcome and, for a
// refusal, the error its rule table entry names (AZ-2392), and proves that a wrong entry fails (AZ-2418).

#pragma once

#include <string>
#include <vector>

struct Case {
  std::string id, stage, expected, hex;
};

// Runs every pack case, then the AZ-2418 wrong-rule checks. Reports through check::expect.
void run_hostile_pack_checks(std::vector<Case> const& packs);
