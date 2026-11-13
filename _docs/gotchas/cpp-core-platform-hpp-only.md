---
title: "The C++ core takes standard names only from packbin/platform.hpp"
applies_when: "editing cpp/include/packbin or cpp/src/core (includes, traits, arrays) or the generated text_tables.hpp"
source: "loop 44 (AZ-2068, cpp-avr-uno target)"
---

The C++ core (`cpp/include/packbin`, `cpp/src/core`) takes standard names only from `packbin/platform.hpp` (loop 44, AZ-2068): no `<cstdint>`, `<type_traits>`, `<array>` there, traits come from `packbin::detail` and arrays are `detail::FixedArray`, or the `cpp-avr-uno` target (avr-gcc 7.3, no C++ library, 16-bit `int` and `size_t`, no `__builtin_is_constant_evaluated`) fails.

A test file includes what it uses (`container_tests.cpp` had `<initializer_list>` through `<array>`), and the generated `text_tables.hpp` changes only through `scripts/text/emit_tables.py`.
