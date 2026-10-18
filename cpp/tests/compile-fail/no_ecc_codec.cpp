// Built with -DPACKBIN_NO_ECC: the codec header declares nothing.
#include "packbin/ecc.hpp"

int main() {
  unsigned char word[4] = {0, 0, 0, 0};
  return packbin::ecc::check(word, 4, 2).ok() ? 0 : 1;
}
