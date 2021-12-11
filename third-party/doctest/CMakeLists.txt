cmake_minimum_required(VERSION 3.19)

project(doctest)

add_library(${PROJECT_NAME} OBJECT main.cpp)
add_library(${PROJECT_NAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME})
target_include_directories(${PROJECT_NAME} INTERFACE 
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/>
)
