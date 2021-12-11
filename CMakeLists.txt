cmake_minimum_required(VERSION 3.19)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

set(PROJECT_CONFIG_FILE project_config.json)

include(xyz_project)
xyz_prepare(project_config_json name version)

project(${name} VERSION ${version} LANGUAGES C CXX)

xyz_configure(${project_config_json} ${version})

enable_testing()
