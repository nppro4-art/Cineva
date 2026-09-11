cmake_minimum_required(VERSION 3.13)
project(cineva_dsp C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

add_compile_options(-O2 -Wall -Wextra -Wno-unused-parameter)

# Bibliothèque statique (liée ensuite par les bindings FFI via une lib
# partagée construite par la plateforme hôte, voir ../ffi/).
add_library(cineva_dsp STATIC
  src/biquad.c
  src/loudness.c
  src/param_eq.c
  src/drc.c
  src/dialogue.c
  src/bass.c
  src/spatial.c
  src/room.c
  src/limiter.c
  src/channel_mapper.c
  src/cineva_dsp.c
)
target_include_directories(cineva_dsp PUBLIC include)

# Bibliothèque partagée (Linux/macOS/Android) pour dart:ffi.
add_library(cineva_dsp_shared SHARED
  src/biquad.c
  src/loudness.c
  src/param_eq.c
  src/drc.c
  src/dialogue.c
  src/bass.c
  src/spatial.c
  src/room.c
  src/limiter.c
  src/channel_mapper.c
  src/cineva_dsp.c
)
target_include_directories(cineva_dsp_shared PUBLIC include)
set_target_properties(cineva_dsp_shared PROPERTIES
  OUTPUT_NAME cineva_dsp
  POSITION_INDEPENDENT_CODE ON
)

enable_testing()

add_executable(cineva_dsp_test test/test_main.c
  src/biquad.c src/loudness.c src/param_eq.c src/drc.c src/dialogue.c
  src/bass.c src/spatial.c src/room.c src/limiter.c src/channel_mapper.c
  src/cineva_dsp.c)
target_include_directories(cineva_dsp_test PRIVATE include src)
add_test(NAME dsp_tests COMMAND cineva_dsp_test)

add_executable(cineva_dsp_benchmark test/benchmark.c
  src/biquad.c src/loudness.c src/param_eq.c src/drc.c src/dialogue.c
  src/bass.c src/spatial.c src/room.c src/limiter.c src/channel_mapper.c
  src/cineva_dsp.c)
target_include_directories(cineva_dsp_benchmark PRIVATE include src)
