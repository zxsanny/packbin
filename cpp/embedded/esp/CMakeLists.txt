# ESP-IDF build of the packbin core and the all-kinds scheme (feature AC-1: build only, no run).
# The core comes from the shipped ESP-IDF component in cpp/ (component name `cpp`).
# run.sh builds it with `idf.py -B <dir> -D SDKCONFIG=<dir>/sdkconfig set-target <chip> build`.
cmake_minimum_required(VERSION 3.16)
get_filename_component(packbin_cpp "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(EXTRA_COMPONENT_DIRS "${packbin_cpp}")
set(COMPONENTS main)
set(PROJECT_VER "0")
include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(packbin_embedded)

# Feature AC-1 flags on the core component, after IDF's own options.
idf_component_get_property(packbin_core_lib cpp COMPONENT_LIB)
target_compile_options(${packbin_core_lib} PRIVATE
  -std=c++17 -fno-exceptions -fno-rtti -Os -Wall -Wextra -Werror)
