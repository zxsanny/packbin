CXX ?= g++
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra -Werror -Iinclude
SRCS := src/field.cpp src/packbin.cpp
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
