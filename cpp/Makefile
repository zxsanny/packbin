CXX ?= g++
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra -Werror -Iinclude
ifdef PACKBIN_CXX_SYSROOT
CXXFLAGS += -isysroot $(PACKBIN_CXX_SYSROOT) -I$(PACKBIN_CXX_SYSROOT)/usr/include/c++/v1
endif
# The core builds the embedded way on the host too.
CORE_FLAGS := -fno-exceptions -fno-rtti
HDRS := $(wildcard include/packbin/*.hpp) src/core/values.hpp
# Firmware compiles CORE_SRCS only; HOST_SRCS hold the operating-system random source.
CORE_SRCS := src/core/values.cpp src/core/pack.cpp src/core/unpack.cpp src/core/session.cpp
HOST_SRCS := src/os_random.cpp
# VECTOR_TESTS are shared with the firmware runner; HOST_TESTS need an operating system.
VECTOR_TESTS := tests/core/scalar_tests.cpp tests/core/scheme_tests.cpp tests/core/grouped_tests.cpp tests/core/counted_tests.cpp tests/core/container_tests.cpp tests/core/session_tests.cpp
HOST_TESTS := tests/core/main.cpp tests/core/host_tests.cpp tests/core/session_host_tests.cpp tests/core/hostile_host_tests.cpp
TEST_BIN := build/packbin_tests
EXPECT_FAIL := ./tests/compile-fail/expect-fail.sh "$(CXX) $(CXXFLAGS) $(CORE_FLAGS) -fsyntax-only"

.PHONY: test core-test clean compile-fail

$(TEST_BIN): $(HDRS) $(CORE_SRCS) $(HOST_SRCS) $(VECTOR_TESTS) $(HOST_TESTS) tests/core/check.hpp
	mkdir -p build
	$(CXX) $(CXXFLAGS) $(CORE_FLAGS) -pthread -o $@ $(CORE_SRCS) $(HOST_SRCS) $(VECTOR_TESTS) $(HOST_TESTS)

# Each case must fail to compile, and the compiler output must match the expected text.
compile-fail: $(HDRS)
	@mkdir -p build
	@$(EXPECT_FAIL) tests/compile-fail/pack_without_scheme.cpp "no matching function"
	@$(EXPECT_FAIL) tests/compile-fail/f64_needs_8_byte_double.cpp "f64 needs an 8-byte double"
	@$(EXPECT_FAIL) tests/compile-fail/scheme_gap.cpp "breaks_order<2>|Id = 2\]"
	@$(EXPECT_FAIL) tests/compile-fail/scheme_repeated_id.cpp "breaks_order<0>|Id = 0\]"
	@$(EXPECT_FAIL) tests/compile-fail/scheme_wrong_anchor.cpp "breaks_order<7>|Id = 7\]"
	@$(EXPECT_FAIL) tests/compile-fail/scheme_when_ahead.cpp "breaks_order<0>|Id = 0\]"
	@$(EXPECT_FAIL) tests/compile-fail/flags_overflow.cpp "breaks_order<0>|Id = 0\]"
	@$(EXPECT_FAIL) tests/compile-fail/bool_outside_flags.cpp "breaks_order<0>|Id = 0\]"
	@$(EXPECT_FAIL) tests/compile-fail/empty_group_outside_flags.cpp "breaks_order<1>|Id = 1\]"
	@$(EXPECT_FAIL) tests/compile-fail/empty_group_without_member.cpp "breaks_order<0>|Id = 0\]"
	@$(EXPECT_FAIL) tests/compile-fail/u2_too_wide.cpp "breaks_order<0>|Id = 0\]"

test: $(TEST_BIN) compile-fail
	./$(TEST_BIN)

core-test: test

clean:
	rm -rf build
