cmake_minimum_required(VERSION 3.24)
set(CMAKE_OSX_DEPLOYMENT_TARGET "13.6" CACHE STRING "Minimum OSX version" FORCE)
set(CMAKE_Swift_LANGUAGE_VERSION "5.0")
project(voxelotl LANGUAGES C Swift VERSION "0.1.0")

find_library(SDL3 SDL3 REQUIRED PATHS "${CMAKE_SOURCE_DIR}/Frameworks" NO_DEFAULT_PATH)

add_subdirectory(Sources/SDLSwift)
add_subdirectory(Sources/Voxelotl)
