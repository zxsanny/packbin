CXX ?= g++
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra -Werror -Iinclude
ifdef PACKBIN_CXX_SYSROOT
CXXFLAGS += -isysroot $(PACKBIN_CXX_SYSROOT) -I$(PACKBIN_CXX_SYSROOT)/usr/include/c++/v1
endif
CORE_FLAGS := -fno-exceptions -fno-rtti
SRCS := src/field.cpp src/packbin.cpp src/counted.cpp src/walk_common.cpp src/walk.cpp src/unpack_walk.cpp src/session.cpp
TEST_SRC := tests/packbin_tests.cpp tests/scheme_tests.cpp tests/kinds_tests.cpp tests/field_id_binding_tests.cpp tests/borrowed_count_tests.cpp tests/session_tests.cpp
TEST_BIN := build/packbin_tests
COMPILE_FAIL_SRC := tests/compile-fail/pack_without_scheme.cpp
CORE_HDRS := include/packbin/core.hpp include/packbin/table.hpp include/packbin/fields.hpp include/packbin/fields_grouped.hpp include/packbin/fields_counted.hpp include/packbin/order.hpp include/packbin/codec.hpp include/packbin/session.hpp
CORE_SRCS := src/core/values.cpp src/core/pack.cpp src/core/unpack.cpp src/core/session.cpp
HOST_ADAPTER_SRCS := src/os_random.cpp
CORE_TEST_SRC := tests/core/main.cpp tests/core/scalar_tests.cpp tests/core/scheme_tests.cpp tests/core/grouped_tests.cpp tests/core/counted_tests.cpp tests/core/container_tests.cpp tests/core/session_tests.cpp
CORE_TEST_BIN := build/core_tests

.PHONY: test clean compile-fail core-test core-compile-fail

$(TEST_BIN): $(SRCS) $(TEST_SRC) include/packbin/packbin.hpp include/packbin/scheme.hpp
	mkdir -p build
	$(CXX) $(CXXFLAGS) -o $@ $(SRCS) $(TEST_SRC)

$(CORE_TEST_BIN): $(CORE_HDRS) $(CORE_SRCS) $(HOST_ADAPTER_SRCS) src/core/values.hpp $(CORE_TEST_SRC) tests/core/check.hpp
	mkdir -p build
	$(CXX) $(CXXFLAGS) $(CORE_FLAGS) -o $@ $(CORE_SRCS) $(HOST_ADAPTER_SRCS) $(CORE_TEST_SRC)

compile-fail: include/packbin/packbin.hpp $(COMPILE_FAIL_SRC)
	@if $(CXX) $(CXXFLAGS) -fsyntax-only $(COMPILE_FAIL_SRC) >/tmp/packbin_compile_fail.out 2>&1; then \
		echo "AC-3: expected compile failure for pack without scheme"; \
		cat /tmp/packbin_compile_fail.out; \
		exit 1; \
	else \
		echo "AC-3: pack without scheme correctly rejected by compiler"; \
	fi

# Each case must fail to compile, and the compiler output must contain the expected text.
core-compile-fail: $(CORE_HDRS)
	@mkdir -p build
	@./tests/compile-fail/expect-fail.sh "$(CXX) $(CXXFLAGS) $(CORE_FLAGS) -fsyntax-only" \
		tests/compile-fail/f64_needs_8_byte_double.cpp "f64 needs an 8-byte double"
	@./tests/compile-fail/expect-fail.sh "$(CXX) $(CXXFLAGS) $(CORE_FLAGS) -fsyntax-only" \
		tests/compile-fail/scheme_gap.cpp "breaks_order<2>|Id = 2\]"
	@./tests/compile-fail/expect-fail.sh "$(CXX) $(CXXFLAGS) $(CORE_FLAGS) -fsyntax-only" \
		tests/compile-fail/scheme_repeated_id.cpp "breaks_order<0>|Id = 0\]"
	@./tests/compile-fail/expect-fail.sh "$(CXX) $(CXXFLAGS) $(CORE_FLAGS) -fsyntax-only" \
		tests/compile-fail/scheme_wrong_anchor.cpp "breaks_order<7>|Id = 7\]"
	@./tests/compile-fail/expect-fail.sh "$(CXX) $(CXXFLAGS) $(CORE_FLAGS) -fsyntax-only" \
		tests/compile-fail/scheme_when_ahead.cpp "breaks_order<0>|Id = 0\]"
	@./tests/compile-fail/expect-fail.sh "$(CXX) $(CXXFLAGS) $(CORE_FLAGS) -fsyntax-only" \
		tests/compile-fail/flags_overflow.cpp "breaks_order<0>|Id = 0\]"

core-test: $(CORE_TEST_BIN) core-compile-fail
	./$(CORE_TEST_BIN)

test: $(TEST_BIN) compile-fail core-test
	./$(TEST_BIN)

clean:
	rm -rf build
