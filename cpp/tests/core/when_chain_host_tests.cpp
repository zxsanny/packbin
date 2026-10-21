// AZ-3132: the all-kinds image holds a source three `when`s deep (u8 m; when(m==1){ u8 k1;
// when(k1==1){ u8 k2; when(k2==1){ u8 k3; when(k3==1){ u8 b } } } }). The host build compares its
// packets and unpacked rows with the Python package (2026-10-21, scheme id 0x5b), so the Cortex-M4F
// stage measures the stack of a scheme whose bytes are known to be right. Host-only.

#include "all_kinds.hpp"

#include "check.hpp"

#include <cstddef>
#include <cstdint>

namespace {

// Python bytes of the four rows (index: 0 all true, 1 m = 0, 2 k1 = 0, 3 k2 = 0).
char const* const python_hex[] = {"5b0101010105", "5b00", "5b0100", "5b010100"};

void ac3_chain_rows_equal_python() {
  // Arrange
  for (std::size_t i = 0; i < all_kinds::chain_row_count; ++i) {
    all_kinds::ChainRow row = all_kinds::chain_sample(i);
    std::uint8_t buf[16];

    // Act
    packbin::Result p = all_kinds::chain_pack(row, buf, sizeof(buf));
    all_kinds::ChainRow back;
    check::expect(p.ok() && check::same_hex(buf, p.offset, python_hex[i]), "AC-3 chain packet equals Python");
    std::uint8_t want[16];
    std::size_t n = check::parse_hex(python_hex[i], want, sizeof(want));
    packbin::Result u = all_kinds::chain_unpack(want, n, back);

    // Assert
    check::expect(u.ok() && all_kinds::chain_mismatched(row, back) == 0,
                  "AC-3 chain Python bytes unpack to the row");
    check::expect(all_kinds::chain_failures(i) == 0, "AC-3 chain image check agrees");
  }
}

// AZ-3141: the same chain with a flag byte and one bit in every `when` body (scheme id 0x5c). Python
// bytes of the four rows (0 all held, 1 m = 0, 2 k1 = 0, 3 no d2 and k2 = 0).
char const* const flag_python_hex[] = {"5c0101070101080101090105", "5c00", "5c01010700",
                                       "5c010107010000"};

void az3141_flag_chain_rows_equal_python() {
  // Arrange
  for (std::size_t i = 0; i < all_kinds::flag_chain_row_count; ++i) {
    all_kinds::FlagChainRow row = all_kinds::flag_chain_sample(i);
    std::uint8_t buf[16];

    // Act
    packbin::Result p = all_kinds::flag_chain_pack(row, buf, sizeof(buf));
    all_kinds::FlagChainRow back;
    std::uint8_t want[16];
    std::size_t n = check::parse_hex(flag_python_hex[i], want, sizeof(want));
    packbin::Result u = all_kinds::flag_chain_unpack(want, n, back);

    // Assert
    check::expect(p.ok() && check::same_hex(buf, p.offset, flag_python_hex[i]),
                  "AZ-3141 AC-1 flag chain packet equals Python");
    check::expect(u.ok() && all_kinds::flag_chain_mismatched(row, back) == 0,
                  "AZ-3141 AC-1 flag chain Python bytes unpack to the row");
    check::expect(all_kinds::flag_chain_failures(i) == 0, "AZ-3141 AC-1 flag chain image check agrees");
  }
}

}  // namespace

int run_core_when_chain_host_tests() {
  ac3_chain_rows_equal_python();
  az3141_flag_chain_rows_equal_python();
  return check::failures();
}
