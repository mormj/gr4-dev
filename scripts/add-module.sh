#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
usage: add-module.sh <project-name> <module-name>

Creates a new module under src/gr4-<project-name>/blocks/<module-name>.
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

to_upper_case() {
  local name="$1"
  printf '%s' "$name" | tr '[:lower:]' '[:upper:]'
}

to_pascal_case() {
  local name="$1"
  local part first rest out=""

  IFS='-_'
  for part in ${name}; do
    [ -n "${part}" ] || continue
    first="${part:0:1}"
    rest="${part:1}"
    out+="$(printf '%s%s' "$(printf '%s' "${first}" | tr '[:lower:]' '[:upper:]')" "${rest}")"
  done
  unset IFS

  printf '%s' "${out}"
}

project_input="${1:-}"
module_input="${2:-}"
if [ -z "${project_input}" ] || [ -z "${module_input}" ] || [ "${project_input}" = "-h" ] || [ "${project_input}" = "--help" ]; then
  usage
  exit 0
fi

project_slug_raw="${project_input#gr4-}"
module_slug_raw="${module_input#gr4-}"

validate_name "project name" "${project_slug_raw}"
validate_name "module name" "${module_slug_raw}"

project_name="$(to_kebab_case "${project_slug_raw}")"
project_ns="$(to_snake_case "${project_name}")"
project_ns_upper="$(to_upper_case "${project_ns}")"
project_class="$(to_pascal_case "${project_name}")"
module_name="$(to_kebab_case "${module_slug_raw}")"
module_ns="$(to_snake_case "${module_name}")"
module_ns_upper="$(to_upper_case "${module_ns}")"
module_class="$(to_pascal_case "${module_name}")"
repo_dir="${ROOT_DIR}/src/gr4-${project_name}"
blocks_dir="${repo_dir}/blocks"
module_dir="${blocks_dir}/${module_name}"
include_dir="${module_dir}/include/gnuradio-4.0/${module_name}"
test_dir="${module_dir}/test"
blocks_cmake="${blocks_dir}/CMakeLists.txt"

if [ ! -d "${repo_dir}" ]; then
  die "missing project repo: ${repo_dir}"
fi

if [ -e "${module_dir}" ]; then
  die "module already exists: ${module_dir}"
fi

mkdir -p \
  "${include_dir}" \
  "${test_dir}"

cat > "${module_dir}/CMakeLists.txt" <<EOF
add_library(gr4_${project_ns}_${module_ns}_headers INTERFACE)
add_library(gr4_${project_ns}::${module_ns}_headers ALIAS gr4_${project_ns}_${module_ns}_headers)

target_include_directories(gr4_${project_ns}_${module_ns}_headers INTERFACE
  \$<BUILD_INTERFACE:\${CMAKE_CURRENT_SOURCE_DIR}/include>
  \$<INSTALL_INTERFACE:\${CMAKE_INSTALL_INCLUDEDIR}>
)

target_link_libraries(gr4_${project_ns}_${module_ns}_headers INTERFACE \${GR4I_GNURADIO4_TARGET})

install(DIRECTORY \${CMAKE_CURRENT_SOURCE_DIR}/include/gnuradio-4.0/${module_name}
  DESTINATION \${CMAKE_INSTALL_INCLUDEDIR}/gnuradio-4.0)

if(ENABLE_PLUGINS)
  file(GLOB GR4_${project_ns_upper}_${module_ns_upper}_HEADERS CONFIGURE_DEPENDS
    "\${CMAKE_CURRENT_SOURCE_DIR}/include/gnuradio-4.0/${module_name}/*.hpp")
  gr4_${project_ns}_add_block_plugin(Gr4${project_class}${module_class}Blocks
    MODULE_NAME_BASE ${module_name}
    SPLIT_BLOCK_INSTANTIATIONS
    HEADERS \${GR4_${project_ns_upper}_${module_ns_upper}_HEADERS}
    INCLUDE_DIRECTORIES "\${CMAKE_CURRENT_SOURCE_DIR}/include")
endif()

if(ENABLE_TESTING)
  add_subdirectory(test)
endif()
EOF

cat > "${module_dir}/README.md" <<EOF
# ${module_name}

This module belongs to the \`gr4-${project_name}\` project.

Namespace prefix:

- \`gr::${project_ns}::${module_ns}\`

Layout:

- \`include/gnuradio-4.0/${module_name}/\` for public block headers
- \`test/\` for unit tests
EOF

cat > "${test_dir}/CMakeLists.txt" <<EOF
if(NOT TARGET GTest::gtest_main)
  find_package(GTest CONFIG QUIET)
endif()

if(NOT TARGET GTest::gtest_main)
  message(STATUS "GTest not found; skipping tests for ${repo_dir}")
  return()
endif()

file(GLOB CONFIGURE_DEPENDS GR4_${project_ns_upper}_${module_ns_upper}_TEST_SOURCES
  "\${CMAKE_CURRENT_SOURCE_DIR}/qa_*.cpp"
)

foreach(test_source IN LISTS GR4_${project_ns_upper}_${module_ns_upper}_TEST_SOURCES)
  get_filename_component(test_name "\${test_source}" NAME_WE)
  string(REPLACE "-" "_" test_target "\${test_name}")
  add_executable("\${test_target}" "\${test_source}")
  target_link_libraries("\${test_target}"
    PRIVATE
      gr4_${project_ns}::${module_ns}_headers
      \${GR4I_GNURADIO4_TARGET}
      GTest::gtest_main
  )
  add_test(NAME "\${test_target}" COMMAND "\${test_target}")
endforeach()
EOF

if [ ! -f "${blocks_cmake}" ]; then
  cat > "${blocks_cmake}" <<'EOF'
# Modules are added below by add-module.sh.
EOF
fi

if ! grep -qxF "add_subdirectory(${module_name})" "${blocks_cmake}"; then
  printf '\nadd_subdirectory(%s)\n' "${module_name}" >> "${blocks_cmake}"
fi

echo "created ${module_dir}"
