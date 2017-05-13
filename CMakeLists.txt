cmake_minimum_required(VERSION 3.6)
project(uncloakCUDA)

find_package(CUDA REQUIRED)

set(CMAKE_C_STANDARD 99)
list(APPEND CUDA_NVCC_FLAGS -arch=sm_20)
set(CUDA_HOST_COMPILATION_CPP OFF)
set(CUDA_SEPARABLE_COMPILATION ON)


set(SOURCE_FILES main.cu hash.cu ip4.cu host.cu ip6.cu itdoesnothingbutfixesclion.c)
cuda_add_executable(uncloakCUDA ${SOURCE_FILES})