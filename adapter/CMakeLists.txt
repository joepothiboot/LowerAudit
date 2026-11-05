cmake_minimum_required(VERSION 3.20)
project(lower-audit-adapter LANGUAGES C CXX)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(MLIR 23.1.1 EXACT REQUIRED CONFIG
             HINTS /opt/homebrew/opt/llvm/lib/cmake/mlir)
message(STATUS "Using MLIRConfig.cmake in: ${MLIR_DIR}")

separate_arguments(LLVM_DEFINITIONS_LIST NATIVE_COMMAND "${LLVM_DEFINITIONS}")

add_executable(lower-audit-adapter main.cpp)
target_include_directories(lower-audit-adapter SYSTEM PRIVATE
                           ${LLVM_INCLUDE_DIRS} ${MLIR_INCLUDE_DIRS})
target_compile_definitions(lower-audit-adapter PRIVATE ${LLVM_DEFINITIONS_LIST})
target_compile_options(lower-audit-adapter PRIVATE -Wall)
target_link_libraries(lower-audit-adapter PRIVATE MLIR LLVM)
