CXX ?= g++
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra -Werror -Iinclude
ifdef PACKBIN_CXX_SYSROOT
CXXFLAGS += -isysroot $(PACKBIN_CXX_SYSROOT) -I$(PACKBIN_CXX_SYSROOT)/usr/include/c++/v1
endif
SRCS := src/field.cpp src/packbin.cpp src/counted.cpp
TEST_SRC := tests/packbin_tests.cpp tests/scheme_tests.cpp
TEST_BIN := build/packbin_tests
COMPILE_FAIL_SRC := tests/compile-fail/pack_without_scheme.cpp

.PHONY: test clean compile-fail

$(TEST_BIN): $(SRCS) $(TEST_SRC) include/packbin/packbin.hpp
	mkdir -p build
	$(CXX) $(CXXFLAGS) -o $@ $(SRCS) $(TEST_SRC)

compile-fail: include/packbin/packbin.hpp $(COMPILE_FAIL_SRC)
	@if $(CXX) $(CXXFLAGS) -fsyntax-only $(COMPILE_FAIL_SRC) >/tmp/packbin_compile_fail.out 2>&1; then \
		echo "AC-3: expected compile failure for pack without scheme"; \
		cat /tmp/packbin_compile_fail.out; \
		exit 1; \
	else \
		echo "AC-3: pack without scheme correctly rejected by compiler"; \
	fi

test: $(TEST_BIN) compile-fail
	./$(TEST_BIN)

clean:
	rm -rf build
