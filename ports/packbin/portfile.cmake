set(SRC "${CURRENT_PORT_DIR}")
file(INSTALL "${SRC}/include/packbin" DESTINATION "${CURRENT_PACKAGES_DIR}/include")
file(INSTALL "${SRC}/src/" DESTINATION "${CURRENT_PACKAGES_DIR}/share/packbin/src")
file(WRITE "${CURRENT_PACKAGES_DIR}/share/packbin/copyright" "MIT\n")
