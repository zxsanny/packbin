CXX ?= g++
# FRAME_LIMIT: a stack frame over 64 KB is a bug here; it catches a local Scratch<N> above 5,461 characters.
FRAME_LIMIT := 65536
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra -Werror -Wframe-larger-than=$(FRAME_LIMIT) -Iinclude
ifdef PACKBIN_CXX_SYSROOT
CXXFLAGS += -isysroot $(PACKBIN_CXX_SYSROOT) -I$(PACKBIN_CXX_SYSROOT)/usr/include/c++/v1
endif
# The core builds the embedded way on the host too.
CORE_FLAGS := -fno-exceptions -fno-rtti
HDRS := $(wildcard include/packbin/*.hpp) src/core/values.hpp src/core/text.hpp src/core/text_count.hpp src/core/text_encode.hpp src/core/text_decode.hpp src/core/crypto.hpp
# The library sources; firmware compiles the same files.
CORE_SRCS := src/core/values.cpp src/core/pack.cpp src/core/unpack.cpp src/core/crypto.cpp src/core/frame.cpp
# VECTOR_TESTS are shared with the firmware runner; HOST_TESTS need an operating system.
VECTOR_TESTS := tests/core/scalar_tests.cpp tests/core/scheme_tests.cpp tests/core/grouped_tests.cpp tests/core/counted_tests.cpp tests/core/container_tests.cpp tests/core/crypto_tests.cpp tests/core/ecc_api_tests.cpp tests/core/frame_tests.cpp
HOST_TESTS := tests/core/main.cpp tests/core/host_tests.cpp tests/core/hostile_host_tests.cpp tests/core/hostile_rule_check_host_tests.cpp tests/core/flag_scope_host_tests.cpp tests/core/source_kinds_host_tests.cpp tests/core/flags_when_member_host_tests.cpp tests/core/flags_times_repeat_member_host_tests.cpp tests/core/split_form_loud_host_tests.cpp tests/core/times_count_zero_host_tests.cpp tests/core/eq_value_checked_host_tests.cpp tests/core/late_source_host_tests.cpp tests/core/held_count_nested_late_host_tests.cpp tests/core/when_skipped_source_host_tests.cpp tests/core/empty_body_rule_host_tests.cpp tests/core/packed_bias_novalue_host_tests.cpp tests/core/novalue_nested_host_tests.cpp tests/core/builder_id_range_host_tests.cpp tests/core/loop25_probe_d1_d7_host_tests.cpp tests/core/text_vectors_host_tests.cpp tests/core/text_codec_host_tests.cpp tests/core/text_api_host_tests.cpp tests/core/ecc_vectors_host_tests.cpp tests/core/ecc_repair_host_tests.cpp tests/core/ecc_api_host_tests.cpp tests/core/crypto_vectors_host_tests.cpp tests/core/dict_order_host_tests.cpp tests/core/text_repeat_host_tests.cpp tests/core/when_chain_host_tests.cpp tests/core/when_flag_bit_host_tests.cpp tests/core/when_group_source_host_tests.cpp tests/core/frame_vectors_host_tests.cpp tests/core/frame_api_host_tests.cpp tests/core/frame_readme_host_tests.cpp tests/core/frame_tag_compare_host_tests.cpp
IMAGE_SRCS := embedded/common/all_kinds.cpp embedded/common/all_kinds_rounds.cpp embedded/common/all_kinds.hpp embedded/common/all_kinds_internal.hpp
TEST_BIN := build/packbin_tests
EXPECT_FAIL := ./tests/compile-fail/expect-fail.sh "$(CXX) $(CXXFLAGS) $(CORE_FLAGS) -fsyntax-only"
EXPECT_FAIL_NO_TEXT := ./tests/compile-fail/expect-fail.sh "$(CXX) $(CXXFLAGS) $(CORE_FLAGS) -DPACKBIN_NO_TEXT -fsyntax-only"
EXPECT_FAIL_NO_ECC := ./tests/compile-fail/expect-fail.sh "$(CXX) $(CXXFLAGS) $(CORE_FLAGS) -DPACKBIN_NO_ECC -fsyntax-only"
# The core without the codec (embedded builds that define PACKBIN_NO_TEXT) and its own tests.
NO_TEXT_TESTS := tests/core/no_text_tests.cpp
NO_TEXT_BIN := build/packbin_no_text_tests
# The core without message error correction (Cortex-M4F builds define PACKBIN_NO_ECC) and its tests.
NO_ECC_TESTS := tests/core/no_ecc_tests.cpp
NO_ECC_BIN := build/packbin_no_ecc_tests

.PHONY: test core-test clean compile-fail object-check no-text-test no-ecc-test frame-check

$(TEST_BIN): $(HDRS) $(CORE_SRCS) $(VECTOR_TESTS) $(HOST_TESTS) tests/core/check.hpp tests/core/hostile_pack_cases.hpp tests/core/hostile_pack_loop21.hpp tests/core/hostile_rule_check.hpp tests/core/member_cases.hpp tests/core/ecc_support_host.hpp $(IMAGE_SRCS)
	mkdir -p build
	$(CXX) $(CXXFLAGS) $(CORE_FLAGS) -Iembedded/common -pthread -o $@ $(CORE_SRCS) $(VECTOR_TESTS) $(HOST_TESTS) embedded/common/all_kinds.cpp embedded/common/all_kinds_rounds.cpp

# The core compiled alone, the way firmware builds it, for the allocation and read-only checks.
OBJ_DIR := build/obj
CORE_OBJS := $(patsubst src/core/%.cpp,$(OBJ_DIR)/%.o,$(CORE_SRCS))

$(OBJ_DIR)/%.o: src/core/%.cpp $(HDRS)
	mkdir -p $(OBJ_DIR)
	$(CXX) $(CXXFLAGS) $(CORE_FLAGS) -c -o $@ $<

NO_TEXT_OBJ_DIR := build/obj-no-text
NO_TEXT_OBJS := $(patsubst src/core/%.cpp,$(NO_TEXT_OBJ_DIR)/%.o,$(CORE_SRCS))

$(NO_TEXT_OBJ_DIR)/%.o: src/core/%.cpp $(HDRS)
	mkdir -p $(NO_TEXT_OBJ_DIR)
	$(CXX) $(CXXFLAGS) $(CORE_FLAGS) -DPACKBIN_NO_TEXT -c -o $@ $<

NO_ECC_OBJ_DIR := build/obj-no-ecc
NO_ECC_OBJS := $(patsubst src/core/%.cpp,$(NO_ECC_OBJ_DIR)/%.o,$(CORE_SRCS))

$(NO_ECC_OBJ_DIR)/%.o: src/core/%.cpp $(HDRS)
	mkdir -p $(NO_ECC_OBJ_DIR)
	$(CXX) $(CXXFLAGS) $(CORE_FLAGS) -DPACKBIN_NO_ECC -c -o $@ $<

# AC-4: no heap, no exceptions, tables in read-only data. AZ-2656 AC-2: the same objects built
# with PACKBIN_NO_TEXT hold no codec table and no codec symbol. AZ-2688: and with PACKBIN_NO_ECC
# no message error correction table and no repair symbol.
object-check: $(CORE_OBJS) $(NO_TEXT_OBJS) $(NO_ECC_OBJS)
	sh tests/core/check-objects.sh $(CORE_OBJS)
	sh tests/core/check-objects.sh --no-text $(NO_TEXT_OBJS)
	sh tests/core/check-objects.sh --no-ecc $(NO_ECC_OBJS)
	@size $(OBJ_DIR)/pack.o $(OBJ_DIR)/unpack.o $(NO_TEXT_OBJ_DIR)/pack.o $(NO_TEXT_OBJ_DIR)/unpack.o

$(NO_TEXT_BIN): $(HDRS) $(CORE_SRCS) $(NO_TEXT_TESTS) tests/core/check.hpp
	mkdir -p build
	$(CXX) $(CXXFLAGS) $(CORE_FLAGS) -DPACKBIN_NO_TEXT -o $@ $(CORE_SRCS) $(NO_TEXT_TESTS)

$(NO_ECC_BIN): $(HDRS) $(CORE_SRCS) $(NO_ECC_TESTS) tests/core/check.hpp
	mkdir -p build
	$(CXX) $(CXXFLAGS) $(CORE_FLAGS) -DPACKBIN_NO_ECC -o $@ $(CORE_SRCS) $(NO_ECC_TESTS)

no-ecc-test: $(NO_ECC_BIN)
	./$(NO_ECC_BIN)

no-text-test: $(NO_TEXT_BIN)
	./$(NO_TEXT_BIN)
	sh tests/core/check-objects.sh --no-text-binary $(NO_TEXT_BIN)

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
	@$(EXPECT_FAIL) tests/compile-fail/flag_byte_in_flags_member.cpp "breaks_order<2>|Id = 2\]"
	@$(EXPECT_FAIL) tests/compile-fail/flag_byte_in_flag_bit_child.cpp "breaks_order<2>|Id = 2\]"
	@$(EXPECT_FAIL) tests/compile-fail/when_eq_bool_false.cpp "breaks_order<1>|Id = 1\]"
	@$(EXPECT_FAIL) tests/compile-fail/when_eq_out_of_range.cpp "breaks_order<1>|Id = 1\]"
	@$(EXPECT_FAIL) tests/compile-fail/utf8_view_member.cpp "Text<N>"
	@$(EXPECT_FAIL) tests/compile-fail/utf8_view_list_element.cpp "utf8_element_must_be_Text_N_or_Packed_not_View"
	@$(EXPECT_FAIL) tests/compile-fail/utf8_view_dict_key.cpp "utf8_element_must_be_Text_N_or_Packed_not_View"
	@$(EXPECT_FAIL) tests/compile-fail/dict_key_packed.cpp "dict_key_must_be_Text_N"
	@$(EXPECT_FAIL_NO_TEXT) tests/compile-fail/no_text_text_member.cpp "PACKBIN_NO_TEXT links no codec"
	@$(EXPECT_FAIL_NO_TEXT) tests/compile-fail/no_text_text_element.cpp "Text_N_needs_the_codec_but_PACKBIN_NO_TEXT_is_defined"
	@$(EXPECT_FAIL_NO_ECC) tests/compile-fail/no_ecc_codec.cpp "ecc"
	@$(EXPECT_FAIL) tests/compile-fail/parity_over_32.cpp "scheme_parity_not_0_to_32_or_ecc_removed"
	@$(EXPECT_FAIL_NO_ECC) tests/compile-fail/no_ecc_parity.cpp "scheme_parity_not_0_to_32_or_ecc_removed"

# RL-1: a large Scratch as a local fails the build, a static one passes.
frame-check: $(HDRS)
	@mkdir -p build
	@bash tests/frame-check.sh "$(CXX) $(CXXFLAGS) $(CORE_FLAGS) -c -o build/frame-check.o"

test: $(TEST_BIN) compile-fail object-check no-text-test no-ecc-test frame-check
	./$(TEST_BIN)

core-test: test

clean:
	rm -rf build
