# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(pocketsphinx_flutter_library VERSION 0.0.1 LANGUAGES C)

add_library(pocketsphinx_flutter SHARED
  "pocketsphinx_flutter.c"
)

set_target_properties(pocketsphinx_flutter PROPERTIES
  PUBLIC_HEADER pocketsphinx_flutter.h
  OUTPUT_NAME "pocketsphinx_flutter"
)

target_compile_definitions(pocketsphinx_flutter PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(pocketsphinx_flutter PRIVATE "-Wl,-z,max-page-size=16384")
endif()
