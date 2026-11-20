cmake_minimum_required(VERSION 3.20)

# Lightweight rebuild using an installed Zig C compiler. Cache/output stay in temp.
# CMakeLists.txt supports a conventional Windows C compiler toolchain.
if(NOT CMAKE_HOST_WIN32)
    message(FATAL_ERROR "The native launcher currently supports Windows only.")
endif()
get_filename_component(bin "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
if(NOT DEFINED ZIG_EXECUTABLE)
    find_program(ZIG_EXECUTABLE NAMES zig REQUIRED)
endif()
if(NOT DEFINED STAGING_DIR)
    message(FATAL_ERROR "Supply a temporary STAGING_DIR for caches and output.")
endif()
file(MAKE_DIRECTORY "${STAGING_DIR}")
set(ENV{ZIG_GLOBAL_CACHE_DIR} "${STAGING_DIR}/cache")
set(ENV{ZIG_LOCAL_CACHE_DIR} "${STAGING_DIR}/local-cache")
# Compile the icon resource separately so the C host remains startup-only.
execute_process(
    COMMAND "${ZIG_EXECUTABLE}" rc /fo "${STAGING_DIR}/CardForgeEngine.res"
        /i "${bin}" "${CMAKE_CURRENT_LIST_DIR}/CardForgeEngine.rc"
    WORKING_DIRECTORY "${STAGING_DIR}"
    RESULT_VARIABLE resource_result)
if(NOT resource_result EQUAL 0)
    message(FATAL_ERROR "Card Forge Engine icon resource compilation failed: ${resource_result}")
endif()
execute_process(
    COMMAND "${ZIG_EXECUTABLE}" cc -target x86_64-windows-gnu
        -std=c11 -O2 -Wall -Wextra -Werror -municode -Wl,--subsystem,windows
        "${CMAKE_CURRENT_LIST_DIR}/main.c" "${STAGING_DIR}/CardForgeEngine.res" -o "${STAGING_DIR}/Card Forge Engine.exe" -luser32 -lshell32
    WORKING_DIRECTORY "${STAGING_DIR}"
    RESULT_VARIABLE result)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "Card Forge Engine launcher compilation failed: ${result}")
endif()
message(STATUS "Built ${STAGING_DIR}/Card Forge Engine.exe")
