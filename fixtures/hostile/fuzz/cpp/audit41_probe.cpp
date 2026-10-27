// AZ-2666 loop 41 security audit probe: C++ compact-text decoder and message ECC unpack path.
//
// Self-contained: it includes the core headers (cpp/include, cpp/src/core) of a checkout and
// links the four core sources. Inputs are copied into heap buffers of their exact size, so an
// AddressSanitizer build reports any read or write past them; a refused repair must leave its
// buffer unchanged (checked byte for byte).
//
// Files (this directory): audit41_probe.cpp (this entry point), probe_common.hpp (shared helpers,
// rows and schemes), probe_text_fuzz.cpp, probe_ecc_fuzz.cpp, probe_edge.cpp, probe_timing.cpp.
//
// Build (from any directory; REPO is a checkout or a `git archive HEAD cpp fixtures` copy). The
// script next to this file does both builds: `build_cpp.sh "$REPO" <this directory> <out dir>`.
// With Command Line Tools only, clang also needs -I"$SDK/usr/include/c++/v1" (as the Makefile's
// PACKBIN_CXX_SYSROOT adds); the script passes it. By hand (PROBE is this directory):
//   SDK="$(xcrun --show-sdk-path)"   # macOS only; drop -isysroot elsewhere
//   CORE="$REPO/cpp/src/core/values.cpp $REPO/cpp/src/core/pack.cpp $REPO/cpp/src/core/unpack.cpp $REPO/cpp/src/core/crypto.cpp"
//   INC="-isysroot $SDK -I$SDK/usr/include/c++/v1 -I$REPO/cpp/include -I$REPO/cpp/src/core -I$PROBE"
//   # sanitizer build (the fuzz and edge modes)
//   clang++ -std=c++17 -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined \
//     -fno-sanitize-recover=all $INC $CORE "$PROBE"/*.cpp -o probe_asan
//   # timing build (the worst-case modes)
//   clang++ -std=c++17 -O2 $INC $CORE "$PROBE"/*.cpp -o probe_o2
//
// Run (FIX is "$REPO/fixtures"; every mode ends on its own):
//   probe_asan text-fuzz FIX <seed> <seconds>   random + mutated string fields: direct decoder and unpack
//   probe_asan ecc-fuzz  FIX <seed> <seconds>   random + mutated protected messages through the API
//   probe_asan edge      FIX                    the AC edge cases (exits 1 on any failed expectation)
//   probe_o2   ecc-worst <iterations>           254-byte buffers at n = 32: slowest and median per call
//   probe_o2   text-amp                         largest accepted text, many max texts in one packet
//   probe_o2   text-long                        a 2,097,151-byte payload that decodes to no text
//   probe_o2   dict-quad <entries>              a dict of <entries> distinct keys (duplicate-key check cost)
// Each mode prints key=value lines and a final "result=PASS" or "result=FAIL".

#include "probe_common.hpp"

int main(int argc, char** argv) {
  if (argc < 2) {
    std::fprintf(stderr, "usage: see the header comment\n");
    return 2;
  }
  std::string mode = argv[1];
  if (mode == "text-fuzz" && argc == 5)
    return probe::text_fuzz(argv[2], std::strtoull(argv[3], nullptr, 10), std::atof(argv[4]));
  if (mode == "ecc-fuzz" && argc == 5)
    return probe::ecc_fuzz(argv[2], std::strtoull(argv[3], nullptr, 10), std::atof(argv[4]));
  if (mode == "edge" && argc == 3)
    return probe::edge(argv[2]);
  if (mode == "ecc-worst" && argc == 3)
    return probe::ecc_worst(std::strtoull(argv[2], nullptr, 10));
  if (mode == "text-amp")
    return probe::text_amp();
  if (mode == "text-long")
    return probe::text_long();
  if (mode == "dict-quad" && argc == 3)
    return probe::dict_quad(std::strtoull(argv[2], nullptr, 10));
  std::fprintf(stderr, "usage: see the header comment\n");
  return 2;
}
