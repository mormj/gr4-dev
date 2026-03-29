#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/dev-env.sh" >/dev/null

if [ ! -d "${GR4_BUILD_PATH}" ]; then
  echo "nothing to clean: ${GR4_BUILD_PATH}"
  exit 0
fi

shopt -s nullglob dotglob
items=("${GR4_BUILD_PATH}"/*)
shopt -u nullglob dotglob

if [ ${#items[@]} -eq 0 ]; then
  echo "nothing to clean under ${GR4_BUILD_PATH}"
  exit 0
fi

rm -rf -- "${items[@]}"
echo "removed all build artifacts under: ${GR4_BUILD_PATH}"
