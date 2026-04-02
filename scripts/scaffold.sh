#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
usage: scaffold.sh <project-name> [module-name]

Creates src/gr4-<project-name> with a minimal GR4 project layout.
If module-name is omitted, a module with the same normalized name as the
project is created automatically.
Project and module names may use hyphens or underscores; generated filesystem
names use hyphens and C++ identifiers use underscores.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

validate_name() {
  local label="$1"
  local name="$2"

  if [[ ! "${name}" =~ ^[a-z]([a-z0-9_-]*[a-z0-9])?$ ]]; then
    die "${label} must match [a-z]([a-z0-9_-]*[a-z0-9])?"
  fi
}

to_kebab_case() {
  local name="$1"
  printf '%s' "${name//_/-}"
}

to_snake_case() {
  local name="$1"
  printf '%s' "${name//-/_}"
}

project_input="${1:-}"
module_input="${2:-}"
if [ -z "${project_input}" ] || [ "${project_input}" = "-h" ] || [ "${project_input}" = "--help" ]; then
  usage
  exit 0
fi

project_slug_raw="${project_input#gr4-}"
if [ -n "${module_input}" ] && { [ "${module_input}" = "-h" ] || [ "${module_input}" = "--help" ]; }; then
  usage
  exit 0
fi

if [ -z "${module_input}" ]; then
  module_input="${project_input}"
fi

module_slug_raw="${module_input#gr4-}"
validate_name "project name" "${project_slug_raw}"
validate_name "module name" "${module_slug_raw}"

project_name="$(to_kebab_case "${project_slug_raw}")"
project_ns="$(to_snake_case "${project_name}")"
module_name="$(to_kebab_case "${module_slug_raw}")"
repo_name="gr4-${project_name}"
repo_dir="${ROOT_DIR}/src/${repo_name}"
blocks_dir="${repo_dir}/blocks"
docs_dir="${repo_dir}/docs"
cmake_dir="${repo_dir}/cmake"

if [ -e "${repo_dir}" ]; then
  die "target already exists: ${repo_dir}"
fi

mkdir -p "${blocks_dir}" "${docs_dir}" "${cmake_dir}"

cat > "${repo_dir}/.gitignore" <<'EOF'
build/
install/
compile_commands.json
EOF

cat > "${repo_dir}/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.22)

project(${repo_name} VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(GNUInstallDirs)

option(ENABLE_TESTING "Enable test targets" ON)
option(ENABLE_PLUGINS "Enable plugin build path" OFF)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GR4I_GNURADIO4 REQUIRED IMPORTED_TARGET gnuradio4)
set(GR4I_GNURADIO4_TARGET "PkgConfig::GR4I_GNURADIO4")

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(Dependencies)
include(PluginHelpers)
gr4_${project_ns}_resolve_dependencies()

if(ENABLE_TESTING)
  include(CTest)
  enable_testing()
endif()

add_subdirectory(blocks)
EOF

cat > "${repo_dir}/README.md" <<EOF
# ${repo_name}

Minimal GR4 project scaffold.

Project namespace prefix:

- \`gr::${project_ns}\`

Project layout:

- \`blocks/<module>/\` for module packages
- \`cmake/\` for dependency and plugin helpers
- \`docs/\` for project-specific documentation
- \`README.md\` for project-level guidance

Block naming:

- block classes and headers are typically PascalCase, like \`Copy\` or \`StreamToPmt\`

Initial module:

- \`blocks/${module_name}/\`

## Build

\`\`\`bash
cmake -S . -B build
cmake --build build -j
\`\`\`

Modules and blocks are organized under \`blocks/\`.

Dependencies are discovered through \`pkg-config\`, so \`gnuradio4\` must be
visible to \`pkg-config\` when you configure the project.

If plugins are enabled, \`gnuradio_4_0_parse_registrations\` must also be
available in \`PATH\` or \`CMAKE_PROGRAM_PATH\`.
EOF

cat > "${repo_dir}/blocks/CMakeLists.txt" <<'EOF'
# Modules are added below by add-module.sh.
EOF

cat > "${repo_dir}/blocks/README.md" <<'EOF'
# Blocks

Module packages live under `blocks/<module>/`.

Each module provides its own public headers under
`include/gnuradio-4.0/<module>/` and tests under `test/`.
EOF

cat > "${repo_dir}/docs/README.md" <<'EOF'
# Documentation

Project-specific documentation lives here.
EOF

cat > "${cmake_dir}/Dependencies.cmake" <<EOF
include_guard(GLOBAL)

function(gr4_${project_ns}_resolve_dependencies)
  set(GR4I_GNURADIO4_TARGET "PkgConfig::GR4I_GNURADIO4" PARENT_SCOPE)

  if(ENABLE_PLUGINS)
    find_program(GR4I_PARSE_REGISTRATIONS_EXE NAMES gnuradio_4_0_parse_registrations)
    if(NOT GR4I_PARSE_REGISTRATIONS_EXE)
      message(FATAL_ERROR
        "ENABLE_PLUGINS=ON requires gnuradio_4_0_parse_registrations in PATH. "
        "Install gnuradio4 blocklib_generator tools and/or set CMAKE_PROGRAM_PATH.")
    endif()
    set(GR4I_PARSE_REGISTRATIONS_EXE "\${GR4I_PARSE_REGISTRATIONS_EXE}" PARENT_SCOPE)
  else()
    set(GR4I_PARSE_REGISTRATIONS_EXE "" PARENT_SCOPE)
  endif()
endfunction()
EOF

cat > "${cmake_dir}/PluginHelpers.cmake" <<EOF
include_guard(GLOBAL)

function(gr4_${project_ns}_merge_files_into merge_output_file)
  file(WRITE "\${merge_output_file}" "")
  foreach(merge_input_file IN LISTS ARGN)
    file(READ "\${merge_input_file}" _contents)
    file(APPEND "\${merge_output_file}" "\${_contents}")
  endforeach()
endfunction()

function(gr4_${project_ns}_add_block_plugin plugin_target_base)
  if(NOT ENABLE_PLUGINS)
    return()
  endif()

  set(options SPLIT_BLOCK_INSTANTIATIONS)
  set(oneValueArgs MODULE_NAME_BASE)
  set(multiValueArgs HEADERS LINK_LIBRARIES INCLUDE_DIRECTORIES)
  cmake_parse_arguments(GR4I_PLUGIN "\${options}" "\${oneValueArgs}" "\${multiValueArgs}" \${ARGN})

  if(NOT GR4I_PLUGIN_HEADERS)
    message(FATAL_ERROR "No HEADERS passed to gr4_${project_ns}_add_block_plugin(\${plugin_target_base})")
  endif()

  if(NOT GR4I_PARSE_REGISTRATIONS_EXE)
    message(FATAL_ERROR "ENABLE_PLUGINS=ON requires gnuradio_4_0_parse_registrations in PATH or CMAKE_PROGRAM_PATH.")
  endif()

  if(NOT GR4I_PLUGIN_MODULE_NAME_BASE)
    set(GR4I_PLUGIN_MODULE_NAME_BASE "\${plugin_target_base}")
  endif()

  if(GR4I_PLUGIN_SPLIT_BLOCK_INSTANTIATIONS)
    set(_parser_split_flag "--split")
  else()
    set(_parser_split_flag "")
  endif()

  set(_gen_dir "\${CMAKE_BINARY_DIR}/generated_plugins/\${GR4I_PLUGIN_MODULE_NAME_BASE}")
  file(REMOVE_RECURSE "\${_gen_dir}")
  file(MAKE_DIRECTORY "\${_gen_dir}")

  set(_generated_cpp "\${_gen_dir}/integrator.cpp")
  set(_plugin_instance_header "\${_gen_dir}/plugin_instance.hpp")
  set(_plugin_entry_cpp "\${_gen_dir}/plugin_entry.cpp")
  file(WRITE "\${_plugin_instance_header}"
    "#pragma once\n"
    "#include <gnuradio-4.0/Plugin.hpp>\n"
    "gr::plugin<>& grPluginInstance();\n")
  file(WRITE "\${_plugin_entry_cpp}"
    "#include <gnuradio-4.0/Plugin.hpp>\n"
    "GR_PLUGIN(\\\"\${plugin_target_base}\\\", \\\"${repo_name}\\\", \\\"MIT\\\", \\\"\\\${PROJECT_VERSION}\\\")\n")
  list(APPEND _generated_cpp "\${_plugin_entry_cpp}")

  foreach(_hdr IN LISTS GR4I_PLUGIN_HEADERS)
    get_filename_component(_abs_hdr "\${_hdr}" ABSOLUTE)
    get_filename_component(_basename "\${_hdr}" NAME_WE)

    file(GLOB _old_cpp "\${_gen_dir}/*\${_basename}*.cpp")
    if(_old_cpp)
      file(REMOVE \${_old_cpp})
    endif()

    file(GLOB _old_hpp_in "\${_gen_dir}/*\${_basename}*.hpp.in")
    if(_old_hpp_in)
      file(REMOVE \${_old_hpp_in})
    endif()

    execute_process(
      COMMAND "\${GR4I_PARSE_REGISTRATIONS_EXE}" "\${_abs_hdr}" "\${_gen_dir}" \${_parser_split_flag}
              --registry-header plugin_instance.hpp
              --registry-instance grPluginInstance
      RESULT_VARIABLE _gen_res
      OUTPUT_VARIABLE _gen_out
      ERROR_VARIABLE _gen_err
      OUTPUT_STRIP_TRAILING_WHITESPACE
      ERROR_STRIP_TRAILING_WHITESPACE
    )
    if(NOT _gen_res EQUAL 0)
      message(FATAL_ERROR
        "Failed generating plugin registration code from \${_hdr}\n"
        "stdout:\n\${_gen_out}\n"
        "stderr:\n\${_gen_err}")
    endif()

    file(GLOB _generated "\${_gen_dir}/\${_basename}*.cpp")
    if(NOT _generated)
      set(_dummy_cpp "\${_gen_dir}/dummy_\${_basename}.cpp")
      file(WRITE "\${_dummy_cpp}" "// No macros or expansions found for '\${_basename}'\n")
      list(APPEND _generated "\${_dummy_cpp}")
    endif()
    list(APPEND _generated_cpp \${_generated})
  endforeach()

  file(GLOB _decl_hpp_in "\${_gen_dir}/*_declarations.hpp.in")
  if(_decl_hpp_in)
    gr4_${project_ns}_merge_files_into("\${_gen_dir}/declarations.hpp" \${_decl_hpp_in})
  endif()
  file(GLOB _raw_calls_hpp_in "\${_gen_dir}/*_raw_calls.hpp.in")
  if(_raw_calls_hpp_in)
    gr4_${project_ns}_merge_files_into("\${_gen_dir}/raw_calls.hpp" \${_raw_calls_hpp_in})
  endif()

  # Ninja writes depfiles alongside the object output path for these generated
  # sources, so pre-create the nested directory shape it expects.
  file(MAKE_DIRECTORY
    "\${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/\${plugin_target_base}.dir/__/__/generated_plugins/\${GR4I_PLUGIN_MODULE_NAME_BASE}")

  add_library(\${plugin_target_base} OBJECT \${_generated_cpp})
  set_target_properties(\${plugin_target_base} PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_include_directories(\${plugin_target_base} PRIVATE "\${_gen_dir}" \${GR4I_PLUGIN_INCLUDE_DIRECTORIES})
  target_link_libraries(\${plugin_target_base}
    PUBLIC
      \${GR4I_GNURADIO4_TARGET}
      \${GR4I_PLUGIN_LINK_LIBRARIES}
  )

  set(_plugin_lib_name "\${plugin_target_base}Plugin")
  add_library(\${_plugin_lib_name} SHARED)
  target_link_libraries(\${_plugin_lib_name} PRIVATE \${plugin_target_base})
  install(TARGETS \${_plugin_lib_name} LIBRARY DESTINATION \${CMAKE_INSTALL_LIBDIR})
endfunction()
EOF

"${ROOT_DIR}/scripts/add-module.sh" "${project_input}" "${module_input}"

if ! git init -b main "${repo_dir}" >/dev/null 2>&1; then
  git -C "${repo_dir}" init >/dev/null
  git -C "${repo_dir}" symbolic-ref HEAD refs/heads/main >/dev/null 2>&1 || true
fi

echo "created ${repo_dir}"
