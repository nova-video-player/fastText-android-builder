# Copyright 2026 Courville Software
# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.16)
project(nova_fasttext VERSION 0.9.2 LANGUAGES CXX)

# Upstream 0.9.2 hardcodes -march=native and builds a CLI and shared libraries.
# Keep its source unchanged and let the NDK toolchain select the target CPU.
set(FASTTEXT_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/fastText-0.9.2" CACHE PATH
    "Path to the pinned fastText source")
set(FASTTEXT_SOURCES
    args.cc autotune.cc densematrix.cc dictionary.cc fasttext.cc loss.cc
    matrix.cc meter.cc model.cc productquantizer.cc quantmatrix.cc utils.cc vector.cc)
list(TRANSFORM FASTTEXT_SOURCES PREPEND "${FASTTEXT_SOURCE_DIR}/src/")
add_library(fasttext STATIC ${FASTTEXT_SOURCES})
set_target_properties(fasttext PROPERTIES
    CXX_STANDARD 11 CXX_STANDARD_REQUIRED YES CXX_EXTENSIONS NO
    POSITION_INDEPENDENT_CODE ON)
target_include_directories(fasttext PUBLIC "${FASTTEXT_SOURCE_DIR}/src")
target_compile_options(fasttext PRIVATE -ffunction-sections -fdata-sections)
find_package(Threads REQUIRED)
target_link_libraries(fasttext PUBLIC Threads::Threads)

if(ANDROID)
    set(FASTTEXT_INSTALL_LIBDIR "lib/${ANDROID_ABI}")
else()
    set(FASTTEXT_INSTALL_LIBDIR lib)
endif()
install(TARGETS fasttext ARCHIVE DESTINATION "${FASTTEXT_INSTALL_LIBDIR}")
install(DIRECTORY "${FASTTEXT_SOURCE_DIR}/src/" DESTINATION include/fasttext
        FILES_MATCHING PATTERN "*.h")

include(CTest)
if(BUILD_TESTING)
    set(FASTTEXT_MODEL "${CMAKE_CURRENT_SOURCE_DIR}/../prebuilt/fastText/share/fastText/lid.176.ftz"
        CACHE FILEPATH "Language model used by the inference smoke test")
    add_executable(fasttext_smoke test/smoke.cpp)
    target_link_libraries(fasttext_smoke PRIVATE fasttext)
    set_target_properties(fasttext_smoke PROPERTIES CXX_STANDARD 11 CXX_STANDARD_REQUIRED YES)
    if(ANDROID)
        target_link_libraries(fasttext_smoke PRIVATE "-Wl,-z,max-page-size=16384")
    endif()
    add_test(NAME language_identification COMMAND fasttext_smoke "${FASTTEXT_MODEL}")
    add_test(NAME missing_model COMMAND fasttext_smoke "${CMAKE_CURRENT_BINARY_DIR}/missing-model.ftz")
    set_tests_properties(missing_model PROPERTIES WILL_FAIL TRUE)
endif()
