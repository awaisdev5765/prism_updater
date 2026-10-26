# The Flutter tooling generates the full CMake configuration; this adds the
# native plugin sources.
cmake_minimum_required(VERSION 3.14)

set(PRISM_UPDATER_BUNDLED_LIBRARIES "")
set(PRISM_UPDATER_PLUGIN_NAME prism_updater_plugin)

add_library(${PRISM_UPDATER_PLUGIN_NAME} SHARED
  "prism_updater_plugin.cpp"
)
apply_standard_settings(${PRISM_UPDATER_PLUGIN_NAME})
target_include_directories(${PRISM_UPDATER_PLUGIN_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PRISM_UPDATER_PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)
