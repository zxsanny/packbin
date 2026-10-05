cmake_minimum_required(VERSION 3.16)

# One file for both uses: an ESP-IDF component (inside an IDF build) and a plain CMake library.
set(PACKBIN_CORE_SRCS
    src/core/values.cpp
    src/core/pack.cpp
    src/core/unpack.cpp
    src/core/session.cpp)

if(ESP_PLATFORM)
  idf_component_register(SRCS ${PACKBIN_CORE_SRCS} INCLUDE_DIRS include)
  target_compile_features(${COMPONENT_LIB} PUBLIC cxx_std_17)
  return()
endif()

project(packbin LANGUAGES CXX)

add_library(packbin STATIC ${PACKBIN_CORE_SRCS})
target_include_directories(packbin PUBLIC include)
target_compile_features(packbin PUBLIC cxx_std_17)

# The operating-system random source for PackSession::start; firmware passes its own.
option(PACKBIN_OS_RANDOM "Build packbin::os_random for host programs" ON)
if(PACKBIN_OS_RANDOM)
  target_sources(packbin PRIVATE src/os_random.cpp)
endif()
