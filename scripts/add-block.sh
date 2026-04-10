#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
usage: add-block.sh <project-name> <module-name> <block-name>

Creates a new block under src/gr4-<project-name>/blocks/<module-name>.
Project and module names may use hyphens or underscores; generated filesystem
names use hyphens and C++ identifiers use underscores. Block names may be
PascalCase or use separators; the generated class and header name preserve
class-style casing.
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

validate_block_name() {
  local name="$1"

  if [[ ! "${name}" =~ ^[A-Za-z][A-Za-z0-9_-]*$ ]]; then
    die "block name must match [A-Za-z][A-Za-z0-9_-]*"
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
block_input="${3:-}"
if [ -z "${project_input}" ] || [ -z "${module_input}" ] || [ -z "${block_input}" ] || [ "${project_input}" = "-h" ] || [ "${project_input}" = "--help" ]; then
  usage
  exit 0
fi

project_slug_raw="${project_input#gr4-}"
module_slug_raw="${module_input#gr4-}"
block_slug_raw="${block_input#gr4-}"

validate_name "project name" "${project_slug_raw}"
validate_name "module name" "${module_slug_raw}"
validate_block_name "${block_slug_raw}"

project_name="$(to_kebab_case "${project_slug_raw}")"
project_ns="$(to_snake_case "${project_name}")"
module_name="$(to_kebab_case "${module_slug_raw}")"
module_ns="$(to_snake_case "${module_name}")"
block_class="$(to_pascal_case "${block_slug_raw}")"

repo_dir="${ROOT_DIR}/src/gr4-${project_name}"
module_dir="${repo_dir}/blocks/${module_name}"
include_dir="${module_dir}/include/gnuradio-4.0/${module_name}"
test_dir="${module_dir}/test"
header_file="${include_dir}/${block_class}.hpp"
test_file="${test_dir}/qa_${block_class}.cpp"

if [ ! -d "${repo_dir}" ]; then
  die "missing project repo: ${repo_dir}"
fi

if [ ! -d "${module_dir}" ]; then
  die "missing module directory: ${module_dir}"
fi

if [ -e "${header_file}" ]; then
  die "block already exists: ${header_file}"
fi

mkdir -p "${include_dir}" "${test_dir}"

cat > "${header_file}" <<EOF
#pragma once

#include <gnuradio-4.0/Block.hpp>
#include <gnuradio-4.0/BlockRegistry.hpp>

namespace gr::${project_ns}::${module_ns} {

template<typename T>
struct ${block_class} : Block<${block_class}<T>> {
    using Description = Doc<"@brief Pass-through scaffold block.">;

    PortIn<T> in;
    PortOut<T> out;

    GR_MAKE_REFLECTABLE(${block_class}, in, out);

    [[nodiscard]] constexpr T processOne(T input) const noexcept { return input; }
};

GR_REGISTER_BLOCK("gr::${project_ns}::${module_ns}::${block_class}", gr::${project_ns}::${module_ns}::${block_class}, ([T]), [ float, double ])

} // namespace gr::${project_ns}::${module_ns}
EOF

cat > "${test_file}" <<EOF
#include <gnuradio-4.0/${module_name}/${block_class}.hpp>

#include <gtest/gtest.h>

using namespace gr::${project_ns}::${module_ns};

TEST(${block_class}, PassThrough) {
    ${block_class}<float> block;
    EXPECT_FLOAT_EQ(block.processOne(4.25F), 4.25F);
}
EOF

echo "created ${header_file}"
