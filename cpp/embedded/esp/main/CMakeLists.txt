get_filename_component(common "${CMAKE_CURRENT_LIST_DIR}/../../common" ABSOLUTE)
idf_component_register(
  SRCS "main.cpp" "${common}/all_kinds.cpp" "${common}/all_kinds_rounds.cpp" "${common}/ecc_probe.cpp"
  INCLUDE_DIRS "${common}"
  PRIV_REQUIRES cpp)
target_compile_options(${COMPONENT_LIB} PRIVATE
  -std=c++17 -fno-exceptions -fno-rtti -Os -Wall -Wextra -Werror)
