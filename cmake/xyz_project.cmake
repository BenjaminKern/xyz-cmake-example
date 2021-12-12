# MIT License
#
# Copyright (c) 2021 Benjamin Kern
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

function(xyz_prepare project_config_json name version)

  if(DEFINED PROJECT_CONFIG_FILE)
    file(READ ${PROJECT_CONFIG_FILE} project_config_file)
  else()
    file(READ xyz_project_config.json project_config_file)
  endif()
  
  string(JSON _project_config_json GET ${project_config_file} 0)

  _xyz_get_project_details(_name _version ${_project_config_json})
  _xyz_configure_options(${_project_config_json})
  file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/${_name}_package_config.cmake.in "@PACKAGE_INIT@\n")
  file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/${_name}_package_config.cmake.in "include(CMakeFindDependencyMacro)\n")
  file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/${_name}_package_config.cmake.in "@LIBRARY_DEPENDENCIES@\n")
  file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/${_name}_package_config.cmake.in "include(\"\$\{CMAKE_CURRENT_LIST_DIR\}/@library_name@Targets.cmake\")\n")
  file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/${_name}_package_config.cmake.in "check_required_components(\"@library_name@\")\n")

  if(HIDE_SYMBOLS)
    set(CMAKE_CXX_VISIBILITY_PRESET hidden PARENT_SCOPE)
    set(CMAKE_CXX_VISIBILITY_INLINES_HIDDEN ON PARENT_SCOPE)
    set(CMAKE_C_VISIBILITY_PRESET hidden PARENT_SCOPE)
    set(CMAKE_C_VISIBILITY_INLINES_HIDDEN ON PARENT_SCOPE)
  endif()

  set(${name} ${_name} PARENT_SCOPE)
  set(${version} ${_version} PARENT_SCOPE)
  set(${project_config_json} ${_project_config_json} PARENT_SCOPE)

endfunction()

function(xyz_configure project_config_json project_version)

  add_subdirectory(third-party)

  _xyz_configure(libs libraries ${project_config_json})
  _xyz_configure(exes executables ${project_config_json})
  
  foreach(x IN LISTS libs exes)
    get_target_property(packages ${x} xyz_find_packages)
    foreach (package IN LISTS packages)
      list(FIND libs ${package} index)
      if(${index} EQUAL -1)
        find_package(${package} REQUIRED)
      endif()
    endforeach()
  endforeach()

  string(JSON root_namespace GET ${project_config_json} project name)
  foreach(val IN LISTS libs)
    _xyz_init(${val} ${project_version} ${root_namespace} libraries)
  endforeach()

  foreach(val IN LISTS exes)
    _xyz_init(${val} ${project_version} ${root_namespace} executables)
  endforeach()

  if(BUILD_CPACK)
    _xyz_configure_cpack(${project_config_json})
  endif()

endfunction()

function(_xyz_init target_name version root_namespace target_type)
  _xyz_apply_target_options(${target_name})

  if("${target_type}" STREQUAL "executables")
    add_executable(${root_namespace}::${target_name} ALIAS ${target_name})
    _xyz_install_executable(${target_name} ${version} ${root_namespace})
  elseif("${target_type}" STREQUAL "libraries")
    add_library(${root_namespace}::${target_name} ALIAS ${target_name})
    if(BUILD_TESTS)
      _xyz_configure_tests(${target_name} ${root_namespace})
    endif()
    _xyz_install_library(${target_name} ${version} ${root_namespace})
  else()
    message(FATAL_ERROR "Unsupported target_type ${target_type}")
  endif()

endfunction()

function(_xyz_install_executable executable_name version root_namespace)
  # share, resources maybe?
  install(TARGETS ${executable_name}
    RUNTIME DESTINATION bin 
  )
endfunction()

function(_xyz_configure_tests target_name root_namespace)

  get_target_property(target_language ${target_name} LINKER_LANGUAGE)
  set(file_extension cpp)
  if("${target_language}" STREQUAL "C")
    set(file_extension c)
  endif()

  file(GLOB files CONFIGURE_DEPENDS ${target_name}/test/*.${file_extension})
  foreach(val ${files})
    get_filename_component(file_name ${val} NAME_WE)
    set(unit_test_file_name ${file_name})
    add_executable(${unit_test_file_name} ${val})
    set_property(TARGET ${unit_test_file_name} PROPERTY RUNTIME_OUTPUT_DIRECTORY ${target_name})
    _xyz_add_compile_options(${unit_test_file_name})

    if("${target_language}" STREQUAL "C")
      target_link_libraries(${unit_test_file_name} PRIVATE ${root_namespace}::${target_name} greatest::greatest)
    else()
      target_link_libraries(${unit_test_file_name} PRIVATE ${root_namespace}::${target_name} doctest::doctest)
    endif()

    set_property(TARGET ${unit_test_file_name} PROPERTY FOLDER tests)
    add_test(NAME ${unit_test_file_name} COMMAND ${unit_test_file_name})
  endforeach()
endfunction()

function(_xyz_install_library library_name version root_namespace)
  set(LIBRARY_DEPENDENCIES "")
  get_target_property(packages ${library_name} xyz_find_packages)
  foreach(val IN LISTS packages)
    string(APPEND LIBRARY_DEPENDENCIES "find_dependency(${val})\n")
  endforeach()
  set(install_lib_dir "lib/${CMAKE_LIBRARY_ARCHITECTURE}")

  install(TARGETS ${library_name} EXPORT ${library_name}Targets
    ARCHIVE DESTINATION ${install_lib_dir}
    LIBRARY DESTINATION ${install_lib_dir}
  )
  install(DIRECTORY ${library_name}/include/ DESTINATION include)
  install(EXPORT ${library_name}Targets
    FILE ${library_name}Targets.cmake
    NAMESPACE ${root_namespace}::
    DESTINATION ${install_lib_dir}/cmake/${library_name}
  )
  include(CMakePackageConfigHelpers)
  write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/${library_name}/${library_name}ConfigVersion.cmake"
    VERSION 
      ${version} 
    COMPATIBILITY
      SameMajorVersion
  )
  configure_package_config_file(${CMAKE_CURRENT_BINARY_DIR}/${root_namespace}_package_config.cmake.in
      ${CMAKE_CURRENT_BINARY_DIR}/${library_name}/${library_name}Config.cmake
      INSTALL_DESTINATION 
        ${install_lib_dir}/cmake/${library_name}
  )
  install(
    FILES 
      "${CMAKE_CURRENT_BINARY_DIR}/${library_name}/${library_name}Config.cmake" 
      "${CMAKE_CURRENT_BINARY_DIR}/${library_name}/${library_name}ConfigVersion.cmake"
    DESTINATION 
      ${install_lib_dir}/cmake/${library_name}
  )
endfunction()

function(_xyz_get_project_details name version project_config_json)

  string(JSON val GET ${project_config_json} project name)
  set(${name} ${val} PARENT_SCOPE)

  string(TIMESTAMP default_version "%Y.%m.%d" "UTC")
  string(JSON val ERROR_VARIABLE error GET ${project_config_json} project version)
  if("${error}" STREQUAL "NOTFOUND")
    set(default_version ${val})
  endif()
  set(${version} ${default_version} PARENT_SCOPE)
endfunction()

function(_xyz_configure_options project_config_json)
  if("${CMAKE_SOURCE_DIR}" STREQUAL "${CMAKE_BINARY_DIR}")
    message(FATAL_ERROR "In-source builds are not allowed")
  endif()
  set_property(GLOBAL PROPERTY USE_FOLDERS ON)
  
  get_property(is_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
  if(is_multi_config)
    if(NOT MSVC)
      set(CMAKE_CONFIGURATION_TYPES "Debug;Release;Tsan;Asan;Lsan;Msan;Ubsan" CACHE STRING "" FORCE)
    endif()
  else()
    if(NOT CMAKE_BUILD_TYPE)
      set(CMAKE_BUILD_TYPE "Release" CACHE STRING "" FORCE)
    endif()
    if(NOT MSVC)
      set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug;Release;Tsan;Asan;Lsan;Msan;Ubsan")
    endif()
  endif()

  set(default_option ON)
  string(JSON val ERROR_VARIABLE error GET ${project_config_json} project options shared_libraries)
  if("${error}" STREQUAL "NOTFOUND")
    set(default_option ${val})
  endif()
  option(BUILD_SHARED_LIBS "Build shared libraries ON/OFF" ${default_option})
  set(default_option ON)
  string(JSON val ERROR_VARIABLE error GET ${project_config_json} project options build_tests)
  if("${error}" STREQUAL "NOTFOUND")
    set(default_option ${val})
  endif()
  option(BUILD_TESTS "Build unit tests ON/OFF" ${default_option})
  set(default_option OFF)
  string(JSON val ERROR_VARIABLE error GET ${project_config_json} project options hide_symbols)
  if("${error}" STREQUAL "NOTFOUND")
    set(default_option ${val})
  endif()
  option(HIDE_SYMBOLS "Build with fvisibility=hidden ON/OFF" ${default_option})

  set(default_option OFF)
  string(JSON val ERROR_VARIABLE error GET ${project_config_json} project cpack debian)
  if("${error}" STREQUAL "NOTFOUND")
    set(default_option ON)
  endif()
  option(BUILD_CPACK "Build a debian packet with cpack ON/OFF" ${default_option})
endfunction()

function(_xyz_configure targets target_type project_config_json)
  string(JSON target_length ERROR_VARIABLE error LENGTH ${project_config_json} project ${target_type})
  if(NOT "${error}" STREQUAL "NOTFOUND")
    set(target_length 0)
  endif()

  if(${target_length} LESS 1)
    message(STATUS "No ${target_type} configured")
    return()
  endif()

  math(EXPR n "${target_length} - 1")

  foreach(i RANGE ${n})
    string(JSON target_name MEMBER ${project_config_json} project ${target_type} ${i})
    list(APPEND tmp ${target_name})

    string(JSON target_language ERROR_VARIABLE error GET ${project_config_json} project ${target_type} ${target_name} language type)
    _xyz_get_file_extension(file_extension ${target_language} ${error})

    file(GLOB_RECURSE src_files CONFIGURE_DEPENDS ${target_name}/src/*.${file_extension})

    if("${target_type}" STREQUAL "executables")
      file(GLOB_RECURSE h_files CONFIGURE_DEPENDS ${target_name}/src/*.h)
      add_executable(${target_name} ${h_files} ${src_files})
      target_include_directories(${target_name} 
        PRIVATE
          ${target_name}/src
      )
      _xyz_add_compile_options(${target_name})
    elseif("${target_type}" STREQUAL "libraries")

      if(NOT IS_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/${target_name}/include/${target_name})
        message(FATAL_ERROR "Expected subdirectory include/${target_name} for library ${target_name} does not exist")
      endif()

      file(GLOB_RECURSE h_files CONFIGURE_DEPENDS ${target_name}/include/*.h)
      if(src_files)
        add_library(${target_name} ${h_files} ${src_files})
        target_include_directories(${target_name} 
          PUBLIC 
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/${target_name}/include>
            $<INSTALL_INTERFACE:include>
          PRIVATE
            ${library_name}/src
        )
        _xyz_add_compile_options(${target_name})
      else()
        add_library(${target_name} INTERFACE ${h_files})
        target_include_directories(${target_name} 
          INTERFACE 
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/${target_name}/include>
            $<INSTALL_INTERFACE:include>
        )
      endif()
    else()
      message(FATAL_ERROR "Unsupported target_type ${target_type}")
    endif()

    _xyz_add_target_options(${target_name} ${project_config_json} ${target_type})
    
  endforeach()

  set(${targets} ${tmp} PARENT_SCOPE)
endfunction()

function(_xyz_add_compile_options target_name)
  if(MSVC)
    set(FLAGS_WARNINGS
      /W4
      /w14640
      /w14242
      /w14265
      /w14287
      /w14905
      /w14906
      /w14928
    )
  else()
    set(FLAGS_WARNINGS
      -Wall
      -Wextra
      -Wshadow
      -pedantic
      -Wunused
      -Wconversion
      -Wsign-conversion
    )
    set(FLAGS_TSAN
      -fsanitize=thread
      -g
      -O1
    )
    set(FLAGS_ASAN
      -fsanitize=address
      -fno-optimize-sibling-calls
      -fsanitize-address-use-after-scope
      -fno-omit-frame-pointer
      -g
      -O1
    )
    set(FLAGS_LSAN
      -fsanitize=leak
      -fno-omit-frame-pointer
      -g
      -O1
    )
    if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
      set(FLAGS_MSAN
        -fsanitize=memory
        -fno-optimize-sibling-calls
        -fsanitize-memory-track-origins=2
        -fno-omit-frame-pointer
        -g
        -O2
      )
    endif()
    set(FLAGS_UBSAN
      -fsanitize=undefined
    )
  endif()

  target_compile_options(${target_name} 
    PRIVATE 
    $<$<CONFIG:DEBUG>:${FLAGS_WARNINGS}>
    $<$<CONFIG:RELEASE>:${FLAGS_WARNINGS}>
    $<$<CONFIG:TSAN>:${FLAGS_TSAN}>
    $<$<CONFIG:ASAN>:${FLAGS_ASAN}>
    $<$<CONFIG:LSAN>:${FLAGS_LSAN}>
    $<$<CONFIG:MSAN>:${FLAGS_MSAN}>
    $<$<CONFIG:UBSAN>:${FLAGS_UBSAN}>
  )
  target_link_options(${target_name}
    PRIVATE 
    $<$<CONFIG:TSAN>:-fsanitize=thread>
    $<$<CONFIG:ASAN>:-fsanitize=address>
    $<$<CONFIG:LSAN>:-fsanitize=leak>
    $<$<CONFIG:MSAN>:-fsanitize=memory>
    $<$<CONFIG:UBSAN>:-fsanitize=undefined>
  )
endfunction()

function(_xyz_add_target_options target_name project_config_json target_type)

  set_target_properties(${target_name} PROPERTIES 
    RUNTIME_OUTPUT_DIRECTORY ${target_name}
    ARCHIVE_OUTPUT_DIRECTORY ${target_name}
    LIBRARY_OUTPUT_DIRECTORY ${target_name}
    DEBUG_POSTFIX "-dbg")

  _xyz_set_language_properties(${target_name} ${project_config_json} ${target_type})

  string(JSON x ERROR_VARIABLE error GET ${project_config_json} project ${target_type} ${target_name} find_packages)
  _xyz_parse_json_array(values ${x} ${error})
  set_target_properties(${target_name} PROPERTIES xyz_find_packages "${values}")

  string(JSON x ERROR_VARIABLE error GET ${project_config_json} project ${target_type} ${target_name} link_libraries public)
  _xyz_parse_json_array(values ${x} ${error})
  set_target_properties(${target_name} PROPERTIES xyz_public_link_libraries "${values}")

  string(JSON x ERROR_VARIABLE error GET ${project_config_json} project ${target_type} ${target_name} link_libraries private)
  _xyz_parse_json_array(values ${x} ${error})
  set_target_properties(${target_name} PROPERTIES xyz_private_link_libraries "${values}")

  string(JSON x ERROR_VARIABLE error GET ${project_config_json} project ${target_type} ${target_name} compile_definitions public)
  _xyz_parse_json_array(values ${x} ${error})
  set_target_properties(${target_name} PROPERTIES xyz_public_compile_definitions "${values}")

  string(JSON x ERROR_VARIABLE error GET ${project_config_json} project ${target_type} ${target_name} compile_definitions private)
  _xyz_parse_json_array(values ${x} ${error})
  set_target_properties(${target_name} PROPERTIES xyz_private_compile_definitions "${values}")
endfunction()

function(_xyz_apply_target_options target_name)

  get_target_property(values ${target_name} xyz_public_link_libraries)
  foreach(val IN LISTS values)
    target_link_libraries(${target_name} PUBLIC ${val})
  endforeach()

  get_target_property(values ${target_name} xyz_private_link_libraries)
  foreach(val IN LISTS values)
    target_link_libraries(${target_name} PRIVATE ${val})
  endforeach()

  get_target_property(values ${target_name} xyz_public_compile_definitions)
  foreach(val IN LISTS values)
    target_compile_definitions(${target_name} PUBLIC ${val})
  endforeach()

  get_target_property(values ${target_name} xyz_private_compile_definitions)
  foreach(val IN LISTS values)
    target_compile_definitions(${target_name} PRIVATE ${val})
  endforeach()

endfunction()

function(_xyz_set_language_properties target_name project_config_json target_type)
  set(default_linker_language CXX)
  set(default_standard 17)
  set(default_use_extensions FALSE)

  string(JSON tmp ERROR_VARIABLE error GET ${project_config_json} project ${target_type} ${target_name} language)
  if("${error}" STREQUAL "NOTFOUND")
    string(JSON val ERROR_VARIABLE error GET ${tmp} type)
    if("${error}" STREQUAL "NOTFOUND")
      if("${val}" STREQUAL "C")
        set(default_linker_language C)
      endif()
    endif()
    string(JSON val ERROR_VARIABLE error GET ${tmp} standard)
    if("${error}" STREQUAL "NOTFOUND")
      set(default_standard ${val})
    endif()
    string(JSON val ERROR_VARIABLE error GET ${tmp} extensions)
    if("${error}" STREQUAL "NOTFOUND")
      set(default_use_extensions ${val})
    endif()
  endif()

  set_target_properties(${target_name} PROPERTIES
    LINKER_LANGUAGE ${default_linker_language}
    ${default_linker_language}_STANDARD ${default_standard}
    ${default_linker_language}_STANDARD_REQUIRED TRUE
    ${default_linker_language}_EXTENSIONS ${default_use_extensions}
  )
endfunction()

function(_xyz_configure_cpack project_config_json)
  set(CPACK_GENERATOR "DEB" CACHE STRING "" FORCE)
  set(CPACK_DEBIAN_FILE_NAME DEB-DEFAULT CACHE STRING "" FORCE)
  string(JSON val GET ${project_config_json} project cpack debian contact)
  set(CPACK_PACKAGE_CONTACT "${val}" CACHE STRING "" FORCE)
  string(JSON val GET ${project_config_json} project cpack debian description)
  set(CPACK_PACKAGE_DESCRIPTION "${val}" CACHE STRING "" FORCE)
  string(JSON val ERROR_VARIABLE error GET ${project_config_json} project cpack debian dependencies)
  _xyz_parse_json_array(values ${val} ${error})

  set(tmp "")
  foreach(package IN LISTS values)
    string(APPEND tmp "${package},")
  endforeach()
  string(REGEX REPLACE ",$" "" package_depends "${tmp}")

  set(CPACK_DEBIAN_PACKAGE_DEPENDS "${package_depends}" CACHE STRING "" FORCE)
  include(CPack)
endfunction()

function(_xyz_parse_json_array out json_array error)
  set(tmp "")
  if("${error}" STREQUAL "NOTFOUND")
    string(JSON array_length LENGTH ${json_array})
    if(${array_length} GREATER 0)
      math(EXPR n "${array_length} -1")
      foreach(i RANGE ${n})
        string(JSON val GET ${json_array} ${i})
        list(APPEND tmp ${val})
      endforeach()
    endif()
  endif()
  set(${out} ${tmp} PARENT_SCOPE)
endfunction()

function(_xyz_get_file_extension out language error)
  set(file_extension cpp)
  if("${error}" STREQUAL "NOTFOUND")
    if("${target_language}" STREQUAL "C")
      set(file_extension c)
    endif()
  endif()
  set(${out} ${file_extension} PARENT_SCOPE)
endfunction()
