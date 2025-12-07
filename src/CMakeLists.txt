# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(pocketsphinx_ffi_wrapper_library VERSION 0.0.1 LANGUAGES C)

add_library(pocketsphinx_ffi_wrapper SHARED
  "pocketsphinx_ffi_wrapper.c"
)

set_target_properties(pocketsphinx_ffi_wrapper PROPERTIES
  PUBLIC_HEADER pocketsphinx_ffi_wrapper.h
  OUTPUT_NAME "pocketsphinx_ffi_wrapper"
)

target_compile_definitions(pocketsphinx_ffi_wrapper PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(pocketsphinx_ffi_wrapper PRIVATE "-Wl,-z,max-page-size=16384")
endif()
