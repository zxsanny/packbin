vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
vcpkg_cmake_configure(
  SOURCE_PATH "${CURRENT_PORT_DIR}"
  OPTIONS "-DPACKBIN_VERSION=${VERSION}")
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME packbin CONFIG_PATH lib/cmake/packbin)
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
vcpkg_install_copyright(FILE_LIST "${CURRENT_PORT_DIR}/LICENSE")
