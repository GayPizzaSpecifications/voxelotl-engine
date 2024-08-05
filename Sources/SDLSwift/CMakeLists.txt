add_library(SDLSwift INTERFACE)
set_property(TARGET SDLSwift PROPERTY Swift_MODULE_NAME "SDL3")

target_include_directories(SDLSwift INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")

target_link_libraries(SDLSwift INTERFACE ${SDL3})
