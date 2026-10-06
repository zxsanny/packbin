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
add_library(packbin::packbin ALIAS packbin)
target_include_directories(packbin PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>)
target_compile_features(packbin PUBLIC cxx_std_17)

# The operating-system random source for PackSession::start; firmware passes its own.
option(PACKBIN_OS_RANDOM "Build packbin::os_random for host programs" ON)
if(PACKBIN_OS_RANDOM)
  target_sources(packbin PRIVATE src/os_random.cpp)
endif()

# Install and export only when packbin is the top-level project (the vcpkg port, or `cmake --install`
# of cpp/ itself): a parent that add_subdirectory()s packbin must not install it with its own files.
# Consumers then use find_package(packbin CONFIG REQUIRED) and the target packbin::packbin.
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  install(TARGETS packbin EXPORT packbin-targets ARCHIVE DESTINATION lib)
  install(DIRECTORY include/packbin DESTINATION include)
  install(EXPORT packbin-targets NAMESPACE packbin:: DESTINATION lib/cmake/packbin)
  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/packbin-config.cmake"
       "include(\"\${CMAKE_CURRENT_LIST_DIR}/packbin-targets.cmake\")\n")
  install(FILES "${CMAKE_CURRENT_BINARY_DIR}/packbin-config.cmake" DESTINATION lib/cmake/packbin)

  # The version comes from the release tag, so only the port knows it: -DPACKBIN_VERSION=<version>.
  set(PACKBIN_VERSION "" CACHE STRING "Version recorded in packbin-config-version.cmake")
  if(PACKBIN_VERSION)
    include(CMakePackageConfigHelpers)
    write_basic_package_version_file("${CMAKE_CURRENT_BINARY_DIR}/packbin-config-version.cmake"
                                     VERSION ${PACKBIN_VERSION} COMPATIBILITY SameMajorVersion)
    install(FILES "${CMAKE_CURRENT_BINARY_DIR}/packbin-config-version.cmake" DESTINATION lib/cmake/packbin)
  endif()
endif()
