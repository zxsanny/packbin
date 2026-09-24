CXX ?= g++
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra -Werror -Iinclude
ifdef PACKBIN_CXX_SYSROOT
CXXFLAGS += -isysroot $(PACKBIN_CXX_SYSROOT) -I$(PACKBIN_CXX_SYSROOT)/usr/include/c++/v1
endif
SRCS := src/field.cpp src/packbin.cpp src/counted.cpp
TEST_SRC := tests/packbin_tests.cpp
TEST_BIN := build/packbin_tests

.PHONY: test clean

$(TEST_BIN): $(SRCS) $(TEST_SRC) include/packbin/packbin.hpp
	mkdir -p build
	$(CXX) $(CXXFLAGS) -o $@ $(SRCS) $(TEST_SRC)

test: $(TEST_BIN)
	./$(TEST_BIN)

clean:
	rm -rf build
