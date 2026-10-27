cmake_minimum_required(VERSION 3.16)

# One file for both uses: an ESP-IDF component (inside an IDF build) and a plain CMake library.
set(PACKBIN_CORE_SRCS
    src/core/values.cpp
    src/core/pack.cpp
    src/core/unpack.cpp
    src/core/crypto.cpp)

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

# Without the compact text codec: strings bind to Packed (the payload as it is) and no codec
# table or code is linked. Public, so the headers of a consumer refuse a Text<N> member too.
option(PACKBIN_NO_TEXT "Build without the compact text codec; strings bind to Packed" OFF)
if(PACKBIN_NO_TEXT)
  target_compile_definitions(packbin PUBLIC PACKBIN_NO_TEXT)
endif()

# Without message error correction: a scheme with parity bytes is refused and no codec table or
# repair code is linked. The Cortex-M4F flash budget needs it.
option(PACKBIN_NO_ECC "Build without message error correction (parity bytes)" OFF)
if(PACKBIN_NO_ECC)
  target_compile_definitions(packbin PUBLIC PACKBIN_NO_ECC)
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
    # Minors below 1.0 may break each other, so there a request must name the installed minor.
    set(PACKBIN_VERSION_RULE SameMajorVersion)
    if(PACKBIN_VERSION VERSION_LESS 1)
      set(PACKBIN_VERSION_RULE SameMinorVersion)
    endif()
    write_basic_package_version_file("${CMAKE_CURRENT_BINARY_DIR}/packbin-config-version.cmake"
                                     VERSION ${PACKBIN_VERSION} COMPATIBILITY ${PACKBIN_VERSION_RULE})
    install(FILES "${CMAKE_CURRENT_BINARY_DIR}/packbin-config-version.cmake" DESTINATION lib/cmake/packbin)
  endif()
endif()
